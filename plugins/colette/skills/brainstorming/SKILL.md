---
name: brainstorming
description: Runs superpowers brainstorming so the spec reaches its end goal through the smallest increments, each one feature and deployable on its own, then plans the first increment only. Use when designing a feature, change or project, instead of superpowers:brainstorming, wherever colette is installed, except after a typed /superpowers:brainstorming.
---

# Colette brainstorming

You run `superpowers:brainstorming` as it is, with one difference in what comes out: the spec describes the **end goal** and the path to it as a sequence of **increments**, each the smallest possible step that ships one thing and can be deployed on its own. Each increment becomes one pull request the review companion accepts. Only the first increment is planned.

## A plain superpowers session

When this session's latest typed brainstorming command is `/superpowers:brainstorming`, the person chose plain superpowers for this work. Do not apply the rules below: invoke `superpowers:brainstorming` with args that start with `[colette]`, followed by the request unchanged, and add nothing else. A typed `/colette:brainstorming` is always colette's.

## Before you start

1. Check that `superpowers:brainstorming` and `engineering-review:engineering-principles` are among your available skills. When one is missing, name its plugin — `superpowers` from `claude-plugins-official`, or `engineering-review` from `colette-club` — say it must be installed and enabled, and stop. Never brainstorm without them.
2. Load `engineering-review:engineering-principles`. The rules EP-I4, EP-I5 and EP-E5 come from it. When it does not define all three, it is older than 0.5.0: say to update `engineering-review` to 0.5.0 or later, and stop.

## Run superpowers brainstorming

Invoke `superpowers:brainstorming` with args that start with `[colette]`, followed by the person's request. The marker tells colette's hook that this call is colette's own; without it the call is redirected back here. Follow superpowers:brainstorming as written: its conversation, playback, visual companion, written design, builder check and approval gate. The rules below add to it. Where they differ from it, they win: the spec's shape, reading the codebase, the sizes and the handoff.

## What an increment is

Every increment meets EP-I4, EP-I5 and EP-E5 as `engineering-principles` states them; cite them by ID, never restate them. Colette adds only this:

- Prefer the thinnest slice someone can use end to end. Cut by layer (data model, then write path, then API) only when no usable slice fits, and keep what is unfinished out of users' reach.
- An increment may rely on increments before it, never on a later one.
- The increments are the path to the end goal: each is chosen because it moves the goal forward, not cut out of a finished design afterwards.
- A request that fits in one increment gets one increment — never invent a split to make the work look incremental.

## Drafting the increments

Draft the increments while the design takes shape, before the spec is written:

1. Read the codebase to estimate the code files each increment touches, and say that you are doing so. Reading the codebase needs no permission: superpowers' approval gate allows reading, so do not offer it as recon. Count as EP-I4 does: tests and docs are not code files.
2. Challenge each increment once, yourself: could this ship as two smaller ones that can each be deployed and used on their own? If it could, split it. Do not ask the person this once per increment.
3. Aim for 10 code files and prefer 20 code files or fewer: a preference, not a limit. What decides is that the increment ships one feature as the smallest deployable step. An increment above 20 code files says why it cannot be smaller; one that could be smaller is split.
4. Play the increments back with the rest of the design, so the person sees and corrects the path, not only the end goal.

## The spec

The written design gains two sections, in this order, with this template exactly:

```markdown
## End goal

<What exists when every increment has shipped, and why.>

## Increments

### Increment <i> — <the one thing it delivers>

- **Delivers:** <what someone can do once it is deployed>
- **Deployable alone:** <what stays hidden or behind a flag; how contracts other apps use stay compatible; what runs while the previous version is still deployed>
- **Consumers:** <the frontends and apps that must change, or "none"; what deploys first>
- **Code files:** <count> — <expected paths>
- [ ] Not shipped
```

Increments are numbered from 1 (`<i>`). An increment's status line becomes `- [x] PR #<n>`, `<n>` being its pull request's number, once that pull request is open, and nothing else changes it.

## Sizes

Superpowers sizes the work. A quick, clear task or a small change gets no spec: say in the chat that the change is one increment (one feature, the smallest deployable step). When it is not one increment, it is project-sized: write the spec, with its End goal and Increments, as below. When the person skips the questions on project-sized work, superpowers' skill ends there; still write the End goal and Increments sections to a spec, play the increments back, get the person's approval of the increments, then follow "The handoff".

## The handoff

When superpowers says to invoke `superpowers:writing-plans`, invoke `colette:writing-plans` with the spec's path instead: it is the planning step superpowers asks for: it runs `superpowers:writing-plans` itself, scoped to the spec's next increment, Increment 1, and ends that plan with its pull request.

Later increments are planned one at a time with `/colette:writing-plans`, after the previous one has shipped, with what it taught.
