#!/usr/bin/env bash
# Builds a git repository in the current directory from one or more eval
# fixtures, copied in order so later ones overlay earlier ones, committed on
# `main`: the codebase a brainstorm or a plan reads.
set -euo pipefail

git init -q -b main .
git config user.email "fixture@example.com"
git config user.name "Fixture"
for fixture in "$@"; do
  cp -R "$fixture/." .
done
git add -A
git commit -q -m "base"
