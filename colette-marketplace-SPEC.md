# Spec — New Colette dev marketplace for the `elixir-phoenix-conventions` skill

> **Scratch file** — this lives in colette-api only because of a write-sandbox. Move it into your new marketplace folder (or your notes) and do NOT commit it to colette-api.

Goal: publish the `elixir-phoenix-conventions` skill as a **Claude Code plugin** in a **new, dedicated team marketplace** repo, then switch `colette-api` to consume it from there (instead of its local `.claude/skills/` copy).

Modeled on two marketplaces already registered on this machine:
- `j-morgan6/elixir-phoenix-guide` (self-hosted plugin via a relative `source`)
- `colette-club/claude-marketplace` (the existing `colette-club` marketplace, holds `day-planner`)

> We deliberately create a **separate** repo so this marketplace can grow to hold many engineering skills/plugins, kept apart from the existing `colette-club` (product) marketplace.

---

## Names (change here if you want, then stay consistent everywhere)

| Thing | Value used in this spec |
|---|---|
| GitHub repo | `colette-club/colette-marketplace` |
| Marketplace `name` (the `@suffix` when enabling plugins) | `colette-dev` |
| Plugin `name` | `elixir-phoenix-conventions` |
| Plugin enable string | `elixir-phoenix-conventions@colette-dev` |
| Visibility | `private` (team-internal conventions) |

⚠️ The marketplace `name` (`colette-dev`) is independent of the repo name (`colette-marketplace`) — that's normal (e.g. the `karpathy-skills` marketplace lives in repo `forrestchang/andrej-karpathy-skills`). Keep the **marketplace name identical** in `marketplace.json`, in the `extraKnownMarketplaces` key, and in the `@colette-dev` enable string.

---

## Final repo structure

```
colette-marketplace/
├── .claude-plugin/
│   └── marketplace.json
├── README.md
└── plugins/
    └── elixir-phoenix-conventions/
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/
            └── elixir-phoenix-conventions/
                ├── SKILL.md          # copied from colette-api
                └── reference.md      # copied from colette-api
```

Notes:
- Skills are **auto-discovered** from the plugin's `skills/` dir — you do NOT list them in `plugin.json`.
- The plugin's `source` is a **relative path** from the marketplace root, so the plugin lives inside this same repo (no extra repos to manage). Add more plugins later as sibling dirs under `plugins/`.

---

## Phase 1 — Scaffold the repo

```bash
cd ~/Code                       # or wherever you keep repos
mkdir colette-marketplace
cd colette-marketplace
git init -b main
mkdir -p .claude-plugin plugins/elixir-phoenix-conventions/.claude-plugin
mkdir -p plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions
```

### `.claude-plugin/marketplace.json`

```json
{
  "name": "colette-dev",
  "description": "Colette engineering Claude Code plugins and skills.",
  "owner": {
    "name": "Colette Club",
    "url": "https://github.com/colette-club"
  },
  "plugins": [
    {
      "name": "elixir-phoenix-conventions",
      "source": "./plugins/elixir-phoenix-conventions",
      "description": "Team Elixir/Phoenix conventions: context/Service layering, Ecto/Query, idiomatic control flow, GraphQL, events & workers, testing.",
      "version": "0.1.0",
      "author": { "name": "Colette Club" },
      "keywords": ["elixir", "phoenix", "ecto", "graphql", "conventions", "best-practices"]
    }
  ]
}
```

### `plugins/elixir-phoenix-conventions/.claude-plugin/plugin.json`

```json
{
  "name": "elixir-phoenix-conventions",
  "version": "0.1.0",
  "description": "Team Elixir/Phoenix conventions: context/Service layering, Ecto/Query, idiomatic control flow, GraphQL, events & workers, testing.",
  "author": {
    "name": "Colette Club",
    "url": "https://github.com/colette-club"
  },
  "homepage": "https://github.com/colette-club/colette-marketplace",
  "repository": "https://github.com/colette-club/colette-marketplace",
  "license": "MIT",
  "keywords": ["elixir", "phoenix", "ecto", "graphql", "conventions", "best-practices"]
}
```

