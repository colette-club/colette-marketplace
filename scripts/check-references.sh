#!/usr/bin/env bash
# Verifies rule references across the three convention skills.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/colette-code-conventions/skills/colette-code-conventions/SKILL.md"
ELIXIR="$ROOT/plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions/SKILL.md"
FLUTTER="$ROOT/plugins/flutter-conventions-guide/skills/flutter-conventions-guide/SKILL.md"

FAIL=0
fail() { printf 'FAIL %s\n' "$1"; FAIL=1; }

command -v rg >/dev/null 2>&1 || { printf 'ripgrep is required\n'; exit 1; }
for f in "$CORE" "$ELIXIR" "$FLUTTER"; do
  [ -e "$f" ] || { printf 'FAIL missing skill file: %s\n' "$f"; exit 1; }
done

# Rule numbers a skill declares: top-level "N. " list items.
declared() { rg --no-filename -o '^[0-9]+\. ' "$1" | tr -d '. ' | sort -n -u; }

# "core #N" citations across both language skills.
core_cited() {
  rg --no-filename -o 'core #[0-9]+' "$ELIXIR" "$FLUTTER" | rg -o '[0-9]+' | sort -n -u
}

# "#N" references within one skill, ignoring the qualified forms.
intra_refs() {
  sed -e 's/core #[0-9]*//g' -e 's/highest-risk #[0-9]*//g' "$1" \
    | rg -o '#[0-9]+' | tr -d '#' | sort -n -u
}

CORE_NUMS="$(declared "$CORE")"
CORE_LIST=" $(echo "$CORE_NUMS" | tr '\n' ' ')"

# 1. Core rules are contiguous 1-21, with Rule 0 as its own section.
if [ "$CORE_NUMS" != "$(seq 1 21)" ]; then
  fail "core rules are not contiguous 1-21; got:$(echo "$CORE_NUMS" | tr '\n' ' ')"
fi
rg -q '^## Rule 0' "$CORE" || fail "core skill has no '## Rule 0' section"

# 2. No duplicate rule numbers in any skill.
for f in "$CORE" "$ELIXIR" "$FLUTTER"; do
  total="$(rg -c '^[0-9]+\. ' "$f" || printf '0')"
  uniq_n="$(declared "$f" | wc -l | tr -d ' ')"
  [ "$total" = "$uniq_n" ] \
    || fail "$(basename "$(dirname "$f")"): $total numbered lines but $uniq_n unique numbers"
done

# 3. Every cited core #N exists.
for n in $(core_cited); do
  [ "$n" = "0" ] && continue
  echo "$CORE_LIST" | rg -q " $n " \
    || fail "core #$n is cited but not declared in the core skill"
done

# 4. Every core rule is cited by a language skill, or tagged (core-only).
CITED=" $(core_cited | tr '\n' ' ')"
for n in $CORE_NUMS; do
  echo "$CITED" | rg -q " $n " && continue
  rg -q "^$n\. .*\(core-only\)" "$CORE" \
    || fail "core #$n is neither cited by a language skill nor tagged (core-only)"
done

# 5. The tagged (core-only) set is exactly 4 16 17 19 20 21 — no more, no
#    fewer. Check 4 alone would let a broken citation through if the editor
#    silences it by also tagging the rule (core-only).
TAGGED_NUMS="$(rg --no-filename -o '^[0-9]+\. .*\(core-only\)' "$CORE" | rg -o '^[0-9]+' | sort -n -u)"
if [ "$TAGGED_NUMS" != "$(printf '4\n16\n17\n19\n20\n21')" ]; then
  fail "tagged (core-only) set is '$(echo "$TAGGED_NUMS" | tr '\n' ' ')' but must be exactly '4 16 17 19 20 21'"
fi

# 6. Intra-skill references resolve.
for f in "$ELIXIR" "$FLUTTER"; do
  own=" $(declared "$f" | tr '\n' ' ')"
  for n in $(intra_refs "$f"); do
    if [ "$n" = "0" ]; then
      rg -q 'Rule 0' "$f" || fail "$(basename "$f"): #0 referenced but no Rule 0 section"
      continue
    fi
    echo "$own" | rg -q " $n " \
      || fail "$(basename "$f"): #$n referenced but never declared"
  done
done

[ "$FAIL" -eq 0 ] && printf 'references ok\n'
exit "$FAIL"
