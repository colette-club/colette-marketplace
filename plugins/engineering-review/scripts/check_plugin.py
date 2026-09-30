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
RULE_TOKEN = re.compile(r"\bEP-[A-Za-z0-9]+")
VALID_RULE_TOKEN = re.compile(r"EP-(?:0|[A-Z]\d+)")
PLACEHOLDER_RULES = {"EP-XN"}
PRINCIPLES = Path("skills") / "engineering-principles" / "SKILL.md"
DESCRIPTION_OPENER = re.compile(r"^(use|load|you|your|i|we)\b", re.IGNORECASE)
DESCRIPTION_TRIGGER = re.compile(r"\bwhen\b", re.IGNORECASE)
XML_TAG = re.compile(r"<[A-Za-z/][^>]*>")
MAX_DESCRIPTION = 1024
CONTENTS_THRESHOLD = 100
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
CARD_FIELDS = ("**Pass:**", "**Status:**", "**What.**", "**Why it matters.**", "**Evidence.**", "**Recommendation.**", "**Effort:**")
REPORT_HEADER_ROWS = (
    "Target",
    "Date",
    "Role of the person asked",
    "Stack and skills applied",
    "Commands run",
    "Previous report",
)
DISCLAIMER = "> This report supports a human review."
SKILLS_TABLE_COLUMNS = ("Skill", "Covers", "Applied to", "Findings")
CLOSING_LINE = "The decision to merge is yours."
VERDICT = re.compile(
    r"\b(LGTM|I approve|approved for merge|ready to merge|requesting changes)\b|\bship it\b(?=\s*(?:[.!]|$))",
    re.IGNORECASE | re.MULTILINE,
)
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


def check_description_style(skill_md):
    try:
        description = parse_frontmatter(skill_md.read_text(encoding="utf-8")).get("description", "")
    except ValueError:
        return []
    description = description if isinstance(description, str) else ""
    errors = []
    if DESCRIPTION_OPENER.match(description):
        opening = " ".join(description.split()[:3])
        errors.append(f"{skill_md}: description must open with what the skill does, in the third person, not '{opening} …'")
    if not DESCRIPTION_TRIGGER.search(description):
        errors.append(f"{skill_md}: description must say when to use the skill ('Use when …')")
    if len(description) > MAX_DESCRIPTION:
        errors.append(f"{skill_md}: description is {len(description)} characters; the limit is {MAX_DESCRIPTION}")
    if XML_TAG.search(description):
        errors.append(f"{skill_md}: description must not contain XML tags ('{XML_TAG.search(description).group(0)}')")
    return errors


def check_table_of_contents(md_path):
    text = md_path.read_text(encoding="utf-8")
    if len(text.splitlines()) <= CONTENTS_THRESHOLD:
        return []
    prose = _without_code_blocks(text)
    headings = [line[3:].strip() for line in prose.splitlines() if line.startswith("## ")]
    if not headings or headings[0] != "Contents":
        return [f"{md_path}: over {CONTENTS_THRESHOLD} lines, so it needs a table of contents ('## Contents') before its first section"]
    sections = headings[1:]
    contents = prose.split("## Contents", 1)[1].split("\n## ", 1)[0]
    linked = re.findall(r"\]\(#([^)]+)\)", contents)
    anchors = {heading_anchor(section): section for section in sections}
    errors = [f"{md_path}: table of contents links to #{anchor}, which is not a section" for anchor in linked if anchor not in anchors]
    errors += [f"{md_path}: table of contents does not list '{section}'" for anchor, section in anchors.items() if anchor not in linked]
    return errors


def heading_anchor(heading):
    """The anchor GitHub gives a heading: lower case, punctuation removed, spaces as hyphens."""
    return re.sub(r"[^\w\- ]", "", heading.strip().lower()).replace(" ", "-")


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


def malformed_rule_ids(text):
    tokens = set(RULE_TOKEN.findall(text)) - PLACEHOLDER_RULES
    return {token for token in tokens if not VALID_RULE_TOKEN.fullmatch(token)}


def check_rule_ids(plugin_dir):
    principles = plugin_dir / PRINCIPLES
    defined = defined_rule_ids(principles) if principles.is_file() else set()
    errors = []
    for md_path in _plugin_markdown(plugin_dir):
        if "graders" in md_path.parts:
            continue
        text = md_path.read_text(encoding="utf-8")
        undefined = sorted(cited_rule_ids(text) - defined)
        errors += [f"{md_path}: cites undefined rule {rule_id}" for rule_id in undefined]
        errors += [f"{md_path}: malformed rule ID '{token}' (expected EP-0 or EP-<letter><number>)"
                   for token in sorted(malformed_rule_ids(text))]
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
        + _check_header(report_md, prose)
        + _check_skills_table(report_md, prose)
        + _check_cards(report_md, prose)
        + _check_verdict(report_md, prose)
        + _check_closing(report_md, prose)
        + check_sql_blocks(report_md)
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


