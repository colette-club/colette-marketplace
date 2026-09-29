# engineering-review evals

Behaviour tests for the `review-companion` and `engineering-principles` skills, run with
`claude plugin eval`. Each case replays a small git fixture: `base/` committed on `main`,
`change/` committed on `feature`, and asks the companion to review `feature` against `main`.

## Run

From the repository root:

```bash
# whole suite (acceptance: every case >= 0.67 over 3 runs)
claude plugin eval plugins/engineering-review --scaffold --trust-plugin \
  --allow-tools "Bash(git *)" Write --no-publish --judge-model sonnet --ablation none --threshold 0.67 -j 3

# one case while iterating
claude plugin eval plugins/engineering-review --case gate-checkpoint-1 --runs 1 --ablation none \
  --scaffold --trust-plugin --allow-tools "Bash(git *)" Write --no-publish --judge-model sonnet
```

Put the target before `--allow-tools` (it takes a list). `--case` takes one glob; a second `--case` replaces the first. Use `--judge-model sonnet`: the default judge is not reliable on long checkpoint messages. Use `--ablation none`: every case starts with the plugin's slash command, which does not exist in a no-plugin baseline, so a baseline arm measures nothing and doubles the cost. Every run starts a real Claude
session on your account; the summary table shows the cost per case.

### Prerequisites

- Claude Code with `claude plugin eval` (2.1.284 or later) and git 2.31 or later.
- Linux: `bubblewrap` and `socat` (granting `Bash` requires Claude Code's OS sandbox; without
  them every run is refused). `apt-get install -y bubblewrap socat`.

## Layout

```
evals/
├── _lib/make-repo.sh           # builds the fixture repo in the run's workspace
├── _fixtures/<fixture>/        # base/, change/, optional deleted.txt and generate.sh
├── _golden/                    # reference files for the validator, not cases
└── <case>/
    ├── prompt.md               # frontmatter (runs, max_turns, allowed_tools) + prompt
    ├── case.yaml               # schema_version "1.1", name, context.scaffold_script
    ├── scaffold.sh             # calls make-repo.sh on the case's fixture
    └── graders/*.md            # one grader per file
```

Each `scaffold.sh` is three lines:

```bash
#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$here/../_lib/make-repo.sh" "$here/../_fixtures/<fixture>"
```

## What the harness does (verified)

- `scaffold.sh` runs in the empty workspace (the run's working directory) before Claude starts,
  and only with `--scaffold`. `BASH_SOURCE` resolves to the case directory, so shared files are
  reached through `$here/../`.
- A prompt starting with `/engineering-review:review-companion` loads the skill directly; it
  does not show up as a `Skill` tool call, so do not grade with `tool_used: Skill`.
- The run allows only the read-only tools in `allowed_tools`; `Bash` and `Write` also need
  `--allow-tools`. Cases list `Write` even when nothing must be written, so "nothing written"
  is a real gate.
- `regex` graders read `last_message` by default. Use `flags: i` for case-insensitive matching
  (inline `(?i)` is not supported). Report contents are graded with
  `target: { source: file, path: ... }`, so every case that writes a report sets `report_path`
  in its pre-answers (file targets take no globs). Avoid `target: trace` for report text: the
  trace also holds the loaded skills, whose template headings match too.
- `llm` graders take no `target`: they judge the final message only. Grade report files with regex.
- Recall graders in the chat anchor to finding lines (`F-\d+\W[^\n]*EP-H2`), never to a bare
  word: the pre-answers echoed under each checkpoint heading would match it.
- `file_exists` with `exists: false` works for named paths (`.reviews/**`,
  `.review-companion/**`, `.gitignore`). A catch-all `**` always fails: the scaffold's own
  files count as created during the run.
- Checkpoints: without pre-answers the companion stops at checkpoint 1. A fenced
  `review-answers` block in the prompt answers checkpoint questions in advance; leaving
  `writes` out makes the run stop at checkpoint 3, whose message lists every finding on one
  line, which is what the recall cases grade.

## Baseline results (v0.1.0)

Full suite on 2026-09-29 after the final review fixes, `--judge-model sonnet --ablation none --threshold 0.67 -j 4`: 21 cases, exit 0, 658 s, $12.99.

| Case | Score | Runs passed | Runs | Cost |
|---|---|---|---|---|
| billing-recall | 1.00 | 100% | 3 | $1.24 |
| clean-change | 1.00 | 100% | 3 | $0.56 |
| effects-beyond-intent | 1.00 | 100% | 3 | $1.16 |
| gate-checkpoint-1 | 1.00 | 100% | 3 | $0.25 |
| gate-checkpoint-2 | 1.00 | 100% | 3 | $0.72 |
| gate-exclusions | 1.00 | 100% | 3 | $0.34 |
| gate-large-diff | 1.00 | 100% | 3 | $0.27 |
| gate-large-preanswered | 1.00 | 100% | 3 | $0.51 |
| gate-pr-target | 1.00 | 100% | 3 | $0.28 |
| listings-recall | 1.00 | 100% | 3 | $0.98 |
| listings-stats-block | 0.92 | 33% | 3 | $0.58 |
| memory-recheck | 1.00 | 100% | 3 | $0.50 |
| previous-report | 1.00 | 100% | 3 | $0.28 |
| profile-recall | 1.00 | 100% | 3 | $0.71 |
| referrals-recall | 1.00 | 100% | 3 | $0.74 |
| referrals-runtime-unknown | 1.00 | 100% | 3 | $0.67 |
| report-written | 1.00 | 100% | 3 | $1.06 |
| secret-checkpoint-3 | 1.00 | 100% | 3 | $0.69 |
| smoke | 1.00 | 100% | 1 | $0.04 |
| target-not-checked-out | 1.00 | 100% | 3 | $0.71 |
| wishes-recall | 0.97 | 67% | 3 | $0.69 |

Two cases changed after this run:

- **listings-stats-block** missed "what the code shows first" in two runs: they described the query instead of its callers. The skills now require a `**Called from:**` line, graded by `called-from-line`; 6 runs since, all 1.00.
- **wishes-recall** missed the Reminders docs finding once; the grader now accepts it under EP-F3 or EP-F4. 3 runs since, all 1.00.
