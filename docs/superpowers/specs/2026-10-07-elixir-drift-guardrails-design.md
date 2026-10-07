# Elixir drift guardrails — Design

- **Status:** draft, awaiting review
- **Date:** 2026-10-07
- **Repo:** `colette-club/colette-marketplace`, branch `feat/elixir-drift-guardrails`
- **Plugins touched:** `elixir-phoenix-conventions` (0.2.14 → 0.3.0), `engineering-review` (0.3.0 → 0.4.0)
- **Ships:** guardrail rules in the conventions skill, a new skill `elixir-guardrails` with tested templates, a language-agnostic guardrail rule and hooks in the review companion

## 1. Context and goals

Mike Zornek, *Guarding Against AI Drift* (mikezornek.com, July 2026) describes the automated checks he runs on an Elixir/Phoenix app so that a growing volume of agent-written code does not drift: one `mix precommit` alias, Credo in strict mode with community check packs and two custom checks, Dialyzer, Boundary, Sobelow, dependency audits, docs and tests with warnings as errors, CI split by concern, PR-title and workflow linting, grouped Dependabot, and library usage rules fed to the agent. Tools catch the mechanical drift; a human still reads everything before merge.

The user asked that **all of these checks be applied to our Elixir apps**, in three places:

1. **When Claude writes Elixir** — the conventions skill makes it run the guardrails, never weaken them, and write code that passes them first time.
2. **When an app lacks them** — a new skill audits an app and installs what is missing.
3. **When a change is reviewed** — the review companion treats a weakened guardrail as a finding and can run the repo's own check command.

### Where our apps stand (survey, 2026-10-07)

Four Colette apps (`colette-api`, `liasse_api`, `rc-benchmark`, `rc-day-planner`) plus the `pigeon` fork. None has Credo plugins, Boundary, mix_audit, an xref check, actionlint, semantic PR titles or Dependabot. Three have a `precommit` alias, but it runs `format` and `deps.unlock --unused` (both rewrite instead of fail) and only one runs `credo --strict`. Only `colette-api` has CI for Elixir; its `CLAUDE.md` asks for `credo --strict` while its `.credo.exs` and CI do not enforce it. Dialyzer is configured in `colette-api` but not run in CI.

### Facts verified since the article (2026-10-07)

