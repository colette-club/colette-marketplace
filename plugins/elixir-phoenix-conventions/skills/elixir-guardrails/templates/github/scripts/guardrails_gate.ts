// templates/github/scripts/guardrails_gate.ts — becomes the app's .github/scripts/guardrails_gate.ts
/**
 * The guardrails-changed gate: fails a pull request that weakens a guardrail. A reviewer
 * who accepts the change adds the `guardrails-changed` label, and the workflow skips this job.
 *
 * - Baselines (`.sobelow-skips`, `.dialyzer_ignore.exs`, and lines from `# >>> baseline`
 *   to `# <<< baseline`): deleting lines passes, adding one fails.
 * - Guarded files (`.credo.exs` outside its baseline, `.sobelow-conf`, `coveralls.json`,
 *   `.github/`): any other change fails.
 * - Any other file: adding an escape hatch (`credo:disable`, `sobelow_skip`, …) fails.
 *
 * A line re-added with only its indentation or trailing comma changed is not an addition,
 * and lowering a `--fail-above` number is allowed everywhere.
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

const WHOLE_FILE_BASELINES = new Set([".sobelow-skips", ".dialyzer_ignore.exs"]);
const GUARDED_FILES = new Set([".credo.exs", ".sobelow-conf", "coveralls.json"]);
const ESCAPE_HATCH =
  /credo:disable|sobelow_skip|@dialyzer \{:nowarn|dirty_xrefs|safety-assured|--fail-above|ignore_advisories|ignore_retirements|continue-on-error|@tag :skip/;
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
  const whole = WHOLE_FILE_BASELINES.has(diff.path);
  const oldRanges = baselineRanges(read(diff.path, "old"));
  const newRanges = baselineRanges(read(diff.path, "new"));
  const inside = (ranges: [number, number][]) => (line: Line) =>
    whole || ranges.some(([from, to]) => line.line >= from && line.line <= to);
  const block = unpaired(diff.added.filter(inside(newRanges)), diff.removed.filter(inside(oldRanges)));
  const rest = unpaired(
    diff.added.filter((line) => !inside(newRanges)(line)),
    diff.removed.filter((line) => !inside(oldRanges)(line)),
  );
  const flag = (reason: string) => (line: Line): Violation => ({
    path: diff.path,
    line: line.line,
    text: line.text.trim(),
    reason,
  });
  const guarded = GUARDED_FILES.has(diff.path) || diff.path.startsWith(".github/");
  return [
    ...block.added.map(flag("adds to a baseline")),
    ...(guarded
      ? [
        ...rest.added.map(flag("changes a guarded file")),
        ...rest.removed.map(flag("removes a line from a guarded file")),
      ]
      : rest.added.filter((line) => ESCAPE_HATCH.test(line.text)).map(flag("adds an escape hatch"))),
  ];
}

/** Pairs each added line with a removed line it merely rewrites; returns what is left on each side. */
function unpaired(added: Line[], removed: Line[]): { added: Line[]; removed: Line[] } {
  const left = [...removed];
  const lonely: Line[] = [];
  for (const line of added) {
    const index = left.findIndex((candidate) => rewrites(line.text, candidate.text));
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

async function git(args: string[]): Promise<{ code: number; out: string }> {
  const { code, stdout } = await new Deno.Command("git", { args, stdout: "piped", stderr: "null" }).output();
  return { code, out: new TextDecoder().decode(stdout) };
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
  const diffs = parseDiff((await git(["diff", "-U0", "--no-color", "--no-renames", from, "HEAD"])).out);
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
