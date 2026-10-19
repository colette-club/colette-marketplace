# Colette brainstorming — Increment 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wherever `colette` is installed, Claude's own calls to `superpowers:brainstorming` go to `colette:brainstorming`, while a typed `/superpowers:brainstorming` still runs plain superpowers.

**Architecture:** A `PreToolUse` hook on the `Skill` tool, shipped in the plugin, denies any `superpowers:brainstorming` call that is not marked as colette's own and tells Claude to invoke `colette:brainstorming` instead. `colette:brainstorming` marks its own call by starting the args with `[colette]`, and its description claims superpowers' role so Claude often picks it directly.

**Tech Stack:** Claude Code plugin hooks (`hooks/hooks.json`), POSIX `sh` with `grep` and `cat` only, Ruby 3.4 + Minitest, `claude plugin eval`.

**Spec:** `docs/superpowers/specs/2026-10-19-colette-brainstorming-design.md` — **Increment 2 only** ("route `superpowers:brainstorming` to `colette:brainstorming`" and "How the routing works"). Increment 1 shipped in PR #8. Increments 3 and 4 (`/colette:writing-plans`, the planning route) are out of scope: `superpowers:writing-plans` stays unrouted.

## Global Constraints

- The hook is a POSIX `sh` script with no dependencies: no `jq`, Deno, Node, Python or Ruby. It runs on every teammate's machine.
- The hook fails open. On input it cannot read, or on any error, it prints nothing and exits 0, so the call goes through.
- It denies with this stdout JSON and exit 0: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`. The reason names `colette:brainstorming`.
- Marker: colette's own call to `superpowers:brainstorming` has `args` starting with `[colette]`. A call carrying the marker passes.
- A typed `/superpowers:brainstorming` does not go through the Skill tool, so it is untouched. No `UserPromptExpansion` hook.
- `hooks/hooks.json` uses exec form: `"command": "${CLAUDE_PLUGIN_ROOT}/hooks/route-skills.sh"`, `"args": []`, `"timeout": 10`, `"matcher": "Skill"`. The script is executable.
- The Skill tool's input fields are `skill` and `args`.
- Neither skill sets `disable-model-invocation`.
- Expected code files: 4 (`hooks/hooks.json`, `hooks/route-skills.sh`, `plugin.json`, `marketplace.json`). The preferred size is 20.
- `colette` is released as `0.2.0`. Tests come first; commit only on green; test scripts are Ruby.

## Review Focus

1. A payload that is pretty-printed (`"skill": "superpowers:brainstorming"` with spaces) is still denied. Pinned in Task 2's unit tests.
2. A skill whose name only starts with `superpowers:brainstorming` (`superpowers:brainstorming-extra`) passes. Pinned in Task 2.
3. A `colette:brainstorming` call whose args quote `"skill":"superpowers:brainstorming"` (escaped inside the JSON string) passes. Pinned in Task 2.
4. Empty or unreadable stdin passes silently, so the hook fails open. Pinned in Task 2.
5. After a deny, Claude goes on with `colette:brainstorming` and the spec still gets its Increments. Pinned by Task 2's `routes-brainstorming` eval.

---

### Task 1: `colette:brainstorming` marks its own call and claims superpowers' role

**Files:**
- Modify: `plugins/colette/skills/brainstorming/SKILL.md` (frontmatter description; "Run superpowers brainstorming" section)
- Modify: `plugins/colette/test/plugin_test.rb` (`BrainstormingSkillTest`)

**Interfaces:**
- Produces: the marker contract the hook relies on: colette invokes `superpowers:brainstorming` with `args` that start with `[colette]`.

- [ ] **Step 1: Write the failing tests**

Add to `BrainstormingSkillTest`:

```ruby
  def test_it_marks_its_own_call_to_superpowers
    assert_includes skill, "with args that start with `[colette]`"
  end

  def test_its_description_takes_over_from_superpowers_brainstorming
    assert_includes frontmatter, "instead of superpowers:brainstorming"
  end
