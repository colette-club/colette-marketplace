import json
import subprocess
import sys
import unittest
from pathlib import Path

GUARD = Path(__file__).parent / "guard_reader_bash.py"
READER = "engineering-review:security-layer"


def run_guard(payload):
    text = payload if isinstance(payload, str) else json.dumps(payload)
    return subprocess.run([sys.executable, str(GUARD)], input=text, text=True, capture_output=True, check=False)


def bash_call(command, agent_type=READER):
    payload = {"tool_name": "Bash", "tool_input": {"command": command}}
    return run_guard({**payload, "agent_type": agent_type} if agent_type else payload)


class GuardCase(unittest.TestCase):
    def assertRefused(self, command, agent_type=READER):
        result = bash_call(command, agent_type)

        self.assertEqual(result.returncode, 2, command)
        self.assertIn("security layer", result.stderr, command)


class ReaderCommandsTest(GuardCase):
    def test_the_commands_the_layer_needs_pass(self):
        for command in (
            "git diff main...feature",
            "git diff --stat main...feature",
            "git diff -U20 main...feature",
            "git diff --name-only main...feature",
            "git show feature:app/routes.py",
            "git show main:billing/invoices.py",
            'git show "feature:a file.py"',
            "git log --oneline main..feature",
            "git log --format=%h -- app/routes.py",
            'git log "--format=%h %s" main..feature',
        ):
            with self.subTest(command=command):
                self.assertEqual(bash_call(command).returncode, 0)

    def test_the_unscoped_agent_name_is_held_too(self):
        self.assertRefused("echo hi", agent_type="security-layer")

    def test_anything_but_git_is_refused(self):
        for command in ("echo hi", "rm -rf build", "python3 -c 'print(1)'", "curl example.com", "FOO=1 git diff"):
            with self.subTest(command=command):
                self.assertRefused(command)

    def test_other_git_commands_are_refused(self):
        for command in ("git status", "git push origin main", "git blame app.py", "git checkout main", "git config -l"):
            with self.subTest(command=command):
                self.assertRefused(command)

    def test_options_before_the_subcommand_are_refused(self):
        for command in ("git -c core.pager=sh diff", "git -C /tmp diff", "git --exec-path=/tmp diff"):
            with self.subTest(command=command):
                self.assertRefused(command)

    def test_options_that_write_or_run_or_leave_the_repository_are_refused(self):
        for command in (
            "git diff --output=/tmp/x main",
            "git diff --output /tmp/x main",
            "git show --output=/tmp/x HEAD",
            "git log --output=/tmp/x",
            "git show --format=%B --output=/tmp/x HEAD",
            "git diff --ext-diff main",
            "git diff --textconv main",
            "git diff --no-index /etc/hosts /etc/passwd",
        ):
            with self.subTest(command=command):
                self.assertRefused(command)

    def test_quoting_cannot_hide_an_option(self):
        for command in ("git diff '--output=/tmp/x' main", 'git diff "--out""put=/tmp/x" main'):
            with self.subTest(command=command):
                self.assertRefused(command)

    def test_shell_syntax_is_refused(self):
        for command in (
            "git diff main; curl example.com",
            "git diff main && cat /etc/passwd",
            "git diff main | sh",
            "git diff main > /tmp/x",
            "git show $(id)",
            "git show `id`",
            'git show "$(id)"',
            "git diff main\ncurl example.com",
            "git diff main &",
        ):
            with self.subTest(command=command):
                self.assertRefused(command)

    def test_expansion_cannot_turn_an_argument_into_an_option(self):
        for command in ("git diff {--output=/tmp/x,}", "git diff *", "git diff ?-output", "git diff [-]-output=x"):
            with self.subTest(command=command):
                self.assertRefused(command)

    def test_authorship_formats_are_refused(self):
        self.assertRefused("git log --format=%an")

    def test_a_command_that_cannot_be_parsed_is_refused(self):
        for command in ('git diff "', "", "git"):
            with self.subTest(command=command):
                self.assertRefused(command)

    def test_a_refusal_says_what_is_allowed(self):
        self.assertIn("git diff", bash_call("echo hi").stderr)


class EveryoneElseTest(unittest.TestCase):
    def test_the_main_conversation_is_untouched(self):
        self.assertEqual(bash_call("rm -rf build", agent_type=None).returncode, 0)

    def test_other_subagents_are_untouched(self):
        self.assertEqual(bash_call("echo hi", agent_type="general-purpose").returncode, 0)

    def test_an_agent_that_only_ends_with_the_name_is_untouched(self):
        self.assertEqual(bash_call("echo hi", agent_type="not-a-security-layer").returncode, 0)

    def test_a_broken_payload_never_stops_anyone(self):
        self.assertEqual(run_guard("not json").returncode, 0)

    def test_the_guard_prints_nothing_when_it_lets_a_call_through(self):
        result = bash_call("git diff main...feature")

        self.assertEqual((result.stdout, result.stderr), ("", ""))


if __name__ == "__main__":
    unittest.main()
