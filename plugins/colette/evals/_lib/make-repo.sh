#!/usr/bin/env bash
# Builds a git repository in the current directory from an eval fixture,
# committed on `main`: the codebase a brainstorm reads.
set -euo pipefail

git init -q -b main .
git config user.email "fixture@example.com"
git config user.name "Fixture"
cp -R "$1/." .
git add -A
git commit -q -m "base"
