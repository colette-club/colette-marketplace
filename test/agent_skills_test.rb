# The repo's committed skills live in `.agents/skills/`, each linked from
# `.claude/skills/` so Claude Code finds it, and AGENTS.md's Skills table
# names them with the plugin skills the work needs, whose plugins
# `.claude/settings.json` enables, each with its marketplace.
require "json"
require "minitest/autorun"

ROOT = File.expand_path("..", __dir__)
SKILLS_DIR = ".agents/skills"
CLAUDE_DIR = ".claude/skills"
SETTINGS_JSON = ".claude/settings.json"
COMMITTED = "committed in .agents/skills/"
TABLE_ROWS = 6

Row = Struct.new(:skill, :when, :install)

module AgentSkills
  def path(*parts) = File.join(ROOT, *parts)

  def read(*parts) = File.read(path(*parts), encoding: "UTF-8")

  def visible_entries(dir)
    return [] unless File.directory?(path(dir))

    Dir.children(path(dir)).reject { |name| name.start_with?(".") }.sort
  end

  def committed_skills
    visible_entries(SKILLS_DIR).select { |name| File.directory?(path(SKILLS_DIR, name)) }
  end

  def table_lines
    lines = read("AGENTS.md").split("\n")
    heading = lines.index("## Skills")
    return [] unless heading

    section = lines.drop(heading + 1)
    body = section.take_while { |line| !line.start_with?("## ") }
    body.drop_while { |line| !line.start_with?("|") }.take_while { |line| line.start_with?("|") }
  end

  def skills_table
    table_lines.drop(2).map do |line|
      cells = line.sub(/\A\|/, "").sub(/\|\z/, "").split("|").map { |cell| cell.strip.delete("`") }
      assert_equal 3, cells.length, "a Skills row has three cells: #{line}"
      Row.new(*cells)
    end
  end
end

class AgentsSkillsDirTest < Minitest::Test
  include AgentSkills

  def test_gives_every_committed_skill_a_skill_md
    committed_skills.each do |name|
      assert File.file?(path(SKILLS_DIR, name, "SKILL.md")), "#{name} has no SKILL.md"
    end
  end
end

class ClaudeSkillsDirTest < Minitest::Test
  include AgentSkills

  def test_links_every_committed_skill
    committed_skills.each do |name|
      link = File.join(CLAUDE_DIR, name)
      target = File.symlink?(path(link)) ? File.readlink(path(link)) : nil
      assert_equal "../../#{SKILLS_DIR}/#{name}", target, "#{link} must link to ../../#{SKILLS_DIR}/#{name}"
    end
  end

  def test_holds_only_those_links
    entries = visible_entries(CLAUDE_DIR)
    assert_equal committed_skills, entries

    entries.each do |entry|
      assert File.symlink?(path(CLAUDE_DIR, entry)), "#{CLAUDE_DIR}/#{entry} is not a link"
    end
  end
end

class SkillsTableTest < Minitest::Test
  include AgentSkills

  def test_has_the_columns_skill_when_and_install
    assert_equal "| Skill | When | Install |", table_lines.first,
      "AGENTS.md needs a ## Skills heading followed by the table"
    assert_equal TABLE_ROWS, skills_table.length, "update TABLE_ROWS when the table changes"
  end

  def test_has_a_row_for_every_committed_skill_and_a_folder_for_every_committed_row
    committed_rows = skills_table.select { |row| row.install == COMMITTED }.map(&:skill).sort
    assert_equal committed_skills, committed_rows
  end

  def test_says_how_to_install_every_plugin_row
    skills_table.reject { |row| row.install == COMMITTED }.each do |row|
      assert_match(/\Aclaude plugin install [\w-]+@[\w-]+\z/, row.install, "#{row.skill} has no install command")
      assert_match(/\A[\w-]+:[\w-]+\z/, row.skill, "#{row.skill} is not named plugin:skill")
    end
  end

  def test_enables_every_plugin_rows_plugin_and_declares_its_marketplace_in_settings
    settings = JSON.parse(read(SETTINGS_JSON))
    enabled = settings.fetch("enabledPlugins")
    marketplaces = settings.fetch("extraKnownMarketplaces")

    skills_table.reject { |row| row.install == COMMITTED }.each do |row|
      id = row.install.delete_prefix("claude plugin install ")
      marketplace = id.split("@").last

      assert_equal true, enabled[id], "#{id} is not in enabledPlugins in #{SETTINGS_JSON}"
      assert marketplace == "claude-plugins-official" || marketplaces.key?(marketplace),
        "#{marketplace} is not in extraKnownMarketplaces in #{SETTINGS_JSON}"
    end
  end
end

class ClaudeMdTest < Minitest::Test
  include AgentSkills

  def test_imports_agents_md
    assert_match(/^@AGENTS\.md$/, read("CLAUDE.md"))
  end
end
