# Worked example — a new feature through every layer

A user refers a friend by email: a new feature with no sibling module to copy, wired the conventional way. Adapt it to the app; it is an example, not a fill-in template. `MyApp`/`MyAppWeb` stand for the app's namespace, and rule numbers (`#15`) refer to `SKILL.md`.

The same feature continues in the files next to this one:

- `graphql.md`: its resolver, mutation type and GraphQL test.
- `testing.md`: its context and event-handler tests.
- `concurrency.md`: the Service it becomes when a second write is added, and that Service's test.
- `docs.md`: its documentation page and its place on the system map.

## Schema (`lib/my_app/accounts/referral.ex`)

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

## Sub-module (`lib/my_app/accounts/referrals.ex`)

```elixir
defmodule MyApp.Accounts.Referrals do
  @moduledoc "Referrals: a user can refer a friend by email."

  alias MyApp.Accounts.Events
  alias MyApp.Accounts.Referral
  alias MyApp.Accounts.Referrals.Query
  alias MyApp.Errors
  alias MyApp.Repo

  @doc """
  Creates a referral.

  Returns `{:ok, %Referral{}}`, `{:error, %Errors.ReferralAlreadyExistsError{}}` when this
  referrer already referred the email, or `{:error, %Ecto.Changeset{}}`.
  """
  def create_referral(attrs \\ %{}, opts \\ []) do
    attrs
    |> Referral.create_changeset()
    |> Repo.insert(success_event: Events.ReferralCreated, event_opts: opts)
    |> case do
      {:ok, referral} ->
        {:ok, referral}

      {:error, %Ecto.Changeset{errors: [{:referrer_id, {_, [{:constraint, :unique} | _]}} | _]}} ->
        {:error, Errors.ReferralAlreadyExistsError.new()}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Fetches a referral by id: `{:ok, %Referral{}}` or `{:error, %Errors.NotFoundError{}}`.

  ## Options
    * `:preloads` — associations to load. Supported: `:referrer`.
  """
  def get_referral(id, opts \\ []) when is_binary(id) do
    preloads = Keyword.get(opts, :preloads, [])

    Referral
    |> maybe_preload(preloads)
    |> Repo.get(id)
    |> case do
      %Referral{} = referral -> {:ok, referral}
      nil -> {:error, Errors.NotFoundError.new(resource_type: "Referral", resource_id: id)}
    end
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

`func` and `default_fun()` stand for the app's `Query.paginate/4` cursor plumbing: copy them from a sibling `list_*` function.

## Query module (`lib/my_app/accounts/referrals/query.ex`)

`preload/2` is called here and only here (#13, #16): one chainable function per association, which the sub-module's `maybe_preload/2` dispatches to.

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

For a **to-many** association a join would multiply the rows and break `limit` and pagination, so a separate-query preload is the right tool there: `def preload_<assoc>(q), do: preload(q, :<assoc>)`.

## Facade (`lib/my_app/accounts.ex`)

```elixir
# add alongside the other defdelegates
defdelegate create_referral(attrs, opts \\ []), to: Referrals
```

Callers outside the context use `Accounts.create_referral/2` (#2).

## Event (`lib/my_app/accounts/events.ex`)

```elixir
# add to the existing defevents list
defevents([
  # ...
  ReferralCreated
])
```

## Typed error (`lib/my_app/errors/referral_already_exists_error.ex`)

```elixir
defmodule MyApp.Errors.ReferralAlreadyExistsError do
  use MyApp.ExErrors

  defexerror(message: "You have already referred this email address")
end
```

An error that carries data lists its fields, and which are required; they surface under `extensions.fields` (#38):

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
