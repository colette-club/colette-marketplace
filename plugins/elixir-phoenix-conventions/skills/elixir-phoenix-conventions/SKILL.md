---
name: elixir-phoenix-conventions
description: Use when writing or editing Elixir/Phoenix code in any of our team's apps — any .ex or .exs file, including contexts, schemas, Ecto Query modules, changesets, GraphQL resolvers and mutations, ExEventBus events and handlers, Oban workers, and ExUnit tests.
---

# Elixir/Phoenix Conventions

## Overview

Our Elixir/Phoenix apps follow strong, consistent conventions. Code that ignores them still compiles and passes tests, but it fails review and erodes the architecture. **Before writing or editing any `.ex`/`.exs` file, check the rules below and match the surrounding code.** Examples use `MyApp`/`MyAppWeb` as placeholders for the app's namespace.

Two core principles cover most mistakes:

- **Business logic flows through a fixed shape:** facade context → namespaced sub-module → `Query` module → schema.
- **Control flow uses pattern matching, multiple function heads, `with`, and `case` — not `if/else`.**

## Highest-risk rules

These are violated most often, even when everything else is correct. Fix these first.

### 1. No `if/else` for dispatch — pattern-match instead

Map results with `case`/function heads, not `if` on the contents of an error.

```elixir
# ❌ BAD — if/else digging into changeset internals, multi-level helper
def create_referral(attrs, opts \\ []) do
  attrs
  |> Referral.create_changeset()
  |> Repo.insert(success_event: Events.ReferralCreated, event_opts: opts)
  |> case do
    {:ok, _} = ok -> ok
    {:error, changeset} -> maybe_duplicate(changeset)
  end
end

defp maybe_duplicate(changeset) do
  if duplicate_email?(changeset.errors), do: {:error, Errors.ReferralAlreadyExistsError.new()}, else: {:error, changeset}
end

# ✅ GOOD — one level of abstraction, error mapped by pattern match
def create_referral(attrs, opts \\ []) do
  attrs
  |> Referral.create_changeset()
  |> Repo.insert(success_event: Events.ReferralCreated, event_opts: opts)
  |> case do
    {:ok, referral} -> {:ok, referral}
    {:error, %Ecto.Changeset{errors: [{:referrer_id, {_, [constraint: :unique]}} | _]}} ->
      {:error, Errors.ReferralAlreadyExistsError.new()}
    {:error, changeset} -> {:error, changeset}
  end
end
```

`if` is acceptable only for a simple boolean business decision, never for type/result dispatch or anything with an `else` returning a different shape. **Never use `cond`** — express the branches as pattern-matched function heads.

When a branch is driven by a boolean predicate, don't `case` on it either — lift it into a private `maybe_<verb>/N` with `true`/`false` heads, passing the boolean as the **LAST** argument (the subject/struct leads):

```elixir
# ❌ BAD — case on a boolean predicate
case skip_moderation?(message.body, urls) do
  true -> {:ok, message}
  false -> moderate(message, urls)
end

# ✅ GOOD — boolean dispatched through maybe_*, flag is the last arg
maybe_moderate(message, urls, skip_moderation?(message.body, urls))

defp maybe_moderate(%Message{} = message, _urls, true), do: {:ok, message}
defp maybe_moderate(%Message{} = message, urls, false), do: moderate(message, urls)
```

### 2. Expose new context functions on the facade via `defdelegate`

The public API of a context is the top-level module (`MyApp.Accounts`). Callers (resolvers, workers, other code) call the **facade**, never a sub-module directly.

```elixir
# ❌ BAD — resolver reaches into a sub-module
alias MyApp.Accounts.Referrals
Referrals.create_referral(attrs, opts)

# ✅ GOOD — sub-module holds the logic, facade delegates, callers use the facade
# lib/my_app/accounts.ex
defdelegate create_referral(attrs, opts \\ []), to: Referrals

# resolver / worker / elsewhere
Accounts.create_referral(attrs, opts)
```

### 3. `import Ecto.Query` ONLY in `*/query.ex` modules

Context and sub-modules must pipe a schema through `Query.*` functions, then call `Repo.*`. Never `import Ecto.Query` (or write `where`/`from`/`order_by`/`join`) in a context module.

### 4. Use the built-in `JSON` module, never `Jason`

`JSON.encode!/1`, `JSON.decode!/1`, `@derive {JSON.Encoder, ...}`. Never `Jason.*`.

### 5. Single level of abstraction

Each function does one thing at one altitude (~10–30 lines). Extract steps into well-named `defp`s. No nested conditionals.

## Quick reference — full checklist

