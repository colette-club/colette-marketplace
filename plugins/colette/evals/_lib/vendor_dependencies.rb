#!/usr/bin/env ruby
# Copies the plugins colette's eval cases load into each case's deps/ folder:
# engineering-review from this repository, and the newest installed superpowers.
# A case can only load plain copies inside its own folder, so run this before
# `claude plugin eval plugins/colette`. The copies are git-ignored.
require "fileutils"
require "rubygems"

module VendorDependencies
  LEFT_OUT = %w[evals .git].freeze

  module_function

  def run(root:, superpowers_cache:)
    superpowers = newest_version(superpowers_cache)
    engineering_review = File.join(root, "plugins", "engineering-review")
    case_dirs(root).each do |case_dir|
      copy(engineering_review, File.join(case_dir, "deps", "engineering-review"))
      copy(superpowers, File.join(case_dir, "deps", "superpowers"))
    end
  end

  def newest_version(cache)
    versions = Dir.exist?(cache) ? Dir.children(cache).grep(/\A\d+(\.\d+)*\z/) : []
    raise "no installed superpowers in #{cache}: install superpowers@claude-plugins-official" if versions.empty?

    File.join(cache, versions.max_by { |version| Gem::Version.new(version) })
  end

  def case_dirs(root)
    Dir.glob(File.join(root, "plugins", "colette", "evals", "*", "prompt.md")).map { |prompt| File.dirname(prompt) }
  end

  def copy(source, target)
    FileUtils.rm_rf(target)
    FileUtils.mkdir_p(target)
    Dir.children(source).reject { |name| LEFT_OUT.include?(name) }.each do |name|
      copy_entry(File.join(source, name), File.join(target, name))
    end
  end

  def copy_entry(source, target)
    if File.directory?(source)
      FileUtils.mkdir_p(target)
      Dir.children(source).each { |name| copy_entry(File.join(source, name), File.join(target, name)) }
    else
      FileUtils.cp(source, target)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  root = File.expand_path("../../../..", __dir__)
  cache = ENV.fetch("SUPERPOWERS_CACHE", File.expand_path("~/.claude/plugins/cache/claude-plugins-official/superpowers"))
  VendorDependencies.run(root: root, superpowers_cache: cache)
  puts "Copied engineering-review and #{File.basename(VendorDependencies.newest_version(cache))} of superpowers into each case's deps/."
end
