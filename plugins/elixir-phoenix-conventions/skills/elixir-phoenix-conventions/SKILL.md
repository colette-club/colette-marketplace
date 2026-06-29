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
4. **Keep context/sub-module functions thin** — take a struct + attrs map and apply the schema changeset (`Repo.insert/update/delete`). Anything more (multi-step `Ecto.Multi` txns, cross-context orchestration, computation, external side effects, branching workflows) moves to a **Service object**: `MyApp.Services.*` (cross-context) or `MyApp.{Context}.Services.*` (context-scoped), with one public `run/…` (+ `opts \\ []`), `@moduledoc` stating its single responsibility, pattern-matched heads + extracted `defp`s, returning `{:ok,_}`/`{:error,_}`. **Callers invoke `Service.run(...)` directly — services are NEVER `defdelegate`d or wrapped through a facade/higher-level module.**
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
29. `Ecto.Multi` for multi-step transactions.
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
53. Structure: `describe "fun/arity"`, `test "when <condition>"`, `setup` blocks, `async: true` for pure tests; GraphQL via `query_gql(...)` + `load_gql_file`.

## Canonical examples

`reference.md` in this skill is a full worked example — a new feature wired through every layer. The conventional home for each pattern (with `my_app` standing in for the app):

- Layering + facade delegation: `lib/my_app/<context>.ex`, `lib/my_app/<context>/<sub_module>.ex`
- Service object (`run/…`, `Ecto.Multi`, called directly): `lib/my_app/services/<name>.ex` or `lib/my_app/<context>/services/<name>.ex`
- Query module (`use MyApp.Query`): `lib/my_app/<context>/<sub_module>/query.ex`
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
- A function taking a full `%Schema{}` but reading only `.id` → accept the id directly; if some callers hold the struct, add a `%Schema{id: id}` head that delegates to the id head (avoids needless DB loads at call sites that already have the id).
- A map/struct/keyword literal with a function call inline as a value → bind it to a named variable above the literal first, then reference the variable (keeps the shape scannable and names the value).
- A context/sub-module fn doing more than changeset + `Repo` write (multi-step `Ecto.Multi`, cross-context calls, computation, external side effects) → extract a **Service** (`MyApp.Services.*` / `{Context}.Services.*`), called directly — don't bloat the context or route it through the facade.
- A domain create/update/delete without `success_event:`.
- One context calling another context's functions directly → emit an event instead (the exception is a Service orchestrating a synchronous transaction).
- A new error returned as a raw string, or `{:error, Errors.X.new(...)}` where `Errors.X` isn't defined → define the `MyApp.Errors.*` module first (define-then-return); never reference an undefined error module.

## Also enforced mechanically

`mix format --check-formatted && mix credo --strict && mix test` must pass before commit. Some rules here (alias/attr placement, `Jason` usage, `import Ecto.Query` leaks) are also good candidates for a committed format/credo hook — this skill covers the judgment calls those tools can't.
