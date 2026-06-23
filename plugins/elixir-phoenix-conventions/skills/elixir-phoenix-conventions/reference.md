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
end
```

No `if/else`: the duplicate is matched in a `case` clause. Event emitted via `success_event:`. Function takes `opts \\ []`.

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
