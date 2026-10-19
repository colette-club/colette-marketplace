require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../evals/_lib/vendor_dependencies"

class VendorDependenciesTest < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir
    @root = File.join(@tmp, "repo")
    @cache = File.join(@tmp, "cache", "superpowers")
    write(@root, "plugins/engineering-review/.claude-plugin/plugin.json", "{}")
    write(@root, "plugins/engineering-review/skills/engineering-principles/SKILL.md", "EP-I4")
    write(@root, "plugins/engineering-review/evals/big-case/prompt.md", "fixture")
    write(@root, "plugins/colette/evals/spec-has-increments/prompt.md", "case")
    write(@root, "plugins/colette/evals/increments-stay-small/prompt.md", "case")
    write(@cache, "6.4.1/skills/brainstorming/SKILL.md", "old")
    write(@cache, "7.0.0/skills/brainstorming/SKILL.md", "new")
  end

  def teardown = FileUtils.rm_rf(@tmp)

  def test_copies_engineering_review_and_the_latest_superpowers_into_each_case
    VendorDependencies.run(root: @root, superpowers_cache: @cache)

    %w[spec-has-increments increments-stay-small].each do |name|
      deps = File.join(@root, "plugins/colette/evals", name, "deps")
      assert_equal "EP-I4", File.read(File.join(deps, "engineering-review/skills/engineering-principles/SKILL.md"))
      assert_equal "new", File.read(File.join(deps, "superpowers/skills/brainstorming/SKILL.md"))
    end
  end

  def test_leaves_out_the_evals_of_engineering_review
    VendorDependencies.run(root: @root, superpowers_cache: @cache)

    refute File.exist?(File.join(@root, "plugins/colette/evals/spec-has-increments/deps/engineering-review/evals"))
  end

  def test_replaces_a_stale_copy
    stale = File.join(@root, "plugins/colette/evals/spec-has-increments/deps/superpowers/stale.md")
    write(File.dirname(stale), "stale.md", "gone")

    VendorDependencies.run(root: @root, superpowers_cache: @cache)

    refute File.exist?(stale)
  end

  def test_copies_files_behind_symlinks_as_plain_files
    File.symlink(File.join(@cache, "7.0.0/skills/brainstorming/SKILL.md"), File.join(@cache, "7.0.0/linked.md"))

    VendorDependencies.run(root: @root, superpowers_cache: @cache)

    copy = File.join(@root, "plugins/colette/evals/spec-has-increments/deps/superpowers/linked.md")
    refute File.symlink?(copy)
    assert_equal "new", File.read(copy)
  end

  def test_fails_without_an_installed_superpowers
    error = assert_raises(RuntimeError) { VendorDependencies.run(root: @root, superpowers_cache: File.join(@tmp, "none")) }

    assert_match(/superpowers/, error.message)
  end

  private

  def write(base, path, content)
    file = File.join(base, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, content)
  end
end
