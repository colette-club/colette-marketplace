import io
import json
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
    | {f"EP-D{n}" for n in range(1, 13)}
    | {f"EP-E{n}" for n in range(1, 5)}
    | {f"EP-F{n}" for n in range(1, 5)}
    | {f"EP-G{n}" for n in range(1, 7)}
    | {f"EP-H{n}" for n in range(1, 11)}
    | {f"EP-I{n}" for n in range(1, 3)}
    | {f"EP-J{n}" for n in range(1, 19)}
    | {f"EP-K{n}" for n in range(1, 11)}
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

        self.assertEqual(len(TABLE_RULE_IDS), 83)
        self.assertEqual(check_plugin.defined_rule_ids(principles), TABLE_RULE_IDS)


REPORT_SECTIONS = [
    "## 1. Summary",
    "## 2. ⚡ Side effects set in motion",
    "## 3. The change at a glance",
    "## 4. Findings",
    "## 5. Tests",
    "## 6. Documentation",
    "## 7. Data access & performance",
    "## 8. Risk and attention map",
    "## 9. Conversation",
    "## 10. Recommended plan",
    "## 11. Limits and decision",
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
| Languages and skills applied | Elixir — engineering-principles |
| Commands run | none |
| Previous report | none found |

> This report supports a human review. It does not approve or reject anything; the decision to merge belongs to the reviewer.
"""


def report_text(sections=REPORT_SECTIONS, card=CARD, extra="", header=HEADER, closing="\nThe decision to merge is yours.\n"):
    parts = ["# Review — feature", "", header]
    for heading in sections:
        parts += [heading, ""]
        if heading == "## 4. Findings":
            parts += [card, ""]
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
        for permission in ("run_tests", "explain_local_db", "fetch_history", "fetch_pr"):
            self.assertIn(f'{permission}: "<exact command>" | no', schema)
        self.assertNotIn("yes|no", schema)

    def test_reference_has_examples_in_every_language_for_every_group(self):
        reference = (PLUGIN_DIR / "skills" / "engineering-principles" / "reference.md").read_text(encoding="utf-8")
        groups = [section for section in reference.split("\n## ")[1:] if not section.startswith("Contents")]

        self.assertEqual(len(groups), 11)
        for group in groups:
            title = group.splitlines()[0]
            for fence in ("```\n", "```elixir\n", "```dart\n"):
                self.assertIn(fence, group, f"{title} has no {fence.strip() or 'pseudocode'} example")

    def test_postgres_template_has_no_version_dependent_explain(self):
        passes = (PLUGIN_DIR / "skills" / "review-passes" / "SKILL.md").read_text(encoding="utf-8")

        self.assertNotIn("GENERIC_PLAN", passes)


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
