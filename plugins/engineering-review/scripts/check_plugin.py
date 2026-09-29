#!/usr/bin/env python3
"""Validate the engineering-review plugin: portable skill frontmatter, links
between skill files, and manifest consistency.

Usage: check_plugin.py plugin <plugin_dir>
Prints `OK`, or one `ERROR <path>: <message>` line per problem.
"""
import json
import re
import sys
from pathlib import Path

ALLOWED_SKILL_KEYS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
SKILL_NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
TOOL_TOKENS = ("AskUserQuestion", "`Bash`", "`Skill`", "`Write`")
RUNTIME_NOTES = re.compile(r"^## Runtime notes\s*$", re.MULTILINE)
MARKDOWN_LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n", re.DOTALL)
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


def check_plugin(plugin_dir):
    repo_root = plugin_dir.parent.parent
    skill_dirs = sorted(path for path in (plugin_dir / "skills").glob("*") if path.is_dir())
    errors = check_manifests(repo_root, plugin_dir)
    for skill_dir in skill_dirs:
        errors += check_skill(skill_dir)
        for md_path in sorted(skill_dir.rglob("*.md")):
            errors += check_references(md_path, skill_dir)
    return errors


def main(argv):
    if len(argv) < 2 or argv[0] != "plugin":
        print("usage: check_plugin.py plugin <plugin_dir>")
        return 2
    errors = check_plugin(Path(argv[1]))
    for error in errors:
        print(f"ERROR {error}")
    if errors:
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
