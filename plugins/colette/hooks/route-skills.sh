#!/bin/sh
# Sends Claude's own calls to superpowers:brainstorming to colette:brainstorming.
# colette:brainstorming marks its own call with args that start with [colette]; that call passes.
# Fails open: on input it cannot read, or any error, it prints nothing and the call goes through.

payload=$(cat) || exit 0

printf '%s' "$payload" | grep -Eq '"skill"[[:space:]]*:[[:space:]]*"superpowers:brainstorming"' || exit 0
printf '%s' "$payload" | grep -Eq '"args"[[:space:]]*:[[:space:]]*"\[colette\]' && exit 0

printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"The colette plugin replaces superpowers:brainstorming here. Invoke colette:brainstorming with the same request instead; it runs superpowers:brainstorming itself."}}'
exit 0
