---
name: writing-plans
description: Plans the next unshipped increment of a colette spec, and only that one, or plans from requirements as superpowers writing-plans does, one increment at a time; ends the plan with its pull request. Use when planning from a spec with an Increments section, after the previous increment has shipped, or from requirements, instead of superpowers:writing-plans, wherever colette is installed, except after a typed /superpowers:brainstorming.
---

# Colette writing plans

You plan one increment at a time: the next one of a spec that has not shipped, or requirements given with no spec, as `superpowers:writing-plans` does. You run `superpowers:writing-plans` for that one increment alone, so the plan becomes one pull request that ships one feature as the smallest deployable step. Later increments are planned after this one ships, with what it taught.

## A plain superpowers session

When this session's latest typed brainstorming command is `/superpowers:brainstorming`, the person chose plain superpowers for this work. That holds only when Claude picked this skill on its own: not when the person typed `/colette:writing-plans`, which asks for colette. Do not apply the rules below: invoke `superpowers:writing-plans` with args that start with `[colette]`, followed by the request unchanged, and add nothing else. A later typed `/colette:brainstorming` brings colette's rules back.

## Before you start

1. Check that `superpowers:writing-plans` and `engineering-review:engineering-principles` are among your available skills. When one is missing, name its plugin — `superpowers` from `claude-plugins-official`, or `engineering-review` from `colette-club` — say it must be installed and enabled, and stop.
2. Load `engineering-review:engineering-principles`. The rules EP-I4, EP-I5 and EP-E5 come from it. When it does not define all three, it is older than 0.5.0: say to update `engineering-review` to 0.5.0 or later, and stop.

## Find the spec and the next increment

- **What to plan.** A spec path given in the request is what to plan. Otherwise, requirements given in the request are what to plan (see "Requirements with no spec"): a feature or change it describes, not just a spec's name or topic, and not "plan the next increment". A spec is looked up only when the request gives neither. When requirements win over an older spec that still has unshipped increments, say so.
- **The spec** is the path given. Otherwise it is the most recent `docs/superpowers/specs/*.md`, by its date, that has an `## Increments` section with a `- [ ] Not shipped` line. When no spec has an unshipped increment but the most recent spec has no Increments section, name it and ask whether to plan it: it gets increments first (see "A spec without increments"). When the request gives neither requirements nor a spec that qualifies, say so and stop. When two are equally recent, ask which. When a newer spec has no Increments section, name it and ask which spec to plan.
- **The next increment** is the first `### Increment` whose status line is `- [ ] Not shipped`. When none is left, say that every increment has shipped, and stop.
- **The previous increment** shipped as `- [x] PR #<n>`; Increment 1 has no previous increment. Check that the PR is merged, from what the person said or with `gh pr view <n> --json state,title,headRefName`, and name the PR you checked: a wrong number can point at another merged PR. When it is not merged, or you cannot tell, say so and ask whether to plan anyway.
- **Say which spec and which increment you chose, and why**, before going on. Status lines reach the default branch only when a PR merges: when this branch is behind its upstream (`git status -sb`), say so, since a shipped increment may still read `- [ ] Not shipped` here.

## A spec without increments

A spec without an Increments section is never planned as is. Draft its End goal and Increments sections the way `colette:brainstorming` does: read "What an increment is", "Drafting the increments" and "The spec" in `../brainstorming/SKILL.md`, next to this skill. Play them back. Once the person approves them, write them into the spec and plan Increment 1.

## Requirements with no spec

Plan requirements given in the request the way `superpowers:writing-plans` does, with colette's rule added. Read the code (reading needs no permission), then decide with EP-I4, EP-I5 and EP-E5 whether they fit in one increment.

- **One increment:** plan it directly, with no spec file. Say in the chat that the work is one increment, and why. Invoke `superpowers:writing-plans` with args that start with `[colette]`, followed by this, with the requirements and a short title filled in:

  > Requirements: <the requirements, as given>. Plan them as one increment: `<title>`. If the plan's file structure goes above the preferred 20 code files (tests and docs not counted), check that it is still the smallest step that ships the feature; if it could be smaller, stop: the requirements need increments first. End the plan with a Finishing section: after the final review, take "push and create a PR" in `finishing-a-development-branch`, never a local merge; the PR description names the change, the frontends and apps that depend on it and whether each must change, the deploy order, and what stays behind a flag.

  When the planner stops because the requirements need increments, go on as for **More than one increment**.

- **More than one increment:** draft an End goal and Increments from them, as for a spec without increments, and play them back. Once the person approves them, save them as a short spec at `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, with a Why from the requirements, then the two sections. When that file exists, add `-2`, `-3`, … before `.md`, so an earlier spec is never overwritten. Then plan its Increment 1 as in "Run superpowers writing-plans".

## Re-check the increment

Read the code as it is now, without asking: reading needs no permission. Check that the increment still meets EP-I4, EP-I5 and EP-E5, and estimate its code files. When shipping the earlier increments changed the picture, propose the change to the spec's Increments section, get it approved and write it, then plan.

## Run superpowers writing-plans

Invoke `superpowers:writing-plans` with args that start with `[colette]`, followed by this, with the spec's path, the increment's number `<i>` and its title filled in:

> Spec: `<spec path>`. Plan ONLY its Increment <i> (`<title>`); other increments are out of scope, and the spec-coverage check covers Increment <i> only. The plan's header names the spec and Increment <i>. If the plan's file structure goes above the preferred 20 code files (tests and docs not counted), check that the increment is still the smallest that ships its feature; if it could be smaller, stop and split it in the spec instead of writing the plan. End the plan with a Finishing section: after the final review, take "push and create a PR" in `finishing-a-development-branch`, never a local merge; the PR description names the increment, the frontends and apps that depend on it and whether each must change, the deploy order, and what stays behind a flag; once the PR exists, commit the spec's status line `- [x] PR #<n>` for Increment <i> on the same branch and push.

Execution stays superpowers': `superpowers:writing-plans` offers it once the plan is written.
