# colette-code-conventions Implementation Plan

> **Status:** Executed to completion on branch `feat/colette-code-conventions`,
> commit range `00f40e5..HEAD`. Checkboxes below are left unchecked as
> originally written rather than retroactively ticked. Task 10 (manual
> acceptance) remains a manual pre-merge gate — it is not automatable and has
> not been run as part of this execution.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a `colette-code-conventions` plugin that loads on every codebase touch in any language, and convert the language-agnostic rules in the two existing skills into numbered stubs pointing at it.

**Architecture:** A new marketplace plugin carrying one skill (`SKILL.md` + `reference.md`) and a `PreToolUse` hook that injects a load instruction once per session. The two existing skills keep their rule numbers; each moved rule becomes a one-line stub naming its `core #N` target plus the language-specific tells. Three bash validation scripts and a CI workflow guard against drift.

**Tech Stack:** Markdown skills, Claude Code plugin manifests, POSIX bash + `jq` + `ripgrep`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-27-colette-code-conventions-design.md`

## Global Constraints

- **English only.** Every identifier, comment, doc line, test name, script message, and commit message is English. This is `core #0` and it applies to the work that builds it.
- **Fails open.** The hook script must print `{}` and `exit 0` on every error path. It must never print a `permissionDecision` key.
- **No renumbering.** Existing rule numbers in both language skills are preserved exactly. `#56`, `#90`, `#91` and commit references like `(#57/#91, …)` must stay valid.
- **Core rule numbering:** `core #0` through `core #21`, contiguous, cited in prose as `core #N`.
- **Core-only rules** (not cited by any language skill) are `#4`, `#16`, `#17`, `#19`, `#20`, `#21`. Each carries a literal `(core-only)` tag at the end of its rule line.
- **Versions:** new plugin `0.1.0`; `elixir-phoenix-conventions` `0.2.12` → `0.3.0`; `flutter-conventions-guide` `0.2.4` → `0.3.0`.
- **Commit style:** semantic prefixes (`feat:`, `docs:`, `chore:`), one logical change per commit.
- **Skill structure:** the core `SKILL.md` mirrors the existing two — Overview → core principles → Rule 0 → highest-risk rules → numbered checklist → red flags → "also enforced mechanically".

---

## File Structure

**Create**

| File | Responsibility |
|---|---|
| `plugins/colette-code-conventions/.claude-plugin/plugin.json` | Plugin manifest |
| `plugins/colette-code-conventions/hooks/hooks.json` | Hook wiring: `PreToolUse` + `SessionStart` |
| `plugins/colette-code-conventions/hooks/inject-conventions.sh` | Once-per-session context injection; `--reset` clears the marker |
| `plugins/colette-code-conventions/hooks/inject-conventions.test.sh` | Unit tests for the hook script |
| `plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md` | The 22 core rules |
| `plugins/colette-code-conventions/skills/colette-code-conventions/reference.md` | Language-neutral worked examples |
| `scripts/validate-manifests.sh` | marketplace.json ↔ plugin.json consistency |
| `scripts/check-references.sh` | Cross-skill reference integrity |
| `.github/workflows/validate.yml` | Runs all three scripts on PR |

**Modify**

| File | Change |
|---|---|
| `plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions/SKILL.md` | 12 stub entries (14 rules) |
| `plugins/elixir-phoenix-conventions/.claude-plugin/plugin.json` | version → `0.3.0` |
| `plugins/flutter-conventions-guide/skills/flutter-conventions-guide/SKILL.md` | 8 stub entries (10 rules) |
| `plugins/flutter-conventions-guide/.claude-plugin/plugin.json` | version → `0.3.0` |
| `.claude-plugin/marketplace.json` | third entry + two version bumps |
| `README.md` | list the plugin, state it is a prerequisite |

---

### Task 1: Hook script

**Files:**
- Create: `plugins/colette-code-conventions/hooks/inject-conventions.test.sh`
- Create: `plugins/colette-code-conventions/hooks/inject-conventions.sh`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `inject-conventions.sh`, invoked as `bash inject-conventions.sh` (PreToolUse) or `bash inject-conventions.sh --reset` (SessionStart). Reads the hook payload JSON on stdin, writes one JSON object to stdout, always exits 0. Marker path: `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/colette-code-conventions}/sessions/<session_id>`.

- [ ] **Step 1: Write the failing test**

Create `plugins/colette-code-conventions/hooks/inject-conventions.test.sh`:

```bash
#!/usr/bin/env bash
# Tests for inject-conventions.sh. Run: bash inject-conventions.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/inject-conventions.sh"

PASS=0
FAIL=0

# Isolate state so tests never touch the real marker directory.
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT
export CLAUDE_PLUGIN_DATA="$TEST_HOME/data"

run_hook() {
  local payload="$1"
  shift
  printf '%s' "$payload" | bash "$SCRIPT" "$@" 2>/dev/null
}

ok() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
no() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n  %s\n' "$1" "$2"; }

assert_contains() {
  case "$2" in
    *"$3"*) ok "$1" ;;
    *) no "$1" "expected to contain '$3', got '$2'" ;;
  esac
}

assert_not_contains() {
  case "$2" in
    *"$3"*) no "$1" "expected NOT to contain '$3', got '$2'" ;;
    *) ok "$1" ;;
  esac
}

assert_equals() {
  if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "expected '$3', got '$2'"; fi
}

PAYLOAD_A='{"session_id":"sess-aaa","hook_event_name":"PreToolUse","tool_name":"Edit"}'
PAYLOAD_B='{"session_id":"sess-bbb","hook_event_name":"PreToolUse","tool_name":"Bash"}'

out="$(run_hook "$PAYLOAD_A")"
assert_contains "first call injects additionalContext" "$out" 'additionalContext'
assert_contains "first call names the PreToolUse event" "$out" 'PreToolUse'
assert_contains "first call names the skill" "$out" 'colette-code-conventions'

out="$(run_hook "$PAYLOAD_A")"
assert_equals "second call in the same session is silent" "$out" '{}'

out="$(run_hook "$PAYLOAD_B")"
assert_contains "a different session injects" "$out" 'additionalContext'

run_hook "$PAYLOAD_A" --reset >/dev/null
out="$(run_hook "$PAYLOAD_A")"
assert_contains "--reset re-arms the session" "$out" 'additionalContext'

out="$(run_hook '{"session_id":"sess-ccc"}')"
assert_not_contains "never emits permissionDecision" "$out" 'permissionDecision'

out="$(run_hook 'not json at all')"
assert_equals "malformed stdin is silent" "$out" '{}'

out="$(run_hook '')"
assert_equals "empty stdin is silent" "$out" '{}'

out="$(run_hook '{"hook_event_name":"PreToolUse"}')"
assert_equals "missing session_id is silent" "$out" '{}'

out="$(run_hook '{"session_id":"../../etc/passwd"}')"
assert_equals "unsafe session_id is silent" "$out" '{}'

out="$(printf '%s' "$PAYLOAD_A" | env PATH=/nonexistent /bin/bash "$SCRIPT" 2>/dev/null)"
assert_equals "missing jq is silent" "$out" '{}'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash plugins/colette-code-conventions/hooks/inject-conventions.test.sh`
Expected: every case FAILs — `inject-conventions.sh` does not exist yet, so each `run_hook` produces empty output.

