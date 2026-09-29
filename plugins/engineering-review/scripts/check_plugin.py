#!/usr/bin/env python3
"""Validate the engineering-review plugin and the reports it produces.

Usage:
  check_plugin.py plugin <plugin_dir> [--mermaid]   skills, links, rule IDs, manifests, diagrams
  check_plugin.py report <report.md> [--mermaid]    a review report's structure

Prints `OK`, or one `ERROR <path>: <message>` line per problem. With --mermaid and
`mmdc` on PATH, every mermaid block must also render.
"""
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ALLOWED_SKILL_KEYS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
SKILL_NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
TOOL_TOKENS = ("AskUserQuestion", "`Bash`", "`Skill`", "`Write`")
RUNTIME_NOTES = re.compile(r"^## Runtime notes\s*$", re.MULTILINE)
MARKDOWN_LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n", re.DOTALL)
DEFINED_RULE = re.compile(r"^- \*\*(EP-(?:0|[A-K]\d+))\*\* — ", re.MULTILINE)
CITED_RULE = re.compile(r"\bEP-(?:0|[A-Z]\d+)\b")
PRINCIPLES = Path("skills") / "engineering-principles" / "SKILL.md"
MERMAID_BLOCK = re.compile(r"^\s*`{3,}mermaid\s*\n(.*?)^\s*`{3,}\s*$", re.MULTILINE | re.DOTALL)
MERMAID_TYPES = ("flowchart", "sequenceDiagram", "erDiagram", "stateDiagram-v2", "classDiagram", "quadrantChart")
REPORT_SECTIONS = (
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
)
CARD_HEADING = re.compile(r"^### F-\d{2} ", re.MULTILINE)
VALID_CARD_HEADING = re.compile(r"^### F-\d{2} (🔴|🟠|🟡|❓)")
CARD_FIELDS = ("**Pass:**", "**Status:**", "**What.**", "**Why it matters.**", "**Recommendation.**", "**Effort:**")
VERDICT = re.compile(r"\b(LGTM|I approve|approved for merge|ship it|requesting changes)\b", re.IGNORECASE)
KEY_LINE = re.compile(r"^([A-Za-z0-9_-]+):\s*(.*)$")
LIST_ITEM = re.compile(r"^\s+-\s+(.*)$")


def parse_frontmatter(text):
    match = FRONTMATTER.match(text)
    if match is None:
        raise ValueError("missing frontmatter")
    result = {}
    current_key = None
    for line in match.group(1).splitlines():
        key_match = KEY_LINE.match(line)
        item_match = LIST_ITEM.match(line)
        if key_match:
            current_key = key_match.group(1)
            value = key_match.group(2).strip()
            result[current_key] = value if value else []
        elif item_match and current_key is not None:
            result[current_key] = _as_list(result[current_key]) + [item_match.group(1).strip()]
    return result


def _as_list(value):
    return value if isinstance(value, list) else []


def body_of(text):
    match = FRONTMATTER.match(text)
    return text[match.end():] if match else text


def check_skill(skill_dir):
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        return [f"{skill_md}: missing SKILL.md"]
    text = skill_md.read_text(encoding="utf-8")
    try:
        frontmatter = parse_frontmatter(text)
    except ValueError as error:
        return [f"{skill_md}: {error}"]
    return (
        _check_keys(skill_md, frontmatter)
        + _check_name(skill_md, skill_dir, frontmatter)
        + _check_description(skill_md, frontmatter)
        + _check_tool_tokens(skill_md, body_of(text))
    )


def _check_keys(skill_md, frontmatter):
    extra = sorted(set(frontmatter) - ALLOWED_SKILL_KEYS)
    return [f"{skill_md}: non-standard frontmatter key(s): {', '.join(extra)}"] if extra else []


def _check_name(skill_md, skill_dir, frontmatter):
    name = frontmatter.get("name", "")
    if name != skill_dir.name:
        return [f"{skill_md}: name '{name}' does not match directory '{skill_dir.name}'"]
    if not SKILL_NAME.match(name) or len(name) > 64:
        return [f"{skill_md}: name '{name}' must be kebab-case and at most 64 characters"]
    return []


