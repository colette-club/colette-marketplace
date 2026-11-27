# colette-marketplace

Colette engineering Claude Code plugins & skills (marketplace name: `colette-club`).

## Use it

Add the marketplace and enable a plugin:

```
/plugin marketplace add colette-club/colette-marketplace
/plugin install elixir-phoenix-conventions@colette-club
```

Or commit it to a repo's `.claude/settings.json` so the whole team gets it automatically.

## Plugins

- **elixir-phoenix-conventions** — team Elixir/Phoenix conventions (English-only
  codebase, context/Service layering, Ecto/Query, idiomatic control flow, GraphQL,
  events & workers, testing, guardrails) and `elixir-guardrails`, which audits an app
  and installs `mix precommit`, Credo check packs, Dialyzer, Boundary, Sobelow,
  dependency audits and CI with a baseline that only shrinks.
- **flutter-conventions-guide** — team Flutter/Dart conventions (English-only
  codebase, three-tier cubit architecture, immutable state, error pipeline, repos &
  GraphQL, models & enums, screens & widgets, localization, testing, DI).

`cadre`, `engineering-review` and `security-audit` moved to their own marketplace, [djeusette/cadre_marketplace](https://github.com/djeusette/cadre_marketplace). `cadre` replaces the former `colette` plugin: `cadre:brainstorming` brainstorms a feature and `cadre:writing-plans` plans it.

## Add a new plugin

Create `plugins/<name>/` with `.claude-plugin/plugin.json` and a `skills/` (and/or
`agents/`, `commands/`, `hooks/`) dir, then add an entry to
`.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`.
