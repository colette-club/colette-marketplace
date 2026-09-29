#!/usr/bin/env bash
# Builds a git repository in the current directory from an eval fixture:
# base/ is committed on main, then change/ is overlaid on branch `feature`,
# paths in deleted.txt are removed and generate.sh (if any) runs, and the
# result is committed. The workspace is left on `feature`.
set -euo pipefail

fixture="$1"

git init -q -b main .
git config user.email "fixture@example.com"
git config user.name "Fixture"
cp -R "$fixture/base/." .
git add -A
git commit -q -m "base"

git checkout -q -b feature
if [ -d "$fixture/change" ]; then
  cp -R "$fixture/change/." .
fi
if [ -f "$fixture/deleted.txt" ]; then
  while IFS= read -r path; do
    if [ -n "$path" ]; then git rm -q -r "$path"; fi
  done < "$fixture/deleted.txt"
fi
if [ -f "$fixture/generate.sh" ]; then
  bash "$fixture/generate.sh"
fi
git add -A
git commit -q -m "change"
