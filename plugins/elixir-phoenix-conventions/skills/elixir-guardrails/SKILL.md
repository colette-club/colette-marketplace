---
name: elixir-guardrails
description: Audits an Elixir/Phoenix app's automated guardrails — `mix precommit`, Credo and its check packs, Dialyzer, Boundary, Sobelow, dependency audits, CI workflows, Dependabot — and installs the missing ones with a committed baseline that may only shrink. Use when setting up or upgrading an app's guardrails, when an app has no `precommit` alias, or when asked to apply the AI-drift checks.
---

# Elixir guardrails

## Overview

Agents write a lot of code quickly, and they repeat whatever pattern they saw last. Guardrails are the checks that fail the build when the code drifts: warnings, formatting, Credo with check packs aimed at agent mistakes, compile-time coupling, context boundaries, security scans, type checks and dependency audits. One `mix precommit` runs them locally and CI runs them again. The set comes from Mike Zornek's *Guarding Against AI Drift* (July 2026), adapted to our apps.

**Core principle: green on day one, stricter every week.** Violations that already exist go into a committed baseline. New code must be clean. A baseline only ever shrinks.

A baseline is either a whole file (`.sobelow-skips`, `.dialyzer_ignore.exs`) or the lines between `# >>> baseline` and `# <<< baseline` in the file it configures (`.credo.exs`, a `use Boundary`). Entries are one per line, so a fix deletes lines and nothing else; the `guardrails-changed` CI job lets such a deletion through without a label and stops any addition.

The templates are in `templates/`, next to this file. `reference.md` holds each guardrail's install steps, baseline and gotchas: read its section before installing a guardrail. The baseline generator is `../../scripts/credo_baseline.ts`, relative to this file.

## The guardrails

| ID | Guardrail | Lives in | Baseline |
|---|---|---|---|
| G1 | `precommit` alias; compile and test with warnings as errors; `deps.unlock --check-unused` | `mix.exs` | none |
| G2 | Credo `--strict` with the Jump, Oeditus, ExSlop, excellent_migrations and phoenix_test checks | `.credo.exs` | the baseline block in `.credo.exs` |
| G3 | `xref graph --label compile-connected --fail-above 0` | `mix.exs` | today's count |
| G4 | Sobelow at the lowest threshold | `.sobelow-conf`, `.sobelow-skips` | skips |
| G5 | `deps.audit` and `hex.audit` | `mix.exs` | none |
| G6 | Dialyzer | `mix.exs`, `.dialyzer_ignore.exs` | ignore entries |
| G7 | `docs --warnings-as-errors` | `mix.exs` | none |
| G8 | Boundary | `mix.exs`, `use Boundary` in the top-level modules | `dirty_xrefs`, in a baseline block |
| G9 | excellent_migrations start point | `config/config.exs` | `start_after` |
| G10 | usage_rules into `AGENTS.md`, imported by `CLAUDE.md` | `mix.exs` | none |
| G11 | CI: setup action, build-and-test, code-quality (lint, docs, security, guardrails-changed), dialyzer, and the gate script | `.github/` | none |
| G12 | actionlint, semantic PR titles, Dependabot, gitleaks | `.github/` | none |

## Workflow

### 1. Audit — read only

Read `mix.exs`, `mix.lock`, `.credo.exs`, `.sobelow-conf`, `.sobelow-skips`, `.dialyzer_ignore.exs`, `.formatter.exs`, `.tool-versions` (or `mise.toml`), `.github/**`, `AGENTS.md`, `CLAUDE.md`, `config/config.exs`. Detect the stack: LiveView, HTML pages, Absinthe, Ecto with Postgres or PostGIS, Oban, the router's path, the default branch or branches. Run nothing in this step.

Send one message with one row per guardrail:

| ID | Guardrail | Status | Evidence |
|---|---|---|---|

- **present** — matches the template.
- **partial** — something exists but does not fail the build. Say exactly what: "`precommit` runs `deps.unlock --unused`, which rewrites `mix.lock`, instead of `--check-unused`, which fails".
- **missing** — nothing.
- **drifted** — installed, but older than the template (a check the template added, an older action major, a missing guarded path).

Every row carries `file:line` evidence, or "not found in <files read>". When the app's own rules disagree with its config (a `CLAUDE.md` asking for `credo --strict` while `.credo.exs` is not strict), say so under the table. Then ask which rows to install (all, by default) and stop.

### 2. Choose and isolate

- **Already in a linked worktree, or on a feature branch with a clean tree** → work there.
- **On the default branch** → create `chore/guardrails`; offer a worktree only if the person wants to keep using the checkout, and create it the `superpowers:using-git-worktrees` way (the native worktree tool first, otherwise `.worktrees/<branch>` inside the app, after checking `.worktrees` is git-ignored).
- **Uncommitted changes** → stop and ask.

### 3. Install — one green commit per guardrail

Install in this order; each step relies only on the ones before it: G1, G2, G3, G4, G5, G6, G7, G8, G9, G10, G11, G12. For each guardrail:

1. Read its section in `reference.md`.
2. Merge the template into the app's file. Never overwrite: keep the app's own settings, and carry the app's non-default Credo params into `app_checks`. When a template is copied, drop its first line (the `# templates/…` comment).
3. Generate the baseline the table names, from a real run, and only the kinds of baseline the table allows.
4. Run the `precommit` steps installed so far. Green → commit with a semantic message (`chore: add Credo check packs with a baseline`), the baseline's size in the body. Red → fix it, or baseline it if the table allows; never commit red.

**Stop and ask** when a guardrail needs more than about 50 fixes or baseline entries, when a fix would change behaviour, when `deps.audit` or `hex.audit` reports anything, and whenever a step in `reference.md` says so.

### 4. Finish

Show the PR description before doing anything with it: what each guardrail checks, each baseline's size and how it shrinks, the labels to create (`guardrails-changed`, `dependencies`), the secret-scan result, and the settings only a person can change (GitHub secret scanning with push protection). Then ask, one at a time, before you push, create the labels (`gh label create`), or open the PR (`gh pr create`). The PR itself changes guardrail files, so it needs the `guardrails-changed` label.

## Rules

- **Never weaken a guardrail to get green** — no inline disables, no new baseline entries beyond the first generation, no raised thresholds. The app's conventions skill states the same rule for every later change (elixir #61).
- **Compile and test warnings, and documentation warnings, are never baselined.** Fix them, or stop and ask.
- **Security findings are the person's decision.** Sobelow skips and advisory ignores are listed in the PR description, one line each, with what the finding is.
- **Never print a secret.** Report a gitleaks finding by file, line and rule only.
- **Re-running on an app that is already set up** is an audit for **drifted** rows; install fixes the same way, one commit per guardrail.

## Red flags — stop and reconsider

- About to overwrite an app's `.credo.exs`, `mix.exs` alias or workflow instead of merging into it.
- About to add a `# credo:disable`, `# sobelow_skip`, `@dialyzer {:nowarn_function, …}` or `dirty_xrefs` entry by hand to get a step green.
- About to commit with a red `precommit` step, or to baseline a warning.
- About to push, create a label or open a PR without asking.
- A baseline that grew on a re-run.
