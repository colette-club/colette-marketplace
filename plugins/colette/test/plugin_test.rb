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

  def test_it_stops_when_a_dependency_is_missing_or_too_old
    ["say it must be installed and enabled, and stop", "update `engineering-review` to 0.5.0 or later, and stop"].each do |text|
      assert_includes skill, text
    end
  end

  def test_small_changes_get_no_spec
    assert_includes skill, "A quick, clear task or a small change gets no spec"
  end

  def test_skipped_questions_still_get_increments_approved_then_the_handoff
    ["still write the End goal and Increments sections", "get the person's approval of the increments, then follow \"The handoff\""].each do |text|
      assert_includes skill, text
    end
  end

  def test_a_request_that_fits_in_one_increment_is_not_split
    assert_includes skill, "never invent a split"
  end

  def test_the_handoff_plans_only_the_first_increment
    assert_includes skill, "Plan ONLY its Increment 1"
  end

  def test_its_rules_win_wherever_they_differ_and_reading_needs_no_permission
    ["Where they differ from it, they win", "Reading the codebase needs no permission"].each { |text| assert_includes skill, text }
  end
end
