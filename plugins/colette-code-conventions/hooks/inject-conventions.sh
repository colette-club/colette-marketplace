#!/usr/bin/env bash
# PreToolUse hook: injects a one-per-session instruction to load the
# colette-code-conventions skill. With --reset (SessionStart) it clears the
# session marker instead. Fails open everywhere: prints {} and exits 0.
set -u

STATE_DIR="${CLAUDE_PLUGIN_DATA:-${HOME:-/tmp}/.claude/colette-code-conventions}/sessions"

silent() { printf '{}'; exit 0; }

command -v jq >/dev/null 2>&1 || silent

SESSION_ID="$(jq -r '.session_id // empty' 2>/dev/null)" || silent
[ -n "$SESSION_ID" ] || silent

# The session id becomes a path segment; allow only safe characters.
case "$SESSION_ID" in
  *[!A-Za-z0-9._-]*) silent ;;
esac

MARKER="$STATE_DIR/$SESSION_ID"

if [ "${1:-}" = "--reset" ]; then
  rm -f "$MARKER" 2>/dev/null
  silent
fi

[ -e "$MARKER" ] && silent

mkdir -p "$STATE_DIR" 2>/dev/null || silent
: >"$MARKER" 2>/dev/null || silent

CONTEXT='Colette engineering conventions govern this repository. Before proceeding, invoke the Skill tool with skill "colette-code-conventions" and follow it. It applies to every file here regardless of language, including comments, documentation, and configuration.'

jq -nc --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}' 2>/dev/null || silent
exit 0
