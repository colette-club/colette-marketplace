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
- `file_exists` accepts globs (`.reviews/*feature-archive-wish.md`); `regex` file targets do not.
- `cards-complete` graders use a negative-lookahead regex to fail a report with any card missing one
  of its parts; keep them in every case that writes to a known `report_path`.
- Other skills: an eval run sees only the plugins it loads. Skills in the workspace's `.claude/skills/` or in
  `$HOME/.claude/skills/` are invisible. To give a case more skills, ship a small plugin inside the case
  directory (`<case>/team-stack/`) and list it in the prompt frontmatter together with the plugin under test:
  `plugins: ["../..", "team-stack"]`. A `plugins:` list replaces the plugin under test, so `../..` is required,
  and a shipped plugin must sit in its own subdirectory of the case.
- Checkpoints: without pre-answers the companion stops at checkpoint 1. A fenced
  `review-answers` block in the prompt answers checkpoint questions in advance; leaving
  `writes` out makes the run stop at checkpoint 3, whose message lists every finding on one
  line, which is what the recall cases grade.

## Checking the reports themselves

Graders check what a report says; the validator checks its shape. After a run with `--keep-temp`, validate every
report the companion wrote (header rows, disclaimer, sections, complete cards, SQL rules, and — with `mmdc` on the
PATH — that every diagram renders):

```bash
for f in /tmp/claude-eval-*/home/cwd/.reviews/*.md; do
  python3 plugins/engineering-review/scripts/check_plugin.py report "$f" --mermaid
done
```

Then remove the kept directories as the harness asks (`chmod -R u+rwX <dir> && rm -rf <dir>`).

## Baseline results (v0.2.0)

Full suite on 2026-09-30, `--judge-model sonnet --ablation none --threshold 0.67 -j 4`: 27 cases, exit 0, 946 s,
$18.60 — every case 1.00, every run passed.

| Case | Score | Runs passed | Runs | Cost |
|---|---|---|---|---|
| billing-recall | 1.00 | 100% | 3 | $1.35 |
| clean-change | 1.00 | 100% | 3 | $0.59 |
| effects-beyond-intent | 1.00 | 100% | 3 | $1.21 |
| frontend-skills-applied | 1.00 | 100% | 3 | $1.01 |
| gate-checkpoint-1 | 1.00 | 100% | 3 | $0.37 |
| gate-checkpoint-2 | 1.00 | 100% | 3 | $0.70 |
| gate-exclusions | 1.00 | 100% | 3 | $0.35 |
| gate-large-diff | 1.00 | 100% | 3 | $0.31 |
| gate-large-preanswered | 1.00 | 100% | 3 | $0.33 |
| gate-pr-target | 1.00 | 100% | 3 | $0.30 |
| gate-test-command-unseen | 1.00 | 100% | 3 | $0.35 |
| listings-recall | 1.00 | 100% | 3 | $1.10 |
| listings-stats-block | 1.00 | 100% | 3 | $0.65 |
| memory-recheck | 1.00 | 100% | 3 | $0.57 |
| previous-report | 1.00 | 100% | 3 | $0.31 |
| profile-recall | 1.00 | 100% | 3 | $0.71 |
| referrals-recall | 1.00 | 100% | 3 | $0.73 |
| referrals-runtime-unknown | 1.00 | 100% | 3 | $0.70 |
| report-no-overwrite | 1.00 | 100% | 3 | $1.14 |
| report-path-slash-branch | 1.00 | 100% | 3 | $1.17 |
| report-written | 1.00 | 100% | 3 | $1.17 |
| rules-in-change | 1.00 | 100% | 3 | $0.60 |
| secret-checkpoint-3 | 1.00 | 100% | 3 | $0.77 |
| smoke | 1.00 | 100% | 1 | $0.05 |
| stack-skills-applied | 1.00 | 100% | 3 | $0.61 |
| target-not-checked-out | 1.00 | 100% | 3 | $0.68 |
| wishes-recall | 1.00 | 100% | 3 | $0.74 |

20 of the 21 reports written in that run passed the validator; one gave a note that was not a finding an `### F-NN`
heading. The report skill now reserves those headings for findings; report-no-overwrite and report-path-slash-branch
then scored 1.00 in all 6 runs, and all 6 reports passed the validator.