def _check_description(skill_md, frontmatter):
    return [] if frontmatter.get("description") else [f"{skill_md}: empty description"]


def _check_tool_tokens(skill_md, body):
    notes = RUNTIME_NOTES.search(body)
    before_notes = body[: notes.start()] if notes else body
    found = [token for token in TOOL_TOKENS if token in before_notes]
    return [f"{skill_md}: tool name {token} outside '## Runtime notes'" for token in found]


def check_references(md_path, skill_dir):
    text = md_path.read_text(encoding="utf-8")
    targets = [target for target in MARKDOWN_LINK.findall(text) if _is_relative_file(target)]
    missing = [target for target in targets if not (md_path.parent / target.split("#")[0]).resolve().is_file()]
    outside = [target for target in targets if not _inside(md_path.parent / target.split("#")[0], skill_dir)]
    return [f"{md_path}: link to missing file {target}" for target in missing] + [
        f"{md_path}: link leaves the skill directory {target}" for target in outside
    ]


def _is_relative_file(target):
    return not re.match(r"^[a-z]+:", target) and not target.startswith("#")


def _inside(path, directory):
    try:
        path.resolve().relative_to(directory.resolve())
        return True
    except ValueError:
        return False


def check_manifests(repo_root, plugin_dir):
    plugin_json = plugin_dir / ".claude-plugin" / "plugin.json"
    marketplace_json = repo_root / ".claude-plugin" / "marketplace.json"
    if not plugin_json.is_file():
        return [f"{plugin_json}: missing plugin manifest"]
    if not marketplace_json.is_file():
        return [f"{marketplace_json}: missing marketplace manifest"]
    plugin = json.loads(plugin_json.read_text(encoding="utf-8"))
    marketplace = json.loads(marketplace_json.read_text(encoding="utf-8"))
    entries = [entry for entry in marketplace.get("plugins", []) if entry.get("name") == plugin.get("name")]
    if not entries:
        return [f"{marketplace_json}: no entry for plugin '{plugin.get('name')}'"]
    return _compare_entry(marketplace_json, entries[0], plugin)


def _compare_entry(marketplace_json, entry, plugin):
    errors = []
    expected_source = f"./plugins/{plugin.get('name')}"
    if entry.get("source") != expected_source:
        errors.append(f"{marketplace_json}: source '{entry.get('source')}' should be '{expected_source}'")
    if entry.get("version") != plugin.get("version"):
        errors.append(
            f"{marketplace_json}: version '{entry.get('version')}' differs from plugin.json '{plugin.get('version')}'"
        )
    return errors


def defined_rule_ids(principles_md):
    return set(DEFINED_RULE.findall(principles_md.read_text(encoding="utf-8")))


def cited_rule_ids(text):
    return set(CITED_RULE.findall(text))


def check_rule_ids(plugin_dir):
    principles = plugin_dir / PRINCIPLES
    defined = defined_rule_ids(principles) if principles.is_file() else set()
    errors = []
    for md_path in _plugin_markdown(plugin_dir):
        undefined = sorted(cited_rule_ids(md_path.read_text(encoding="utf-8")) - defined)
        errors += [f"{md_path}: cites undefined rule {rule_id}" for rule_id in undefined]
    return errors


def _plugin_markdown(plugin_dir):
    results_dir = plugin_dir / "evals" / "results"
    return sorted(path for path in plugin_dir.rglob("*.md") if results_dir not in path.parents)


def check_mermaid_blocks(md_path, render=False):
    text = md_path.read_text(encoding="utf-8")
    errors = []
    for block in MERMAID_BLOCK.findall(text):
        kind = _first_word(block)
        if kind not in MERMAID_TYPES:
            errors.append(f"{md_path}: mermaid type '{kind}' is outside the safe subset")
        elif render:
            errors += _render_mermaid(md_path, block)
    return errors


