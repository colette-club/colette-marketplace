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

- **colette-code-conventions** — language-agnostic engineering conventions
  (English-only codebase, abstraction and naming, error handling, contracts and
  application boundaries, change hygiene, self-contained tests, workflow).
  **Install this one first** — the two skills below cite its rules as `core #N`.
- **elixir-phoenix-conventions** — team Elixir/Phoenix conventions (English-only
  codebase, context/Service layering, Ecto/Query, idiomatic control flow, GraphQL,
  events & workers, testing).
- **flutter-conventions-guide** — team Flutter/Dart conventions (English-only
  codebase, three-tier cubit architecture, immutable state, error pipeline, repos &
  GraphQL, models & enums, screens & widgets, localization, testing, DI).

## Add a new plugin

Create `plugins/<name>/` with `.claude-plugin/plugin.json` and a `skills/` (and/or
`agents/`, `commands/`, `hooks/`) dir, then add an entry to
`.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`.
