# Concurrency — rule #55 in full

Rule numbers (`#4`) refer to `SKILL.md`. The worked code continues the referrals feature of `reference.md`.

## Pick the protection by what is at risk

Use the cheapest mechanism that enforces the rule, not the most powerful.

| What you're protecting | Use | Not |
|---|---|---|
| A counter / balance / stock | `Repo.update_all(inc: [...])` with the guard in the `where`, branching on the affected-row count | `get` → compute → `update`: both readers see the same value and the second erases the first, transaction or no transaction |
| A row that may or may not exist yet | unique index + `on_conflict` upsert, `unique_constraint/3` for the message | `if get_by(...), do: update, else: insert`: check-then-act is a race two requests will hit |
| A one-shot stamp / state transition | the condition in the statement (`where: is_nil(field)`) or a partial unique index | a changeset validation against the in-memory struct: two callers both read `nil`, both pass, both write |
| A decision read from rows you then write | `FOR UPDATE` as the first step **inside** the Multi (`lock/2` lives in `query.ex`, #13) | reading first and locking later, or never |
| An edit spanning human time (load form → submit) | `optimistic_lock(:lock_version)`, `Ecto.StaleEntryError` → typed error (#38) | a row lock held across a user session |
| Get-or-create, or replacing a whole set for a key | `pg_advisory_xact_lock` as the first Multi step, keyed on the domain id | session-scoped `pg_advisory_lock` + a manual unlock step: a rollback does not release it, and the lock rides the pooled connection to the next caller |
| An external call that must happen once per key | a claim row (unique index) + the provider's idempotency key, the call made outside the transaction | a lock held across the round-trip |
| Duplicate async work | Oban `unique:` on the worker | any lock: nothing contends if the duplicate is never enqueued |

## Rules that hold whichever row applies

- **Nothing external inside a transaction.** An HTTP call, an email or a payment capture holds a connection and every lock for a full round-trip, and cannot be rolled back. Make the call before the transaction opens, or enqueue an Oban job *as* a Multi step, so the job commits with the write and vanishes with it.
- **Take locks in one order everywhere**: ascending id, parent before children. A deadlock is two transactions taking the same locks in opposite order.
- **A lock only serialises the writers that take it.** Every writer of those columns locks and re-reads inside the transaction, or it commits stale-derived data over the top.
- **Services compose through `run/…`.** A Service calls another Service's `run/…` directly, from a `Multi.run` step included. Ecto transactions are reentrant: the inner `Repo.transaction` joins the outer one, so both sets of writes commit or roll back together.
- **A Service's external work is an Oban job enqueued as a Multi step**, which commits with the outermost transaction. Work done after the Service's own `Repo.transaction` returns still runs inside the caller's transaction, before its commit, when the Service is called from a `Multi.run` step.
- **Test the invariant, not the interleaving.** The ExUnit sandbox shares one connection, so a `Task.async` "race" proves nothing. Force the *last* Multi step to fail and assert nothing landed, `refute_enqueued` and `refute_event_received` included (#52), and assert the lock statement was issued with the expected key.

## Worked example — when one write becomes two

A referral must now also *spend* one of the referrer's invites. That is a second write, so the operation stops being a context function and becomes a Service running one `Ecto.Multi` in one transaction: a referral never exists without the invite it cost, and an invite is never spent without a referral.

The counter claim stays in the context that owns the row, as one atomic statement. The `where` carries the guard, so two concurrent referrals cannot both read the same `invites_remaining` and both spend it:

```elixir
# lib/my_app/accounts/users/query.ex
def with_invites_remaining_at_least(queryable, count) when is_integer(count) do
  where(queryable, [u], u.invites_remaining >= ^count)
end

# lib/my_app/accounts/users.ex
@doc "Spends one of the user's invites: `{:ok, user_id}` or `{:error, %Errors.NoInvitesRemainingError{}}`."
def claim_invite(user_id) when is_binary(user_id) do
  User
  |> Query.with_id(user_id)
  |> Query.with_invites_remaining_at_least(1)
  |> Repo.update_all(inc: [invites_remaining: -1])
  |> case do
    {1, _} -> {:ok, user_id}
    {0, _} -> {:error, Errors.NoInvitesRemainingError.new()}
  end
end
```

The Service (`lib/my_app/accounts/services/create_referral.ex`) composes the two context functions and writes no changeset of its own:

```elixir
defmodule MyApp.Accounts.Services.CreateReferral do
  @moduledoc "Creates a referral and spends one of the referrer's invites, atomically."

  alias Ecto.Multi
  alias MyApp.Accounts.Referral
  alias MyApp.Accounts.Referrals
  alias MyApp.Accounts.Users
  alias MyApp.Repo

  @doc """
  Creates the referral and spends the invite in one transaction.

  Returns `{:ok, %Referral{}}`, or `{:error, reason}` with nothing written.
  """
  def run(attrs, opts \\ []) do
    Multi.new()
    |> Multi.run(:referral, fn _repo, _changes -> Referrals.create_referral(attrs, opts) end)
    |> Multi.run(:claim_invite, fn _repo, %{referral: %Referral{referrer_id: referrer_id}} ->
      Users.claim_invite(referrer_id)
    end)
    |> Repo.transaction()
    |> unwrap()
  end

  # `Repo.transaction/1` reports a failed step as `{:error, step, reason, changes}`.
  # Every step here already returns a typed error, so the step name adds nothing —
  # match it by name only when the mapping differs per step.
  defp unwrap({:ok, %{referral: %Referral{} = referral}}), do: {:ok, referral}
  defp unwrap({:error, _step, reason, _changes}), do: {:error, reason}
end
```

What the Service changes around it:

- Callers use `CreateReferral.run(attrs, opts)` **directly**; a Service is never `defdelegate`d onto the facade (#4). The resolver in `graphql.md` calls `CreateReferral.run(attrs, EventMetadata.build_opts(res))` in place of `Accounts.create_referral/2`.
- The facade's `defdelegate create_referral` is deleted: no caller outside the context is left (#56).
- `Errors.NoInvitesRemainingError` is defined before this code returns it (#38).
- The `success_event:` on `create_referral/2` still fires from inside the transaction. The event is an Oban job row, so it is enqueued with the write and rolls back with it.
- The viewer in the mutation test of `graphql.md` is inserted with `invites_remaining: 1`.

## Testing the Service

Force the *last* step to fail, so the earlier write has already been applied, then assert that nothing survived, the event included:

```elixir
# test/my_app/accounts/services/create_referral_test.exs
use MyApp.DataCase, async: true
use ExEventBus.Testing, ex_event_bus: MyApp.EventBus

describe "run/2" do
  test "when the referrer has an invite left" do
    referrer = insert(:user, invites_remaining: 1)

    assert {:ok, %Referral{email: "friend@example.com"}} =
             CreateReferral.run(%{referrer_id: referrer.id, email: "friend@example.com"})

    assert Repo.reload(referrer).invites_remaining == 0
  end

  test "when the referrer is out of invites, nothing is written" do
    referrer = insert(:user, invites_remaining: 0)

    assert {:error, %Errors.NoInvitesRemainingError{}} =
             CreateReferral.run(%{referrer_id: referrer.id, email: "friend@example.com"})

    assert Repo.aggregate(Referral, :count) == 0
    refute_event_received(Events.ReferralCreated)
  end
end
```

The two tests differ only in the fixture that drives the outcome (`invites_remaining: 1` against `0`), so the cause of each result is visible in the diff between them (#54).
