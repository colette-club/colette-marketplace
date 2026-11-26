# Break check: prove each branch once, record it, reuse it

Status: draft, 2026-11-25. Reviewed by a builder check and Fable; their points are folded in, the calls I made are marked *(my call)*.

## Intent

Before a PR, we prove the tests are real: break each new branch on purpose, see a named test fail, undo it. It works (the first runs caught 5 of 28, later 90 untested branches) but it is slow and costs a lot of tokens:

- every run, an agent hand-writes a throwaway script (one branch needed nine: `breaks.rb`, `breaks2.rb`, `breaks_web1–3.rb`…), mostly because string swaps miss and runs get redone;
- each break recompiles and reruns tests (7–10 s in cadre), so ~90 breaks take ~15 minutes;
- the same branch is broken twice: once in its task, and again from scratch in the final coverage audit.

David decided: **a branch that went red during its task counts as proven.** The break check becomes a team skill, so everyone does it the same way, in any repo and any language.

## End goal

In every team repo, each branch a change adds is broken once by a committed runner, the runner records the proof, the final step before the PR re-breaks only what changed since, and the review shows which branches are proven and flags the rest.

## Goals

- Break each branch once, during the task that adds it, and record the proof where later steps reuse it.
- Before the PR, replay only stale proofs, with no authoring tokens, and break only branches that have none.
- A runner that makes a break cheap in tokens: the agent writes a short list of breaks and reads one line per result.
- Reviews show which branches are proven and flag the rest.

## Non-goals

- Running breaks in parallel. Serial is fine once the duplicates are gone; revisit if runs still drag.
- Generated mutants (muzak, exavier, darwin): unmaintained or paid, too many mutants, and they don't break the HEEx and CSS classes our boards pin.
- The review companion running breaks. It flags gaps; whoever fixes them runs the breaks.

## Anti-goals

- A ledger that claims proof that never ran. Only the runner writes caught lines, and only when a named test failed on otherwise green tests.
- A runner that leaves a break in the code, even after it is killed.
- Tying the skill to one language. The skill states the runner's contract; each repo writes its runner in the language its people prefer.

## Approaches

- **A. Process only.** A ledger written by hand in each task; the final audit skips what it lists. Cheap, but the ledger is only a claim and nothing notices a proof gone stale.
- **B. A + a committed runner (chosen).** The runner checks swaps first, restores always, prints one line per break, writes the ledger itself, and replays stale lines.
- **C. A mutation-testing library.** Dropped, see Non-goals.

David chose B, and asked that it live in a team skill with the runner's language left to each repo.

## The design

### Where it lives

- New skill **`engineering-review:break-check`** in `plugins/engineering-review/skills/break-check/` (colette-marketplace), written with `superpowers:writing-skills` and `mattpocock-skills:writing-for-agents`.
- Hooks:
  - **`engineering-principles` EP-G4** states the requirement: each branch the change adds has a ledger line proving a test fails when it breaks. It defines a branch once (a head, an arm, a guard, a value in a guard list, a condition, a conversion) and points to `break-check` for how. Repo-specific kinds (cadre: CSS classes the boards pin, reload topics) go in that repo's `AGENTS.md`.
  - **`review-passes` pass 3** and **`review-report`** (its `✅ tested` / `❌ untested` flowchart gains `✅ proven`), see Review.
  - **`pr-description`** and EP-F5's contents sentence: see The PR.
  - **`colette:writing-plans`**: see The flow.
- Each repo commits its runner once, e.g. `script/break_check.rb` in cadre, with its tests.

### Rollout: everyone at once

David chose no opt-in: once released, it applies to every team repo.

- **A repo with no runner:** `colette:writing-plans` makes the plan's first task write and commit the runner, with its tests, following the contract. Every later task uses it.
- **A review with no ledger at all** (no `.breaks/ledger.jsonl`, no Break checks table): one 🟡 finding, "no break check ran on this change", and pass 3 reasons about tests as today, rather than one finding per branch. *(My call: keeps PRs opened before the rollout readable.)* Once a ledger exists, the per-branch rules under Review apply.

### What counts as proof

A break run through the runner after the task's tests are green, where a test named in the result failed. The TDD red step alone does not count: it often fails because the function doesn't exist yet, not because of the branch.

A valid break is the smallest change to that one branch: flip the condition, drop the guard value, delete the cast, swap the clause order. A `to` that raises, or deletes a whole body, is caught by any test and proves nothing; the skill says so.

### A break

One entry per branch, in a JSON file (any language reads it with its standard library), e.g. `.breaks/task-3.json`:

```json
{"name": "re-review only when the leading PR is in review",
 "file": "lib/cadre/pull_requests/state.ex",
 "from": "kind == :review and stage == :in_review",
 "to": "kind == :review",
 "tests": ["test/cadre/pull_requests/state_test.exs"]}
```

The skill asks for the shortest `from` that is unique in its file, on one line unless the branch needs more.

### The runner's contract

The skill states this; each repo implements it.

