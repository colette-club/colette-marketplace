# Colette brainstorming — design

## Why

A superpowers spec usually becomes one plan, and that plan becomes one pull request that is too big to review. The review companion (`engineering-review` 0.5.0) now sends such a PR back: more than 20 code files, more than one feature, or not deployable without hurting users. Sending work back at review time is too late. The split has to happen when the work is designed and planned, every single time.

## End goal

Two commands in a new `colette` plugin of this marketplace:

- **`/colette:brainstorming`** runs `superpowers:brainstorming` as it is, with one change to what it produces: the spec describes the **end goal** and the **path to it as a sequence of increments**, each the smallest possible step toward the goal. When the spec is approved, it plans the first increment only.
- **`/colette:writing-plans`** plans the **next** increment of such a spec, once the previous one has shipped, by running `superpowers:writing-plans` for that one increment, and only it.

No PR planned this way is one the review companion would send back.

**Both commands run only when someone types them.** Claude never picks them on its own: "let's build X" still goes to `superpowers:brainstorming`, unchanged. Each skill sets `disable-model-invocation: true` in its frontmatter. `engineering-review`'s validator does not allow that key (`ALLOWED_SKILL_KEYS`), so whatever validates `colette` must accept it. That `/colette:writing-plans` is typed-only too is my call, following the answer for `/colette:brainstorming`.

## What an increment is

The definition is the review companion's: EP-I4, EP-I5 and EP-E5 in `engineering-review`'s `engineering-principles`. Both commands cite those IDs; they do not restate them in other words.

- **One new thing**: one feature, one fix, or one refactor that changes no behaviour. Never two.
- **The smallest step that delivers it.** Prefer the thinnest slice someone can use end to end. Cut by layer (data model, then write path, then API) only when no usable slice fits, and then keep what is unfinished out of users' reach.
- **One increment = one pull request.**
- **Deployable on its own as soon as its PR is open.** Merged and deployed alone, it breaks nothing, shows users nothing half-built, keeps every frontend and app working, works while the previous version still runs during the rollout, and rolls back without data loss (EP-I5, EP-E5). It may rely on increments before it in the sequence, never on a later one.
- **Within the review companion's limits**: at most 20 code files, tests and docs not counted, and aiming for 10. Even under 20, the command asks whether the increment could ship as two smaller ones.
- **Done** when implemented, tested, properly designed, following the conventions, and deployable without hurting users, with its PR naming the frontends and apps that depend on it and whether each must change.

The increments are chosen to reach the end goal. They are the path to the goal, not a split of a finished design into PRs.

## Increments of this work

This spec follows its own format.

### Increment 1 — `/colette:brainstorming`

- **Delivers:** the `colette` plugin with the `brainstorming` skill, listed in `marketplace.json` and the README, declaring `superpowers` as a dependency (see Constraints). A user can run `/colette:brainstorming` and get a spec with an end goal and an increments section, then a plan for the first increment.
- **Deployable alone:** yes. Until increment 2 ships, the handoff runs `superpowers:writing-plans` directly, with the first increment's scope and limits stated in the request.
- **Consumers:** none. A new plugin; nothing else changes.

### Increment 2 — `/colette:writing-plans`

- **Delivers:** the `writing-plans` skill. A user can run `/colette:writing-plans` on a spec and get a plan for its next unshipped increment. `/colette:brainstorming` hands its first increment to it instead of calling `superpowers:writing-plans` directly.
- **Deployable alone:** yes. It relies on increment 1's spec format only.
- **Consumers:** `/colette:brainstorming`'s handoff, in the same plugin.

## How `/colette:brainstorming` behaves

1. **Run `superpowers:brainstorming` unchanged**: the same conversation, questions, playback, visual companion, written design and builder check. The colette skill adds rules on top; it does not copy or rewrite the superpowers skill.
2. **The spec gains two sections**, in this order, in the document superpowers writes at its usual path (`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`):
   - **End goal:** what exists when every increment has shipped, and why.
   - **Increments:** the ordered path. Each increment states:
     - the one thing it delivers and what someone can do once it is deployed;
     - why it is deployable alone: what stays hidden or behind a flag, how contracts other apps use stay compatible, what runs during the rollout;
     - the frontends and apps that must change, or "none", and what deploys first;
     - the code files it is expected to touch and their count;
     - a status line, `- [ ] Not shipped`, which becomes `- [x] PR #<n>` once its PR is open.
3. **Smallness is checked while drafting the increments**, before the spec is written. Claude challenges each increment itself ("could this ship as two smaller ones that each deploy alone?"); it does not ask the person once per increment *(my call)*. Any increment expected above 10 code files says why it cannot be smaller, and one above 20 is split, always. To estimate the files, Claude reads the codebase without asking (reading is allowed before approval) and says it is doing so.
4. **The playback covers the increments**: the person sees and corrects the path, not only the end goal.
5. **The handoff plans the first increment only.** Where superpowers says to invoke `superpowers:writing-plans`, the colette skill invokes it for increment 1 alone (increment 1 of this work) or `/colette:writing-plans` (once increment 2 has shipped). Later increments are planned only after the previous one has shipped, with what it taught.

