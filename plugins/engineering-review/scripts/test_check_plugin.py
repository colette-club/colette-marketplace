import io
import json
import re
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import check_plugin

VALID_SKILL = """---
name: demo-skill
description: Demonstrates the validator. Use when testing it.
---

# Demo

Read the diff, then read [the pass](passes/one.md).
"""


def write(path: Path, text: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def build_plugin(root: Path, plugin_version="0.1.0", marketplace_version="0.1.0", skill_text=VALID_SKILL) -> Path:
    plugin_dir = root / "plugins" / "demo"
    write(
        plugin_dir / ".claude-plugin" / "plugin.json",
        json.dumps({"name": "demo", "version": plugin_version}),
    )
    write(
        root / ".claude-plugin" / "marketplace.json",
        json.dumps(
            {
                "name": "market",
                "owner": {"name": "Team"},
                "plugins": [{"name": "demo", "source": "./plugins/demo", "version": marketplace_version}],
            }
        ),
    )
    write(plugin_dir / "skills" / "demo-skill" / "SKILL.md", skill_text)
    write(plugin_dir / "skills" / "demo-skill" / "passes" / "one.md", "# One\n")
    return plugin_dir


class ParseFrontmatterTest(unittest.TestCase):
    def test_frontmatter_parses_scalars_and_lists(self):
        text = "---\nname: agent\ndescription: Does things\nskills:\n  - a\n  - b\n---\nBody\n"

        self.assertEqual(
            check_plugin.parse_frontmatter(text),
            {"name": "agent", "description": "Does things", "skills": ["a", "b"]},
        )

    def test_frontmatter_missing_raises(self):
        with self.assertRaises(ValueError):
            check_plugin.parse_frontmatter("# No frontmatter\n")


class CheckSkillTest(unittest.TestCase):
    def test_skill_rejects_non_standard_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            skill_dir = Path(tmp) / "demo-skill"
            write(skill_dir / "SKILL.md", "---\nname: demo-skill\ndescription: Demo\nargument-hint: x\n---\nBody\n")

            errors = check_plugin.check_skill(skill_dir)

        self.assertEqual(len(errors), 1)
        self.assertIn("argument-hint", errors[0])

    def test_skill_name_must_match_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            skill_dir = Path(tmp) / "demo-skill"
            write(skill_dir / "SKILL.md", "---\nname: other-name\ndescription: Demo\n---\nBody\n")

            errors = check_plugin.check_skill(skill_dir)

        self.assertEqual(len(errors), 1)
        self.assertIn("other-name", errors[0])

    def test_tool_names_only_under_runtime_notes(self):
        with tempfile.TemporaryDirectory() as tmp:
            before = Path(tmp) / "before-skill"
            write(before / "SKILL.md", "---\nname: before-skill\ndescription: Demo\n---\nAsk with AskUserQuestion.\n")
            after = Path(tmp) / "after-skill"
            write(
                after / "SKILL.md",
                "---\nname: after-skill\ndescription: Demo\n---\nRead the diff.\n\n## Runtime notes\n\nUse AskUserQuestion.\n",
            )

            before_errors = check_plugin.check_skill(before)
            after_errors = check_plugin.check_skill(after)

        self.assertEqual(len(before_errors), 1)
        self.assertIn("AskUserQuestion", before_errors[0])
        self.assertEqual(after_errors, [])


def description_errors(description):
    with tempfile.TemporaryDirectory() as tmp:
        skill_md = write(Path(tmp) / "demo-skill" / "SKILL.md", f"---\nname: demo-skill\ndescription: {description}\n---\nBody\n")
        return check_plugin.check_description_style(skill_md)


class DescriptionStyleTest(unittest.TestCase):
    def test_description_says_what_then_when(self):
        self.assertEqual(description_errors("Checks invoices against orders. Use when reconciling billing."), [])

    def test_description_must_open_with_what_the_skill_does(self):
        for opener in ("Use when reconciling billing. Checks invoices.", "You can check invoices when billing."):
            errors = description_errors(opener)

            self.assertEqual(len(errors), 1, opener)
            self.assertIn("third person", errors[0])

    def test_description_must_say_when_to_use_it(self):
        errors = description_errors("Checks invoices against orders.")

        self.assertEqual(len(errors), 1)
        self.assertIn("when", errors[0])

    def test_description_length_and_tags(self):
        long_errors = description_errors("Checks invoices. Use when billing. " + "x" * 1024)
        tag_errors = description_errors("Checks <invoice> files. Use when billing.")

        self.assertEqual(len(long_errors), 1)
        self.assertIn("1024", long_errors[0])
        self.assertEqual(len(tag_errors), 1)
        self.assertIn("tag", tag_errors[0])


def reference_errors(text):
    with tempfile.TemporaryDirectory() as tmp:
        md = write(Path(tmp) / "demo-skill" / "reference.md", text)
        return check_plugin.check_table_of_contents(md)


LONG_SECTIONS = "".join(f"## {letter}. Group {letter} (EP-{letter}1–{letter}3)\n\n" + "text\n" * 12 for letter in "ABCDEFGHI")


class TableOfContentsTest(unittest.TestCase):
    def test_long_reference_needs_contents(self):
        errors = reference_errors("# Examples\n\n" + LONG_SECTIONS)

        self.assertEqual(len(errors), 1)
        self.assertIn("table of contents", errors[0])

    def test_contents_links_every_section_by_its_anchor(self):
        contents = "## Contents\n\n" + "".join(
            f"- [{letter}. Group {letter}](#{letter.lower()}-group-{letter.lower()}-ep-{letter.lower()}1{letter.lower()}3)\n"
            for letter in "ABCDEFGHI"
        )

        self.assertEqual(reference_errors("# Examples\n\n" + contents + "\n" + LONG_SECTIONS), [])

    def test_contents_with_a_broken_or_missing_link_is_error(self):
        contents = "## Contents\n\n- [A. Group A](#no-such-section)\n"

        errors = reference_errors("# Examples\n\n" + contents + "\n" + LONG_SECTIONS)

        self.assertTrue(any("#no-such-section" in error for error in errors))
        self.assertTrue(any("'B. Group B (EP-B1–B3)'" in error for error in errors))

    def test_short_reference_needs_no_contents(self):
        self.assertEqual(reference_errors("# Examples\n\n## A. Names\n\ntext\n"), [])


class CheckReferencesTest(unittest.TestCase):
    def test_reference_to_missing_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            skill_dir = Path(tmp) / "demo-skill"
            md = write(skill_dir / "SKILL.md", "See [missing](passes/missing.md) and `docs/README.md`.\n")

            errors = check_plugin.check_references(md, skill_dir)

        self.assertEqual(len(errors), 1)
        self.assertIn("passes/missing.md", errors[0])


class CheckManifestsTest(unittest.TestCase):
    def test_manifest_version_mismatch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            plugin_dir = build_plugin(root, plugin_version="0.1.0", marketplace_version="0.2.0")

            errors = check_plugin.check_manifests(root, plugin_dir)

        self.assertEqual(len(errors), 1)
        self.assertIn("0.2.0", errors[0])


PLUGIN_DIR = Path(__file__).resolve().parent.parent

TABLE_RULE_IDS = (
    {"EP-0"}
    | {f"EP-A{n}" for n in range(1, 6)}
    | {f"EP-B{n}" for n in range(1, 8)}
    | {f"EP-C{n}" for n in range(1, 5)}
    | {f"EP-D{n}" for n in range(1, 14)}
    | {f"EP-E{n}" for n in range(1, 7)}
    | {f"EP-F{n}" for n in range(1, 6)}
    | {f"EP-G{n}" for n in range(1, 7)}
    | {f"EP-H{n}" for n in range(1, 15)}
    | {f"EP-I{n}" for n in range(1, 8)}
    | {f"EP-J{n}" for n in range(1, 19)}
    | {f"EP-K{n}" for n in range(1, 12)}
)


class RuleIdsTest(unittest.TestCase):
    def test_defined_rule_ids_parses_list_items(self):
        with tempfile.TemporaryDirectory() as tmp:
            md = write(
                Path(tmp) / "SKILL.md",
                "- **EP-0** — English only.\n- **EP-H2** — No races.\nSee EP-K1 in prose.\n",
            )

            self.assertEqual(check_plugin.defined_rule_ids(md), {"EP-0", "EP-H2"})

    def test_undefined_citation_is_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            plugin_dir = build_plugin(root)
            write(
                plugin_dir / "skills" / "engineering-principles" / "SKILL.md",
                "---\nname: engineering-principles\ndescription: Demo\n---\n- **EP-H2** — No races.\n",
            )
            write(plugin_dir / "skills" / "demo-skill" / "passes" / "one.md", "Cites EP-H2 and EP-Z9.\n")

            errors = check_plugin.check_rule_ids(plugin_dir)

        self.assertEqual(len(errors), 1)
        self.assertIn("EP-Z9", errors[0])

    def test_malformed_rule_id_is_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            plugin_dir = build_plugin(root)
            write(
                plugin_dir / "skills" / "engineering-principles" / "SKILL.md",
                "---\nname: engineering-principles\ndescription: Demo\n---\n- **EP-H2** — No races.\n",
            )
            write(plugin_dir / "skills" / "demo-skill" / "passes" / "one.md", "Cites EP-01, EP-h2 and EP-H.\n")

            errors = check_plugin.check_rule_ids(plugin_dir)

        self.assertEqual(len(errors), 3)
        for token in ("EP-01", "EP-h2", "EP-H"):
            self.assertTrue(any(f"'{token}'" in error for error in errors), token)

    def test_placeholder_and_grader_patterns_are_not_rule_ids(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            plugin_dir = build_plugin(root)
            write(
                plugin_dir / "skills" / "engineering-principles" / "SKILL.md",
                "---\nname: engineering-principles\ndescription: Demo\n---\n- **EP-F3** — Docs ship.\n",
            )
            write(plugin_dir / "skills" / "demo-skill" / "passes" / "one.md", "**Rules:** `<EP-XN>`\n")
            write(plugin_dir / "evals" / "case" / "graders" / "docs.md", "---\ntype: regex\npattern: 'EP-F[34]'\n---\n")

            self.assertEqual(check_plugin.check_rule_ids(plugin_dir), [])

    def test_all_table_ids_defined(self):
        principles = PLUGIN_DIR / "skills" / "engineering-principles" / "SKILL.md"

        self.assertEqual(len(TABLE_RULE_IDS), 97)
        self.assertEqual(check_plugin.defined_rule_ids(principles), TABLE_RULE_IDS)


REPORT_SECTIONS = [
    "## 1. Summary",
    "## 2. ⚡ Side effects set in motion",
    "## 3. The change at a glance",
    "## 4. Findings",
    "## 5. Tests",
    "## 6. Documentation",
    "## 7. Data access & performance",
    "## 8. Locks and deadlocks",
    "## 9. Risk and attention map",
    "## 10. Conversation",
    "## 11. Recommended plan",
    "## 12. Limits and decision",
]

CARD = """### F-01 🔴 Two requests can both spend the last invite
**Pass:** Concurrency · **Rules:** `EP-H2` · **Where:** `lib/app/referrals.ex:42` · **Status:** confirmed

**What.** Reads then writes the counter.

**Why it matters.** Both requests read 1.

**Evidence.** `n = read(invites); write(invites, n - 1)`

**Recommendation.**
1. Use one conditional update.

**Effort:** small.
"""


HEADER = """| | |
|---|---|
| Target | `feature` compared with `main` at `3f9c2a1` |
| Date | 2026-09-30 |
| Role of the person asked | reviewer |
| Stack and skills applied | Elixir — engineering-principles |
| Commands run | none |
| Previous report | none found |

> This report supports a human review. It does not approve or reject anything; the decision to merge belongs to the reviewer.
"""


DONE_TABLE = """**Definition of done**

| Criterion | Findings |
|---|---|
| Implemented | none found |
| Tested | none found |
| Properly designed | F-01 |
| Follows the conventions | none found |
| Deployable without hurting users | none found |
| Consumers stated | none found — no frontend or app must change |
"""


SKILLS_TABLE = """**Skills applied**

| Skill | Covers | Applied to | Findings |
|---|---|---|---|
| engineering-principles | every language | all changed files | F-01 |
"""


LOCKS_TABLE = """| Path | Locks and waits, in order | Same locks taken elsewhere | Verdict |
|---|---|---|---|
| `create_referral` | user row (write) | `close_account`: user row | Can't deadlock: both take the user row first |
"""


def report_text(sections=REPORT_SECTIONS, card=CARD, extra="", header=HEADER, closing="\nThe decision to merge is yours.\n",
                skills_table=SKILLS_TABLE, done_table=DONE_TABLE, locks=LOCKS_TABLE):
    parts = ["# Review — feature", "", header]
    for heading in sections:
        parts += [heading, ""]
        if heading == "## 1. Summary":
            parts += [done_table, ""]
        if heading == "## 3. The change at a glance":
            parts += [skills_table, ""]
        if heading == "## 4. Findings":
            parts += [card, ""]
        if heading == "## 8. Locks and deadlocks":
            parts += [locks, ""]
    return "\n".join(parts) + extra + closing


class MermaidTest(unittest.TestCase):
    def test_mermaid_unknown_type_is_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "doc.md", "```mermaid\ngantt\n  title Plan\n```\n")

            errors = check_plugin.check_mermaid_blocks(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("gantt", errors[0])

    def test_mermaid_safe_types_ok(self):
        blocks = "".join(
            f"```mermaid\n{kind}\n  A\n```\n"
            for kind in ["flowchart LR", "sequenceDiagram", "erDiagram", "stateDiagram-v2", "classDiagram", "quadrantChart"]
        )
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "doc.md", blocks)

            self.assertEqual(check_plugin.check_mermaid_blocks(md), [])


class ReportTest(unittest.TestCase):
    def test_report_ok(self):
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text())

            self.assertEqual(check_plugin.check_report(md), [])

    def test_report_missing_section(self):
        sections = [s for s in REPORT_SECTIONS if s != "## 6. Documentation"]
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(sections=sections))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("## 6. Documentation", errors[0])

    def test_report_sections_out_of_order(self):
        sections = list(REPORT_SECTIONS)
        sections[4], sections[5] = sections[5], sections[4]
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(sections=sections))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("order", errors[0])

    def test_card_missing_recommendation(self):
        card = CARD.replace("**Recommendation.**\n1. Use one conditional update.\n", "")
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(card=card))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("**Recommendation.**", errors[0])

    def test_card_missing_evidence(self):
        card = CARD.replace("**Evidence.** `n = read(invites); write(invites, n - 1)`\n", "")
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(card=card))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("**Evidence.**", errors[0])

    def test_report_verdict_phrase(self):
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(extra="\nLGTM, ship it.\n"))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("verdict", errors[0])

    def test_report_ready_to_merge_is_a_verdict(self):
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(extra="\nThis change is ready to merge.\n"))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("verdict", errors[0])

    def test_ship_it_inside_a_sentence_is_not_a_verdict(self):
        extra = "\n- [ ] Can wait: F-05 — the docs update (small, but ship it with the change).\n"
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(extra=extra))

            self.assertEqual(check_plugin.check_report(md), [])

    def test_ship_it_as_a_verdict_is_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(extra="\nLooks good. Ship it!\n"))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("verdict", errors[0])

    def test_headings_inside_code_fences_are_ignored(self):
        card = CARD.replace(
            "**Why it matters.**",
            "**Evidence.**\n```markdown\n## What it does\n## 1. Summary\n```\n\n**Why it matters.**",
        )
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(card=card))

            self.assertEqual(check_plugin.check_report(md), [])

    def test_report_header_rows_required(self):
        header = HEADER.replace("| Previous report | none found |\n", "").replace("| Commands run | none |\n", "")
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(header=header))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 2)
        self.assertTrue(any("Commands run" in error for error in errors))
        self.assertTrue(any("Previous report" in error for error in errors))

    def test_report_needs_the_skills_applied_table(self):
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(skills_table=""))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("Skills applied", errors[0])

    def test_skills_table_needs_a_populated_row(self):
        table = "**Skills applied**\n\n| Skill | Covers | Applied to | Findings |\n|---|---|---|---|\n"
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(skills_table=table))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("no skill rows", errors[0])

    def test_skills_table_needs_every_column(self):
        table = "**Skills applied**\n\n| Skill | Findings |\n|---|---|\n| engineering-principles | F-01 |\n"
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(skills_table=table))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("Covers", errors[0])
        self.assertIn("Applied to", errors[0])

    def test_report_needs_the_definition_of_done_table(self):
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(done_table=""))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("Definition of done", errors[0])

    def test_report_definition_of_done_needs_every_criterion(self):
        done_table = DONE_TABLE.replace("| Consumers stated | none found — no frontend or app must change |\n", "")
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(done_table=done_table))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("Consumers stated", errors[0])

    def test_report_disclaimer_required(self):
        header = HEADER.replace("> This report supports a human review.", "> A review.")
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(header=header))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("disclaimer", errors[0])

    def test_report_closing_line_required(self):
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(closing="\nThanks for reading.\n"))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("The decision to merge is yours.", errors[0])

    def test_report_unlabelled_sql_block_is_error(self):
        block = "```sql\nDELETE FROM listings;\n```\n"
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(extra="\n" + block))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("-- engine:", errors[0])

    def test_report_sql_blocks_are_checked(self):
        block = PG_BLOCK.replace("ROLLBACK;\n", "")
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(extra="\n" + block))

            errors = check_plugin.check_report(md)

        self.assertEqual(len(errors), 1)
        self.assertIn("ROLLBACK", errors[0])

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

    def test_golden_report_passes(self):
        golden = PLUGIN_DIR / "evals" / "_golden" / "example-report.md"

        self.assertEqual(check_plugin.check_report(golden), [])


