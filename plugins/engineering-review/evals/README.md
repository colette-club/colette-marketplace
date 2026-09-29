# engineering-review evals

Behaviour tests for the `review-companion` and `engineering-principles` skills, run with
`claude plugin eval`. Each case replays a small git fixture: `base/` committed on `main`,
`change/` committed on `feature`, and asks the companion to review `feature` against `main`.

## Run

From the repository root:

```bash
# whole suite (acceptance: every case >= 0.67 over 3 runs)
claude plugin eval plugins/engineering-review --scaffold --trust-plugin \
  --allow-tools "Bash(git *)" Write --no-publish --judge-model sonnet --threshold 0.67 -j 3

# one case while iterating
claude plugin eval plugins/engineering-review --case gate-checkpoint-1 --runs 1 --ablation none \
  --scaffold --trust-plugin --allow-tools "Bash(git *)" Write --no-publish --judge-model sonnet
```

Put the target before `--allow-tools` (it takes a list). `--case` takes one glob; a second `--case` replaces the first. Use `--judge-model sonnet`: the default judge is not reliable on long checkpoint messages. Every run starts a real Claude
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