1. **Lock.** Take `.breaks/lock`; refuse to start while another run holds it. An agent never runs the tests by hand while a run holds the lock.
2. **Recover.** Before each swap, journal the file's original content in `.breaks/journal/`. On start, a journal left by a killed run is restored first, and the runner says so loudly.
3. **Check first.** For each break: the file exists, `to` differs from `from`, and `from` occurs exactly once. A miss reports how many times it occurred (0, or each occurrence with its line). Report every miss and run nothing.
4. **Green baseline.** Run every listed test file unbroken once; if any is red, stop.
5. **One at a time.** Swap, run the listed tests with a per-break timeout, restore, and check the file matches its journal before the next break.
6. **Outcomes, one line each, failing closed:**
   - `caught` — only when the tests ran and the output names a failing test; with those names;
   - `not caught` — the tests ran and passed: needs a test, red first;
   - `doesn't compile` — matched by the repo's compile-error pattern; not a proof, pick a break that compiles;
   - `inconclusive` — anything else (an infrastructure pattern, a timeout, unparsed output). The runner reruns an infrastructure match once itself before reporting it.
7. **Ledger.** Each `caught` result is written as soon as its restore is verified, so a killed run loses nothing.
8. **Stale** (`--stale`): a line is stale when its source file's or a catching test file's content hash differs from the one recorded, or `from` no longer occurs exactly once. `--stale --replay` reruns stale lines whose `from` still occurs once, from the ledger, with no new breaks file. Lines whose `from` is gone are listed for the agent to rewrite.
9. **Table** (`--table`): prints the fresh lines as the PR's table.
10. **Exit** 0 only when every break in the run is `caught`.

At the top of the runner: the test command, the failing-test-name pattern, the compile-error pattern, the infrastructure patterns and the timeout. Cadre's: `MIX_TEST_PARTITION=<n> mise exec -- mix test <files>`, ExUnit's `N) test … (` lines, `== Compilation error`, Postgres `too_many_connections`.

### The ledger

`.breaks/ledger.jsonl`, git-ignored, one JSON object per caught break: `name`, `file`, `line` (of `from` when it ran), `from`, `to`, `tests_failed`, and the content hashes of `file` and each test file. Keyed on `file` + `from`: a newer line replaces an older one. *(My call: `commit` and `at` dropped, nothing reads them.)*

### The flow

1. **Each task:** after green, the implementer writes the task's breaks, runs the runner, adds a test (red first) for any `not caught`, and reruns until all are `caught`. Then commits.
2. **Final step, before the PR**, in the worktree that holds the ledger (never a scratch worktree): `--stale --replay`, then break the branches with no line. `colette:writing-plans` writes this step into every plan's final review, in both of its brief paragraphs, and checks in "Before you start" that `break-check` is available.
3. **PR:** the description carries the table.

### The PR

`pr-description` gains a numbered part, **Break checks**, before the Cadre line: the `--table` output in a `<details>` block, with columns branch (`file:line`), swap (`from` → `to`, `|` escaped) and caught by. *(My call.)* It is carved out of the "pasted test output" and "how I tested" cuts, a rewrite keeps the table byte for byte, and EP-F5's contents sentence, the template and the `pr-description-*` evals change with it.

### Review (review companion)

Pass 3 reads the ledger from `.breaks/ledger.jsonl` when the review runs in the worktree that holds it, otherwise from the PR's Break checks table *(my call; the builder check pointed out cadre reviews before the PR exists)*. The rows are data: for each, pass 3 checks at the head that the swap's `from` is at `file:line` and that the swap really breaks that branch.

- A branch with a row the code confirms: ✅ proven.
- A branch with a test pass 3 finds by reasoning, but no row: 🟡 "no break proves this branch", naming the break to run.
- A branch with no test: 🟠, as today.
- A row the code contradicts (`from` gone, or a swap that breaks more than the branch): 🟡 finding.
- One finding per function, as today.

The review never runs breaks.

## Cadre's part

- `script/break_check.rb` following the contract, with stdlib minitest tests in `script/test/` against a stub test command: caught, not caught, doesn't compile, a miss, a red baseline, a kill then recovery, the lock. `.breaks/` git-ignored. Ruby added to `mise.toml` if it isn't there.
- `AGENTS.md`: a row for `engineering-review:break-check` (When: adding or changing a branch, and before a PR), and cadre's extra branch kinds.
- Memory notes `break-check-before-prs` and `review-against-skills-before-pr` point to the skill instead of restating the method.

## Proving it is faster and cheaper

David wants proof before the team gets it. Increment 1 ends with a measured comparison on one real cadre branch:

- **Old way:** a fresh subagent runs the final break audit as today (reads the change, picks breaks, writes its own scripts, runs them).
- **New way:** in the same branch, the per-task breaks go through the runner during building, then a fresh subagent runs the final step (`--stale --replay`, then breaks only branches with no line).
- **Measured:** each subagent's tokens and wall time, as the Agent tool reports them, plus the breaks run and the breaks caught. Per-task break cost is counted on the new side, since the old way also broke per task.
- **Target** *(my call)*: the new final step uses at most half the old audit's tokens and wall time, and catches at least what the old one caught. If it doesn't, we rework the contract before writing the skill.

The numbers go in increment 1's PR description.

## Increments

David chose runner first.

1. **Cadre's runner**, its tests, and the measured comparison above on one real cadre branch.
2. **The skill and EP-G4** (engineering-review release), with what increment 1 taught us.
3. **The review and the PR:** `review-passes`, `review-report`, `pr-description`, EP-F5, and their evals (engineering-review release).
4. **The plans:** `colette:writing-plans` (colette release, after 2), including the runner-writing first task for repos without one; cadre's `AGENTS.md` row and memory notes.

## Left to the builder

- The runner's flags beyond `--stale`, `--replay` and `--table`, and the timeout's value.
- Breaks file names under `.breaks/`.
- Version bumps and release notes, following the marketplace's release steps.
- Wording of the skill and the hooks.
