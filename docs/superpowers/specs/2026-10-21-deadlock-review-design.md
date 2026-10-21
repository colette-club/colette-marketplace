# Deadlock-proof review — design

## Why

The person wants the review companion to make sure no deadlock can occur in a change it reviews. Today pass 6 has one line on deadlocks — "locks taken in different orders in different places (EP-H6)" — and every race finding is **conditional** unless the author confirms at checkpoint 2 that two requests can overlap.

Real apps are used by many people at once. A deadlock or a race that only needs two requests to overlap will happen in production; asking whether it can is the wrong default. The person wants every situation that can cause a deadlock hunted — row locks, multi-row locks and everything similar — the verdict written out even when nothing is found, and real concurrent usage assumed. The review stays generic: nothing in it is tied to a programming language, framework, ORM or database engine.

## End goal

- **Every deadlock situation is hunted** (the catalogue below), in pass 6, in terms of transactions, rows, locks, workers and connections.
- **Every review states a deadlock verdict.** A new report section lists each path the change adds or touches that holds a lock, its locks and waits in order, the other paths that take the same locks, and why it cannot deadlock — or the finding that says it can.
- **Real concurrent usage is assumed**, for deadlocks and for races alike. A finding that only needs two things to overlap is confirmed, not conditional.

## The assumption: many real users at once

The reviewer assumes the app is in real use by many people at the same time:

