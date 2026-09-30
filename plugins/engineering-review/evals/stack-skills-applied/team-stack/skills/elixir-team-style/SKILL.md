---
name: elixir-team-style
description: Team Elixir rules for modules, documentation and error handling. Use when writing or reviewing Elixir code.
---

# Elixir team style

- **EX-1** — Every module under `lib/` has a `@moduledoc` that says what it is for.
- **EX-2** — Code in `lib/` does not call bang functions (`get!`, `insert!`) for records that may be missing; it matches on the result.
