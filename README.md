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
  frontend changes. As a reviewer it offers the author a comment on the description; as the
  author, a redraft it applies once approved. Start it with `/engineering-review:review-companion`.
- **colette** — `/colette:brainstorming` runs superpowers brainstorming, but the spec
  reaches its end goal through the smallest increments, each one feature and deployable on
  its own, and only the first increment is planned. `/colette:writing-plans` plans the next
  increment once the previous one has shipped, and plans from requirements too, as superpowers
  does: one increment directly, bigger work as increments first.
  Its plans end with a PR titled and described to EP-F5: a spec increment's title gives its
  place, and frontend changes get marked spots for their pictures.
  Colette runs only when you ask for it: otherwise Claude brainstorms and plans with plain superpowers.
  A spec colette writes says to plan it with `colette:writing-plans`, so its increments are always planned that way.
  Installing it also installs `superpowers` and `engineering-review`. It needs superpowers 7.0 or later,
  whose brainstorming and planning steps its rules follow, and engineering-review 0.7.0 or later.

The `cadre` plugin moved to its own marketplace, [djeusette/cadre_marketplace](https://github.com/djeusette/cadre_marketplace).

## Add a new plugin

Create `plugins/<name>/` with `.claude-plugin/plugin.json` and a `skills/` (and/or
`agents/`, `commands/`, `hooks/`) dir, then add an entry to
`.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`.
