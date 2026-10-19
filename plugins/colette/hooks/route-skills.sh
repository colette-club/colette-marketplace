#!/bin/sh
# Sends Claude's own calls to superpowers:brainstorming and superpowers:writing-plans to colette's skills.
# colette's skills mark their own calls with args that start with [colette]; those calls pass.
# A session whose latest typed brainstorming command is /superpowers:brainstorming keeps plain superpowers.
# Fails open: on input it cannot read, or any error, it prints nothing and the call goes through.

payload=$(cat) || exit 0

skill_is() {
  printf '%s' "$payload" | grep -Eq "\"skill\"[[:space:]]*:[[:space:]]*\"[[:space:]]*/?superpowers:$1[[:space:]]*\""
}

if skill_is brainstorming; then
  skill=brainstorming
elif skill_is writing-plans; then
  skill=writing-plans
else
  exit 0
fi

printf '%s' "$payload" | grep -Eq '"args"[[:space:]]*:[[:space:]]*"\[colette\]' && exit 0

# The line number of the latest brainstorming command the person typed for plugin $1, or 0.
typed_last() {
  line=$(grep -nE "\"(content|text)\":\"<command-message>$1:brainstorming</command-message>" "$transcript" 2>/dev/null | tail -n 1 | cut -d: -f1)
  printf '%s' "${line:-0}"
}

transcript=$(printf '%s' "$payload" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
if [ -n "$transcript" ] && [ "$(typed_last superpowers)" -gt "$(typed_last colette)" ]; then
  exit 0
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"The colette plugin replaces superpowers:%s here. Invoke colette:%s with the same request instead; it runs superpowers:%s itself."}}\n' "$skill" "$skill" "$skill"
exit 0