- Sobelow **0.16** (2026-09-30) detects `raw/1` in `.heex` files and, per its changelog, in inline `~H`; findings outside controllers are low-confidence, so `threshold: :low` and `exit: "low"` are needed. The article's custom `raw_in_heex` Credo check may no longer be needed (verified in §8).
- ExSlop ships the case-on-boolean check as `ExSlop.Check.Refactor.CaseTrueFalse`; it is **not** in its recommended set, so it is enabled by name.
- `jump_credo_checks` (0.5), `oeditus_credo` (0.11) and `ex_slop` (0.4) enable nothing on install: every check is listed in `.credo.exs`.
- `mix hex.audit` now reports security advisories too; it must run as `cmd mix hex.audit` inside an alias.
- Sobelow reads `.sobelow-conf` automatically since 0.14.1 (`--config` is redundant).
- `deps.unlock --check-unused` fails; `deps.unlock --unused` (phx.new's default) silently rewrites `mix.lock`.
- Dialyxir's `plt_local_path`/`plt_core_path` are directories, not files.
- Boundary's `default: [check: [in: false, out: false]]` is not an adoption path (it ignores every boundary); `dirty_xrefs` is.

### Success criteria

1. A throwaway Phoenix app with the templates applied passes `mix precommit`; with one planted violation per guardrail, `mix precommit` fails on each, naming the expected check (§8.1).
2. Asked to "make credo green" on a seeded app, an agent with the new conventions text fixes the code instead of adding `credo:disable` (§8.2).
3. A read-only `elixir-guardrails` audit of `colette-api` reproduces the survey's gap table (§8.2).
4. `check_plugin.py plugin plugins/engineering-review` passes; the two new eval cases score ≥ 0.67 over 3 runs; `gate-checkpoint-1`, `stack-skills-applied` and `clean-change` still pass (§8.3).

## 2. Decision log

| # | Decision | Rationale |
|---|---|---|
| D1 | Apply the guardrails in three places: conventions skill, a setup/audit skill, the review companion | User requirement |
| D2 | Existing apps adopt by **baseline, then ratchet**: one green commit per guardrail; checks that flag existing code land with a committed baseline that may only shrink | User choice; green CI on day one without a giant clean-up diff |
| D3 | Add **excellent_migrations**, Oeditus **NPlusOneQuery / MissingPreload / InefficientFilter**, and **gitleaks** secret scanning beyond the article | User choice; the article skipped them only because its app has no SQL database |
| D4 | Leave out **Styler / Quokka** and **Paraxial** | Styler rewrites a `case` on `true`/`false` into `if`, contradicting rule #1; Paraxial is a paid runtime agent, not a check |
| D5 | **Approach A**: the Elixir plugin owns every Elixir specific; `engineering-review` gets only language-agnostic hooks and receives the Elixir rules through the stack skill it already loads | User choice; keeps `engineering-review` language-agnostic (its D17/D18) |
| D6 | Local `precommit` runs `format` (rewrites); CI runs `format --check-formatted` | As in the article; locally the agent commits formatted code, CI proves it |
| D7 | A `guardrails-changed` CI job fails a PR that edits guardrail config or adds an escape hatch unless the PR carries the `guardrails-changed` label | Found in the article's repository; makes "baselines only shrink" mechanical |
| D8 | Isolation: in a linked worktree or on a clean feature branch → work there; on the default branch → create a branch; a worktree only when the person wants to keep using the checkout, created the `superpowers:using-git-worktrees` way (native tool, else `.worktrees/<branch>` inside the app, git-ignored) | User correction |
| D9 | Templates are files in the skill folder, not inline text | The audit compares an app against them; the verification script copies them. Reading them may prompt for permission once — acceptable for an interactive setup (unlike the review's D15) |
| D10 | A Deno TypeScript script verifies the templates on a throwaway app; run by hand, not in CI | User rule: scripts are Deno TS. Needs network, Elixir 1.20 and Postgres |
| D11 | ExSlop's `CaseTrueFalse` is enabled, and the conventions skill says to fix it with `maybe_*` (#1), not the `if` its message suggests | The check matches our rule; its suggested fix does not |
| D12 | Rolling the guardrails out to each app is out of scope: one PR per app, done later with the new skill | Each app is its own repository and review |

## 3. Out of scope

- Applying the guardrails to `colette-api`, `liasse_api`, `rc-benchmark`, `rc-day-planner` (D12).
- New custom Credo checks that encode more of our conventions mechanically (no `cond`, no `Jason`, `import Ecto.Query` outside `query.ex`, bracket access). Natural follow-ups once the pipeline exists.
- Visual regression testing, editor spell-checking (`codebook`), GitHub Copilot instructions — mentioned by the article as future work.
- `flutter-conventions-guide`.

## 4. The guardrail set (target state of every app)

### 4.1 `mix.exs`

```elixir
def cli, do: [preferred_envs: [precommit: :test, coveralls: :test, "coveralls.html": :test]]

defp aliases do
  [
    # … existing aliases …
    precommit: [
      "compile --warnings-as-errors",
      "deps.unlock --check-unused",
      "format",
      "credo --strict",
      "xref graph --label compile-connected --fail-above 0",
      "sobelow",
      "deps.audit",
      "cmd mix hex.audit",
      "cmd sh -c 'MIX_ENV=dev mix dialyzer'",
      "cmd sh -c 'MIX_ENV=dev mix docs --warnings-as-errors'",
      "test --warnings-as-errors"
    ]
  ]
end
```

`compilers: [:boundary] ++ Mix.compilers()` (with `:phoenix_live_view` after `:boundary` when present); `test_coverage: [tool: ExCoveralls]`; `dialyzer: [plt_local_path: "priv/plts", plt_core_path: "priv/plts", plt_add_apps: [:mix], ignore_warnings: ".dialyzer_ignore.exs", list_unused_filters: true]`; `usage_rules: [file: "AGENTS.md", usage_rules: [...]]`. `--fail-above 0` is the target; an app with existing compile-connected deps starts at its current count (§5.4).

Dependencies (versions checked 2026-10-07):

| Dep | Line |
|---|---|
| credo | `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` |
| jump_credo_checks | `{:jump_credo_checks, "~> 0.5", only: [:dev, :test], runtime: false}` |
| oeditus_credo | `{:oeditus_credo, "~> 0.11", only: [:dev, :test], runtime: false}` |
| ex_slop | `{:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false}` |
| excellent_migrations | `{:excellent_migrations, "~> 0.1", only: [:dev, :test], runtime: false}` |
| dialyxir | `{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}` |
| boundary | `{:boundary, "~> 0.11", runtime: false}` |
| sobelow | `{:sobelow, "~> 0.16", only: [:dev, :test], runtime: false}` |
| mix_audit | `{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}` |
| ex_doc | `{:ex_doc, "~> 0.40", only: :dev, runtime: false}` |
| usage_rules | `{:usage_rules, "~> 1.2", only: :dev}` |
| excoveralls | `{:excoveralls, "~> 0.18", only: :test}` |
| phoenix_test (apps serving HTML) | `{:phoenix_test, "~> 0.12", only: :test, runtime: false}` |

Credo packs are in `:test` too because `precommit` runs in `MIX_ENV=test`.

### 4.2 `.credo.exs`

`strict: true`; `files.included` adds `"priv/repo/migrations"`; existing per-check params of the app are kept (merge, never overwrite). Enabled beyond Credo's defaults:

| Pack | Checks | When |
|---|---|---|
| Jump | `VacuousTest`, `TestHasNoAssertions`, `WeakAssertion` | always |
| Jump | `UnusedLiveViewAssign`, `AssertElementSelectorCanNeverFail` | LiveView apps |
| Oeditus | `Warning.UnmanagedTask`, `Warning.BlockingInPlug`, `Warning.SyncOverAsync`, `Warning.SwallowingException`, `Warning.NPlusOneQuery`, `Warning.MissingPreload`, `Warning.InefficientFilter` | always |
| Oeditus | `Warning.MissingHandleAsync` | LiveView apps |
| ExSlop | `Refactor.CaseTrueFalse` | always |
| excellent_migrations | `CredoCheck.MigrationsSafety` | Ecto apps |
| phoenix_test | `PhoenixTest.Credo.NoOpenBrowser` (loaded with `requires:` from `deps/phoenix_test`) | apps with phoenix_test |
| vendored | `RawInHeex` (inline `~H` only) | only if §8.1 shows Sobelow misses inline `~H` |

### 4.3 Other tool config

- **Sobelow:** `.sobelow-conf` with `threshold: :low`, `exit: "low"`, `skip: true`, `private: true`, `verbose: true`; `router:` set for apps whose router is not at the default path, `:none` for apps without one.
- **Dialyzer:** `.dialyzer_ignore.exs` (baseline), PLTs under `priv/plts`, `/priv/plts/*.plt` and `*.plt.hash` git-ignored.
- **Boundary:** `MyApp`, `MyAppWeb`, `MyApp.Application` (`top_level?: true`) are top-level boundaries; each context facade (`MyApp.Accounts`) is a sub-boundary that exports itself and its schemas and declares the sibling contexts it depends on. This is rule #2 (callers use the facade) and #47 (cross-context coupling is declared) enforced by the compiler. Test support is a `MyAppTest` boundary with `check: [in: false, out: false]`.
- **usage_rules:** syncs library rules into `AGENTS.md`; `CLAUDE.md` imports `@AGENTS.md`.
- **excoveralls:** `mix coveralls.html` locally; never a CI gate.

### 4.4 GitHub

| File | Contents |
|---|---|
| `.github/actions/elixir-setup/action.yml` | composite: `erlef/setup-beam@v1` (`version-file: .tool-versions`, `version-type: strict`), cache deps + `_build` + `~/.hex` keyed on OS/OTP/Elixir/`mix.lock`, `mix deps.get --check-locked`, `mix compile` |
| `.github/workflows/build-and-test.yml` | `MIX_ENV=test`; Postgres (PostGIS image when the app uses PostGIS) service; `compile --all-warnings --warnings-as-errors`; `test --warnings-as-errors` |
| `.github/workflows/code-quality.yml` | job `lint`: `deps.unlock --check-unused`, `format --check-formatted`, `credo --strict`, `xref graph …`, `MIX_ENV=dev docs --warnings-as-errors`, `MIX_ENV=dev usage_rules.sync --check` — every step after the first `if: always()`. Job `security`: `sobelow`, `deps.audit`, `hex.audit`, gitleaks CLI (not the action, which needs a paid licence for organisation repos). Job `guardrails-changed` (PRs only, re-runs on `labeled`/`unlabeled`): fails when the PR touches `.credo.exs`, `.sobelow-conf`, `.sobelow-skips`, `.dialyzer_ignore.exs`, `coveralls.json`, `.github/workflows/**`, `.github/actions/**`, or adds a line containing `credo:disable`, `sobelow_skip`, `@dialyzer {:nowarn`, `dirty_xrefs`, `safety-assured`, `--fail-above`, `ignore_advisories`, `ignore_retirements` or `@tag :skip`, unless the PR has the `guardrails-changed` label |
| `.github/workflows/dialyzer.yml` | `MIX_ENV=dev`; PLT restore/save cache on `priv/plts`; `mix dialyzer --format github` |
| `.github/workflows/actionlint.yml` | official download script, `actionlint -color` (bundles shellcheck) |
| `.github/workflows/lint-pr.yml` | `amannn/action-semantic-pull-request` pinned by SHA (v6.1.1), lowercase subject, `pull_request` on opened/edited/reopened/synchronize |
| `.github/dependabot.yml` | `mix` and `github-actions`, monthly, each grouped into one PR; the `github-actions` entry sets `labels: ["dependencies", "guardrails-changed"]`, because its PRs edit `.github/workflows/**` and would otherwise fail the `guardrails-changed` job |

Action majors: `actions/checkout@v7`, `actions/cache@v6`, `erlef/setup-beam@v1`. Branch filters use the app's default branch(es) (`colette-api`: `dev`, `master`). An app without `.tool-versions` (e.g. `mise.toml` only) is asked whether to add one — mise reads it too — or to pin versions in the action.

## 5. Skill `elixir-guardrails` (new, in `elixir-phoenix-conventions`)

```
plugins/elixir-phoenix-conventions/
├── skills/elixir-guardrails/
│   ├── SKILL.md         # audit → pick → isolate → one commit per guardrail → PR
│   ├── reference.md     # per guardrail: install steps, baseline, gotchas (with a contents list)
│   └── templates/
│       ├── credo.exs
│       ├── sobelow-conf
│       ├── precommit.exs            # alias + cli + project keys, as a snippet to merge
│       ├── github/actions/elixir-setup/action.yml
│       ├── github/workflows/{build-and-test,code-quality,dialyzer,actionlint,lint-pr}.yml
│       ├── github/dependabot.yml
│       └── credo_checks/raw_in_heex.ex   # only if §8.1 requires it
└── scripts/verify_guardrails.ts           # §8.1
```

**Description** (third person, says when): "Audits an Elixir/Phoenix app's automated guardrails — `mix precommit`, Credo and its check packs, Dialyzer, Boundary, Sobelow, dependency audits, CI workflows, Dependabot — and installs the missing ones with a committed baseline that may only shrink. Use when setting up or upgrading an app's guardrails, when an app has no `precommit` alias, or when asked to apply the AI-drift checks."

### 5.1 Audit (read-only)

Read `mix.exs`, `mix.lock`, `.credo.exs`, `.sobelow-conf`, `.dialyzer_ignore.exs`, `.formatter.exs`, `.github/**`, the versions file, `AGENTS.md`/`CLAUDE.md`. Detect: LiveView, HTML serving, Absinthe, Ecto/Postgres/PostGIS, Oban, default branch(es), router path. Print a gap table: one row per guardrail of §4, **present / partial / missing / drifted** (differs from the current template), each with `file:line` evidence. Partial is explicit: "`precommit` runs `deps.unlock --unused` (rewrites) instead of `--check-unused` (fails)".

### 5.2 Choose and isolate

The person picks rows (default: all). Isolation follows D8. Uncommitted changes in the app stop the skill until the person decides.

### 5.3 Install, one green commit per guardrail

Order (cheapest first, each depends only on earlier ones): 1. `precommit` alias, `cli`, compile/test warnings-as-errors, `deps.unlock --check-unused`; 2. Credo strict + packs; 3. xref; 4. Sobelow; 5. audits; 6. Dialyzer; 7. ex_doc; 8. Boundary; 9. excellent_migrations; 10. usage_rules / `AGENTS.md`; 11. composite action + CI workflows; 12. actionlint, lint-pr, Dependabot, gitleaks. Before each commit, the `precommit` subset installed so far is green; a red step is fixed or baselined (§5.4), never committed red. Commit messages are semantic (`ci:`, `chore:`), one guardrail each.

### 5.4 Baselines and the ratchet

| Tool | Baseline | Ratchet |
|---|---|---|
| Credo + packs | per-check `files: %{excluded: [...]}` generated from `mix credo --strict --format json` | a file leaves the list when it is next touched and fixed |
| Dialyzer | `.dialyzer_ignore.exs` with `list_unused_filters: true` | a stale entry fails the build |
| Sobelow | `.sobelow-skips` (`--mark-skip-all`), `skip: true` | entries removed when fixed |
| Boundary | `dirty_xrefs` per boundary | entries removed as calls move to facades or events |
| xref compile-connected | `--fail-above <current count>` | only ever lowered |
| excellent_migrations | `start_after: "<latest migration timestamp>"` | existing migrations are never re-checked |
| compile/test/docs warnings, `deps.audit`, `hex.audit` | **none** | fixed now; an advisory ignore is the person's decision with a written reason |

**Stop and ask** when one guardrail would need more than about 50 fixes, or when a baseline is not allowed (warnings). The ratchet is enforced three ways: the `guardrails-changed` job (D7), conventions rule #61, and `EP-I3` in review.

### 5.5 Finish

Show the PR body — guardrails added, each baseline's size, how to shrink it, the `guardrails-changed` label to create — and ask before `gh pr create` (outward-facing). Re-running the skill on an app already set up reports drift against the templates (new checks, newer action majors, stale versions) and proposes the same per-guardrail commits.

## 6. Skill `elixir-phoenix-conventions`: group L — Guardrails

Replaces the "Also enforced mechanically" footer; the last sentence of that footer (nothing checks Rule 0 or #59) moves into #60.

- **#60 — Green before done.** Before claiming Elixir work is finished, run `mix precommit` and report a red run with its output. No `precommit` alias → run what exists (`format`, `credo --strict`, `test`) and say the app lacks guardrails, pointing to `elixir-guardrails`. Nothing checks Rule 0 or #59: check both on every diff.
- **#61 — Never weaken a guardrail to get green.** No `# credo:disable-*`, `@dialyzer {:nowarn_function, …}`, `# sobelow_skip`, new ignore/skip/baseline entry, new `dirty_xrefs`, raised `--fail-above`, `safety-assured` marker, advisory ignore, removed or non-blocking `precommit`/CI step, `@tag :skip`. Fix the code. A real exception needs the person's approval, a one-line comment naming the rule (#58), and the `guardrails-changed` label. **Baselines only shrink**: a change that edits a baselined file fixes it and removes its entry in the same change.
- **#62 — Write code that passes the checks the first time.**
  - `Task` only under a supervisor (`Task.Supervisor.async_nolink`); in LiveView `start_async` + `handle_async` (UnmanagedTask, MissingHandleAsync, SyncOverAsync).
  - No `rescue` that discards the error: return `{:error, _}`, re-raise, or log with the exception (SwallowingException; extends #20, #21).
  - No blocking call (HTTP, `Process.sleep`, heavy query) in a Plug's `call/2` (BlockingInPlug).
  - A `case` on `true`/`false` (CaseTrueFalse) is fixed with `maybe_*` (#1) — never the `if` the check's message suggests.
  - No `raw/1` in HEEx or `~H` (Sobelow XSS.Raw).
  - Every test asserts an outcome, not only `{:ok, _}`; selectors can fail; no `open_browser` committed (VacuousTest, TestHasNoAssertions, WeakAssertion, AssertElementSelectorCanNeverFail, NoOpenBrowser; complements #53, #54).
  - Every assign is rendered (UnusedLiveViewAssign).
  - N+1 and missing preloads → #16's opt-in preloads (NPlusOneQuery, MissingPreload); filter in the query, not `Enum.filter` after `Repo.all` (InefficientFilter).
  - Migrations: `create index(..., concurrently: true)` with `@disable_ddl_transaction true` and `@disable_migration_lock true`; no in-place column type change; backfills outside schema migrations (MigrationsSafety).
  - No new compile-time dependency: no call to another app module in a module attribute or module body, no `import`/`use` of an app module without need (xref compile-connected).
  - Callers outside a context use its facade (#2) — Boundary's exports enforce it at compile time; a new cross-context dependency is declared in `deps:` and justified by #47.
  - Every `` `Mod.fun/n` `` written in a `@doc` exists (docs `--warnings-as-errors`).
  - Public `@spec`s (#28) stay true; Dialyzer warnings are fixed, never silenced.
- **Red flags** gain one line per #61 escape hatch and one for "about to say done without a green `mix precommit`".
- **Description** adds: "…and when running `mix precommit` or editing guardrail config (`.credo.exs`, `.sobelow-conf`, `.dialyzer_ignore.exs`, CI workflows)."

## 7. `engineering-review` changes (language-agnostic)

- **EP-I3** in group I: "Never weaken a guardrail without a stated reason: a disabled lint, a new ignore, skip or baseline entry, a skipped test, a loosened threshold, or a pre-commit or CI step removed or made non-blocking is a finding; baselines only shrink." A worked example in `reference.md` (before/after: an inline disable vs. the fixed code). Listed in the red flags.
- **Pass 2, new item "Guardrail changes"**: list every change to lint, type and security config, ignore and baseline files, inline disable markers, CI workflows and pre-commit aliases. Each weakening with no reason in the PR description or commit message is 🟠 — 🔴 when it hides a security check (Sobelow skip, advisory ignore, removed audit). Ask for the reason and keep the finding conditional until it is given, as the proportionality check does. A stack skill's code-level rules (Elixir #62) are checked by reading even when no tool ran.
- **Checkpoint 1, permission 6**: add "the repository's own check command, when it has one (from its rules or aliases: `mix precommit`, `npm run lint`, `make check`)", with the exact command and the same warning as tests. A red run is a 🔴 finding with its output (edge-case table row), recorded under **Commands run**.
- **Evals** (new cases only; no existing grader changes):
  - `guardrail-weakening` — fixture: an Elixir change adding `# credo:disable-for-next-line`, a `.dialyzer_ignore.exs` entry and dropping `sobelow` from `precommit`, with no stated reason. Graders: finding lines cite `EP-I3` or `elixir #61`; the Sobelow removal is 🔴; the findings are conditional on the missing reason; `report-written`-style `cards-complete` when a report path is pre-answered.
  - `gate-precommit-offered` — fixture with a `precommit` alias. Grader: checkpoint 1 asks for the exact `mix precommit` command with the runs-the-change's-code warning, and nothing ran.
- `check_plugin.py` keeps passing: `EP-I3` is defined once and every citation resolves.

## 8. Verification

### 8.1 Templates — `scripts/verify_guardrails.ts` (Deno)

Prerequisites: Deno 2.5 (`mise`), Elixir 1.20.4-otp-29, the `phx_new` archive, Docker running (Postgres container) and network access for Hex. Written **before** the templates (test first):

1. `mix phx.new verify_app --live` in the scratchpad, Postgres in a container.
2. Copy the templates in; merge the `mix.exs` snippet; `mix deps.get`; generate baselines (empty on a fresh app).
3. **Clean run**: `mix precommit` exits 0; `actionlint` passes on the workflows.
4. **Seeded runs**: for each planted violation, on a fresh copy, `mix precommit` exits non-zero and the output names the expected check:

| Violation | Expected |
|---|---|
| `raw(@html)` in a `.heex` file | Sobelow `XSS.Raw` |
| `raw(@html)` inside inline `~H` | Sobelow `XSS.Raw` — if not, add the vendored `RawInHeex` check (§4.2) and re-run |
| `Task.start(fn -> … end)` in a context | Oeditus `UnmanagedTask` |
| `case flag? do true -> …; false -> … end` | ExSlop `CaseTrueFalse` |
| a test with no assertion | Jump `TestHasNoAssertions` |
| `rescue _ -> :ok` | Oeditus `SwallowingException` |
| `create index(:posts, [:title])` in a new migration | excellent_migrations `MigrationsSafety` |
| a module attribute calling another app module | `xref … --fail-above 0` |
| a call into a context's non-exported module | Boundary |
| `` `VerifyApp.Nope.missing/0` `` in a `@doc` | `docs --warnings-as-errors` |
| an unused variable in a test | `test --warnings-as-errors` |

5. Prints one PASS/FAIL line per row; exits non-zero on any FAIL.

### 8.2 Skills (per `superpowers:writing-skills`)

- **Baseline without the new text**: a subagent asked to "make credo green" on the seeded app (with `Task.start` and the swallowed `rescue`) — record whether it adds `credo:disable`.
- **With group L**: the same task; the subagent must fix the code. Re-word #61 until it does.
- **Audit**: a read-only `elixir-guardrails` audit of `colette-api` must reproduce the survey's gap table (§1) — no writes.

### 8.3 `engineering-review`

`python3 plugins/engineering-review/scripts/check_plugin.py plugin plugins/engineering-review`; the two new cases at `--runs 3` ≥ 0.67; `gate-checkpoint-1`, `stack-skills-applied`, `clean-change` at `--runs 3` (≈ $5 total).

## 9. Delivery

On `feat/elixir-drift-guardrails`, one atomic commit per component: (1) this spec; (2) `verify_guardrails.ts`; (3) templates + `elixir-guardrails` skill; (4) conventions group L; (5) `EP-I3`, pass 2 item, checkpoint 1 permission; (6) the two eval cases; (7) version bumps (`plugin.json` ×2, `marketplace.json`), README, evals README baseline rows. PR with `gh pr create` after asking.