### A. Context architecture & layering
1. 4-tier layering: facade (`MyApp.Accounts`) → sub-module (`Accounts.Users`) → `Query` (`accounts/users/query.ex`) → schema (`Accounts.User`).
2. Facade = public API only; `defdelegate` to sub-modules. Substantial cross-context / multi-step orchestration does NOT live inline in the facade — it goes in a Service (#4).
3. Sub-modules hold CRUD/business logic; domain-named (`Users`, `Confirmations`) — never `Impl`.
4. **Keep context/sub-module functions thin** — take a struct + attrs map and apply the schema changeset (`Repo.insert/update/delete`). Anything more (a second write — which makes it a multi-step `Ecto.Multi` txn, #29 — cross-context orchestration, computation, external side effects, branching workflows) moves to a **Service object**: `MyApp.Services.*` (cross-context) or `MyApp.{Context}.Services.*` (context-scoped), with one public `run/…` (+ `opts \\ []`) — plus a `multi/1,2` when another Service composes its steps (#29), the only sanctioned second public function — `@moduledoc` stating its single responsibility, pattern-matched heads + extracted `defp`s, returning `{:ok,_}`/`{:error,_}`. **Callers invoke `Service.run(...)` directly — services are NEVER `defdelegate`d or wrapped through a facade/higher-level module.**
5. **External services/adapters** use behaviour + `Impl` + `StubImpl`/Mock, swapped via config (e.g. `Geocoding`, `PaymentProvider`, `StripeClient`). `Impl` belongs ONLY to this layer.
6. Schemas `use MyApp.Schema, :schema` (binary_id UUID PKs) — never bare `use Ecto.Schema`.
7. Changesets live in the schema module (`changeset/2` or intent-named like `archive_changeset/2`); sub-modules call them.
8. `@derive {JSON.Encoder, except: [...]}` on schemas to control field exposure.
9. Soft-delete (and other lifecycle stamps) via nullable datetime (`archived_at`/`deleted_at`/`flagged_at`/…), not DB deletes. A lifecycle mutator takes attrs — `fn(%Schema{} = struct, attrs \\ %{}, opts \\ [])` — so the **same** function both stamps and resets the field: pass `%{field: nil}` to clear it. The changeset `put_change`s the timestamp, then `cast(attrs, [field])` so attrs can override, guarded by `validate_no_override/2` (built on `validate_change`, which Ecto skips when the new value is nil — so set-when-already-set fails, but reset-to-nil succeeds).
10. Context dir layout: `context.ex`, `supervisor.ex`, `events.ex`, `event_handler/`, `services/` (Service objects), schema files, sub-module dirs each with `query.ex`.

### B. Ecto / Query / Repo
11. Query modules `use MyApp.Query` (gives `filtered_by/2`, `ordered_by/2`, `with_id(s)/2`, `paginate/4`, `count/1`).
12. Custom query functions are chainable, return queryables, with guards + a fallthrough clause (`def filtered_by(q, _), do: q`). **Build each by piping the queryable through Ecto's macro forms — `where(q, [m], …)`, `order_by/3`, `join(q, :inner, [m], t in assoc(m, :thread), as: :thread)`, `select/3`, `limit/2` — never by wrapping it in `from(...)`**, so every function stays a single composable pipe step (our query modules are overwhelmingly pipe-macro, not `from`-keyword). **For joins, prefer `assoc(m, :name)` whenever the schema declares the association** — it reuses the association's foreign-key/conditions instead of restating an `on:`; drop to an explicit `on:` only when no association exists (computed or cross-schema joins). `from(...)` is reserved for the three things the pipe forms can't express: (a) **naming the root binding** — `from(t in Thing, as: :things)` for `base/0`, or `from(q, as: :things)` inside a `has_named_binding?`/`maybe_alias_*` guard (no pipe macro attaches a root `as:`); (b) a **standalone subquery / `exists`/`not exists`** expression (`subquery(...)`, `parent_as(...)`); (c) an **`update:`/fragment atomic-write** expression.
13. `import Ecto.Query` only in `*/query.ex` (see highest-risk #3).
14. Read chain: `Schema |> Query.filtered_by(args) |> Query.ordered_by(o) |> Query.paginate(...)` / `Repo.one`.
15. Read by id through a context getter (`get_*`/`get_*!`), never `Repo.*` from outside the context — callers (resolvers, workers, other contexts) use the getter. Inside the getter, `Repo.get`/`Repo.get_by` is fine; reach for `Schema |> Query.with_id(id) |> Repo.one` when you need the Query layer's standard filters (e.g. soft-deletes).
16. **Preloads are opt-in via `opts[:preloads]`** — a list of association atoms, default `[]`; nothing is preloaded unless the caller asks (no over-fetching, no implicit N+1). A getter/list fn reads `preloads = Keyword.get(opts, :preloads, [])` and threads it through **one** private `maybe_preload/2` per module: an `is_list` head that `Enum.reduce`s the list, mapping each supported atom to a `Query.preload_<assoc>/1` call (`:referrer, acc -> Query.preload_referrer(acc)`) with a `_, acc -> acc` fallthrough, plus a second `maybe_preload(queryable, _), do: queryable` head for non-list input. The `preload/2` call itself lives ONLY in the Query module (highest-risk #3), exposed as chainable `preload_<assoc>/1` fns; atom names mirror association names; nested/keyword preloads are fine (`preload_driver/1` → `preload(q, driver: :user)`). List the supported atoms in the fn's `@doc`. **Avoid the extra DB call: for a to-one (`belongs_to`/`has_one`) association, create the binding with `with_named_binding/3` (wrapped in a chainable `with_<assoc>_binding/1` helper) and `preload` off that named binding — one round-trip, and the join is reused, never duplicated, if a filter already added it — rather than a bare `preload/2`, which fires a *second* query. Drop to the separate-query `preload/2` only when a join is the wrong tool (no choice): a to-many a join would multiply, or a `limit`/paginated query a join would break.** **Gotcha:** when the result feeds a GraphQL/JSON field that reads the struct directly (no field resolver), the caller MUST pass the needed `:preloads` or the field is `%Ecto.Association.NotLoaded{}` — opt-in preloads make this the caller's responsibility. This single list-reduce `maybe_preload/2` supersedes the old per-flag `maybe_preload_<assoc>(q, true | false)` boolean variant.
17. List queries paginate via `Query.paginate`.

### C. Idiomatic Elixir
18. No `if/else` or `cond` for dispatch (highest-risk #1); prefer function heads, guards, `case`, `with`. Boolean-predicate branches → a private `maybe_<verb>(subject, …, predicate?)` with `true`/`false` heads, boolean **last** (highest-risk #1).
19. `with` for happy-path `{:ok,_}`/`{:error,_}` chains; `else` only for error mapping.
20. Be exhaustive in `case`/`with`: enumerate the real result shapes (`{:error, X}`, `{:error, Y}`, …) explicitly so every outcome is controlled. Avoid a blanket `_ ->` that swallows unforeseen results — let an unexpected shape crash rather than be silently mishandled. (The chainable-query-builder fallthrough in #12 is the deliberate exception.)
21. **Propagate fallible results — never replace them with a hardcoded `:ok`.** When a function's final action is a fallible call (`Repo.insert/update/delete`, `Oban.insert`, or another `{:ok,_}|{:error,_}` function), return *that call's* result — don't run it for effect and then return a literal `:ok`, which swallows the failure (the caller sees success, can't retry, and transient errors vanish). Give every head the **same return shape**: a no-op/short-circuit head returns the matching `{:ok, nil}`-style tuple, not a bare `:ok`, so the whole function has one uniform `{:ok,_}|{:error,_}` contract callers can pattern-match. (Complements #20 — that bans swallowing *unforeseen* shapes; this bans swallowing a *known* fallible result.)
22. Tagged tuples `{:ok, _}`/`{:error, reason}` for fallible functions; mutation resolvers wrap in a map (`{:ok, %{user: user}}`).
23. Single level of abstraction; small functions; extract `defp`s (highest-risk #5).
24. No single-value pipes — only pipe 2+ chained calls.
25. `alias`/`import`/`require`/`@attr` at the top of the module only.
26. Naming: predicates end `?`, raising fns end `!`, snake_case fns, PascalCase modules, no abbreviations.
27. `@impl true` on all behaviour/OTP/Phoenix callbacks.
28. `@moduledoc` on every module (`false` for internal); `@doc`/`@spec` on public API.
29. **A function that performs more than one write — or one write whose value depends on a row it read first — MUST be atomic: compose the steps with `Ecto.Multi` and run them in a single `Repo.transaction/1`.** Two writes in one logical operation without a transaction is a defect even when both "always succeed": a constraint violation, a race, or a node restart between them leaves a half-applied state that no code path can produce and nothing rolls back — an orphan row, a charged card with no order, a membership pointing at a user that was never created. Counts as a write: `Repo.insert/update/delete` (and `!` variants), `insert_all`/`update_all`/`delete_all`, `insert_or_update`, and any call to a function that itself writes (a context fn, another Service).
    **Exactly one row of this table applies — find it, don't weigh it.**

    | The operation | Write it as |
    |---|---|
    | One write whose value doesn't depend on a row that could change under it | plain `Repo.insert/update/delete` in the context — no transaction |
    | One write whose value **does** depend on a row read first | `Multi`: lock step → read → write, one `Repo.transaction/1` (#55 picks which lock). The write *count* is not the trigger — the dependency is |
    | Two or more writes | `Multi`, one `Repo.transaction/1`, in a Service (#4) |
    | A write **plus its `success_event:`** | plain `Repo.*` — the wrapper (#44) already transacts the row and the event job together, so this counts as ONE write; calling it inside a Multi step is also fine, Ecto joins the enclosing transaction |
    | A write plus a side effect that must not be lost (payment capture, awaited email) | `Multi` + `Oban.insert(multi, :name, …)` — the job row commits with the write or vanishes with it. Never "after the commit": the process can die in between |
    | A write plus a fire-and-forget side effect (analytics ping, cache warm) | after the write succeeds — after `Repo.transaction/1` returns `{:ok, _}` when there is a transaction, after the `{:ok, _}` of the single write when there isn't |
    | A write plus an external call (HTTP, Stripe, mail, upload) | the call happens **before** the transaction opens or **after** it commits — never inside a step, which would hold every lock for the round-trip (#56) |
    | Reads only | no transaction |

    - **Compose, don't nest.** Build the steps and run once: `Multi.new() |> Multi.insert(:user, cs) |> Multi.update(:org, cs) |> Repo.transaction()`. Name each step for what it *produces* (`:user`, `:membership`) — a later step takes a function receiving the accumulated changes map and pattern-matches only the keys it needs: `Multi.insert(:membership, fn %{user: user} -> Membership.owner_changeset(user, org) end)`. Never hand-roll `Repo.transaction(fn -> … end)` with `Repo.rollback/1`: the function form buries the writes in nested `case`s and throws away which step failed.
    - **`Multi.run/3` for a step that isn't a plain changeset write.** Its callback MUST return `{:ok, value}` or `{:error, reason}` — any other shape raises. Use the injected `repo` (`fn repo, %{user: user} -> … end`) for raw SQL or a `Repo` call made inline in the step; calling a **context function that owns its own `Repo` access** (#15) is equally correct and preferred — it runs on the same connection inside the same transaction, and threading a repo argument through getters would break the layering. The injected `repo` is load-bearing only where the app runs multiple or dynamic repos.
    - **Map the 4-tuple back to the standard contract.** `Repo.transaction/1` returns `{:ok, %{step => value}}` or `{:error, failed_step, failed_value, changes_so_far}` — **not** the `{:ok,_}`/`{:error,_}` of #22. Convert it in a `case`: match the failing step by name wherever the mapping differs per step (the step name is exactly what a typed error, #38, needs); a single `{:error, _step, reason, _changes}` clause is right when every step already returns a typed error and there is nothing step-specific to add. What's banned is losing the failure — flattening it to `:ok`, `nil`, or a generic string (#21).
    - **Events stay on the write.** Pass `success_event:`/`event_opts:` as the step's opts — `Multi.insert(:referral, cs, success_event: Events.ReferralCreated, event_opts: opts)` — it is the same `Repo` wrapper as #44, and because the event is an Oban job row it is enqueued inside the transaction and rolls back with it, so a write that didn't stick never emits.
    - **It lives in a Service.** Needing a Multi is the signal that the operation outgrew the context (#4): sub-modules keep their one-changeset-one-write functions, and the Service's `run/…` composes them.
    - **Compose Multis across Services — NEVER nest `Repo.transaction`.** A Service that another Service will reuse exposes **two** public functions (the sanctioned exception to #4's single `run/…`): `multi/1,2`, which takes a Multi and adds its steps, and `run/…`, which is just the transaction boundary for direct callers. The composer appends the callee's steps into its own Multi, so there is exactly one transaction:

      ```elixir
      # callee — steps only, no Repo.transaction
      def multi(multi \\ Multi.new(), attrs), do: Multi.insert(multi, :membership, changeset(attrs))
      def run(attrs), do: Multi.new() |> multi(attrs) |> Repo.transaction() |> case do … end

      # composer — one transaction covering both Services
      Multi.new() |> Multi.insert(:user, cs) |> CreateMembership.multi(attrs) |> Repo.transaction()
      ```

      Nesting instead — a `Multi.run` step calling a Service whose `run/…` opens its own transaction — is not an isolated inner transaction: Ecto joins it to the outer one, and it fails in three ways that all look correct at the call site. (a) The inner rollback **aborts the outer transaction**, so the next statement raises `** (Postgrex.Error) ERROR 25P02 (in_failed_sql_transaction)` — an "if the inner fails, do this instead" branch is unreachable code that crashes instead of recovering. (b) The outer then returns `{:error, :rollback}`, carrying none of the inner's typed error (#38). (c) Worst: the callee's post-commit work — the `{:ok, _}` branch where it sends the mail or treats the write as durable (#29's table) — silently becomes **pre**-commit work, because a callee cannot know it was nested. Ecto's own docs say the same: avoid nested transactions, compose with `Ecto.Multi`.

    ```elixir
    # ❌ BAD — two writes, no transaction: a failed membership leaves an orphan user behind
    def create_org_owner(attrs, org) do
      {:ok, user} = Users.create_user(attrs)
      {:ok, _membership} = Memberships.create_membership(user, org, :owner)
      {:ok, user}
    end

    # ✅ GOOD — one transaction, named steps, 4-tuple mapped back to {:ok,_} | {:error,_}
    defmodule MyApp.Accounts.Services.CreateOrgOwner do
      @moduledoc "Creates a user and their owner membership for an org, atomically."

      alias Ecto.Multi
      alias MyApp.Accounts.Events
      alias MyApp.Accounts.Membership
      alias MyApp.Accounts.User
      alias MyApp.Errors
      alias MyApp.Orgs.Org
      alias MyApp.Repo
      alias MyApp.Workers.WelcomeEmailWorker

      def run(attrs, %Org{} = org, opts \\ []) do
        Multi.new()
        |> Multi.insert(:user, User.create_changeset(attrs),
          success_event: Events.UserCreated,
          event_opts: opts
        )
        |> Multi.insert(:membership, fn %{user: user} -> Membership.owner_changeset(user, org) end)
        |> Oban.insert(:welcome_email, fn %{user: user} ->
          WelcomeEmailWorker.new(%{"user_id" => user.id})
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{user: user}} ->
            {:ok, user}

          {:error, :user, changeset, _changes} ->
            {:error, changeset}

          {:error, :membership, _changeset, _changes} ->
            {:error, Errors.MembershipCreationFailedError.new()}

          {:error, :welcome_email, _changeset, _changes} ->
            {:error, Errors.JobEnqueueFailedError.new()}
        end
      end
    end
    ```
30. Context fn names: `list_*`, `get_*`, `create_*`, `update_*`, `delete_*`, `count_*`.
31. Use the built-in `JSON` module, never `Jason` (highest-risk #4).
32. **Take an id, not a struct, when you only need the id.** A function that reads only `entity.id` should accept the bare id (`binary`), not force callers to load and pass the whole struct (needless DB reads at call sites that already hold the id). When some callers hold the full struct and others only the id, overload generically — a `%Schema{id: id}` head delegating to the id head: `def f(%Schema{id: id}, x), do: f(id, x)` then `def f(id, x) when is_binary(id), do: …`.
33. **Bind a computed value to a variable before placing it in a map/struct/keyword list.** Don't inline a function call as a map/struct/keyword *value* — assign it to a well-named variable first, then reference that variable, so the data literal stays a flat, scannable shape and the value carries a name. E.g. `member_wish_ids = unserved_wish_ids_for_cluster(id)` above the map, then `%{cluster_id: id, member_wish_ids: member_wish_ids}` — not `%{cluster_id: id, member_wish_ids: unserved_wish_ids_for_cluster(id)}`.

34. **Access maps and keyword lists through their module functions — `Map.get/2,3`, `Map.fetch/2`, `Map.fetch!/2`, `Map.put/3`, `Map.merge/2`, `Map.update/4`, … and `Keyword.get/2,3`, `Keyword.fetch/2`, `Keyword.fetch!/2`, `Keyword.put/3`, … — never bracket/`Access` syntax (`attrs[:x]`, `opts[:x]`).** Bracket access silently returns `nil` for a missing key (erasing the missing-vs-`nil` distinction) and breaks on structs; the module functions are explicit and uniform. Use `fetch!` when the key MUST be present, `get/3` with an explicit default when it's optional. Destructuring in a function head or `with`/`case` pattern (`def build(%{user_id: id, text: text})`) is equally good and often clearer — the ban is specifically the `x[:key]` Access idiom, not pattern matching. Nested access still uses `get_in`/`put_in`/`update_in`.

### D. GraphQL / web layer
35. Schema split per endpoint/audience (e.g. `/api`, `/admin`); shared types/middleware under `api/shared/`.
36. Naming: `MyAppWeb.Api.{Endpoint}.Resolvers.{Domain}.{Name}`, `.Schema.{Queries,Mutations,Types,Middlewares}.…`.
37. Resolvers return tagged tuples, use `with` chains; auth via middleware (entry) + resolver (business rules).
38. Typed errors: `MyApp.Errors.*` with `use MyApp.ExErrors` + `defexerror`; return `{:error, Errors.X.new(...)}` — not raw strings. **Define-then-return: the error module must exist in the project** (`lib/my_app/errors/<name>_error.ex`); before returning `Errors.X.new(...)`, create `Errors.X` if it doesn't exist — never reference an undefined error module. Errors may carry structured fields — `defexerror([:resource_type, :resource_id, message: "..."], required_fields: [:resource_type])` — which surface in the GraphQL response under `extensions.fields` alongside `extensions.errorCode`.
39. Global middleware `SafeResolution.apply(…) ++ [ErrorHandler]` normalizes errors to `extensions.errorCode`.
40. Mutations use `payload field` with `input`/`output`; apply auth middleware inline.
41. Pass event metadata (`EventMetadata.build_opts(res)`) from resolvers into context functions.
42. Nested lists via a Dataloader-backed connection (`Dataloader.Ecto`) — avoid N+1 in GraphQL.

### E. Events & workers
43. Eventing is the **`ex_event_bus` hex dependency** (Oban-backed, exactly-once delivery). The bus module is `MyApp.EventBus` (`use ExEventBus, otp_app: :my_app`); events live in `MyApp.{Context}.Events` via `use ExEventBus.Event` + `defevents([...])`. Every `ex_event_bus` `use` macro **requires** its option (`otp_app:` or `ex_event_bus:`) and raises `ArgumentError` at compile time without it.
44. Emit on success: `Repo.insert/update/delete(cs, success_event: Events.X, event_opts: opts)`; functions take `opts \\ []`. `Repo` accepts `success_event:`/`event_opts:` only because it does `use ExEventBus.EctoRepoWrapper, ex_event_bus: MyApp.EventBus` — that wrapper publishes the event when the write succeeds.
45. Handlers `MyApp.{Context}.EventHandler.{Name}`: `use ExEventBus.EventHandler, ex_event_bus: MyApp.EventBus, events: ["Elixir.MyApp.{Context}.Events.{Name}"]` (both options required), implement `handle_event/1` (returns `:ok | {:ok, any} | :error | {:error, any}`), pattern-match aggregate/changes (string keys — JSON round-trip), enqueue via `Oban.insert()`.
46. Handler supervision: `EventHandler` delegates `child_spec` to its `Supervisor` (`:one_for_one`).
47. **Cross-context communication MUST go through events** for decoupled reactions; the one exception is a Service (#4) orchestrating a synchronous cross-context transaction. Otherwise direct calls only within a context.
48. Workers in `lib/my_app/workers/`: `use MyApp.Worker` + `use Oban.Worker, queue:, max_attempts:`, `@impl` `perform(%Oban.Job{args: %{"k" => v}})`, return `:ok`/`{:error}`/`{:cancel}`/`{:snooze}`; add `tags:`.

### F. Testing
49. Case templates: `MyApp.DataCase` (contexts/changesets), `MyAppWeb.ConnCase` (HTTP), `*GqlCase` (GraphQL).
50. Factories: ExMachina `{name}_factory`, `insert/2` over `build/2`, `sequence/2` for uniqueness.
51. Mocking: Mox with behaviours, `defmock` centralized in `test_helper.exs`, `setup [:set_mox_from_context, :verify_on_exit!]`.
52. Event testing: `use ExEventBus.Testing, ex_event_bus: MyApp.EventBus` (the `ex_event_bus:` option is required) — gives `assert_event_received(Events.X, args: …)`, `refute_event_received/2`, `all_received/1`, and `execute_events/0,1`. Events are Oban jobs on the `:ex_event_bus` queue, so `assert_event_received` is `Oban.Testing.assert_enqueued` under the hood, and `execute_events()` *drains* that queue to actually run the handlers — assert on its result: `assert %{success: 1, failure: 0} = execute_events()`, or scope it with `execute_events(event_handler: MyApp.{Context}.EventHandler.{Name})`. Worker testing: `use Oban.Testing`, `perform_job/2`, `assert_enqueued/1`.
53. **One `describe` block per function — and exactly one function per `describe`.** Name it `describe "fun/arity"` after the function under test; every `test` inside exercises *that* function only. Never group several functions under one `describe`, and never split a single function's tests across multiple `describe`s — it's one function ↔ one `describe`. Tests read `test "when <condition>"`; `async: true` for pure tests; `setup` **only** for harness wiring — Mox mode, `conn`, sandbox — never the entities the test asserts against, which are built inside the `test` body (#54); GraphQL via `query_gql(...)` + `load_gql_file` (there the `describe` names the `.gql` file — a single operation, the same one-thing-per-`describe` rule).
54. **Self-contained tests — arrange the data under assertion inside the test body.** A test must be understandable on its own: everything that drives the assertion — the input data *and* the expected values — is visible in the `test` block. A reader should never scroll up to a `setup` block, a module attribute, or a shared fixture to learn what is under test or why the assertion holds. Concretely:
    - **Build the domain data each test needs inside that test** (`insert(:user)`, explicit attrs), passing the fields the assertion depends on explicitly and inline. Don't hoist entity creation into `setup` and inject it via context (`test "...", %{referrer: referrer}`) — that hides what matters and forces every test in the block to carry data it may not need. Where sibling tests cover different outcomes, let the **fixture that varies** be the only thing that differs between them (`invites_remaining: 1` vs `0`) — the cause of each outcome is then visible in the diff between the two tests.
    - **Reserve `setup` for test-harness wiring that is never the subject of an assertion** — Mox mode (`set_mox_from_context`, `verify_on_exit!`), a `conn`, sandbox/config, a feature flag. Never for the entities the test asserts against. Even a justified `setup` rots: fixtures accrete as tests are added and their consumers scatter across the module, so nothing ever *looks* unused — stale state that #58 can't catch, because no single edit reveals it.
    - **No module attributes for shared test data or "magic" attrs** (`@valid_attrs`, `@user_id`) — inline the literal values so the input↔assertion relationship reads top to bottom in one place.
    - **Prefer duplication over indirection.** The question is never "how do I remove every repeated line?" — it's "how much context does someone need to understand this test?" A few repeated `insert(:user)` lines are fine; WET-over-DRY in tests buys locality. When repetition genuinely hurts, extract a **named helper the test calls** (visible in the body) — a factory (#50) or a small `defp unavailable_product/0` that names a domain intent. The distinction that decides it: **a helper runs because the test calls it; a `setup` runs because the test happens to live in that module.**
    - The payoff: each test reads as one Arrange–Act–Assert story and stays independent — deletable, movable, and reviewable in isolation. It also survives being read **detached from its file** — quoted in a PR comment, pasted into an agent's context, dropped into a CI failure report — which is where most tests are actually read now. Reinforces the factory-in-test style of #50 and complements the one-function-per-`describe` rule of #53.

    ```elixir
    # ❌ BAD — data and expectations hoisted out of the test; the reader must scroll away to understand it
    describe "create_referral/2" do
      @attrs %{email: "friend@example.com"}

      setup do
        %{referrer: insert(:user)}
      end

      test "creates a referral", %{referrer: referrer} do
        assert {:ok, referral} = Accounts.create_referral(Map.put(@attrs, :referrer_id, referrer.id))
        assert referral.email == @attrs.email
      end
    end

    # ✅ GOOD — each test carries its own arrange and its own expected values;
    # the siblings differ only in the fixture that drives the outcome
    describe "create_referral/2" do
      test "when the referrer has invites left" do
        referrer = insert(:user, invites_remaining: 1)

        assert {:ok, referral} =
                 Accounts.create_referral(%{referrer_id: referrer.id, email: "friend@example.com"})

        assert referral.email == "friend@example.com"
      end

      test "when the referrer is out of invites" do
        referrer = insert(:user, invites_remaining: 0)

        assert {:error, %Errors.NoInvitesRemainingError{}} =
                 Accounts.create_referral(%{referrer_id: referrer.id, email: "friend@example.com"})
      end
    end
    ```

### G. Concurrency & locking
55. **Concurrent access to a shared resource: choose by what you are protecting, then by cost.** The table is the short answer; the rungs below it carry the detail. Every rung down costs more contention and more deadlock surface, so drop to it only when the one above can't express the rule. The default is rung 1 — most "we need a lock here" problems are a read-modify-write that shouldn't exist.

    | What you're protecting | Use | Not |
    |---|---|---|
    | A counter / balance / stock on one row | atomic `update_all(inc:)`, guard in the `where` | `get` → compute → `update` |
    | A row that may or may not exist yet | unique index + `on_conflict` upsert | `if get_by(...), do: update, else: insert` |
    | A user-facing edit that must not clobber a newer one | `optimistic_lock(:lock_version)` | a row lock held across human time |
    | A decision read from rows you then write | `FOR UPDATE` as the first step *inside* the Multi | reading first, locking later (or never) |
    | Something with **no row to lock yet** — get-or-create, replace-a-set, one-external-call-per-key | `pg_advisory_xact_lock` | session-scoped `pg_advisory_lock` + manual unlock |
    | Work that is already async | Oban `unique:` on the worker | any lock at all |

    When two rows of that table both look plausible, the tiebreaker is a single question — answer it, don't weigh it:

    | Torn between | Ask | Take |
    |---|---|---|
    | optimistic lock vs `FOR UPDATE` | Is the read→write gap inside one request? | inside → `FOR UPDATE`; spanning human time or two requests → `optimistic_lock` |
    | `FOR UPDATE` vs advisory | Is the row you'd lock a row you are writing? | yes → `FOR UPDATE` on it; no (you'd lock a parent to guard a child that doesn't exist yet) → `pg_advisory_xact_lock` keyed on the tuple |
    | advisory vs unique index | Would the duplicate violate a constraint? | the index goes in either way; add the advisory lock only to keep the racing pair off it |
    | Oban `unique:` vs a lock | Does a later job carry fresher data than the running one? | yes → exclude `:executing` **and** take the row lock in the job (mandatory pair); no → include `:executing`, no lock needed |

    1. **One atomic statement — no lock, no transaction.** A counter, balance, or stock change is `Repo.update_all(query, inc: [credits: -1])` (or an `update:` fragment, #12), never `get` → compute in Elixir → `update`: two concurrent read-modify-writes both read the same value and the second silently erases the first (a lost update), *including* inside a transaction. Make the guard part of the statement — `Product |> Query.with_id(id) |> Query.with_stock_at_least(1) |> Repo.update_all(inc: [stock: -1])` — and branch on the affected-row count it returns (`{1, _} -> :ok`, `{0, _} -> {:error, Errors.OutOfStockError.new()}`), which is the check and the write in one indivisible step.
    2. **A unique index + upsert.** `Repo.insert(cs, on_conflict: :nothing | {:replace, [...]}, conflict_target: [:user_id, :day])` — never `if get_by(...), do: update, else: insert`, whose check-then-act window is a race two requests will hit. The index is the guarantee; keep `unique_constraint/3` on the changeset and pattern-match `{:error, changeset}` for the user-facing error (highest-risk #1). Uniqueness that isn't backed by a DB index does not exist. The same goes for any "only if not already set" rule (a one-shot stamp like `frozen_at`, a state transition): a changeset validation comparing against the **in-memory** struct is a check-then-act on a snapshot — two concurrent callers both read `nil`, both pass, both write. Put the condition in the statement (`update_all` with `where: is_nil(field)`, branch on the affected-row count) or in a partial unique index; keep the changeset validation for the friendly error message only.
    3. **Optimistic locking** — `Ecto.Changeset.optimistic_lock(:lock_version)` for user-facing edits where conflicts are rare and the stale writer must lose. `Repo.update` then raises `Ecto.StaleEntryError`; rescue it at the Service boundary and return a typed error (#38). Nothing is held, so nothing can deadlock — the right default for long "load form → user edits → submit" cycles, where a row lock would be held across human time.
    4. **Pessimistic row lock** — `FOR UPDATE`, only when a decision must *read* rows and be the sole actor on them until it writes (e.g. re-check a balance, then debit it). It goes inside the Multi (#29), never around one; `lock/2` is an `Ecto.Query` macro, so it lives in `query.ex` as chainable `for_update/1` and `for_update_nowait/1` helpers (#13) — the `nowait` one is what a request path uses (#56), and the locked set must be the narrowest one that satisfies the rule. Prefer `FOR NO KEY UPDATE` when the update touches no key column (it doesn't block inserts that reference the row), and `FOR UPDATE SKIP LOCKED` to hand rows out of a queue-shaped table with no waiting at all. **A row lock is only as good as its weakest writer:** it serializes the transactions that *take* it, so every writer of those columns must lock and re-read inside the transaction. One writer that computes from a struct loaded earlier — above all one loaded before an HTTP call — still commits stale-derived data over the top, last-write-wins. When you add the lock, say in the `@moduledoc` which writers are expected to contend, and make the read that feeds the write happen *after* the lock, never before.
    5. **Transaction-scoped advisory lock — the tool for "there is no row to lock yet".** Its three shapes: a **get-or-create** (two callers both miss the read, both insert), **replacing a whole set for a key** (each deletes nothing, each inserts, the key ends up holding the union of the racing sets), and **one-external-call-per-key** ("a single payout run / payment intent per user at a time"). Take it as the *first* `Multi.run` step, keyed on the domain id: `SQL.query(repo, "SELECT pg_advisory_xact_lock($1, hashtext($2)::int)", [@lock_class, key])`. Four rules:
        - **Always the `_xact_` variant.** Session-scoped `pg_advisory_lock` paired with a manual unlock step is a leak waiting to happen: a rollback does **not** release a session lock, so any failing step between lock and unlock skips the unlock, and the connection returns to the pool still holding it — every later caller on that key blocks until that connection is recycled. `_xact_` releases on commit *and* rollback and needs no unlock step (so there is also no `:unlock` step to get skipped).
        - **Namespace the key.** The advisory keyspace is one global integer space per database, shared by every subsystem. Use the two-argument `(classid, objid)` form, and take `classid` from **one module that owns every constant** (`MyApp.LockClasses`, one `@doc`'d value per use case) — a "pick a constant per module" convention guarantees two modules eventually pick the same integer and block each other silently, which is the exact failure this rule exists to prevent.
        - **On a request path, don't queue — `pg_try_advisory_xact_lock`** returns `false` immediately instead of waiting; map that to a typed "already in progress" error (#38). Reserve the blocking form for background/worker code.
        - **The lock is not the guarantee.** The unique index (rung 2) still enforces the invariant; the advisory lock only keeps the racing pair from reaching it. And nothing external runs while it is held (#29) — an HTTP call inside an advisory lock holds a connection *and* a global lock for the round-trip.
    6. **Serialize upstream instead.** When the work is already async, Oban `unique:` options (or a dedicated low-concurrency queue) stop the duplicate from ever being enqueued — cheaper than every lock above, because nothing contends. Scope `states:` deliberately: excluding `:executing` means a job that arrives while one is running still gets enqueued, which is what you want when the new job carries fresher data — the in-flight one is then serialized by the row lock, not by uniqueness.
    - **Never build an in-app mutex.** A `GenServer`/`Agent` that serializes DB writes is a single-node bottleneck that silently stops guaranteeing anything the moment a second node boots (and a single-process choke point under load). Shared-state invariants belong to the database, which is the only thing every node agrees on.
56. **Deadlocks: one house order for taking locks, short transactions, and the loser retries the whole thing.** A deadlock is two transactions taking the same locks in opposite order, so the fix is a total order — the same one everywhere, not a per-Service choice:

    | You touch | Take them in this order |
    |---|---|
    | Several rows of one table | ascending `id` — `Enum.sort()` the ids before locking or writing, plus a matching `order_by`. Never the order your business logic happened to produce (a computed sequence differs between two transactions, which IS the deadlock) |
    | A parent and its children | **parent first**, then children by ascending id — the house order, in every Service |
    | Two or more tables | the same parent-before-child direction; if there's no parent relation, alphabetical by table name |
    | A lock another transaction already holds | worker: block, and let Oban retry the **whole** transaction on `40P01`/`40001` (#48). Request path: `Query.for_update_nowait/1` → `%Postgrex.Error{postgres: %{code: :lock_not_available}}` → a typed "busy" error (#38), so a user never waits on a lock |

    - **Keep the transaction short.** Reads, computation, and validation happen *before* it opens; acquire the lock as late as possible and commit as soon as the writes are done. Nothing external inside (#29) — an HTTP call inside a lock multiplies the lock's duration by the network.
    - **Retry the whole transaction, never part of it.** Postgres aborts one side with `%Postgrex.Error{postgres: %{code: :deadlock_detected}}` (`40P01`) or `:serialization_failure` (`40001`); the entire Multi must run again. Never rescue either into an `{:error, _}` the caller reads as a business rule failing.
    - **Lock only what a concurrent writer would corrupt.** A blanket `FOR UPDATE` on a parent row to "be safe" serializes every child write behind it — that isn't safety, it's a queue with extra steps and a deadlock partner.

    ```elixir
    # ❌ BAD — read-modify-write: two concurrent redemptions both read 5, both write 4, one credit vanishes.
    # (Adding a transaction around this does NOT fix it — only a lock or an atomic statement does.)
    def redeem_credit(%User{} = user) do
      user
      |> User.changeset(%{credits: user.credits - 1})
      |> Repo.update()
    end

    # ✅ GOOD — the check and the decrement are one indivisible statement; no lock, no transaction
    def redeem_credit(user_id) when is_binary(user_id) do
      User
      |> Query.with_id(user_id)
      |> Query.with_credits_at_least(1)
      |> Repo.update_all(inc: [credits: -1])
      |> case do
        {1, _} -> :ok
        {0, _} -> {:error, Errors.NoCreditsRemainingError.new()}
      end
    end

    # ❌ BAD — a transfer locking rows in call order: two opposite transfers deadlock on each other
    Multi.new()
    |> Multi.run(:from, fn repo, _ -> {:ok, repo.one(Query.for_update(Query.with_id(Account, from_id)))} end)
    |> Multi.run(:to, fn repo, _ -> {:ok, repo.one(Query.for_update(Query.with_id(Account, to_id)))} end)

    # ✅ GOOD — one lock step, ids sorted into a total order, so no two transfers can interleave badly
    Multi.new()
    |> Multi.run(:lock_accounts, fn repo, _ ->
      accounts =
        Account
        |> Query.with_ids(Enum.sort([from_id, to_id]))
        |> Query.ordered_by(:id)
        |> Query.for_update()
        |> repo.all()

      {:ok, Map.new(accounts, &{&1.id, &1})}
    end)
    ```

57. **Test the invariant, never the interleaving.** Two transactions cannot contend inside the ExUnit sandbox — every process shares one connection inside one enclosing transaction — so a `Task.async` pair "racing" in a test proves nothing: it either deadlocks the checkout or runs sequentially and passes for the wrong reason. A green test that cannot fail on the bug it names is worse than no test. Test what the sandbox *can* prove, and say plainly what it can't:

    | What the code claims | The test that proves it |
    |---|---|
    | The operation is atomic (#29) | Force the **last** step to fail (so every earlier write has already been applied) and assert nothing landed: the row is unchanged, `Repo.aggregate(Other, :count) == 0`, `refute_enqueued(worker: …)`, and `refute_event_received(Events.X)` (#52) — a rolled-back write must not emit |
    | The guard is in the statement, not in Elixir (#55 rung 1) | Call it at the boundary — stock `1` → `{:ok, _}`, stock `0` → the typed error — and assert the row did not move on the failing call |
    | The upsert / unique index holds (#55 rung 2) | Run the operation twice with the same key; assert one row and the second call's documented result. This is the test that fails loudly when the migration's index is missing |
    | The row lock is taken (#55 rung 4) | A `query.ex` unit test on the chainable: `Query.for_update/1` produces SQL containing `FOR UPDATE` |
    | The advisory lock is taken, on the right key (#55 rung 5) | Attach a `:telemetry` handler to `[:my_app, :repo, :query]` inside the test, run the operation, and `assert_received` the `pg_advisory_xact_lock` statement **with the expected params**. Match on the params, not just the statement — the handler is global and other async tests take advisory locks of their own — and detach in an `after` block |
    | Duplicate work is suppressed (#55 rung 6) | Enqueue twice, `assert_enqueued` once (`Oban.Testing`, #52) |
    | The interleaving itself | Nothing here can. Say so in a comment on the `describe` — "serialisation is verified by inspection; the sandbox shares one connection" — so the next reader doesn't mistake the coverage. A genuine two-connection test is `async: false`, `@tag :integration`, checks out a second non-sandboxed connection, cleans up after itself, and stays out of the default `mix test` run |

### H. Change hygiene
58. **After editing — above all after removing logic — re-read the code you touched and, in the SAME change, delete whatever the edit made pointless.** A helper collapsed to `x -> x` gets inlined at its lone call site and removed; a now-unreachable clause and an unused `@attr` get deleted. Comments must stay **useful and current**: drop any that no longer matches the code, and never keep or write one that narrates what the code *used to be* or *used to do* — that history belongs in git, and a backward-looking comment is dead weight that misleads the next reader. Leave no dead scaffolding behind. (Keeps the single-level-of-abstraction discipline of #5/#23 intact edit-over-edit.)

## Canonical examples

`reference.md` in this skill is a full worked example — a new feature wired through every layer. The conventional home for each pattern (with `my_app` standing in for the app):

- Layering + facade delegation: `lib/my_app/<context>.ex`, `lib/my_app/<context>/<sub_module>.ex`
- Service object (`run/…` = the transaction boundary, plus `multi/1,2` when another Service composes its steps, called directly): `lib/my_app/services/<name>.ex` or `lib/my_app/<context>/services/<name>.ex`
- Query module (`use MyApp.Query`) — including every `lock`/`for_update` and guard clause used for concurrency (#55): `lib/my_app/<context>/<sub_module>/query.ex`
- Events / handlers: `lib/my_app/<context>/events.ex`, `lib/my_app/<context>/event_handler/<name>.ex`
- Typed error: `lib/my_app/errors/<name>_error.ex`
- Resolver / mutation: `lib/my_app_web/api/<endpoint>/resolvers/<domain>/<name>.ex`, `.../schema/mutations/<domain>/<name>.ex`
- Oban worker: `lib/my_app/workers/<name>.ex`

## Red flags — stop and reconsider

- About to write `if ... do ... else` → use pattern matching / `case` / function heads.
- About to write `cond do` → use pattern-matched function heads (struct/guard patterns; dispatch any leftover boolean through a `maybe_<verb>` helper with the boolean last).
- About to `case` on a boolean predicate → extract `maybe_<verb>(subject, …, predicate?())` with `true`/`false` heads (boolean **LAST**).
- About to write a blanket `_ ->` in a `case`/`with` → enumerate the real result/error shapes instead, so nothing unexpected is silently swallowed (chainable query fallthroughs in #12 excepted).
- A function ending in a fallible call (`Repo.*`, `Oban.insert`, an `{:ok,_}|{:error,_}` fn) followed by a hardcoded `:ok` — or whose no-op head returns a bare `:ok` while the real head returns a tuple → return the fallible call's result; give every head the same `{:ok,_}|{:error,_}` shape so the failure can't be silently dropped.
- About to `import Ecto.Query` (or `where`/`from`/`order_by`) outside a `query.ex` → move it to the Query module.
- A `query.ex` function wrapping the queryable in `from(...)` for a plain filter/order/join/select → pipe it through the macro form (`where/3`, `order_by/3`, `join/5`, `select/3`). `from(...)` is only for naming the root binding (`from(q, as: :x)`), a standalone subquery/`exists` (`subquery`/`parent_as`), or an `update:`/fragment write (#12).
- A `join` restating an `on:` foreign-key condition for an association the schema already declares → use `assoc(m, :name)` instead (`join(q, :inner, [m], t in assoc(m, :thread), as: :thread)`); reserve explicit `on:` for joins with no declared association (#12).
- An unconditional `with_<assoc>_preload`/inline `preload/2` in a context or sub-module, or a `case`/`if` per preload flag → thread `opts[:preloads]` (a list of atoms) through one private `maybe_preload/2` that `Enum.reduce`s the list to `Query.preload_<assoc>/1` calls; keep the `preload/2` itself in the Query module (#16, highest-risk #3).
- A to-one (`belongs_to`/`has_one`) preload written as a bare `preload/2` (a *second* query) when it could load in the same query → create the binding with `with_named_binding/3` and `preload` off it (one query, join reused not duplicated); reserve the separate-query `preload/2` for to-many associations or paginated queries a join would break (#16).
- A resolver/worker calling `Context.SubModule.fn(...)` → call the facade; add a `defdelegate`.
- A resolver/worker/another context reading via `Repo.get`/`Repo.get_by` (or any `Repo.*`) → call the context getter (`get_*`) instead. (`Repo.get`/`Repo.get_by` inside the getter itself is fine.)
- Typing `Jason` → use `JSON`.
- `attrs[:x]` / `opts[:x]` (a bracket/`Access` read on a map or keyword list) → use `Map.get`/`Map.fetch!` or `Keyword.get`/`Keyword.fetch!`, or destructure in the function head; `get_in`/`put_in` stay reserved for nested access (#34).
- A new public context function not exposed on the facade.
- A function over ~30 lines or mixing abstraction levels → extract `defp`s.
- A just-edited change left a now-trivial wrapper (`defp f(x), do: x`), an unreachable clause, an unused `@attr`, or a stale/backward-looking comment (one describing what the code *used to be*) behind → inline/remove it in the same change; re-check what your edit made pointless (#58).
- A function taking a full `%Schema{}` but reading only `.id` → accept the id directly; if some callers hold the struct, add a `%Schema{id: id}` head that delegates to the id head (avoids needless DB loads at call sites that already have the id).
- A map/struct/keyword literal with a function call inline as a value → bind it to a named variable above the literal first, then reference the variable (keeps the shape scannable and names the value).
- A context/sub-module fn doing more than changeset + `Repo` write (multi-step `Ecto.Multi`, cross-context calls, computation, external side effects) → extract a **Service** (`MyApp.Services.*` / `{Context}.Services.*`), called directly — don't bloat the context or route it through the facade.
- **Two writes in one function with no transaction** — two `Repo.insert/update/delete`/`*_all` calls, or one write plus a call to another writing function/Service — **or one write whose value came from a row read earlier in the function** → compose the steps with `Ecto.Multi` and run one `Repo.transaction/1` in a Service; map the `{:error, step, value, changes}` 4-tuple back to `{:ok,_}|{:error,_}` (#29 — match the step by name only where the mapping differs per step). "The second one can't realistically fail" is not an argument — a constraint, a race, or a restart makes it fail, and there is nothing to undo the first.
- `Repo.transaction(fn -> … end)` with `Repo.rollback/1` inside a `case` → rewrite as a named-step `Ecto.Multi` (#29).
- A `Multi.run` step (or any code inside a transaction) calling a Service whose `run/…` opens its **own** `Repo.transaction` → expose the callee's steps as `multi/1,2` and append them into the caller's Multi. Ecto joins the nested call to the outer transaction: the inner rollback aborts the outer (the next statement raises `25P02`), the outer returns `{:error, :rollback}` stripped of the inner's typed error, and the callee's post-commit work runs *pre*-commit because it can't tell it was nested (#29).
- A test spawning `Task.async` pairs to "prove" two transactions serialise → the sandbox shares one connection, so it deadlocks or passes for the wrong reason. Assert the invariant instead — rollback leaves nothing (`refute_enqueued`/`refute_event_received` included), and the lock statement was issued with the expected key — and note in the `describe` that the interleaving is verified by inspection (#57).
- An HTTP call, email, payment capture, or upload inside a `Multi.run` step → take it out: if losing it would be a defect, enqueue an Oban job as a Multi step (`Oban.insert(multi, :notify, …)`); only a fire-and-forget effect may run after the commit (#29's table decides which).
- A counter/balance/stock updated by `get` → compute → `update` (even inside a transaction) → one atomic `Repo.update_all(query, inc: [field: n])` with the guard in the `where` and a branch on the affected-row count; lost updates need no lock, they need one statement (#55).
- `if get_by(...), do: update, else: insert` (check-then-act) → unique index + `on_conflict`/`conflict_target` upsert, `unique_constraint/3` on the changeset for the error path (#55).
- `lock("FOR UPDATE")` written outside a `query.ex`, wrapped *around* a Multi instead of inside it, or taken on ids in an order that varies per code path → chainable `Query.for_update/1`, inside the transaction, on a sorted id list — varying lock order IS the deadlock (#55, #56).
- A session-scoped `pg_advisory_lock` released by an explicit unlock step → `pg_advisory_xact_lock` (or `pg_try_*` on a request path): a rollback does not release a session lock, the unlock step never runs when an earlier step fails, and the connection goes back to the pool still holding it (#55).
- An advisory lock (or a `validate_*` on the in-memory struct) standing in for a DB constraint → add the unique/partial index, or put the condition in the `where` of the write; the lock only keeps the racing pair off the guarantee, it isn't the guarantee (#55).
- A writer of a column that another transaction locks `FOR UPDATE`, building its changeset from a struct loaded earlier (worse: before an HTTP call) → lock and re-read inside the transaction; a row lock only serializes the writers that take it (#55).
- A `GenServer`/`Agent` introduced to serialize DB writes → use the database's guarantee (atomic statement, unique index, row or advisory lock); an in-app mutex stops guaranteeing anything on a second node (#55).
- A domain create/update/delete without `success_event:`.
- One context calling another context's functions directly → emit an event instead (the exception is a Service orchestrating a synchronous transaction).
- A new error returned as a raw string, or `{:error, Errors.X.new(...)}` where `Errors.X` isn't defined → define the `MyApp.Errors.*` module first (define-then-return); never reference an undefined error module.
- A test `describe` block covering more than one function — or a single function's tests scattered across several `describe`s → one `describe` per function, named `"fun/arity"` and exercising only that function (#53).
- A test whose data or expected values live outside the `test` block — an entity created in `setup` and injected via context, a `@valid_attrs`/`@user_id` module attribute, a value asserted against something computed off-screen → arrange the entities under assertion inside the test body with explicit inline attrs and inline the expected literals; keep `setup` for harness wiring only (Mox/conn/sandbox), and if duplication hurts extract a *called* helper/factory, never an implicit `setup` (#54). Quick test: paste the `test` block alone into a PR comment — if a reviewer can't tell why it passes, it isn't self-contained.

## Also enforced mechanically

`mix format --check-formatted && mix credo --strict && mix test` must pass before commit. Some rules here (alias/attr placement, `Jason` usage, `import Ecto.Query` leaks) are also good candidates for a committed format/credo hook — this skill covers the judgment calls those tools can't.
