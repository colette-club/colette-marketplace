# EP catches the live-room defects — plan

**Goal.** The `engineering-review` companion reports, at checkpoint 3, at the right severity and citing the right rule,
every defect that shipped in colette-api #2168 (joining an online activity's live room), plus the ones David's commits
on that PR fixed. A finding under these rules keeps its severity when the author gives a reason; only the rules that
ask for a reason (EP-D12, EP-I3) are cleared by one.

**Language.** `engineering-principles` stays language-neutral: rules and red flags name no Elixir or Dart construct.
`reference.md` keeps its pseudocode → Elixir → Dart pairs. Elixir-only wording goes in `elixir-phoenix-conventions`,
which the companion applies only to Elixir code. Fixtures are Elixir; the evals load only `engineering-review`, so the
graders check EP IDs.

**Method (writing-skills TDD).** All six recall cases are written first and run on `main` (baseline, red). Then each
PR changes the skills and turns its case green (each case ≥ 0.67 over 3 runs); `clean-change` and `deadlocks-clean`
must stay green. Evals cannot run inside this nono sandbox (it denies `~/.aws`, which `claude plugin eval` must vet
for a Bash-granting run): the person runs them in a normal terminal and the results are read from `evals/results/`.

## PRs, rules and cases

| PR | Defects (colette-api #2168) | Rules | Case → fixture |
|---|---|---|---|
| 1 Unused code and migrations | 1 code for the next PR (unread columns, unconsumed event, unwritten state + its branch); 2 edited migration | EP-D8 rewritten as the reader check and made highest-risk; EP-I4 points to it; new EP-I6 (a migration that may have run is final) | `live-unused-recall` → `live-unused` |
| 2 External services and config | 12 provider reached without the adapter, provider payload in the domain; config not checked at boot | EP-D6 (adapter: app-owned contract, the adapter translates payloads and reads its own settings); new EP-E6 (settings checked at boot where the component is on) | `live-adapter-recall` → `live-adapter` |
| 3 Events and recorded facts | 3 one rule per actor; 4 fact re-derived at job time; 5 event on every heartbeat; 11 rows change meaning, readers unchecked | EP-D10 (variant as data on one path); new EP-H14 (events and rows carry the facts as they were); EP-H10 (liveness writes publish nothing); new EP-I7 (a change to what rows mean names every reader, stacked PRs included) | `live-events-recall` → `live-events`; 11 graded in `live-unused-recall` |
| 4 Errors and constraints | 6 constraint not turned into an error (webhook 500); 7 `get_*` returning null, `ok(null)` | EP-H3 (every constraint a write can hit maps to a typed error at that write); EP-C1; EP-G4 (an endpoint's promise for every input has a failure-path test); EP-A2 (a convention family's contract); EP-C2 (no success wrapper around a possible null) | `live-errors-recall` → `live-errors` |
| 5 Tests | 9 environment-dependent behaviour untested; 10 branches no test fails on | EP-G4 (per branch, the test that fails; environment set to a non-default value) | `live-tests-recall` → `live-tests` |
| 6 Queries and idioms | 8 raw SQL naming tables; the repo's idiom (env default, config wrapper); the domain's verb (mint vs issue) | new EP-K11 (query builder constructs; raw SQL only for the fragment it cannot express); new EP-D13 (same job, same idiom; a convention family keeps its contract); EP-A2 | `live-queries-recall` → `live-queries` |

The companion: each unused piece is its own confirmed 🟠 finding at checkpoint 3 (EP-D8) that no reason clears;
checkpoint 2 still stops a change holding a second feature, or one that adds no feature at all
(`gate-large-preanswered`).

## Fixture conventions

- `App` namespace, `use App.Schema, :schema`, `use App.Query`, ExEventBus events through `Repo.insert(success_event:)`,
  typed errors `App.Errors.*`, PostgreSQL. Each fixture is one feature, so checkpoint 2 does not stop it.
- Everything outside the planted defects is clean: no other rule should fire. Tests exist and look thorough.
- Prompts pre-answer every checkpoint-1 and checkpoint-2 question and leave `writes` out (stops at checkpoint 3). The
  pre-answered intent and necessity carry the author's real reasons ("the next PR needs it"), never rule IDs
  (`check_plugin.py` checks rule IDs in prompts).
- Graders: one per defect, `regex` on finding lines, `F-\d+ (?:🔴|🟠)(?![^\n]*conditional)[^\n]*EP-XX[^\n]*<anchor>`;
  plus `stopped-at-checkpoint-3`, `no-reviews-dir`, `no-memory-file`, `no-gitignore`.

## Run

Outside nono, from the repository root, with a real git first on `PATH` on macOS:

```bash
claude plugin eval plugins/engineering-review --case 'live-*' --runs 3 --ablation none --scaffold --trust-plugin \
  --allow-tools "Bash(git *)" Write --no-publish --judge-model sonnet -j 4 --json /tmp/ep-baseline.json
```

## Outcome

The six PRs shipped the rules, red flags, examples and companion steps above. The recall cases were written but never
measured: on the Mac used, `xcode-select` points at Xcode, so the review's `git` (the `/usr/bin` shim) asks `xcodebuild`
and exits 72 inside the eval sandbox, and every run stopped at checkpoint 1. The cases were dropped; the evals README
says how to give the review a real git before writing new ones.
