#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$here/../_lib/make-repo.sh" "$here/../_fixtures/small-elixir"
git branch -q -m feature feature/archive-wish
