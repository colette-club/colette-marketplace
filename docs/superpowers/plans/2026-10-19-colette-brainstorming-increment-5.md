# Colette brainstorming — Increment 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wherever `colette` is installed, Claude's own calls to `superpowers:writing-plans` go to `colette:writing-plans`; a typed `/superpowers:writing-plans` still runs plain superpowers.

**Architecture:** The existing `PreToolUse` hook on the `Skill` tool learns a second skill. It denies an unmarked `superpowers:writing-plans` call, and its reason names `colette:writing-plans`, just as it already does for brainstorming. `colette:writing-plans` claims superpowers' role in its description. It also offers the most recent spec when that spec has no Increments section, so a redirected plan with no spec path still has something to plan.

**Tech Stack:** POSIX `sh` hook, Ruby 3.4 + Minitest, `claude plugin eval`.

**Spec:** `docs/superpowers/specs/2026-10-19-colette-brainstorming-design.md` — **Increment 5 only** ("route `superpowers:writing-plans` to `colette:writing-plans`" and "How the routing works"). Increments 1–4 have shipped (PRs #8, #10, #11, #13).

## Global Constraints

- The hook stays POSIX `sh` with only `cat`, `grep` and `printf`. It fails open, and denies with the same stdout JSON shape (`hookEventName: PreToolUse`, `permissionDecision: deny`).
- A call whose args start with `[colette]` passes, for both skills. A typed `/superpowers:<skill>` never reaches the hook.
- The skill-name patterns allow a leading `/` and surrounding spaces, as the brainstorming one already does. Names that only start the same, such as `superpowers:writing-plans-extra`, pass.
- Deny reasons are `The colette plugin replaces superpowers:<skill> here. Invoke colette:<skill> with the same request instead; it runs superpowers:<skill> itself.`. The brainstorming text stays as it is, since evals grade its prefix.
- `hooks.json` keeps the matcher `Skill`, the exec-form command, `args: []` and `timeout: 10`. Only its description changes.
- Expected code files: 4 (`route-skills.sh`, `hooks.json`, `plugin.json`, `marketplace.json`). The spec says 3, and the PR corrects it. The preferred size is 20.
- Released as colette `0.5.0`. Tests come first; commit only on green; scripts are Ruby.

## Review Focus

1. A typed `/superpowers:writing-plans` is not redirected. Pinned by the `typed-superpowers-writing-plans-not-routed` eval.
2. `/superpowers:writing-plans` or a space-padded name, as Claude may send it, is denied. Pinned in Task 2's unit tests.
3. colette's own marked planner call passes, so planning never loops. Pinned in Task 2's unit tests and by the `routes-writing-plans` marker grader.
4. A redirected plan with no spec path, where the only spec has no Increments: the skill names that spec and asks to plan it, increments first. Pinned in Task 1's content test and by the `routes-a-plan-to-a-spec-without-increments` eval.
5. The brainstorming deny still names `colette:brainstorming` only. Pinned in Task 2's unit tests.

---

### Task 1: `colette:writing-plans` takes over superpowers' planning role

**Files:**
- Modify: `plugins/colette/skills/writing-plans/SKILL.md` (frontmatter description; "The spec" bullet)
- Modify: `plugins/colette/test/plugin_test.rb` (`WritingPlansSkillTest`)

**Interfaces:**
- Produces: the description that makes Claude pick `colette:writing-plans`, and the spec-lookup rule a redirected call with no spec path relies on.

- [ ] **Step 1: Write the failing tests**

In `test_frontmatter_names_the_skill_and_says_when_to_use_it`, replace `refute_match(/disable-model-invocation|instead of superpowers:writing-plans/, frontmatter)` with `refute_match(/disable-model-invocation/, frontmatter)` and `assert_match(/instead of superpowers:writing-plans, wherever colette is installed/, frontmatter)`. Then add:

```ruby
  def test_it_offers_the_most_recent_spec_when_it_has_no_increments
    assert_includes skill, "When no spec has an unshipped increment but the most recent spec has no Increments section, name it and ask whether to plan it"
  end
```

- [ ] **Step 2: Run them to see them fail**

Run: `ruby plugins/colette/test/plugin_test.rb` — Expected: 2 failures; 38 runs.

- [ ] **Step 3: Edit the skill**

- The description ends: "Use when planning from a spec with an Increments section, after the previous increment has shipped, or from requirements, instead of superpowers:writing-plans, wherever colette is installed."
- In "The spec" bullet, before "When the request gives neither requirements nor a spec that qualifies, say so and stop.", insert: "When no spec has an unshipped increment but the most recent spec has no Increments section, name it and ask whether to plan it: it gets increments first (see \"A spec without increments\")."

- [ ] **Step 4: Run the tests**

Run: `ruby plugins/colette/test/plugin_test.rb` — Expected: `38 runs, … 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add plugins/colette/skills/writing-plans/SKILL.md plugins/colette/test/plugin_test.rb
git commit -m "feat(colette): colette:writing-plans takes over superpowers' planning role"
```

### Task 2: The hook routes `superpowers:writing-plans`, with evals and the 0.5.0 release

**Files:**
- Modify: `plugins/colette/hooks/route-skills.sh`, `plugins/colette/hooks/hooks.json` (description)
- Modify: `plugins/colette/test/route_skills_test.rb`, `plugins/colette/test/plugin_test.rb` (`HooksTest`, `ManifestTest`)
- Create: `plugins/colette/evals/routes-writing-plans/`, `plugins/colette/evals/typed-superpowers-writing-plans-not-routed/`, `plugins/colette/evals/routes-a-plan-to-a-spec-without-increments/` (`case.yaml`, `prompt.md`, `scaffold.sh`, `graders/*.md`)
- Modify: `plugins/colette/evals/README.md` (three rows), `plugins/colette/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (`0.5.0`), `README.md` (colette bullet)

**Interfaces:**
- Consumes: Task 1's description and lookup rule; the `[colette]` marker `colette:writing-plans` already puts on its planner calls.

- [ ] **Step 1: Write the failing tests**

In `route_skills_test.rb`, in `test_lets_other_skills_through`, replace `"superpowers:writing-plans"` with `"superpowers:executing-plans"`, and add `"colette:writing-plans"` and `"superpowers:writing-plans-extra"`. Then add:

```ruby
  def reason(out) = JSON.parse(out).dig("hookSpecificOutput", "permissionDecisionReason")

  def test_denies_claudes_own_call_to_superpowers_writing_plans
    out, _err, status = route(call("superpowers:writing-plans", "Plan the next increment"))
    assert_equal "deny", JSON.parse(out).dig("hookSpecificOutput", "permissionDecision")
    assert_includes reason(out), "Invoke colette:writing-plans with the same request instead"
    refute_includes reason(out), "brainstorming"
    assert status.success?
  end

  def test_denies_writing_plans_named_with_a_slash_or_spaces
    ["/superpowers:writing-plans", " superpowers:writing-plans "].each do |skill|
      out, = route(real({ skill: skill }))
      assert_includes reason(out), "colette:writing-plans", skill
    end
  end

  def test_lets_colettes_own_planner_call_through
    out, = route(call("superpowers:writing-plans", "[colette] Spec: `docs/superpowers/specs/x-design.md`. Plan ONLY its Increment 2"))
    assert_equal "", out
  end

  def test_the_brainstorming_deny_names_colette_brainstorming_only
    out, = route(call("superpowers:brainstorming"))
    assert_includes reason(out), "Invoke colette:brainstorming with the same request instead"
    refute_includes reason(out), "writing-plans"
  end
```

In `HooksTest`, add `assert_includes File.read(File.join(PLUGIN, "hooks", "hooks.json")), "superpowers:writing-plans"`. In `ManifestTest`, change `"0.4.0"` to `"0.5.0"`, and in `test_readme_lists_colette` add `assert_includes readme, "Claude's own planning goes through it too"`.

- [ ] **Step 2: Run them to see them fail**

Run: `ruby plugins/colette/test/route_skills_test.rb` — Expected: 15 runs, with 2 failures or errors (`test_denies_claudes_own_call_to_superpowers_writing_plans`, `test_denies_writing_plans_named_with_a_slash_or_spaces`). The tests that let calls through, and the brainstorming deny, already pass; they pin behaviour the change must keep. Run: `ruby plugins/colette/test/plugin_test.rb` — Expected: 3 failures (`HooksTest`, version, README).

- [ ] **Step 3: Write the eval cases**

Prompt frontmatter as in `spec-has-increments`. Scaffolds layer fixtures on `_fixtures/wishes-app`.

- **`routes-writing-plans`** (overlay `wishes-app-increment-1`). Prompt, no slash: "Use the superpowers:writing-plans skill to plan the next increment of docs/superpowers/specs/2026-10-19-archive-wishes-design.md. PR #8 (Increment 1) is merged. You may read this repository without asking. I approve the plan you write; save it to docs/superpowers/plans/2026-10-19-archive-wishes-next-increment.md and stop once it is written: do not execute it."
  Graders: regex `replaces superpowers:writing-plans here` with `target: trace`; `tool_used` `Skill` `input_match: 'colette:writing-plans'` `min: 1`; `tool_used` `Skill` `input_match: '\[colette\] Spec'` `min: 1`; plan regex `list_archived_wishes`; plan regex `restore_wish\(` with `match: not_contains`.
- **`typed-superpowers-writing-plans-not-routed`** (overlay `wishes-app-increment-1`). Prompt: "/superpowers:writing-plans docs/superpowers/specs/2026-10-19-archive-wishes-design.md", then "PR #8 (Increment 1) is merged. You may read this repository without asking. I approve the plan you write; save it to docs/superpowers/plans/2026-10-19-archive-wishes-plain-plan.md and stop once it is written: do not execute it."
  Graders: `file_exists` on that plan; `tool_used` `Skill` `input_match: 'colette:writing-plans'` `min: 0` `max: 0`; regex `replaces superpowers:writing-plans here` with `target: trace` and `match: not_contains`.
- **`routes-a-plan-to-a-spec-without-increments`** (overlay `wishes-app-spec-without-increments`). Prompt, no slash: "Use the superpowers:writing-plans skill to plan the work in our latest spec." then "You may read this repository without asking."
  Graders: `file_exists` `docs/superpowers/plans/**` `exists: false`; `tool_used` `Skill` `input_match: 'colette:writing-plans'` `min: 1`; `llm`: "PASS if the final message names docs/superpowers/specs/2026-10-19-wish-reminders-design.md and, before any plan, proposes increments for it or asks to draft them for approval. FAIL if it writes or presents an implementation plan, or says there is nothing to plan."

Three README rows.

- [ ] **Step 4: Commit the tests**

```bash
git add plugins/colette/test plugins/colette/evals
git commit -m "test(colette): add the planning route's tests and eval cases"
```

- [ ] **Step 5: Extend the hook and release**

`route-skills.sh`:
- A `skill_is` function greps the payload for the `"skill"` key, with `superpowers:$1` between the optional `/` and spaces. The pattern is the existing one with the skill name as its parameter.
- `brainstorming`, then `writing-plans`, set the name. Anything else exits 0 silently.
- The marker check is unchanged.
- The deny JSON is printed with `printf`, with the name in the three places of the reason given in the Global Constraints.
- The header comment names both skills.

`hooks.json` description: "Send Claude's own calls to superpowers:brainstorming and superpowers:writing-plans to colette's own skills".

Version `0.5.0` in `plugin.json` and the marketplace entry. The README colette bullet, after the brainstorming routing sentence: "Claude's own planning goes through it too; typing `/superpowers:writing-plans` still runs plain superpowers."

- [ ] **Step 6: Run the tests and validators**

Run each Ruby test file. Expected: `route_skills` 15 runs, `plugin` 38, `make_repo` 2, `vendor_dependencies` 5, all with 0 failures. Run `claude plugin validate ./plugins/colette` and `claude plugin validate .`. Expected: both pass.

- [ ] **Step 7: Run the evals**

`ruby plugins/colette/evals/_lib/vendor_dependencies.rb`, then, from a copy of `plugins/colette` outside `/Users`, run the three new cases plus `routes-brainstorming`, `redirects-an-explicit-superpowers-call` and `typed-superpowers-not-routed`, which check that the brainstorming route is unchanged. Use `--runs 1 --ablation none --scaffold --trust-plugin --allow-tools Write --no-publish --judge-model sonnet`.
Expected: all 1.00.

- [ ] **Step 8: Commit**

```bash
git add plugins/colette/hooks plugins/colette/.claude-plugin/plugin.json .claude-plugin/marketplace.json README.md
git commit -m "feat(colette): route Claude's own superpowers:writing-plans calls to colette:writing-plans (0.5.0)"
```

---

## Finishing

After the final review, in `superpowers:finishing-a-development-branch`, take **"push and create a PR"** against `main`, never a local merge.

- **Title:** `feat(colette): route superpowers:writing-plans to colette:writing-plans`
- **Description**, ending with the Claude Code attribution line:
  - **Increment:** 5, the last, of `docs/superpowers/specs/2026-10-19-colette-brainstorming-design.md`. The increment's code-file count changes from 3 to 4, because `hooks.json`'s description changes.
  - **Consumers:** every session where `colette` is installed. Claude's own planning, including the handoff after a typed `/superpowers:brainstorming`, now goes through colette. A typed `/superpowers:writing-plans` is unchanged. No frontend or app must change.
  - **Deploy notes:** released as colette 0.5.0. Teammates get it on the next marketplace update, and the hook loads in new sessions or after `/reload-plugins`. Nothing is behind a flag. The hook fails open.
  - **Tests:** the Ruby test counts, each eval case's score, and the validator results.
- Once the PR number exists, change Increment 5's status line in the spec to `- [x] PR #<n>`, and its code-file line to `4 — route-skills.sh, hooks.json, plugin.json, marketplace.json`. Commit `docs: mark colette increment 5 as PR #<n>` on the same branch, and push.
