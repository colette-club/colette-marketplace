# colette-code-conventions — design

**Date:** 2026-08-27
**Status:** approved, pending implementation plan

## Problem

Our two convention skills — `elixir-phoenix-conventions` and
`flutter-conventions-guide` — each carry a set of rules that have nothing to do
with Elixir or Dart. Rule 0 (English only), change hygiene, and application
boundaries are near-verbatim duplicates across both files. Several more
(never swallow a failure, self-contained tests, single level of abstraction,
exhaustive branching) say the same thing in two idioms.

Two consequences:

1. **The duplicates drift.** This is precisely what our own boundary rule
   (elixir `#57` / flutter `#91`) warns about: two copies of one rule diverge,
   and the bug surfaces in whichever copy you weren't reading.
2. **Neither skill loads for anything else.** A Ruby script, a Terraform file,
   a README, a JSON config — none of it triggers either skill, so none of it
   gets the rules that were never language-specific in the first place.

## Goals

- One home for every rule that is not language-specific.
- That home loads whenever we touch a codebase, in any language, including
  edits that are only comments or documentation.
- The two language skills keep their language-specific tells and their existing
  rule numbers.
- No rule is stated in more than one place.

## Non-goals

- Changing any genuinely language-specific rule in either existing skill.
- Introducing a linter or codemod. This is guidance, not enforcement.
- Building a dependency mechanism between plugins (the format has none).

## Decisions

| Question | Decision |
|---|---|
| Scope of the new skill | Full engineering practices — code craft **and** workflow (TDD, atomic commits, green build, PR hygiene) |
| Activation guarantee | `PreToolUse` hook, deduped to one injection per session |
| Hook matchers | `Edit`, `Write`, `NotebookEdit`, and `Bash` — unconditionally |
| What stays in the language skills | The principle moves to core; the language-specific concretization stays behind as a numbered stub |
| Numbering | Language-skill numbers are preserved. Core rules are `core #0`–`core #21` |
| Packaging | Its own plugin — it must load in repos with no Elixir and no Flutter |
| Structure | One skill, `SKILL.md` + `reference.md`, mirroring the existing two |

Workflow rules are restated here even though they overlap the maintainer's
personal `CLAUDE.md`: teammates installing the plugin do not have that file.

## Architecture

### Package layout

```
plugins/colette-code-conventions/
├── .claude-plugin/plugin.json
├── hooks/
│   ├── hooks.json
│   ├── inject-conventions.sh
│   └── inject-conventions.test.sh
└── skills/colette-code-conventions/
    ├── SKILL.md
    └── reference.md
```

`SKILL.md` mirrors the structure of the existing two: Overview → core
principles → Rule 0 → highest-risk rules with bad/good snippets → numbered
checklist → red flags → "also enforced mechanically".

### Activation

`hooks/hooks.json` declares two entries:

- `PreToolUse`, matcher `Edit|Write|NotebookEdit|Bash` → `inject-conventions.sh`
- `SessionStart`, matcher `startup|resume|clear|compact` →
  `inject-conventions.sh --reset`

`inject-conventions.sh` reads the hook payload on stdin, extracts `session_id`,
and checks for a marker at
`${CLAUDE_PLUGIN_DATA:-$HOME/.claude/colette-code-conventions}/sessions/<id>`.

- Marker absent → create it, print the injection JSON.
- Marker present → print `{}`.
- `jq` missing, stdin malformed, `session_id` absent, or any other error →
  print `{}` and exit 0.

**Fails open, always.** A broken hook must never block an edit.

The injection payload is:

```json
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "..."}}
```

with **no** `permissionDecision` key, so the normal permission flow is
untouched. This contract is verified against a working implementation:
`vercel/0.45.1/hooks/pretooluse-skill-inject.mjs:524`. The per-session dedup
and `SessionStart` reset pattern follows
`vercel/0.45.1/hooks/session-start-seen-skills.mjs:48`.

`additionalContext` carries an instruction, not the rules: invoke the
`colette-code-conventions` skill before proceeding, and note that it governs
every file in the repo regardless of language, comments and docs included.
Keeping it to ~3 lines means the skill body carries the weight.

As a secondary, non-guaranteed path, `SKILL.md` frontmatter also sets a broad
`description` and `file_patterns: ["**/*"]`, so the skill remains selectable the
ordinary way.

## The core rules

Continuous numbering across lettered sections, cited as `core #N`.

### § Code