def _check_header(report_md, text):
    summary = text.find("## 1. Summary")
    header = text[: summary if summary >= 0 else len(text)]
    rows = {match.group(1).strip() for match in re.finditer(r"^\|([^|\n]+)\|", header, re.MULTILINE)}
    errors = [f"{report_md}: header is missing the '{name}' row" for name in REPORT_HEADER_ROWS if name not in rows]
    if DISCLAIMER not in header:
        errors.append(f"{report_md}: header is missing the disclaimer line '{DISCLAIMER} …'")
    return errors


def _check_skills_table(report_md, text):
    start = text.find("## 3. The change at a glance")
    if start < 0:
        return []
    end = text.find("\n## ", start + 1)
    section = text[start : end if end >= 0 else len(text)]
    lines = section.splitlines()
    header = next((index for index, line in enumerate(lines) if re.match(r"^\|\s*Skill\s*\|", line)), None)
    if header is None:
        return [f"{report_md}: section 3 needs the 'Skills applied' table (| Skill | Covers | Applied to | Findings |)"]
    columns = {cell.strip().lower() for cell in lines[header].strip().strip("|").split("|")}
    missing = [name for name in SKILLS_TABLE_COLUMNS if name.lower() not in columns]
    if missing:
        return [f"{report_md}: the Skills applied table is missing the column(s) {', '.join(missing)}"]
    rows = []
    for line in lines[header + 1 :]:
        if not line.startswith("|"):
            break
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if cells and not all(re.fullmatch(r":?-+:?", cell) for cell in cells) and cells[0]:
            rows.append(cells)
    if not rows:
        return [f"{report_md}: the Skills applied table has no skill rows"]
    return []


def _check_closing(report_md, text):
    start = text.find("## 11. Limits and decision")
    if start < 0 or CLOSING_LINE in text[start:]:
        return []
    return [f"{report_md}: section 11 must end with '{CLOSING_LINE}'"]


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


SQL_BLOCK = re.compile(r"^\s*`{3,}sql\s*\n(.*?)^\s*`{3,}\s*$", re.MULTILINE | re.DOTALL)
ENGINE_MARKER = re.compile(r"^\s*--\s*engine:\s*(\w+)", re.MULTILINE)
MIGRATION_MARKER = re.compile(r"\A\s*--\s*migration\b", re.IGNORECASE)
SQL_FORBIDDEN = (
    (re.compile(r"\bexplain\s+analy[sz]e\b|\bexplain\s*\([^)]*\banaly[sz]e\b", re.IGNORECASE), "EXPLAIN ANALYZE runs the statement"),
    (re.compile(r"count\s*\(\s*\*\s*\)", re.IGNORECASE), "count(*) scans the table; use estimates"),
    (re.compile(r"\b(most_common_vals|most_common_elems|most_common_elem_freqs|histogram_bounds)\b", re.IGNORECASE),
     "value statistics return column values"),
    (re.compile(r"\b(pg_terminate_backend|pg_cancel_backend|pg_reload_conf|pg_rotate_logfile|pg_try_advisory\w*|pg_advisory\w*"
                r"|set_config|nextval|setval|pg_sleep\w*|dblink\w*|lo_import|lo_export|lo_unlink|pg_read_file"
                r"|pg_read_binary_file|pg_ls_dir|pg_stat_reset\w*|pg_switch_wal|sleep|benchmark|get_lock|load_file)\s*\(",
                re.IGNORECASE), "functions with side effects are not allowed"),
)
SQL_ALLOWED_FIRST_WORDS = {"select", "with", "explain", "show", "begin", "start", "rollback", "set", "pragma"}
SQL_WRITE_WORDS = re.compile(
    r"\b(insert|update|delete|merge|truncate|drop|alter|create|grant|revoke|vacuum|reindex|cluster|copy|lock|call)\b",
    re.IGNORECASE,
)
SQL_ALLOWED_SET = re.compile(
    r"\Aset\s+(local\s+|session\s+)?(statement_timeout|idle_in_transaction_session_timeout|lock_timeout"
    r"|max_execution_time|max_statement_time)\b",
    re.IGNORECASE,
)
SQL_ALLOWED_PRAGMA = re.compile(
    r"\Apragma\s+(query_only|index_list|index_info|index_xinfo|table_info|table_xinfo|table_list|foreign_key_list"
    r"|database_list)\b",
    re.IGNORECASE,
)
SQL_ENGINE_RULES = {
    "postgresql": (
        (re.compile(r"\A\s*begin\s+(transaction\s+)?read\s+only\s*;", re.IGNORECASE), "must start with BEGIN TRANSACTION READ ONLY;"),
        (re.compile(r"\bstatement_timeout\b", re.IGNORECASE), "must set statement_timeout"),
        (re.compile(r"\bidle_in_transaction_session_timeout\b", re.IGNORECASE), "must set idle_in_transaction_session_timeout"),
        (re.compile(r"\brollback\s*;\s*\Z", re.IGNORECASE), "must end with ROLLBACK;"),
    ),
    "mysql": (
        (re.compile(r"\A\s*start\s+transaction\s+read\s+only\s*;", re.IGNORECASE), "must start with START TRANSACTION READ ONLY;"),
        (re.compile(r"\bmax_execution_time\b", re.IGNORECASE), "must set MAX_EXECUTION_TIME"),
        (re.compile(r"\brollback\s*;\s*\Z", re.IGNORECASE), "must end with ROLLBACK;"),
    ),
    "mariadb": (
        (re.compile(r"\A\s*start\s+transaction\s+read\s+only\s*;", re.IGNORECASE), "must start with START TRANSACTION READ ONLY;"),
        (re.compile(r"\bmax_statement_time\b", re.IGNORECASE), "must set max_statement_time"),
        (re.compile(r"\brollback\s*;\s*\Z", re.IGNORECASE), "must end with ROLLBACK;"),
    ),
    "sqlite": (
        (re.compile(r"\A\s*pragma\s+query_only\s*=\s*(on|1|true)\s*;", re.IGNORECASE), "must start with PRAGMA query_only = ON;"),
    ),
}