## How `/colette:writing-plans` behaves

1. **Find the spec and the next increment**: the spec given as argument, or the most recent one in `docs/superpowers/specs/` with an Increments section. The next increment is the first one whose status is `- [ ] Not shipped`. If the previous increment's PR is not merged yet, say so and ask whether to plan anyway. **A spec without an Increments section is never planned as is** *(my call)*: the command drafts its End goal and Increments sections with the same rules, plays them back, and plans the first increment once the person approves them.
2. **Re-check the increment before planning** against what the code is now: still one thing, still deployable alone, still the smallest step. If shipping the earlier increments changed the picture, propose the change to the spec's Increments section and get it approved first.
3. **Run `superpowers:writing-plans` for that increment only.** The plan's header names the spec and the increment. Its file structure lists the code files; above 20, stop and split the increment in the spec instead of writing the plan.
4. **The plan ends with the PR** *(my call on how, since superpowers' execution cannot change)*. The plan's tasks do not open the PR. Instead the plan ends with a **Finishing** section that superpowers' executor follows after its final review:
   - in `finishing-a-development-branch`, take "push and create a PR", never a local merge;
   - write the PR description given there: the increment, the frontends and apps that depend on it and whether each must change, the deploy order, and what stays behind a flag. The review companion's EP-E5 check reads this description;
   - once the PR number exists, commit the spec's status line `- [x] PR #<n>` on the same branch and push it.
5. **Execution** stays superpowers' (`subagent-driven-development` or `executing-plans`, as `superpowers:writing-plans` offers).

## Goals

- Every spec written through `/colette:brainstorming` has an end goal and an increments section.
- Every plan covers exactly one increment and ends with its PR.
- Every increment meets the review companion's limits before any code is written.

## Non-goals

- Changing the `superpowers` skills. The colette skills wrap them.
- Enforcing anything when someone calls `superpowers:brainstorming` or `superpowers:writing-plans` directly.
- Stacked PRs. Increments ship in order, one PR at a time.
- Executing plans, or reviewing PRs: superpowers executes, the review companion reviews.

## Anti-goals

- A "PR breakdown" bolted onto a finished design: increments that do not each move the end goal forward.
- An increment that needs a later one to be safe, or that users can reach before it works.
- Layer-by-layer increments (all migrations, then all services, then all API) when a thin usable slice would fit.
- Restating the review companion's rules in different words, so the two drift apart.

## Constraints

- **`superpowers` is installed with `colette`.** The `colette` plugin declares it as a dependency, so installing `colette` installs and enables `superpowers` at the same scope:
  - `plugins/colette/.claude-plugin/plugin.json`: `"dependencies": ["superpowers@claude-plugins-official"]`;
  - `.claude-plugin/marketplace.json` (top level): `"allowCrossMarketplaceDependenciesOn": ["claude-plugins-official"]`. Without it, the cross-marketplace dependency is refused or `colette` fails to load.

  This ships with increment 1 and is checked with `claude plugin validate ./plugins/colette` (documented at code.claude.com/docs/en/plugins/dependencies). If someone later disables `superpowers`, both commands say so and stop instead of running without it.
- **`engineering-review` is a dependency too** *(my call)*: `"engineering-review"` in the same `dependencies` list (same marketplace, no allowlist needed). Both commands load `engineering-review:engineering-principles` and apply EP-I4, EP-I5 and EP-E5 from it. Code files are counted as EP-I4 says: tests and docs are not counted. A plan's file list is an estimate; the review companion's exact count still applies at review.
- The colette skills follow the repository's conventions: one `SKILL.md` per skill, a description in the third person with a "Use when …" clause, English only.
- Tests come first. This marketplace tests skills with `claude plugin eval` cases (see `plugins/engineering-review/evals/`) and Python validators; each increment ships its own eval cases.
- Each increment is its own branch and PR.

## Left to the builder

- The exact skill wording, and whether the increment rules live in each `SKILL.md` or in one shared reference file in the plugin.
- How `/colette:writing-plans` finds the spec when several qualify.
- Eval case design. Each increment needs at least one case that would fail without it. There is no block of answers given in advance *(my call: it would weaken superpowers' approval gate)*. A brainstorming case puts the conversation and the person's explicit approval in its one prompt, and must produce an Increments section with status lines. A writing-plans case starts from a fixture spec and must plan only its next increment.
- The plugin's initial version (`0.1.0` suggested) and its README entry.
