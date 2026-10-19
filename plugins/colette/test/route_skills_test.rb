require "minitest/autorun"
require "open3"
require "json"
require "tmpdir"

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
    ["superpowers:executing-plans", "colette:brainstorming", "colette:writing-plans", "superpowers:brainstorming-extra", "/superpowers:brainstorming-extra", "superpowers:writing-plans-extra"].each do |skill|
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

  def reason(out) = JSON.parse(out).dig("hookSpecificOutput", "permissionDecisionReason")

  def test_denies_claudes_own_call_to_superpowers_writing_plans
    out, _err, status = route(call("superpowers:writing-plans", "Plan the next increment"))
    assert_equal "deny", JSON.parse(out).dig("hookSpecificOutput", "permissionDecision")
    assert_includes reason(out), "Invoke colette:writing-plans with the same request instead"
    refute_includes reason(out), "brainstorming"
    assert status.success?
  end

  def test_denies_writing_plans_named_with_a_slash_or_spaces
    ["/superpowers:writing-plans", " superpowers:writing-plans "].each do |skill|
      out, = route(real({ skill: skill }))
      assert_includes reason(out), "colette:writing-plans", skill
    end
  end

  def test_lets_colettes_own_planner_call_through
    out, = route(call("superpowers:writing-plans", "[colette] Spec: `docs/superpowers/specs/x-design.md`. Plan ONLY its Increment 2"))
    assert_equal "", out
  end

  def test_the_brainstorming_deny_names_colette_brainstorming_only
    out, = route(call("superpowers:brainstorming"))
    assert_includes reason(out), "Invoke colette:brainstorming with the same request instead"
    refute_includes reason(out), "writing-plans"
  end

  def typed(command) = JSON.generate({ type: "user", message: { role: "user", content: "<command-message>#{command}</command-message>\n<command-name>/#{command}</command-name>\n<command-args>Let's build X</command-args>" } })

  def with_transcript(*lines)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "session.jsonl")
      File.write(path, lines.map { |line| line + "\n" }.join)
      yield path
    end
  end

  def call_in(transcript, skill, args = "Plan it") = JSON.generate({ transcript_path: transcript, tool_name: "Skill", tool_input: { skill: skill, args: args } })

  def test_a_session_started_with_a_typed_superpowers_brainstorming_keeps_plain_superpowers
    with_transcript(typed("superpowers:brainstorming"), JSON.generate({ type: "assistant", message: { content: "Spec written." } })) do |transcript|
      ["superpowers:writing-plans", "superpowers:brainstorming"].each do |skill|
        out, = route(call_in(transcript, skill))
        assert_equal "", out, skill
      end
    end
  end

  def test_a_later_typed_colette_brainstorming_routes_again
    with_transcript(typed("superpowers:brainstorming"), typed("colette:brainstorming")) do |transcript|
      out, = route(call_in(transcript, "superpowers:writing-plans"))
      assert_includes reason(out), "colette:writing-plans"
    end
  end

  def test_a_quoted_command_is_not_a_typed_one
    quoted = JSON.generate({ type: "user", message: { content: [{ type: "tool_result", content: typed("superpowers:brainstorming") }] } })
    with_transcript(quoted) do |transcript|
      out, = route(call_in(transcript, "superpowers:writing-plans"))
      assert_includes reason(out), "colette:writing-plans"
    end
  end

  def test_a_missing_transcript_routes_as_usual
    out, = route(call_in("/nonexistent/session.jsonl", "superpowers:writing-plans"))
    assert_includes reason(out), "colette:writing-plans"
  end
end
