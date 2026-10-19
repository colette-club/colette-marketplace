---
name: writing-plans
description: Plans the next unshipped increment of a colette spec, and only that one, by running superpowers writing-plans with the increment's scope, and ends the plan with its pull request. Use when planning from a spec with an Increments section, or when the previous increment has shipped.
---

# Colette writing plans

You plan one increment of a spec: the next one that has not shipped. You run `superpowers:writing-plans` for it alone, so the plan becomes one pull request that ships one feature as the smallest deployable step. Later increments are planned after this one ships, with what it taught.

## Before you start

1. Check that `superpowers:writing-plans` and `engineering-review:engineering-principles` are among your available skills. When one is missing, name its plugin — `superpowers` from `claude-plugins-official`, or `engineering-review` from `colette-club` — say it must be installed and enabled, and stop.
2. Load `engineering-review:engineering-principles`. The rules EP-I4, EP-I5 and EP-E5 come from it. When it does not define all three, it is older than 0.5.0: say to update `engineering-review` to 0.5.0 or later, and stop.

## Find the spec and the next increment

- **The spec** is the path given. Otherwise it is the most recent `docs/superpowers/specs/*.md`, by its date, that has an `## Increments` section with a `- [ ] Not shipped` line. When no spec qualifies, say so and stop. When two are equally recent, ask which. When a newer spec has no Increments section, name it and ask which spec to plan.
- **The next increment** is the first `### Increment` whose status line is `- [ ] Not shipped`. When none is left, say that every increment has shipped, and stop.
- **The previous increment** shipped as `- [x] PR #<n>`; Increment 1 has no previous increment. Check that the PR is merged, from what the person said or with `gh pr view <n> --json state`. When it is not merged, or you cannot tell, say so and ask whether to plan anyway.
- **Say which spec and which increment you chose, and why**, before going on. Status lines reach the default branch only when a PR merges: when this branch is behind its upstream (`git status -sb`), say so, since a shipped increment may still read `- [ ] Not shipped` here.

## A spec without increments

A spec without an Increments section is never planned as is. Draft its End goal and Increments sections the way `colette:brainstorming` does: read "What an increment is", "Drafting the increments" and "The spec" in `../brainstorming/SKILL.md`, next to this skill. Play them back. Once the person approves them, write them into the spec and plan Increment 1.

## Re-check the increment

Read the code as it is now, without asking: reading needs no permission. Check that the increment is still one feature, still deployable on its own, and still the smallest step, and estimate its code files. When shipping the earlier increments changed the picture, propose the change to the spec's Increments section, get it approved and write it, then plan.

## Run superpowers writing-plans

Invoke `superpowers:writing-plans` with args that start with `[colette]`, followed by this, with the spec's path, the increment's number `<i>` and its title filled in:

> Spec: `<spec path>`. Plan ONLY its Increment <i> (`<title>`); other increments are out of scope, and the spec-coverage check covers Increment <i> only. The plan's header names the spec and Increment <i>. If the plan's file structure goes above the preferred 20 code files (tests and docs not counted), check that the increment is still the smallest that ships its feature; if it could be smaller, stop and split it in the spec instead of writing the plan. End the plan with a Finishing section: after the final review, take "push and create a PR" in `finishing-a-development-branch`, never a local merge; the PR description names the increment, the frontends and apps that depend on it and whether each must change, the deploy order, and what stays behind a flag; once the PR exists, commit the spec's status line `- [x] PR #<n>` for Increment <i> on the same branch and push.

Execution stays superpowers': `superpowers:writing-plans` offers it once the plan is written.
