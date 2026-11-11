# GraphQL — worked resolver, mutation and test

Rule numbers (`#40`) refer to `SKILL.md`. The code is the web layer of the referrals feature of `reference.md`; `Public` stands for one GraphQL endpoint.

## Resolver (`lib/my_app_web/api/public/resolvers/accounts/referral.ex`)

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

- A `payload field` mutation resolver takes `(input, resolution)`: two arguments, not three.
- The typed error and the changeset fall through the `with`, and the schema's `ErrorHandler` serializes them (#39).
- Once the operation is a Service, the resolver calls `CreateReferral.run/2` directly (`concurrency.md`).

## Mutation type (`lib/my_app_web/api/public/schema/mutations/accounts/referral.ex`)

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

## GraphQL test

Conventions:

- `use MyAppWeb.ConnCase, async: true` **and** `use MyAppWeb.{Endpoint}GqlCase`, together; `@moduletag :gql`.
- The GraphQL document lives next to its test, named like the operation. `load_gql_file("X.gql")` takes the filename only; the schema is inferred from the GqlCase.
- The `describe` is the `.gql` filename (#53).
- Relay input is passed as `variables: %{"input" => %{...}}`, with a string `"input"` key; authentication as `current_user:`.
- Error assertions drill into `["errors", Access.at(0), "extensions", "errorCode"]` and check that `["data", "<mutation>"]` is `nil`.

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
