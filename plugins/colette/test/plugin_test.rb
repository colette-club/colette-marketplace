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
    assert_equal "0.5.0", manifest["version"]
    assert_equal manifest["version"], entry["version"]
  end

  def test_readme_lists_colette
    readme = File.read(File.join(ROOT, "README.md"))
    assert_match(/^- \*\*colette\*\* — /, readme)
    assert_includes readme, "It needs superpowers 7.0 or later"
    assert_includes readme, "plans from requirements too"
    assert_includes readme, "Claude's own planning goes through it too"
  end
end

class HooksTest < Minitest::Test
  def test_a_skill_call_runs_the_routing_hook_in_exec_form
    entry = JSON.parse(File.read(File.join(PLUGIN, "hooks", "hooks.json"))).dig("hooks", "PreToolUse", 0)
    assert_equal "Skill", entry["matcher"]
    hook = entry.dig("hooks", 0)
    assert_equal ["command", "${CLAUDE_PLUGIN_ROOT}/hooks/route-skills.sh", [], 10], hook.values_at("type", "command", "args", "timeout")
    assert File.executable?(File.join(PLUGIN, "hooks", "route-skills.sh"))
    assert_includes File.read(File.join(PLUGIN, "hooks", "hooks.json")), "superpowers:writing-plans"
  end
end

class EvalCasesTest < Minitest::Test
  def prompts = Dir.glob(File.join(PLUGIN, "evals", "*", "prompt.md"))

  def test_each_case_loads_its_own_copies_of_the_dependencies
    refute_empty prompts
    prompts.each do |prompt|
      assert_includes File.read(prompt), 'plugins: ["../..", "deps/engineering-review", "deps/superpowers"]', prompt
    end
  end

  def test_overlay_fixtures_hold_only_what_differs_from_the_base_app
    base = File.join(PLUGIN, "evals", "_fixtures", "wishes-app")
    %w[wishes-app-increment-1 wishes-app-spec-without-increments].each do |name|
      overlay = File.join(PLUGIN, "evals", "_fixtures", name)
      Dir.glob("**/*", base: overlay).each do |path|
        twin = File.join(base, path)
        next unless File.file?(twin)
        refute_equal File.read(twin), File.read(File.join(overlay, path)), "#{name}/#{path} repeats the base app"
      end
      assert_includes File.read(File.join(PLUGIN, "evals", scaffold_case(name), "scaffold.sh")), "_fixtures/wishes-app\" \"$here/../_fixtures/#{name}\""
    end
  end

  def scaffold_case(fixture) = { "wishes-app-increment-1" => "plans-the-next-increment", "wishes-app-spec-without-increments" => "spec-without-increments" }.fetch(fixture)

  def test_the_copies_are_not_committed
    assert_includes File.read(File.join(ROOT, ".gitignore")), "plugins/colette/evals/*/deps/"
  end
end