def check_sql_blocks(md_path):
    text = md_path.read_text(encoding="utf-8")
    errors = []
    for block in SQL_BLOCK.findall(text):
        marker = ENGINE_MARKER.search(block)
        if marker is None:
            if not MIGRATION_MARKER.match(block):
                errors.append(f"{md_path}: a SQL block must start with '-- engine: <engine>' (a query to run) "
                              "or '-- migration' (a recommended schema change)")
            continue
        errors += _check_sql_block(md_path, marker.group(1).lower(), sql_code(block))
    return errors


def sql_code(block):
    """The block with comments removed and every string literal emptied, so words inside them do not count."""
    out = []
    index = 0
    while index < len(block):
        if block.startswith("--", index):
            end = block.find("\n", index)
            index = len(block) if end < 0 else end
        elif block.startswith("/*", index):
            end = block.find("*/", index + 2)
            index = len(block) if end < 0 else end + 2
        elif block[index] == "'":
            index = _end_of_string(block, index + 1)
            out.append("''")
        else:
            out.append(block[index])
            index += 1
    return "".join(out)


def _end_of_string(block, index):
    while index < len(block):
        if block.startswith("''", index):
            index += 2
        elif block[index] == "'":
            return index + 1
        else:
            index += 1
    return index


def _check_sql_block(md_path, engine, sql):
    if engine not in SQL_ENGINE_RULES:
        return [f"{md_path}: unknown SQL engine '{engine}'"]
    missing = [message for pattern, message in SQL_ENGINE_RULES[engine] if not pattern.search(sql)]
    matches = [(pattern.search(sql), message) for pattern, message in SQL_FORBIDDEN]
    forbidden = [f"{message}: '{match.group(0).strip()}'" for match, message in matches if match]
    statements = [problem for statement in sql.split(";") if (problem := _statement_problem(statement.strip()))]
    return [f"{md_path}: {engine} block {message}" for message in missing + forbidden + statements]


def _statement_problem(statement):
    if not statement:
        return None
    first = re.match(r"[\s(]*([A-Za-z_]+)", statement)
    word = first.group(1).lower() if first else ""
    shown = " ".join(statement.split())[:60]
    if word not in SQL_ALLOWED_FIRST_WORDS:
        return f"statement is not read-only: '{shown}'"
    write = SQL_WRITE_WORDS.search(statement)
    if write:
        return f"writes or DDL are not allowed: '{write.group(0)}' in '{shown}'"
    if word == "set" and not SQL_ALLOWED_SET.match(statement):
        return f"SET may only set a timeout: '{shown}'"
    if word == "pragma" and not SQL_ALLOWED_PRAGMA.match(statement):
        return f"PRAGMA may only read metadata: '{shown}'"
    return None


AGENT_SKILLS = ("engineering-principles", "review-companion", "review-passes", "review-report")


def check_agent(agent_md):
    try:
        frontmatter = parse_frontmatter(agent_md.read_text(encoding="utf-8"))
    except ValueError as error:
        return [f"{agent_md}: {error}"]
    errors = [] if frontmatter.get("name") == "review-companion" else [f"{agent_md}: name must be 'review-companion'"]
    errors += [] if frontmatter.get("description") else [f"{agent_md}: empty description"]
    skills = frontmatter.get("skills") if isinstance(frontmatter.get("skills"), list) else []
    missing = [skill for skill in AGENT_SKILLS if skill not in skills]
    return errors + ([f"{agent_md}: skills list is missing {', '.join(missing)}"] if missing else [])


def check_plugin(plugin_dir, render=False):
    repo_root = plugin_dir.parent.parent
    skill_dirs = sorted(path for path in (plugin_dir / "skills").glob("*") if path.is_dir())
    errors = check_manifests(repo_root, plugin_dir)
    for skill_dir in skill_dirs:
        errors += check_skill(skill_dir) + check_description_style(skill_dir / "SKILL.md")
        for md_path in sorted(skill_dir.rglob("*.md")):
            errors += check_references(md_path, skill_dir)
            errors += [] if md_path.name == "SKILL.md" else check_table_of_contents(md_path)
    for md_path in _plugin_markdown(plugin_dir):
        errors += check_mermaid_blocks(md_path, render) + check_sql_blocks(md_path)
    for agent_md in sorted((plugin_dir / "agents").glob("*.md")):
        errors += check_agent(agent_md)
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
