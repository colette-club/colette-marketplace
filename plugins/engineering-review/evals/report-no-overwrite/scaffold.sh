#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$here/../_lib/make-repo.sh" "$here/../_fixtures/small-elixir"
mkdir -p .reviews
printf '# Review — feature (earlier run today)\n\nEARLIER-REPORT\n' > ".reviews/$(date +%F)-feature.md"
