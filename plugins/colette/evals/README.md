# colette evals

Behaviour tests for `/colette:brainstorming`, run with `claude plugin eval`. Each case builds a small
Elixir/Phoenix repository from `_fixtures/wishes-app` on `main`, then runs one prompt that answers what a
brainstorm would ask and approves the design, so the run ends with a written spec.

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
and `deps/superpowers`. Run it again after either plugin changes. `Agent` is not allowed, so superpowers'
builder check runs inline.

## Cases

| Case | Checks |
|---|---|
| spec-has-increments | A small feature gets a spec with `## End goal`, `## Increments`, consumers, code files and `- [ ] Not shipped`; `superpowers:brainstorming` and `engineering-principles` were loaded; nothing was planned |
| increments-stay-small | A large feature is cut into three or more increments |
| routes-brainstorming | Asked to build without the colette command, Claude ends in `colette:brainstorming` and the spec has Increments |
| redirects-an-explicit-superpowers-call | Asked in plain words to use `superpowers:brainstorming`, the hook denies the unmarked call and Claude goes on with `colette:brainstorming` |
| plans-the-next-increment | Given a spec whose Increment 1 shipped, `/colette:writing-plans` plans Increment 2 only, through `superpowers:writing-plans`, ending with its PR |
| spec-without-increments | A spec without increments gets an end goal and increments proposed for approval; nothing is planned |
| brainstorm-hands-off-to-writing-plans | After an approved brainstorm, the handoff goes to `colette:writing-plans`, which plans Increment 1 only |
| typed-superpowers-not-routed | A typed `/superpowers:brainstorming` runs plain superpowers: no Increments section |

The content tests in `../test/plugin_test.rb` pin each rule of both skills, including what one prompt cannot
reach: the stops, the questions before planning, and the scope `colette:writing-plans` gives
`superpowers:writing-plans`.