def _first_word(block):
    lines = [line.strip() for line in block.splitlines() if line.strip()]
    return lines[0].split()[0] if lines else ""


def _render_mermaid(md_path, block):
    mmdc = shutil.which("mmdc")
    if mmdc is None:
        return []
    with tempfile.TemporaryDirectory() as tmp:
        source = Path(tmp) / "diagram.mmd"
        source.write_text(block, encoding="utf-8")
        result = subprocess.run([mmdc, "-i", str(source), "-o", str(Path(tmp) / "diagram.svg")], capture_output=True)
    if result.returncode != 0:
        return [f"{md_path}: mermaid block '{_first_word(block)}' does not render"]
    return []


def check_report(report_md, render=False):
    text = report_md.read_text(encoding="utf-8")
    prose = _without_code_blocks(text)
    return (
        _check_sections(report_md, prose)
        + _check_cards(report_md, prose)
        + _check_verdict(report_md, prose)
        + check_mermaid_blocks(report_md, render)
    )


def _without_code_blocks(text):
    lines = []
    fence = None
    for line in text.splitlines():
        marker = re.match(r"^\s*(`{3,}|~{3,})", line)
        if fence is None and marker:
            fence = marker.group(1)
            lines.append("")
        elif fence is not None:
            if line.strip().startswith(fence) and line.strip().strip(fence[0]) == "":
                fence = None
            lines.append("")
        else:
            lines.append(line)
    return "\n".join(lines)


def _check_sections(report_md, text):
    headings = [line.strip() for line in text.splitlines() if line.startswith("## ")]
    missing = [section for section in REPORT_SECTIONS if section not in headings]
    if missing:
        return [f"{report_md}: missing section '{section}'" for section in missing]
    positions = [headings.index(section) for section in REPORT_SECTIONS]
    if positions != sorted(positions):
        return [f"{report_md}: sections are out of order (expected {', '.join(REPORT_SECTIONS)})"]
    return []


def _check_cards(report_md, text):
    starts = [match.start() for match in CARD_HEADING.finditer(text)]
    errors = []
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else len(text)
        card = _until_next_section(text[start:end])
        heading = card.splitlines()[0]
        if not VALID_CARD_HEADING.match(heading):
            errors.append(f"{report_md}: card '{heading}' has no severity (🔴 🟠 🟡 ❓)")
        missing = [field for field in CARD_FIELDS if field not in card]
        errors += [f"{report_md}: card '{heading}' is missing {field}" for field in missing]
    return errors


def _until_next_section(card):
    match = re.search(r"^## ", card, re.MULTILINE)
    return card[: match.start()] if match else card


def _check_verdict(report_md, text):
    found = sorted({match.group(0) for match in VERDICT.finditer(text)})
    if not found:
        return []
    return [f"{report_md}: verdict phrase(s) {', '.join(repr(p) for p in found)} — the companion never approves"]


def check_plugin(plugin_dir, render=False):
    repo_root = plugin_dir.parent.parent
    skill_dirs = sorted(path for path in (plugin_dir / "skills").glob("*") if path.is_dir())
    errors = check_manifests(repo_root, plugin_dir)
    for skill_dir in skill_dirs:
        errors += check_skill(skill_dir)
        for md_path in sorted(skill_dir.rglob("*.md")):
            errors += check_references(md_path, skill_dir)
    for md_path in _plugin_markdown(plugin_dir):
        errors += check_mermaid_blocks(md_path, render)
    return errors + check_rule_ids(plugin_dir)


def main(argv):
    render = "--mermaid" in argv
    args = [arg for arg in argv if arg != "--mermaid"]
    if len(args) != 2 or args[0] not in ("plugin", "report"):
        print(__doc__.strip())
        return 2
    if render and shutil.which("mmdc") is None:
        print("WARNING mmdc not found; mermaid blocks were checked for type only")
    target = Path(args[1])
    errors = check_plugin(target, render) if args[0] == "plugin" else check_report(target, render)
    for error in errors:
        print(f"ERROR {error}")
    if errors:
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