class BrainstormingSkillTest < Minitest::Test
  def skill = File.read(File.join(PLUGIN, "skills", "brainstorming", "SKILL.md"))
  def frontmatter = skill[/\A---\n(.*?)\n---\n/m, 1]

  def test_frontmatter_names_the_skill_and_says_when_to_use_it
    assert_match(/^name: brainstorming$/, frontmatter)
    assert_match(/Use when/, frontmatter)
    refute_match(/disable-model-invocation/, frontmatter)
  end

  def test_a_plain_superpowers_session_is_handed_back_to_superpowers_brainstorming
    assert_match(/instead of superpowers:brainstorming, wherever colette is installed, except after a typed \/superpowers:brainstorming/, frontmatter)
    section = skill[/^## A plain superpowers session\n.*?(?=^## )/m].to_s
    ["When this session's latest typed brainstorming command is `/superpowers:brainstorming`", "Do not apply the rules below",
     "invoke `superpowers:brainstorming` with args that start with `[colette]`, followed by the request unchanged", "add nothing else"].each { |text| assert_includes section, text }
    assert_operator skill.index("## A plain superpowers session"), :<, skill.index("## Before you start")
  end

  def test_it_marks_its_own_call_to_superpowers
    assert_includes skill, "with args that start with `[colette]`"
  end

  def test_its_description_takes_over_from_superpowers_brainstorming
    assert_includes frontmatter, "instead of superpowers:brainstorming"
  end

  def test_it_runs_superpowers_with_the_review_rules
    %w[superpowers:brainstorming engineering-review:engineering-principles EP-I4 EP-I5 EP-E5].each do |text|
      assert_includes skill, text
    end
  end

  def test_it_fixes_the_spec_format
    ["## End goal", "## Increments", "### Increment <i> — ", "**Code files:** <count>", "- [ ] Not shipped", "- [x] PR #<n>"].each do |text|
      assert_includes skill, text
    end
  end

  def test_it_challenges_every_increment_to_be_smaller
    ["20 code files", "10 code files", "could this ship as two smaller ones that can each be deployed and used on their own?"].each { |text| assert_includes skill, text }
  end

  def test_the_file_count_is_a_preference_not_a_limit
    ["a preference, not a limit", "says why it cannot be smaller"].each { |text| assert_includes skill, text }
    ["is split, always", "at most 20 code files"].each { |text| refute_includes skill, text }
  end

  def test_the_handoff_names_colette_writing_plans_as_the_planning_step
    assert_includes skill, "it is the planning step superpowers asks for: it runs `superpowers:writing-plans` itself"
  end

  def test_the_handoff_goes_to_colette_writing_plans_for_increment_1
    ["invoke `colette:writing-plans` with the spec's path", "Increment 1"].each { |text| assert_includes skill, text }
    ["Plan ONLY its Increment 1", "push and create a PR"].each { |text| refute_includes skill, text }
  end

  def test_it_stops_when_a_dependency_is_missing_or_too_old
    ["say it must be installed and enabled, and stop", "update `engineering-review` to 0.5.0 or later, and stop"].each do |text|
      assert_includes skill, text
    end
  end

  def test_small_changes_get_no_spec
    assert_includes skill, "A quick, clear task or a small change gets no spec"
    assert_includes skill, "When it is not one increment, it is project-sized: write the spec"
    refute_includes skill, "or propose increments when it is not"
  end

  def test_skipped_questions_still_get_increments_approved_then_the_handoff
    ["still write the End goal and Increments sections", "get the person's approval of the increments, then follow \"The handoff\""].each do |text|
      assert_includes skill, text
    end
  end

  def test_a_request_that_fits_in_one_increment_is_not_split
    assert_includes skill, "never invent a split"
  end

  def test_its_rules_win_wherever_they_differ_and_reading_needs_no_permission
    ["Where they differ from it, they win", "Reading the codebase needs no permission"].each { |text| assert_includes skill, text }
  end
end

class WritingPlansSkillTest < Minitest::Test
  def skill = File.read(File.join(PLUGIN, "skills", "writing-plans", "SKILL.md"))
  def frontmatter = skill[/\A---\n(.*?)\n---\n/m, 1]

  def test_frontmatter_names_the_skill_and_says_when_to_use_it
    assert_match(/^name: writing-plans$/, frontmatter)
    assert_match(/Use when/, frontmatter)
    refute_match(/disable-model-invocation/, frontmatter)
    assert_match(/instead of superpowers:writing-plans, wherever colette is installed, except after a typed \/superpowers:brainstorming/, frontmatter)
    assert_match(/from requirements/, frontmatter)
  end

  def test_it_stops_when_a_dependency_is_missing_or_too_old
    ["superpowers:writing-plans", "engineering-review:engineering-principles", "EP-I4", "EP-I5", "EP-E5",
     "say it must be installed and enabled, and stop", "update `engineering-review` to 0.5.0 or later, and stop"].each { |text| assert_includes skill, text }
  end

  def test_it_finds_the_next_unshipped_increment_or_stops
    ["- [ ] Not shipped", "When the request gives neither requirements nor a spec that qualifies, say so and stop", "say that every increment has shipped, and stop"].each { |text| assert_includes skill, text }
  end

  def test_it_asks_before_planning_on_an_unmerged_previous_increment
    ["Increment 1 has no previous increment", "`gh pr view <n> --json state,title,headRefName`", "name the PR you checked", "When it is not merged, or you cannot tell, say so and ask whether to plan anyway"].each { |text| assert_includes skill, text }
  end

  def test_a_spec_without_increments_gets_them_approved_first
    ["is never planned as is", "../brainstorming/SKILL.md", "Play them back. Once the person approves them, write them into the spec and plan Increment 1."].each { |text| assert_includes skill, text }
  end

  def test_it_rechecks_the_increment_against_the_code
    assert_includes skill, "propose the change to the spec's Increments section, get it approved and write it, then plan"
    assert_includes skill, "still meets EP-I4, EP-I5 and EP-E5"
    refute_includes skill, "still one feature, still deployable on its own"
  end

  def test_it_plans_only_that_increment_and_ends_with_its_pr
    ["with args that start with `[colette]`", "Plan ONLY its Increment <i>", "covers Increment <i> only", "The plan's header names the spec and Increment <i>", "`- [x] PR #<n>` for Increment <i>",
     "if it could be smaller, stop and split it in the spec", "push and create a PR", "never a local merge", "- [x] PR #<n>"].each do |text|
      assert_includes skill, text
    end
    refute_includes skill, "exceeds 20 code files"
  end

  def test_it_says_which_spec_and_increment_it_chose
    ["Say which spec and which increment you chose, and why", "behind its upstream",
     "When a newer spec has no Increments section, name it and ask which spec to plan"].each { |text| assert_includes skill, text }
  end

  def test_the_brainstorming_sections_it_reads_exist
    brainstorming = File.read(File.join(PLUGIN, "skills", "brainstorming", "SKILL.md"))
    ["What an increment is", "Drafting the increments", "The spec"].each do |section|
      assert_includes skill, "\"#{section}\""
      assert_match(/^## #{Regexp.escape(section)}$/, brainstorming)
    end
  end

  def requirements_section = skill[/^## Requirements with no spec\n.*?(?=^## )/m]

  def test_a_spec_path_wins_then_requirements_then_a_lookup
    ["A spec path given in the request is what to plan",
     "not just a spec's name or topic, and not \"plan the next increment\"",
     "When requirements win over an older spec that still has unshipped increments, say so"].each { |text| assert_includes skill, text }
    refute_includes skill, "When the request gives requirements, they are what to plan; a spec is looked up only when it gives none"
  end

  def test_it_plans_from_requirements_like_superpowers
    section = requirements_section
    refute_nil section
    ["decide with EP-I4, EP-I5 and EP-E5", "plan it directly, with no spec file", "with args that start with `[colette]`",
     "Requirements: <the requirements, as given>. Plan them as one increment",
     "if it could be smaller, stop: the requirements need increments first",
     "push and create a PR", "never a local merge", "the PR description names the change",
     "as for a spec without increments", "play them back",
     "Once the person approves them, save them as a short spec at `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, with a Why from the requirements, then the two sections",
     "plan its Increment 1"].each { |text| assert_includes section, text }
  end

  def test_its_intro_covers_requirements_too
    assert_includes skill[/\A---\n.*?\n---\n.*?(?=^## )/m], "or requirements given with no spec"
  end

  def test_it_says_when_it_judged_the_work_one_increment
    assert_includes requirements_section.to_s, "Say in the chat that the work is one increment, and why"
  end

  def test_a_short_spec_never_overwrites_one_from_the_same_day
    assert_includes requirements_section.to_s, "When that file exists, add `-2`, `-3`, … before `.md`"
  end

  def test_a_stop_for_increments_goes_on_to_draft_them
    assert_includes requirements_section.to_s, "When the planner stops because the requirements need increments, go on as for **More than one increment**"
  end

  def test_it_offers_the_most_recent_spec_when_it_has_no_increments
    assert_includes skill, "When no spec has an unshipped increment but the most recent spec has no Increments section, name it and ask whether to plan it"
  end

  def test_a_plain_superpowers_session_is_handed_back_to_superpowers
    section = skill[/^## A plain superpowers session\n.*?(?=^## )/m].to_s
    ["When this session's latest typed brainstorming command is `/superpowers:brainstorming`",
     "Claude picked this skill on its own: not when the person typed `/colette:writing-plans`",
     "Do not apply the rules below", "invoke `superpowers:writing-plans` with args that start with `[colette]`, followed by the request unchanged",
     "add nothing else", "A later typed `/colette:brainstorming` brings colette's rules back"].each { |text| assert_includes section, text }
    assert_operator skill.index("## A plain superpowers session"), :<, skill.index("## Before you start")
  end
end