| # | Rule | Source |
|---|---|---|
| 0 | **English only** — identifiers, files, comments, tests, logs, errors, migrations, commits, PRs. Sole exception: translated *values* in a message catalogue (`.po`, `app_fr.arb`), whose keys and metadata stay English. Not grandfathered — rename as you touch. | elixir `#0` + flutter `#0` |
| 1 | Match the surrounding code — consistency outranks individual preference | both Overviews |
| 2 | Single level of abstraction — one thing at one altitude, extract named helpers, no nested conditionals | elixir HR`#5`, `#23` |
| 3 | Intention-revealing names, no abbreviations | elixir `#26` |
| 4 | YAGNI — no speculative abstraction, no unused param/flag/config for a future caller | *new* |
| 5 | Name the value before you use it — bind a computed value to a variable before putting it in a literal | elixir `#33` |
| 6 | Accept the narrowest input you need — take the id, not the whole entity | elixir `#32` |
| 7 | Be exhaustive in branching — enumerate real shapes, no blanket catch-all | elixir `#20` + flutter known-errors-first |
| 8 | **Never swallow a failure** — propagate fallible results, never a hardcoded success; every branch returns the same shape | elixir `#21` + flutter HR`#1`/`#7` |
| 9 | Typed errors, never raw strings — define the error type before returning it | elixir `#38` + flutter typed exceptions |
| 10 | One error pipeline per app — map once at the boundary, propagate in between | flutter principle 2 + elixir `ErrorHandler` |
| 11 | Mirror the contract exactly — optionality and cardinality flow through every layer unchanged | flutter principle 1, generalized |
| 12 | **Application boundaries** — no reaching into another app's data, no branching on the caller, no re-implementing the other side's rule, no documenting another app's behaviour | elixir `#57` + flutter `#91` |
| 13 | **Change hygiene** — delete what the edit made pointless; comments current; never backward-looking | elixir `#56` + flutter `#90` |
| 14 | Document the public API and keep it true — a doc unverifiable from this repo is a boundary leak (→ `#12`) | elixir `#28`, generalized |
| 15 | **Self-contained tests** — one group per unit; arrange inside the test body; setup for harness wiring only; no magic shared fixtures; duplication over indirection; readable detached from its file | elixir `#53`/`#54` + flutter `#76`/`#82`/`#83` |

### § Workflow

| # | Rule | Source |
|---|---|---|
| 16 | Test first — the failing test defines the behaviour | maintainer `CLAUDE.md` |
| 17 | Small steps, always releasable | maintainer `CLAUDE.md` |
| 18 | Green build before commit — format, lint, tests; each language skill names its own commands | both "also enforced mechanically" |
| 19 | Atomic commits, semantic prefixes (`feat:`/`fix:`/`docs:`/…), English | `CLAUDE.md` + git history |
| 20 | PR hygiene — what changed and why, in English; cite the convention number on convention changes | git history |
| 21 | Isolate work — branch or worktree per unit of work | maintainer `CLAUDE.md` |

Two entries are not lifted from an existing rule and were approved as
additions: `#4` (YAGNI) is new, and `#14` generalizes Elixir's `@moduledoc`
rule, which Flutter has no counterpart for. `#11` generalizes Flutter's
GraphQL-shaped contract principle to "any published contract".

### Highest-risk six

Rule 0, `#8` never swallow, `#13` change hygiene, `#15` self-contained tests,
`#12` boundaries, `#2` abstraction levels — each gets a bad/good snippet.

Snippets rotate across real languages (Elixir, Dart, TypeScript, Python, SQL)
rather than using pseudocode. Real code is more credible, and rotating
reinforces that these rules belong to no single stack. `reference.md` carries
the longer worked examples.

## Stub conversion

Uniform format — number preserved, rule name, pointer, then only the
language-specific tells:

```markdown
56. **Change hygiene** → `core #13`. Elixir tells: a helper collapsed to
    `defp f(x), do: x` gets inlined at its lone call site and removed; an
    unreachable clause and an unused `@attr` get deleted.
```

Every stub keeps its current number, so `#56`, `#90`, `#91` and existing commit
references such as `(#57/#91, …)` remain valid. Nothing renumbers.

### Elixir — 12 stub entries, covering 14 rules

| Rule | → core | Tells that stay |
|---|---|---|
| `#0` Rule 0 | `#0` | `@moduledoc`/`@doc`, `describe`/`test` names, typed-error fields, migration/index names, seed labels; Gettext `.po` values the sole exception; the French/English snippet |
| HR`#5`, `#23` | `#2` | ~10–30 lines, extract `defp`s |
| `#20` | `#7` | blanket `_ ->` in `case`/`with`; chainable query fallthrough is the exception |
| `#21` | `#8` | `Repo.*`/`Oban.insert`; no-op head returns `{:ok, nil}`, never bare `:ok` |
| `#26` | `#3` | predicates `?`, raising `!`, snake_case/PascalCase |
| `#28` | `#14` | `@moduledoc false` for internal, `@doc`/`@spec` on public API |
| `#32` | `#6` | the `%Schema{id: id}` head delegating to the id head |
| `#33` | `#5` | the map-literal example |
| `#38` | `#9`, `#10` | `use MyApp.ExErrors`, `defexerror`, define-then-return, `extensions.errorCode`/`fields` |
| `#53`, `#54` | `#15` | `describe "fun/arity"`, setup for Mox/conn/sandbox only, no `@valid_attrs`, the referral bad/good pair |
| `#56` | `#13` | `x -> x` helper, unreachable clause, unused `@attr` |
| `#57` | `#12` | second `Repo` at another service's DB, schema mirroring a table we don't own, `if client == "mobile"`, per-endpoint split (`#35`) |

