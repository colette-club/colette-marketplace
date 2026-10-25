---
name: cadre
description: Use when the person asks to register, create or track a project, feature or milestones in Cadre, or to sign in to Cadre.
---

# Cadre

Cadre shows where every milestone of a feature stands, on every repo, in deploy order. You register a project there from a colette spec with the `cadre` CLI: one milestone per spec increment, each with the repos it touches.

## Before you start

1. Check that `colette:brainstorming` is among your available skills. When it is missing, say the `colette` plugin must be installed and enabled, and stop.
2. Run `gh auth status`. When it fails, tell the person to run `gh auth login`, and stop. The CLI is downloaded with `gh`.

## Install or update the CLI

Run `cadre version`. When the command is missing or reports a version below `0.1.0`, run:

```bash
mkdir -p ~/.local/bin
gh release download -R djeusette/cadre_cli --pattern "cadre_$(uname -s)_$(uname -m).tar.gz" -O - | tar -xz -C ~/.local/bin cadre
```

Then run `cadre version` again. When the command is still missing, `~/.local/bin` is not on the person's `PATH`: tell them to add it, and stop. When it still reports an older version, another `cadre` earlier on `PATH` shadows the new one: tell the person which (`command -v cadre`), and stop.

## Sign in

Run `cadre whoami --json`. It succeeds when the exit code is 0 and the JSON holds an `email`.

- `Not signed in. Run cadre login.` or `Your key is no longer valid. Run cadre login.`: run `cadre login`. It waits up to 10 minutes for the person to click **Allow**, but the Bash tool stops a command after 2 minutes by default and shows no output until the command exits. So run it in the background (Bash `run_in_background`), or with a `timeout` of 600000 ms. Read its first two output lines, `Opening <uri> in your browser.` and `Check that the page shows this code: <code>`, and tell the person the URL and the code: they check that the page shows that code, then click **Allow**. Then wait for the command to exit and read `Signed in as <email>.`
- `The code expired. Run cadre login again.`: run `cadre login` again.

The person never types or copies a key.

## Create a project

1. Find the spec of the feature in `docs/superpowers/specs/`. When there is none, run `colette:brainstorming` first and come back with its spec.
2. Build the project from the spec:
   - `name`: the spec's title without ` — design`.
   - `slug`: the name in kebab case, lowercase letters and digits only.
   - `end_goal`: the text of the End goal section.
   - `milestones`: one per `### Increment`, in spec order, its `title` the increment's title. Its `repos` are the repositories the increment changes, in deploy order: the order the spec's Consumers and deploy-order lines give, the repo that must deploy first listed first.
   Repo names are bare, `colette-api` and not `colette-club/colette-api`, and match the limits below. The current repository (`gh repo view --json name -q .name`) is a repo of every increment whose Code files live in it. A file path is never a repo. Consumers can say "none".
3. Play the repos of each milestone back, and ask the person once to confirm them. Take a repo name only from the spec or from the person, and ask when unsure.
4. Write the JSON to a temporary file and run `cadre project create <file> --json`.
   When it prints `Your key is no longer valid. Run cadre login.`, go back to Sign in, then run it again.
5. On a `422`, the CLI prints one `<path>: <message>` line per error, for example `milestones.1.repos.0: …`. Fix the fields those paths name, then run the command again. Error paths are 0-based positions in the JSON arrays: `milestones.1.repos.0` is the first repo of the second milestone, while milestone numbers shown elsewhere start at 1.
6. Report the `url` field of the JSON body the command printed.

```json
{
  "name": "Wish reminders",
  "slug": "wish-reminders",
  "end_goal": "Members get a reminder before a wish expires.",
  "milestones": [
    {"title": "The API stores a reminder date", "repos": ["colette-api"]},
    {"title": "The app lets members set it", "repos": ["colette-api", "club-mobile"]}
  ]
}
```

## Limits

| Field | Rule |
| --- | --- |
| `name` | 1–120 characters |
| `slug` | `^[a-z0-9]+(-[a-z0-9]+)*$`, up to 60 characters, unique |
| `end_goal` | 1–10 000 characters |
| `milestones` | 1–50, each `title` 1–200 characters |
| `repos` | 1–10 per milestone, no repeats, each `^[a-z0-9][a-z0-9._-]{0,99}$` |