- [ ] **Step 3: Write the hook script**

Create `plugins/colette-code-conventions/hooks/inject-conventions.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse hook: injects a one-per-session instruction to load the
# colette-code-conventions skill. With --reset (SessionStart) it clears the
# session marker instead. Fails open everywhere: prints {} and exits 0.
set -u

STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/colette-code-conventions}/sessions"

silent() { printf '{}'; exit 0; }

command -v jq >/dev/null 2>&1 || silent

SESSION_ID="$(jq -r '.session_id // empty' 2>/dev/null)" || silent
[ -n "$SESSION_ID" ] || silent

# The session id becomes a path segment; allow only safe characters.
case "$SESSION_ID" in
  *[!A-Za-z0-9._-]*) silent ;;
esac

MARKER="$STATE_DIR/$SESSION_ID"

if [ "${1:-}" = "--reset" ]; then
  rm -f "$MARKER" 2>/dev/null
  silent
fi

[ -e "$MARKER" ] && silent

mkdir -p "$STATE_DIR" 2>/dev/null || silent
: >"$MARKER" 2>/dev/null || silent

CONTEXT='Colette engineering conventions govern this repository. Before proceeding, invoke the Skill tool with skill "colette-code-conventions" and follow it. It applies to every file here regardless of language, including comments, documentation, and configuration.'

jq -nc --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}' 2>/dev/null || silent
exit 0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash plugins/colette-code-conventions/hooks/inject-conventions.test.sh`
Expected: `12 passed, 0 failed`, exit 0.

- [ ] **Step 5: Confirm no real state was written**

Run: `ls ~/.claude/colette-code-conventions 2>&1`
Expected: `No such file or directory` — the tests must have used the temp dir only.

- [ ] **Step 6: Commit**

```bash
git add plugins/colette-code-conventions/hooks/inject-conventions.sh \
        plugins/colette-code-conventions/hooks/inject-conventions.test.sh
git commit -m "feat: add once-per-session conventions injection hook script"
```

---

### Task 2: Plugin scaffold, hook wiring, and Rule 0

**Files:**
- Create: `plugins/colette-code-conventions/.claude-plugin/plugin.json`
- Create: `plugins/colette-code-conventions/hooks/hooks.json`
- Create: `plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md`

**Interfaces:**
- Consumes: `hooks/inject-conventions.sh` from Task 1.
- Produces: an installable plugin named `colette-code-conventions` at version `0.1.0`, and a `SKILL.md` whose frontmatter `name` is `colette-code-conventions`. Tasks 3 and 4 append sections to this same `SKILL.md`.

- [ ] **Step 1: Write the plugin manifest**

Create `plugins/colette-code-conventions/.claude-plugin/plugin.json`, matching the shape of the existing two:

```json
{
  "name": "colette-code-conventions",
  "version": "0.1.0",
  "description": "Colette engineering conventions that apply to every codebase regardless of language: English-only, abstraction and naming, error handling, contracts and application boundaries, change hygiene, self-contained tests, and the commit and review workflow.",
  "author": {
    "name": "Colette Club",
    "url": "https://github.com/colette-club"
  },
  "homepage": "https://github.com/colette-club/colette-marketplace",
  "repository": "https://github.com/colette-club/colette-marketplace",
  "license": "MIT",
  "keywords": ["conventions", "best-practices", "code-quality", "workflow", "testing"]
}
```

- [ ] **Step 2: Write the hook wiring**

Create `plugins/colette-code-conventions/hooks/hooks.json`:

```json
{
  "description": "Loads the Colette core conventions skill once per session, the first time a file or the shell is touched.",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/inject-conventions.sh\""
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/inject-conventions.sh\" --reset"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Verify both manifests parse**

Run:
```bash
jq -e . plugins/colette-code-conventions/.claude-plugin/plugin.json >/dev/null && \
jq -e . plugins/colette-code-conventions/hooks/hooks.json >/dev/null && echo "both parse"
```
Expected: `both parse`

- [ ] **Step 4: Verify the hook command path resolves**

Run:
```bash
test -f plugins/colette-code-conventions/hooks/inject-conventions.sh && echo "script present"
```
Expected: `script present` — `${CLAUDE_PLUGIN_ROOT}/hooks/inject-conventions.sh` must exist relative to the plugin root.

- [ ] **Step 5: Write SKILL.md frontmatter, Overview, core principles, and Rule 0**

Create `plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md`. Frontmatter exactly:

```markdown
---
name: colette-code-conventions
description: Use when reading, writing, or editing ANY file in any Colette repository — source in any language, tests, comments, documentation, configuration, and commit or PR text. Carries the language-agnostic engineering rules that the Elixir and Flutter convention skills build on.
file_patterns:
  - "**/*"
---
```

Then these sections, in order:

1. `# Colette Code Conventions`
2. `## Overview` — state that these rules hold in every language and every file type, that language skills add to them and never override them, and that `core #N` is how the rest of the marketplace cites them. Name the three core principles: **everything we write is in English**; **a failure is never silently swallowed**; **an edit is not finished until what it made pointless is gone**.
3. `## Rule 0 — everything is in English. No exceptions.` — port the rationale from `elixir-phoenix-conventions` `#0` (the translation-step / split-naming / broken-search / excluded-teammate argument), generalized: identifiers, file and directory names, comments and doc comments, test names, log and telemetry messages, error messages and types, migration and index names, `TODO`s, commit messages, PR descriptions. State the single exception: translated **values** in a message catalogue (Gettext `.po`, `app_fr.arb`), whose source locale is English and whose keys and metadata stay English. State that non-English code you did not write is not grandfathered — rename as you touch it. Close with a bad/good snippet **in Python** (the language rotation is set in Task 3).

