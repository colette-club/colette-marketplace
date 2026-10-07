// templates/github/scripts/guardrails_gate.ts — becomes the app's .github/scripts/guardrails_gate.ts
/**
 * The guardrails-changed gate: fails a pull request that weakens a guardrail. A reviewer
 * who accepts the change adds the `guardrails-changed` label, and the workflow skips this job.
 *
 * - Baselines (`.sobelow-skips`, `.dialyzer_ignore.exs`, `.gitleaksignore`, and lines from
 *   `# >>> baseline` to `# <<< baseline`): deleting lines passes, adding one fails, and so
 *   does adding, deleting or moving a marker line.
 * - Guarded files (`.credo.exs` outside its baseline, `.sobelow-conf`, `coveralls.json`,
 *   `.gitattributes`, `.gitleaks.toml`, `.github/`): any other change fails. Files are
 *   matched by name, so `config/.credo.exs` and umbrella apps are covered too.
 * - `mix.exs`: adding or removing a line about a guardrail (a `precommit` step, `compilers:`,
 *   `dialyzer:`, a check's dep, …) fails.
 * - Any other file: adding an escape hatch (`credo:disable`, `sobelow_skip`, `@dialyzer`, …) fails.
 *
 * A line re-added with only its indentation or trailing comma changed is not an addition,
 * a baseline list or map emptied by `mix format` (`X => []`, `baseline = %{}`) is a deletion,
 * and lowering a `--fail-above` number is allowed everywhere.
 *
 * The gate is a tripwire, not a lock: it cannot see a new entry inside an existing
 * multi-line ignore list, and a PR can edit the workflow that runs it. Required status
 * checks, CODEOWNERS on `.github/` and the guardrail files, and review cover the rest.
 *
 * Usage: deno run --allow-run=git guardrails_gate.ts <base-sha>
 */

export interface Line {
  line: number;
  text: string;
}

export interface FileDiff {
  path: string;
  removed: Line[];
  added: Line[];
}

export interface Violation {
  path: string;
  line: number;
  text: string;
  reason: string;
}

const WHOLE_FILE_BASELINES = new Set([".sobelow-skips", ".dialyzer_ignore.exs", ".gitleaksignore"]);
const GUARDED_FILES = new Set([".credo.exs", ".sobelow-conf", "coveralls.json", ".gitattributes", ".gitleaks.toml"]);
const ESCAPE_HATCH =
  /credo:disable|sobelow_skip|@dialyzer\b|dirty_xrefs|safety-assured|--fail-above|ignore_advisories|ignore_retirements|ignore_warnings|continue-on-error|@(?:module|describe)?tag\b.*\bskip|gitleaks:allow|start_after|skip_checks/;
const MIX_GUARDRAIL =
  /precommit|credo|sobelow|dialyzer|boundary|xref|audit|warnings-as-errors|all-warnings|deps\.unlock|compilers|excellent_migrations|ignore_|\bdocs\b/;
const MARKER = /^\s*# (?:>>>|<<<) baseline/;
const FILE_HEADER = /^diff --git a\/.+ b\/(.+)$/;
const HUNK_HEADER = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/;
const FAIL_ABOVE = /--fail-above (\d+)/;

/** Reads `git diff -U0` output into the lines each file lost and gained. */
export function parseDiff(unified: string): FileDiff[] {
  const files: FileDiff[] = [];
  let current: FileDiff | null = null;
  let inHunk = false;
  let oldLine = 0;
  let newLine = 0;
  for (const raw of unified.split("\n")) {
    const file = raw.match(FILE_HEADER);
    const hunk = raw.match(HUNK_HEADER);
    if (file) {
      current = { path: file[1], removed: [], added: [] };
      files.push(current);
      inHunk = false;
    } else if (raw.startsWith("diff --git ")) {
      throw new Error(`cannot read the file name in: ${raw}`);
    } else if (hunk && current) {
      oldLine = Number(hunk[1]);
      newLine = Number(hunk[2]);
      inHunk = true;
    } else if (current && inHunk && raw.startsWith("-")) {
      current.removed.push({ line: oldLine++, text: raw.slice(1) });
    } else if (current && inHunk && raw.startsWith("+")) {
      current.added.push({ line: newLine++, text: raw.slice(1) });
    }
  }
  return files;
}

/** The 1-based, inclusive line ranges from `# >>> baseline` to `# <<< baseline`. */
export function baselineRanges(text: string): [number, number][] {
  const ranges: [number, number][] = [];
  let start = 0;
  const lines = text.split("\n");
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index].trim();
    if (start === 0 && line.startsWith("# >>> baseline")) start = index + 1;
    else if (start > 0 && line.startsWith("# <<< baseline")) {
      ranges.push([start, index + 1]);
      start = 0;
    }
  }
  if (start > 0) ranges.push([start, Number.MAX_SAFE_INTEGER]);
  return ranges;
}

export function findViolations(diffs: FileDiff[], read: (path: string, side: "old" | "new") => string): Violation[] {
  return diffs.flatMap((diff) => fileViolations(diff, read));
}

