---
name: break-check
description: Break check: breaks each branch a change adds or changes and records the proof. Use when a task's tests are green, before a PR, or to write a missing runner.
---

# Break check

A test is real only if it fails when its code breaks. A break check shows it: break one **branch** on purpose, see a named test fail, undo the break. EP-G4 asks it of every branch a change adds or changes, and says what a branch is. Each repository commits a **runner** that does the breaking and keeps the record, so the check costs few tokens and each branch is proven once.

- **Break:** the smallest change to one branch that still compiles (see [Breaks](#breaks)). Its **swap** is the pair `from` → `to`: the exact text it replaces, and the text it puts there.
- **Proof:** a line in the **ledger**, written by the runner alone, when a test it names failed on a break, on tests that ran green just before. A proof starts from green tests: the red step of TDD fails because the code is not there yet, not because of the branch.
- **Fresh:** a proof whose file and test files are unchanged since it ran, and whose `from` still occurs exactly once.
- **Stale:** a proof whose file or one of whose test files changed since; the runner replays it.
- **Gone:** a proof whose `from` no longer occurs exactly once, or whose test file is missing; its branch needs a new break.

## Run it in your own context

Whoever wrote the code runs its breaks, in the same session: a fresh agent's starting context is most of what a break check costs. The runner prints one line per break: read those lines, not the test output.

## The runner

`<runner>` below is the repository's committed runner, as its `AGENTS.md` or a README names it, the runner's own README included. `<runner> --help` lists its flags, including whatever the repository's tests need to run beside other sessions. A runner with more than one profile (one per test suite, such as the app's and the runner's own) runs each recipe below once for each profile whose watched paths the change touches; when stale proofs of two suites stop a replay, see the known gaps in [contract.md](contract.md).

Look for a committed runner (a `break_check` script, its README) before deciding there is none. A repository with no runner gets one before its first break: write it in the language the repository's people prefer, following [contract.md](contract.md), with its tests, and commit it. Breaks go through the runner, since only it records a proof a later step or a review can read, and the PR's table comes from its `--table` (`pr-description`).

## After a task's tests are green

1. `<runner> --uncovered <the task's base commit>` lists the changed lines no fresh proof covers. It lists added lines under the profile's watched paths only, so read `git diff <the task's base commit>` for deleted lines, and for branches outside those paths, too.
2. Write one break per branch on those lines into a breaks file under `.breaks/`, such as `.breaks/task-3.json`. A proof covers every line its `from` spans, so a line holding several branches (each value in a guard list) gets a break for each. A branch the change narrows only by deleting lines (a value dropped from a guard list) gets a break too: its `from` taken from the lines around the deletion, its `to` the same lines with the deleted text put back.
3. `<runner> .breaks/task-3.json`. The runner checks every swap first and runs nothing on a miss, so let it do the checking.
4. For each `NOT CAUGHT`: write a test, add its file to the break's `tests` when it is not listed, then rerun the file: its `caught` line is the test failing on the break.

Done when the run exits 0, every line `--uncovered` still lists holds no branch, and each branch `--uncovered` cannot list (narrowed only by deleting lines, or outside the watched paths) has a fresh proof. Then commit: the ledger is git-ignored and stays in this worktree.

## Before the PR

In the worktree that holds the ledger (a scratch worktree has none):

1. `<runner> --stale --replay` reruns every stale proof and drops the gone ones, whose branches `--uncovered` then lists again, except a branch `--uncovered` cannot list: break it again from the `gone` line the replay printed.
2. `<runner> --uncovered <the PR's base commit>`, and `git diff <the PR's base commit>` for the branches it cannot list (deleted lines, paths outside the watched ones) that `--table` shows no fresh proof for; break those as in steps 2–4 of "After a task's tests are green". A test added here can make other proofs stale: rerun step 1 until `<runner> --stale` ends with `0 stale`.
3. Once `--stale` ends with `0 stale`, every line `--uncovered` lists holds no branch, and each branch `--uncovered` cannot list (narrowed only by deleting lines, or outside the watched paths) has a fresh proof, `<runner> --table` prints the Break checks part of the PR description (`pr-description`).

Done when the table is printed after the last break.

## Breaks

A breaks file is a JSON array, one object per branch:

```json
[{"name": "same second is not after", "file": "lib/cadre/source_control/change_requests.ex",
  "from": "DateTime.compare(head_committed_at, submitted_at) == :gt",
  "to": "DateTime.compare(head_committed_at, submitted_at) != :lt",
  "tests": ["test/cadre/source_control/change_requests_test.exs"]}]
```

- `name` is the branch's identity in its file: unique among the file's breaks, and refused while a proof of another swap in that file holds it, unless that proof's `from` no longer occurs exactly once. A proof of the same swap never blocks it.
- `from` is the shortest text found exactly once in `file`, on one line unless the branch needs more: copy it from the `--uncovered` line.
- `to` is the smallest change to that one branch, one that still compiles: flip the condition, drop the guard value, delete the cast, swap the clause order. A break that raises, empties or replaces a body proves nothing: any test catches it.
- `tests` lists only the test files that cover the branch: the fewer, the faster.

## Results

A run prints one line per break as it happens, then a summary line (`<n> caught, <n> not caught, <n> doesn't compile, <n> inconclusive`):

| Line | Means | Do |
|---|---|---|
| `caught  <name>  ← <tests>` | a proof, now in the ledger | nothing |
| `proven  <name>  (fresh in the ledger)` | a fresh proof of this exact swap was already there; nothing ran | nothing |
| `NOT CAUGHT  <name>` | no test notices the break | write the test, list its file in the break's `tests`, and rerun the file, so the runner shows it failing on the break; on a replay, put the proof's swap in a breaks file with the test files that now cover it, and its new proof replaces the old |
| `doesn't compile  <name>` | not a valid break | write another break for that branch; on a replay, see the known gaps in [contract.md](contract.md) |
| `inconclusive  <name>  (<reason>)` | a timeout, the infrastructure, another test run, or output the runner cannot read | rerun it |

`--stale` prints `replayable <file>:<line> <name>` or `gone <file>:<line> <name>` per proof, then `<n> stale`, counting both. `--uncovered` prints `<file>:<line> | <text>` per line, then `<n> changed lines have no fresh proof`.

## Exit codes

- **0** every break was caught or already `proven`, or nothing is left.
- **1** something is left: a break not caught, one that doesn't compile or is inconclusive, a stale or gone proof listed, a line no proof covers, a gone proof dropped. A normal end of `--uncovered`, `--stale` and `--stale --replay`: read the lines.
- **2** the runner refused and broke nothing: the lock is held, a swap missed, a bad breaks file, tests red before any break, a bad command line, an unexpected error.
- **3** a file could not be restored, or changed while it held a break. The message names the journal entry that holds the original. When the file differs from the original only by the break, put the original back; when someone edited it meanwhile, undo the break by hand and keep their edit. Then delete the entry, or every command exits 3 again.

## The ledger

`.breaks/ledger.jsonl`, git-ignored, one JSON object per line, one line per proof:

```json
{"name": "same second is not after", "file": "lib/cadre/source_control/change_requests.ex", "line": 42,
 "from": "DateTime.compare(head_committed_at, submitted_at) == :gt", "to": "DateTime.compare(head_committed_at, submitted_at) != :lt",
 "tests_failed": ["test a commit in the same second is not after the review (Cadre.SourceControl.ChangeRequestsTest)"],
 "hashes": {"lib/cadre/source_control/change_requests.ex": "<sha256>", "test/cadre/source_control/change_requests_test.exs": "<sha256>"}}
```

`line` is where `from` was when the break ran. `hashes` holds the SHA-256 of `file` and of each test file, which tells fresh from stale. A newer proof replaces the one with the same swap in the same file, and one with the same `file` and name whose `from` no longer occurs exactly once.

A proof **belongs** to a change when its `from` spans a line the change adds or changes, or sits next to a line it deletes. `<runner> --table` prints every fresh proof in this worktree, whichever change it belongs to, in this shape, `|` escaped as `\|` and a newline as `⏎`:

```markdown
<details><summary>Break checks (1)</summary>

| Branch | Swap | Caught by |
|---|---|---|
| lib/cadre/source_control/change_requests.ex:42 | `DateTime.compare(head_committed_at, submitted_at) == :gt` → `DateTime.compare(head_committed_at, submitted_at) != :lt` | test a commit in the same second is not after the review (Cadre.SourceControl.ChangeRequestsTest) |

</details>
```