- **The same path runs many times at once** — for one person (a double tap, two devices, a retry) and for different people acting on a shared record (two guests booking the same slot, two members editing the same list).
- **Everything else runs alongside** — background jobs, scheduled tasks, webhooks, admin actions, migrations during a rolling deploy — touching the same rows while users do.
- **Work runs more than once** — a job runs again after a failure, an event or webhook is delivered twice, a request is retried (the person's answer).

Consequences:

- A race, deadlock or duplicate-execution finding (EP-H2, EP-H6, EP-H7) that depends only on overlap or on work running more than once is **confirmed**. It is never conditional on "whether X can run twice at once", "whether this job is retried" or "whether this event is delivered more than once".
- A path is cleared only by a **guarantee in the code**, and the verdict names it: a job that cannot run twice at once, a job with retries turned off, an idempotency key or claim row, a lock taken earlier that makes the paths queue, a unique constraint, a single conditional statement. *(My call: an answer such as "it runs once per click" does not clear it, since it does not stop a second person or a second device.)*
- Checkpoint 2's "How the code runs" question no longer asks whether something can run twice at once, is retried or is delivered more than once. It keeps only what the code cannot show, such as who calls it from outside the repository *(my call)*; a finding that rests on such a fact stays conditional on it, as today.
- The confirmation rule ("never act on an assumption that needs confirming") is unchanged, with this one stated exception: overlap is the given, not an assumption. The companion's descriptions that say it "asks before assuming anything" say so too.
- Other uses of "conditional" — proportionality, guardrails, consumers, production statistics, removed effects — are unchanged.

## What counts as a deadlock

The catalogue pass 6 hunts. Rule wording is generic; the language skills supply the syntax, as EP-H4 already does.

**Locks in the database**

1. **Several rows locked in no fixed order** — a lock-for-update on many rows without a sort, an update or delete that matches many rows, a bulk update, a bulk upsert of unsorted rows. Every write locks the rows it writes until the commit, so plain writes count.
2. **Tables locked in opposite orders** — one path locks the parent then the child, another the child then the parent.
3. **Lock upgrades** — two transactions read a row with a shared lock, then both try to write it.
4. **Locks the database takes silently** — writing a child row locks its parent row for the foreign key; triggers and cascading deletes or updates lock rows in other tables. Whether the foreign-key lock blocks a later write to the parent depends on the engine: on MySQL it does, so "insert child, then update parent" (counter caches, touching the parent's timestamp) deadlocks with itself under load; on PostgreSQL it does not, unless the later statement changes the parent's key, deletes it, or locks it for update. *(My call: the reviewer reads which database the repository uses — from its config, adapter or migrations, as pass 7 already does — and flags an implicit lock only where that engine takes one that blocks. When the engine cannot be read, the finding is conditional on it. The fix that holds everywhere — lock the parent first — is always named.)*
5. **Unique-index waits** — two transactions insert the same keys in different orders and each waits for the other's commit.
6. **Gap locks on rows that do not exist yet** — on MySQL, at its default isolation, a lock-for-update that finds no row, or a range write through a non-unique index, locks the gap; two get-or-create or "reserve if free" transactions both take it, then each insert waits on the other. Flagged only where the engine takes gap locks; the fix is a unique constraint with the insert first, an upsert, or an advisory lock on the key. *(Added after the final review.)*
7. **Advisory or application locks** — taken in different orders, or mixed with row locks in different orders (including locks held in a cache or another store).
8. **Migrations** — schema changes that lock several tables in an order opposite to the app's transactions. *(How long a migration holds its lock stays in pass 7, EP-K9.)*

**Waits the database cannot see**

9. **A transaction holding a lock waits on another worker** — a thread, process, task or job — that needs the same lock through another connection. The database sees one waiter; the app hangs until a timeout.
10. **Pool exhaustion** — a transaction holding a pooled connection waits on work that needs another connection from the same pool; under load the pool runs dry and everything waits.
11. **Workers waiting on each other in a cycle** — A waits for B while B waits for A, or a worker makes a synchronous call to itself.

**Hot rows**

12. **A row every user locks** — a shared counter, a popular parent record, a global settings row. Not a deadlock on its own, but under real traffic it makes every lock-order mistake fire and every lock wait pile up. *(My call: 🟠, or folded into the 🔴 deadlock finding it makes likely.)*

## How the reviewer works (pass 6)

1. **Find every path that holds a lock** among the paths the change adds or touches: transactions, explicit locks, writes inside a transaction, a held pooled connection, a synchronous wait on another worker while any of these is held.
2. **Write each path's lock sequence**: every lock in the order it is taken, explicit and implicit (writes, foreign keys, unique indexes, triggers, cascades), and every wait on another worker or connection while a lock is held.
3. **Search the whole repository**, not only the diff, for other paths that take any of the same locks: other transactions on the same tables, jobs, scheduled tasks, webhook handlers, migrations — and the same path running against itself.
4. **Compare every pair**, each path with itself included. Two locks that can be taken in opposite orders, an upgrade, or a wait cycle is a finding.
5. **Each finding** is 🔴 and confirmed *(my call: a deadlock aborts a transaction or hangs requests under real usage)*, with the two paths, the two locks and their opposite order. It carries a `sequenceDiagram` of the two paths blocking each other, and names the fix: sort and lock every row up front; lock the parent before touching children; take the strongest lock first instead of upgrading; one lock order, written down; move the wait out of the transaction; release the connection before waiting; a timeout on every wait the database cannot see (EP-H9). A retry on a detected deadlock is a fallback, never the fix.
6. **No concrete pair, no finding.** The existing rule holds: a deadlock finding names both paths, both locks and the order that blocks.
7. **Deadlocks the change did not create are reported too** (the person's answer). A pair the search finds where neither path was added or touched by the change is still a finding, marked "existed before this change" so the reviewer can tell it apart *(my call on the marker; whether it counts in the Definition of done is the builder's)*.

## Engineering principles

The rules behind the catalogue go into section H of `engineering-principles`, building on what exists *(the split and wording are the builder's)*:

- **EP-H2** says what "a second request" means: many people at once, the same person twice, different people on a shared record, and jobs alongside.
- **EP-H6** widens: one lock order everywhere, rows sorted and all locked up front, the strongest lock taken first.
- New rules for: counting the locks the database takes for you; never waiting on another worker, connection or process while holding a lock or a pooled connection; no row every user locks on a hot path.
- Section H's index line (`EP-H1–H10`) and the trigger list at the end of `SKILL.md` follow.
- New examples in `reference.md` are **pseudocode only** — no SQL dialect, ORM or runtime *(my call, from "keep the review generic")*.

## The report

A new section **`## 8. Locks and deadlocks`**, after `## 7. Data access & performance`; sections 8–11 become 9–12.

```markdown
## 8. Locks and deadlocks

| Path | Locks and waits, in order | Same locks taken elsewhere | Verdict |
|---|---|---|---|
| `spend_invite` | user row (write) → referral insert (locks user row for the foreign key) | `close_account`: user row (write) | Can't deadlock: both take the user row first |
| `merge_wishes` | wish rows (write), unsorted | `merge_wishes` itself | F-04 |
```

- One row per path the change adds or touches that holds a lock or waits while holding one. The verdict is either "Can't deadlock: <the guarantee or the shared order>" or the finding's ID.
- A change that takes no lock says so in one line: "The change takes no lock and waits on nothing while holding one."
- Hot rows (catalogue item 12) appear in the table with their finding.
- **The verdict does not depend on the report being written** *(my call)*. Checkpoint 3 gains a short **Locks and deadlocks** item after the finding list — one line per path with its verdict, or the "takes no lock" line — and the chat summary carries one line with the count of paths compared and the deadlock findings. The report holds the full table.
- `check_plugin.py report` requires the section in its place. `## 11. Limits and decision` becomes `## 12.` in `_check_closing` and its message.
- Everything that numbers sections moves with it: the template and "Before you write" (eleven → twelve) in `review-report`; pass 8's "**Report.** Section 8" in `review-passes`; `REPORT_SECTIONS` in `check_plugin.py` and its copy in `test_check_plugin.py`; the golden report `evals/_golden/example-report.md`; the graders that hard-code `## 8\.`, `## 9\.` and `## 11\.` (billing-recall ×3, effects-beyond-intent, report-written).
- The diagram guide gains a row for a deadlock: a `sequenceDiagram` with both paths side by side.

## Evals

- **A deadlock recall case** with its own fixture: a change that holds catalogue items 1, 4 and 9 at least, and one opposite-order pair whose other half lives in code the diff does not touch (so only the repository-wide search finds it). The fixture states its database, so item 4 is a true positive on that engine. Graders check each is reported as a confirmed finding.
- **A no-false-alarm case**: a change that locks several rows in a consistent, sorted order, plus an "insert child, then update parent" on an engine where it does not deadlock. Graders check there is no deadlock finding and checkpoint 3's verdict says why it cannot deadlock.
- **clean-change** also checks checkpoint 3's one-line "takes no lock" verdict.
- The cases built on the `referrals` fixture are re-checked: whether its insert-then-update now yields a deadlock finding depends on the database the fixture uses.
- **referrals-runtime-unknown** is inverted: with `runtime: unknown`, the race is still confirmed, not conditional.
- **gate-checkpoint-2**'s grader stops expecting questions about running twice at once, retries or redelivery.
- **billing-recall** and **secret-checkpoint-3** are re-checked: their retry findings (EP-H7) are now confirmed.
- The recall case's untouched pair, or a second one, includes a deadlock where neither side changed; a grader checks it is reported and marked as existing before the change.
- **The golden report** gains the section and its status line no longer cites a checkpoint-2 answer for the race.
- Cases that pre-answer "once per click" may now report races they did not before; their graders are checked, none is known to fail.

## Goals

- No deadlock situation in the catalogue gets past a review unflagged, including the ones the database cannot detect.
- Every report says, path by path, why the change can or cannot deadlock.
- Races, deadlocks and duplicate work are judged against real usage — many people at once, retries and repeat deliveries — never against a single request run once.

## Non-goals

- A formal proof, a load test, or running anything against a database to detect deadlocks.
- Engine-specific rules: the EP rules stay generic. Pass 6 names an engine only where its implicit locks differ (catalogue items 4 and 6), as pass 7 already names engines for indexes.
- Changing the companion's other "conditional" uses.
- Fixing the code: the companion still only reviews.

## Anti-goals

- Crying wolf: a deadlock finding without two concrete paths, two locks and the order that blocks.
- A verdict of "can't deadlock" that does not show what it compared.
- A path cleared on someone's word rather than a guarantee in the code.
- Any rule or example tied to a programming language, framework or ORM.
- A report that is silent about deadlocks.

## Constraints

- Skills follow this repository's conventions: one `SKILL.md` per skill, a third-person description with a "Use when …" clause, plain English. `python3 plugins/engineering-review/scripts/check_plugin.py plugin plugins/engineering-review` passes, and so does `python3 -m unittest discover -s plugins/engineering-review/scripts -p 'test_*.py'`.
- Tests first: the checker tests and the eval cases are written before the skill text that makes them pass.
- Precedence is unchanged: the repository's rules, then framework and library skills, then the language skill, then `engineering-principles`.
- The companion's confirmation rule holds for everything but overlap.
- One branch and PR *(my call: the assumption and the deadlock work ship together, as atomic commits)*. It bumps engineering-review's minor version (0.8.1 → 0.9.0) in `plugin.json` and `marketplace.json`, with a release note in `evals/README.md`.

## Left to the builder

- The split, numbering and wording of the new and widened EP-H rules, and of the pass 6 block.
- The fixtures' language and contents (any language: the review must not depend on it).
- Whether `check_plugin.py` checks the new table's columns, or only the section.
- The exact wording of the "takes no lock" line and of the verdicts.
