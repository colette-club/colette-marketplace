# Colette brainstorming — Increment 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `/colette:writing-plans`, which plans the next unshipped increment of a spec and only that one, ending the plan with its PR; `colette:brainstorming` hands its first increment to it.

**Architecture:** A second Markdown skill in `plugins/colette`. It finds the spec and its next increment, re-checks the increment against the code, then invokes `superpowers:writing-plans` with the increment's scope; the scope args move here from `colette:brainstorming`'s handoff. A spec without increments gets them drafted, using `colette:brainstorming`'s own sections, and approved first.

**Tech Stack:** Claude Code plugin skills, Ruby 3.4 + Minitest, `claude plugin eval`.

**Spec:** `docs/superpowers/specs/2026-10-19-colette-brainstorming-design.md` — **Increment 3 only** (its entry under "Increments of this work" and "How `colette:writing-plans` behaves"). Increments 1 (PR #8) and 2 (PR #10) have shipped. Increment 4 (routing `superpowers:writing-plans`) is out of scope: no hook change.

## Global Constraints

- Skill `plugins/colette/skills/writing-plans/SKILL.md`, name `writing-plans`, invoked as `/colette:writing-plans`. Third-person description with "Use when …"; no `disable-model-invocation`. The description does not claim to replace `superpowers:writing-plans`: that is increment 4.
- It cites EP-I4, EP-I5 and EP-E5 from `engineering-review:engineering-principles` and never restates them. It has the same dependency stops as `colette:brainstorming`: a missing plugin, or `engineering-review` older than 0.5.0.
- It invokes `superpowers:writing-plans` with args that start with `[colette]`, the marker increment 4's hook will let through.
- Status lines are exactly `- [ ] Not shipped` and `- [x] PR #<n>`. In its own template the increment number is `<i>` and the PR number `<n>`.
- The file count is a preference: aim for 10 code files, prefer at most 20. Only an increment that could be smaller is split.
- Expected code files: 2 (`plugin.json`, `marketplace.json`), released as colette `0.3.0`. Skills, tests, evals and fixtures are docs and tests.
- Tests come first; commit only on green; scripts are Ruby.

## Review Focus

1. No spec path is given and no spec has an unshipped increment: the skill says so and stops. Pinned in Task 1's content tests.
2. Every increment of the spec has shipped: the skill says so and stops. Pinned in Task 1.
3. The previous increment's PR is not merged, or that cannot be told: the skill says so and asks whether to plan anyway. Pinned in Task 1.
4. The code has moved since the spec was written: the skill proposes the change to the spec's Increments before planning. Pinned in Task 1.
5. A spec without increments is never planned as is: they are drafted and approved first. Pinned by Task 1's `spec-without-increments` eval and content test.

---

### Task 1: The `colette:writing-plans` skill, its tests and its eval cases

**Files:**
- Create: `plugins/colette/skills/writing-plans/SKILL.md`
- Modify: `plugins/colette/test/plugin_test.rb` (new class `WritingPlansSkillTest`)
- Create: `plugins/colette/evals/_fixtures/wishes-app-increment-1/` — `_fixtures/wishes-app` plus Increment 1's code and a spec:
  - an `archived_at` field and `archive_changeset/1` in `lib/app/wishes/wish.ex`;
  - `archive_wish/1` in `lib/app/wishes.ex`;
  - `priv/repo/migrations/20261001000000_add_archived_at_to_wishes.exs`;
  - `docs/superpowers/specs/2026-10-19-archive-wishes-design.md`, in `colette:brainstorming`'s template, with three increments: 1 "Archive a wish" (`- [x] PR #8`), 2 "See archived wishes in an Archived tab" (`list_archived_wishes/1` and a GraphQL field, `- [ ] Not shipped`), 3 "Restore an archived wish" (`restore_wish/1` and a mutation, `- [ ] Not shipped`).
- Create: `plugins/colette/evals/_fixtures/wishes-app-spec-without-increments/` — `_fixtures/wishes-app` plus `docs/superpowers/specs/2026-10-19-wish-reminders-design.md`: the wish-reminders design from `increments-stay-small`'s prompt, as plain sections, with no End goal and no Increments.
- Create: `plugins/colette/evals/plans-the-next-increment/{case.yaml,prompt.md,scaffold.sh,graders/*.md}`
- Create: `plugins/colette/evals/spec-without-increments/{case.yaml,prompt.md,scaffold.sh,graders/*.md}`
- Modify: `plugins/colette/evals/README.md` (two rows)

**Interfaces:**
- Produces: the skill `colette:writing-plans`, taking a spec path as its argument (optional). Task 2's handoff invokes it with the spec's path.

- [ ] **Step 1: Write the failing content tests**

```ruby
class WritingPlansSkillTest < Minitest::Test
  def skill = File.read(File.join(PLUGIN, "skills", "writing-plans", "SKILL.md"))
  def frontmatter = skill[/\A---\n(.*?)\n---\n/m, 1]

  def test_frontmatter_names_the_skill_and_says_when_to_use_it
    assert_match(/^name: writing-plans$/, frontmatter)
    assert_match(/Use when/, frontmatter)
    refute_match(/disable-model-invocation|instead of superpowers:writing-plans/, frontmatter)
  end

  def test_it_stops_when_a_dependency_is_missing_or_too_old
    ["superpowers:writing-plans", "engineering-review:engineering-principles", "EP-I4", "EP-I5", "EP-E5",
     "say it must be installed and enabled, and stop", "update `engineering-review` to 0.5.0 or later, and stop"].each { |text| assert_includes skill, text }
  end

  def test_it_finds_the_next_unshipped_increment_or_stops
    ["- [ ] Not shipped", "When no spec qualifies, say so and stop", "every increment has shipped"].each { |text| assert_includes skill, text }
  end

  def test_it_asks_before_planning_on_an_unmerged_previous_increment
    assert_includes skill, "ask whether to plan anyway"
  end

  def test_a_spec_without_increments_gets_them_approved_first
    ["is never planned as is", "../brainstorming/SKILL.md"].each { |text| assert_includes skill, text }
  end

  def test_it_rechecks_the_increment_against_the_code
    assert_includes skill, "propose the change to the spec's Increments section"
  end

  def test_it_plans_only_that_increment_and_ends_with_its_pr
    ["with args that start with `[colette]`", "Plan ONLY its Increment <i>", "covers Increment <i> only",
     "if it could be smaller, stop and split it in the spec", "push and create a PR", "never a local merge", "- [x] PR #<n>"].each do |text|
      assert_includes skill, text
    end
    refute_includes skill, "exceeds 20 code files"
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `ruby plugins/colette/test/plugin_test.rb`
Expected: 7 errors (no `SKILL.md`); the other 22 tests pass.

- [ ] **Step 3: Write the fixtures and the eval cases**

Both cases copy `spec-has-increments`' `case.yaml`/`scaffold.sh` pattern (scaffold pointing at their own fixture) and prompt frontmatter (`plugins: ["../..", "deps/engineering-review", "deps/superpowers"]`, `allowed_tools: [Read, Glob, Grep, Skill, Write]`).

- **`plans-the-next-increment`** (fixture `wishes-app-increment-1`). Prompt: `/colette:writing-plans docs/superpowers/specs/2026-10-19-archive-wishes-design.md`, then "PR #8 (Increment 1) is merged. You may read this repository without asking. I approve the plan you write; save it to docs/superpowers/plans/2026-10-19-archive-wishes-increment-2.md and stop once it is written: do not execute it."
  Graders on that path: `file_exists`; regex `Increment 2`; regex `push and create a PR`; regex `restore_wish` with `match: not_contains`; `tool_used` `Skill` `input_match: 'superpowers:writing-plans'` `min: 1`.
- **`spec-without-increments`** (fixture `wishes-app-spec-without-increments`). Prompt: `/colette:writing-plans docs/superpowers/specs/2026-10-19-wish-reminders-design.md`, then "You may read this repository without asking."
  Graders: `file_exists` `docs/superpowers/plans/**` `exists: false`; `llm`: "PASS if the final message proposes an end goal and a sequence of increments for the wish reminders spec, each one feature deployable on its own, and asks the person to approve them before any plan is written. FAIL if it writes or presents an implementation plan, or plans the whole spec at once."

Two README rows.

- [ ] **Step 4: Commit the tests**

```bash
git add plugins/colette/test/plugin_test.rb plugins/colette/evals
git commit -m "test(colette): add the writing-plans content tests and eval cases"
```

- [ ] **Step 5: Write `plugins/colette/skills/writing-plans/SKILL.md`**

Frontmatter description, for example: "Plans the next unshipped increment of a colette spec, and only that one, by running superpowers writing-plans with the increment's scope, and ends the plan with its pull request. Use when planning from a spec with an Increments section, or when the previous increment has shipped." Sections, in order:

1. **Before you start.** The same two checks and stops as `colette:brainstorming`, for `superpowers:writing-plans` and `engineering-review:engineering-principles`, then load the principles.
2. **Find the spec and the next increment.**
   - The spec is the path given; otherwise the most recent `docs/superpowers/specs/*.md` by its date that has an `## Increments` section with a `- [ ] Not shipped` line. When no spec qualifies, say so and stop. When two are equally recent, ask which.
   - The next increment is the first `### Increment` whose status line is `- [ ] Not shipped`. When none is left, say that every increment has shipped, and stop.
   - Check that the previous increment's PR (`- [x] PR #<n>`) is merged, from what the person said or with `gh pr view <n> --json state`. When it is not merged, or you cannot tell, say so and ask whether to plan anyway.
3. **A spec without increments** is never planned as is. Draft its End goal and Increments sections as `colette:brainstorming` does — read "What an increment is", "Drafting the increments" and "The spec" in `../brainstorming/SKILL.md`, next to this skill — play them back, and once the person approves them, write them into the spec and plan Increment 1.
4. **Re-check the increment** against the code as it is now: still one feature, still deployable alone, still the smallest step; estimate its code files. When shipping the earlier increments changed the picture, propose the change to the spec's Increments section, get it approved and write it, then plan.
5. **Run superpowers writing-plans.** Invoke `superpowers:writing-plans` with args that start with `[colette]`, then:

   > Spec: `<spec path>`. Plan ONLY its Increment <i> (`<title>`); other increments are out of scope, and the spec-coverage check covers Increment <i> only. The plan's header names the spec and Increment <i>. If the plan's file structure goes above the preferred 20 code files (tests and docs not counted), check that the increment is still the smallest that ships its feature; if it could be smaller, stop and split it in the spec instead of writing the plan. End the plan with a Finishing section: after the final review, take "push and create a PR" in `finishing-a-development-branch`, never a local merge; the PR description names the increment, the frontends and apps that depend on it and whether each must change, the deploy order, and what stays behind a flag; once the PR exists, commit the spec's status line `- [x] PR #<n>` for Increment <i> on the same branch and push.

   Execution stays superpowers': `superpowers:writing-plans` offers it.

- [ ] **Step 6: Run the tests**

Run: `ruby plugins/colette/test/plugin_test.rb` — Expected: `29 runs, … 0 failures, 0 errors`.
Run: `claude plugin validate ./plugins/colette` — Expected: pass.

- [ ] **Step 7: Run the two eval cases**

`ruby plugins/colette/evals/_lib/vendor_dependencies.rb`, then from a copy of `plugins/colette` outside `/Users`: `claude plugin eval <copy> --case <name> --runs 1 --ablation none --scaffold --trust-plugin --allow-tools Write --no-publish --judge-model sonnet`, once for each case.
Expected: both score 1.00.

- [ ] **Step 8: Commit**

```bash
git add plugins/colette/skills/writing-plans
git commit -m "feat(colette): add /colette:writing-plans — plan the next increment only, ending with its PR"
```

### Task 2: `colette:brainstorming` hands off to `colette:writing-plans`, released as 0.3.0

**Files:**
- Modify: `plugins/colette/skills/brainstorming/SKILL.md` ("The handoff")
- Modify: `plugins/colette/test/plugin_test.rb`:
  - `BrainstormingSkillTest`: replace `test_the_handoff_splits_only_an_increment_that_could_be_smaller`, `test_it_hands_off_the_first_increment_only_ending_with_a_pr` and `test_the_handoff_plans_only_the_first_increment`;
  - `ManifestTest`: version `0.3.0`.
- Modify: `plugins/colette/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (`0.3.0`), `README.md` (colette bullet)

**Interfaces:**
- Consumes: `colette:writing-plans` from Task 1.

- [ ] **Step 1: Write the failing tests**

Replace the three handoff tests in `BrainstormingSkillTest` with:

```ruby
  def test_the_handoff_goes_to_colette_writing_plans_for_increment_1
    ["invoke `colette:writing-plans` with the spec's path", "Increment 1"].each { |text| assert_includes skill, text }
    ["Plan ONLY its Increment 1", "push and create a PR"].each { |text| refute_includes skill, text }
  end
```

In `ManifestTest`, change `"0.2.0"` to `"0.3.0"`.

- [ ] **Step 2: Run them to see them fail**

Run: `ruby plugins/colette/test/plugin_test.rb`
Expected: 2 failures (the handoff test and the version); 27 runs in total.

- [ ] **Step 3: Rewrite the handoff and release**

"The handoff" becomes: "When superpowers says to invoke `superpowers:writing-plans`, invoke `colette:writing-plans` with the spec's path instead. It plans only the spec's next increment, Increment 1, and ends that plan with its pull request. Later increments are planned one at a time with `/colette:writing-plans`, after the previous one has shipped, with what it taught." The skipped-questions rule keeps pointing at "The handoff".

Version `0.3.0` in `plugin.json` and the marketplace entry. The README colette bullet adds: "`/colette:writing-plans` plans the next increment once the previous one has shipped."

- [ ] **Step 4: Run the tests and validators**

Run: `ruby plugins/colette/test/plugin_test.rb` — Expected: `27 runs, … 0 failures`.
Run: `ruby plugins/colette/test/route_skills_test.rb` and `ruby plugins/colette/test/vendor_dependencies_test.rb` — Expected: 7 and 5 runs, 0 failures.
Run: `claude plugin validate ./plugins/colette` and `claude plugin validate .` — Expected: both pass.

- [ ] **Step 5: Run the brainstorming evals**

From a fresh copy outside `/Users`, run `spec-has-increments`, `increments-stay-small` and `routes-brainstorming`. Expected: 1.00 each. They stop before planning, so they confirm that the handoff change broke nothing upstream of it.

- [ ] **Step 6: Commit**

```bash
git add plugins/colette/skills/brainstorming/SKILL.md plugins/colette/test/plugin_test.rb plugins/colette/.claude-plugin/plugin.json .claude-plugin/marketplace.json README.md
git commit -m "feat(colette): brainstorming hands its first increment to /colette:writing-plans (0.3.0)"
```

---

## Finishing

After the final review, in `superpowers:finishing-a-development-branch`, take **"push and create a PR"** against `main`, never a local merge.

- **Title:** `feat(colette): /colette:writing-plans — plan the next increment only`
- **Description**, ending with the Claude Code attribution line:
  - **Increment:** 3 of `docs/superpowers/specs/2026-10-19-colette-brainstorming-design.md`.
  - **Consumers:** `colette:brainstorming`'s handoff, in the same plugin, now goes to `colette:writing-plans`. No frontend or app must change.
  - **Deploy notes:** released as colette 0.3.0. Teammates get it on the next marketplace update. Nothing is behind a flag. `superpowers:writing-plans` is not routed yet; that is Increment 4.
  - **Tests:** the Ruby test counts, each eval case's score, and the validator results.
- Once the PR number exists, change Increment 3's status line in the spec to `- [x] PR #<n>`, commit `docs: mark colette increment 3 as PR #<n>` on the same branch, and push.