function fileViolations(diff: FileDiff, read: (path: string, side: "old" | "new") => string): Violation[] {
  const name = diff.path.slice(diff.path.lastIndexOf("/") + 1);
  const whole = WHOLE_FILE_BASELINES.has(name);
  const oldRanges = baselineRanges(read(diff.path, "old"));
  const newRanges = baselineRanges(read(diff.path, "new"));
  const inside = (ranges: [number, number][]) => (line: Line) =>
    whole || ranges.some(([from, to]) => line.line >= from && line.line <= to);
  const isMarker = (line: Line) => MARKER.test(line.text);
  const added = diff.added.filter((line) => !isMarker(line));
  const removed = diff.removed.filter((line) => !isMarker(line));
  const block = unpaired(added.filter(inside(newRanges)), removed.filter(inside(oldRanges)), true);
  const rest = unpaired(
    added.filter((line) => !inside(newRanges)(line)),
    removed.filter((line) => !inside(oldRanges)(line)),
    false,
  );
  const flag = (reason: string) => (line: Line): Violation => ({
    path: diff.path,
    line: line.line,
    text: line.text.trim(),
    reason,
  });
  const markers = [...diff.removed, ...diff.added].filter(isMarker).map(flag("moves a baseline marker"));
  const escapeHatches = (lines: Line[]) =>
    lines.filter((line) => ESCAPE_HATCH.test(line.text)).map(flag("adds an escape hatch"));
  const guarded = GUARDED_FILES.has(name) || diff.path.startsWith(".github/");
  const mixExs = name === "mix.exs";
  return [
    ...markers,
    ...block.added.map(flag("adds to a baseline")),
    ...(guarded
      ? [
        ...rest.added.map(flag("changes a guarded file")),
        ...rest.removed.map(flag("removes a line from a guarded file")),
      ]
      : escapeHatches(rest.added)),
    ...(mixExs
      ? [
        ...rest.added.filter((line) => !ESCAPE_HATCH.test(line.text) && MIX_GUARDRAIL.test(line.text)).map(
          flag("changes a guardrail line in mix.exs"),
        ),
        ...rest.removed.filter((line) => MIX_GUARDRAIL.test(line.text)).map(
          flag("removes a guardrail line from mix.exs"),
        ),
      ]
      : []),
  ];
}

/** Pairs each added line with a removed line it merely rewrites; returns what is left on each side. */
function unpaired(added: Line[], removed: Line[], inBaseline: boolean): { added: Line[]; removed: Line[] } {
  const left = [...removed];
  const lonely: Line[] = [];
  for (const line of added) {
    const index = left.findIndex((candidate) =>
      rewrites(line.text, candidate.text) || (inBaseline && empties(line.text, candidate.text))
    );
    if (index === -1) lonely.push(line);
    else left.splice(index, 1);
  }
  return { added: lonely, removed: left };
}

function rewrites(added: string, removed: string): boolean {
  const normalize = (text: string) => text.trim().replace(/,$/, "");
  if (normalize(added) === normalize(removed)) return true;
  const [newLimit, oldLimit] = [added.match(FAIL_ABOVE), removed.match(FAIL_ABOVE)];
  return newLimit !== null && oldLimit !== null && Number(newLimit[1]) < Number(oldLimit[1]) &&
    added.replace(FAIL_ABOVE, "") === removed.replace(FAIL_ABOVE, "");
}

/** `X => []` or `baseline = %{}` replacing the opening line `X => [` or `baseline = %{`. */
function empties(added: string, removed: string): boolean {
  const normalize = (text: string) => text.trim().replace(/,$/, "");
  const [emptied, opening] = [normalize(added), normalize(removed)];
  return (emptied.endsWith("[]") || emptied.endsWith("%{}")) && opening === emptied.slice(0, -1);
}

async function git(args: string[]): Promise<{ code: number; out: string; err: string }> {
  const { code, stdout, stderr } = await new Deno.Command("git", { args, stdout: "piped", stderr: "piped" }).output();
  return { code, out: new TextDecoder().decode(stdout), err: new TextDecoder().decode(stderr) };
}

async function main(): Promise<number> {
  const [base] = Deno.args;
  if (!base) {
    console.error("usage: guardrails_gate.ts <base-sha>");
    return 2;
  }
  const mergeBase = await git(["merge-base", base, "HEAD"]);
  if (mergeBase.code !== 0) {
    console.error(`no merge base between ${base} and HEAD`);
    return 2;
  }
  const from = mergeBase.out.trim();
  // --text, --no-ext-diff and --no-textconv: a .gitattributes in the PR cannot hide a change.
  const diff = await git([
    "-c",
    "core.quotePath=false",
    "diff",
    "-U0",
    "--no-color",
    "--no-renames",
    "--text",
    "--no-ext-diff",
    "--no-textconv",
    "--src-prefix=a/",
    "--dst-prefix=b/",
    from,
    "HEAD",
  ]);
  if (diff.code !== 0) {
    console.error(`git diff failed: ${diff.err.trim()}`);
    return 2;
  }
  let diffs: FileDiff[];
  try {
    diffs = parseDiff(diff.out);
  } catch (error) {
    console.error(String(error));
    return 2;
  }
  const texts = new Map<string, string>();
  for (const { path } of diffs) {
    for (const [side, rev] of [["old", from], ["new", "HEAD"]] as const) {
      const shown = await git(["show", `${rev}:${path}`]);
      texts.set(`${side}:${path}`, shown.code === 0 ? shown.out : "");
    }
  }
  const violations = findViolations(diffs, (path, side) => texts.get(`${side}:${path}`) ?? "");
  if (violations.length === 0) return 0;
  console.log(
    "::error::This PR changes the guardrails. A reviewer adds the guardrails-changed label once the change is justified.",
  );
  for (const v of violations) console.log(`${v.path}:${v.line} ${v.reason}: ${v.text}`);
  return 1;
}

if (import.meta.main) Deno.exit(await main());
