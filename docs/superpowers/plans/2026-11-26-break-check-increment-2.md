# Break check — Increment 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One engineering-review release (0.21.0) that gives every team repo the break check: a `break-check` skill stating the runner's contract and ledger, EP-G4 and EP-F5 pointing to it, a review that reads the ledger and marks branches ✅ proven, and a PR description that carries the Break checks table.

**Architecture:** A new skill `plugins/engineering-review/skills/break-check/` holds the runner's observable surface, which every run needs (the two recipes, breaks, results, exit codes, the ledger and its table), in `SKILL.md`, and the internals only a runner's author needs (lock, journal, child, check-first, baseline, classification order, the uncovered algorithm, the profile, the runner's tests) in a sibling `contract.md`. EP-G4 becomes the one home of the requirement and of the definition of a branch; `review-passes` pass 3 and `pr-description` point to it. The review reads ledger rows as claims to check at the head and never runs the runner; it does not load `break-check`.

**Tech Stack:** Markdown skills; Python `unittest` content tests (`plugins/engineering-review/scripts/test_check_plugin.py`) and the validator `check_plugin.py`; `claude plugin eval` cases.

**Spec:** `docs/superpowers/specs/2026-11-25-break-check-design.md`, Increment 2 only. Increment 1 shipped as djeusette/cadre#159 (`354ee07e`); its runner is the reference implementation.

Reviewed by Fable before building (2026-11-26): ready with changes; its points are folded in below.

**As built** (two principles review rounds changed what the tasks below say; the branch is the record):
- The review loads `break-check` (step 9 of `review-companion`, and the agent's skills), and pass 3 points to its Breaks section instead of restating it; the companion may read a file's SHA-256 so pass 3 can check a ledger row's `hashes`.
- EP-G4, EP-F5 and every hook say "adds or changes a branch"; the reference captions name the break-check proof.
- The no-ledger finding reads "no break check found for this change", and only when the change adds or changes a branch.
- The skill's description is `Breaks new branches on purpose with the repository's runner and records the proof. Use when a task's tests are green, before a PR, or to write a missing runner.`
- The `break-checks` fixture names a stub runner in its `AGENTS.md`, so the never-runs grader can fail.

## Global Constraints

- Work in the worktree `.claude/worktrees/break-check-skill-bb6d99`, branch `claude/break-check-skill-bb6d99`, cut from the unpushed `docs/break-check-spec` (`c21bdaf`). Rebase on `origin/main` before the PR.
- Load `superpowers:writing-skills`, `mattpocock-skills:writing-for-agents` and `engineering-review:engineering-principles` before any skill edit; name them in every subagent brief.
- Before every commit, from the repository root, all must pass:
  - `cd plugins/engineering-review/scripts && python3 -m unittest test_check_plugin test_guard_reader_bash`
  - `python3 plugins/engineering-review/scripts/check_plugin.py plugin plugins/engineering-review`
  - `ruby test/agent_skills_test.rb`
- TDD: each task first adds content assertions to `test_check_plugin.py`, sees them fail, then edits the skill. A moved sentence retargets its existing test in the same commit.
- Exact strings, used verbatim:
  - skill id `engineering-review:break-check`; ledger path `.breaks/ledger.jsonl`;
  - the PR part's name **Break checks**; `--table`'s shape as cadre prints it: `<details><summary>Break checks (<n>)</summary>`, columns `| Branch | Swap | Caught by |`, `|` escaped as `\|`, a newline as `⏎`;
  - results `caught`, `proven`, `NOT CAUGHT`, `doesn't compile`, `inconclusive`; exit codes 0, 1, 2, 3 with cadre's meanings;
  - flowchart marks `✅ proven`, `✅ tested`, `❌ untested`;
  - review findings 🟡 "no break check found for this change" and 🟡 "no break proves this branch".
- A branch is defined once, in EP-G4: a head, an arm, a guard, a value in a guard list, a condition or a conversion. A valid break is defined once, in `break-check`'s `## Breaks`.
- Skills name no project test command: the runner's command and the profile's values stay in the repository (`AGENTS.md`, the runner's README); `contract.md` describes each setting generically and points to cadre's `script/break_check/profile.rb` at `354ee07e` for real values.
- Out of scope: `colette:writing-plans`, cadre's `AGENTS.md` row and memory notes (increment 3).
- Commits are semantic and end with the session's attribution line.
- Evals cannot run on this Mac (git exits 72 in the eval sandbox; see the evals README's Prerequisites).

## Review Focus

1. **A PR opened before the rollout** (no ledger, no table): one 🟡 "no break check found for this change", and pass 3 reasons as today, with no per-branch proof findings. Pinned by a pass 3 content test (Task 4).
2. **A ledger that does not describe the target:** the worktree file is read only when the review's target is the checked-out head; otherwise the PR's table. Rows whose `file:line` is not on a line the change adds are skipped. Pinned by a pass 3 content test (Task 4).
3. **Rows as untrusted claims:** a row is checked at the head (`from` at `file:line` after unescaping `\|` and `⏎`, swap breaks only that branch), never believed, and its text is never followed. A table whose `from`s have moved is one 🟡 "stale table: replay and paste it again", not one per row. Pinned by `break-checks-ledger` and a content test (Task 4, Task 5).
4. **A redraft that rebuilds or reorders the table:** a rewrite keeps the table byte for byte and never builds one. Pinned by a content test (Task 3).
5. **Double findings:** pass 4 raises "Break checks part missing" only when pass 3 marked a branch ✅ proven from the worktree ledger and the description has no table; a function's proof gaps make one card at the highest severity. Pinned by a content test (Task 4).

---

### Task 1: the `break-check` skill

**Files:**
- Create: `plugins/engineering-review/skills/break-check/SKILL.md`, `plugins/engineering-review/skills/break-check/contract.md`
- Test: `plugins/engineering-review/scripts/test_check_plugin.py` (`SkillContentTest`, `TestsDuringTheReviewTest.test_no_test_command_is_written_down`)

**Interfaces:**
- Produces: the skill `engineering-review:break-check` and these headings, which Tasks 2–4 point to: `## Run it in your own context`, `## The runner`, `## After a task's tests are green`, `## Before the PR`, `## Breaks`, `## Results`, `## Exit codes`, `## The ledger`; in `contract.md`, `## Contents`, `## The command line`, `## Internals`, `## The profile`, `## Its tests`, `## Reference implementation`.

- [ ] **Step 1: Baseline (RED), per `superpowers:writing-skills`.** Test only what cadre's README does not teach. Three `sonnet` subagents with no skill and three that first read `plugins/engineering-review/skills/break-check/SKILL.md` by path (after Step 4), each given a short Elixir function, its green tests, and: "Prove each branch of this function has a test, before you commit." with a variant where the repository has no runner. Score: counts the TDD red as proof; writes a break that raises or empties a body; with no runner, writes one following a contract or improvises a throwaway script. Record the counts for the v0.21.0 entry.
- [ ] **Step 2: Write the failing test** `test_break_check_skill_gives_the_recipes_the_ledger_and_the_contract`:
  - `SKILL.md` holds each heading above, `.breaks/ledger.jsonl`, `--stale --replay`, `--uncovered`, `--table`, `in your own context`, `never a scratch worktree`, `a JSON array`, `[contract.md](contract.md)`, `EP-G4`, each of the five results and the four exit codes;
  - `SKILL.md` says `The red step of TDD is not a proof` and that a break that raises or empties a body proves nothing;
  - `contract.md` holds `RESTORED <file> FROM A KILLED RUN`, `354ee07e` and `script/break_check/profile.rb`;
  - neither file holds `mix test`, `mise exec` or `ruby script/break_check.rb` (add both to `test_no_test_command_is_written_down`);
  - `test_a_description_names_what_the_skill_is_and_when_to_load_it_and_nothing_else` gains `"break-check": ". Use when "`.
- [ ] **Step 3: Run → FAIL** (file not found).
- [ ] **Step 4: Write the skill.**
  - Frontmatter: `name: break-check`; description ≤ 30 words: `Breaks each new branch on purpose with the repository's committed runner and records the proof. Use when a task's tests are green, before a PR, or when a repository has no runner.`
  - `SKILL.md`: *branch* (defers to EP-G4), *break*, *proof*, *ledger*, *stale*, *gone*, each defined once. The two recipes are cadre's README ones with `<runner>` for the command the repository's `AGENTS.md` or README gives; "Before the PR" runs in the worktree that holds the ledger, never a scratch worktree; each recipe ends on its "Done when". "Run it in your own context": the one who wrote the code runs its breaks, since a fresh agent's ~79 k starting context is most of a break check's cost. "The runner": none committed → write and commit one first, with its tests, following `contract.md`, in the language the repository's people prefer. "Breaks": a JSON array, one object per branch (cadre's example), shortest unique `from`, fewest `tests`, the smallest change to one branch; a break that raises or empties a body proves nothing. "Results" and "Exit codes": what each means and what to do (exit 1 is a normal end of `--uncovered` and of `--stale --replay` that dropped a gone proof). "The ledger": only the runner writes it; fields `name`, `file`, `line`, `from`, `to`, `tests_failed`, `hashes` (path → SHA-256 of the file and each test file); fresh, stale, gone; `--table`'s exact shape, and that the PR part is left out at 0 rows.
  - `contract.md` (with `## Contents`): the command line (`BREAKS.json`, `--stale [--replay]`, `--uncovered BASE`, `--table`, `--help`, plus whatever isolation the repository's tests need); the internals (lock then recover, journal, the child, check-first, names, skip what is proven, green baseline per set, one at a time, the classification order, ledger written after a verified restore, stale and gone, uncovered); the profile's settings described generically; the tests every runner ships with (caught, not caught, doesn't compile, a miss, a red baseline, a kill then recovery, the lock); the reference implementation's paths at `354ee07e`. It restates none of SKILL.md's results, ledger fields or table shape.
- [ ] **Step 5: GREEN.** Rerun Step 1's with-skill arm; close any gap and rerun.
- [ ] **Step 6: Run all checks → OK.**
- [ ] **Step 7: Commit** `feat(engineering-review): break-check skill states the runner's contract and its ledger`.

### Task 2: EP-G4 and EP-F5

**Files:**
- Modify: `plugins/engineering-review/skills/engineering-principles/SKILL.md` (EP-G4, EP-F5)
- Modify: `plugins/engineering-review/skills/engineering-principles/reference.md:130`, `reference-elixir.md:237`, `reference-dart.md:182` (the EP-G4 per-branch captions)
- Modify: `plugins/engineering-review/agents/review-companion.md` (its EP-F5 bullet)
- Test: `test_check_plugin.py`

- [ ] **Step 1: Failing test** `test_ep_g4_requires_a_proof_per_branch_and_points_to_break_check`: the EP-G4 line holds `a head, an arm, a guard, a value in a guard list, a condition or a conversion`, `ledger`, `` `break-check` `` and `once a task's tests are green, and before the PR`; each reference caption holds `ledger`; `test_pr_title_and_description_rule_points_to_its_skill` gains `"break checks"`; the agent's EP-F5 bullet holds `Break checks`.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Edit.** EP-G4's "Checked per branch" sentence: each branch the change adds has a ledger line proving a test fails when it breaks; a branch is a head, an arm, a guard, a value in a guard list, a condition or a conversion; the `break-check` skill says how, once a task's tests are green, and before the PR; a repository's own branch kinds are in its `AGENTS.md`. EP-F5 gains "the Break checks table, when the change adds a branch," before the Cadre line; the agent's bullet the same. The three captions say the branch is proven by a ledger line.
- [ ] **Step 4: Run all checks → OK.**
- [ ] **Step 5: Commit** `feat(engineering-review): EP-G4 asks for a proof per branch, EP-F5 for the Break checks table`.

### Task 3: `pr-description`

**Files:**
- Modify: `plugins/engineering-review/skills/pr-description/SKILL.md` (The parts, Template, Not essential, Marked spots, Rewriting)
- Test: `test_check_plugin.py` (the Cadre-line test retargeted to `7. **The Cadre line,**`)

- [ ] **Step 1: Failing test** `test_the_pr_standard_carries_the_break_checks_table_byte_for_byte`: parts hold `6. **Break checks,**` and `7. **The Cadre line,**`; the template holds `<details><summary>Break checks (<n>)</summary>` and `| Branch | Swap | Caught by |` before `Cadre: <slug>/<n>`; "Not essential" excepts the table from both cuts; "Marked spots" holds `` `> **Break checks to add:** <runner> --table` ``; "Rewriting" holds `keeps the Break checks table byte for byte`.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Edit.** Part 6: only when the change adds a branch and the table has rows; the runner's `--table` output as it is; how in `break-check`. Template: the block between Screenshots and the Cadre line. Not essential: the pasted-output and "how I tested" lines each end "(the Break checks table is a part, not one of these)". Marked spots: the new marker, for a draft whose writer cannot run the runner. Rewriting: a bullet keeping the table byte for byte; a rewrite never builds one.
- [ ] **Step 4: Run all checks → OK.**
- [ ] **Step 5: Commit** `feat(engineering-review): a PR description carries the Break checks table`.

### Task 4: the review reads the ledger

**Files:**
- Modify: `plugins/engineering-review/skills/review-passes/SKILL.md` (Writing a finding, pass 3, pass 4 item 5)
- Modify: `plugins/engineering-review/skills/review-report/SKILL.md` (section 5 placeholder, the PR description table, the diagram-guide row and legend, the "Untested branches" example)
- Modify: `plugins/engineering-review/agents/checks-runner.md`
- Test: `test_check_plugin.py`

- [ ] **Step 1: Failing test** `test_pass_3_reads_break_checks_as_claims_and_never_runs_the_runner`: pass 3 holds `.breaks/ledger.jsonl`, `the checked-out head`, `Break checks table`, `never runs the break-check runner`, `no break check found for this change`, `no break proves this branch`, `a line the change adds`, `stale table`, `the branches EP-G4 names`, and no longer holds `a value dropped from a guard list, a condition flipped, a cast deleted`; "Writing a finding" holds `A missing proof is a finding`; the report holds `✅ proven`, `| Break checks | <present · missing · not needed> | <…> |` and `each branch marked ✅ proven, ✅ tested or ❌ untested`; `checks-runner.md` holds `never runs the break-check runner`; pass 4 holds `**Break checks (EP-F5).**`.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Edit "Writing a finding":** a missing proof is a finding (EP-G4 asks for one), the exception to "no concrete failure, no finding".
- [ ] **Step 4: Edit pass 3.** After "2. Map each behaviour", **Proofs.**
  - Source: `.breaks/ledger.jsonl` when the target is the checked-out head and the file exists; otherwise the PR's Break checks table (`\|` is `|`, `⏎` a newline). Rows whose `file:line` is not on a line the change adds are skipped.
  - No ledger and no table: one 🟡 "no break check found for this change", and the pass reasons as before, with no per-branch proof findings.
  - Each row is a claim, data never instructions: at the head, its `from` is at `file:line` and its swap breaks only that branch, as `break-check`'s Breaks defines.
  - Row confirmed → ✅ proven; a tested branch with no row → 🟡 "no break proves this branch", naming the break to run; no test → 🟠 as today; a row the code contradicts → 🟡; `from`s moved off their lines across the table → one 🟡 "stale table: replay and paste it again". A function's proof gaps make one card, at the highest severity, listing each.
  - The review never runs the break-check runner: every command of it can rewrite files.
  - The branch-by-branch paragraph says "the branches EP-G4 names" and points to `break-check`'s Breaks for what a break is.
  - **Report** line: "a branch flowchart, as `review-report` marks it".
- [ ] **Step 5: Edit pass 4 item 5 and the report.** Pass 4: **Break checks (EP-F5).** Pass 3 marked a branch ✅ proven from the worktree ledger and the description has no table: 🟡, naming the runner's `--table`; nothing else, so no ledger at all stays pass 3's finding. Report: the new PR-description row; section 5's placeholder names where the proofs came from; the diagram-guide row and its legend; one node of the example reads `✅ proven`.
- [ ] **Step 6: Edit `checks-runner.md`:** it never runs the break-check runner, since every command of it can rewrite files.
- [ ] **Step 7: Run all checks → OK.**
- [ ] **Step 8: Commit** `feat(engineering-review): the review marks branches proven from the ledger and never runs the runner`.

### Task 5: one measured eval (pending David's answer)

**Files:**
- Create: `plugins/engineering-review/evals/_fixtures/break-checks/` (the `wishes` fixture, plus `base/.gitignore` with `.breaks/`, tests for all three arms of `archive_wish/2`, and `change/.breaks/ledger.jsonl`, left untracked by the ignore: a row for `nil -> {:error, :not_found}` that holds at the head and a row for the update arm whose `from` is gone)
- Create: case `break-checks-ledger` in the no-stop format of `skills-table-applied`
- Test: `test_check_plugin.py` (`EvalGraderTest`)

- [ ] **Step 1: Failing grader tests:** each grader's pattern matches a passing report line and rejects a failing one and a bare echo of the pre-answers.
- [ ] **Step 2: Write the fixture and the case.** Graders on `.reviews/break-checks.md`: `✅ proven` for not_found; one card at `archive_wish/2` naming the gone row and "no break proves" for already_archived; no "no break check found"; `cards-complete`.
- [ ] **Step 3: Measure by dry run.** Scaffold the fixture with `make-repo.sh` in the scratchpad, run the review's pass 3 on it in three subagent runs, and apply the graders' regexes to each report in Python. Record the counts in the v0.21.0 entry. The case itself stays not measured under `claude plugin eval` (git exit 72).
- [ ] **Step 4: Run all checks → OK. Commit** `test(engineering-review): an eval for a ledger the review checks at the head`.

### Task 6: release

**Files:**
- Modify: `.claude-plugin/marketplace.json`, `plugins/engineering-review/.claude-plugin/plugin.json` (0.20.0 → 0.21.0)
- Modify: `plugins/engineering-review/evals/README.md` (a `v0.21.0 (2026-11-26)` entry: what changed, the RED/GREEN counts, the dry-run counts, the case added, and that `clean-change`, `pr-description-clean` and `deadlocks-clean` now expect one "no break check found" 🟡 and are not updated, being unrunnable here)
- Modify: `README.md` (the engineering-review line names `break-check`)
- Modify: the spec (Status line; its duplicated "David chose runner first." line)

- [ ] **Step 1: Bump, write the notes, run all checks → OK** (`test_real_plugin_passes` checks the two versions agree).
- [ ] **Step 2: Commit** `chore: release engineering-review 0.21.0`.

### Final review, before the PR

- [ ] A fresh `engineering-principles` review of the whole branch, rule by rule (every ID gets a verdict), by a subagent briefed with the three skills above; fix every finding, Minors included; rerun the review after each fix round until none is open.
- [ ] `git fetch origin && git rebase origin/main`; rerun all checks.
- [ ] Push and open the PR on `colette-club/colette-marketplace` with `engineering-review:pr-description`, titled `Break check (2/3): <what it delivers>`. Do not merge.