PG_BLOCK = """```sql
-- engine: postgresql
-- review-companion · read-only · safe on production
BEGIN TRANSACTION READ ONLY;
SET LOCAL statement_timeout = '5s';
SET LOCAL idle_in_transaction_session_timeout = '30s';
SELECT relname, n_live_tup FROM pg_stat_user_tables WHERE relname IN ('listings');
EXPLAIN (GENERIC_PLAN) SELECT * FROM listings WHERE city_id = $1;
ROLLBACK;
```
"""


def sql_errors(text):
    with tempfile.TemporaryDirectory() as tmp:
        md = write(Path(tmp) / "queries.md", text)
        return check_plugin.check_sql_blocks(md)


class SqlBlocksTest(unittest.TestCase):
    def test_sql_block_ok(self):
        self.assertEqual(sql_errors(PG_BLOCK), [])

    def test_sql_block_must_be_read_only(self):
        errors = sql_errors(PG_BLOCK.replace("BEGIN TRANSACTION READ ONLY;\n", ""))

        self.assertEqual(len(errors), 1)
        self.assertIn("READ ONLY", errors[0])

    def test_postgres_block_needs_idle_transaction_timeout(self):
        errors = sql_errors(PG_BLOCK.replace("SET LOCAL idle_in_transaction_session_timeout = '30s';\n", ""))

        self.assertEqual(len(errors), 1)
        self.assertIn("idle_in_transaction_session_timeout", errors[0])

    def test_sql_block_rejects_explain_analyze(self):
        errors = sql_errors(PG_BLOCK.replace("EXPLAIN (GENERIC_PLAN)", "EXPLAIN (ANALYZE, BUFFERS)"))

        self.assertEqual(len(errors), 1)
        self.assertIn("ANALYZE", errors[0])

    def test_sql_block_rejects_dml(self):
        errors = sql_errors(PG_BLOCK.replace("ROLLBACK;", "DELETE FROM listings;\nROLLBACK;"))

        self.assertEqual(len(errors), 1)
        self.assertIn("DELETE", errors[0].upper())

    def test_sql_block_rejects_count_star(self):
        errors = sql_errors(PG_BLOCK.replace("SELECT relname, n_live_tup", "SELECT count(*)"))

        self.assertEqual(len(errors), 1)
        self.assertIn("count(*)", errors[0])

    def test_sql_block_rejects_most_common_vals(self):
        errors = sql_errors(PG_BLOCK.replace("n_live_tup FROM pg_stat_user_tables", "most_common_vals FROM pg_stats"))

        self.assertEqual(len(errors), 1)
        self.assertIn("most_common_vals", errors[0])

    def test_sql_block_rejects_explain_analyse_spelling(self):
        errors = sql_errors(PG_BLOCK.replace("EXPLAIN (GENERIC_PLAN)", "EXPLAIN ANALYSE"))

        self.assertEqual(len(errors), 1)
        self.assertIn("ANALYSE", errors[0].upper())

    def test_sql_block_rejects_every_value_statistic(self):
        for column in ("histogram_bounds", "most_common_elems", "most_common_elem_freqs"):
            errors = sql_errors(PG_BLOCK.replace("n_live_tup FROM pg_stat_user_tables", f"{column} FROM pg_stats"))

            self.assertEqual(len(errors), 1, column)
            self.assertIn(column, errors[0])

    def test_sql_block_rejects_dml_after_another_statement(self):
        errors = sql_errors(PG_BLOCK.replace("ROLLBACK;", "SELECT 1; DELETE FROM listings;\nROLLBACK;"))

        self.assertEqual(len(errors), 1)
        self.assertIn("DELETE", errors[0].upper())

    def test_sql_block_rejects_data_modifying_cte(self):
        cte = "WITH gone AS (DELETE FROM listings RETURNING id) SELECT id FROM gone;\n"
        errors = sql_errors(PG_BLOCK.replace("ROLLBACK;", cte + "ROLLBACK;"))

        self.assertEqual(len(errors), 1)
        self.assertIn("DELETE", errors[0].upper())

    def test_sql_block_allows_only_timeout_settings(self):
        for statement in ("SET TRANSACTION READ WRITE;", "SET LOCAL default_transaction_read_only = off;", "SET search_path = evil;"):
            errors = sql_errors(PG_BLOCK.replace("ROLLBACK;", statement + "\nROLLBACK;"))

            self.assertEqual(len(errors), 1, statement)
            self.assertIn("SET", errors[0].upper(), statement)

    def test_sql_block_rejects_side_effect_functions(self):
        for call in ("pg_terminate_backend(123)", "set_config('work_mem', '1GB', false)", "pg_sleep(30)", "nextval('invites_id_seq')"):
            errors = sql_errors(PG_BLOCK.replace("ROLLBACK;", f"SELECT {call};\nROLLBACK;"))

            self.assertEqual(len(errors), 1, call)
            self.assertIn(call.split("(")[0], errors[0], call)

    def test_sql_keywords_inside_strings_and_comments_are_ignored(self):
        line = "SELECT relname FROM pg_stat_user_tables WHERE relname = 'delete_log'; -- update this later\n"
        block = PG_BLOCK.replace("ROLLBACK;", line + "/* drop nothing */\nROLLBACK;")

        self.assertEqual(sql_errors(block), [])

    def test_mariadb_block_ok(self):
        text = (
            "```sql\n-- engine: mariadb\nSTART TRANSACTION READ ONLY;\nSET SESSION max_statement_time = 5;\n"
            "SELECT table_name, table_rows FROM information_schema.tables WHERE table_name = 'listings';\n"
            "EXPLAIN SELECT * FROM listings WHERE city_id = 42;\nROLLBACK;\n```\n"
        )

        self.assertEqual(sql_errors(text), [])

    def test_mariadb_block_needs_max_statement_time(self):
        text = "```sql\n-- engine: mariadb\nSTART TRANSACTION READ ONLY;\nSELECT 1;\nROLLBACK;\n```\n"

        errors = sql_errors(text)

        self.assertEqual(len(errors), 1)
        self.assertIn("max_statement_time", errors[0])

    def test_statistics_block_without_engine_marker_is_error(self):
        text = "```sql\nBEGIN TRANSACTION READ ONLY;\nSELECT relname, n_live_tup FROM pg_stat_user_tables;\nROLLBACK;\n```\n"

        errors = sql_errors(text)

        self.assertEqual(len(errors), 1)
        self.assertIn("-- engine:", errors[0])

    def test_unlabelled_sql_block_is_error(self):
        text = "```sql\nCREATE INDEX CONCURRENTLY listings_city_id_index ON listings (city_id);\n```\n"

        errors = sql_errors(text)

        self.assertEqual(len(errors), 1)
        self.assertIn("-- migration", errors[0])

    def test_migration_block_is_not_held_to_read_only_rules(self):
        text = "```sql\n-- migration\nCREATE INDEX CONCURRENTLY listings_city_id_index ON listings (city_id);\n```\n"

        self.assertEqual(sql_errors(text), [])

    def test_mysql_and_sqlite_blocks_ok(self):
        text = (
            "```sql\n-- engine: mysql\nSTART TRANSACTION READ ONLY;\nSET SESSION MAX_EXECUTION_TIME = 5000;\n"
            "SELECT table_name, table_rows FROM information_schema.tables WHERE table_name = 'listings';\nROLLBACK;\n```\n"
            "```sql\n-- engine: sqlite\nPRAGMA query_only = ON;\nSELECT tbl, idx, stat FROM sqlite_stat1 WHERE tbl = 'wishes';\n```\n"
        )

        self.assertEqual(sql_errors(text), [])


