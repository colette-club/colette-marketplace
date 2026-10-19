# Colette brainstorming — design

## Why

A superpowers spec usually becomes one plan, and that plan becomes one pull request that is too big to review. The review companion (`engineering-review` 0.5.0) now sends such a PR back: more than 20 code files, more than one feature, or not deployable without hurting users. Sending work back at review time is too late. The split has to happen when the work is designed and planned, every single time.

## End goal

A new `colette` plugin in this marketplace. Wherever it is installed, designing and planning go through it:

- **`colette:brainstorming`** runs `superpowers:brainstorming` as it is, with one change to what it produces: the spec describes the **end goal** and the **path to it as a sequence of increments**, each the smallest possible step toward the goal. When the spec is approved, it plans the first increment only.
- **`colette:writing-plans`** plans the **next** increment of such a spec, once the previous one has shipped, by running `superpowers:writing-plans` for that one increment, and only it. Like `superpowers:writing-plans`, it also plans from requirements given with no spec: one increment's worth directly, anything bigger as increments first.
- **Automatic routing.** When Claude reaches for `superpowers:brainstorming` or `superpowers:writing-plans` on its own (for example on "let's build X", or when a brainstorm hands off to planning), the colette version runs instead. Typing `/superpowers:brainstorming` or `/superpowers:writing-plans` still runs plain superpowers: that is the escape hatch.

No PR designed and planned this way is one the review companion would send back.

## What an increment is

The definition is the review companion's: EP-I4, EP-I5 and EP-E5 in `engineering-review`'s `engineering-principles`. Both skills cite those IDs; they do not restate them in other words.

- **One new thing**: one feature, one fix, or one refactor that changes no behaviour. Never two.
- **The smallest step that delivers it.** Prefer the thinnest slice someone can use end to end. Cut by layer (data model, then write path, then API) only when no usable slice fits, and then keep what is unfinished out of users' reach.
- **One increment = one pull request.**
- **Deployable on its own as soon as its PR is open.** Merged and deployed alone, it breaks nothing, shows users nothing half-built, keeps every frontend and app working, works while the previous version still runs during the rollout, and rolls back without data loss (EP-I5, EP-E5). It may rely on increments before it in the sequence, never on a later one.
- **Small by preference**: aiming for 10 code files and preferably at most 20, tests and docs not counted. This is a preference, not a limit; what decides is one feature as the smallest deployable step. Above 20, the increment says why it cannot be smaller. Even under 20, it is challenged: could it ship as two smaller ones?
- **Done** when implemented, tested, properly designed, following the conventions, and deployable without hurting users, with its PR naming the frontends and apps that depend on it and whether each must change.

The increments are chosen to reach the end goal. They are the path to the goal, not a split of a finished design into PRs.

## Increments of this work

This spec follows its own format.

### Increment 1 — `/colette:brainstorming`

- **Delivers:** the `colette` plugin with the `brainstorming` skill, listed in `marketplace.json` and the README, with `superpowers` and `engineering-review` as dependencies (see Constraints). A user can run `/colette:brainstorming` and get a spec with an end goal and an increments section, then a plan for the first increment.
- **Deployable alone:** yes. The handoff runs `superpowers:writing-plans` itself, with the first increment's scope and limits stated in the request, until increment 3 ships.
- **Consumers:** none. A new plugin; nothing else changes.
- **Code files:** 2 — `plugins/colette/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (the skill, README and evals are docs and tests)
- [x] PR #8

### Increment 2 — route `superpowers:brainstorming` to `colette:brainstorming`

- **Delivers:** the routing hook for brainstorming (see "How the routing works"). "Let's build X" now produces a spec with increments without anyone typing the colette command.
- **Deployable alone:** yes. It relies on increment 1's skill. Removing the plugin removes the hook.
- **Consumers:** every session where `colette` is installed. Typed `/superpowers:brainstorming` is unchanged.
- **Code files:** 4 — `plugins/colette/hooks/hooks.json`, `plugins/colette/hooks/route-skills.sh`, `plugins/colette/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (the version)
- [x] PR #10

### Increment 3 — `/colette:writing-plans`

- **Delivers:** the `writing-plans` skill. A user can run `/colette:writing-plans` on a spec and get a plan for its next unshipped increment. `colette:brainstorming` hands its first increment to it instead of running `superpowers:writing-plans` itself.
- **Deployable alone:** yes. It relies on increment 1's spec format only.
- **Consumers:** `colette:brainstorming`'s handoff, in the same plugin.
- **Code files:** 2 — `plugins/colette/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (the version); the skill is Markdown
- [x] PR #11

### Increment 4 — `/colette:writing-plans` plans from requirements

- **Delivers:** `/colette:writing-plans` plans from requirements given in the conversation, the way `superpowers:writing-plans` does, with no spec. Requirements that fit in one increment are planned directly; bigger ones get an End goal and Increments drafted for approval, saved as a short spec, and Increment 1 is planned.
- **Deployable alone:** yes. A new path in a typed command; a spec, or a spec path, is handled as before.
- **Consumers:** none outside the plugin.
- **Code files:** 2 — `plugins/colette/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (the version); the skill is Markdown
- [x] PR #13

