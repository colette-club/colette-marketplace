# Colette brainstorming — Increment 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/colette:writing-plans` plans from requirements given with no spec, the way `superpowers:writing-plans` does. One increment's worth is planned directly; bigger work gets increments approved and saved as a short spec, then Increment 1 is planned.

**Architecture:** One new section, "Requirements with no spec", in `plugins/colette/skills/writing-plans/SKILL.md`, and a rule that the request's requirements, when given, are what to plan. The one-increment path invokes `superpowers:writing-plans` with `[colette] Requirements: …` scope args; the bigger path reuses the spec-without-increments drafting. Released as colette 0.4.0, which also ships the review follow-ups merged in #12.

**Tech Stack:** Claude Code plugin skills, Ruby 3.4 + Minitest, `claude plugin eval`.

**Spec:** `docs/superpowers/specs/2026-10-19-colette-brainstorming-design.md` — **Increment 4 only** ("`/colette:writing-plans` plans from requirements", and step 0 of "How `colette:writing-plans` behaves"). Increment 5, routing `superpowers:writing-plans`, is out of scope: no hook change.

## Global Constraints

- Requirements in the request are what to plan; a spec is looked up only when the request gives none.
- One increment's worth (EP-I4, EP-I5, EP-E5) is planned directly, with no spec file. Bigger work gets an End goal and Increments drafted with `colette:brainstorming`'s sections, played back, saved once approved as `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, and its Increment 1 planned.
- Every call to `superpowers:writing-plans` starts its args with `[colette]`, the marker increment 5's hook will let through.
- The description may say the skill plans from requirements, but does not claim to replace `superpowers:writing-plans`: that is increment 5.
- File count: aim for 10, prefer at most 20. Only work that could be smaller is split.
- Expected code files: 2 (`plugin.json`, `marketplace.json`) for colette `0.4.0`.
- Tests come first; commit only on green; scripts are Ruby.

## Review Focus

1. A request that gives requirements while an older spec still has unshipped increments: the requirements are planned, not the old spec. Pinned in the content tests.
2. Requirements that fit in one increment: no spec file is written. Pinned by the `plans-small-requirements` eval and a content test.
3. Requirements found too big only while planning (the file structure could be smaller): the planner stops, and they get increments first. Pinned in the content tests.
4. Approved increments are saved as a short spec with a Why and colette's two sections, so `/colette:writing-plans` can plan the next one later. Pinned in the content tests.
5. A request with neither requirements nor a spec: the skill says so and stops. Pinned in the content tests.

---

### Task 1: Plan from requirements, with tests, evals and the 0.4.0 release

**Files:**
- Modify: `plugins/colette/skills/writing-plans/SKILL.md` (frontmatter description; "Find the spec and the next increment"; new section "Requirements with no spec" after "A spec without increments")
- Modify: `plugins/colette/test/plugin_test.rb` (`WritingPlansSkillTest`; `ManifestTest` version and README)
- Create: `plugins/colette/evals/plans-small-requirements/{case.yaml,prompt.md,scaffold.sh,graders/*.md}`
- Create: `plugins/colette/evals/big-requirements-get-increments/{case.yaml,prompt.md,scaffold.sh,graders/*.md}`
- Modify: `plugins/colette/evals/README.md` (two rows)
- Modify: `plugins/colette/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (`0.4.0`), `README.md` (colette bullet)

**Interfaces:**
- Produces: `colette:writing-plans` accepting requirements as its argument; the `[colette] Requirements: …` args shape that increment 5's hook sees.

- [ ] **Step 1: Write the failing content tests**

In `WritingPlansSkillTest`:
- In `test_it_finds_the_next_unshipped_increment_or_stops`, replace `"When no spec qualifies, say so and stop"` with `"When the request gives neither requirements nor a spec that qualifies, say so and stop"`.
- In `test_frontmatter_names_the_skill_and_says_when_to_use_it`, add `assert_match(/from requirements/, frontmatter)`.
- Add:

```ruby
  def test_it_plans_from_requirements_like_superpowers
    ["## Requirements with no spec", "When the request gives requirements, they are what to plan; a spec is looked up only when it gives none",
     "plan it directly, with no spec file", "Requirements: <the requirements, as given>. Plan them as one increment",
     "if it could be smaller, stop: the requirements need increments first",
     "save them as a short spec at `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, with a Why from the requirements, then the two sections"].each do |text|
      assert_includes skill, text
    end
  end
```

In `ManifestTest`, change `"0.3.0"` to `"0.4.0"`, and in `test_readme_lists_colette` add `assert_includes readme, "plans from requirements too"`.

- [ ] **Step 2: Run them to see them fail**

Run: `ruby plugins/colette/test/plugin_test.rb`
Expected: 5 failures (`test_it_finds_the_next_unshipped_increment_or_stops`, `test_frontmatter_names_the_skill_and_says_when_to_use_it`, `test_it_plans_from_requirements_like_superpowers`, `test_marketplace_lists_colette_at_the_plugin_version`, `test_readme_lists_colette`); 32 runs.

- [ ] **Step 3: Write the eval cases**

Both use the base fixture: `scaffold.sh` like `spec-has-increments`' (`make-repo.sh "$here/../_fixtures/wishes-app"`). The prompt frontmatter is the same as `spec-has-increments`'.

- **`plans-small-requirements`.** Prompt: "/colette:writing-plans Members can rename a wish: add `update_wish_title/2` to `App.Wishes` and an `updateWishTitle` mutation for the mobile app and the web front." then "You may read this repository without asking. I approve the plan you write; save it to docs/superpowers/plans/2026-10-19-rename-wish.md and stop once it is written: do not execute it."
  Graders:
  - `file_exists` on that plan;
  - `tool_used` `Skill` `input_match: '\[colette\] Requirements'` `min: 1`;
  - `file_exists` `docs/superpowers/specs/**` `exists: false`;
  - regex `push and create a PR` on the plan.
- **`big-requirements-get-increments`.** Prompt: "/colette:writing-plans " plus the wish-reminders requirements from `increments-stay-small`'s prompt, in one paragraph, then "You may read this repository without asking."
  Graders:
  - `file_exists` `docs/superpowers/plans/**` `exists: false`;
  - `file_exists` `docs/superpowers/specs/**` `exists: false`;
  - `llm`: "PASS if the final message proposes an end goal and a sequence of increments for the wish reminders requirements, each one feature deployable on its own, and asks the person to approve them before any plan or spec is written. FAIL if it writes or presents an implementation plan, or plans everything at once."

Two README rows.

- [ ] **Step 4: Commit the tests**

```bash
git add plugins/colette/test/plugin_test.rb plugins/colette/evals
git commit -m "test(colette): add the plan-from-requirements content tests and eval cases"
```

- [ ] **Step 5: Edit the skill, and release**

- **Description:** "Plans the next unshipped increment of a colette spec, and only that one, or plans from requirements as superpowers writing-plans does, one increment at a time; ends the plan with its pull request. Use when planning from a spec with an Increments section, after the previous increment has shipped, or from requirements."
- **"Find the spec and the next increment":** before the spec bullet, add "**The request** comes first. When the request gives requirements, they are what to plan; a spec is looked up only when it gives none (see "Requirements with no spec")." In the spec bullet, "When no spec qualifies, say so and stop." becomes "When the request gives neither requirements nor a spec that qualifies, say so and stop."
- **New section "## Requirements with no spec"**, after "A spec without increments":
  - Plan them the way `superpowers:writing-plans` does, with colette's rule. Read the code (reading needs no permission), then decide with EP-I4, EP-I5 and EP-E5 whether they fit in one increment.
  - **One increment:** plan it directly, with no spec file. Invoke `superpowers:writing-plans` with args that start with `[colette]`, followed by:

    > Requirements: <the requirements, as given>. Plan them as one increment: `<title>`. If the plan's file structure goes above the preferred 20 code files (tests and docs not counted), check that it is still the smallest step that ships the feature; if it could be smaller, stop: the requirements need increments first. End the plan with a Finishing section: after the final review, take "push and create a PR" in `finishing-a-development-branch`, never a local merge; the PR description names the change, the frontends and apps that depend on it and whether each must change, the deploy order, and what stays behind a flag.

  - **More than one increment:** draft an End goal and Increments from them, as for a spec without increments, and play them back. Once the person approves them, save them as a short spec at `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, with a Why from the requirements, then the two sections, and plan its Increment 1 as in "Run superpowers writing-plans".
- **Release:** version `0.4.0` in `plugin.json` and the marketplace entry. The README colette bullet adds "`/colette:writing-plans` plans from requirements too, as superpowers does: one increment directly, bigger work as increments first." It must contain the exact phrase "plans from requirements too".

- [ ] **Step 6: Run the tests and validators**

Run: `ruby plugins/colette/test/plugin_test.rb` — Expected: `32 runs, … 0 failures, 0 errors`.
Run: `ruby plugins/colette/test/route_skills_test.rb`, `make_repo_test.rb`, `vendor_dependencies_test.rb` — Expected: 11, 2 and 5 runs, 0 failures.
Run: `claude plugin validate ./plugins/colette` and `claude plugin validate .` — Expected: both pass.

- [ ] **Step 7: Run the evals**

`ruby plugins/colette/evals/_lib/vendor_dependencies.rb`, then, from a copy of `plugins/colette` outside `/Users`, run the two new cases and `plans-the-next-increment` (it must still plan a spec's next increment): `claude plugin eval <copy> --case <name> --runs 1 --ablation none --scaffold --trust-plugin --allow-tools Write --no-publish --judge-model sonnet`.
Expected: all three 1.00.

- [ ] **Step 8: Commit**

```bash
git add plugins/colette/skills/writing-plans/SKILL.md plugins/colette/.claude-plugin/plugin.json .claude-plugin/marketplace.json README.md
git commit -m "feat(colette): /colette:writing-plans plans from requirements, one increment at a time (0.4.0)"
```

---

## Finishing

After the final review, in `superpowers:finishing-a-development-branch`, take **"push and create a PR"** against `main`, never a local merge.

- **Title:** `feat(colette): /colette:writing-plans plans from requirements`
- **Description**, ending with the Claude Code attribution line:
  - **Increment:** 4 of `docs/superpowers/specs/2026-10-19-colette-brainstorming-design.md`. The spec change that split the old Increment 4 into 4 and 5 is in this PR.
  - **Consumers:** none outside the plugin. No frontend or app must change.
  - **Deploy notes:** released as colette 0.4.0, which also ships #12's follow-ups. Teammates get it on the next marketplace update. Nothing is behind a flag. `superpowers:writing-plans` is not routed yet; that is Increment 5.
  - **Tests:** the Ruby test counts, each eval case's score, and the validator results.
- Once the PR number exists, change Increment 4's status line in the spec to `- [x] PR #<n>`, commit `docs: mark colette increment 4 as PR #<n>` on the same branch, and push.
