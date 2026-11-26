# The runner's contract

What a repository's break-check runner does, whatever its language. Read it before writing or changing a runner. What the runner prints, its exit codes, the breaks file and the ledger are in [SKILL.md](SKILL.md): a runner matches them exactly, so the recipes, the PR's table and the review read every repository's runner the same way.

## Contents

- [The command line](#the-command-line)
- [Internals](#internals)
- [The profile](#the-profile)
- [Its tests](#its-tests)
- [Reference implementation](#reference-implementation)

## The command line

Run from the repository root:

- `<runner> BREAKS.json` breaks each branch in the file, one at a time, and records what is caught.
- `<runner> --stale` lists stale and gone proofs; `--stale --replay` reruns the stale ones from the ledger.
- `<runner> --uncovered BASE` lists the changed lines since `BASE` that no fresh proof covers, one `<file>:<line> | <text>` each.
- `<runner> --table` prints the fresh proofs as the PR's table.
- `<runner> --help` lists every flag.

One command at a time. Add only what the repository's tests need to run beside other sessions (cadre takes `--partition N`, checked only when a test runs) and a way to pick a profile.

## Internals

1. **Lock, then recover.** Every command takes a lock the operating system drops when the process dies (cadre: `flock` on `.breaks/lock`), then recovers what a killed run left before reading any file, and says so loudly: `RESTORED <file> FROM A KILLED RUN`.
2. **Journal.** Before each swap, write `{path, original, hash of the broken text}` to `.breaks/journal/`, whole or not at all (a temp file, then a rename). A file is restored only while it still holds that break, at the end of a swap and when recovering; a file edited since is left alone with its entry, and the run exits 3 naming the entry. An entry that cannot be read is named, never skipped.
3. **The test run in flight** is recorded in `.breaks/child`. A run killed outright leaves it; the next run names it with the command to stop it, and never kills it, since a pid can be reused.
4. **Check first.** For each break: the file and each test file exist, `tests` is a non-empty list, `to` differs from `from`, `from` occurs exactly once, and no two breaks in one file share a name. A miss says how many times `from` occurred: 0, or each occurrence with its line. Report every problem and run nothing.
5. **Names.** A new break may take a name only from a gone proof.
6. **Skip what is proven.** A break whose exact swap (`file`, `from`, `to`) has a fresh proof prints `proven` and runs nothing.
7. **Green baseline per set.** Run each distinct set of listed tests unbroken, in a fixed order (cadre: a fixed seed); a red set stops the run with the failing names, or the output's tail.
8. **One at a time.** Swap, run the break's tests with a per-break timeout in their own process group, restore. A signal or a timeout stops that group; the runner puts the previous signal handlers back.
9. **Outcomes fail closed,** checked in this order:
   1. a timeout: `inconclusive`;
   2. the compile-error pattern: `doesn't compile`;
   3. the infrastructure pattern: rerun once, then `inconclusive`;
   4. the refusal pattern (another test run holding the database or the partition): `inconclusive`;
   5. a failing exit that names failing tests: `caught`, with those names;
   6. a passing exit: `NOT CAUGHT`;
   7. anything else: `inconclusive`, with the output's last lines.
10. **Ledger.** Each `caught` is written once its restore is verified, so a killed run loses nothing. The ledger is rewritten whole (a temp file, then a rename).
11. **Stale.** A proof is stale when the hash of its file or of a test file differs, and gone when its `from` no longer occurs exactly once or a test file is missing. `--stale --replay` names the gone proofs, reruns the stale ones, and only then drops the gone ones.
12. **Uncovered.** The lines added since `BASE` under the watched paths, untracked files included, that no fresh proof's `from` spans, minus noise lines and doc-block lines. A proof covers every line its `from` spans.
13. **Table.** Only fresh proofs, in the shape SKILL.md shows.
14. **Exit codes** as SKILL.md gives them.

## The profile

A profile at the top of the runner holds the repository's settings, so the rest of the runner is the same everywhere:

- **command:** the test command for a list of test files, with its environment; it runs the tests in a fixed order;
- **failing test:** a pattern whose first group captures each failing test's name in the output;
- **compile error, infrastructure, refusal:** the output patterns of item 9 (infrastructure and refusal may be absent);
- **timeout:** seconds per test run;
- **watched:** the paths `--uncovered` looks at;
- **noise:** a pattern for changed lines that hold no branch (a closing keyword, a comment);
- **doc open, doc close:** the lines that start and end a doc block, whose lines hold no branch.

A repository with more than one test suite has a profile for each; cadre has one for its app and one for the runner's own tests. Cadre's values are in its `script/break_check/profile.rb` at `354ee07e`.

## Its tests

The runner ships with tests in the repository's test framework, against a stub test command, so they run in seconds:

- a break caught, and one not caught;
- a break that doesn't compile;
- a miss (a `from` found 0 times, and twice);
- a red baseline;
- a run killed mid-break, then recovered by the next command;
- the lock held by another run;
- the ledger: a proof recorded, made stale, replayed, gone and dropped;
- `--uncovered` and `--table` on a small git repository.

Once its tests are green, break-check the runner itself with its own runner profile.

## Reference implementation

Cadre's runner, merged as `354ee07e` (djeusette/cadre#159): `script/break_check.rb`, the files under `script/break_check/` (`breaks.rb`, `ledger.rb`, `profile.rb`, `run.rb`, `uncovered.rb`, `workspace.rb`), their tests in `script/test/`, and `script/README.md`. It is Ruby with the standard library only. Read it when the contract leaves a choice open; where the two disagree, the contract wins and the runner is fixed.
