# Colette brainstorming — Increment 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the `colette` plugin with `/colette:brainstorming`, which runs superpowers brainstorming but writes the spec as an end goal plus the smallest deployable increments, then plans the first increment only.

**Architecture:** A Markdown-only plugin (`plugins/colette/`) whose one skill wraps `superpowers:brainstorming` and cites the review companion's rules from `engineering-review:engineering-principles`. Both plugins are declared dependencies, so installing `colette` installs them. Ruby/Minitest tests pin the manifests and the skill's rules; `claude plugin eval` cases check its behaviour.

**Tech Stack:** Claude Code plugin (skills, `plugin.json` dependencies), Ruby 3.4 + Minitest, `claude plugin eval`, POSIX `sh` for eval scaffolds.

**Spec:** `docs/superpowers/specs/2026-10-19-colette-brainstorming-design.md` — this plan covers **Increment 1 only**. Increments 2–4 (routing hook, `/colette:writing-plans`, planning route) are out of scope.

## Global Constraints

- Plugin name `colette`, version `0.1.0`, in `plugins/colette/`.
- `plugin.json` `"dependencies": ["superpowers@claude-plugins-official", "engineering-review"]`.
- `.claude-plugin/marketplace.json` top level: `"allowCrossMarketplaceDependenciesOn": ["claude-plugins-official"]`.
- The skill cites EP-I4, EP-I5 and EP-E5 by ID and loads `engineering-review:engineering-principles`; it never restates those rules in other words.
- The skill does not copy or rewrite `superpowers:brainstorming`; it invokes it and adds rules on top.
- No `disable-model-invocation`. The description does **not** claim to replace `superpowers:brainstorming`; that, and the routing hook, are increment 2.
- One `SKILL.md`; description in the third person, opening with what it does, with a "Use when …" clause; English only.
- Status line format, exactly: `- [ ] Not shipped`, later `- [x] PR #<n>`.
- Limits: at most 20 code files per increment (tests and docs not counted), aiming for 10.
- This increment must itself stay within 20 code files. Expected: 2 (`plugin.json`, `marketplace.json`).
- Tests first; commit with green tests only. Scripts are Ruby, except eval scaffolds, which follow the existing `sh` pattern.

## Review Focus

