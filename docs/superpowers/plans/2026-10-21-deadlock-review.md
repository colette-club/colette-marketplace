# Deadlock-proof review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The review companion judges every change against real concurrent use, hunts every deadlock situation in the spec's catalogue across the whole repository, and states a deadlock verdict in every review: at checkpoint 3, in the chat summary and in a new report section.

**Architecture:** Only `plugins/engineering-review` changes. The new rules go into section H of `engineering-principles`. Pass 6 of `review-passes` gets the assumption and a **Deadlocks** block. `review-companion` gets the confirmation-rule exception, a narrower checkpoint 2 question and a checkpoint 3 verdict item. `review-report` gets `## 8. Locks and deadlocks`, and sections 8–11 become 9–12. `check_plugin.py` requires the new section and its verdict. Two new eval cases and their fixtures pin recall and precision.

**Tech Stack:** Markdown skills; Python 3 stdlib `unittest` (`scripts/test_check_plugin.py`); `claude plugin eval` cases (regex and llm graders).

**Spec:** `docs/superpowers/specs/2026-10-21-deadlock-review-design.md`

## Global Constraints

- Branch `feat/deadlock-review`, which already holds the spec commit. No worktree.
- Before every commit, run both from the repository root, and both must pass:
  - `python3 -m unittest discover -s plugins/engineering-review/scripts -p 'test_*.py'`
  - `python3 plugins/engineering-review/scripts/check_plugin.py plugin plugins/engineering-review`
- Exact strings, used verbatim wherever they appear:
  - the heading `## 8. Locks and deadlocks`;
  - the table header `| Path | Locks and waits, in order | Same locks taken elsewhere | Verdict |`;
  - the no-lock line `The change takes no lock and waits on nothing while holding one.`;
  - the verdict form `Can't deadlock: <why>`;
  - the marker `existed before this change`;
  - the checkpoint 3 label `**Locks and deadlocks.**`;
  - the assumption lead `**Real use is a given, not an assumption:**`.
- Rules and examples are generic: no programming language, framework or ORM is named in a rule or a new example. New `reference.md` examples are pseudocode. Pass 6 names a database engine only for catalogue item 4.
- Plain English, in the house style of the existing skills. Skill descriptions stay third-person with a "Use when …" clause.
- Evals cannot run inside this session's nono sandbox (`/Users` EPERM). Before running any case, ask the person to choose: `nono run --read /Users -- claude --resume`, or a copy of the repository outside `/Users`. A case that is not run is recorded as `not measured` in `evals/README.md`.
- Commits are semantic (`feat(engineering-review): …`, `chore: release …`) and end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

- **A change with no lock at all:** the review must say so in one line, not leave an empty table or stay silent. Pinned by `clean-change/graders/no-lock-verdict.md` (Task 4) and `test_report_locks_section_needs_a_verdict` (Task 2).
- **A deadlock whose other half is in code the diff does not touch:** only the repository-wide search finds it. Pinned by `deadlocks-recall/graders/opposite-order-with-cancel.md` (Task 5).
- **A repository whose database cannot be read:** the foreign-key finding must be conditional on the engine, not a confirmed 🔴 and not dropped. No fixture covers it, so `test_deadlocks_are_hunted_across_the_repository` asserts the rule text (Task 4).
- **Locks taken in a sorted, consistent order, and an insert-child-then-update-parent on PostgreSQL:** neither is a deadlock finding. Pinned by `deadlocks-clean` (Task 5).
- **A pre-answered runtime fact such as "once per click":** it must not clear a race. `test_real_use_is_a_given` asserts the rule text (Task 3). The cases that pre-answer it are re-run in Task 6.

---

### Task 1: The rules behind the catalogue

**Files:**
- Modify: `plugins/engineering-review/skills/engineering-principles/SKILL.md`. Section H: EP-H2 (line 147), EP-H6 (line 162), new EP-H11–H13 after EP-H10. "Red flags" list: lines 210–225.
- Modify: `plugins/engineering-review/skills/engineering-principles/reference.md`. The contents line for H (line 14), the H heading (line 250), new pseudocode examples in section H.
- Test: `plugins/engineering-review/scripts/test_check_plugin.py` (`TABLE_RULE_IDS`, `RuleIdsTest`, `SkillContentTest`)

**Interfaces:**
- Produces: rule IDs `EP-H11`, `EP-H12` and `EP-H13`, cited by Tasks 3 and 4. `check_rule_ids` fails on any citation of an undefined ID, so this task comes first.

- [ ] **Step 1: Write the failing tests**

In `TABLE_RULE_IDS`, change `range(1, 11)` for H to `range(1, 14)`. In `test_all_table_ids_defined`, change `88` to `91`. Add to `SkillContentTest`:

