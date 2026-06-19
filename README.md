# colette-marketplace

Colette engineering Claude Code plugins & skills (marketplace name: `colette-dev`).

## Use it

Add the marketplace and enable a plugin:

```
/plugin marketplace add colette-club/colette-marketplace
/plugin install elixir-phoenix-conventions@colette-dev
```

Or commit it to a repo's `.claude/settings.json` so the whole team gets it automatically.

## Plugins

- **elixir-phoenix-conventions** — team Elixir/Phoenix conventions (context/Service
  layering, Ecto/Query, idiomatic control flow, GraphQL, events & workers, testing).

## Add a new plugin

Create `plugins/<name>/` with `.claude-plugin/plugin.json` and a `skills/` (and/or
`agents/`, `commands/`, `hooks/`) dir, then add an entry to
`.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`.
