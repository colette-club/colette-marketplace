# Worked example — adding a feature the conventional way

One complete, correct example of a **new feature with no existing template**: a user refers a friend by email. This is the failure-prone case (nothing to copy), so it shows every layer wired the conventional way. Adapt it; don't treat it as a fill-in template. `MyApp`/`MyAppWeb` stand in for the app namespace, and `Public` for one GraphQL endpoint.

## 1. Schema (`lib/my_app/accounts/referral.ex`)

```elixir
defmodule MyApp.Accounts.Referral do
  @moduledoc "A referral: a user inviting a friend by email."

  use MyApp.Schema, :schema

  alias MyApp.Accounts.User

  @derive {JSON.Encoder, except: [:__meta__, :referrer]}
  schema "referrals" do
    field :email, :string
    belongs_to :referrer, User

    timestamps()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:referrer_id, :email])
    |> validate_required([:referrer_id, :email])
    |> update_change(:email, &String.downcase/1)
    |> foreign_key_constraint(:referrer_id)
    |> unique_constraint([:referrer_id, :email])
  end
end
```

Schema `use MyApp.Schema, :schema`, `@derive {JSON.Encoder, ...}`, changeset in the schema module.

## 2. Sub-module holds the logic (`lib/my_app/accounts/referrals.ex`)

```elixir
defmodule MyApp.Accounts.Referrals do
  @moduledoc "Referrals: a user can refer a friend by email."

  alias MyApp.Accounts.Events
  alias MyApp.Accounts.Referral
  alias MyApp.Accounts.Referrals.Query
  alias MyApp.Errors
  alias MyApp.Repo

  def create_referral(attrs \\ %{}, opts \\ []) do
    attrs
    |> Referral.create_changeset()
    |> Repo.insert(success_event: Events.ReferralCreated, event_opts: opts)
    |> case do
      {:ok, referral} ->
        {:ok, referral}

      {:error, %Ecto.Changeset{errors: [{:referrer_id, {_, [constraint: :unique]}} | _]}} ->
        {:error, Errors.ReferralAlreadyExistsError.new()}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Fetches a referral by id.

  ## Options
    * `:preloads` — associations to load. Supported: `:referrer`.
  """
  def get_referral(id, opts \\ []) when is_binary(id) do
    preloads = Keyword.get(opts, :preloads, [])

    Referral
    |> maybe_preload(preloads)
    |> Repo.get(id)
  end

  @doc """
  Lists referrals, paginated.

  ## Options
    * `:preloads` — associations to load. Supported: `:referrer`.
  """
  def list_referrals(func \\ default_fun(), args \\ %{}, opts \\ []) do
    preloads = Keyword.get(opts, :preloads, [])

    Referral
    |> maybe_preload(preloads)
    |> Query.paginate(func, args, opts)
  end

  # ONE reducer per module: each supported atom maps to a Query.preload_<assoc>/1
  # call, unknown atoms fall through, and a second head guards non-list input.
  defp maybe_preload(queryable, preloads) when is_list(preloads) do
    Enum.reduce(preloads, queryable, fn
      :referrer, acc -> Query.preload_referrer(acc)
      _, acc -> acc
    end)
  end

  defp maybe_preload(queryable, _), do: queryable
end
```