```

- [ ] **Step 2: Run them to see them fail**

Run: `ruby plugins/colette/test/plugin_test.rb`
Expected: 2 failures (`test_it_marks_its_own_call_to_superpowers`, `test_its_description_takes_over_from_superpowers_brainstorming`). The other 19 tests pass.

- [ ] **Step 3: Edit the skill**

- Description: keep what it does, then "Use when designing a feature, change or project, instead of superpowers:brainstorming, wherever colette is installed." Keep it in the third person.
- "Run superpowers brainstorming": "Invoke `superpowers:brainstorming` with args that start with `[colette]`, followed by the person's request. The marker tells colette's hook that this call is colette's own; without it the call is redirected back here." Then the rest of the section, unchanged.

- [ ] **Step 4: Run the tests**

Run: `ruby plugins/colette/test/plugin_test.rb`
Expected: `21 runs, … 0 failures, 0 errors`.

- [ ] **Step 5: Commit**

```bash
git add plugins/colette/skills/brainstorming/SKILL.md plugins/colette/test/plugin_test.rb
git commit -m "feat(colette): mark colette's own call to superpowers:brainstorming and take over its role"
```

### Task 2: The routing hook, its evals and the 0.2.0 release

**Files:**
- Create: `plugins/colette/hooks/route-skills.sh` (mode 755)
- Create: `plugins/colette/hooks/hooks.json`
- Create: `plugins/colette/test/route_skills_test.rb`
- Modify: `plugins/colette/test/plugin_test.rb` (new class `HooksTest`; `ManifestTest` version `0.2.0`)
- Create: `plugins/colette/evals/routes-brainstorming/{case.yaml,prompt.md,scaffold.sh,graders/*.md}`
- Create: `plugins/colette/evals/typed-superpowers-not-routed/{case.yaml,prompt.md,scaffold.sh,graders/*.md}`
- Modify: `plugins/colette/evals/README.md` (two rows)
- Modify: `plugins/colette/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (`0.2.0`), `README.md` (colette bullet)

**Interfaces:**
- Consumes: Task 1's marker (`args` starting with `[colette]`).
- Produces: `hooks/route-skills.sh`. It reads a PreToolUse payload on stdin and either prints the deny JSON or prints nothing; it always exits 0. Increment 4 adds `superpowers:writing-plans` to it.

- [ ] **Step 1: Write the failing tests**

`plugins/colette/test/route_skills_test.rb`. It runs the script directly with `env -i PATH=/usr/bin:/bin`, through `Open3.capture3` with `stdin_data`, so it only sees what every machine has:

```ruby
require "minitest/autorun"
require "open3"
require "json"

class RouteSkillsTest < Minitest::Test
  SCRIPT = File.expand_path("../hooks/route-skills.sh", __dir__)

  def route(stdin) = Open3.capture3({ "PATH" => "/usr/bin:/bin" }, SCRIPT, stdin_data: stdin, unsetenv_others: true)
  def call(skill, args = "Let's build X") = JSON.generate({ hook_event_name: "PreToolUse", tool_name: "Skill", tool_input: { skill: skill, args: args } })

  def test_denies_claudes_own_call_to_superpowers_brainstorming
    out, _err, status = route(call("superpowers:brainstorming"))
    decision = JSON.parse(out).fetch("hookSpecificOutput")
    assert_equal ["PreToolUse", "deny"], decision.values_at("hookEventName", "permissionDecision")
    assert_includes decision["permissionDecisionReason"], "colette:brainstorming"
    assert status.success?
  end

  def test_denies_a_pretty_printed_payload
    out, = route(JSON.pretty_generate(JSON.parse(call("superpowers:brainstorming"))))
    assert_equal "deny", JSON.parse(out).dig("hookSpecificOutput", "permissionDecision")
  end

  def test_lets_colettes_own_call_through
    out, _err, status = route(call("superpowers:brainstorming", "[colette] Let's build X"))
    assert_equal "", out
    assert status.success?
  end

  def test_lets_other_skills_through
    ["superpowers:writing-plans", "colette:brainstorming", "superpowers:brainstorming-extra"].each do |skill|
      out, _err, status = route(call(skill))
      assert_equal "", out, skill
      assert status.success?, skill
    end
  end

  def test_lets_through_a_call_that_only_quotes_the_name_in_its_args
    out, = route(call("colette:brainstorming", %q({"skill":"superpowers:brainstorming"})))
    assert_equal "", out
  end

  def test_fails_open_on_input_it_cannot_read
    ["", "not json"].each do |stdin|
      out, _err, status = route(stdin)
      assert_equal "", out
      assert status.success?
    end
  end
end
```

Add to `plugin_test.rb`:

```ruby
class HooksTest < Minitest::Test
  def test_a_skill_call_runs_the_routing_hook_in_exec_form
    entry = JSON.parse(File.read(File.join(PLUGIN, "hooks", "hooks.json"))).dig("hooks", "PreToolUse", 0)
    assert_equal "Skill", entry["matcher"]
    hook = entry.dig("hooks", 0)
    assert_equal ["command", "${CLAUDE_PLUGIN_ROOT}/hooks/route-skills.sh", [], 10], hook.values_at("type", "command", "args", "timeout")
    assert File.executable?(File.join(PLUGIN, "hooks", "route-skills.sh"))
  end
end
```

In `ManifestTest`, change `"0.1.0"` to `"0.2.0"`.

- [ ] **Step 2: Run them to see them fail**

Run: `ruby plugins/colette/test/route_skills_test.rb` — Expected: 6 errors (no script).
Run: `ruby plugins/colette/test/plugin_test.rb` — Expected: 2 failures/errors (`HooksTest`, the version).

- [ ] **Step 3: Write the eval cases**

Both cases copy `spec-has-increments`' `case.yaml`/`scaffold.sh` pattern and its prompt frontmatter (`plugins: ["../..", "deps/engineering-review", "deps/superpowers"]`, `allowed_tools: [Read, Glob, Grep, Skill, Write]`), and need `ruby plugins/colette/evals/_lib/vendor_dependencies.rb` re-run to get their `deps/`.

- **`routes-brainstorming`** — the `spec-has-increments` prompt *without* the `/colette:brainstorming` line; it opens "Let's build a feature in this app: members can archive a wish they no longer want." Graders: `tool_used` `Skill` `input_match: 'colette:brainstorming'` `min: 1`; file regex `^## Increments` (`m`) on `docs/superpowers/specs/2026-10-19-archive-wishes-design.md`.
- **`typed-superpowers-not-routed`** — the same prompt starting with `/superpowers:brainstorming`. Graders: `file_exists` on the spec path; file regex `^## Increments` (`m`) with `match: not_contains`.

README rows: one line each, in the existing table.

- [ ] **Step 4: Commit the tests**

```bash
git add plugins/colette/test plugins/colette/evals
git commit -m "test(colette): add the routing hook's tests and eval cases"
```

- [ ] **Step 5: Write the hook, its registration and the release**

`hooks/route-skills.sh` (`#!/bin/sh`, `chmod 755`):
- Read stdin with `cat`; on failure exit 0.
- No match for `grep -Eq '"skill"[[:space:]]*:[[:space:]]*"superpowers:brainstorming"'` → exit 0 silently. The closing quote rules out `superpowers:brainstorming-extra`, and an escaped `\"skill\"` inside args cannot match.
- `"args"[[:space:]]*:[[:space:]]*"\[colette\]` matches → exit 0 silently.
- Otherwise print the deny JSON on one line. Reason: "The colette plugin replaces superpowers:brainstorming here. Invoke colette:brainstorming with the same request instead; it runs superpowers:brainstorming itself."

Three comment lines at the top say what it does, the marker, and that it fails open.

`hooks/hooks.json`: `{"description": "Send Claude's own calls to superpowers:brainstorming to colette:brainstorming", "hooks": {"PreToolUse": [{"matcher": "Skill", "hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/route-skills.sh", "args": [], "timeout": 10}]}]}}`

Version `0.2.0` in `plugin.json` and the marketplace entry. The README colette bullet adds: "Wherever it is installed, Claude's own brainstorming goes through it; typing `/superpowers:brainstorming` still runs plain superpowers."

- [ ] **Step 6: Run the tests and the validators**

Run: `ruby plugins/colette/test/route_skills_test.rb` — Expected: `6 runs, … 0 failures, 0 errors`.
Run: `ruby plugins/colette/test/plugin_test.rb` — Expected: `22 runs, … 0 failures, 0 errors`.
Run: `ruby plugins/colette/test/vendor_dependencies_test.rb` — Expected: `5 runs, … 0 failures`.
Run: `claude plugin validate ./plugins/colette` and `claude plugin validate .` — Expected: both pass.

- [ ] **Step 7: Run the evals**

`ruby plugins/colette/evals/_lib/vendor_dependencies.rb`. Then, from a copy of `plugins/colette` outside `/Users` (this sandbox cannot list `/Users`): `claude plugin eval <copy> --runs 1 --ablation none --scaffold --trust-plugin --allow-tools Write --no-publish --judge-model sonnet -j 2`.
Expected: all four cases score 1.00. A `routes-brainstorming` failure where `superpowers:brainstorming` ran unredirected means the payload's field names differ from `skill`/`args`. In that case, add a temporary hook that logs stdin, read the real shape, fix the pattern and its test, and ledger the ruling.

- [ ] **Step 8: Commit**

```bash
git add plugins/colette/hooks plugins/colette/.claude-plugin/plugin.json .claude-plugin/marketplace.json README.md
git commit -m "feat(colette): route Claude's own superpowers:brainstorming calls to colette:brainstorming (0.2.0)"
```

---

## Finishing

After the final review, in `superpowers:finishing-a-development-branch`, take **"push and create a PR"** against `main`, never a local merge.

- **Title:** `feat(colette): route superpowers:brainstorming to colette:brainstorming`
- **Description**, ending with the Claude Code attribution line:
  - **Increment:** 2 of `docs/superpowers/specs/2026-10-19-colette-brainstorming-design.md`.
  - **Consumers:** every session where `colette` is installed. Claude's own brainstorming now goes through colette. A typed `/superpowers:brainstorming` is unchanged. No frontend or app must change.
  - **Deploy notes:** released as colette 0.2.0. Teammates get it on the next marketplace update; the hook loads in new sessions or after `/reload-plugins`. Nothing is behind a flag. The hook fails open.
  - **Tests:** the Ruby test counts, each eval case's score, and the validator results.
- Once the PR number exists, change Increment 2's status line in the spec to `- [x] PR #<n>`, commit `docs: mark colette increment 2 as PR #<n>` on the same branch, and push.
