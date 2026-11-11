# Engineering principles — worked examples in Elixir

The bad/good pairs of [reference.md](reference.md), in Elixir. `elixir #N` cites a rule of the `elixir-phoenix-conventions` skill; when that skill is loaded, its own examples take precedence.

## Contents

- [A. Names (EP-A1–A5)](#a-names-ep-a1a5): examples for EP-A1, EP-A2
- [B. Functions (EP-B1–B7)](#b-functions-ep-b1b7): examples for EP-B5, EP-B6
- [C. Control flow and errors (EP-C1–C4)](#c-control-flow-and-errors-ep-c1c4): examples for EP-C1, EP-C2, EP-H3
- [D. Design (EP-D1–D13)](#d-design-ep-d1d13): examples for EP-D6, EP-D8, EP-D10, EP-D12, EP-D13
- [E. Boundaries (EP-E1–E6)](#e-boundaries-ep-e1e6): examples for EP-E2, EP-E5, EP-E6
- [F. Comments and docs (EP-F1–F5)](#f-comments-and-docs-ep-f1f5): examples for EP-F1, EP-F4
- [G. Tests (EP-G1–G6)](#g-tests-ep-g1g6): examples for EP-G4, EP-G5
- [H. Concurrency, transactions and side effects (EP-H1–H14)](#h-concurrency-transactions-and-side-effects-ep-h1h14): examples for EP-H2, EP-H5, EP-H10, EP-H14
- [I. Change hygiene (EP-I1–I7)](#i-change-hygiene-ep-i1i7): examples for EP-I1, EP-I3, EP-I5, EP-I6, EP-I7
- [J. Code smells (EP-J1–J18)](#j-code-smells-ep-j1j18): examples for EP-J5
- [K. Data access and performance (EP-K1–K11)](#k-data-access-and-performance-ep-k1k11): examples for EP-K6, EP-K7, EP-K9, EP-K11

## A. Names (EP-A1–A5)

```elixir
# ✗
def calc(u), do: u.r * 12
# ✓
def yearly_rent(%Student{monthly_rent: monthly_rent}), do: monthly_rent * 12
```

EP-A2: the concept keeps the word the codebase already gives it.

```elixir
# ✗
@callback mint_participant_token(participant()) :: String.t()
# ✓
@callback issue_participant_token(participant()) :: String.t()
```

## B. Functions (EP-B1–B7)

A name that promises a question must not change anything (EP-B5, EP-B6).

```elixir
# ✗ — a predicate that writes
def valid?(%Booking{} = booking) do
  Repo.update!(Booking.check_changeset(booking))
  Date.compare(booking.starts_on, booking.ends_on) == :lt
end

# ✓
def valid?(%Booking{starts_on: starts_on, ends_on: ends_on}),
  do: Date.compare(starts_on, ends_on) == :lt
```

## C. Control flow and errors (EP-C1–C4)

```elixir
# ✗ — the update can fail; the caller always sees :ok
def archive_wish(%Wish{} = wish) do
  wish |> Wish.archive_changeset() |> Repo.update()
  :ok
end

# ✓ — every shape handled, the failure travels back
def archive_wish(%Wish{} = wish) do
  wish
  |> Wish.archive_changeset()
  |> Repo.update()
  |> case do
    {:ok, wish} -> {:ok, wish}
    {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
  end
end
```

EP-H3, EP-C1, EP-C2 and EP-A2: every constraint comes back as an error, and a getter keeps its family's contract.

```elixir
# ✗ — an undeclared foreign key raises; a private get_* returns nil; the race recovery can return {:ok, nil}
|> unique_constraint([:session_id, :user_id])

defp get_participation(session_id, user_id),
  do: Participation |> Query.with_session_id(session_id) |> Query.with_user_id(user_id) |> Repo.one()

{:error, %Ecto.Changeset{errors: [{:session_id, {_, [constraint: :unique, constraint_name: _]}} | _]}} ->
  {:ok, get_participation(session_id, user_id)}

# ✓ — every constraint declared (elixir #7); the getter keeps the family's contract (elixir #15)
|> foreign_key_constraint(:user_id)
|> unique_constraint([:session_id, :user_id])

defp get_participation(session_id, user_id) do
  case Participation |> Query.with_session_id(session_id) |> Query.with_user_id(user_id) |> Repo.one() do
    %Participation{} = participation -> {:ok, participation}
    nil -> {:error, Errors.NotFoundError.new(resource_type: "LiveParticipation")}
  end
end

{:error, %Ecto.Changeset{errors: [{:session_id, {_, [constraint: :unique, constraint_name: _]}} | _]}} ->
  get_participation(session_id, user_id)
```

## D. Design (EP-D1–D13)

Minimal solution first (EP-D12): build for the requirement that exists.

```elixir
# ✗ — a behaviour, a registry and a config switch for one provider
@callback charge(Order.t()) :: {:ok, Charge.t()} | {:error, term()}
def provider, do: Application.fetch_env!(:app, :payment_provider)
def charge(order), do: provider().charge(order)

# ✓ — one module; the behaviour arrives with the second provider (or with a test double at the boundary, EP-D6)
def charge(%Order{} = order), do: StripeClient.create_charge(order)
```

EP-D6: an external service is reached through an adapter that speaks the app's types.

```elixir
# ✗ — the plug calls the provider's module; the service matches the provider's payload
case App.Live.LiveKitWebhook.verify(token, body) do ... end
def run(%{"event" => "participant_joined", "participant" => %{"identity" => identity}}), do: ...

# ✓ — the configured adapter verifies and translates (elixir #5); past it, only the app's struct
@callback verify_webhook(token :: String.t() | nil, body :: binary()) ::
            {:ok, Connection.t() | :ignored} | {:error, :invalid_signature}
def run(%Connection{activity_id: activity_id, user_id: user_id, role: role}), do: ...
```

EP-D8: every piece a change adds is read by production code in that change.

```elixir
# ✗ — written on every host connection, read by nothing but its own test
def mark_host_seen(%Session{} = session),
  do: session |> Session.host_seen_changeset() |> Repo.update()

# ✓ — left out of this change; the change that closes a live the host left adds the columns, this function and its reader
```

EP-D10: a rule that varies by actor takes the actor as data, on one path.

```elixir
# ✗ — a second event and handler that differ from the viewer's only by the actor
defevents([LiveParticipationRecorded, LiveHostSeen])
# ConfirmViewerAttendance handles LiveParticipationRecorded; ConfirmHostAttendance handles LiveHostSeen

# ✓ — the role is a column of the participation; one event, one handler
|> cast(attrs, [:session_id, :user_id, :role, :first_joined_at])
|> validate_inclusion(:role, ~w(host viewer))
```

EP-D13: the same job, done the codebase's way.

```elixir
# ✗ — a second way to read a setting and to default one, beside the codebase's
:app |> Application.fetch_env!(:live) |> Keyword.fetch!(:opens_before_minutes)
String.to_integer(System.get_env("LIVE_OPENS_BEFORE_MINUTES", "15"))

# ✓ — the app's config module and the default idiom config/runtime.exs already uses (elixir #64)
:app |> App.Config.fetch_env!(:live) |> Keyword.fetch!(:opens_before_minutes)
String.to_integer(System.get_env("LIVE_OPENS_BEFORE_MINUTES") || "15")
```

## E. Boundaries (EP-E1–E6)

```elixir
# ✗ — the context knows its consumers
def list_activities(client), do: if(client == "mobile", do: public(), else: all())
# ✓ — one domain function; the /api and /admin schemas shape the output
def list_activities(filters), do: Activity |> Query.filtered_by(filters) |> Repo.all()
```

EP-E5 — the old field keeps working until no installed app asks for it:

```elixir
# ✗ — every installed app that still asks for `title` gets an error
field :name, non_null(:string)

# ✓ — add `name`, keep `title` deprecated, remove it once no deployed client uses it
field :name, non_null(:string)
field :title, non_null(:string), deprecate: "Use name.", resolve: fn wish, _, _ -> {:ok, wish.name} end
```

EP-E6: a setting is checked at boot, wherever the code that reads it is on.

```elixir
# ✗ — config/runtime.exs: nil allowed, production only, under the domain's key
if config_env() == :prod do
  config :app, :live, livekit_webhook_secret: System.get_env("LIVEKIT_WEBHOOK_SECRET")
end

# ✓ — under the adapter's key, required wherever it is the configured adapter (elixir #5)
if live_adapter == App.Live.Adapters.LiveKit do
  config :app, App.Live.Adapters.LiveKit, webhook_secret: fetch_env!.("LIVEKIT_WEBHOOK_SECRET")
end
```

## F. Comments and docs (EP-F1–F5)

A stale doc is a bug (EP-F4): when `list_wishes` stops returning archived wishes, the sentence "lists every wish, including archived ones" changes in the same commit.

```elixir
# ✗ — the comment repeats the code; the doc still describes the old behaviour
# insert the event
Repo.insert(event, on_conflict: :nothing, conflict_target: :provider_event_id)

@doc "Lists every wish of the member, including archived ones."
def list_wishes(member), do: member |> Wish.Query.for_member() |> Wish.Query.not_archived() |> Repo.all()

# ✓ — the comment says why; the doc changed with the behaviour
# The provider redelivers webhooks for 3 days; the unique index turns a replay into a no-op.
Repo.insert(event, on_conflict: :nothing, conflict_target: :provider_event_id)

@doc "Lists the member's wishes that are not archived, newest first."
def list_wishes(member), do: member |> Wish.Query.for_member() |> Wish.Query.not_archived() |> Repo.all()
```

## G. Tests (EP-G1–G6)

```elixir
# ✗ — passes whatever archive_wish returns inside :ok
test "archives the wish" do
  wish = insert(:wish)
  assert {:ok, _} = Wishes.archive_wish(wish)
end

# ✓
test "when the wish is active" do
  wish = insert(:wish, archived_at: nil)
  assert {:ok, %Wish{archived_at: %DateTime{}}} = Wishes.archive_wish(wish)
end

test "when the wish is already archived" do
  wish = insert(:wish, archived_at: ~U[2026-01-01 00:00:00Z])
  assert {:error, %Errors.WishAlreadyArchivedError{}} = Wishes.archive_wish(wish)
end
```

EP-G4, per branch: each branch of the changed code names the test that fails when it changes, and behaviour that depends on the environment is tested under a non-default one.

```elixir
# ✓ — the session's time zone is not the default, so the conversion is what the test checks (elixir #54)
test "when the database reads times in another time zone" do
  activity = insert(:activity, starts_at: ~U[2026-10-28 18:00:00Z])
  ended = insert(:live_session, activity: activity, status: "ended", activity_starts_at: ~N[2026-10-28 18:00:00])
  Repo.query!("SET LOCAL TIME ZONE 'America/New_York'")

  assert {:ok, %Session{id: id}} = Live.get_session(activity.id)
  assert id == ended.id
end
```

EP-G4: an endpoint's promise for every input is tested on its failure paths.

```elixir
# ✓ — drives the failure path the controller's moduledoc promises to answer 200
test "when the connection cannot be recorded", %{conn: conn} do
  user = insert(:user)
  {:ok, _deleted} = Accounts.delete_user(user)
  expect(App.Live.AdapterMock, :verify_webhook, fn _token, _body -> {:ok, connection_of(user)} end)

  conn = post(conn, "/webhooks/media-server", "{}")

  assert json_response(conn, 200) == %{"status" => "ok"}
  assert Repo.aggregate(Participation, :count) == 0
end
```

## H. Concurrency, transactions and side effects (EP-H1–H14)

```elixir
# ✗ — email inside the transaction, read-then-write on the counter
Repo.transaction(fn ->
  user = Repo.get!(User, user_id)
  Repo.update!(User.changeset(user, %{invites_remaining: user.invites_remaining - 1}))
  Mailer.deliver_invite(email)
end)

# ✓ — one atomic conditional update, the email as a job that commits with the write
Ecto.Multi.new()
|> Ecto.Multi.update_all(:spend_invite, Query.with_invites_left(user_id), inc: [invites_remaining: -1])
|> Ecto.Multi.run(:check, fn _repo, %{spend_invite: {count, _}} -> ensure_spent(count) end)
|> Oban.insert(:send_invite, SendInviteWorker.new(%{email: email}))
|> Repo.transaction()
```

EP-H14 and EP-H10: the event carries what happened, and only what matters once publishes one.

```elixir
# ✗ — a stamp that publishes on every check; a handler that re-derives the host when it runs
def mark_host_seen(session, opts),
  do: session |> Session.host_seen_changeset() |> Repo.update(success_event: Events.LiveHostSeen, event_opts: opts)

def handle_event(%{aggregate: %{"activity_id" => activity_id}}) do
  with {:ok, activity} <- Communities.get_activity(activity_id),
       do: Communities.confirm_attendance(activity_id, Live.host_id(activity))
end

# ✓ — the stamp stays silent; the participation's event carries who connected (elixir #45)
def mark_host_seen(session), do: session |> Session.host_seen_changeset() |> Repo.update()

def handle_event(%{aggregate: %{"activity_id" => activity_id, "user_id" => user_id}}),
  do: Communities.confirm_attendance(activity_id, user_id)
```

## I. Change hygiene (EP-I1–I7)

```elixir
# ✗ — left behind when the query moved to Wish.Query; it only delegates
def fetch_wish(id), do: get_wish(id)

# ✓ — deleted in the same change; its callers now call get_wish/1
```

EP-I3 — the check stays on; the code changes:

```elixir
# ✗ — silences the check that caught the nesting, and says nothing about why
# credo:disable-for-next-line Credo.Check.Refactor.Nesting
def partial_refund(%{amount: total} = payment, amount) do
  if amount > 0 do
    if amount <= total, do: Payments.refund(payment.id, amount), else: {:error, :exceeds_payment}
  else
    {:error, :invalid_amount}
  end
end

# ✓ — the guards say what the nesting said; nothing is disabled
def partial_refund(%{amount: total} = payment, amount) when amount > 0 and amount <= total,
  do: Payments.refund(payment.id, amount)

def partial_refund(%{amount: total}, amount) when amount > total, do: {:error, :exceeds_payment}
def partial_refund(_payment, _amount), do: {:error, :invalid_amount}
```

EP-I5 — the previous version keeps working while the new one rolls out:

```elixir
# ✗ — the previous version still reads and writes `title` for the minutes the rollout lasts
rename table(:wishes), :title, to: :name

# ✓ — deploy 1 adds `name`, writes both and backfills; deploy 2 reads `name`;
#     deploy 3 drops `title` once nothing uses it
alter table(:wishes), do: add(:name, :string)
```

EP-I6: a migration that may have run is final; the schema moves forward.

```elixir
# ✗ — priv/repo/migrations/20261001000000_create_live_sessions.exs, already on main, edited in place
add :role, :string, null: false, default: "viewer"

# ✓ — a new migration (elixir #63)
defmodule App.Repo.Migrations.AddRoleToLiveParticipations do
  use Ecto.Migration

  def change do
    alter table(:live_participations) do
      add :role, :string, null: false, default: "viewer"
    end
  end
end
```

EP-I7: a change to what rows mean names every reader.

```elixir
# ✗ — host rows land in a table that a reader counts as members
Live.record_participation(session, host_id, "host", opts)
def count_participants(session_id), do: Participation |> Query.with_session_id(session_id) |> Query.count()

# ✓ — the same change updates every reader it found, and the PR description names them
def count_participants(session_id),
  do: Participation |> Query.with_session_id(session_id) |> Query.with_role("viewer") |> Query.count()
```

## J. Code smells (EP-J1–J18)

Feature envy (EP-J5 → EP-D2): the logic moves to the data it uses.

```elixir
# ✗ — the controller computes a billing rule from the invoice's own data
def show(conn, %{"id" => id}) do
  invoice = Billing.get_invoice!(id)
  total = Enum.reduce(invoice.lines, 0, &(&1.price * &1.quantity + &2)) - invoice.customer.discount
  render(conn, :show, invoice: invoice, total: total)
end

# ✓ — the rule lives in the context, next to the data it uses
def show(conn, %{"id" => id}) do
  invoice = Billing.get_invoice!(id)
  render(conn, :show, invoice: invoice, total: Billing.invoice_total(invoice))
end
```

## K. Data access and performance (EP-K1–K11)

```elixir
# ✗ — N+1, unbounded, and an index built with a write lock
listings |> Enum.map(&Repo.preload(&1, :host))
create index(:listings, [:host_id])

# ✓ — one preload query, a page, and a non-blocking index build
Listing |> Query.filtered_by(filters) |> Query.paginate(page) |> Repo.all() |> Repo.preload(:host)

@disable_ddl_transaction true
@disable_migration_lock true
def change, do: create index(:listings, [:host_id], concurrently: true)
```

EP-K11: the query builder's constructs; raw SQL only for what it cannot express.

```elixir
# ✗ — the subquery and its table written by hand (elixir #12)
where(queryable, [s], fragment(
  "NOT EXISTS (SELECT 1 FROM live_sessions AS later WHERE later.activity_id = ? AND (later.inserted_at, later.id) > (?, ?))",
  s.activity_id, s.inserted_at, s.id))

# ✓ — exists and parent_as over the schema; the row comparison is the only fragment
queryable |> from(as: :session) |> where([s], not exists(later_session()))

defp later_session do
  from(later in Session,
    where: later.activity_id == parent_as(:session).activity_id,
    where: fragment("(?, ?) > (?, ?)", later.inserted_at, later.id, parent_as(:session).inserted_at, parent_as(:session).id),
    select: 1
  )
end
```
