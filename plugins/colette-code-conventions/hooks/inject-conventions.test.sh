#!/usr/bin/env bash
# Tests for inject-conventions.sh. Run: bash inject-conventions.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/inject-conventions.sh"

PASS=0
FAIL=0

# Isolate state so tests never touch the real marker directory.
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT
export CLAUDE_PLUGIN_DATA="$TEST_HOME/data"

run_hook() {
  local payload="$1"
  shift
  printf '%s' "$payload" | bash "$SCRIPT" "$@" 2>/dev/null
}

ok() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
no() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n  %s\n' "$1" "$2"; }

assert_contains() {
  case "$2" in
    *"$3"*) ok "$1" ;;
    *) no "$1" "expected to contain '$3', got '$2'" ;;
  esac
}

assert_not_contains() {
  case "$2" in
    *"$3"*) no "$1" "expected NOT to contain '$3', got '$2'" ;;
    *) ok "$1" ;;
  esac
}

assert_equals() {
  if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "expected '$3', got '$2'"; fi
}

PAYLOAD_A='{"session_id":"sess-aaa","hook_event_name":"PreToolUse","tool_name":"Edit"}'
PAYLOAD_B='{"session_id":"sess-bbb","hook_event_name":"PreToolUse","tool_name":"Bash"}'

out="$(run_hook "$PAYLOAD_A")"
assert_contains "first call injects additionalContext" "$out" 'additionalContext'
assert_contains "first call names the PreToolUse event" "$out" 'PreToolUse'
assert_contains "first call names the skill" "$out" 'colette-code-conventions'

out="$(run_hook "$PAYLOAD_A")"
assert_equals "second call in the same session is silent" "$out" '{}'

out="$(run_hook "$PAYLOAD_B")"
assert_contains "a different session injects" "$out" 'additionalContext'

run_hook "$PAYLOAD_A" --reset >/dev/null
out="$(run_hook "$PAYLOAD_A")"
assert_contains "--reset re-arms the session" "$out" 'additionalContext'

out="$(run_hook '{"session_id":"sess-ccc"}')"
assert_not_contains "never emits permissionDecision" "$out" 'permissionDecision'

out="$(run_hook 'not json at all')"
assert_equals "malformed stdin is silent" "$out" '{}'

out="$(run_hook '')"
assert_equals "empty stdin is silent" "$out" '{}'

out="$(run_hook '{"hook_event_name":"PreToolUse"}')"
assert_equals "missing session_id is silent" "$out" '{}'

out="$(run_hook '{"session_id":"../../etc/passwd"}')"
assert_equals "unsafe session_id is silent" "$out" '{}'

out="$(printf '%s' "$PAYLOAD_A" | env PATH=/nonexistent /bin/bash "$SCRIPT" 2>/dev/null)"
assert_equals "missing jq is silent" "$out" '{}'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
