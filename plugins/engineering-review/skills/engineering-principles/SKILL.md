---
name: engineering-principles
description: Language-agnostic engineering rules, cited as EP-0 to EP-K10 — naming, functions, error handling, design and minimal solutions, boundaries, comments and docs, tests, concurrency and transactions, side effects, change hygiene, code smells, and database access and indexes — with worked examples. Use when writing or reviewing code in any language; language skills take precedence where they conflict.
---

# Engineering principles

## Overview

These rules hold in every language we write. Code that ignores them can compile and pass its tests, but it fails review and erodes the codebase. **Before writing or reviewing code, check the rules below and match the surrounding code.**

Every rule has a stable ID (`EP-H2`) so reviews and other skills can cite it. Language skills are cited as `elixir #55` or `flutter #90`; other skills by the IDs they give their rules.

[reference.md](reference.md) has a bad/good pair for every group, in neutral pseudocode, then in Elixir, then in Dart. Read it when writing code and an example would help; during a review the rules below are enough.

## Precedence

When two rules conflict, the more specific one wins:

1. the repository's own rules (`CLAUDE.md`, contributing guides);
2. framework and library skills (Phoenix, Oban, React, flutter_bloc, …), then the language skill (`elixir-phoenix-conventions`, `flutter-conventions-guide`, …);
3. this skill.

Known conflicts, so you do not have to guess:

