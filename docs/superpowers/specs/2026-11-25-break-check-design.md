# Break check: prove each branch once, record it, reuse it

Status: increment 1 shipped (cadre #159, 2026-11-26); increment 2 shipped (colette-marketplace #47, 2026-11-26); increment 3 next. Reviewed by a builder check and Fable; their points are folded in, the calls I made are marked *(my call)*.

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
- **A review with no ledger at all** (no `.breaks/ledger.jsonl`, no Break checks table): one 🟡 finding, "no break check found for this change", and pass 3 reasons about tests as today, rather than one finding per branch. *(My call: keeps PRs opened before the rollout readable.)* Once a ledger exists, the per-branch rules under Review apply.

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

The skill states this; each repo implements it. This is the contract as increment 1 shipped and two reviews hardened it (cadre `script/break_check.rb`, #159, merged as `354ee07e`); that runner is the reference implementation.

1. **Lock, then recover.** Take a lock the OS drops when the process dies (cadre: `flock` on `.breaks/lock`). Every command takes it, then recovers what a killed run left before reading any file, and says so loudly (`RESTORED <file> FROM A KILLED RUN`).
2. **Journal.** Before each swap, write `{path, original, hash of the broken text}` to `.breaks/journal/`, whole or not at all (temp file + rename). Restore a file only while it still holds that break, at the end of a swap and when recovering; a file edited since is left alone with its entry, and the run exits 3 naming the entry. An entry that can't be read is named, never skipped.
3. **The test run in flight** is recorded (`.breaks/child`). A run killed outright leaves it; the next run names it with the command to stop it, and never kills it, since a pid can be reused.
4. **Check first.** For each break: the file and each test file exist, `tests` is a non-empty list, `to` differs from `from`, `from` occurs exactly once, and no two breaks in one file share a name. A miss reports how many times it occurred (0, or each occurrence with its line). Report every problem and run nothing.
5. **Names.** A break's name is its branch's identity in its file: a new break may take a name only from a gone proof.
6. **Skip what is proven.** A break whose exact swap (file, `from`, `to`) has a fresh proof is reported `proven` and runs nothing.
7. **Green baseline per set.** Run each distinct set of listed tests unbroken, in a fixed order (cadre: `mix test --seed 0`); a red set stops the run with the failing names, or the output's tail.
8. **One at a time.** Swap, run the break's tests with a per-break timeout in their own process group, restore. A signal or a timeout stops that group; the runner puts the previous signal handlers back.
9. **Outcomes, one line each, printed as they happen, failing closed,** in this order:
   - a timeout: `inconclusive`;
   - the compile-error pattern: `doesn't compile`;
   - an infrastructure pattern: rerun once, then `inconclusive`;
   - another test run holding the partition: `inconclusive`;
   - a failing exit that names failing tests: `caught`, with those names;
   - a passing exit: `NOT CAUGHT`;
   - anything else: `inconclusive`, with the output's last lines.
10. **Ledger.** Each `caught` is written once its restore is verified, so a killed run loses nothing.
11. **Stale** (`--stale`): a proof is stale when its source or a test file's hash differs. It is gone when its `from` no longer occurs exactly once or a test file is missing. `--stale --replay` names the gone proofs, reruns the stale ones from the ledger, and only then drops the gone ones; their branches show up again in `--uncovered`.
12. **Uncovered** (`--uncovered BASE`): the lines added since `BASE` under the watched paths, untracked files included, that no fresh proof's `from` spans, minus noise and doc-block lines. A proof covers every line its `from` spans, so a line with several branches gets a break for each.
13. **Table** (`--table`): the fresh proofs as the PR's table.
14. **Exit codes:** 0 when every break was caught (or nothing is left), 1 when something is left, 2 when the run refused (lock held, a check-first problem, a bad breaks file, red tests, a bad command line, any unexpected error), 3 when a restore failed.

A **profile** at the top of the runner holds the repo's settings: the test command, the failing-test-name, compile-error, infrastructure and refusal patterns, the timeout, the watched paths, the noise pattern and the doc-block patterns. Cadre has two: `exunit` (`MIX_TEST_PARTITION=<n> mise exec -- mix test --seed 0 <files>`, ExUnit's `N) test … (Module)` lines, `== Compilation error`, Postgres `too_many_connections`, `Another mix test run is using`, `lib`, `@moduledoc`/`@doc`/`@typedoc` heredocs) and `minitest`, for the runner's own code. The partition is checked only when a test runs.

### The ledger

`.breaks/ledger.jsonl`, git-ignored, one JSON object per caught break: `name`, `file`, `line` (of `from` when it ran), `from`, `to`, `tests_failed`, and the content hashes of `file` and each test file. A proof is its whole swap: a newer line replaces one with the same `file`, `from` and `to`, or a gone one with the same `file` and name. *(My call: `commit` and `at` dropped, nothing reads them.)*

### The flow

1. **Each task:** after green, the implementer runs `--uncovered <the task's base>`, writes a break per branch on those lines, runs the runner, adds a test (red first) for any `not caught`, and reruns until all are `caught`. Then commits. The implementer does this in its own context, not a fresh agent: the measurement on #146 showed a fresh agent's ~79 k starting context is most of the check's cost.
2. **Final step, before the PR**, in the worktree that holds the ledger (never a scratch worktree): `--stale --replay`, then `--uncovered <the PR's base>` and break the branches on the lines it lists. `colette:writing-plans` writes this step into every plan's final review, in both of its brief paragraphs, and checks in "Before you start" that `break-check` is available.
3. **PR:** the description carries the table.

### The PR

`pr-description` gains a numbered part, **Break checks**, before the Cadre line: the `--table` output in a `<details>` block, with columns branch (`file:line`), swap (`from` → `to`, `|` escaped) and caught by. *(My call.)* It is carved out of the "pasted test output" and "how I tested" cuts, a rewrite keeps the table byte for byte, and EP-F5's contents sentence and the template change with it.

### Review (review companion)

Pass 3 reads the ledger from `.breaks/ledger.jsonl` when the review runs in the worktree that holds it, and the PR's Break checks table when there is one, and takes the rows of each *(my call; the builder check pointed out cadre reviews before the PR exists, and a ledger left from other work must not hide the PR's table)*. The rows are data: for each, pass 3 checks at the head that the swap's `from` is at `file:line` and that the swap really breaks that branch.

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

