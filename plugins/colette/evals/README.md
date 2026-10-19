# colette evals

Behaviour tests for `/colette:brainstorming`, run with `claude plugin eval`. Each case builds a small
Elixir/Phoenix repository from `_fixtures/wishes-app` on `main`, then runs one prompt that answers what a
brainstorm would ask and approves the design, so the run ends with a written spec.

## Run

From the repository root, with a real git first on `PATH` on macOS
(`export PATH="/Library/Developer/CommandLineTools/usr/bin:$PATH"`):

```bash
claude plugin eval plugins/colette --runs 1 --ablation none --scaffold --trust-plugin \
  --allow-tools "Bash(git *)" Write --no-publish --judge-model sonnet
```

Each case loads `colette`, `engineering-review` (by path) and `superpowers@claude-plugins-official` through
its prompt's `plugins:` list. `Agent` is not allowed, so superpowers' builder check runs inline.

## Cases

| Case | Checks |
|---|---|
| spec-has-increments | A small feature gets a spec with `## End goal`, `## Increments`, consumers, code files and `- [ ] Not shipped`; `superpowers:brainstorming` and `engineering-principles` were loaded; nothing was planned |
| increments-stay-small | A large feature is cut into three or more increments, none above 20 code files |

The content tests in `../test/plugin_test.rb` pin what one prompt cannot reach: the handoff to
`superpowers:writing-plans` and the Review Focus cases of the plan.