No `if/else`: the duplicate is matched in a `case` clause. Event emitted via `success_event:`. Function takes `opts \\ []`. Preloads are **opt-in**: each read pulls a list of association atoms from `opts[:preloads]` (default `[]`) and threads it through the single private `maybe_preload/2`, so nothing is over-fetched and there is no implicit N+1. (`func`/`default_fun()` are the app's `Query.paginate/4` cursor plumbing, elided here.)

## 2a. Query module — opt-in preloads (`lib/my_app/accounts/referrals/query.ex`)

The actual `preload/2` lives here, never in the sub-module (highest-risk #3). One chainable fn per association; the sub-module's `maybe_preload/2` just dispatches to these.

```elixir
defmodule MyApp.Accounts.Referrals.Query do
  @moduledoc false

  use MyApp.Query

  # `:referrer` is a `belongs_to` (to-one): create the named binding, then preload
  # off it — one query, no extra DB call. `with_named_binding/3` adds the join only
  # if that binding isn't already present, so a filter and a preload that both need
  # `:referrer` share ONE join instead of duplicating it.
  def preload_referrer(queryable) do
    queryable
    |> with_referrer_binding()
    |> preload([referrer: u], referrer: u)
  end

  defp with_referrer_binding(queryable) do
    with_named_binding(queryable, :referrer, fn query, binding ->
      # LEFT so referrals without a referrer aren't dropped; use :inner when the
      # association is required or the binding is shared with a filtering join.
      join(query, :left, [r], u in assoc(r, ^binding), as: ^binding)
    end)
  end
end
```

`preload_referrer/1` creates the `:referrer` binding via `with_named_binding/3`, then preloads off it — all in one query **because `:referrer` is to-one** — so the rule *avoid the extra DB call whenever you can* holds, and the join is never duplicated even if a filter already added the same binding. For a **to-many** association you have no such choice: a join would multiply referral rows and corrupt `limit`/pagination, so a separate-query `preload/2` is the right tool — `def preload_<assoc>(q), do: preload(q, :<assoc>)` — not a smell. Nested/keyword preloads use the same shape (`preload(q, driver: :user)`).

## 2b. Service — when one write becomes two (`lib/my_app/accounts/services/create_referral.ex`)

Say a referral must also *spend* one of the referrer's invites. That is a second write, so the operation stops being a context function and becomes a Service running one `Ecto.Multi` in one transaction (#55) — a referral must never exist without the invite it cost, and an invite must never be spent without a referral.

The counter claim stays in the context that owns the row, as one atomic statement — the `where` carries the guard, so two concurrent referrals cannot both read the same `invites_remaining` and both spend it:

```elixir
# lib/my_app/accounts/users/query.ex
def with_invites_remaining_at_least(queryable, count) when is_integer(count) do
  where(queryable, [u], u.invites_remaining >= ^count)
end

# lib/my_app/accounts/users.ex
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

The Service composes the two context functions — it writes no changesets of its own:

```elixir
defmodule MyApp.Accounts.Services.CreateReferral do
  @moduledoc "Creates a referral and spends one of the referrer's invites, atomically."

  alias Ecto.Multi
  alias MyApp.Accounts.Referral
  alias MyApp.Accounts.Referrals
  alias MyApp.Accounts.Users
  alias MyApp.Repo

  @doc """
  Adds this Service's steps to a Multi.

  A Service composing this one calls `multi/3` — NEVER `run/2` — so both sets of
  steps share ONE transaction. Nesting `Repo.transaction` instead does not create
  an inner transaction: Ecto joins it to the outer one, an inner rollback aborts
  the whole outer transaction, and this module's post-commit work would silently
  run before the commit.
  """
  def multi(multi \\ Multi.new(), attrs, opts) do
    multi
    |> Multi.run(:referral, fn _repo, _changes -> Referrals.create_referral(attrs, opts) end)
    |> Multi.run(:claim_invite, fn _repo, %{referral: %Referral{referrer_id: referrer_id}} ->
      Users.claim_invite(referrer_id)
    end)
  end

  @doc """
  Creates the referral and spends the invite in one transaction.

  Returns `{:ok, %Referral{}}`, or `{:error, reason}` with nothing written.
  """
  def run(attrs, opts \\ []) do
    Multi.new()
    |> multi(attrs, opts)
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

Callers use `CreateReferral.run(attrs, opts)` **directly** — a Service is never `defdelegate`d onto the facade (#4). `Errors.NoInvitesRemainingError` must exist before this code returns it (define-then-return, section 5). The `success_event:` on `create_referral/2` still fires from inside the transaction: the event is an Oban job row, so it is enqueued with the write and rolls back with it — a referral that didn't stick never announces itself.

## 3. Facade delegates (`lib/my_app/accounts.ex`)

```elixir
# add alongside the other defdelegates
defdelegate create_referral(attrs, opts \\ []), to: Referrals
```

Callers use `Accounts.create_referral/2` — never `Accounts.Referrals.create_referral/2`.

## 4. Event (`lib/my_app/accounts/events.ex`)

```elixir
# add to the existing defevents list
defevents([
  # ...
  ReferralCreated
])
```

## 5. Typed error (`lib/my_app/errors/referral_already_exists_error.ex`)

```elixir
defmodule MyApp.Errors.ReferralAlreadyExistsError do
  use MyApp.ExErrors

  defexerror(message: "You have already referred this email address")
end
```

The module must exist before any code returns it — **define-then-return**; never reference an undefined `Errors.*`. For errors that carry data, list the fields (and which are required); they surface under `extensions.fields`:

```elixir
defmodule MyApp.Errors.NotFoundError do
  use MyApp.ExErrors

  defexerror([:resource_type, :resource_id, message: "Resource not found"],
    required_fields: [:resource_type]
  )
end

# {:error, Errors.NotFoundError.new(resource_type: "User", resource_id: id)}
# → extensions: %{"errorCode" => "NotFoundError", "fields" => %{"resource_type" => "User", "resource_id" => id}}
```

## 6. Resolver (`lib/my_app_web/api/public/resolvers/accounts/referral.ex`)

```elixir
defmodule MyAppWeb.Api.Public.Resolvers.Accounts.Referral do
  @moduledoc false

  use MyAppWeb, :resolver

  alias MyApp.Accounts
  alias MyAppWeb.Support.EventMetadata

  # `payload field` mutations use 2-arity resolvers: (input, resolution).
  def create_referral(%{email: email}, %{context: %{current_user: current_user}} = res) do
    attrs = %{referrer_id: current_user.id, email: email}

    with {:ok, referral} <- Accounts.create_referral(attrs, EventMetadata.build_opts(res)) do
      {:ok, %{referral: referral}}
    end
  end
end
```

Calls the **facade**, `with` chain, `EventMetadata.build_opts(res)`, returns `{:ok, %{referral: ...}}`. The typed error and changeset fall through `with` and the schema's `ErrorHandler` serializes them. Note the arity: `payload field` mutation resolvers take `(input, resolution)` — 2 args, not 3.

## 7. Mutation type (`lib/my_app_web/api/public/schema/mutations/accounts/referral.ex`)

```elixir
defmodule MyAppWeb.Api.Public.Schema.Mutations.Accounts.Referral do
  @moduledoc false

  use MyAppWeb, :type

  alias MyAppWeb.Api.Public.Resolvers.Accounts.Referral, as: Resolver
  alias MyAppWeb.Api.Public.Schema.Middlewares

  object :referral_mutations do
    @desc "Refer a friend by email."
    payload field(:create_referral) do
      input do
        field :email, non_null(:string)
      end

      output do
        field :referral, non_null(:referral)
      end

      middleware(Middlewares.Authenticated)
      resolve(&Resolver.create_referral/2)
    end
  end
end
```

## 8. Tests

Each `describe` block covers **one and only one function**, named `"fun/arity"` — `get_referral/2` and `list_referrals/3` would each get their *own* `describe`, never a shared one, and `create_referral/2`'s tests never spill into another block.

Every test is **self-contained**: it builds the data it asserts against inside its own body (`referrer = insert(:user)`), passes the fields the assertion depends on explicitly and inline, and asserts on values you can see in the test — no `setup` fixture, no `@valid_attrs` module attribute, nothing to scroll up for. `setup` is reserved for harness wiring (Mox mode, `conn`, sandbox), never the entities under assertion — a helper runs because the test *calls* it, a `setup` runs because the test *happens to live* in that module. Note how each test below re-creates its own `referrer` rather than sharing one through context: the duplicated `insert(:user)` is the price of a test that still makes sense quoted on its own in a PR comment or an agent's context.

```elixir
# test/my_app/accounts/referrals_test.exs
use MyApp.DataCase, async: true
use ExEventBus.Testing, ex_event_bus: MyApp.EventBus

describe "create_referral/2" do
  test "creates a referral and emits an event" do
    referrer = insert(:user)

    assert {:ok, referral} =
             Accounts.create_referral(%{referrer_id: referrer.id, email: "friend@example.com"})

    assert_event_received(Events.ReferralCreated, args: %{aggregate: %{id: referral.id}})
  end

  test "when the same email was already referred" do
    referrer = insert(:user)
    attrs = %{referrer_id: referrer.id, email: "friend@example.com"}
    assert {:ok, _} = Accounts.create_referral(attrs)

    assert {:error, %Errors.ReferralAlreadyExistsError{}} = Accounts.create_referral(attrs)
  end
end
```

`assert_event_received` only proves the event was *enqueued* (events are Oban jobs). To prove the handler actually *runs* cleanly, drain the queue with `execute_events/0,1` (provided by `use ExEventBus.Testing, ex_event_bus: MyApp.EventBus`) and assert on the result:

```elixir
test "ReferralCreated handler runs without failures" do
  referrer = insert(:user)
  {:ok, _} = Accounts.create_referral(%{referrer_id: referrer.id, email: "friend@example.com"})

  assert %{failure: 0} =
           execute_events(event_handler: Accounts.EventHandler.ReferralCreated)
end
```

A transactional Service is tested for its **invariant**, not for two transactions racing — the sandbox shares one connection, so a `Task.async` "race" proves nothing (#55). Force the *last* step to fail, so the earlier write has already been applied, then assert that nothing survived — including the event, which is an Oban row inside the same transaction:

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

The two tests differ only in the fixture that drives the outcome (`invites_remaining: 1` vs `0`), so the cause of each result is visible in the diff between them.

The GraphQL document lives next to its test, named like the query:

```graphql
# test/my_app_web/api/public/schema/mutations/accounts/CreateReferral.gql
mutation CreateReferral($input: CreateReferralInput!) {
  createReferral(input: $input) {
    referral {
      id
      email
    }
  }
}
```

```elixir
# test/my_app_web/api/public/schema/mutations/accounts/create_referral_test.exs
defmodule MyAppWeb.Api.Public.Schema.Mutations.Accounts.CreateReferralTest do
  @moduledoc false

  use MyAppWeb.ConnCase, async: true
  use MyAppWeb.PublicGqlCase

  @moduletag :gql

  load_gql_file("CreateReferral.gql")

  describe "CreateReferral.gql" do
    test "when not authenticated" do
      query_data = query_gql(variables: %{"input" => %{email: "friend@example.com"}})

      assert nil == get_in(query_data, ["data", "createReferral"])

      assert "UnauthenticatedError" ==
               get_in(query_data, ["errors", Access.at(0), "extensions", "errorCode"])
    end

    test "when authenticated" do
      viewer = insert(:user)

      query_data =
        query_gql(
          variables: %{"input" => %{email: "friend@example.com"}},
          current_user: viewer
        )

      assert nil == get_in(query_data, ["errors"])

      assert "friend@example.com" ==
               get_in(query_data, ["data", "createReferral", "referral", "email"])
    end

    test "when the email was already referred" do
      viewer = insert(:user)
      insert(:referral, referrer: viewer, email: "friend@example.com")

      query_data =
        query_gql(
          variables: %{"input" => %{email: "friend@example.com"}},
          current_user: viewer
        )

      assert nil == get_in(query_data, ["data", "createReferral"])

      assert "ReferralAlreadyExistsError" ==
               get_in(query_data, ["errors", Access.at(0), "extensions", "errorCode"])
    end
  end
end
```

GQL test conventions: `use MyAppWeb.ConnCase, async: true` **and** `use MyAppWeb.{Endpoint}GqlCase` together; `@moduletag :gql`; `load_gql_file("X.gql")` (filename only — the schema is inferred from the GqlCase); `describe` is the `.gql` filename; Relay input passed as `variables: %{"input" => %{...}}` (string `"input"` key); auth via `current_user:`; error assertions drill into `["errors", Access.at(0), "extensions", "errorCode"]` and check `["data", "<mutation>"] == nil`.