### Increment 5 — route `superpowers:writing-plans` to `colette:writing-plans`

- **Delivers:** the routing hook covers planning too. Any plan Claude starts on its own, including a request with no spec, goes through `colette:writing-plans`. A session whose latest typed brainstorming command is `/superpowers:brainstorming` keeps plain superpowers, planning included *(the person's decision while building this increment)*.
- **Deployable alone:** yes. It relies on increments 2, 3 and 4: without increment 4, routing a plan that has no spec would stop it.
- **Consumers:** every session where `colette` is installed. Typed `/superpowers:writing-plans` is unchanged.
- **Code files:** 3 — `plugins/colette/hooks/route-skills.sh`, `plugins/colette/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (the version)
- [ ] Not shipped

## How `colette:brainstorming` behaves

1. **Run `superpowers:brainstorming` unchanged**: the same conversation, questions, playback, visual companion, written design and builder check. The colette skill adds rules on top; it does not copy or rewrite the superpowers skill.
2. **The spec gains two sections**, in this order, in the document superpowers writes at its usual path (`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`):
   - **End goal:** what exists when every increment has shipped, and why.
   - **Increments:** the ordered path. Each increment states:
     - the one thing it delivers and what someone can do once it is deployed;
     - why it is deployable alone: what stays hidden or behind a flag, how contracts other apps use stay compatible, what runs during the rollout;
     - the frontends and apps that must change, or "none", and what deploys first;
     - the code files it is expected to touch and their count;
     - a status line, `- [ ] Not shipped`, which becomes `- [x] PR #<n>` once its PR is open.
3. **Smallness is checked while drafting the increments**, before the spec is written. Claude challenges each increment itself ("could this ship as two smaller ones that each deploy alone?"); it does not ask the person once per increment *(my call)*. Any increment expected above 20 code files says why it cannot be smaller; one that could be smaller is split. To estimate the files, Claude reads the codebase without asking (reading is allowed before approval) and says it is doing so.
4. **The playback covers the increments**: the person sees and corrects the path, not only the end goal.
5. **The handoff plans the first increment only.** Where superpowers says to invoke `superpowers:writing-plans`, the colette skill runs it for increment 1 alone, or `colette:writing-plans` once increment 3 has shipped. Later increments are planned only after the previous one has shipped, with what it taught.

## How `colette:writing-plans` behaves

0. **What to plan** *(added with increment 4)*: a spec path given in the request wins. Otherwise requirements given in the request are planned the way `superpowers:writing-plans` does, even when an older spec still has unshipped increments; a spec is looked up only when the request gives neither. When they fit in one increment, plan them directly, with no spec file. When they do not, draft an End goal and Increments from them, play them back, save them as a short spec once approved, and plan Increment 1.
1. **Find the spec and the next increment**: the spec given as argument, or the most recent one in `docs/superpowers/specs/` with an Increments section. The next increment is the first one whose status is `- [ ] Not shipped`. If the previous increment's PR is not merged yet, say so and ask whether to plan anyway. **A spec without an Increments section is never planned as is** *(my call)*: the skill drafts its End goal and Increments sections with the same rules, plays them back, and plans the first increment once the person approves them.
2. **Re-check the increment before planning** against what the code is now: still one thing, still deployable alone, still the smallest step. If shipping the earlier increments changed the picture, propose the change to the spec's Increments section and get it approved first.
3. **Run `superpowers:writing-plans` for that increment only.** The plan's header names the spec and the increment. Its file structure lists the code files; above the preferred 20, check the increment is still the smallest that ships its feature, and if it could be smaller, stop and split it in the spec instead of writing the plan.
4. **The plan ends with the PR** *(my call on how, since superpowers' execution cannot change)*. The plan's tasks do not open the PR. Instead the plan ends with a **Finishing** section that superpowers' executor follows after its final review:
   - in `finishing-a-development-branch`, take "push and create a PR", never a local merge;
   - write the PR description given there: the increment, the frontends and apps that depend on it and whether each must change, the deploy order, and what stays behind a flag. The review companion's EP-E5 check reads this description;
   - once the PR number exists, commit the spec's status line `- [x] PR #<n>` on the same branch and push it.
5. **Execution** stays superpowers' (`subagent-driven-development` or `executing-plans`, as `superpowers:writing-plans` offers).

## How the routing works

- **A `PreToolUse` hook on the `Skill` tool**, shipped in `plugins/colette/hooks/hooks.json`, so it is active wherever the plugin is installed and enabled.
- When the call is `superpowers:brainstorming` (increment 2) or `superpowers:writing-plans` (increment 5), the hook **denies** it. The reason it returns tells Claude to invoke `colette:brainstorming` or `colette:writing-plans` instead, with the same request.
- **The colette skills' own calls pass.** When `colette:brainstorming` or `colette:writing-plans` invokes the superpowers skill, it marks the call in the Skill tool's `args`, and the hook lets a marked call through. The builder picks the marker.
- **A plain superpowers session stays plain.** When the person's latest typed brainstorming command in the session is `/superpowers:brainstorming`, the hook lets both superpowers skills through: it reads the session transcript (`transcript_path` in its input) for the typed command. `colette:writing-plans` hands such a call back to plain `superpowers:writing-plans` too, since Claude may pick it by its description. A later typed `/colette:brainstorming` brings the routing back. The transcript format is not documented: if it changes, the hook routes as usual.
- **A typed command is not intercepted.** A prompt starting with `/superpowers:brainstorming` loads the skill without a `Skill` tool call (the same behaviour `plugins/engineering-review/evals/README.md` records for the review companion), so the escape hatch needs no code. The builder confirms this with an eval case.
- **The hook fails open.** If it cannot run or cannot read its input, the call goes through unchanged: a missing redirect must never block someone's work.
- The colette skills' descriptions also say they replace the superpowers skills when the plugin is installed, so Claude picks them directly where it can. The hook is what makes it certain. Neither skill sets `disable-model-invocation`.

## Goals

- Wherever `colette` is installed, every spec has an end goal and an increments section, whether the brainstorm was typed or started by Claude.
- Every plan covers exactly one increment and ends with its PR.
- Every increment is one feature as the smallest deployable step before any code is written.

## Non-goals

- Changing the `superpowers` skills. The colette skills wrap them; the hook only redirects.
- Redirecting a superpowers command the person types themselves.
- Stacked PRs. Increments ship in order, one PR at a time.
- Executing plans, or reviewing PRs: superpowers executes, the review companion reviews.

## Anti-goals

- A "PR breakdown" bolted onto a finished design: increments that do not each move the end goal forward.
- An increment that needs a later one to be safe, or that users can reach before it works.
- Layer-by-layer increments (all migrations, then all services, then all API) when a thin usable slice would fit.
- Restating the review companion's rules in different words, so the two drift apart.
- A hook that blocks work when it fails.

## Constraints

- **`superpowers` is installed with `colette`.** The `colette` plugin declares it as a dependency, so installing `colette` installs and enables `superpowers` at the same scope:
  - `plugins/colette/.claude-plugin/plugin.json`: `"dependencies": ["superpowers@claude-plugins-official", "engineering-review"]`;
  - `.claude-plugin/marketplace.json` (top level): `"allowCrossMarketplaceDependenciesOn": ["claude-plugins-official"]`. Without it, the cross-marketplace dependency is refused or `colette` fails to load.

  This ships with increment 1 and is checked with `claude plugin validate ./plugins/colette` (documented at code.claude.com/docs/en/plugins/dependencies). If someone later disables `superpowers`, both skills say so and stop instead of running without it.
- **`engineering-review` is a dependency too** *(my call)*. It is in the same marketplace, so no allowlist is needed. Both skills load `engineering-review:engineering-principles` and apply EP-I4, EP-I5 and EP-E5 from it. Code files are counted as EP-I4 says: tests and docs are not counted. A plan's file list is an estimate; the review companion's exact count still applies at review.
- The colette skills follow the repository's conventions: one `SKILL.md` per skill, a description in the third person with a "Use when …" clause, English only.
- **The hook is a POSIX `sh` script with no dependencies** (no `jq`, Deno, Node or Python), because it runs on every teammate's machine and `sh` is the one interpreter they all have. Its unit tests run only in this repository, so they are written in Ruby (Minitest), the person's preferred scripting language *(my call on the split)*.
- Tests come first. This marketplace tests skills with `claude plugin eval` cases (see `plugins/engineering-review/evals/`); each increment ships its own eval cases.
- Each increment is its own branch and PR.

## Left to the builder

- The exact skill wording, and whether the increment rules live in each `SKILL.md` or in one shared reference file in the plugin.
- How `colette:writing-plans` finds the spec when several qualify.
- The hook's marker in `args`.
- Eval case design. Each increment needs at least one case that would fail without it. There is no block of answers given in advance *(my call: it would weaken superpowers' approval gate)*. A brainstorming case puts the conversation and the person's explicit approval in its one prompt, and must produce an Increments section with status lines. A writing-plans case starts from a fixture spec and must plan only its next increment. A routing case checks that a request to brainstorm, made without the command, ends in `colette:brainstorming`, and that a typed `/superpowers:brainstorming` does not.
- The plugin's initial version (`0.1.0` suggested) and its README entry.
