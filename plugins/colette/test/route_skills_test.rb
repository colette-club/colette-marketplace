require "minitest/autorun"
require "open3"
require "json"

class RouteSkillsTest < Minitest::Test
  SCRIPT = File.expand_path("../hooks/route-skills.sh", __dir__)

  def route(stdin) = Open3.capture3({ "PATH" => "/usr/bin:/bin" }, SCRIPT, stdin_data: stdin, unsetenv_others: true)
  def call(skill, args = "Let's build X") = JSON.generate({ hook_event_name: "PreToolUse", tool_name: "Skill", tool_input: { skill: skill, args: args } })

  def test_denies_claudes_own_call_to_superpowers_brainstorming
    out, _err, status = route(call("superpowers:brainstorming"))
    decision = JSON.parse(out).fetch("hookSpecificOutput")
    assert_equal ["PreToolUse", "deny"], decision.values_at("hookEventName", "permissionDecision")
    assert_includes decision["permissionDecisionReason"], "colette:brainstorming"
    assert status.success?
  end

  def test_denies_the_names_the_skill_tool_also_accepts
    ["/superpowers:brainstorming", " superpowers:brainstorming ", " /superpowers:brainstorming"].each do |skill|
      out, = route(JSON.generate({ tool_name: "Skill", tool_input: { skill: skill } }))
      assert_equal "deny", JSON.parse(out).dig("hookSpecificOutput", "permissionDecision"), skill
    end
  end

  def test_denies_a_pretty_printed_payload
    out, = route(JSON.pretty_generate(JSON.parse(call("superpowers:brainstorming"))))
    assert_equal "deny", JSON.parse(out).dig("hookSpecificOutput", "permissionDecision")
  end

  def test_lets_colettes_own_call_through
    out, _err, status = route(call("superpowers:brainstorming", "[colette] Let's build X"))
    assert_equal "", out
    assert status.success?
  end

  def test_lets_other_skills_through
    ["superpowers:writing-plans", "colette:brainstorming", "superpowers:brainstorming-extra", "/superpowers:brainstorming-extra"].each do |skill|
      out, _err, status = route(call(skill))
      assert_equal "", out, skill
      assert status.success?, skill
    end
  end

  def test_lets_through_a_call_that_only_quotes_the_name_in_its_args
    out, = route(call("colette:brainstorming", %q({"skill":"superpowers:brainstorming"})))
    assert_equal "", out
  end

  def test_fails_open_on_input_it_cannot_read
    ["", "not json"].each do |stdin|
      out, _err, status = route(stdin)
      assert_equal "", out
      assert status.success?
    end
  end

  def real(tool_input) = JSON.generate({ session_id: "abc", transcript_path: "/tmp/t.jsonl", cwd: "/repo", permission_mode: "default",
                                          hook_event_name: "PreToolUse", tool_name: "Skill", tool_input: tool_input, tool_use_id: "toolu_1" })

  def test_denies_the_real_payload_without_args
    out, = route(real({ skill: "superpowers:brainstorming" }))
    assert_equal "deny", JSON.parse(out).dig("hookSpecificOutput", "permissionDecision")
  end

  def test_denies_a_marker_that_is_not_at_the_start_of_args
    out, = route(real({ skill: "superpowers:brainstorming", args: "Let's build X [colette]" }))
    assert_equal "deny", JSON.parse(out).dig("hookSpecificOutput", "permissionDecision")
  end

  def test_reads_args_placed_before_skill
    out, = route(real({ args: "[colette] Let's build X", skill: "superpowers:brainstorming" }))
    assert_equal "", out
  end

  def test_ignores_a_matching_name_in_other_fields
    out, = route(JSON.generate({ cwd: "superpowers:brainstorming", description: %q("skill":"superpowers:brainstorming"), tool_name: "Skill", tool_input: { skill: "colette:brainstorming" } }))
    assert_equal "", out
  end
end
