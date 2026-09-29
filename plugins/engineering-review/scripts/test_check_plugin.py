import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import check_plugin

VALID_SKILL = """---
name: demo-skill
description: Use when testing the validator.
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

**Recommendation.**
1. Use one conditional update.

**Effort:** small.
"""


def report_text(sections=REPORT_SECTIONS, card=CARD, extra=""):
    parts = ["# Review — feature", ""]
    for heading in sections:
        parts += [heading, ""]
        if heading == "## 4. Findings":
            parts += [card, ""]
    return "\n".join(parts) + extra + "\nThe decision to merge is yours.\n"


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

    def test_report_verdict_phrase(self):
        with tempfile.TemporaryDirectory() as tmp:
            md = write(Path(tmp) / "report.md", report_text(extra="\nLGTM, ship it.\n"))

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

    def test_golden_report_passes(self):
        golden = PLUGIN_DIR / "evals" / "_golden" / "example-report.md"

        self.assertEqual(check_plugin.check_report(golden), [])


PG_BLOCK = """```sql
-- engine: postgresql
-- review-companion · read-only · safe on production
BEGIN TRANSACTION READ ONLY;
SET LOCAL statement_timeout = '5s';
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

    def test_blocks_without_engine_marker_are_ignored(self):
        text = "```sql\nCREATE INDEX CONCURRENTLY listings_city_id_index ON listings (city_id);\n```\n"

        self.assertEqual(sql_errors(text), [])

    def test_mysql_and_sqlite_blocks_ok(self):
        text = (
            "```sql\n-- engine: mysql\nSTART TRANSACTION READ ONLY;\nSET SESSION MAX_EXECUTION_TIME = 5000;\n"
            "SELECT table_name, table_rows FROM information_schema.tables WHERE table_name = 'listings';\nROLLBACK;\n```\n"
            "```sql\n-- engine: sqlite\nPRAGMA query_only = ON;\nSELECT tbl, idx, stat FROM sqlite_stat1 WHERE tbl = 'wishes';\n```\n"
        )

        self.assertEqual(sql_errors(text), [])


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
