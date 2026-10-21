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
- **engineering-review** — language-agnostic engineering principles (clean code,
  concurrency and transactions, side effects, tests, docs, database access) and
  `review-companion`, which supports a human code review in any language with
  confirmation checkpoints and a report of explained findings, recommendations and
  diagrams. It loads and applies every installed skill for the change's languages,
  frameworks, libraries and frontend work. It flags a change that weakens a
  guardrail and can run the repository's own checks. It sends back a change that is not the
  smallest increment shipping one feature, with a proposed split, and holds a change to the
  definition of done, including the frontends and apps that depend on it. It checks the
  pull request's title and description (EP-F5): the feature and the increment's place, what
  it does, how it works with diagrams, what happens behind the scenes, and pictures for
  frontend changes. Start it with `/engineering-review:review-companion`.
- **colette** — `/colette:brainstorming` runs superpowers brainstorming, but the spec
  reaches its end goal through the smallest increments, each one feature and deployable on
  its own, and only the first increment is planned. Wherever it is installed, Claude's own
  brainstorming goes through it; typing `/superpowers:brainstorming` still runs plain
  superpowers. Claude's own planning goes through it too; typing `/superpowers:writing-plans`
  still runs plain superpowers, and once `/superpowers:brainstorming` is the latest brainstorming command
  you typed in a session, that session stays plain superpowers, planning included. `/colette:writing-plans` plans the next increment once the previous one has
  shipped, and plans from requirements too, as superpowers does: one increment directly,
  bigger work as increments first. Installing it also installs `superpowers` and `engineering-review`. It needs superpowers 7.0 or later:
  its rules follow that version's brainstorming and planning steps.

## Add a new plugin

Create `plugins/<name>/` with `.claude-plugin/plugin.json` and a `skills/` (and/or
`agents/`, `commands/`, `hooks/`) dir, then add an entry to
`.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`.