```python
def test_deadlock_rules_are_generic_and_cover_the_catalogue(self):
    principles = (PLUGIN_DIR / "skills" / "engineering-principles" / "SKILL.md").read_text(encoding="utf-8")
    reference = (PLUGIN_DIR / "skills" / "engineering-principles" / "reference.md").read_text(encoding="utf-8")
    rules = {rule: next(line for line in principles.splitlines() if line.startswith(f"- **{rule}** — "))
             for rule in ("EP-H2", "EP-H6", "EP-H11", "EP-H12", "EP-H13")}

    self.assertIn("many people at once", rules["EP-H2"])
    self.assertIn("jobs run again", rules["EP-H2"])
    for text in ("sorted", "up front", "strongest lock first"):
        self.assertIn(text, rules["EP-H6"])
    for text in ("every write locks", "foreign key", "trigger", "cascade"):
        self.assertIn(text, rules["EP-H11"])
    for text in ("another worker", "pooled connection", "cannot see"):
        self.assertIn(text, rules["EP-H12"])
    self.assertIn("every user locks", rules["EP-H13"])
    for rule in ("EP-H11", "EP-H12", "EP-H13"):
        self.assertIn(f"→ {rule}", principles)
    self.assertIn("(EP-H1–H13)](#h-concurrency-transactions-and-side-effects-ep-h1h13)", reference)
    section = reference.split("\n## H. ", 1)[1].split("\n## ", 1)[0]
    for name in ("Ecto", "Repo.", "ActiveRecord", "SQLAlchemy", "FOR UPDATE"):
        self.assertNotIn(name, section.split("```elixir", 1)[0], f"generic examples name {name}")
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python3 -m unittest discover -s plugins/engineering-review/scripts -p 'test_*.py' -k all_table_ids_defined -k deadlock_rules`
Expected: 2 failing tests. The ID set is missing H11–H13, and `StopIteration` is raised on the EP-H11 line.

- [ ] **Step 3: Write the rules**

Use this text, verbatim:

- **EP-H2** — No check-then-act and no read-modify-write races: assume real use — many people at once, the same person twice, different people on a shared record, jobs run again after a failure, events delivered more than once.
- **EP-H6** — Take locks in one order everywhere: rows sorted by key and all locked up front, parent before children, the strongest lock first — never read under a shared lock and then write.
- **EP-H11** — Count the locks the database takes for you in that order: every write locks its rows until the commit; a foreign key locks the parent row; unique indexes, triggers and cascades lock rows elsewhere.
- **EP-H12** — Never wait on another worker, thread or process, or on a second connection, while holding a lock or a pooled connection: the database cannot see that wait and never breaks it.
- **EP-H13** — No row that every user locks on a hot path — a shared counter, a popular parent, a global settings row: it queues everyone behind one lock and makes every lock-order mistake fire.

Add red flags after the EP-H5 line:
- "Rows locked or written in the order a list arrives in, or two paths locking the same tables in opposite orders → EP-H6."
- "A child row inserted, then its parent updated, in one transaction → EP-H11."
- "A transaction that waits on a job, thread, task or second connection → EP-H12."
- "One row updated by every request → EP-H13."

In `reference.md`:
- Change the H contents line and heading to `EP-H1–H13`.
- At the top of section H, add one pseudocode ✗/✓ block each for EP-H6, EP-H11 and EP-H12, in the existing `✗ … // comment` style. For example: `✗ for id in cart: lock(product[id])` against `✓ lock(products where id in cart, order by id)`.

- [ ] **Step 4: Run the tests and the checker**

Run both Global Constraints commands.
Expected: all tests pass. `check_plugin.py` prints no errors, and the table-of-contents anchor resolves.

- [ ] **Step 5: Commit**

```bash
git add plugins/engineering-review/skills/engineering-principles plugins/engineering-review/scripts/test_check_plugin.py
git commit -m "feat(engineering-review): rules for lock order, implicit locks, invisible waits and hot rows"
```

---

### Task 2: The report's Locks and deadlocks section

**Files:**
- Modify: `plugins/engineering-review/scripts/check_plugin.py`: `REPORT_SECTIONS` (lines 38–50), `_check_closing` (lines 395–399), `check_report` (line 303), and a new `_check_locks_section`.
- Modify: `plugins/engineering-review/skills/review-report/SKILL.md`: the template after section 7 (line 113), the renumbered headings (lines 115–134), and "Before you write" (line 197).
- Modify: `plugins/engineering-review/skills/review-passes/SKILL.md:368` (`**Report.** Section 8` → `Section 9`).
- Modify: `plugins/engineering-review/evals/_golden/example-report.md`: the new section after line 259, and sections renumbered to 9–12.
- Create: `plugins/engineering-review/evals/_fixtures/referrals/base/lib/app/repo.ex`
- Modify graders (renumber only):
  - `evals/billing-recall/graders/authorship-reminder.md`, `risk-map-names-payment-code.md` and `risk-map-names-refund-route.md`: `## 8\.` → `## 9\.`
  - `evals/effects-beyond-intent/graders/asked-in-conversation.md`: `## 9\.` → `## 10\.`
  - `evals/report-written/graders/report-has-last-section.md`: `## 11\.` → `## 12\.`