Untouched: layering `#1`–`#10`, Ecto/Query `#11`–`#17`, `if`/`cond`/`maybe_*`
HR`#1`, `JSON`-not-`Jason` HR`#4`, `Map`/`Keyword` `#34`, GraphQL `#35`–`#42`,
events and workers `#43`–`#48`, and the whole concurrency section `#55`.

### Flutter — 8 stub entries, covering 10 rules

| Rule | → core | Tells that stay |
|---|---|---|
| `#0` Rule 0 | `#0` | ARB keys + en `@`-descriptions, `AppRoutes` values, `Palette` entries; `app_fr.arb` *values* the sole exception; the Dart snippet |
| principle 1 | `#11` | the full GraphQL-nullability rule — non-null lists are `final List<T>` + `const []`, nullability flows model → repo → state |
| principle 2 | `#8`, `#10` | mapping lives once in `GraphqlService`; repos `rethrow` only |
| HR`#1` | `#8` | the exact two-line `Bloc.observer.onError` idiom; known typed errors first |
| HR`#7` | `#10` | "the bare `try/catch/rethrow` is intentional — do not clean it up" |
| `#76`, `#82`, `#83` | `#15` | `test/` mirrors `lib/`, file-local `_wish(...)` factories, `group("<method>")`, no `bloc_test`, `fakeAsync` |
| `#90` | `#13` | wrapper widget returning only its child, dead state field still in `copyWith`/`props`, orphaned ARB key in both files |
| `#91` | `#12` | no backend internals, no hardcoded URL/key (`#85`), no raw HTTP past `GraphqlService` (`#16`), no hand-synced copied file |

Untouched: cubit architecture, state discipline, `loadingId`, list-reference
emission, `copyWith(field: null)`, repos and GraphQL, models and enums, screens
and widgets, routing and theme, localization, DI.

Red flags get the same treatment in both skills: generic lines move to the core
skill's red-flag list, lines naming a language construct stay put.

Each language skill's Overview gains one line stating that it assumes
`colette-code-conventions` is loaded and carries the language-agnostic rules.

## Versioning and packaging

- new plugin `colette-code-conventions` at `0.1.0`
- `elixir-phoenix-conventions` `0.2.12` → `0.3.0`
- `flutter-conventions-guide` `0.2.4` → `0.3.0`

Minor bumps, since this restructures rather than adds.

`.claude-plugin/marketplace.json` gains the third entry and both version bumps.
`README.md` gains the plugin in its list and states that core is a prerequisite
for the other two.

## Verification

### 1. Hook script — `hooks/inject-conventions.test.sh`

Dependency-free bash. Written before the script itself (`core #16`).

| Given | Expect |
|---|---|
| first call, valid `session_id` | JSON with `hookEventName: "PreToolUse"` + `additionalContext`, exit 0 |
| second call, same session | `{}`, exit 0 |
| `--reset` then call again | injection JSON again |
| different `session_id` | injection JSON |
| `jq` unavailable | `{}`, exit 0 |
| malformed or empty stdin | `{}`, exit 0 |
| no `session_id` in payload | `{}`, exit 0 |
| any call | output never contains `permissionDecision` |

The last case is load-bearing: a regression there would silently auto-approve
every edit in every repo that installs this.

### 2. Manifest validation — `scripts/validate-manifests.sh`

All three `plugin.json` files and `marketplace.json` parse; every marketplace
`source` path exists; every marketplace `version` equals the matching
`plugin.json` version.

### 3. Reference integrity — `scripts/check-references.sh`

- every `core #N` cited in either language skill exists in the core skill
- core rule numbers are unique and contiguous 0–21
- every intra-skill `#N` reference resolves within its own skill
- every core rule is cited by at least one language skill, or carries an
  explicit `core-only` tag on its rule line. The core-only set is `#4` (YAGNI)
  and the whole Workflow section, `#16`–`#21`; any other uncited core rule is a
  failure

### 4. CI

A GitHub Actions workflow runs all three scripts on pull request. The repo has
no CI today; reference integrity is exactly the kind of thing that rots
invisibly.

### 5. Manual acceptance

Not automatable, run once before merge:

1. Install all three plugins locally.
2. Open a repo that is neither Elixir nor Flutter.
3. Edit a `.md` file → the skill loads.
4. Edit a second file → no second injection.
5. `/clear`, then edit → the injection re-arms.

## Risks

**Dangling references on partial install.** The plugin format has no dependency
declaration, so installing only `flutter-conventions-guide` leaves stubs
pointing at `core #N` rules that are not present. Mitigated three ways: the
README states core is a prerequisite, each language skill's Overview says so,
and both marketplace descriptions say so. The failure mode is a dangling
reference, not a crash — the language skill still reads, it just loses the why.

**Context cost on first edit.** Every session that touches a file pays the core
skill's load. Bounded by the per-session dedup and by keeping the injected
payload to an instruction rather than the rules themselves.

**Hook coverage is not total.** A file changed by a process the hook cannot see
— an external editor, an MCP server's own write tool — gets no injection. The
`file_patterns` frontmatter is the fallback; there is no way to close this
fully, and it is accepted.
