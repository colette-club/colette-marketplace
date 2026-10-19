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