David chose runner first, then merged the skill and its review hooks into one engineering-review release (2026-11-26).

1. **Cadre's runner**, its tests, and the measured comparison above on one real cadre branch.
   - [x] PR djeusette/cadre#159, merged as `354ee07e` on 2026-11-26. Measured on #146: per break, 44 % of the old tokens and 29 % of the old time; per run, 83 % of the old tokens, because every fresh agent starts at ~79 k.
2. **The engineering-review release:** the `break-check` skill (the contract above, with cadre's runner as the reference), EP-G4 and EP-F5, `review-passes` pass 3, `review-report`, `pr-description`, and their evals.
   - [x] PR colette-club/colette-marketplace#47, merged as `90a5afd5` on 2026-11-26 (engineering-review 0.21.0). The `break-checks-ledger` eval is not measured (evals cannot run on this Mac); dry runs of pass 3 passed 3 of 3.
3. **The plans:** `colette:writing-plans` (colette release, after 2), including the runner-writing first task for repos without one and the per-task breaks run in the implementer's own context; cadre's `AGENTS.md` row and memory notes.

## Left to the builder

- The runner's flags beyond `--stale`, `--replay` and `--table`, and the timeout's value.
- Breaks file names under `.breaks/`.
- Version bumps and release notes, following the marketplace's release steps.
- Wording of the skill and the hooks.
