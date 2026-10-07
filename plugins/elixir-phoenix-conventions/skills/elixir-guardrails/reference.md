# Elixir guardrails — reference

How to install each guardrail in an existing app: steps, baseline, gotchas. `templates/` holds the files.

## Contents

- [G1 precommit, warnings, unused deps](#g1-precommit-warnings-unused-deps)
- [G2 Credo and the check packs](#g2-credo-and-the-check-packs)
- [G3 Compile-time coupling (xref)](#g3-compile-time-coupling-xref)
- [G4 Sobelow](#g4-sobelow)
- [G5 Dependency audits](#g5-dependency-audits)
- [G6 Dialyzer](#g6-dialyzer)
- [G7 Docs](#g7-docs)
- [G8 Boundary](#g8-boundary)
- [G9 excellent_migrations](#g9-excellent_migrations)
- [G10 usage_rules](#g10-usage_rules)
- [G11 CI workflows](#g11-ci-workflows)
- [G12 actionlint, PR titles, Dependabot, gitleaks](#g12-actionlint-pr-titles-dependabot-gitleaks)

## G1 precommit, warnings, unused deps

1. From `templates/mix.exs.snippet`, add the `# >>> precommit` alias to `aliases/0` and the `# >>> cli` envs to `cli/0` (create `def cli, do: [preferred_envs: …]` if missing). Add only the deps for the steps being installed now; each later guardrail adds its own.
2. Replace an existing `precommit` (phx.new generates one) — it usually runs `deps.unlock --unused`, which rewrites `mix.lock` instead of failing.
3. Keep an app-wide `compile: "compile --warnings-as-errors"` or `test: [... "test --warnings-as-errors"]` alias if the app has one; precommit passing the flags again is harmless.
4. Until a step's guardrail is installed, leave it out of `precommit`; each later commit adds its step.
5. Run `mix precommit`. Warnings are fixed now; there is no baseline for them. More than about 50 → stop and ask.

`--all-warnings` re-reports warnings from files compiled earlier: without it, a warning in a cached file passes.

## G2 Credo and the check packs

1. Add the credo, jump_credo_checks, oeditus_credo, ex_slop and excellent_migrations deps (and phoenix_test when the app serves HTML pages and wants feature tests).
2. Copy `templates/credo.exs` to `.credo.exs`. Merge the old file into it: every check whose params differ from Credo's defaults goes into `app_checks` (for example `{Credo.Check.Readability.MaxLineLength, [max_length: 120]}`), every `{Check, false}` into `app_disabled`. Show the person what was carried over.
3. Generate the baseline block inside `.credo.exs`:
   ```bash
   MIX_ENV=test mix credo --strict --format json > /tmp/credo.json
   deno run --allow-read --allow-write <plugin>/scripts/credo_baseline.ts /tmp/credo.json .credo.exs
   MIX_ENV=test mix credo --strict
   ```
   The last command must be green. `<plugin>` is this skill's folder `../..`. The script rewrites only the lines between `# >>> baseline` and `# <<< baseline`.
4. In CI, replace `credo --ignore …` flags with plain `credo --strict`.
5. ExSlop's `CaseTrueFalse` message suggests `if`/`else`; our fix is a `maybe_*` helper (conventions #1).

Gotchas: none of the packs enables anything on install; every check is named in `.credo.exs`. `mix igniter.install jump_credo_checks` adds all 22 Jump checks, including `UseObanProWorker` — do not use it. A file leaves the baseline the next time a change touches it: fix it and delete its line.

Credo merges `extra:` entries by replacing a check's params, so `credo_default_params` in the template restates Credo's own params for its parametrized default checks (AliasUsage, TagTODO, MaxLineLength); without it, baselining AliasUsage would make it stricter. Check those params against `deps/credo/.credo.exs` when Credo is upgraded.

Oeditus `SwallowingException` only sees an explicit `try … rescue`. A function-level `rescue` that discards the error passes it, and Credo's `PreferImplicitTry` pushes code toward exactly that form, so check every `rescue` by reading (conventions #62).

## G3 Compile-time coupling (xref)

1. Add the `xref graph --label compile-connected --fail-above 0` step.
2. Run it. If it fails with `Too many references (found: N, …)`, show the person `mix xref graph --label compile-connected`, and set `--fail-above N` in `precommit` and CI as the baseline. N only ever goes down.

Usual causes: a module attribute or module body calling another app module, `import`/`use` of an app module, a struct expanded at compile time.

## G4 Sobelow

1. Add the sobelow dep; copy `templates/sobelow-conf` to `.sobelow-conf`. Set `router:` when the router is not where Phoenix puts it; `router: :none` for an app without one.
2. Run `MIX_ENV=test mix sobelow`. Findings → list them for the person (type, file, line), then baseline with `mix sobelow --mark-skip-all`, which writes `.sobelow-skips`. Each skip goes in the PR description.
3. Sobelow 0.16 also flags `raw` in `.heex` templates and in inline `~H` (low confidence, which is why `threshold: :low`); both are verified end to end, so no custom Credo check is needed.

## G5 Dependency audits

1. Add the mix_audit dep and the `deps.audit` and `cmd mix hex.audit` steps (`cmd`, because compiling first unloads Hex's tasks).
2. Any finding → stop and show it. Upgrading is the default; an ignore (`hex: [ignore_advisories: [...]]` in `project/0`, or `--ignore-advisory-ids` for mix_audit) needs the person's decision and a written reason.

`deps.audit` needs git and network access (it fetches the advisory database).

## G6 Dialyzer

1. Add the dialyxir dep and the `# >>> project` `dialyzer:` keys (merge with an existing `dialyzer:`; keep its `plt_add_apps`). Add `/priv/plts/*.plt` and `/priv/plts/*.plt.hash` to `.gitignore`, and commit `priv/plts/.gitkeep`.
2. Keep an existing `.dialyzer_ignore.exs`; otherwise copy `templates/dialyzer_ignore.exs`. Run `MIX_ENV=dev mix dialyzer`. Warnings → baseline them with `MIX_ENV=dev mix dialyzer --format ignore_file_strict`, pasting its entries into the list one per line, each ending with a comma (rewrite an existing file into that shape too, so later fixes only delete lines).
3. `list_unused_filters: true` makes a stale entry fail, so the file shrinks as code is fixed.

The first PLT build takes several minutes. Run Dialyzer in `MIX_ENV=dev`.

## G7 Docs

1. Add the ex_doc dep and the `cmd sh -c 'MIX_ENV=dev mix docs --warnings-as-errors'` step.
2. Fix every warning (usually a `` `Mod.fun/n` `` reference to something renamed or removed). More than about 50 → stop and ask. A deliberate reference to something without docs goes in `docs: [skip_code_autolink_to: [...]]`.

## G8 Boundary

1. Add the boundary dep and put `:boundary` first in `compilers:` (`[:boundary, :phoenix_live_view] ++ Mix.compilers()`).
2. Declare three top-level boundaries:
   ```elixir
   defmodule MyApp do
     use Boundary, deps: [], exports: []
   end

   defmodule MyAppWeb do
     use Boundary,
       deps: [MyApp],
       exports: [Endpoint],
       # >>> baseline
       dirty_xrefs: [
         MyApp.DataCase
       ]

     # <<< baseline
   end

   defmodule MyApp.Application do
     use Boundary, top_level?: true, deps: [MyApp, MyAppWeb]
   end
   ```
   `dirty_xrefs` is always the last option, one module per line, inside a baseline block (`mix format` moves the closing marker below the call, as shown, which is fine). `MyApp.DataCase` is the one permanent entry: `ConnCase` calls `DataCase.setup_sandbox/1`.
3. `mix compile`. For each `forbidden reference to X`: if X is a context facade or a schema the web layer may use, add it to `MyApp`'s `exports`; otherwise add it to the calling boundary's `dirty_xrefs` — that is the baseline. Every module must belong to a boundary: "X is not included in any boundary" means a module outside the app's namespaces; move or classify it.
4. Contexts as sub-boundaries (`MyApp.Accounts` with `use Boundary, deps: [...], exports: [User]`) come later, one context per commit. They enforce conventions #2 (callers use the facade) and make every cross-context dependency explicit (#47).

Gotchas: in `MIX_ENV=dev` (Dialyzer, docs) Boundary warns that `MyApp.DataCase` need not be in `dirty_xrefs`, because test support is not compiled there; the warning is harmless and fails nothing. A stale `_build` cache gives false "unknown module is listed as an export" warnings — the CI cache key includes `mix.lock`, so adding the dep renews it. `mix boundary.visualize` draws the graph.

## G9 excellent_migrations

Set `config :excellent_migrations, start_after: "<timestamp of the newest file in priv/repo/migrations>"` in `config/config.exs`; existing migrations are never re-checked. The Credo check was added in G2. A justified exception uses `# excellent_migrations:safety-assured-for-next-line <operation>`, which the `guardrails-changed` job catches.

## G10 usage_rules

1. Add the usage_rules dep and the `usage_rules:` key; keep an app's existing `usage_rules:` config (for example a `skills:` block).
2. `MIX_ENV=dev mix usage_rules.sync --yes`. Make sure `CLAUDE.md` contains `@AGENTS.md`.
3. CI runs `mix usage_rules.sync --check` (exit status 2 or 3 when the file is stale).

## G11 CI workflows

1. Copy `templates/github/actions/elixir-setup/action.yml`, `templates/github/scripts/guardrails_gate.ts` (to `.github/scripts/`) and the `build-and-test`, `code-quality` and `dialyzer` workflows.
2. Replace `branches: [main]` with the app's default branch or branches; use `postgis/postgis:17-3.5` when the app's migrations use PostGIS.
3. setup-beam reads `.tool-versions`. An app with only `mise.toml` → ask whether to add `.tool-versions` (mise reads it too) or pin the versions in the action.
4. An old workflow that the new ones replace (for example a single `elixir.yml`) → show both and ask before deleting it. Leave unrelated workflows (Claude review, deploys) alone.

The `guardrails-changed` job runs the base branch's copy of the gate, so a PR cannot loosen the gate that judges it. Besides baselines, guarded files and escape hatches, it fails a PR that adds or removes a guardrail line in `mix.exs` (a `precommit` step, `compilers:`, `dialyzer:`, a check's dep) — so a Dependabot PR that raises a Credo or Sobelow requirement in `mix.exs` needs the label. The gate is a tripwire, not a lock: it cannot see a new entry inside an existing multi-line ignore list, and a PR can edit the workflow itself. Required status checks and CODEOWNERS (SKILL.md, step 4) and review (EP-I3) cover the rest.

## G12 actionlint, PR titles, Dependabot, gitleaks

1. Copy `actionlint.yml`, `lint-pr.yml` and `dependabot.yml`; set the branches.
2. Labels `guardrails-changed` and `dependencies` must exist: `gh label create guardrails-changed --color B60205 --description "Reviewed change to a guardrail"` — ask first.
3. Run one full-history scan locally: `gitleaks git --redact .`. Report each finding by file, line and rule, never the value, and tell the person to rotate anything real. CI then scans only new commits.
4. Ask the person to turn on GitHub secret scanning with push protection; only they can.