### `README.md`

````markdown
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
````

---

## Phase 2 — Copy the skill content

The skill files already exist and are final in colette-api. Copy them verbatim (single source — don't retype):

```bash
SRC=/Users/djeusette/Code/colette-api/.claude/skills/elixir-phoenix-conventions
DST=plugins/elixir-phoenix-conventions/skills/elixir-phoenix-conventions
cp "$SRC/SKILL.md" "$DST/SKILL.md"
cp "$SRC/reference.md" "$DST/reference.md"
```

---

## Phase 3 — Create the GitHub repo & push

```bash
git add -A
git commit -m "feat: add colette-dev marketplace with elixir-phoenix-conventions plugin"
gh repo create colette-club/colette-marketplace --private --source=. --remote=origin --push
```

(Teammates need read access to this private repo for the marketplace to resolve. Use `--public` instead if you prefer.)

### Quick local sanity check (optional)

```
/plugin marketplace add colette-club/colette-marketplace
/plugin install elixir-phoenix-conventions@colette-dev
```

Then in a new session, confirm the `elixir-phoenix-conventions` skill appears in the available-skills list.

---

## Phase 4 — Switch colette-api to consume it

Do this **after** Phase 3 is pushed (the plugin must resolve). In the **colette-api** repo:

### 4a. Replace the committed `.claude/settings.json` with:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "extraKnownMarketplaces": {
    "elixir-phoenix-guide": {
      "source": {
        "source": "github",
        "repo": "j-morgan6/elixir-phoenix-guide"
      },
      "autoUpdate": true
    },
    "karpathy-skills": {
      "source": {
        "source": "github",
        "repo": "forrestchang/andrej-karpathy-skills"
      }
    },
    "colette-dev": {
      "source": {
        "source": "github",
        "repo": "colette-club/colette-marketplace"
      },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "elixir-phoenix-guide@elixir-phoenix-guide": true,
    "andrej-karpathy-skills@karpathy-skills": true,
    "elixir-phoenix-conventions@colette-dev": true
  }
}
```

### 4b. Remove the now-duplicated local copy and commit:

```bash
cd /Users/djeusette/Code/colette-api
git rm -r .claude/skills/elixir-phoenix-conventions
git add .claude/settings.json
git commit -m "chore: consume elixir-phoenix-conventions from colette-dev marketplace"
```

> Order matters: enable the plugin (4a) and remove the local copy (4b) together, so the skill is never missing. For zero gap, push the marketplace first, verify it resolves, then do 4a+4b in one commit.

---

## Verification checklist

- [ ] `marketplace.json` `name` == `extraKnownMarketplaces` key == `@colette-dev` suffix (all `colette-dev`).
- [ ] `plugin.json` `name` (`elixir-phoenix-conventions`) matches `marketplace.json` `plugins[].name` and the enable-string prefix.
- [ ] `source` in `marketplace.json` points to `./plugins/elixir-phoenix-conventions`, and that dir contains `.claude-plugin/plugin.json` + `skills/`.
- [ ] `gh repo create … --push` succeeded; repo visible at `github.com/colette-club/colette-marketplace`.
- [ ] In a fresh colette-api session, the `elixir-phoenix-conventions` skill loads and `.claude/skills/elixir-phoenix-conventions/` is gone.
- [ ] A teammate (with repo access) running colette-api gets the skill via committed settings — no manual install.

---

## Notes / gotchas

- **Bump versions on change.** When you edit the skill later, bump `version` in both `marketplace.json` and `plugin.json`; `autoUpdate: true` in settings pulls it for the team.
- **Private repo auth.** Marketplace resolution uses each user's git/gh credentials. Everyone who needs the skill must have read access to `colette-club/colette-marketplace`.
- **One source of truth.** After Phase 4, the skill lives ONLY in the marketplace repo. Future edits happen there, not in colette-api.
- **More than skills.** The same plugin can also ship `agents/`, `commands/`, and a `hooks/hooks.json` — drop them next to `skills/` and they're auto-discovered.
