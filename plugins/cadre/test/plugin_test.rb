require "minitest/autorun"
require "json"

ROOT = File.expand_path("../../..", __dir__)
PLUGIN = File.join(ROOT, "plugins", "cadre")
INSTALL = 'gh release download -R djeusette/cadre_cli --pattern "cadre_$(uname -s)_$(uname -m).tar.gz" -O - | tar -xz -C ~/.local/bin cadre'

class ManifestTest < Minitest::Test
  def manifest = JSON.parse(File.read(File.join(PLUGIN, ".claude-plugin", "plugin.json")))
  def marketplace = JSON.parse(File.read(File.join(ROOT, ".claude-plugin", "marketplace.json")))
  def entry = marketplace.fetch("plugins").find { |plugin| plugin["name"] == "cadre" }

  def test_plugin_depends_on_colette
    assert_equal "cadre", manifest["name"]
    assert_equal ["colette"], manifest["dependencies"]
  end

  def test_marketplace_lists_cadre_last_at_the_plugin_version
    assert_equal "cadre", marketplace.fetch("plugins").last["name"]
    assert_equal "./plugins/cadre", entry["source"]
    assert_equal "0.1.0", manifest["version"]
    assert_equal manifest["version"], entry["version"]
  end

  def test_descriptions_match
    refute_empty manifest["description"]
    assert_equal manifest["description"], entry["description"]
  end

  def test_readme_lists_cadre
    assert_match(/^- \*\*cadre\*\* — /, File.read(File.join(ROOT, "README.md")))
  end
end

class SkillTest < Minitest::Test
  def skill = File.read(File.join(PLUGIN, "skills", "cadre", "SKILL.md"))
  def frontmatter = skill[/\A---\n(.*?)\n---\n/m, 1]
  def description = frontmatter[/^description: (.*)$/, 1]

  def test_frontmatter_has_only_name_and_description
    assert_match(/^name: cadre$/, frontmatter)
    assert_equal %w[description name], frontmatter.lines.map { |line| line[/\A(\w+):/, 1] }.compact.sort
    assert_operator description.length, :<=, 1024
    assert_match(/Use when/, description)
  end

  def test_it_installs_the_cli_from_the_release_at_the_minimum_version
    assert_includes skill, INSTALL
    assert_includes skill, "0.1.0"
  end

  def test_it_turns_the_spec_into_bare_repo_names
    ["bare", "not `colette-club/colette-api`", "gh repo view --json name -q .name", "A file path is never a repo", "ask when unsure"].each { |text| assert_includes skill, text }
  end

  def test_it_handles_a_shadowed_cli_and_a_key_that_stops_working
    ["command -v cadre", "exit code is 0 and the JSON holds an `email`", "go back to Sign in", "the repo that must deploy first listed first"].each { |text| assert_includes skill, text }
  end

def test_it_runs_the_login_in_the_background_and_relays_the_code
  ["run_in_background", "600000 ms", "Opening <uri> in your browser.", "Check that the page shows this code: <code>"].each { |text| assert_includes skill, text }
end

def test_it_reports_the_json_url_and_explains_zero_based_paths
  ["`url` field", "0-based positions", "milestones.1.repos.0"].each { |text| assert_includes skill, text }
  refute_includes skill, "Report the URL from"
end

  def test_it_never_asks_for_a_pasted_key
    refute_match(/paste/i, skill)
  end

  def test_it_uses_the_cli_copy
    ["Signed in as <email>.", "Not signed in. Run cadre login.", "Your key is no longer valid. Run cadre login.", "The code expired. Run cadre login again."].each do |text|
      assert_includes skill, text
    end
  end
end