- Test: `plugins/engineering-review/scripts/test_check_plugin.py` (`REPORT_SECTIONS`, `report_text`, `ReportTest`, `SkillContentTest`)

**Interfaces:**
- Produces:
  - `check_plugin.LOCKS_TABLE_HEADER: str`, `check_plugin.NO_LOCK_LINE: str`, holding the exact strings from Global Constraints;
  - `_check_locks_section(report_md: Path, text: str) -> list[str]`;
  - the template text that Task 4's pass 6 **Report.** line points to.

- [ ] **Step 1: Write the failing tests**

- In the test file's `REPORT_SECTIONS`, insert `"## 8. Locks and deadlocks"` after section 7 and renumber the rest to `## 9.`–`## 12.`.
- Add `LOCKS_TABLE` with the header row, the separator and one row: ``| `create_referral` | user row (write) | `close_account`: user row | Can't deadlock: both take the user row first |``.
- Give `report_text` a parameter `locks=LOCKS_TABLE`, written under the section 8 heading.
- Add to `ReportTest`:

```python
def test_report_locks_section_needs_a_verdict(self):
    with tempfile.TemporaryDirectory() as tmp:
        md = write(Path(tmp) / "report.md", report_text(locks="Nothing to say."))

        errors = check_plugin.check_report(md)

    self.assertEqual(len(errors), 1)
    self.assertIn("section 8", errors[0])

def test_report_no_lock_line_is_a_verdict(self):
    with tempfile.TemporaryDirectory() as tmp:
        md = write(Path(tmp) / "report.md", report_text(locks=check_plugin.NO_LOCK_LINE))

        self.assertEqual(check_plugin.check_report(md), [])
```

Add to `SkillContentTest`:

```python
def test_report_template_has_the_locks_section(self):
    report = (PLUGIN_DIR / "skills" / "review-report" / "SKILL.md").read_text(encoding="utf-8")
    passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")

    for text in ("## 8. Locks and deadlocks", check_plugin.LOCKS_TABLE_HEADER, check_plugin.NO_LOCK_LINE,
                 "Can't deadlock: <why>", "the twelve sections are there, in order, and section 12 ends with"):
        self.assertIn(text, report)
    self.assertIn("**Report.** Section 9: one row per touched file", passes)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python3 -m unittest discover -s plugins/engineering-review/scripts -p 'test_*.py'`
Expected failures:
- the new tests, with `AttributeError` on `NO_LOCK_LINE`;
- every report test, because the checker still expects 11 sections;
- `test_golden_report_passes`.

- [ ] **Step 3: Implement the checker**

- Add the two constants and the section to `REPORT_SECTIONS`.
- Point `_check_closing` at `## 12. Limits and decision`, with the message "section 12".
- `_check_locks_section` returns `[]` when the heading is missing, because `_check_sections` already reports that. Otherwise it returns one error, `"{report_md}: section 8 needs the lock table ({LOCKS_TABLE_HEADER}) or '{NO_LOCK_LINE}'"`, when the section's text holds neither string.
- Call it from `check_report`.

- [ ] **Step 4: Write the template, the golden report and the fixture file**

- **Template** (`review-report`), new section 8:
  - a placeholder line: `<One row per path the change adds or touches that holds a lock or waits while holding one, and per path elsewhere that takes the same locks; or the no-lock line.>`;
  - the table header;
  - the no-lock line, introduced with "A change that takes no lock says:";
  - a note that a hot row (EP-H13) appears with its finding, and a finding that existed before the change is marked `existed before this change`.
- Renumber sections 9–12. In "Before you write":
  - change the sections line to `the twelve sections are there, in order, and section 12 ends with`;
  - add the bullet `section 8 has the lock table or the no-lock line;`.