- [ ] **Step 6: Verify the skill file structure**

Run:
```bash
rg -n '^(---|name:|description:|file_patterns:|# |## )' \
  plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md
```
Expected: frontmatter delimiters and keys, then `# Colette Code Conventions`, `## Overview`, `## Rule 0 — everything is in English. No exceptions.` and nothing else yet.

- [ ] **Step 7: Verify Rule 0 states the exception**

Run:
```bash
rg -c 'catalogue|\.po|app_fr\.arb' \
  plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md
```
Expected: at least `1` — the message-catalogue exception must be present, or the rule reads as banning translated copy.

- [ ] **Step 8: Commit**

```bash
git add plugins/colette-code-conventions/
git commit -m "feat: scaffold colette-code-conventions plugin with Rule 0"
```

---

### Task 3: Core rules 1-15 (§ Code)

**Files:**
- Modify: `plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md`

**Interfaces:**
- Consumes: the `SKILL.md` created in Task 2.
- Produces: numbered rules `1`–`15` as top-level markdown list items in the exact form `N. **Name** — text`, parseable by `^([0-9]+)\. `. Task 4 appends `16`–`21` in the same form. Task 9's `check-references.sh` depends on this exact shape.

- [ ] **Step 1: Add the highest-risk section**

Insert `## Highest-risk rules` after Rule 0, with five numbered subsections, each carrying a bad/good snippet. Rule 0 is the sixth highest-risk rule and already has its own section above, so it is not repeated here.

| Subsection | Rule | Snippet language |
|---|---|---|
| `### 1. Never swallow a failure` | `core #8` | TypeScript |
| `### 2. Change hygiene` | `core #13` | Ruby |
| `### 3. Self-contained tests` | `core #15` | Python (pytest) |
| `### 4. Application boundaries` | `core #12` | SQL |
| `### 5. Single level of abstraction` | `core #2` | Go |

Snippets rotate languages deliberately: these rules belong to no single stack, and a reader who only writes Dart should still see the rule stated in code that is not Dart. Never use Elixir or Dart here — those have their own skills, and reusing them would make the core skill read as a subset of one of them.

- [ ] **Step 2: Add the § Code checklist**

Insert `## Quick reference — full checklist`, then these sections and rules. Rule text comes from the spec's core-rules table; each entry is one to three sentences plus, where useful, an inline example. `(core-only)` is a literal tag ending the rule line.

```markdown
### A. Foundations
1. **Match the surrounding code** — consistency outranks individual preference.
2. **Single level of abstraction** — one thing at one altitude; extract named helpers; no nested conditionals.
3. **Intention-revealing names, no abbreviations.**
4. **YAGNI** — no speculative abstraction, no parameter, flag, or config entry added for a caller that does not exist yet. (core-only)

### B. Data & control flow
5. **Name the value before you use it** — bind a computed value to a well-named variable before placing it in a literal or passing it on.
6. **Accept the narrowest input you need** — a function that reads only an id takes the id, not the whole entity.
7. **Be exhaustive in branching** — enumerate the real shapes; no blanket catch-all that swallows the case you did not foresee.

### C. Errors
8. **Never swallow a failure** — propagate a fallible result rather than replacing it with a hardcoded success, and give every branch of a function the same return shape.
9. **Typed errors, never raw strings** — define the error type before you return it.
10. **One error pipeline per app** — map once at the boundary; every layer in between only propagates.

### D. Contracts & boundaries
11. **Mirror the contract exactly** — optionality, cardinality, and required-ness flow through every layer unchanged; widening a contract hides it and breeds dead checks and ambiguous empty-versus-absent states.
12. **Application boundaries** — never reach into another app's data, never branch on who is calling, never re-implement a rule that lives on the other side, never document another app's behaviour here.

### E. Change hygiene & docs
13. **Change hygiene** — after editing, above all after removing, delete whatever the edit made pointless; comments stay current, and none of them narrates what the code used to be.
14. **Document the public API and keep it true** — a doc that cannot be verified from this repository alone is a boundary leak (#12).

### F. Testing
15. **Self-contained tests** — one group per unit under test; arrange the data under assertion inside the test body; reserve setup for harness wiring; no magic shared fixtures; prefer duplication over indirection; a test must be readable detached from its file.
```

- [ ] **Step 3: Verify the rules are numbered 1-15 and contiguous**

Run:
```bash
rg -o '^([0-9]+)\. ' -r '$1' \
  plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md \
  | sort -n | tr '\n' ' '
```
Expected exactly: `1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 `

- [ ] **Step 4: Verify the core-only tag**

Run:
```bash
rg -n '\(core-only\)' \
  plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md
```
Expected: exactly one line, rule `4`. Rules `16`–`21` get theirs in Task 4.

- [ ] **Step 5: Verify no Elixir or Dart in the snippets**

Run:
```bash
rg -c '```(elixir|dart)' \
  plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md
```
Expected: no matches (exit 1). The core skill must not lean on either language.

- [ ] **Step 6: Commit**

```bash
git add plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md
git commit -m "feat: add core code rules 1-15 to colette-code-conventions"
```

---

### Task 4: Core rules 16-21 (§ Workflow), red flags, mechanical enforcement

**Files:**
- Modify: `plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md`

**Interfaces:**
- Consumes: rules `1`–`15` from Task 3.
- Produces: the complete 22-rule core skill (`core #0`–`core #21`). Tasks 6 and 7 cite these numbers from the language skills.

- [ ] **Step 1: Add the § Workflow checklist**

Append after section F. Every rule here is `(core-only)` — no language skill cites them, because they are about how we work rather than what the code looks like.