1. `superpowers` or `engineering-review` disabled after install: the skill names the missing plugin and stops, never brainstorms without it. Pinned in Task 2's content test.
2. The person skips the questions on a project-sized request: superpowers then ends its skill, but colette still writes End goal + Increments and plays the increments back before any plan. Pinned in Task 2.
3. A request that fits in one increment: the spec has one increment; colette never invents a split to look incremental. Pinned in Task 2.
4. A quick, clear task or a small change (superpowers' smaller sizes): no spec is forced; the chat description still states it is one increment within the limits. Pinned in Task 2.
5. The handoff: writing-plans gets increment 1 only, the 20-file stop, and the Finishing rules. Pinned in Task 2; the eval cannot reach it in one prompt.

---

### Task 1: The plugin, its dependencies and its marketplace entry

**Files:**
- Create: `plugins/colette/.claude-plugin/plugin.json`
- Create: `plugins/colette/test/plugin_test.rb`
- Modify: `.claude-plugin/marketplace.json` (top-level key; new plugin entry after `engineering-review`)
- Modify: `README.md` (new bullet under "Plugins", after `engineering-review`)

**Interfaces:**
- Produces: `plugins/colette/test/plugin_test.rb`, a Minitest file run with `ruby plugins/colette/test/plugin_test.rb` from the repository root, with constants `ROOT` (repository root) and `PLUGIN` (`ROOT/plugins/colette`), which Task 2 extends.

- [ ] **Step 1: Write the failing tests**

```ruby
require "minitest/autorun"
require "json"

ROOT = File.expand_path("../../..", __dir__)
PLUGIN = File.join(ROOT, "plugins", "colette")

class ManifestTest < Minitest::Test
  def manifest = JSON.parse(File.read(File.join(PLUGIN, ".claude-plugin", "plugin.json")))
  def marketplace = JSON.parse(File.read(File.join(ROOT, ".claude-plugin", "marketplace.json")))
  def entry = marketplace.fetch("plugins").find { |plugin| plugin["name"] == "colette" }

  def test_plugin_declares_superpowers_and_engineering_review_as_dependencies
    assert_equal "colette", manifest["name"]
    assert_equal ["superpowers@claude-plugins-official", "engineering-review"], manifest["dependencies"]
  end

  def test_marketplace_allows_dependencies_on_the_official_marketplace
    assert_includes marketplace.fetch("allowCrossMarketplaceDependenciesOn"), "claude-plugins-official"
  end

  def test_marketplace_lists_colette_at_the_plugin_version
    assert_equal "./plugins/colette", entry["source"]
    assert_equal "0.1.0", manifest["version"]
    assert_equal manifest["version"], entry["version"]
  end

  def test_readme_lists_colette
    assert_match(/^- \*\*colette\*\* — /, File.read(File.join(ROOT, "README.md")))
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `ruby plugins/colette/test/plugin_test.rb`
Expected: 4 errors/failures (no `plugin.json`, no allowlist, no entry, no README bullet).

- [ ] **Step 3: Create `plugin.json`, the marketplace entry and the README bullet**

`plugin.json` follows `plugins/engineering-review/.claude-plugin/plugin.json` (author, homepage, repository, license `MIT`), with the Global Constraints' name, version and dependencies; description: "Colette's way to design and plan: specs that reach their end goal through the smallest increments, each one feature and deployable on its own, planned one increment at a time."; keywords `["brainstorming", "planning", "increments", "superpowers"]`. The marketplace entry copies its name, source, description, version and keywords, with `"author": { "name": "Colette Club" }`. The README bullet says what `/colette:brainstorming` does in two or three lines, and that installing `colette` also installs `superpowers` and `engineering-review`.

- [ ] **Step 4: Run the tests and the validators**

Run: `ruby plugins/colette/test/plugin_test.rb`
Expected: `4 runs, … 0 failures, 0 errors`.
Run: `claude plugin validate ./plugins/colette` then `claude plugin validate .`
Expected: both pass. If a sandbox blocks the command, note it for the PR description and go on.

- [ ] **Step 5: Commit**

```bash
git add plugins/colette/.claude-plugin/plugin.json plugins/colette/test/plugin_test.rb .claude-plugin/marketplace.json README.md
git commit -m "feat(colette): add the colette plugin with superpowers and engineering-review as dependencies"
```

### Task 2: The `brainstorming` skill, its content tests and its eval cases

**Files:**
- Create: `plugins/colette/skills/brainstorming/SKILL.md`
- Modify: `plugins/colette/test/plugin_test.rb` (new class `BrainstormingSkillTest`)
- Create: `plugins/colette/evals/README.md`, `plugins/colette/evals/_lib/make-repo.sh`
- Create: `plugins/colette/evals/_fixtures/wishes-app/` (copy of `plugins/engineering-review/evals/_fixtures/rename-api-field/base/`, plus a `mix.exs` for app `:app` depending on `phoenix`, `ecto_sql`, `absinthe` and `oban`)
- Create: `plugins/colette/evals/spec-has-increments/{case.yaml,prompt.md,scaffold.sh,graders/*.md}`
- Create: `plugins/colette/evals/increments-stay-small/{case.yaml,prompt.md,scaffold.sh,graders/*.md}`

**Interfaces:**
- Consumes: `ROOT`, `PLUGIN` from Task 1's test file.
- Produces: the skill `colette:brainstorming`; the spec format below, which increment 3's `colette:writing-plans` will parse (`## End goal`, `## Increments`, `### Increment <n> — <title>`, `**Code files:** <n>`, the status line).

- [ ] **Step 1: Write the failing content tests**

Add to `plugin_test.rb`:

```ruby
class BrainstormingSkillTest < Minitest::Test
  def skill = File.read(File.join(PLUGIN, "skills", "brainstorming", "SKILL.md"))
  def frontmatter = skill[/\A---\n(.*?)\n---\n/m, 1]

  def test_frontmatter_names_the_skill_and_says_when_to_use_it
    assert_match(/^name: brainstorming$/, frontmatter)
    assert_match(/Use when/, frontmatter)
    refute_match(/disable-model-invocation/, frontmatter)
  end

  def test_it_runs_superpowers_with_the_review_rules
    %w[superpowers:brainstorming engineering-review:engineering-principles EP-I4 EP-I5 EP-E5].each do |text|
      assert_includes skill, text
    end
  end

  def test_it_fixes_the_spec_format
    ["## End goal", "## Increments", "### Increment <n> — ", "**Code files:** <n>", "- [ ] Not shipped", "- [x] PR #<n>"].each do |text|
      assert_includes skill, text
    end
  end

  def test_it_holds_every_increment_to_the_limits
    ["20 code files", "10 code files", "could this ship as two smaller ones"].each { |text| assert_includes skill, text }
  end

  def test_it_hands_off_the_first_increment_only_ending_with_a_pr
    ["superpowers:writing-plans", "Increment 1", "push and create a PR", "never a local merge"].each do |text|
      assert_includes skill, text
    end
  end

  def test_review_focus_cases_are_covered
    ["stop", "skips the questions", "one increment", "never invent"].each { |text| assert_includes skill, text }
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `ruby plugins/colette/test/plugin_test.rb`
Expected: the 4 manifest tests pass; the 6 `BrainstormingSkillTest` tests error (no `SKILL.md`).

- [ ] **Step 3: Write the eval cases**

`_lib/make-repo.sh` builds a git repo on `main` from a fixture (`git init -q -b main .`, set `user.email`/`user.name`, `cp -R "$1/." .`, `git add -A`, `git commit -q -m base`). Each `scaffold.sh` is the three-line pattern from `plugins/engineering-review/evals/README.md`, pointing at `_fixtures/wishes-app`. Each `case.yaml` is `schema_version: "1.1"`, its name, `context.scaffold_script: scaffold.sh`.

Both prompts' frontmatter: `tags: [spec]`, `max_turns: 60`, `timeout_seconds: 1500`, `allowed_tools: [Read, Glob, Grep, Skill, Bash, Write]` (no `Agent`: the builder check is done inline), `plugins: ["../..", "../../../engineering-review", "superpowers@claude-plugins-official"]`.

- **`spec-has-increments`** — prompt: `/colette:brainstorming` with "Members can archive a wish they no longer want", then everything a brainstorm would ask, answered (who: members in the mobile app and the web front through the GraphQL API; why: their list fills with abandoned wishes; what: an Archive action, archived wishes leave the list and can be seen and restored from an Archived tab; non-goals: deleting wishes, archiving for staff; built in this Elixir/Phoenix app), then: "I approve the design as described above. Write the written design to docs/superpowers/specs/2026-10-19-archive-wishes-design.md now, and do not plan or build anything yet."
  Graders (file targets on that path): `file_exists`; regex `^## End goal` (`flags: m`); regex `^## Increments` (`m`); regex `^- \[ \] Not shipped` (`m`); regex `\*\*Consumers:\*\*`; regex `\*\*Code files:\*\* *\d+`; `tool_used` `Skill` `input_match: 'superpowers:brainstorming'`; `tool_used` `Skill` `input_match: 'engineering-principles'`; `file_exists` `docs/superpowers/plans/**` `exists: false`.
- **`increments-stay-small`** — prompt: the same shape for "Wish reminders": weekly email, push and in-app reminders of open wishes; per-member settings for channel and day; an admin view of reminder volume; GraphQL fields for the mobile app and web front; a scheduled job. The path is `docs/superpowers/specs/2026-10-19-wish-reminders-design.md`.
  Graders: `file_exists`; regex `Not shipped[\s\S]*Not shipped[\s\S]*Not shipped` (three increments or more); regex `match: not_contains` `\*\*Code files:\*\* *(2[1-9]|[3-9]\d|\d{3,})` (none above 20).

`evals/README.md`: purpose, the run command from Step 7, the two cases, max 50 lines.

- [ ] **Step 4: Commit the tests**

```bash
git add plugins/colette/test/plugin_test.rb plugins/colette/evals
git commit -m "test(colette): add the brainstorming content tests and eval cases"
```

- [ ] **Step 5: Write `plugins/colette/skills/brainstorming/SKILL.md`**

Frontmatter: `name: brainstorming`; description, for example: "Runs superpowers brainstorming so the spec reaches its end goal through the smallest increments, each one feature and deployable on its own, then plans the first increment only. Use when designing a feature, change or project with colette." Sections, in order:

1. **Before you start.** Check that `superpowers:brainstorming` and `engineering-review:engineering-principles` are available; if either is not, name the plugin to enable or install and stop. Load `engineering-review:engineering-principles` (EP-I4, EP-I5, EP-E5 apply from it).
2. **Run `superpowers:brainstorming`** with the person's request, and follow it as written. The rules below add to it; where they differ (the spec's shape, the handoff), they win.
3. **What an increment is.** Cite EP-I4, EP-I5, EP-E5. Add only what the rules do not say: the thinnest usable slice before any layer-by-layer cut; an increment relies on earlier ones, never a later one; increments are the path to the end goal, not a split of a finished design. A request that fits in one increment gets one increment — never invent a split.
4. **Drafting the increments.** Read the codebase to estimate each increment's code files, and say so. Challenge each increment once: "could this ship as two smaller ones that each deploy alone?" Above 10 code files, say why it cannot be smaller; above 20 code files, split it, always. The playback covers the increments.
5. **The spec's two sections.** This template, exactly:

   ```markdown
   ## End goal

   <What exists when every increment has shipped, and why.>

   ## Increments

   ### Increment <n> — <the one thing it delivers>

   - **Delivers:** <what someone can do once it is deployed>
   - **Deployable alone:** <what stays hidden or behind a flag; how contracts other apps use stay compatible; what runs while the previous version is still deployed>
   - **Consumers:** <the frontends and apps that must change, or "none"; what deploys first>
   - **Code files:** <n> — <expected paths>
   - [ ] Not shipped
   ```

   The status line becomes `- [x] PR #<n>` once that increment's PR is open.
6. **Sizes.** Superpowers' quick tasks and small changes get no spec; the chat description says the change is one increment within the limits. When the person skips the questions on a project-sized request, still write End goal and Increments and play the increments back before any plan.
7. **The handoff.** Where superpowers says to invoke `superpowers:writing-plans`, invoke it with args naming the spec and saying: plan ONLY Increment 1; stop and split the increment in the spec if its file structure exceeds 20 code files; end with a Finishing section — after the final review, take "push and create a PR" in `finishing-a-development-branch`, never a local merge; the PR description names the increment, the frontends and apps that depend on it and whether each must change, the deploy order, and what stays behind a flag; once the PR exists, commit the spec's `- [x] PR #<n>` for Increment 1 on the same branch and push. Later increments are planned after the previous one ships.

- [ ] **Step 6: Run the content tests**

Run: `ruby plugins/colette/test/plugin_test.rb`
Expected: `10 runs, … 0 failures, 0 errors`.

- [ ] **Step 7: Run the eval cases**

Run, from the repository root, with a real git first on `PATH` on macOS (`export PATH="/Library/Developer/CommandLineTools/usr/bin:$PATH"`):
`claude plugin eval plugins/colette --runs 1 --ablation none --scaffold --trust-plugin --allow-tools "Bash(git *)" Write --no-publish --judge-model sonnet`
Expected: both cases score 1.00.
- If the harness rejects `superpowers@claude-plugins-official` in `plugins:`, stop and report it: how the eval loads superpowers is the human's decision.
- If the sandbox blocks the run (`/Users … EPERM`), record "not measured" with the reason for the PR description and go on.

- [ ] **Step 8: Commit**

```bash
git add plugins/colette/skills/brainstorming/SKILL.md
git commit -m "feat(colette): add /colette:brainstorming — specs reach their end goal through the smallest deployable increments"
```

---

## Finishing

After the final review, in `superpowers:finishing-a-development-branch`, take **"push and create a PR"** against `main`, never a local merge.

- **Title:** `feat(colette): /colette:brainstorming — specs reach their end goal through the smallest deployable increments`
- **Description**, ending with the Claude Code attribution line:
  - **Increment:** 1 of `docs/superpowers/specs/2026-10-19-colette-brainstorming-design.md`: the `colette` plugin and `/colette:brainstorming`.
  - **Consumers:** none. This is a new plugin and nothing else changes; no frontend or app must change.
  - **Deploy notes:** installing `colette` also installs and enables `superpowers` (from `claude-plugins-official`, allowed by `allowCrossMarketplaceDependenciesOn`) and `engineering-review`. Nothing is behind a flag. Teammates get it on the next marketplace update.
  - **Tests:** the Ruby test count; each eval case's score, or "not measured" with the reason; the `claude plugin validate` results.
- Once the PR number exists, change Increment 1's status line in the spec to `- [x] PR #<n>`, commit `docs: mark colette increment 1 as PR #<n>` on the same branch, and push.
