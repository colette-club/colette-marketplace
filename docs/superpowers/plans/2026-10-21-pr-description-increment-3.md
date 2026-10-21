# PR description standard — Increment 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Plans written by `colette:writing-plans` end with a PR whose title and description already meet EP-F5: a spec increment's title gives its place, `(<i>/<n>)`, and frontend changes get marked spots for their pictures.

**Architecture:** Only colette's `writing-plans` skill changes. Its two Finishing texts, passed to `superpowers:writing-plans`, are the one place where a PR's content is decided: one for requirements, one for a spec's increment. They now point to EP-F5 and `engineering-review:pr-description` instead of listing the content themselves, and keep what they already require. "Before you start" refuses an `engineering-review` older than 0.7.0, the first release with EP-F5. Brainstorming does not change.

**Tech Stack:** Markdown skills; Ruby Minitest (`plugins/colette/test/plugin_test.rb`); `claude plugin eval` cases.

**Spec:** `docs/superpowers/specs/2026-10-21-pr-description-design.md`, Increment 3 only (Increments 1 and 2 shipped as PR #15 and PR #17).

## Global Constraints

- Work on branch `feat/pr-description-increment-3`, cut from `main` after PR #17 merged. No worktree.
- Before every commit, from the repository root, all four must report 0 failures:
  - `ruby plugins/colette/test/plugin_test.rb`
  - `ruby plugins/colette/test/route_skills_test.rb`
  - `ruby plugins/colette/test/make_repo_test.rb`
  - `ruby plugins/colette/test/vendor_dependencies_test.rb`
- Exact strings, used verbatim:
  - the titles `<feature> (<i>/<n>): <title>` (a spec's increment) and `<feature>: <title>` (requirements);
  - the phrase `follow EP-F5 and `engineering-review:pr-description`, loaded when they are written`;
  - the version floor `0.7.0`.
- Brainstorming's own check stays at 0.5.0: it does not use EP-F5.
- Plain English in the house style of the existing colette skills.
- Evals: run `ruby plugins/colette/evals/_lib/vendor_dependencies.rb` first. If `claude plugin eval` is refused (`/Users could not be examined (EPERM)`), record the case as not measured.
- Commits are semantic and end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

- **An `engineering-review` older than 0.7.0** (no EP-F5): writing-plans stops and names the version to update to. Pinned by the updated `test_it_stops_when_a_dependency_is_missing_or_too_old` (Task 1).
- **The feature name comes from the spec's title** (`# Archive wishes — design` → `Archive wishes`). Pinned by `plans-the-next-increment/graders/titles-the-pr-with-its-place.md` (Task 1).
- **A requirements PR is not part of a sequence,** so its title gets no `(<i>/<n>)`. Pinned by `plans-small-requirements/graders/no-sequence-place.md` (Task 1).
- **A frontend change** gets marked spots and a final message saying what to capture. There is no frontend fixture in colette's evals, so this is pinned by the content test in Task 1.
- **Both Finishing texts change together:** a fix to one and not the other would give requirements PRs and increment PRs different standards. Pinned by the count assertion in Task 1's test.

---

### Task 1: The Finishing texts follow EP-F5

**Files:**
- Modify: `plugins/colette/skills/writing-plans/SKILL.md`:
  - "Before you start", item 2 (line 18);
  - "Requirements with no spec", the **One increment** quote (lines 35–37);
  - "Run superpowers writing-plans", the fill-in line and the quote (lines 49–51).
- Modify: `plugins/colette/evals/README.md` (the `plans-the-next-increment` and `plans-small-requirements` rows)
- Create:
  - `plugins/colette/evals/plans-the-next-increment/graders/titles-the-pr-with-its-place.md`
  - `plugins/colette/evals/plans-the-next-increment/graders/description-follows-ep-f5.md`
  - `plugins/colette/evals/plans-small-requirements/graders/description-follows-ep-f5.md`
  - `plugins/colette/evals/plans-small-requirements/graders/no-sequence-place.md`
- Test: `plugins/colette/test/plugin_test.rb` (`WritingPlansSkillTest`)

**Interfaces:**
- Consumes: EP-F5 and the `pr-description` skill (`engineering-review` 0.7.0 or later): the template, the title formats, the marked-spot form.
- Produces: the Finishing text that every colette plan now carries; Increment 4 adds picture capture to it.

- [ ] **Step 1: Write the failing tests**

In `WritingPlansSkillTest`:
- In `test_it_stops_when_a_dependency_is_missing_or_too_old`, add `"EP-F5"`, and change `"update \`engineering-review\` to 0.5.0 or later, and stop"` to `0.7.0`.
- In `test_it_plans_from_requirements_like_superpowers`, change `"the PR description names the change"` to `"the description names the change"`.
- Add:

```ruby
def test_its_prs_follow_the_pr_description_standard
  ["the PR title is `<feature> (<i>/<n>): <title>`", "the PR title is `<feature>: <title>`",
   "its number of increments `<n>`", "its `# ` title without ` — design`",
   "a marked spot for each picture and video, and the final message tells the person what to capture and where each goes"].each do |text|
    assert_includes skill, text
  end
  assert_equal 2, skill.scan("follow EP-F5 and `engineering-review:pr-description`, loaded when they are written").size
end
```

- [ ] **Step 2: Run them to verify they fail**

Run: `ruby plugins/colette/test/plugin_test.rb -n /dependency_is_missing|from_requirements_like|description_standard/`
Expected: 3 failures — the writing-plans dependency check, the requirements text, the new test. Brainstorming's dependency test still passes.

- [ ] **Step 3: Edit the skill**

- **Before you start, item 2:** `Load `engineering-review:engineering-principles`. The rules EP-I4, EP-I5, EP-E5 and EP-F5 come from it. When it does not define all four, it is older than 0.7.0: say to update `engineering-review` to 0.7.0 or later, and stop.`
- **Requirements, One increment:**
  - the fill-in line becomes "with the requirements, a short title `<title>` and the feature `<feature>` it belongs to filled in";
  - in the quote, replace "the PR description names the change, the frontends and apps that depend on it and whether each must change, the deploy order, and what stays behind a flag." with: `the PR title is `<feature>: <title>`, and the title and description follow EP-F5 and `engineering-review:pr-description`, loaded when they are written: the description names the change, the frontends and apps that depend on it and whether each must change, the deploy order, and what stays behind a flag; for a frontend change, it holds a marked spot for each picture and video, and the final message tells the person what to capture and where each goes.`
- **Run superpowers writing-plans:**
  - the fill-in line becomes "with the spec's path, the increment's number `<i>` and its title, the spec's feature `<feature>` (its `# ` title without ` — design`) and its number of increments `<n>` filled in";
  - in the quote, replace "the PR description names the increment, the frontends and apps … and what stays behind a flag;" with: `the PR title is `<feature> (<i>/<n>): <title>`, and the title and description follow EP-F5 and `engineering-review:pr-description`, loaded when they are written: the description names the increment, the frontends and apps that depend on it and whether each must change, the deploy order, and what stays behind a flag; for a frontend change, it holds a marked spot for each picture and video, and the final message tells the person what to capture and where each goes;`
  - keep the rest of the quote unchanged ("once the PR exists, commit the spec's status line …").

- [ ] **Step 4: Run the tests**

Run: `ruby plugins/colette/test/plugin_test.rb`
Expected: 0 failures, 0 errors.

- [ ] **Step 5: Add the graders**

All of these are `type: regex`, with `target: { source: file, path: '<the case's plan file>' }`. The plan file is `docs/superpowers/plans/2026-10-19-archive-wishes-next-increment.md` for `plans-the-next-increment` and `docs/superpowers/plans/2026-10-19-rename-wish.md` for `plans-small-requirements`, as in each case's `ends-with-the-pr.md`.
- `plans-the-next-increment/graders/titles-the-pr-with-its-place.md`: `pattern: 'Archive wishes \(2/3\)'`
- `plans-the-next-increment/graders/description-follows-ep-f5.md`: `pattern: 'EP-F5'`
- `plans-small-requirements/graders/description-follows-ep-f5.md`: `pattern: 'EP-F5'`
- `plans-small-requirements/graders/no-sequence-place.md`: `pattern: '\(\d+/\d+\):'`, `match: not_contains`

In `evals/README.md`, extend two rows:
- `plans-the-next-increment`: "…, ending with its PR, titled `Archive wishes (2/3): …` and described to EP-F5".
- `plans-small-requirements`: "…; its PR is described to EP-F5, with no place in a sequence".

- [ ] **Step 6: Run the colette suites and the two evals once**

Run: the four `ruby plugins/colette/test/*_test.rb` files → 0 failures.
Run: `ruby plugins/colette/evals/_lib/vendor_dependencies.rb`, then for each of `plans-the-next-increment` and `plans-small-requirements`:
`claude plugin eval plugins/colette --case '<case>' --runs 1 --ablation none --scaffold --trust-plugin --allow-tools Write --no-publish --judge-model sonnet`
Expected: 1.00 each, or not measured when refused.

- [ ] **Step 7: Commit**

```bash
git add plugins/colette
git commit -m "feat(colette): plans end with a PR titled and described to EP-F5"
```

---

### Task 2: Release colette 0.6.0

**Files:**
- Modify: `plugins/colette/.claude-plugin/plugin.json` (`version`), `.claude-plugin/marketplace.json` (colette's `version`)
- Modify: `README.md` (the colette entry)
- Test: `plugins/colette/test/plugin_test.rb:23`

- [ ] **Step 1: Write the failing test**

In `test_marketplace_lists_colette_at_the_plugin_version`, change `"0.5.0"` to `"0.6.0"`, and add to `test_readme_lists_colette`: `assert_includes readme, "Its plans end with a PR titled and described to EP-F5"`.

- [ ] **Step 2: Run it to verify it fails**

Run: `ruby plugins/colette/test/plugin_test.rb -n /lists_colette/`
Expected: 2 failures.

- [ ] **Step 3: Release.**
  - Set `"version": "0.6.0"` in both manifests.
  - In `README.md`'s colette entry, before "Installing it also installs", add: `Its plans end with a PR titled and described to EP-F5: a spec increment's title gives its place, and frontend changes get marked spots for their pictures.`
  - The README notes that colette needs `engineering-review` 0.7.0 or later: add ` and engineering-review 0.7.0 or later` after "It needs superpowers 7.0 or later".

- [ ] **Step 4: Run every check**

Run: the four colette test files → 0 failures; `python3 -m unittest discover -s plugins/engineering-review/scripts -p 'test_*.py'` → OK; `python3 plugins/engineering-review/scripts/check_plugin.py plugin plugins/engineering-review` → `OK`.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json plugins/colette/.claude-plugin/plugin.json plugins/colette/test/plugin_test.rb README.md
git commit -m "chore: release colette 0.6.0"
```

---

## Finishing

After the final review, take "push and create a PR" in `superpowers:finishing-a-development-branch`, never a local merge.

1. `git push -u origin feat/pr-description-increment-3`
2. Write the PR body to a file outside the repository, following EP-F5:
   - **What it does:** colette's plans now end with a PR titled and described to EP-F5; spec link.
   - **How it works:** a `flowchart LR` from `colette:writing-plans`: the Finishing text (requirements, or a spec's increment) → `superpowers:writing-plans` → the plan's Finishing section → `pr-description` loaded when the PR is written.
   - **Behind the scenes:**
     - no side effects;
     - consumers: plans written after the update; plans already written keep their old Finishing text;
     - colette now needs `engineering-review` 0.7.0 or later;
     - evals: measured or not.
   - No screenshots: not a frontend change.

   Then create the PR: `gh pr create --base main --title "PR description standard (3/4): colette's plans end with a PR described to EP-F5" --body-file <that file>`.
3. Once the PR exists, change Increment 3's status line in the spec from `- [ ] Not shipped` to `- [x] PR #<n>`, then:

```bash
git add docs/superpowers/specs/2026-10-21-pr-description-design.md
git commit -m "docs: mark PR description increment 3 as PR #<n>"
git push
```