- **Golden report**, new section 8 with one row: ``| `create_referral/2` | referral insert (locks the referrer's user row for the foreign key) → referrer's user row (write) | `create_referral/2` itself, for the same referrer | Can't deadlock: on PostgreSQL (`lib/app/repo.ex`) the foreign-key lock does not block a write that leaves the key alone |``. Renumber the sections after it.
- **`repo.ex`**: `defmodule App.Repo do use Ecto.Repo, otp_app: :app, adapter: Ecto.Adapters.Postgres end`, formatted on three lines.
- Apply the five grader renumbers listed under **Files**.

- [ ] **Step 5: Run the tests and the checker**

Run both Global Constraints commands. Then run `rg -n '## (8|9|10|11|12)' plugins/engineering-review/evals -g '**/graders/*.md'`.
Expected:
- all tests pass, including `test_golden_report_passes`;
- the checker is clean;
- `rg` shows only `## 9\. Risk` (×3), `## 10\. Conversation` and `## 12\. Limits`.

- [ ] **Step 6: Commit**

```bash
git add plugins/engineering-review
git commit -m "feat(engineering-review): every report states its locks and deadlocks in section 8"
```

---

### Task 3: Real use is a given

**Files:**
- Modify: `plugins/engineering-review/skills/review-companion/SKILL.md`:
  - the confirmation rule (lines 36–41);
  - the `runtime` key in the schema (line 62);
  - checkpoint 2, item 4 (line 151);
  - "Writing a finding", the conditional example (the line starting `- **Conditional findings**`).
- Modify: `plugins/engineering-review/agents/review-companion.md` (the `description` on line 3, and the bullet on line 15)
- Modify: `plugins/engineering-review/skills/review-passes/SKILL.md`:
  - line 19, the conditional example;
  - pass 6's **Purpose** (line 165);
  - **Concurrency** items 1 and 2 (lines 169–170);
  - **Side-effect safety** item 3.
- Modify: `plugins/engineering-review/evals/_golden/example-report.md`: F-01's status (line 93), and section 10's "Answers given".
- Delete: `plugins/engineering-review/evals/referrals-runtime-unknown/graders/race-conditional.md`
- Create: `plugins/engineering-review/evals/referrals-runtime-unknown/graders/race-confirmed.md` and `race-not-conditional.md`
- Modify: `plugins/engineering-review/evals/referrals-runtime-unknown/prompt.md`: the description becomes `With runtime facts unknown, the race finding is still confirmed: real use is a given.`
- Modify: `plugins/engineering-review/evals/gate-checkpoint-2/graders/context-and-runtime.md`
- Test: `plugins/engineering-review/scripts/test_check_plugin.py` (`SkillContentTest`, `EvalGraderTest`)

**Interfaces:**
- Consumes: EP-H2 and EP-H7 as reworded in Task 1.
- Produces: the assumption that Task 4's deadlock findings rely on ("confirmed; only a guarantee in the code clears it").

- [ ] **Step 1: Write the failing tests**

```python
def test_real_use_is_a_given(self):
    companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
    passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")
    agent = (PLUGIN_DIR / "agents" / "review-companion.md").read_text(encoding="utf-8")

    self.assertIn("**Real use is a given, not an assumption:**", companion)
    for text in ("only a guarantee in the code clears it", '"it runs once per click" does not clear it'):
        self.assertIn(text, companion)
    self.assertIn("overlap, retries and redelivery are given", companion.split("```yaml\n", 1)[1].split("```", 1)[0])
    self.assertIn("Never ask whether code can run twice at once, is retried or is delivered more than once", companion)
    self.assertIn("Judge every path against real use", passes)
    self.assertIn("real use", agent)
    for retired in ("whether that can happen is a runtime fact", "can run twice at once for the same wish",
                    "Can `archive_wish/1` run twice at once"):
        self.assertNotIn(retired, companion + passes)
```

In `EvalGraderTest`:

```python
def test_the_runtime_unknown_race_is_confirmed(self):
    found = self.grader_pattern("referrals-runtime-unknown", "race-confirmed")
    conditional = self.grader_pattern("referrals-runtime-unknown", "race-not-conditional")

    line = "F-01 🔴 ⚡ [EP-H2, EP-H4] Two requests can both spend the last invite — lib/app/accounts/referrals.ex:24"
    self.assertIsNotNone(found.search(line))
    self.assertIsNone(conditional.search(line))
    self.assertIsNotNone(conditional.search(line + " (conditional: whether create_referral can run twice at once)"))
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python3 -m unittest discover -s plugins/engineering-review/scripts -p 'test_*.py' -k real_use -k runtime_unknown_race`
Expected: 2 failures. The first is an assertion on the missing lead. The second is a `FileNotFoundError` on `race-confirmed.md`.

- [ ] **Step 3: Write the skill text**

- **Confirmation rule:** add a bullet after "Needs no confirmation": `- **Real use is a given, not an assumption:** many people use the app at once, the same person acts twice, different people act on a shared record, jobs run again after a failure, events and webhooks arrive more than once. A finding that needs only this is confirmed; only a guarantee in the code clears it, and the finding or verdict names it. An answer such as "it runs once per click" does not clear it.` In "Needs confirmation", change "how the code runs" to "how the code runs beyond real use".
- **Schema:** `runtime: ["<fact>", ...] | unknown   # facts the code cannot show; overlap, retries and redelivery are given`.
- **Checkpoint 2, item 4:** `**How the code runs**, only what the code cannot show: "Is \`archive_wish/1\` called from outside this repository?". Never ask whether code can run twice at once, is retried or is delivered more than once: real use is a given.`
- **Conditional examples** (companion and passes line 19): use `conditional on whether the mobile app still reads \`title\`` in place of the race example.
- **Agent:** the description becomes `…; assumes real use and asks before assuming anything else; never approves.` The bullet becomes `You ask instead of assuming — except real use: many people at once, retries and repeat deliveries are given. Whenever any other fact needs confirming, …`.
- **Pass 6 Purpose:** `Find what breaks when two things happen at once, when a step fails halfway, or when work runs twice. Judge every path against real use (the confirmation rule in \`review-companion\`): a finding that needs only overlap, a retry or a repeat delivery is confirmed; only a guarantee in the code clears it — job uniqueness, retries turned off, an idempotency key or claim row, a lock taken earlier, a unique constraint, one conditional statement — and the finding or verdict names it. A finding that depends on any other unconfirmed fact is conditional on it.`
- **Concurrency item 1:** drop the sentence from "but whether that can happen is a runtime fact" to the end. In its place write: `A second request arrives at the same moment, from the same person or from another one on a shared record: the finding is confirmed.`
- **Concurrency item 2:** append `— all given; confirmed unless the code guarantees a single run.`
- **Side-effect safety item 3:** append `— a retry is given.`
- **Golden:**
  - F-01's status becomes `**Status:** confirmed`.
  - In section 10, "Answers given" drops the runtime quote: `intent confirmed by the reviewer; no incidents or legal constraints known.`
- **Graders:**
  - `race-confirmed.md`: `type: regex`, `pattern: 'F-\d+\W[^\n]*EP-H2'`.
  - `race-not-conditional.md`: `type: regex`, `pattern: 'EP-H2[^\n]*conditional'`, `match: not_contains`.
  - `context-and-runtime.md`: `PASS if the final message asks about context outside the repository (for example incidents, deprecations, legal, compliance or retention limits, migrations in progress) and does not ask whether code can run twice at once, whether a job is retried, or whether an event is delivered more than once.` / `FAIL if the context question is missing, or if it asks any of those three.`

- [ ] **Step 4: Run the tests and the checker**

Run both Global Constraints commands. Then run `rg -n "twice at once" plugins/engineering-review/skills plugins/engineering-review/agents`.
Expected:
- all tests pass, and the checker is clean;
- `rg` shows only the new "Never ask whether code can run twice at once" sentence.

- [ ] **Step 5: Commit**

```bash
git add plugins/engineering-review
git commit -m "feat(engineering-review): races and duplicate work are judged against real use, not asked about"
```

---

### Task 4: Pass 6 hunts every deadlock, and checkpoint 3 states the verdict

**Files:**
- Modify: `plugins/engineering-review/skills/review-passes/SKILL.md`:
  - pass 6: replace **Concurrency** item 5 ("Lock order …") with `5. Deadlocks: the block below.`;
  - add a **Deadlocks.** block after **Concurrency**;
  - add a **Report.** line at the end of pass 6.
- Modify: `plugins/engineering-review/skills/review-companion/SKILL.md`: checkpoint 3 gets a new item 2, and items 2–3 become 3–4 (lines 176–185).
- Modify: `plugins/engineering-review/skills/review-report/SKILL.md`:
  - "Chat summary": a new item 4, with items 4–7 renumbered to 5–8;
  - "Which diagram for which finding": a new row.
- Create: `plugins/engineering-review/evals/clean-change/graders/no-lock-verdict.md`
- Test: `plugins/engineering-review/scripts/test_check_plugin.py` (`SkillContentTest`)

**Interfaces:**
- Consumes:
  - EP-H6, EP-H9 and EP-H11–H13 (Task 1);
  - `LOCKS_TABLE_HEADER`, `NO_LOCK_LINE` and section 8 (Task 2);
  - the real-use assumption (Task 3).
- Produces: the behaviour that Task 5's graders check: the deadlock finding lines at checkpoint 3, and the `**Locks and deadlocks.**` item.

- [ ] **Step 1: Write the failing tests**

```python
def test_deadlocks_are_hunted_across_the_repository(self):
    passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")
    block = passes.split("**Deadlocks.**", 1)[1].split("**Transactions.**", 1)[0]

    for item in ("Several rows locked in no fixed order", "Tables locked in opposite orders", "Lock upgrades",
                 "Locks the database takes silently", "Unique-index waits", "Advisory or application locks",
                 "Migrations", "A transaction holding a lock waits on another worker", "Pool exhaustion",
                 "Workers waiting on each other in a cycle", "A row every user locks"):
        self.assertIn(f"**{item}**", block)
    for text in ("Search the whole repository", "each path with itself included", "existed before this change",
                 "flag an implicit lock only where that engine takes one that blocks", "conditional on the database",
                 "A retry on a detected deadlock is a fallback, never the fix", "No concrete pair, no finding"):
        self.assertIn(text, block)
    self.assertIn("**Report.** Section 8", passes)

def test_checkpoint_3_and_the_chat_summary_state_the_deadlock_verdict(self):
    companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
    report = (PLUGIN_DIR / "skills" / "review-report" / "SKILL.md").read_text(encoding="utf-8")
    checkpoint = companion.split("### ③ Checkpoint 3 — before anything is written`", 1)[1].split("\n## ", 1)[0]

    self.assertIn("2. **Locks and deadlocks.**", checkpoint)
    self.assertIn(check_plugin.NO_LOCK_LINE, checkpoint)
    self.assertIn("4. **Approvals,**", checkpoint)
    self.assertIn("the locks and deadlocks line", report.split("## Chat summary", 1)[1])
    self.assertIn("| Deadlock, or a wait the database cannot see |", report)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python3 -m unittest discover -s plugins/engineering-review/scripts -p 'test_*.py' -k deadlocks_are_hunted -k deadlock_verdict`
Expected: 2 failures (an `IndexError` on the missing `**Deadlocks.**` block, and the missing checkpoint item).

- [ ] **Step 3: Write the pass 6 block**

The **Deadlocks.** block opens with a purpose sentence. It then has two numbered parts, written from the spec's sections "How the reviewer works" and "What counts as a deadlock", with each catalogue item's label in bold exactly as the test lists them:

- the procedure, steps 1–7 from the spec, with this wording:
  - "Search the whole repository";
  - "each path with itself included";
  - "No concrete pair, no finding";
  - "existed before this change";
  - "A retry on a detected deadlock is a fallback, never the fix";
- the catalogue, items 1–11, citing:
  - EP-H6 on items 1–3, 6 and 7;
  - EP-H11 on items 4 and 5;
  - EP-H12 and EP-H9 on items 8–10;
  - EP-H13 on item 11.

Item 4 carries the engine rule: `Read which database the repository uses — its config, adapter or migrations, as pass 7 does — and flag an implicit lock only where that engine takes one that blocks: on MySQL a foreign-key check blocks a later write to the parent; on PostgreSQL it does not, unless the write changes the parent's key. When the engine cannot be read, the finding is conditional on the database. Always name the fix that holds everywhere: lock the parent first.`

Severity: a deadlock or an invisible wait is 🔴. A hot row is 🟠, or is folded into the 🔴 finding it makes likely. Each finding carries the `sequenceDiagram` of the two paths blocking each other. The **Report.** line reads: `**Report.** Section 8, Locks and deadlocks: one row per path compared, with its verdict — \`Can't deadlock: <why>\` or the finding's ID — or the no-lock line; and checkpoint 3's **Locks and deadlocks.** item.`

- [ ] **Step 4: Write checkpoint 3, the chat summary and the diagram row**

- **Checkpoint 3, item 2:** `**Locks and deadlocks.** One line per path compared, with its verdict — \`Can't deadlock: <why>\` or the finding's ID, and \`existed before this change\` where it applies — or \`The change takes no lock and waits on nothing while holding one.\`` Renumber Questions to 3 and Approvals to 4.
- **Chat summary, item 4:** `the locks and deadlocks line: the paths compared and the deadlock findings ("Locks and deadlocks: 3 paths compared — F-02 can deadlock; 2 can't"), or the no-lock line;`
- **Diagram row:** `| Deadlock, or a wait the database cannot see | \`sequenceDiagram\`: the two paths side by side, each holding one lock and waiting for the other's |`
- **`no-lock-verdict.md`:** `type: regex`, `pattern: 'takes no lock and waits on nothing while holding one'`.

- [ ] **Step 5: Run the tests and the checker**

Run both Global Constraints commands.
Expected: all tests pass. The checker is clean, so every cited EP-H ID is defined.

- [ ] **Step 6: Commit**

```bash
git add plugins/engineering-review
git commit -m "feat(engineering-review): pass 6 hunts every deadlock across the repository and checkpoint 3 states the verdict"
```

---

### Task 5: Deadlock recall and precision evals

**Files:**
- Create the fixture `plugins/engineering-review/evals/_fixtures/orders-python/` (Python, MySQL):
  - `base/app/database.py`: `DATABASE_URL = "mysql+pymysql://app@localhost/shop"`, an engine with `pool_size=5`, and `connect()`;
  - `base/shop/db.py`: `transaction()`, as in billing-python;
  - `base/shop/schema.sql`: `orders`, `products`, and `order_lines` with `order_id` referencing `orders(id)`;
  - `base/shop/orders.py`:
    - `cancel_order(order_id)` locks the order row (`SELECT … FOR UPDATE`), then updates each line's product stock;
    - `restock(shipment)` updates product stock in shipment order, unsorted;
  - `base/docs/orders.md`;
  - `change/shop/orders.py` adds `place_order(order_id, cart)`. In one transaction it:
    - locks each cart product `FOR UPDATE` in cart order and decrements its stock;
    - calls `pricing.refresh_prices(product_ids)`;
    - inserts an `order_lines` row for each item;
    - updates `orders.total`;
  - `change/shop/pricing.py` adds `refresh_prices(product_ids)`. It submits `_refresh(product_id)` to a `ThreadPoolExecutor` and waits on `.result()`. `_refresh` opens its own `connect()` and updates that product's price;
  - `change/docs/orders.md` documents `place_order`.
- Create the fixture `plugins/engineering-review/evals/_fixtures/ledger-elixir/` (Elixir, PostgreSQL):
  - `base/lib/app/repo.ex` (the Postgres adapter), `base/lib/app/ledger/account.ex` and `base/lib/app/ledger/entry.ex` (with `belongs_to :account`), `base/docs/ledger.md`;
  - the change adds `App.Ledger.transfer/3` and `App.Ledger.record_entry/2`, with tests and the docs update:
    - `transfer/3` locks both accounts in one query, ordered by id with `lock: "FOR UPDATE"`, then moves the cents with conditional updates;
    - `record_entry/2` inserts an entry, then runs `update_all(inc: [entry_count: 1])` on its account.
- Create the case `plugins/engineering-review/evals/deadlocks-recall/`: `case.yaml`, `prompt.md`, `scaffold.sh` (fixture `orders-python`), and `graders/`:
  - `stopped-at-checkpoint-3.md`
  - `no-reviews-dir.md`
  - `unsorted-product-locks.md`
  - `opposite-order-with-cancel.md`
  - `foreign-key-lock-on-mysql.md`
  - `wait-on-worker.md`
  - `pre-existing-restock.md`
  - `deadlocks-confirmed.md`
  - `verdict-listed.md`
- Create the case `plugins/engineering-review/evals/deadlocks-clean/`: `case.yaml`, `prompt.md`, `scaffold.sh` (fixture `ledger-elixir`), and `graders/`:
  - `stopped-at-checkpoint-3.md`
  - `no-deadlock-finding.md`
  - `verdict-says-why.md`
- Test: `plugins/engineering-review/scripts/test_check_plugin.py` (`EvalGraderTest`)

**Interfaces:**
- Consumes: Task 4's checkpoint 3 line formats.
- Produces: the two cases that Task 6 lists in `evals/README.md`.

- [ ] **Step 1: Write the failing grader tests**

```python
def test_deadlock_graders_tell_deadlocks_from_other_concurrency_findings(self):
    confirmed = self.grader_pattern("deadlocks-recall", "deadlocks-confirmed")
    clean = self.grader_pattern("deadlocks-clean", "no-deadlock-finding")

    self.assertIsNotNone(confirmed.search("F-02 🔴 [EP-H6] Two orders lock the same products in opposite orders — shop/orders.py:14 (conditional: whether two orders overlap)"))
    self.assertIsNone(confirmed.search("F-02 🔴 [EP-H6] Two orders lock the same products in opposite orders — shop/orders.py:14"))
    self.assertIsNotNone(clean.search("F-01 🔴 [EP-H6, EP-H11] Two transfers deadlock — lib/app/ledger.ex:12"))
    self.assertIsNone(clean.search("F-01 🟡 [EP-H2] A race on the balance — lib/app/ledger.ex:12"))
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 -m unittest discover -s plugins/engineering-review/scripts -p 'test_*.py' -k deadlock_graders`
Expected: FAIL with `FileNotFoundError` on `deadlocks-confirmed.md`.

- [ ] **Step 3: Write the fixtures and the cases**

**Fixtures.**
- Each fixture is the smallest code that holds its situations, with English names and no comment that hints at a deadlock.
- In `orders-python`, put `cancel_order` and `restock` only in `base/`, so the diff does not touch them.
- In `ledger-elixir`, the tests and docs cover every branch. That way a 🔴 or 🟠 finding outside concurrency is a real precision miss.

**Prompts.**
- Copy `clean-change/prompt.md`'s frontmatter and answer block, then change these:
  - `tags: [recall]` / `[precision]`;
  - each case's own `intent`;
  - `runtime: unknown`;
  - `effects: intended`.
- No `writes`, so the run stops at checkpoint 3.
- **deadlocks-recall** intent: "Customers place an order: stock is reserved, prices are refreshed, and the order's lines and total are written."
- **deadlocks-clean** intent: "Members transfer cents between their accounts, and every ledger entry counts towards its account's entry count."

**`deadlocks-recall` graders:**
- `deadlocks-confirmed`: `type: regex`, `pattern: 'EP-H(6|11|12)[^\n]*conditional'`, `match: not_contains`.
- `stopped-at-checkpoint-3` and `no-reviews-dir`: copy them from `referrals-recall`.
- The llm graders each pass only on a finding at checkpoint 3 that names:
  - `unsorted-product-locks`: `place_order` locking products in cart order, so two orders deadlock;
  - `opposite-order-with-cancel`: `place_order` (products, then the order) against `cancel_order` (the order, then products);
  - `foreign-key-lock-on-mysql`: inserting `order_lines` and then updating `orders.total` deadlocking on MySQL through the foreign-key lock;
  - `wait-on-worker`: `place_order` waiting on `refresh_prices`' worker, which needs the product rows held by the caller through another connection;
  - `pre-existing-restock`: `restock` deadlocking, marked `existed before this change`;
  - `verdict-listed`: the `**Locks and deadlocks.**` item lists `place_order` with its finding IDs.

**`deadlocks-clean` graders:**
- `no-deadlock-finding`: `type: regex`, `pattern: 'F-\d+\W[^\n]*EP-H(6|11|12)'`, `match: not_contains`.
- `stopped-at-checkpoint-3`: copy it from `referrals-recall`.
- `verdict-says-why`: an llm grader. It passes only when the `**Locks and deadlocks.**` item gives `transfer/3` and `record_entry/2` as `Can't deadlock:`, each with its reason: the sorted lock taken up front, and PostgreSQL's foreign-key lock not blocking the counter update.

- [ ] **Step 4: Run the tests, the checker and the fixtures**

Run:
- both Global Constraints commands;
- for each new case, `bash plugins/engineering-review/evals/<case>/scaffold.sh` from a scratch directory, then `git -C <dir> diff --stat main feature`.

Expected:
- all tests pass;
- the checker is clean;
- each fixture builds a repository, and its diff shows only the `change/` files.

- [ ] **Step 5: Commit**

```bash
git add plugins/engineering-review/evals plugins/engineering-review/scripts/test_check_plugin.py
git commit -m "feat(engineering-review): deadlock recall and precision evals"
```

---

### Task 6: Release 0.9.0 and the PR

**Files:**
- Modify: `plugins/engineering-review/.claude-plugin/plugin.json` (`"version": "0.9.0"`)
- Modify: `.claude-plugin/marketplace.json` (the engineering-review entry: `"version": "0.9.0"`)
- Modify: `plugins/engineering-review/evals/README.md`:
  - results rows for `deadlocks-clean` and `deadlocks-recall`, kept in alphabetical order;
  - the `referrals-runtime-unknown`, `gate-checkpoint-2` and `clean-change` rows, reset to `not measured` unless they are re-run;
  - a `v0.9.0 (2026-10-21)` release note at the end.
- Test: `plugins/engineering-review/scripts/test_check_plugin.py` (`SkillContentTest`)

- [ ] **Step 1: Write the failing test**

```python
def test_release_note_says_real_use_is_a_given(self):
    readme = (PLUGIN_DIR / "evals" / "README.md").read_text(encoding="utf-8")
    note = readme.split("v0.9.0 (2026-10-21):", 1)[1]

    for text in ("real use", "Locks and deadlocks", "deadlocks-recall", "deadlocks-clean"):
        self.assertIn(text, note)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 -m unittest discover -s plugins/engineering-review/scripts -p 'test_*.py' -k real_use_is_a_given`
Expected: FAIL with `IndexError`.

- [ ] **Step 3: Bump the version and write the release note**

The note covers four things in the README's existing style:
- what changed: real use is a given, pass 6 hunts the catalogue across the repository, and every review states a deadlock verdict;
- the renumbered sections;
- the eval changes;
- which cases were measured.

- [ ] **Step 4: Run the evals, or record why not**

Ask the person which way to lift the sandbox (see Global Constraints). If they choose one, run:
- `deadlocks-recall`, `deadlocks-clean`, `clean-change`, `referrals-runtime-unknown`, `gate-checkpoint-2`, `billing-recall`, `secret-checkpoint-3` and `wishes-recall`;
- one of the cases that pre-answers "once per click".

Use `--runs 3 --threshold 0.67` with the README's flags, and record each result in its row. If they choose neither, mark those rows `not measured` and say so in the note.

- [ ] **Step 5: Run the tests and the checker, then commit**

Run both Global Constraints commands.
Expected: all pass.

```bash
git add .claude-plugin/marketplace.json plugins/engineering-review
git commit -m "chore: release engineering-review 0.9.0"
```

- [ ] **Step 6: Open the PR**

Push `feat/deadlock-review` and run `gh pr create`.
- Title: `Deadlock-proof review: real use is a given, every review states its deadlock verdict`.
- Description: follow EP-F5 and `engineering-review:pr-description`, loaded when it is written.
  - **How it works:** a `flowchart` of pass 6's deadlock procedure (find paths → lock sequences → repository-wide search → pairwise compare → verdict).
  - **Behind the scenes:** "none: skill text, the report checker and evals only".
- End with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
