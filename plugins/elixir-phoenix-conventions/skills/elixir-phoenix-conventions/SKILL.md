---
name: elixir-phoenix-conventions
description: Team conventions for our Elixir/Phoenix apps. Use when writing or editing any `.ex` or `.exs` file, a `docs/` page a change ships with, running `mix precommit`, or editing guardrail config (`.credo.exs`, `.sobelow-conf`, `.sobelow-skips`, `.dialyzer_ignore.exs`, CI workflows).
---

# Elixir/Phoenix Conventions

Code that breaks these rules still compiles and passes its tests, so only this list catches it. Hold every line you write or edit to the rules below; where they are silent, do the job the way the app already does it (#64).

- `MyApp`/`MyAppWeb` stand for the app's namespace.
- Rules are cited by number (`#18`), and the numbers are stable. An `EP-…` id names the matching language-agnostic rule in the `engineering-principles` skill of the `engineering-review` plugin, where that plugin is installed.
- Broken most often, so check them first: #2, #13, #18, #23, #31, #59.

## Read first, when it applies

Each file sits next to this one and holds the detail and worked code for one kind of work.

| Before you | Read |
|---|---|
| add a feature that has no sibling module to copy | `reference.md`: one feature wired through every layer |
| write or change a test | `testing.md` |
| write an operation with more than one write, a write whose value was read earlier, a lock, a transaction or a Service | `concurrency.md` |
| write a resolver, a mutation, a GraphQL type or a GraphQL test | `graphql.md` |
| change what the app does or how it is wired | `docs.md`: the page and the map the change ships with |

## Before you say done

1. Every function you touched is re-read, and what the edit made pointless is deleted (#56).
2. `docs/` describes the app after the change, or the PR description names the page you checked (#59).
3. Every character of the diff is English (Rule 0).
4. `mix precommit` exits 0 on a run started after your last edit (#60). A red run is reported with its output.

## Rule 0 — everything is in English

**Every character we author is English** (EP-0): module, function and variable names, `@moduledoc` and `@doc` text, comments, `describe`/`test` names, error messages and typed-error fields, log and telemetry messages, migration and index names, seed labels, `TODO`s, commit messages and PR descriptions. This holds whoever wrote the surrounding code and however short the snippet.

The only other language allowed is translated *copy*, which is data: message catalogues (Gettext `.po` files or equivalent) whose source locale is English. Their keys, and every comment around them, are English.

Code you touch that is in another language is renamed and its comments rewritten in English, in the same change (#56).

## The rules

### A. Context architecture & layering
1. Four tiers: facade (`MyApp.Accounts`) → sub-module (`Accounts.Users`) → `Query` (`accounts/users/query.ex`) → schema (`Accounts.User`).
2. The facade is the context's public API and nothing else: it `defdelegate`s to sub-modules, and every new public context function gets its `defdelegate` (`defdelegate create_referral(attrs, opts \\ []), to: Referrals`). Callers outside the context (resolvers, workers, other contexts) call the facade, `Accounts.create_referral(attrs, opts)`; a sub-module is private to its context. Substantial cross-context or multi-step orchestration lives in a Service (#4), not inline in the facade.
3. Sub-modules hold CRUD and business logic and carry a domain name (`Users`, `Confirmations`); the name `Impl` belongs to adapters only (#5).
4. **Context and sub-module functions stay thin**: take a struct and an attrs map, apply the schema changeset, call `Repo.insert/update/delete`. Anything more (a multi-step `Ecto.Multi`, cross-context orchestration, computation, an external side effect, a branching workflow) is a **Service**: `MyApp.Services.*` when it crosses contexts, `MyApp.{Context}.Services.*` when it stays in one. A Service has exactly one public function, `run/…`, taking `opts \\ []`, with as many heads as it needs; a second job is a Service of its own. Its `@moduledoc` states its single responsibility, it is built from pattern-matched heads and extracted `defp`s, and it returns `{:ok, _}`/`{:error, _}`. **Callers invoke `Service.run(...)` directly: a Service is never `defdelegate`d or wrapped by a facade or another module.**
5. **External services and adapters** are a behaviour + `Impl` + `StubImpl`/Mock, swapped via config (`Geocoding`, `PaymentProvider`, `StripeClient`). The behaviour's callbacks return the app's structs: a webhook comes back as `{:ok, %Connection{}}`, not as the provider's decoded map. Only the implementation names the provider; controllers, plugs, routes, assigns and log lines say what they do (`MediaServerController`, `/webhooks/media-server`). The implementation reads its settings from its own key (`config :my_app, MyApp.Live.Adapters.LiveKit, …`), and `config/runtime.exs` requires each one, counting a blank value as missing, wherever that implementation is the configured one (EP-D6, EP-E6).
6. Schemas `use MyApp.Schema, :schema` (binary_id UUID primary keys), in place of a bare `use Ecto.Schema`.
7. Changesets live in the schema module (`changeset/2`, or intent-named like `archive_changeset/2`); sub-modules call them. A changeset declares every constraint of its table that the write can hit (`unique_constraint`, `foreign_key_constraint`, `check_constraint`), so the write returns `{:error, changeset}` for the caller to map to a typed error (#38) in place of raising `Ecto.ConstraintError` (EP-H3).
8. `@derive {JSON.Encoder, except: [...]}` on schemas controls which fields are exposed.
9. Soft-delete, and every other lifecycle stamp, is a nullable datetime (`archived_at`/`deleted_at`/`flagged_at`/…), not a database delete. A lifecycle mutator takes attrs, `fn(%Schema{} = struct, attrs \\ %{}, opts \\ [])`, so the **same** function stamps and resets the field: pass `%{field: nil}` to clear it. The changeset `put_change`s the timestamp, then `cast(attrs, [field])` so attrs can override, guarded by `validate_no_override/2`. That guard is built on `validate_change`, which Ecto skips when the new value is nil, so setting a field that is already set fails and resetting it to nil succeeds.
10. Context directory layout: `context.ex`, `supervisor.ex`, `events.ex`, `event_handler/`, `services/` (Service objects), schema files, and one directory per sub-module, each with its `query.ex`.

### B. Ecto / Query / Repo
11. Query modules `use MyApp.Query`, which gives `filtered_by/2`, `ordered_by/2`, `with_id(s)/2`, `paginate/4` and `count/1`.
12. Custom query functions are chainable and return queryables, with guards and a fallthrough clause (`def filtered_by(q, _), do: q`). **Build each one by piping the queryable through Ecto's macro forms**: `where(q, [m], …)`, `order_by/3`, `join(q, :inner, [m], t in assoc(m, :thread), as: :thread)`, `select/3`, `limit/2`. Every function is then a single composable pipe step. **A join uses `assoc(m, :name)` whenever the schema declares the association**, which reuses its foreign key and conditions; an explicit `on:` is for a join with no association (computed or cross-schema). `from(...)` is reserved for the three things the pipe forms cannot express:
    - **naming the root binding**: `from(t in Thing, as: :things)` for `base/0`, or `from(q, as: :things)` inside a `has_named_binding?`/`maybe_alias_*` guard;
    - a **standalone subquery or `exists`/`not exists`** expression (`subquery(...)`, `parent_as(...)`);
    - an **`update:` or fragment atomic write**.

    A table name inside a `fragment` string means the builder was skipped: write the subquery with `exists`/`subquery` and `parent_as` over the schema, and keep in `fragment` only what the builder cannot express, such as a row comparison `(?, ?) > (?, ?)` or a cast (EP-K11).
13. `import Ecto.Query`, and with it `where`/`from`/`order_by`/`join`/`preload`/`lock`, appears **only** in `*/query.ex` modules. Context and sub-modules pipe a schema through `Query.*` functions, then call `Repo.*`.
14. Read chain: `Schema |> Query.filtered_by(args) |> Query.ordered_by(o) |> Query.paginate(...)` / `Repo.one`.
15. Read by id through a context getter (`get_*`/`get_*!`). Callers outside the context use the getter and never `Repo.*`. Inside the getter, `Repo.get`/`Repo.get_by` is fine; use `Schema |> Query.with_id(id) |> Repo.one` when you need the Query layer's standard filters, such as soft-deletes. Every `get_*`, private ones included, returns `{:ok, struct}` or `{:error, %Errors.NotFoundError{}}`. A unique-constraint race recovers through the getter and returns its result as is, never `{:ok, get_*(...)}` around a lookup that may return `nil` (EP-A2, EP-C2).
16. **Preloads are opt-in through the `:preloads` option**: a list of association atoms, default `[]`, so nothing is loaded unless the caller asks.
    - A getter or list function reads `preloads = Keyword.get(opts, :preloads, [])` and threads it through **one** private `maybe_preload/2` per module. Its `is_list` head `Enum.reduce`s the list, mapping each supported atom to a `Query.preload_<assoc>/1` call (`:referrer, acc -> Query.preload_referrer(acc)`) with a `_, acc -> acc` fallthrough; a second head, `maybe_preload(queryable, _), do: queryable`, takes non-list input.
    - `preload/2` itself is called only in the Query module (#13), as chainable `preload_<assoc>/1` functions. Atom names mirror association names; nested and keyword preloads are fine (`preload_driver/1` → `preload(q, driver: :user)`). The function's `@doc` lists the supported atoms.
    - **One query wherever a join can do it.** For a to-one association (`belongs_to`/`has_one`), create the binding with `with_named_binding/3`, wrapped in a chainable `with_<assoc>_binding/1` helper, and `preload` off that named binding: one round-trip, and the join is reused if a filter already added it. A separate-query `preload/2` is for the cases where a join is the wrong tool: a to-many association a join would multiply, or a `limit`ed or paginated query a join would break.
    - **Gotcha:** when the result feeds a GraphQL or JSON field that reads the struct directly, with no field resolver, the caller passes the `:preloads` it needs, or the field is `%Ecto.Association.NotLoaded{}`.
    - `reference.md` shows both modules.
17. List queries paginate through `Query.paginate`.

### C. Idiomatic Elixir
18. **Dispatch by pattern matching**: function heads, guards, `case` and `with`, in place of `if/else`, and never `cond`. Map a result with `case` clauses or function heads that match its shape, such as `{:error, %Ecto.Changeset{errors: [{:referrer_id, {_, [{:constraint, :unique} | _]}} | _]}}`, not with an `if` on the contents of an error. `if` is for a simple boolean business decision only: it never dispatches on a type or a result, and never has an `else` returning a different shape. A branch driven by a boolean predicate becomes a private `maybe_<verb>/N` with `true` and `false` heads, the boolean as the **last** argument (the subject leads), in place of a `case` on the boolean:

    ```elixir
    maybe_moderate(message, urls, skip_moderation?(message.body, urls))

    defp maybe_moderate(%Message{} = message, _urls, true), do: {:ok, message}
    defp maybe_moderate(%Message{} = message, urls, false), do: moderate(message, urls)
    ```
19. `with` for happy-path `{:ok, _}`/`{:error, _}` chains; `else` only for error mapping.
20. Be exhaustive in `case`/`with`: list the real result shapes (`{:error, X}`, `{:error, Y}`, …) so every outcome is handled on purpose. An unexpected shape crashes; a blanket `_ ->` would mishandle it silently. The chainable query fallthrough of #12 is the one deliberate exception.
21. **Propagate fallible results.** When a function's final action is a fallible call (`Repo.insert/update/delete`, `Oban.insert`, another `{:ok, _}|{:error, _}` function), it returns *that call's* result. Running it for effect and returning a literal `:ok` hides the failure: the caller sees success and cannot retry. Every head has the **same return shape**: a no-op or short-circuit head returns the matching `{:ok, nil}`-style tuple, not a bare `:ok`. (#20 covers unforeseen shapes; this covers a known fallible result.)
22. Tagged tuples `{:ok, _}`/`{:error, reason}` for fallible functions; mutation resolvers wrap the value in a map (`{:ok, %{user: user}}`).
23. Single level of abstraction: each function does one thing at one altitude, in about 10–30 lines, with its steps extracted into well-named `defp`s and no nested conditionals.
24. Pipe two or more chained calls; a single call is written as a plain call.
25. `alias`/`import`/`require`/`@attr` at the top of the module only.
26. Naming: predicates end in `?`, raising functions in `!`; snake_case functions, PascalCase modules, no abbreviations.
27. `@impl true` on every behaviour, OTP and Phoenix callback.
28. `@moduledoc` on every module (`false` for an internal one); `@doc` and `@spec` on the public API.
29. `Ecto.Multi` for multi-step transactions; #55 says when one is required and which lock goes with it.
30. Context function names: `list_*`, `get_*`, `create_*`, `update_*`, `delete_*`, `count_*`.
31. JSON goes through the built-in `JSON` module (`JSON.encode!/1`, `JSON.decode!/1`, `@derive {JSON.Encoder, ...}`), never `Jason`.
32. **Take an id, not a struct, when you only need the id.** A function that reads only `entity.id` accepts the bare id (a `binary`), so a caller that already holds the id does not load the struct. When some callers hold the struct and others the id, add a struct head that delegates to the id head: `def f(%Schema{id: id}, x), do: f(id, x)`, then `def f(id, x) when is_binary(id), do: …`.
33. **Bind a computed value to a variable before placing it in a map, struct or keyword list.** `member_wish_ids = unserved_wish_ids_for_cluster(id)` above the literal, then `%{cluster_id: id, member_wish_ids: member_wish_ids}`. The literal stays a flat shape and the value carries a name; a function call is not written inline as a value.
34. **Read and write maps and keyword lists through their module functions**: `Map.get/2,3`, `Map.fetch/2`, `Map.fetch!/2`, `Map.put/3`, `Map.merge/2`, `Map.update/4`, … and `Keyword.get/2,3`, `Keyword.fetch/2`, `Keyword.fetch!/2`, `Keyword.put/3`, …, never bracket (`Access`) syntax such as `attrs[:x]` or `opts[:x]`, which returns `nil` for a missing key and breaks on structs. `fetch!` when the key must be present, `get/3` with an explicit default when it is optional. Destructuring in a function head or a `with`/`case` pattern (`def build(%{user_id: id, text: text})`) is as good and often clearer. Nested access still uses `get_in`/`put_in`/`update_in`.

### D. GraphQL / web layer

Worked resolver, mutation type and GraphQL test: `graphql.md`.

35. One schema per endpoint or audience (`/api`, `/admin`); shared types and middleware under `api/shared/`.
36. Naming: `MyAppWeb.Api.{Endpoint}.Resolvers.{Domain}.{Name}`, `.Schema.{Queries,Mutations,Types,Middlewares}.…`.
37. Resolvers return tagged tuples and use `with` chains; authorization is middleware at the entry plus the resolver for business rules.
38. Typed errors: `MyApp.Errors.*` with `use MyApp.ExErrors` + `defexerror`, returned as `{:error, Errors.X.new(...)}`, not as raw strings. **Define, then return**: the error module exists in the project (`lib/my_app/errors/<name>_error.ex`) before any code returns it, so create `Errors.X` first when it is missing. An error may carry structured fields, `defexerror([:resource_type, :resource_id, message: "..."], required_fields: [:resource_type])`, which surface in the GraphQL response under `extensions.fields` beside `extensions.errorCode`.
39. Global middleware `SafeResolution.apply(…) ++ [ErrorHandler]` normalizes errors to `extensions.errorCode`.
40. Mutations use `payload field` with `input`/`output`, and apply their auth middleware inline.
41. Resolvers pass event metadata, `EventMetadata.build_opts(res)`, into context functions.
42. Nested lists go through a Dataloader-backed connection (`Dataloader.Ecto`), so GraphQL has no N+1.

### E. Events & workers
43. Eventing is the **`ex_event_bus` hex dependency** (Oban-backed, exactly-once delivery). The bus module is `MyApp.EventBus` (`use ExEventBus, otp_app: :my_app`); events live in `MyApp.{Context}.Events` via `use ExEventBus.Event` + `defevents([...])`. Every `ex_event_bus` `use` macro **requires** its option (`otp_app:` or `ex_event_bus:`) and raises `ArgumentError` at compile time without it.
44. Every domain create, update or delete emits on success: `Repo.insert/update/delete(cs, success_event: Events.X, event_opts: opts)`, in a function that takes `opts \\ []`. `Repo` accepts `success_event:`/`event_opts:` because it does `use ExEventBus.EctoRepoWrapper, ex_event_bus: MyApp.EventBus`; that wrapper publishes the event when the write succeeds.
45. Handlers are `MyApp.{Context}.EventHandler.{Name}`: `use ExEventBus.EventHandler, ex_event_bus: MyApp.EventBus, events: ["Elixir.MyApp.{Context}.Events.{Name}"]` (both options required). They implement `handle_event/1`, returning `:ok | {:ok, any} | :error | {:error, any}`, pattern-match the aggregate and changes (string keys, after the JSON round-trip), and enqueue work with `Oban.insert()`. The aggregate carries the facts the handler acts on, who acted and as what (`"user_id"`, `"role"`), so the handler calls no getter to learn them (EP-H14). One handler per rule: a variant by actor is a field of the aggregate, not a second event (EP-D10). A stamp written on every request or cron tick (`host_last_seen_at`) takes no `success_event:` (EP-H10).
46. Handler supervision: `EventHandler` delegates `child_spec` to its `Supervisor` (`:one_for_one`).
47. **Cross-context communication goes through events**, for decoupled reactions. The one exception is a Service (#4) orchestrating a synchronous cross-context transaction. Direct calls otherwise stay within a context.
48. Workers live in `lib/my_app/workers/`: `use MyApp.Worker` + `use Oban.Worker, queue:, max_attempts:`, an `@impl` `perform(%Oban.Job{args: %{"k" => v}})` returning `:ok`/`{:error}`/`{:cancel}`/`{:snooze}`, and `tags:`.

### F. Testing

Detail, worked tests and the reasons: `testing.md`.

49. Case templates: `MyApp.DataCase` (contexts, changesets), `MyAppWeb.ConnCase` (HTTP), `*GqlCase` (GraphQL).
50. Factories: ExMachina `{name}_factory`, `insert/2` over `build/2`, `sequence/2` for uniqueness.
51. Mocking: Mox with behaviours, `defmock` centralized in `test_helper.exs`, `setup [:set_mox_from_context, :verify_on_exit!]`.
52. Event testing: `use ExEventBus.Testing, ex_event_bus: MyApp.EventBus` (the option is required) gives `assert_event_received(Events.X, args: …)`, `refute_event_received/2`, `all_received/1` and `execute_events/0,1`. Events are Oban jobs on the `:ex_event_bus` queue, so `assert_event_received` is `Oban.Testing.assert_enqueued` underneath and proves only that the event was enqueued. `execute_events()` *drains* that queue and runs the handlers; assert on its result, `assert %{success: 1, failure: 0} = execute_events()`, or scope it with `execute_events(event_handler: MyApp.{Context}.EventHandler.{Name})`. Worker testing: `use Oban.Testing`, `perform_job/2`, `assert_enqueued/1`.
53. **One `describe` per function, and one function per `describe`**, named `describe "fun/arity"` after the function under test; every `test` inside exercises that function only, and all of a function's tests sit in its one `describe`. Tests read `test "when <condition>"`. `async: true` for pure tests. GraphQL tests go through `query_gql(...)` + `load_gql_file`, and there the `describe` names the `.gql` file: one operation.
54. **Self-contained tests**: everything that drives the assertion, the input data *and* the expected values, is visible in the `test` body. Build the entities under assertion inside the test, with the fields the assertion depends on passed explicitly and inline. `setup` is for harness wiring that is never asserted on: Mox mode, a `conn`, sandbox or config, a feature flag. Inline literal values in place of module attributes (`@valid_attrs`, `@user_id`). When repetition hurts, extract a named helper or a factory (#50) that the test calls. Set the environment the behaviour depends on, a time zone or a locale, inside the test (EP-G4).

### G. Concurrency
55. **Assume a concurrent writer: make the operation atomic, and put the invariant in the database.** More than one write in one logical operation, or a single write whose value came from a row read moments earlier, runs as one `Ecto.Multi` in a single `Repo.transaction/1` (#29), in a Service (#4), with the `{:error, step, value, changes}` 4-tuple mapped back to `{:ok, _}`/`{:error, _}`. "The second write can't realistically fail" is not an argument: a constraint, a race or a restart makes it fail, and nothing undoes the first. **Nothing external runs inside a transaction**: an HTTP call, an email or a payment is an Oban job enqueued as a Multi step. `concurrency.md` gives the protection for each thing at risk (counter, upsert, state transition, `FOR UPDATE`, optimistic lock, advisory lock, claim row, Oban `unique:`), the lock order, how Services compose and how to test the invariant.

### H. Change hygiene
56. **After editing, above all after removing logic, re-read the code you touched and, in the same change, delete whatever the edit made pointless.** A helper collapsed to `x -> x` is inlined at its lone call site and removed; a clause that became unreachable and an unused `@attr` are deleted. Comments stay useful and current: drop any that no longer matches the code, and keep none that says what the code *used to be* or *used to do*, since that history is in git. What a change adds is held to the same bar (EP-D8): an event in `defevents` that no `EventHandler` lists, a schema field that is only `cast` and written, a `def` or `defdelegate` no production code calls, a status string nothing writes and the clause that matches it — each ships with the change that reads it.

### I. Application boundaries
57. **An app knows everything inside its own boundary and nothing outside it** (EP-E1 to EP-E4). This backend owns its domain, its database and the contract it publishes, and encodes no knowledge of another application: a client app's screens, navigation, local state or release cadence; another service's modules, tables or file layout.
    - **Another app's data arrives through its API or as an event.** There is no second `Repo` on another service's database, no schema mirroring a table we don't own, no SQL across a boundary. #47 is the same principle one level down, between contexts.
    - **The domain does not know who is calling.** `if client == "mobile"` in a context is a boundary leak. Shaping for an audience is the web layer's job, which is what the per-endpoint schema split (#35) is for.
    - **One side owns each rule.** A caller that needs a computed value or a decision gets it as a field, a mutation result or a typed error (#38), and a client is not left to re-implement ours: two copies of one rule drift.
    - **Docs and comments describe what this code guarantees**, never what a client does with it ("the mobile app shows this on the profile screen"). Nothing in this repo can verify such a sentence, and nobody updates it when that app changes.

### J. Comments & prose
58. **No comment unless the code cannot say it.** The default is zero inline comments: names, small single-altitude functions (#23), pattern-matched heads and typed errors (#38) carry the meaning.
    - **The code says the *what*.** A comment restating the function name or the next line (`# fetch the user`, `# build the changeset`), or walking through a pipe step by step, is deleted; when the code needs that prose to be followed, the fix is a better name or an extracted `defp`.
    - **A comment earns its place for a *why* the code cannot show**: a workaround for an external system's quirk, a non-obvious constraint (a lock order, a provider's idempotency rule, #55), a deliberate deviation from a rule in this skill (name the rule), or the ticket that decided it. One or two lines, at the line it explains; a paragraph belongs in the `@moduledoc` or the PR description.
    - **`@moduledoc`/`@doc` stay mandatory (#28) and describe the contract**: what the function guarantees, its options, its return shapes. The `defp`s it calls and the queries it runs are implementation, and change while the doc does not. `@moduledoc false` is a complete doc for an internal module.
    - **No structural or decorative prose**: no banner or section comments (`# ---- Helpers ----`), no `# TODO` for something doable in this change, no commented-out code (git keeps it, #56). In tests the `describe`/`test` names are the documentation (#53); a comment explaining what a test checks means its name is wrong.

    ```elixir
    # Stripe redelivers webhooks for up to 3 days; `on_conflict: :nothing` makes a replay a no-op.
    Repo.insert(changeset, on_conflict: :nothing)
    ```

### K. Documentation
59. **Every PR ships its documentation**, describing the app *after* the change. `docs/README.md` is the system map: every feature, and every edge between features. `docs/<context>/<feature>.md` is one living page per feature, with mermaid diagrams. A change to behaviour or wiring updates the page(s), and the map when an edge appeared or disappeared, in the same PR. A change that alters nothing documented (formatting, a version bump) says in the PR description which page was checked and why it needed no change. No `docs/` diff and no such statement is an incomplete PR, exactly like a missing test. `docs.md` has the page skeleton, the writing rules and a worked page.

### L. Guardrails

60. **Green before done.** Before saying any Elixir work is finished, run `mix precommit` after your last edit and read its output; a red run is reported with that output, not summarised as done. An app with no `precommit` alias → run what it has (`mix format`, `mix credo --strict`, `mix test`) and say the app is missing guardrails; the `elixir-guardrails` skill installs them. No check covers Rule 0 or #59: English-only code and a behaviour change shipped without its `docs/` change are caught only by reading, so read every diff for both.
61. **Never weaken a guardrail to get green.** No `# credo:disable-*`, `@dialyzer {:nowarn_function, …}`, `# sobelow_skip`, `# excellent_migrations:safety-assured-for-next-line`, new entry in a baseline (the `# >>> baseline` block of `.credo.exs` or of a `use Boundary`, `.dialyzer_ignore.exs`, `.sobelow-skips`), raised `--fail-above`, advisory ignore, `precommit` or CI step removed or made non-blocking, or `@tag :skip`. Fix the code instead. A genuine exception needs the person's approval, a one-line comment naming the rule (#58 allows that comment), and the `guardrails-changed` label on the PR. **Baselines only shrink:** a change that edits a file listed in a baseline fixes that file's issues and deletes its entry in the same change. Deleting entries needs no label; the CI gate lets it through.
62. **Write code that passes the checks the first time.** Each item names the check that enforces it:
    - `Task` only under a supervisor, `Task.Supervisor.async_nolink/3`, and in LiveView `start_async/3` with `handle_async/3` (UnmanagedTask, MissingHandleAsync, SyncOverAsync).
    - A `rescue` never discards the error: return `{:error, reason}`, re-raise, or log with the exception (SwallowingException; extends #20 and #21). The check only sees an explicit `try … rescue`, and Credo's PreferImplicitTry turns that into a function-level `rescue` it cannot see, so read every `rescue` you write or move.
    - No blocking call (HTTP, `Process.sleep`, a slow query) inside a Plug's `call/2` (BlockingInPlug).
    - A `case` on `true`/`false` (CaseTrueFalse) is fixed with a `maybe_*` helper (#18), never with the `if`/`else` the check's message suggests.
    - No `raw/1` in a `.heex` file or a `~H` template (Sobelow XSS.Raw).
    - Every test asserts an outcome, a value or stored state and not only `{:ok, _}`; every selector can fail; no `open_browser` is committed (VacuousTest, TestHasNoAssertions, WeakAssertion, AssertElementSelectorCanNeverFail, NoOpenBrowser; complements #53 and #54).
    - Every LiveView assign is rendered (UnusedLiveViewAssign).
    - No query per item and no missing preload: use #16's opt-in preloads (NPlusOneQuery, MissingPreload). Filter in the query, never with `Enum.filter` after `Repo.all` (InefficientFilter).
    - Migrations: `create index(…, concurrently: true)` with `@disable_ddl_transaction true` and `@disable_migration_lock true`; no column type changed in place; backfills outside schema migrations (MigrationsSafety).
    - No new compile-time dependency: no call to another app module in a module attribute or module body, no `import`/`use` of an app module without a real need (xref compile-connected).
    - Callers outside a context use its facade (#2). Boundary's `exports` enforce it at compile time; a new cross-context dependency goes in `deps:` and is justified by #47.
    - Every `` `Mod.fun/n` `` in a `@doc` or `@moduledoc` exists (docs `--warnings-as-errors`).
    - Public `@spec`s (#28) stay true; a Dialyzer warning is fixed, never silenced.

### M. Migrations

63. **A migration in `priv/repo/migrations` is final once it is on main or pushed (EP-I6).** Change the schema with a new migration, so every database runs the same files in the same order: production, staging, CI and each teammate's. A column added too soon is dropped by a new migration (`remove :host_last_seen_at, :utc_datetime_usec`, with its type so it rolls back) and added back by the change that reads it.

### N. The app's idioms

64. **Do a job the way the app already does it (EP-D13).** Read config through the app's config module when it has one (`MyApp.Config.fetch_env!/2`, which async tests override per process) rather than `Application.fetch_env!`; default an environment variable in `config/runtime.exs` the way the file already does (`String.to_integer(System.get_env("NAME") || "15")`); name operations with the app's verbs (tokens are `issue_*`d where the app says so, EP-A2). Before writing a helper, find how two existing modules do the same job.
