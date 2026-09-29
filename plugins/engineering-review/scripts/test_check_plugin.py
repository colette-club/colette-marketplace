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
