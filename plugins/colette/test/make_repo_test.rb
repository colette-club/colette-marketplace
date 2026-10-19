require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"

class MakeRepoTest < Minitest::Test
  SCRIPT = File.expand_path("../evals/_lib/make-repo.sh", __dir__)

  def setup
    @tmp = Dir.mktmpdir
    write("base/lib/a.ex", "base a")
    write("base/lib/b.ex", "base b")
    write("overlay/lib/b.ex", "overlay b")
    write("overlay/docs/spec.md", "spec")
    @repo = File.join(@tmp, "repo")
    FileUtils.mkdir_p(@repo)
  end

  def teardown = FileUtils.rm_rf(@tmp)

  def test_layers_the_fixtures_in_order_into_one_commit_on_main
    _out, err, status = Open3.capture3("bash", SCRIPT, File.join(@tmp, "base"), File.join(@tmp, "overlay"), chdir: @repo)
    assert status.success?, err

    assert_equal "base a", read("lib/a.ex")
    assert_equal "overlay b", read("lib/b.ex")
    assert_equal "spec", read("docs/spec.md")
    log, = Open3.capture3("git", "log", "--format=%s", "main", chdir: @repo)
    assert_equal "base\n", log
  end

  def test_a_single_fixture_still_works
    _out, err, status = Open3.capture3("bash", SCRIPT, File.join(@tmp, "base"), chdir: @repo)
    assert status.success?, err

    assert_equal "base b", read("lib/b.ex")
  end

  private

  def write(path, content)
    file = File.join(@tmp, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, content)
  end

  def read(path) = File.read(File.join(@repo, path))
end
