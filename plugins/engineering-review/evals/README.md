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
  (inline `(?i)` is not supported). Report contents are graded with `target: trace`, where the
  `Write` call carries the report text (quotes appear JSON-escaped).
- `file_exists` counts only files Claude created during the run.
- Checkpoints: without pre-answers the companion stops at checkpoint 1. A fenced
  `review-answers` block in the prompt answers checkpoint questions in advance; leaving
  `writes` out makes the run stop at checkpoint 3, whose message lists every finding on one
  line, which is what the recall cases grade.

## Baseline results (v0.1.0)

Full suite on 2026-09-29, `--judge-model sonnet --ablation none --threshold 0.67 -j 4`: 16 cases, exit 0, 473 s, $9.12.

| Case | Score | Runs passed | Runs | Cost |
|---|---|---|---|---|
| billing-recall | 1.00 | 100% | 3 | $1.12 |
| clean-change | 1.00 | 100% | 3 | $0.58 |
| gate-checkpoint-1 | 1.00 | 100% | 3 | $0.27 |
| gate-checkpoint-2 | 1.00 | 100% | 3 | $0.68 |
| gate-exclusions | 1.00 | 100% | 3 | $0.27 |
| gate-large-diff | 1.00 | 100% | 3 | $0.27 |
| listings-recall | 1.00 | 100% | 3 | $0.95 |
| listings-stats-block | 0.95 | 67% | 3 | $0.58 |
| memory-recheck | 1.00 | 100% | 3 | $0.47 |
| previous-report | 1.00 | 100% | 3 | $0.25 |
| profile-recall | 1.00 | 100% | 3 | $0.61 |
| referrals-recall | 1.00 | 100% | 3 | $0.70 |
| referrals-runtime-unknown | 1.00 | 100% | 3 | $0.60 |
| report-written | 1.00 | 100% | 3 | $1.07 |
| smoke | 1.00 | 100% | 1 | $0.05 |
| wishes-recall | 0.97 | 67% | 3 | $0.66 |

The two cases below 1.00 each had one run where a single grader missed (the judge on the "code first, then the block" wording; the literal `{:ok, _}` not quoted).
