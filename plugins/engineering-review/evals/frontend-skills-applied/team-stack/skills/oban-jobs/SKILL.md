---
name: oban-jobs
description: Team rules for Oban background workers: retries, uniqueness and return values. Use when writing or reviewing code that defines or enqueues Oban jobs.
---

# Oban jobs

- **OBAN-1** — Every worker sets `max_attempts` explicitly in `use Oban.Worker`.
- **OBAN-2** — A worker whose job must not run twice for the same arguments declares `unique:` with a period.
- **OBAN-3** — `perform/1` returns `:ok`, `{:error, reason}` or `{:cancel, reason}`; an expected failure (a missing record) never raises.