```markdown
### G. Workflow
16. **Test first** — write the failing test that defines the behaviour before the implementation, and run it to watch it fail. A test that has never failed has proved nothing. (core-only)
17. **Small steps, always releasable** — identify the smallest next step, make it green, commit, repeat. The codebase is at every moment in a state you could ship. (core-only)
18. **Green build before commit** — format, lint, and the relevant tests pass. Each language skill names its own commands; there is no version of this rule where a red build is committed. (core-only)
19. **Atomic commits** — one logical change plus its tests, with a semantic prefix (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`) and an English message (#0). (core-only)
20. **PR hygiene** — say what changed and why, in English. When a change alters a convention, cite the rule number so the diff is findable later. (core-only)
21. **Isolate work** — a branch or worktree per unit of work, so an unfinished change never blocks a shippable one. (core-only)
```

- [ ] **Step 2: Add the red-flags section**

Append `## Red flags — stop and reconsider` as a bullet list, matching the voice of the existing two skills — each bullet is a symptom, an arrow, and the fix, closing with the rule number. Write one bullet per rule `#0`–`#15`; the workflow rules `#16`–`#21` do not get red flags, because they describe process rather than a shape you can spot in a diff. Generic red-flag lines that currently sit in the Elixir and Flutter skills move here in Tasks 6 and 7; write these fresh and language-neutral, for example:

```markdown
- **A non-English identifier, comment, doc line, test name, log message, or error string — anywhere** → rewrite it in English before doing anything else; the only non-English text we allow is a translated value inside a message catalogue (#0).
- A function whose final action is fallible, followed by a hardcoded success → return the fallible call's result; give every branch the same shape (#8).
- A catch-all branch standing in for cases you did not enumerate → list the real shapes and let an unforeseen one fail loudly (#7).
- A just-edited change that left a now-trivial wrapper, an unreachable branch, an unused constant, or a comment describing what the code used to do → remove it in the same change (#13).
- A test whose data or expected values live outside the test body → arrange inside the test; keep setup for harness wiring only (#15).
- A comment or doc describing what another application does internally → describe what this code guarantees instead (#12, #14).
```

- [ ] **Step 3: Add the mechanical-enforcement section**

Append `## Also enforced mechanically`, stating plainly which of these rules a tool can catch and which cannot. Formatters and linters catch some shape rules per language; **nothing checks Rule 0, change hygiene, boundary leaks, or test self-containment** — those are caught in review, so they must be checked on every diff read. Point at each language skill for the exact command set (`core #18`).

- [ ] **Step 4: Verify all 21 numbered rules are present and contiguous**

Run:
```bash
rg -o '^([0-9]+)\. ' -r '$1' \
  plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md \
  | sort -n | tr '\n' ' '
```
Expected exactly: `1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 `

- [ ] **Step 5: Verify the core-only set**

Run:
```bash
rg -o '^([0-9]+)\. .*\(core-only\)' -r '$1' \
  plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md \
  | sort -n | tr '\n' ' '
```
Expected exactly: `4 16 17 18 19 20 21 `

- [ ] **Step 6: Verify Rule 0 has its section**

Run:
```bash
rg -c '^## Rule 0' \
  plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md
```
Expected: `1`

- [ ] **Step 7: Commit**

```bash
git add plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md
git commit -m "feat: add workflow rules 16-21, red flags, enforcement notes"
```

---

### Task 5: reference.md

**Files:**
- Create: `plugins/colette-code-conventions/skills/colette-code-conventions/reference.md`

**Interfaces:**
- Consumes: the complete rule set from Tasks 2-4.
- Produces: `reference.md`, cited from `SKILL.md`'s Overview the way both existing skills cite theirs.

- [ ] **Step 1: Write the five worked examples**

Create the file with `# Colette Code Conventions — Reference` and these sections. Each shows a full before/after, not a fragment, and each names the rule it demonstrates.

| Section | Demonstrates | Language |
|---|---|---|
| `## An edit that is not finished` | `#13` — a removal, then everything it orphaned: a collapsed helper, a dead branch, an unused constant, a stale comment | Ruby |
| `## A test you can read detached from its file` | `#15` — a setup-and-shared-fixture test rewritten so each case carries its own arrange and expectations, siblings differing only in the fixture that drives the outcome | Python (pytest) |
| `## Three boundary leaks and their fixes` | `#12` — reading another service's table directly; branching on the calling client; re-implementing the other side's rule | SQL + TypeScript |
| `## One error pipeline, end to end` | `#8`, `#9`, `#10` — a typed error raised at the source, propagated untouched through the middle, mapped once at the boundary | TypeScript |
| `## A contract mirrored through the layers` | `#11` — an optional field staying optional and a required one staying required, from transport through to the view model | TypeScript |

Reuse none of the highest-risk snippets from `SKILL.md` verbatim — `reference.md` is where an example is allowed to be long enough to show the whole shape.

- [ ] **Step 2: Link reference.md from SKILL.md**

Add a line to `SKILL.md`'s Overview pointing at `reference.md` as the home of the longer worked examples, mirroring how `elixir-phoenix-conventions` and `flutter-conventions-guide` each cite theirs.

- [ ] **Step 3: Verify every section is present**

Run:
```bash
rg -n '^## ' plugins/colette-code-conventions/skills/colette-code-conventions/reference.md
```
Expected: the five section headings above, in order.

- [ ] **Step 4: Verify the cross-link exists**

Run:
```bash
rg -c 'reference\.md' \
  plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md
```
Expected: at least `1`

- [ ] **Step 5: Commit**

```bash
git add plugins/colette-code-conventions/skills/colette-code-conventions/reference.md \
        plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md
git commit -m "docs: add worked examples to colette-code-conventions reference"
```

---

### Task 6: Convert the Elixir skill to stubs

**Files:**
- Modify: `plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions/SKILL.md`
- Modify: `plugins/elixir-phoenix-conventions/.claude-plugin/plugin.json:3`

**Interfaces:**
- Consumes: `core #0`–`core #15` from Tasks 2-4.
- Produces: an Elixir skill citing `core #N` in the exact string form `core #N`, which Task 9's `check-references.sh` parses.

**Do not renumber anything.** Every stub keeps the number it has today.

- [ ] **Step 1: Add the dependency line to the Overview**

Insert immediately after the `## Overview` heading:

```markdown
This skill assumes `colette-code-conventions` is loaded — it carries the
language-agnostic rules (English-only, abstraction, error handling, boundaries,
change hygiene, self-contained tests, workflow), cited below as `core #N`.
Everything here is what Elixir and Phoenix add on top.
```

Then append `` (`core #1`) `` to the existing Overview sentence that tells the
reader to match the surrounding code, so the consistency rule is cited rather
than silently restated.

Leave the two existing core principles (the layering shape and the control-flow rule) exactly as they are — both are Elixir-specific.

- [ ] **Step 2: Convert the Rule 0 section**

Replace the body of `## Rule 0 — everything is in English. No exceptions.` with a stub. Keep the heading and keep the existing French/English `def creer_parrainage` snippet — that is the Elixir concretization. Replace the two rationale paragraphs (they now live in `core #0`) with:

```markdown
`core #0` states the rule and why it matters. Elixir tells: module, function and
variable names; `@moduledoc` and `@doc` text; `describe`/`test` names; typed-error
fields and messages; log and telemetry messages; migration and index names; seed
labels. The only non-English text allowed is a Gettext `.po` **value** — its keys,
and every comment around them, stay English. Non-English code you did not write is
not grandfathered: when you touch a function, rename its identifiers and rewrite
its comments in English as part of the same change (#56).
```

- [ ] **Step 3: Convert highest-risk rule 5**

Replace the body of `### 5. Single level of abstraction` with:

```markdown
→ `core #2`. Elixir tells: each function does one thing at one altitude
(~10–30 lines); extract steps into well-named `defp`s; no nested conditionals.
```

- [ ] **Step 4: Convert the twelve checklist entries**

Replace each numbered entry below with exactly this text. Everything not listed stays untouched.

```markdown
20. **Be exhaustive in `case`/`with`** → `core #7`. Elixir tells: no blanket `_ ->` — enumerate the real result shapes (`{:error, X}`, `{:error, Y}`, …) so an unexpected shape crashes rather than being silently mishandled. The chainable-query-builder fallthrough in #12 is the deliberate exception.
21. **Propagate fallible results** → `core #8`. Elixir tells: when a function's final action is `Repo.insert/update/delete`, `Oban.insert`, or another `{:ok,_}|{:error,_}` call, return *that call's* result — never a hardcoded `:ok`. A no-op or short-circuit head returns `{:ok, nil}`, not a bare `:ok`, so every head shares one contract callers can match on.
23. **Single level of abstraction** → `core #2`. Elixir tells: ~10–30 lines per function; extract steps into well-named `defp`s; no nested conditionals.
26. **Naming** → `core #3`. Elixir tells: predicates end `?`, raising functions end `!`, snake_case functions, PascalCase modules.
28. **Documentation** → `core #14`. Elixir tells: `@moduledoc` on every module (`false` for internal); `@doc` and `@spec` on the public API.
32. **Take an id, not a struct** → `core #6`. Elixir tells: when some callers hold the struct and others only the id, overload with a `%Schema{id: id}` head delegating to the id head — `def f(%Schema{id: id}, x), do: f(id, x)` then `def f(id, x) when is_binary(id), do: …`.
33. **Bind a computed value before placing it in a literal** → `core #5`. Elixir tells: `member_wish_ids = unserved_wish_ids_for_cluster(id)` above the map, then `%{cluster_id: id, member_wish_ids: member_wish_ids}` — not the call inlined as a map value.
38. **Typed errors** → `core #9`, `core #10`. Elixir tells: `MyApp.Errors.*` with `use MyApp.ExErrors` + `defexerror`; define-then-return — create `lib/my_app/errors/<name>_error.ex` before returning `Errors.X.new(...)`, never reference an undefined error module. Errors carry structured fields — `defexerror([:resource_type, :resource_id, message: "..."], required_fields: [:resource_type])` — which surface under `extensions.fields` beside `extensions.errorCode`. The mapping happens once, in the global middleware of #39.
53. **One `describe` per function** → `core #15`. Elixir tells: `describe "fun/arity"`, exactly one function per block and one block per function; tests read `test "when <condition>"`; `async: true` for pure tests; GraphQL via `query_gql(...)` + `load_gql_file`, where the `describe` names the `.gql` file.
54. **Self-contained tests** → `core #15`. Elixir tells: build entities in the test body (`insert(:user, invites_remaining: 1)`) with the fields the assertion depends on passed explicitly; reserve `setup` for Mox mode, `conn`, and sandbox wiring; no `@valid_attrs`/`@user_id` module attributes; where sibling tests cover different outcomes, let the fixture that varies be the only difference between them.
56. **Change hygiene** → `core #13`. Elixir tells: a helper collapsed to `defp f(x), do: x` gets inlined at its lone call site and removed; an unreachable clause and an unused `@attr` get deleted.
57. **Application boundaries** → `core #12`. Elixir tells: no second `Repo` pointed at another service's database, no schema module mirroring a table we don't own, no SQL across a boundary; no branching on the caller (`if client == "mobile"`) — audience-specific shaping is the web layer's job, which is exactly what the per-endpoint schema split (#35) is for. #47 is this same principle one level down, between contexts.
```

Keep the `#54` bad/good snippet that follows the entry — it is the Elixir concretization and stays.

- [ ] **Step 5: Prune the red flags**

In `## Red flags — stop and reconsider`, keep every bullet that names an Elixir construct and append its `core #N` citation where one now applies. Delete only bullets that are entirely language-neutral, since `core`'s own red-flag list carries them — concretely, delete the "A business rule re-implemented here because 'the client already does it too'" bullet.

- [ ] **Step 6: Update the mechanical-enforcement note**

In `## Also enforced mechanically`, keep the `mix format --check-formatted && mix credo --strict && mix test` command line and add that `core #18` states the rule this command enforces.

- [ ] **Step 7: Bump the plugin version**

```bash
jq '.version = "0.3.0"' \
  plugins/elixir-phoenix-conventions/.claude-plugin/plugin.json > /tmp/ep.json \
  && mv /tmp/ep.json plugins/elixir-phoenix-conventions/.claude-plugin/plugin.json
```

- [ ] **Step 8: Verify no rule numbers changed**

Run:
```bash
git show HEAD:plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions/SKILL.md \
  | rg -o '^[0-9]+\. ' | tr -d '. ' | sort -n > /tmp/before.txt
rg -o '^[0-9]+\. ' plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions/SKILL.md \
  | tr -d '. ' | sort -n > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt && echo "numbering unchanged"
```
Expected: `numbering unchanged`

- [ ] **Step 9: Verify the twelve stubs cite core**

Run:
```bash
rg -o '^([0-9]+)\. \*\*[^*]+\*\* → `core #' -r '$1' \
  plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions/SKILL.md \
  | sort -n | tr '\n' ' '
```
Expected exactly: `20 21 23 26 28 32 33 38 53 54 56 57 `

- [ ] **Step 10: Verify the version**

Run: `jq -r .version plugins/elixir-phoenix-conventions/.claude-plugin/plugin.json`
Expected: `0.3.0`

- [ ] **Step 11: Commit**

```bash
git add plugins/elixir-phoenix-conventions/
git commit -m "feat: point Elixir conventions at core rules (elixir v0.3.0)"
```

---

### Task 7: Convert the Flutter skill to stubs

**Files:**
- Modify: `plugins/flutter-conventions-guide/skills/flutter-conventions-guide/SKILL.md`
- Modify: `plugins/flutter-conventions-guide/.claude-plugin/plugin.json:3`

**Interfaces:**
- Consumes: `core #0`–`core #15` from Tasks 2-4.
- Produces: a Flutter skill citing `core #N` in the same string form as Task 6.

**Do not renumber anything.**

- [ ] **Step 1: Add the dependency line to the Overview**

Insert immediately after the `## Overview` heading:

```markdown
This skill assumes `colette-code-conventions` is loaded — it carries the
language-agnostic rules (English-only, abstraction, error handling, boundaries,
change hygiene, self-contained tests, workflow), cited below as `core #N`.
Everything here is what Flutter and Dart add on top.
```

Then append `` (`core #1`) `` to the existing Overview sentence stating that
consistency is the single most important property of these codebases, so the
rule is cited rather than silently restated.

- [ ] **Step 2: Annotate the three core principles**

Keep all three in full — they are the Flutter concretizations — and append a citation to the first two:

- Principle 1 (mirror the GraphQL schema's contract exactly) → append `` (`core #11`) ``
- Principle 2 (errors flow through ONE pipeline) → append `` (`core #8`, `core #10`) ``
- Principle 3 (three-tier cubit architecture) → unchanged, no citation; it is purely Flutter.

- [ ] **Step 3: Convert the Rule 0 section**

Keep the heading and the `construirePrix` bad/good snippet. Replace the two rationale paragraphs with:

```markdown
`core #0` states the rule and why it matters. Flutter tells: class, method and
variable names; file and directory names; doc comments and comments;
`group`/`test` names; `AppRoutes` values; `Palette` entries; log messages;
exception names and messages; ARB **keys** and their en `@`-descriptions. The one
exception is a message **value** in `app_fr.arb` — `app_en.arb` is the source of
truth, its keys are English (#71) and its `@`-metadata is English (#72). French
anywhere else is either a hardcoded user string (highest-risk #8) or a Rule 0
violation. Non-English code you did not write is not grandfathered: when you touch
a widget, cubit, or repo, rename its identifiers and rewrite its comments in
English as part of the same change (#90).
```

- [ ] **Step 4: Annotate highest-risk rules 1 and 7**

These stay in full — the exact idiom is the whole point — but each gains a citation on its heading line:

- `### 1. Forward unexpected errors to Bloc.observer with the exact idiom` → append `` → `core #8` ``
- `### 7. Repos only try/catch + rethrow — never map or toast` → append `` → `core #10` ``

- [ ] **Step 5: Convert the five checklist entries**

Replace each with exactly this text. Entries `77`–`81` are Flutter-specific testing rules and stay untouched.

```markdown
76. **Test layout** → `core #15`. Flutter tells: tests at `test/<same path as lib/>` with a `_test.dart` suffix, one file per source unit.
82. **Fixtures** → `core #15`. Flutter tells: build them with file-local private factories (`_wish(...)`, `_activity(...)`); for `fromMap`, build fully-populated maps matching the non-null schema.
83. **Grouping and naming** → `core #15`. Flutter tells: `group("<methodOrFeature>")`; tests named as present-tense behavioural sentences; drive Timers with `fakeAsync`; use explicit `tester.pump(Duration)` instead of `pumpAndSettle` when a perpetual spinner is in flight.
90. **Change hygiene** → `core #13`. Flutter tells: a wrapper widget that now only returns its child gets inlined at its lone call site and removed; an unreachable branch, an unused private method, a state field nobody reads any more (with its `copyWith` and `props` entries, #3), an orphaned ARB key (from BOTH files plus its en `@`metadata, #75), and a dead import get deleted.
91. **Application boundaries** → `core #12`. Flutter tells: never encode backend internals — no table or column names, no id format taken apart client-side, no assumption about how a value is stored or computed server-side; what the schema exposes is what exists. Never bypass the boundary we do have: no hardcoded URL or key (#85), no raw HTTP call sidestepping `GraphqlService` (#16). Shared code ships as a versioned package — a file copied across apps and kept in sync by hand is already out of sync.
```

- [ ] **Step 6: Prune the red flags**

Keep every bullet naming a Dart or Flutter construct and append its `core #N` citation where one applies. Delete only entirely language-neutral bullets, since core carries them — concretely, delete the "A rule recomputed client-side because 'the API doesn't return it yet'" bullet, whose Flutter-specific half (hardcoded endpoint, hand-synced file) is already covered by the `#91` stub above.

- [ ] **Step 7: Update the mechanical-enforcement note**

Keep the `flutter analyze` / `flutter gen-l10n` / `flutter test` paragraph and the NOT-mechanically-enforced list. Add that `core #18` states the rule the command set enforces, and that Rule 0, change hygiene, and boundary leaks are core rules no linter checks in any language.

- [ ] **Step 8: Bump the plugin version**

```bash
jq '.version = "0.3.0"' \
  plugins/flutter-conventions-guide/.claude-plugin/plugin.json > /tmp/fc.json \
  && mv /tmp/fc.json plugins/flutter-conventions-guide/.claude-plugin/plugin.json
```

- [ ] **Step 9: Verify no rule numbers changed**

Run:
```bash
git show HEAD:plugins/flutter-conventions-guide/skills/flutter-conventions-guide/SKILL.md \
  | rg -o '^[0-9]+\. ' | tr -d '. ' | sort -n > /tmp/before.txt
rg -o '^[0-9]+\. ' plugins/flutter-conventions-guide/skills/flutter-conventions-guide/SKILL.md \
  | tr -d '. ' | sort -n > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt && echo "numbering unchanged"
```
Expected: `numbering unchanged`

- [ ] **Step 10: Verify the five stubs cite core**

Run:
```bash
rg -o '^([0-9]+)\. \*\*[^*]+\*\* → `core #' -r '$1' \
  plugins/flutter-conventions-guide/skills/flutter-conventions-guide/SKILL.md \
  | sort -n | tr '\n' ' '
```
Expected exactly: `76 82 83 90 91 `

- [ ] **Step 11: Verify the version**

Run: `jq -r .version plugins/flutter-conventions-guide/.claude-plugin/plugin.json`
Expected: `0.3.0`

- [ ] **Step 12: Commit**

```bash
git add plugins/flutter-conventions-guide/
git commit -m "feat: point Flutter conventions at core rules (flutter v0.3.0)"
```

---

### Task 8: Marketplace entry and README

**Files:**
- Modify: `.claude-plugin/marketplace.json`
- Modify: `README.md`

**Interfaces:**
- Consumes: the three `plugin.json` versions set in Tasks 2, 6, and 7.
- Produces: a marketplace whose entries match those manifests, which Task 9's `validate-manifests.sh` asserts.

- [ ] **Step 1: Add the third marketplace entry**

Insert into the `plugins` array of `.claude-plugin/marketplace.json`, **first** in the list, since the other two depend on it:

```json
{
  "name": "colette-code-conventions",
  "source": "./plugins/colette-code-conventions",
  "description": "Colette engineering conventions for every codebase regardless of language: English-only, abstraction and naming, error handling, contracts and application boundaries, change hygiene, self-contained tests, and the commit and review workflow. Prerequisite for elixir-phoenix-conventions and flutter-conventions-guide.",
  "version": "0.1.0",
  "author": { "name": "Colette Club" },
  "keywords": ["conventions", "best-practices", "code-quality", "workflow", "testing"]
}
```

- [ ] **Step 2: Bump the two existing entries**

Set `elixir-phoenix-conventions` to `"version": "0.3.0"` and `flutter-conventions-guide` to `"version": "0.3.0"`. Append to both descriptions: `Requires colette-code-conventions.`

- [ ] **Step 3: Update the README**

In the `## Plugins` list, add as the first bullet:

```markdown
- **colette-code-conventions** — language-agnostic engineering conventions
  (English-only codebase, abstraction and naming, error handling, contracts and
  application boundaries, change hygiene, self-contained tests, workflow).
  **Install this one first** — the two skills below cite its rules as `core #N`.
```

Keep the README at or under 50 lines.

- [ ] **Step 4: Verify the marketplace parses and has three entries**

Run:
```bash
jq -r '.plugins[] | "\(.name) \(.version) \(.source)"' .claude-plugin/marketplace.json
```
Expected:
```
colette-code-conventions 0.1.0 ./plugins/colette-code-conventions
elixir-phoenix-conventions 0.3.0 ./plugins/elixir-phoenix-conventions
flutter-conventions-guide 0.3.0 ./plugins/flutter-conventions-guide
```

- [ ] **Step 5: Verify the README length**

Run: `wc -l < README.md`
Expected: a number at or under `50`.

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin/marketplace.json README.md
git commit -m "feat: publish colette-code-conventions to the marketplace"
```

---

### Task 9: Validation scripts and CI

**Files:**
- Create: `scripts/validate-manifests.sh`
- Create: `scripts/check-references.sh`
- Create: `.github/workflows/validate.yml`

**Interfaces:**
- Consumes: the finished skill files from Tasks 2-8. Both scripts run from any directory and resolve the repo root from their own location.
- Produces: two scripts exiting 0 on success and 1 on failure, plus a workflow running them and Task 1's hook tests.

- [ ] **Step 1: Write the manifest validator**

Create `scripts/validate-manifests.sh`:

```bash
#!/usr/bin/env bash
# Verifies marketplace.json against each plugin's own manifest.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKET="$ROOT/.claude-plugin/marketplace.json"
FAIL=0
fail() { printf 'FAIL %s\n' "$1"; FAIL=1; }

command -v jq >/dev/null 2>&1 || { printf 'jq is required\n'; exit 1; }
jq -e . "$MARKET" >/dev/null 2>&1 || { printf 'FAIL marketplace.json does not parse\n'; exit 1; }

while IFS="$(printf '\t')" read -r name source version; do
  dir="$ROOT/${source#./}"
  manifest="$dir/.claude-plugin/plugin.json"
  if [ ! -d "$dir" ]; then fail "$name: source path missing: $source"; continue; fi
  if [ ! -e "$manifest" ]; then fail "$name: no plugin.json at $manifest"; continue; fi
  if ! jq -e . "$manifest" >/dev/null 2>&1; then fail "$name: plugin.json does not parse"; continue; fi
  pname="$(jq -r '.name' "$manifest")"
  pversion="$(jq -r '.version' "$manifest")"
  [ "$pname" = "$name" ] || fail "$name: plugin.json declares name '$pname'"
  [ "$pversion" = "$version" ] || fail "$name: marketplace says '$version', plugin.json says '$pversion'"
done <<EOF
$(jq -r '.plugins[] | [.name, .source, .version] | @tsv' "$MARKET")
EOF

[ "$FAIL" -eq 0 ] && printf 'manifests ok\n'
exit "$FAIL"
```

- [ ] **Step 2: Run the manifest validator**

Run: `bash scripts/validate-manifests.sh`
Expected: `manifests ok`, exit 0.

- [ ] **Step 3: Write the reference checker**

Create `scripts/check-references.sh`:

```bash
#!/usr/bin/env bash
# Verifies rule references across the three convention skills.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md"
ELIXIR="$ROOT/plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions/SKILL.md"
FLUTTER="$ROOT/plugins/flutter-conventions-guide/skills/flutter-conventions-guide/SKILL.md"

FAIL=0
fail() { printf 'FAIL %s\n' "$1"; FAIL=1; }

command -v rg >/dev/null 2>&1 || { printf 'ripgrep is required\n'; exit 1; }
for f in "$CORE" "$ELIXIR" "$FLUTTER"; do
  [ -e "$f" ] || { printf 'FAIL missing skill file: %s\n' "$f"; exit 1; }
done

# Rule numbers a skill declares: top-level "N. " list items.
declared() { rg --no-filename -o '^[0-9]+\. ' "$1" | tr -d '. ' | sort -n -u; }

# "core #N" citations across both language skills.
core_cited() {
  rg --no-filename -o 'core #[0-9]+' "$ELIXIR" "$FLUTTER" | rg -o '[0-9]+' | sort -n -u
}

# "#N" references within one skill, ignoring the qualified forms.
intra_refs() {
  sed -e 's/core #[0-9]*//g' -e 's/highest-risk #[0-9]*//g' "$1" \
    | rg -o '#[0-9]+' | tr -d '#' | sort -n -u
}

CORE_NUMS="$(declared "$CORE")"
CORE_LIST=" $(echo "$CORE_NUMS" | tr '\n' ' ')"

# 1. Core rules are contiguous 1-21, with Rule 0 as its own section.
if [ "$CORE_NUMS" != "$(seq 1 21)" ]; then
  fail "core rules are not contiguous 1-21; got:$(echo "$CORE_NUMS" | tr '\n' ' ')"
fi
rg -q '^## Rule 0' "$CORE" || fail "core skill has no '## Rule 0' section"

# 2. No duplicate rule numbers in any skill.
for f in "$CORE" "$ELIXIR" "$FLUTTER"; do
  total="$(rg -c '^[0-9]+\. ' "$f" || printf '0')"
  uniq_n="$(declared "$f" | wc -l | tr -d ' ')"
  [ "$total" = "$uniq_n" ] \
    || fail "$(basename "$(dirname "$f")"): $total numbered lines but $uniq_n unique numbers"
done

# 3. Every cited core #N exists.
for n in $(core_cited); do
  [ "$n" = "0" ] && continue
  echo "$CORE_LIST" | rg -q " $n " \
    || fail "core #$n is cited but not declared in the core skill"
done

# 4. Every core rule is cited by a language skill, or tagged (core-only).
CITED=" $(core_cited | tr '\n' ' ')"
for n in $CORE_NUMS; do
  echo "$CITED" | rg -q " $n " && continue
  rg -q "^$n\. .*\(core-only\)" "$CORE" \
    || fail "core #$n is neither cited by a language skill nor tagged (core-only)"
done

# 5. Intra-skill references resolve.
for f in "$ELIXIR" "$FLUTTER"; do
  own=" $(declared "$f" | tr '\n' ' ')"
  for n in $(intra_refs "$f"); do
    if [ "$n" = "0" ]; then
      rg -q 'Rule 0' "$f" || fail "$(basename "$f"): #0 referenced but no Rule 0 section"
      continue
    fi
    echo "$own" | rg -q " $n " \
      || fail "$(basename "$f"): #$n referenced but never declared"
  done
done

[ "$FAIL" -eq 0 ] && printf 'references ok\n'
exit "$FAIL"
```

- [ ] **Step 4: Run the reference checker**

Run: `bash scripts/check-references.sh`
Expected: `references ok`, exit 0. Any `FAIL` line names the exact rule number and file — fix the skill, not the script.

- [ ] **Step 5: Prove the checker actually catches a break**

Run:
```bash
sed -i.bak 's/`core #13`/`core #99`/' \
  plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions/SKILL.md
bash scripts/check-references.sh; echo "exit=$?"
mv plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions/SKILL.md.bak \
   plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions/SKILL.md
```
Expected: `FAIL core #99 is cited but not declared in the core skill` and `exit=1`, then the file is restored. A checker that passes on a deliberately broken reference is worse than none.

- [ ] **Step 6: Confirm the restore worked**

Run: `git diff --stat plugins/elixir-phoenix-conventions/`
Expected: no output — the `.bak` restore left the file byte-identical.

- [ ] **Step 7: Write the CI workflow**

Create `.github/workflows/validate.yml`:

```yaml
name: validate

on:
  pull_request:
  push:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install ripgrep
        run: sudo apt-get update && sudo apt-get install -y ripgrep

      - name: Hook script tests
        run: bash plugins/colette-code-conventions/hooks/inject-conventions.test.sh

      - name: Manifest validation
        run: bash scripts/validate-manifests.sh

      - name: Reference integrity
        run: bash scripts/check-references.sh
```

- [ ] **Step 8: Run all three checks together, as CI will**

Run:
```bash
bash plugins/colette-code-conventions/hooks/inject-conventions.test.sh && \
bash scripts/validate-manifests.sh && \
bash scripts/check-references.sh && echo "ALL GREEN"
```
Expected: `ALL GREEN`

- [ ] **Step 9: Commit**

```bash
git add scripts/ .github/
git commit -m "chore: add manifest, reference, and hook validation with CI"
```

---

### Task 10: Manual acceptance

**Files:** none — this is the gate before merge.

**Interfaces:**
- Consumes: everything. Nothing consumes this.

The hook can only be verified by a real session; no script can stand in for it. Run every step and record the result.

- [ ] **Step 1: Install the marketplace from this branch**

In a Claude Code session:
```
/plugin marketplace add /Users/djeusette/Code/colette-marketplace
/plugin install colette-code-conventions@colette-club
```
Expected: install succeeds and the plugin is listed.

- [ ] **Step 2: Confirm the injection fires on a non-Elixir, non-Flutter file**

Open a scratch repository that is neither Elixir nor Flutter. Edit any `.md` file.
Expected: the `colette-code-conventions` skill loads before the edit is applied. This is the whole point of the design — a documentation-only edit in a language neither existing skill covers must still pull the rules in.

- [ ] **Step 3: Confirm the dedup**

Edit a second file in the same session.
Expected: no second injection; the skill is already loaded.

- [ ] **Step 4: Confirm the Bash matcher**

In a fresh session, run a shell command before touching any file.
Expected: the injection fires on that first Bash call.

- [ ] **Step 5: Confirm the reset**

Run `/clear`, then edit a file.
Expected: the injection fires again — `SessionStart` cleared the marker.

- [ ] **Step 6: Confirm edits are never blocked**

Throughout the steps above, no edit was blocked or auto-approved by the hook.
Expected: permission behaviour is exactly as it was before the plugin was installed. If any edit was auto-approved, stop — `permissionDecision` has leaked into the output and Task 1 must be revisited.

- [ ] **Step 7: Clean up the marker directory**

```bash
rm -rf ~/.claude/colette-code-conventions
```

- [ ] **Step 8: Open the pull request**

Push the branch and open a PR with `gh pr create`. Title: `feat: add colette-code-conventions core skill`. The body should summarise:

- 22 core rules across a Code section and a Workflow section
- the `PreToolUse` hook on `Edit|Write|NotebookEdit|Bash`, one injection per session, reset at `SessionStart`, failing open on every error path
- 12 Elixir entries (14 rules) and 8 Flutter entries (10 rules) converted to numbered stubs keeping their language-specific tells, with no renumbering so existing `#57`/`#91` references stay valid
- manifest, reference-integrity, and hook tests wired into CI

and link both `docs/superpowers/specs/2026-08-27-colette-code-conventions-design.md` and `docs/superpowers/plans/2026-08-27-colette-code-conventions.md`.
