#!/usr/bin/env python3
"""PreToolUse hook: holds the security-layer subagent's Bash to read-only git commands.

The subagent reads untrusted code, so a prompt injection in a reviewed change must not reach a
shell. Every other agent passes straight through: this hook runs on each Bash call of every
session that has the plugin, so anything it cannot read lets the call go on.
"""
import json
import re
import shlex
import sys

READER = "security-layer"
SUBCOMMANDS = {"diff", "show", "log"}
SAFE_COMMAND = re.compile(r"""[\w ./:@^~+=,%"'-]*""", re.ASCII)
SAFE_OPTION = re.compile(
    r"--stat|--name-only|--name-status|--numstat|--oneline|--no-color|--patch|-p"
    r"|-U\d+|--unified=\d+|-n\d+|--max-count=\d+"
    r"|--(format|pretty)=(%[hHsb]| )+"
)
REFUSAL = (
    "The security layer may only run `git diff`, `git show` and `git log` with plain revisions, "
    "paths and read-only options, one command per call. Read the file another way, or leave this "
    "fact as the candidate's unresolved_fact."
)


def is_reader(agent_type):
    return isinstance(agent_type, str) and agent_type.split(":")[-1] == READER


def is_allowed(command):
    if not isinstance(command, str) or not SAFE_COMMAND.fullmatch(command):
        return False
    try:
        words = shlex.split(command)
    except ValueError:
        return False
    if len(words) < 2 or words[0] != "git" or words[1] not in SUBCOMMANDS:
        return False
    return _only_safe_options(words[2:])


def _only_safe_options(arguments):
    for argument in arguments:
        if argument == "--":
            return True
        if argument.startswith("-") and not SAFE_OPTION.fullmatch(argument):
            return False
    return True


def main():
    try:
        call = json.load(sys.stdin)
    except ValueError:
        return 0
    if not isinstance(call, dict) or call.get("tool_name") != "Bash" or not is_reader(call.get("agent_type")):
        return 0
    tool_input = call.get("tool_input")
    if isinstance(tool_input, dict) and is_allowed(tool_input.get("command")):
        return 0
    print(REFUSAL, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