AGENT = """---
name: review-companion
description: Supports a human code review.
skills:
  - engineering-principles
  - review-companion
  - review-passes
  - review-report
---
Soul.
"""


class AgentTest(unittest.TestCase):
    def test_agent_ok(self):
        with tempfile.TemporaryDirectory() as tmp:
            agent = write(Path(tmp) / "review-companion.md", AGENT)

            self.assertEqual(check_plugin.check_agent(agent), [])

    def test_agent_must_list_all_review_skills(self):
        with tempfile.TemporaryDirectory() as tmp:
            agent = write(Path(tmp) / "review-companion.md", AGENT.replace("  - review-passes\n", ""))

            errors = check_plugin.check_agent(agent)

        self.assertEqual(len(errors), 1)
        self.assertIn("review-passes", errors[0])

    def test_real_agent_passes(self):
        self.assertEqual(check_plugin.check_agent(PLUGIN_DIR / "agents" / "review-companion.md"), [])


class SkillContentTest(unittest.TestCase):
    def test_language_skills_are_named_with_their_plugin(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("elixir-phoenix-conventions:elixir-phoenix-conventions", companion)
        self.assertIn("flutter-conventions-guide:flutter-conventions-guide", companion)

    def test_no_skill_mentions_retired_supporting_files(self):
        retired = ("diagrams.md", "report-template.md", "passes/", "after checkpoint 2")
        for skill_md in sorted((PLUGIN_DIR / "skills").glob("*/SKILL.md")):
            text = skill_md.read_text(encoding="utf-8")
            for name in retired:
                self.assertNotIn(name, text, f"{skill_md.parent.name} mentions {name}")

    def test_answers_in_advance_cannot_approve_what_nobody_has_seen(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
        schema = companion.split("```yaml\n", 1)[1].split("```", 1)[0]

        self.assertIn("memory: decline,", schema)
        self.assertNotIn("memory: approve", schema)
        self.assertNotIn("memory_still_true: all", schema)
        for permission in ("run_tests", "run_checks", "explain_local_db", "fetch_history", "fetch_pr", "read_pr"):
            self.assertIn(f'{permission}: "<exact command>" | no', schema)
        self.assertNotIn("yes|no", schema)

    def test_check_command_warns_it_may_rewrite_files_and_a_timeout_is_not_a_failure(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
        passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("it may also rewrite files", companion)
        self.assertIn("| The repository's check command times out |", companion)
        self.assertIn("a run that times out is reported as not completed", passes)

    def test_only_the_smallest_increment_of_one_feature_is_reviewed(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("## Not the smallest increment", companion)
        self.assertIn("| More than one feature |", companion)
        self.assertIn("| Part of the change could ship on its own first |", companion)
        retired = ("1,500 changed lines", "propose reviewing by area", "review as is, review part, or stop", "## Too large to review")
        for phrase in retired:
            self.assertNotIn(phrase, companion)

    def test_the_code_file_count_is_a_preference_not_a_limit(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
        principles = (PLUGIN_DIR / "skills" / "engineering-principles" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("above the preferred **20 code files**", companion)
        self.assertIn("the count alone never stops the review", companion)
        self.assertIn("a preference, not a limit", principles)
        for retired in ("Nothing overrides the limit", "the limit is 20", "never exceeds 20", "at most 20 code files (tests"):
            self.assertNotIn(retired, companion + principles)

    def test_report_template_lists_every_definition_of_done_criterion(self):
        report = (PLUGIN_DIR / "skills" / "review-report" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("**Definition of done**", report)
        for criterion in check_plugin.DONE_CRITERIA:
            self.assertIn(f"| {criterion} |", report)

    def test_consumers_are_asked_and_checked(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
        passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("**Consumers.**", companion)
        self.assertIn("**4. Consumers and deploy (EP-E5, EP-I5).**", passes)

    def test_reference_has_examples_in_every_language_for_every_group(self):
        reference = (PLUGIN_DIR / "skills" / "engineering-principles" / "reference.md").read_text(encoding="utf-8")
        groups = [section for section in reference.split("\n## ")[1:] if not section.startswith("Contents")]

        self.assertEqual(len(groups), 11)
        for group in groups:
            title = group.splitlines()[0]
            for fence in ("```\n", "```elixir\n", "```dart\n"):
                self.assertIn(fence, group, f"{title} has no {fence.strip() or 'pseudocode'} example")

    def test_pr_title_and_description_rule_points_to_its_skill(self):
        principles = (PLUGIN_DIR / "skills" / "engineering-principles" / "SKILL.md").read_text(encoding="utf-8")
        rule = next(line for line in principles.splitlines() if line.startswith("- **EP-F5** — "))

        for part in ("title", "what it does", "how it works", "mermaid", "behind the scenes", "screenshots and videos", "`pr-description`"):
            self.assertIn(part, rule.lower())
        self.assertIn("`<feature> (<i>/<n>): <what it delivers>`", rule)
        self.assertIn("→ EP-F5", principles)

    def test_pr_description_skill_fixes_the_title_headings_and_markers(self):
        skill = (PLUGIN_DIR / "skills" / "pr-description" / "SKILL.md").read_text(encoding="utf-8")
        agent = (PLUGIN_DIR / "agents" / "review-companion.md").read_text(encoding="utf-8")

        for text in ("`<feature> (<i>/<n>): <what it delivers>`", "`<feature>: <what it delivers>`",
                     "## What it does", "## How it works", "## Behind the scenes", "## Screenshots and videos",
                     "> **Picture to add:** <screen> — <state>, <before | after>", "> **Video to add:** <flow>",
                     "EP-F5", "EP-E5", "EP-I5", "EP-I3", "elixir #59"):
            self.assertIn(text, skill)
        for section in ("## The title", "## The parts", "## Template", "## Not essential", "## Marked spots", "## A repository's own template"):
            self.assertIn(f"\n{section}\n", skill)
        self.assertIn("  - pr-description\n", agent)

    def test_the_pr_title_and_description_are_read_or_pasted(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
        schema = companion.split("```yaml\n", 1)[1].split("```", 1)[0]

        self.assertIn('pr_title: "<title>"', schema)
        self.assertIn("pr_description: |", schema)
        self.assertIn("`gh pr view <n> --json title,body`", companion)
        self.assertIn("four backticks", companion)
        self.assertIn("`engineering-review:pr-description`", companion)
        self.assertIn("| No PR yet and nothing pasted |", companion)
        self.assertIn("| Reading the PR declined and nothing pasted |", companion)

    def test_the_description_check_runs_in_passes_4_and_6_and_lands_in_section_6(self):
        passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")
        report = (PLUGIN_DIR / "skills" / "review-report" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("**5. The PR title and description (EP-F5).**", passes)
        self.assertIn("**PR description, behind the scenes (EP-F5).**", passes)
        self.assertIn("**PR description**", report)
        self.assertIn("| Part | Status | Findings |", report)
        for part in ("Title", "What it does", "How it works", "Behind the scenes", "Screenshots and videos", "Not essential"):
            self.assertIn(f"| {part} |", report)
        self.assertIn("no PR description yet", report)

    def test_a_pasted_description_is_always_checked_and_reaches_pass_6(self):
        passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("A pasted description is always checked, with a PR or without one.", passes)
        self.assertIn("When a description was read or pasted", passes)
        self.assertIn("only the guarantees that apply", passes)

    def test_a_description_finding_card_points_to_the_pr_not_a_line(self):
        report = (PLUGIN_DIR / "skills" / "review-report" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("**Where:** is `PR title` or `PR description`", report)
        self.assertIn("the rewritten passage", report)

    def test_one_gap_in_the_description_is_one_finding(self):
        passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("One that only the PR description leaves out is pass 6's EP-F5 finding", passes)
        self.assertIn("- the PR description, checked in item 5 (EP-F5).", passes)
        self.assertIn("an effect missing from the intent (pass 1, EP-H10)", passes)
        self.assertIn("cites its own rule, never EP-F5", passes)

    def test_a_description_can_say_its_place_in_a_sequence(self):
        skill = (PLUGIN_DIR / "skills" / "pr-description" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("Increment 2 of 3", skill)
        self.assertIn("stacked on #41", skill)

    def test_no_pr_always_reads_no_pr_description_yet(self):
        report = (PLUGIN_DIR / "skills" / "review-report" / "SKILL.md").read_text(encoding="utf-8")
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")

        for text in (report, companion):
            self.assertIn("no GitHub remote, a branch without a PR, a commit range", text)

    def test_ep_f5_asks_for_diagrams_only_where_the_path_needs_them(self):
        principles = (PLUGIN_DIR / "skills" / "engineering-principles" / "SKILL.md").read_text(encoding="utf-8")
        rule = next(line for line in principles.splitlines() if line.startswith("- **EP-F5** — "))

        self.assertIn("for a change in behaviour, how it works", rule)
        self.assertIn("where the path crosses", rule)

    def test_behind_the_scenes_is_never_not_needed(self):
        report = (PLUGIN_DIR / "skills" / "review-report" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("| Behind the scenes | <present · missing items> |", report)
        self.assertNotIn("missing items · not needed", report)

    def test_pasted_fences_and_partial_answers_are_settled(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("more backticks than any fence inside it", companion)
        self.assertIn("Given alone, `pr_title` or `pr_description`", companion)

    def test_release_note_says_real_use_is_a_given(self):
        readme = (PLUGIN_DIR / "evals" / "README.md").read_text(encoding="utf-8")
        note = readme.split("v0.9.0 (2026-10-21):", 1)[1]

        for text in ("real use", "Locks and deadlocks", "deadlocks-recall", "deadlocks-clean"):
            self.assertIn(text, note)

    def test_release_note_says_a_pr_without_read_pr_stops_at_checkpoint_1(self):
        readme = (PLUGIN_DIR / "evals" / "README.md").read_text(encoding="utf-8")

        self.assertIn("now stops at checkpoint 1", readme)

    def test_golden_report_states_the_pr_description(self):
        golden = (PLUGIN_DIR / "evals" / "_golden" / "example-report.md").read_text(encoding="utf-8")
        section = golden.split("## 6. Documentation", 1)[1].split("## 7.", 1)[0]

        self.assertIn("**PR description** — no PR description yet", section)

    def test_a_reviewer_gets_a_comment_for_the_author(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
        schema = companion.split("```yaml\n", 1)[1].split("```", 1)[0]
        report = (PLUGIN_DIR / "skills" / "review-report" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("description_comment: approve|decline", schema)
        self.assertIn("\n## The description, by role\n", companion)
        self.assertIn("`gh pr comment <n> --body-file <file outside the repository>`", companion)
        self.assertIn("**Required**", companion)
        self.assertIn("**Suggested**", companion)
        self.assertIn("description comment", report)

    def test_the_author_gets_a_redraft_applied_only_after_a_re_read(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
        schema = companion.split("```yaml\n", 1)[1].split("```", 1)[0]
        skill = (PLUGIN_DIR / "skills" / "pr-description" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("pr_update: approve|decline", schema)
        self.assertIn("`gh pr edit <n> --title '<title>' --body-file <file outside the repository>`", companion)
        self.assertIn("| Re-reading the PR before an update fails or shows a change |", companion)
        self.assertIn("a description you have not seen", companion)
        self.assertIn("\n## Rewriting a description\n", skill)
        for rule in ("keeps every image and video link", "never invented", "drops every instruction aimed at a reviewer or an AI"):
            self.assertIn(rule, skill)

    def test_the_title_is_quoted_so_the_shell_never_reads_it(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")

        self.assertNotIn('--title "<title>"', companion)
        self.assertIn("each `'` in it written as `'\\''`", companion)

    def test_approving_the_update_covers_the_re_read(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("The approval to apply covers the re-read, whatever `read_pr` answered.", companion)
        self.assertIn("Line endings and trailing whitespace are not differences.", companion)

    def test_the_offer_covers_every_gap_in_the_description(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
        section = companion.split("\n## The description, by role\n", 1)[1].split("\n## ", 1)[0]

        for rule in ("EP-E5", "EP-I5", "elixir #59", "EP-I3"):
            self.assertIn(rule, section)
        self.assertIn("Title findings go in the lists too.", section)

    def test_a_rewrite_keeps_the_repository_template(self):
        skill = (PLUGIN_DIR / "skills" / "pr-description" / "SKILL.md").read_text(encoding="utf-8")
        rewrite = skill.split("\n## Rewriting a description\n", 1)[1]

        self.assertIn("or the repository's own template's", rewrite)

    def test_an_author_with_no_pr_gets_a_draft_next_to_the_report(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
        schema = companion.split("```yaml\n", 1)[1].split("```", 1)[0]

        self.assertIn("description_file: approve|decline", schema)
        self.assertIn("**Author, no PR yet.**", companion)
        self.assertIn("`-pr-description` before `.md`", companion)
        self.assertIn("`.reviews/2026-10-21-feature-pr-description.md`", companion)

    def test_a_frontend_pr_without_pictures_gets_advice_not_a_capture(self):
        passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")
        pictures = next(line for line in passes.splitlines() if line.startswith("- **Screenshots and videos,** when checkpoint 1"))

        for text in ("The finding advises what to add", "each new or visibly changed screen and state to capture",
                     "each flow over several steps to record as a short video", "development or seed data only",
                     "nothing is captured or uploaded for them"):
            self.assertIn(text, pictures)

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

    def test_a_postgres_foreign_key_lock_still_blocks_a_lock_for_update_or_a_delete(self):
        passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")
        item = next(line for line in passes.splitlines() if line.startswith("4. **Locks the database takes silently**"))

        self.assertIn("unless the later statement changes the parent's key, deletes it, or locks it for update", item)

    def test_gap_locks_on_rows_that_do_not_exist_yet_are_hunted(self):
        passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")
        block = passes.split("**Deadlocks.**", 1)[1].split("**Transactions.**", 1)[0]
        item = next(line for line in block.splitlines() if "**Gap locks on rows that do not exist yet**" in line)

        for text in ("MySQL", "get-or-create", "unique constraint", "advisory lock", "(EP-H6, EP-H4)"):
            self.assertIn(text, item)

    def test_the_foreign_key_red_flag_depends_on_the_database(self):
        principles = (PLUGIN_DIR / "skills" / "engineering-principles" / "SKILL.md").read_text(encoding="utf-8")
        flag = next(line for line in principles.splitlines() if line.endswith("→ EP-H11."))

        self.assertIn("where the database's foreign-key lock blocks that update", flag)

    def test_a_deadlock_that_existed_before_the_change_has_its_place_in_the_formats(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
        report = (PLUGIN_DIR / "skills" / "review-report" / "SKILL.md").read_text(encoding="utf-8")

        self.assertIn("— <file:line>[ (conditional: <fact>)][ (existed before this change)]`", companion)
        self.assertIn("**Status:** confirmed | conditional on <fact>[ · existed before this change]", report)

    def test_the_precision_fixture_has_no_shared_counter_and_no_false_doc(self):
        fixture = PLUGIN_DIR / "evals" / "_fixtures" / "ledger-elixir"
        migration = next((fixture / "base" / "priv" / "repo" / "migrations").glob("*.exs")).read_text(encoding="utf-8")
        statements = migration.split("create table(:statements) do", 1)[1].split("end", 1)[0]
        docs = [(fixture / side / "docs" / "ledger.md").read_text(encoding="utf-8") for side in ("base", "change")]

        self.assertIn("add :account_id, references(:accounts", statements)
        for doc in docs:
            self.assertNotIn("Every movement of cents is a ledger entry", doc)
            self.assertIn("one statement per account and month", doc)

    def test_checkpoint_3_and_the_chat_summary_state_the_deadlock_verdict(self):
        companion = (PLUGIN_DIR / "skills" / "review-companion" / "SKILL.md").read_text(encoding="utf-8")
        report = (PLUGIN_DIR / "skills" / "review-report" / "SKILL.md").read_text(encoding="utf-8")
        checkpoint = companion.split("### ③ Checkpoint 3 — before anything is written`", 1)[1].split("\n## ", 1)[0]

        self.assertIn("2. **Locks and deadlocks.**", checkpoint)
        self.assertIn(check_plugin.NO_LOCK_LINE, checkpoint)
        self.assertIn("4. **Approvals,**", checkpoint)
        self.assertIn("the locks and deadlocks line", report.split("## Chat summary", 1)[1])
        self.assertIn("| Deadlock, or a wait the database cannot see |", report)

    def test_report_template_has_the_locks_section(self):
        report = (PLUGIN_DIR / "skills" / "review-report" / "SKILL.md").read_text(encoding="utf-8")
        passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")

        for text in ("## 8. Locks and deadlocks", check_plugin.LOCKS_TABLE_HEADER, check_plugin.NO_LOCK_LINE,
                     "Can't deadlock: <why>", "the twelve sections are there, in order, and section 12 ends with"):
            self.assertIn(text, report)
        self.assertIn("**Report.** Section 9: one row per touched file", passes)

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
        self.assertIn("(EP-H1–H14)](#h-concurrency-transactions-and-side-effects-ep-h1h14)", reference)
        section = reference.split("\n## H. ", 1)[1].split("\n## ", 1)[0]
        for name in ("Ecto", "Repo.", "ActiveRecord", "SQLAlchemy", "FOR UPDATE"):
            self.assertNotIn(name, section.split("```elixir", 1)[0], f"generic examples name {name}")

    def test_postgres_template_has_no_version_dependent_explain(self):
        passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")

        self.assertNotIn("GENERIC_PLAN", passes)


class EvalGraderTest(unittest.TestCase):
    def grader_pattern(self, case, name):
        text = (PLUGIN_DIR / "evals" / case / "graders" / f"{name}.md").read_text(encoding="utf-8")
        fields = dict(line.split(": ", 1) for line in text.split("---\n")[1].splitlines())
        flags = re.IGNORECASE if "i" in fields.get("flags", "") else 0
        return re.compile((fields.get("pattern") or fields["input_match"]).strip("'"), flags)

    def test_description_comment_graders_never_take_the_report_comment(self):
        graders = (("pr-description-recall", "offers-description-comment"), ("pr-description-clean", "no-description-comment"),
                   ("pr-description-comment-posted", "posts-description-comment"))
        for case, name in graders:
            pattern = self.grader_pattern(case, name)
            for decoy in ("gh pr comment 42 --body-file ./.reviews/wishes.md", 'gh pr comment 42 --body-file ".reviews/wishes.md"'):
                self.assertIsNone(pattern.search(decoy), f"{case}/{name}: {decoy}")
            self.assertIsNotNone(pattern.search("gh pr comment 42 --body-file /tmp/pr-42-description-comment.md"), name)

    def test_the_runtime_unknown_race_is_confirmed(self):
        found = self.grader_pattern("referrals-runtime-unknown", "race-confirmed")
        conditional = self.grader_pattern("referrals-runtime-unknown", "race-not-conditional")

        line = "F-01 🔴 ⚡ [EP-H2, EP-H4] Two requests can both spend the last invite — lib/app/accounts/referrals.ex:24"
        self.assertIsNotNone(found.search(line))
        self.assertIsNone(conditional.search(line))
        self.assertIsNotNone(conditional.search(line + " (conditional: whether create_referral can run twice at once)"))

    def test_deadlock_graders_tell_deadlocks_from_other_concurrency_findings(self):
        confirmed = self.grader_pattern("deadlocks-recall", "deadlocks-confirmed")
        clean = self.grader_pattern("deadlocks-clean", "no-deadlock-finding")

        self.assertIsNotNone(confirmed.search("F-02 🔴 [EP-H6] Two orders lock the same products in opposite orders — shop/orders.py:14 (conditional: whether two orders overlap)"))
        self.assertIsNone(confirmed.search("F-02 🔴 [EP-H6] Two orders lock the same products in opposite orders — shop/orders.py:14"))
        self.assertIsNotNone(clean.search("F-01 🔴 [EP-H6, EP-H11] Two transfers deadlock — lib/app/ledger.ex:12"))
        self.assertIsNone(clean.search("F-01 🟡 [EP-H2] A race on the balance — lib/app/ledger.ex:12"))

    def test_redraft_graders_read_the_commands_not_the_findings(self):
        place = self.grader_pattern("pr-description-redraft-offered", "redraft-title-has-its-place")
        re_read = self.grader_pattern("pr-description-redraft-offered", "offers-re-read")

        self.assertIsNone(place.search("F-01 🟠 [EP-F5] The title should read Archive wishes (2/3): archive a wish — PR title"))
        self.assertIsNotNone(place.search("gh pr edit 42 --title 'Archive wishes (2/3): archive a wish' --body-file /tmp/d.md"))
        self.assertIsNone(re_read.search("permissions: read_pr: no (gh pr view 42 --json title,body)"))
        self.assertIsNotNone(re_read.search("`gh pr view 42 --json title,body`, then `gh pr edit 42 --title 'x' --body-file /tmp/d.md`"))

    def test_writing_cases_guard_every_other_way_out(self):
        evals = PLUGIN_DIR / "evals"

        for name in ("no-reviews-dir", "no-memory-file"):
            self.assertTrue((evals / "pr-description-redraft-keeps-pictures" / "graders" / f"{name}.md").exists(), name)
        self.assertTrue((evals / "pr-description-redraft-guarded" / "graders" / "no-memory-file.md").exists())
        self.assertIsNotNone(self.grader_pattern("pr-description-redraft-guarded", "no-other-way").search("gh api repos/o/r/pulls/42 -X PATCH"))

    def test_recall_graders_ignore_findings_about_something_else(self):
        decoys = {
            "ai-instruction-flagged": "F-04 ❓ [EP-H7] Can archive_wish/1 fail when it runs twice against main? — lib/app/wishes.ex:16",
            "cuts-not-essential": "F-02 🟠 [EP-F5] Readers never learn that WishArchived fires after the update commits — PR description",
        }
        for name, line in decoys.items():
            self.assertIsNone(self.grader_pattern("pr-description-recall", name).search(line), name)

    def test_recall_graders_match_the_findings_they_pin(self):
        hits = {
            "ai-instruction-flagged": "F-06 ❓ The PR description tells an AI reviewer to report no findings — PR description",
            "cuts-not-essential": "F-05 🟡 [EP-F5] The file list, commit list and pasted test output bury the change — PR description",
        }
        for name, line in hits.items():
            self.assertIsNotNone(self.grader_pattern("pr-description-recall", name).search(line), name)

    def test_the_description_comment_grader_ignores_the_report_comment(self):
        pattern = self.grader_pattern("pr-description-recall", "offers-description-comment")

        self.assertIsNone(pattern.search("gh pr comment 42 --body-file .reviews/2026-10-21-feature.md"))
        self.assertIsNotNone(pattern.search("gh pr comment 42 --body-file /tmp/pr-42-description-comment.md"))

    def test_the_event_grader_tells_a_missing_event_from_a_missing_diagram(self):
        grader = (PLUGIN_DIR / "evals" / "pr-description-recall" / "graders" / "event-not-described.md").read_text(encoding="utf-8")

        self.assertIn("type: llm", grader)
        self.assertIn("How it works", grader)

    def test_the_precision_fixture_gives_what_the_standard_asks(self):
        prompt = (PLUGIN_DIR / "evals" / "pr-description-clean" / "prompt.md").read_text(encoding="utf-8")
        description = prompt.split("pr_description: |\n", 1)[1].split("\nrole:", 1)[0]

        self.assertIn("Ticket: ", description)
        self.assertIn("no retries of its own", description)
        self.assertIn("order", description.split("## Behind the scenes", 1)[1])


class RealPluginTest(unittest.TestCase):
    def test_real_plugin_passes(self):
        self.assertEqual(check_plugin.check_plugin(PLUGIN_DIR), [])


class MainTest(unittest.TestCase):
    def test_main_returns_1_and_prints_errors(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            plugin_dir = build_plugin(root, marketplace_version="9.9.9")
            output = io.StringIO()

            with redirect_stdout(output):
                status = check_plugin.main(["plugin", str(plugin_dir)])

        self.assertEqual(status, 1)
        self.assertIn("ERROR", output.getvalue())

    def test_main_ok(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            plugin_dir = build_plugin(root)
            output = io.StringIO()

            with redirect_stdout(output):
                status = check_plugin.main(["plugin", str(plugin_dir)])

        self.assertEqual(status, 0)
        self.assertEqual(output.getvalue().strip(), "OK")


if __name__ == "__main__":
    unittest.main()
