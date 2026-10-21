# colette evals

Behaviour tests for colette's two skills, `/colette:brainstorming` and `/colette:writing-plans`, and its
routing hook, run with `claude plugin eval`. Each case builds a small Elixir/Phoenix repository on `main` from
`_fixtures/wishes-app`, with an overlay fixture on top when it needs a spec, then runs one prompt that answers
what the skill would ask and approves in advance only what the case needs.

## Run

From the repository root, with a real git first on `PATH` on macOS
(`export PATH="/Library/Developer/CommandLineTools/usr/bin:$PATH"`):

```bash
ruby plugins/colette/evals/_lib/vendor_dependencies.rb
claude plugin eval plugins/colette --runs 1 --ablation none --scaffold --trust-plugin \
  --allow-tools Write --no-publish --judge-model sonnet
```

A case loads only plugins inside its own folder, as plain copies. The first command copies
`plugins/engineering-review` and the newest installed `superpowers` (or the one under `$SUPERPOWERS_CACHE`)
into each case's `deps/`, git-ignored; each prompt's `plugins:` list loads `../..`, `deps/engineering-review`
and `deps/superpowers`. Run it again after either plugin changes. `allowed_tools` does not stop a run from using `Agent`
or `Edit`: traces show superpowers' builder check dispatching a subagent.

## Cases

| Case | Checks |
|---|---|
| spec-has-increments | A small feature gets a spec with `## End goal`, `## Increments`, consumers, code files and `- [ ] Not shipped`; `superpowers:brainstorming` and `engineering-principles` were loaded; nothing was planned |
| increments-stay-small | A large feature is cut into three or more increments, counted by their status lines |
| routes-brainstorming | Asked to build without the colette command, Claude ends in `colette:brainstorming` and the spec has Increments |
| redirects-an-explicit-superpowers-call | Asked in plain words to use `superpowers:brainstorming`, the hook denies the unmarked call and Claude goes on with `colette:brainstorming` |
| plans-the-next-increment | Given a spec whose Increment 1 shipped, `/colette:writing-plans` plans Increment 2 only, through `superpowers:writing-plans`, ending with its PR, titled `Archive wishes (2/3): …` and described to EP-F5 |
| spec-without-increments | A spec without increments gets an end goal and increments proposed for approval; nothing is planned |
| brainstorm-hands-off-to-writing-plans | After an approved brainstorm, the handoff goes to `colette:writing-plans`, which plans Increment 1 only |
| plans-small-requirements | Requirements that fit in one increment are planned directly, with `[colette] Requirements` scope; no spec file; its PR is described to EP-F5, with no place in a sequence |
| big-requirements-get-increments | Bigger requirements get an end goal and increments proposed for approval; no plan, no spec yet |
| routes-writing-plans | Asked in plain words to use `superpowers:writing-plans`, the hook denies the unmarked call and `colette:writing-plans` plans the next increment |
| typed-superpowers-writing-plans-not-routed | A typed `/superpowers:writing-plans` runs plain superpowers; `colette:writing-plans` never runs |
| routes-a-plan-to-a-spec-without-increments | A redirected plan with no spec path, where the latest spec has no Increments, gets that spec named and increments proposed first |
| typed-superpowers-brainstorming-plans-plain | A session started with a typed `/superpowers:brainstorming` stays plain: its planning runs `superpowers:writing-plans`, with no deny and no increments |
| typed-superpowers-not-routed | A typed `/superpowers:brainstorming` runs plain superpowers: no Increments section |

The content tests in `../test/plugin_test.rb` pin each rule of both skills, including what one prompt cannot
reach: the stops, the questions before planning, and the scope `colette:writing-plans` gives
`superpowers:writing-plans`.