| General rule | Where the more specific rule wins |
|---|---|
| Exceptions over error codes | Elixir returns `{:ok, _}` / `{:error, _}` tuples |
| No flag arguments (EP-B2) | Elixir's `maybe_<verb>(subject, …, flag?)` helper with the boolean last |
| Don't return null | Flutter mirrors the GraphQL schema's nullability |
| DRY everywhere (EP-D10) | Tests prefer repetition over indirection (EP-G2, elixir #54) |

## Rule 0

- **EP-0** — Everything we author is in English: identifiers, comments, docs, test names, log and error messages, commit messages, PR descriptions. The only exception is translated copy that lives in a message catalogue (Gettext, ARB), whose keys are still English. Non-English code you touch is renamed in the same change.

## Highest-risk rules

These are violated most often, even when everything else is right. Check them first.

**EP-C2 — never turn a failure into a success.**
```
✗  write(record); return OK            // the write's failure is lost
✓  return write(record)                // the caller sees what happened
```

**EP-D12 — minimal solution first.**
```
✗  PaymentProviderFactory + ProviderRegistry + AbstractProvider   // one provider exists
✓  StripeProvider.charge(order)                                    // add the abstraction when a second provider is real
```

**EP-H1 / EP-H2 — writes that belong together are atomic; no check-then-act.**
```
✗  n = read(invites); if n >= 1 then write(invites, n - 1)        // two requests both read 1
✓  update invites set n = n - 1 where id = ? and n >= 1            // one statement; 0 rows = none left
```

**EP-H5 — nothing external inside a transaction.**
```
✗  transaction { insert(order); email.send(receipt) }             // email sent even if the commit fails
✓  transaction { insert(order); enqueue(SendReceipt) }            // the job commits with the order
```

**EP-G4 / EP-G5 — every behaviour has a test, and each test fails when its behaviour breaks.**
```
✗  one test: archive(wish) → assert result is ok                  // error branches untested (G4); passes whatever the value (G5)
✓  one test per branch — ok, not_found, already_archived — each asserting the outcome: archived_at is set, or unchanged
```

**EP-K1 — every query pattern on a table that can grow is backed by an index.**
```
✗  select … from listings where city_id = ? order by inserted_at desc     // no index: full scan
✓  create index … on listings (city_id, inserted_at desc) where archived_at is null
```

## Full checklist

### A. Names

- **EP-A1** — Names reveal intent: a reader knows what a thing is for without reading its body.
- **EP-A2** — One word per concept across the codebase (`fetch`/`get`/`load` are not three things).
- **EP-A3** — No abbreviations, no noise words (`data`, `info`, `manager`, `helper`, `util`) unless they are the domain term.
- **EP-A4** — Use the domain's vocabulary; the same concept has the same name in code, docs and conversation.
- **EP-A5** — Predicates read as questions (`archived?`, `isArchived`, `has_invites`).

### B. Functions

- **EP-B1** — Small: a function fits on one screen, roughly 10–30 lines.
- **EP-B2** — One thing: if you can extract a meaningful function from it, it does more than one. No flag arguments that switch behaviour (see Precedence).
- **EP-B3** — One level of abstraction per function; steps are named functions, not inline detail next to high-level calls.
- **EP-B4** — Few parameters: three at most; group related ones into a value object or map.
- **EP-B5** — Command–query separation: a function either changes state or answers a question, not both.
- **EP-B6** — No hidden side effects: a name like `validate`, `get` or `format` never writes, sends or enqueues.
- **EP-B7** — Ask only for what you need: take an id, not the whole object, when only the id is read.

### C. Control flow and errors

- **EP-C1** — Handle every result shape explicitly; no catch-all branch that silently absorbs cases you did not foresee.
- **EP-C2** — Never turn a failure into a success: return or propagate the fallible call's result; every branch of a function returns the same shape.
- **EP-C3** — Handle known errors where you can act on them; send unknown ones to one place (the error pipeline, the observer, the crash reporter) — never log-and-continue.
- **EP-C4** — Typed errors, not strings: a caller can match on the error, and the error can carry fields.

### D. Design

- **EP-D1** — Beck's four rules of simple design, in priority order: passes the tests, reveals intention, no duplication, fewest elements.
- **EP-D2** — Single responsibility: a module or function has one reason to change.
- **EP-D3** — Open–closed: add behaviour by adding code at an extension point that already exists, not by editing every caller.
- **EP-D4** — Substitutability: every implementation of a behaviour, protocol or interface honours the same contract.
- **EP-D5** — Small interfaces: callers depend only on the functions they use.
- **EP-D6** — Depend on abstractions at boundaries (external services, clocks, randomness), not everywhere.
- **EP-D7** — Law of Demeter: talk to your direct collaborators; no `a.b().c().d()` reaching through other objects' internals.
- **EP-D8** — YAGNI: no code for requirements that do not exist yet.
- **EP-D9** — KISS: the plainest construct that works; clever code needs a reason.
- **EP-D10** — DRY for knowledge: one rule, one place. Duplicated *text* is fine when it encodes different decisions (and in tests, see EP-G2).
- **EP-D11** — Composition over inheritance.
- **EP-D12** — Minimal solution first: build the simplest change that satisfies the confirmed intent. Every extra layer, abstraction, generic mechanism (factory, registry, strategy, plugin point), configuration option, dependency or service needs a stated reason — a second implementation that exists today, a real configuration need, a measured problem. Without one, remove it; add it when the reason becomes real.

### E. Boundaries

- **EP-E1** — An app knows everything inside its boundary and nothing outside it; it crosses the boundary only through a published contract (API, event, adapter).
- **EP-E2** — Never branch on who is calling; audience-specific shaping belongs at the edge.
- **EP-E3** — Never re-implement a rule that lives on the other side of a boundary; one side owns it and exposes the result.
- **EP-E4** — Never document another app's behaviour; describe what this code guarantees.

### F. Comments and docs

- **EP-F1** — No comment unless the code cannot say it: comments explain *why* (a constraint, a workaround, a deliberate deviation), never *what*. No narration, banners, commented-out code or history.
- **EP-F2** — Contract docs (docstrings, `@doc`, doc comments) describe what a function guarantees — inputs, options, return shapes — not how it is implemented.
- **EP-F3** — New behaviour ships its docs in the same change, following the repository's documentation convention.
- **EP-F4** — Existing docs, docstrings and comments that describe what you changed are updated in the same change; a stale sentence is a bug.

### G. Tests

- **EP-G1** — FIRST: fast, independent, repeatable, self-validating, timely.
- **EP-G2** — Arrange the data under assertion inside the test body; shared setup is only for harness wiring. Prefer repetition over indirection.
- **EP-G3** — Test behaviour, not implementation: assert outcomes, not which internal calls were made.
- **EP-G4** — Every behaviour has a test that fails when the behaviour breaks: the happy path, each error branch, boundaries and edge cases, state transitions, and each side effect — present on success, absent on failure.
- **EP-G5** — No test smells: no assertion or only "did not fail"; asserting that a mock returns its own stub; checking calls instead of outcomes, or mocking everything; depending on time, order, randomness or sleeps; data hidden in setup; duplicates that cover nothing new; skipped or commented-out tests; testing the framework instead of your code.
- **EP-G6** — Tests ship with the change, in the location the repository's convention gives them.

### H. Concurrency, transactions and side effects

- **EP-H1** — Writes that must succeed or fail together run in one transaction; so does a write whose value came from a row read moments earlier.
- **EP-H2** — No check-then-act and no read-modify-write races: assume a second request arrives at the same moment.
- **EP-H3** — Put invariants in the database (unique index, check constraint, foreign key), not only in code.
- **EP-H4** — Choose the protection by what is at risk, the cheapest one that enforces the rule:

  | At risk | Protection |
  |---|---|
  | Counter, balance, stock | One conditional atomic update, branch on affected rows |
  | Row that may not exist yet | Unique index + upsert |
  | One-shot state transition | Condition in the statement, or a partial unique index |
  | Decision read from rows you then write | Row lock as the first step inside the transaction |
  | Edit spanning human time | Optimistic lock (version column) |
  | Get-or-create, replace a set | Transaction-scoped advisory lock on the domain id |
  | External call once per key | Claim row + the provider's idempotency key, call outside the transaction |
  | Duplicate async work | Job uniqueness |
- **EP-H5** — Nothing external inside a transaction: no HTTP call, email or payment while locks are held; make the call before, or enqueue a job as part of the transaction.
- **EP-H6** — Take locks in one order everywhere (ascending id, parent before children).
- **EP-H7** — Work that can be retried or delivered more than once is idempotent: an idempotency key, a claim row, or a uniqueness guard.
- **EP-H8** — Effects fire only after the commit: events and jobs are published with the write, never before it.
- **EP-H9** — Guard state after every `await` and on cancellation: the screen, request or record may be gone; set timeouts on external waits.
- **EP-H10** — Every side effect is explicit and intended, fires only on success, is safe to repeat or guarded, is tested in its presence and its absence, and is documented as an edge on the system map. Removing an effect is a change to every listener.

### I. Change hygiene

- **EP-I1** — After editing, delete what your edit made pointless: trivial wrappers, unreachable branches, unused fields, stale comments.
- **EP-I2** — Leave the code you touch a little cleaner (the boy-scout rule) — only the code you touch; unrelated clean-ups go in their own change.

### J. Code smells

Each smell points at the rule it breaks.

- **EP-J1** — Long function → EP-B1.
- **EP-J2** — Long parameter list → EP-B4.
- **EP-J3** — Divergent change: one module changes for unrelated reasons → EP-D2.
- **EP-J4** — Shotgun surgery: one change touches many modules → EP-D2, EP-D10.
- **EP-J5** — Feature envy: a function uses another module's data more than its own → EP-D2.
- **EP-J6** — Data clumps: the same values always travel together → EP-B4.
- **EP-J7** — Primitive obsession: strings and integers standing for domain concepts → EP-A4, EP-C4.
- **EP-J8** — Repeated switches on the same type or status → EP-D3.
- **EP-J9** — Speculative generality → EP-D8, EP-D12.
- **EP-J10** — Message chains → EP-D7.
- **EP-J11** — Middle man: a module that only delegates → EP-D12.
- **EP-J12** — Temporary field: a field set only in some cases → EP-D2.
- **EP-J13** — Mysterious name → EP-A1.
- **EP-J14** — Global mutable data → EP-H2.
- **EP-J15** — Dead code → EP-I1.
- **EP-J16** — Comments as deodorant: a comment covering for unclear code → EP-F1.
- **EP-J17** — Duplicated code → EP-D10.
- **EP-J18** — Large module → EP-D2.

### K. Data access and performance

- **EP-K1** — Every query pattern on a table that can grow is backed by an index covering its filters, joins and sort.
- **EP-K2** — Every foreign key is indexed (PostgreSQL does not do it for you).
- **EP-K3** — Composite index columns in the right order: equality columns first, then range or sort columns.
- **EP-K4** — Use the index the condition needs: partial for soft-delete filters (`archived_at IS NULL`), functional for case-insensitive lookups (`lower(email)`), trigram for `LIKE '%…%'`, GiST for geo, GIN for JSON.
- **EP-K5** — No redundant indexes (one index repeating another's leading columns) and no orphaned ones (the query that needed it is gone); every index slows every write.
- **EP-K6** — No N+1: never one query per item of a list; batch, join or preload.
- **EP-K7** — Every list is bounded: a limit or pagination.
- **EP-K8** — Select only the columns you need on wide tables or hot paths.
- **EP-K9** — Migrations are safe on large tables: build indexes without blocking writes, avoid whole-table rewrites, keep backfills out of schema migrations, hold no long locks.
- **EP-K10** — Measure with `EXPLAIN` rather than guess; know roughly how big the table is and how often the query runs.

## Red flags — stop and reconsider

- A non-English identifier, comment or message → EP-0.
- A new factory, registry, strategy, base class, option or dependency with a single user and no stated reason → EP-D12.
- A fallible call followed by a hardcoded success → EP-C2.
- Read a value, decide, then write it back in another statement → EP-H2.
- An HTTP call, email or payment inside a transaction → EP-H5.
- A retry loop around an external call with no idempotency key → EP-H7.
- An event removed while listeners remain, or an effect that fires before the commit → EP-H10, EP-H8.
- `context`, `this` or a record used after `await` without a check → EP-H9.
- A test whose only assertion is "no error", or that asserts a mock's own stub → EP-G5.
- A new branch or error path with no test → EP-G4.
- A behaviour change with no docs change, or a doc sentence that is no longer true → EP-F3, EP-F4.
- `a.b().c().d()` → EP-D7.
- A new `where`, join or `order by` on a growing table with no index; a foreign key without an index → EP-K1, EP-K2.
- A query inside a loop over query results → EP-K6.
- An index created on a large table in a normal (blocking) migration → EP-K9.
