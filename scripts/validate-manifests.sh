#!/usr/bin/env bash
# Verifies marketplace.json against each plugin's own manifest.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKET="$ROOT/.claude-plugin/marketplace.json"
FAIL=0
fail() { printf 'FAIL %s\n' "$1"; FAIL=1; }

command -v jq >/dev/null 2>&1 || { printf 'jq is required\n'; exit 1; }
jq -e . "$MARKET" >/dev/null 2>&1 || { printf 'FAIL marketplace.json does not parse\n'; exit 1; }

while IFS="$(printf '\t')" read -r name source version; do
  dir="$ROOT/${source#./}"
  manifest="$dir/.claude-plugin/plugin.json"
  if [ ! -d "$dir" ]; then fail "$name: source path missing: $source"; continue; fi
  if [ ! -e "$manifest" ]; then fail "$name: no plugin.json at $manifest"; continue; fi
  if ! jq -e . "$manifest" >/dev/null 2>&1; then fail "$name: plugin.json does not parse"; continue; fi
  pname="$(jq -r '.name' "$manifest")"
  pversion="$(jq -r '.version' "$manifest")"
  [ "$pname" = "$name" ] || fail "$name: plugin.json declares name '$pname'"
  [ "$pversion" = "$version" ] || fail "$name: marketplace says '$version', plugin.json says '$pversion'"
done <<EOF
$(jq -r '.plugins[] | [.name, .source, .version] | @tsv' "$MARKET")
EOF

[ "$FAIL" -eq 0 ] && printf 'manifests ok\n'
exit "$FAIL"
