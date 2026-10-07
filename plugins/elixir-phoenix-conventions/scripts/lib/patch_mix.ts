// plugins/elixir-phoenix-conventions/scripts/lib/patch_mix.ts
export interface MixSnippet {
  project: string;
  deps: string;
  precommit: string;
  cli: string;
}

const SECTIONS = ["project", "deps", "precommit", "cli"] as const;

/** Splits `templates/mix.exs.snippet` at its `# >>> <section>` lines. */
export function parseSnippet(text: string): MixSnippet {
  const parts: Record<string, string[]> = {};
  let current: string | null = null;
  for (const line of text.split("\n")) {
    const marker = line.match(/^# >>> (\w+)$/);
    if (marker) {
      current = marker[1];
      parts[current] = [];
    } else if (current) {
      parts[current].push(line);
    }
  }
  const [project, deps, precommit, cli] = SECTIONS.map((name) => {
    const body = trimBlankLines(parts[name] ?? []);
    if (!body) throw new Error(`snippet has no "${name}" section`);
    return body;
  });
  return { project, deps, precommit, cli };
}

/**
 * Merges the snippet into a fresh `mix phx.new` 1.8 `mix.exs`. Real apps are merged
 * by hand (elixir-guardrails skill), so anything unexpected is an error, not a guess.
 */
export function patchMixExs(mix: string, snippet: MixSnippet): string {
  rejectExisting(mix, snippet);
  let out = replaceOnce(
    mix,
    /^( *)deps: deps\(\),\n/m,
    (match) => `${match}${snippet.project}\n`,
    "`deps: deps(),` in project/0",
  );
  out = addBoundaryCompiler(out);
  out = replaceOnce(out, /defp deps do\n *\[\n/, (match) => `${match}${snippet.deps}\n`, "`defp deps do [`");
  out = replaceOnce(out, /^ *precommit: \[[^\]]*\]/m, () => snippet.precommit, "a `precommit:` alias");
  out = replaceOnce(out, /preferred_envs: \[[^\]]*\]/, () => snippet.cli.trim(), "`preferred_envs:` in cli/0");
  return out;
}

function addBoundaryCompiler(mix: string): string {
  if (/compilers: \[[^\]]*:boundary/.test(mix)) return mix;
  if (/compilers: \[/.test(mix)) return mix.replace("compilers: [", "compilers: [:boundary, ");
  return replaceOnce(
    mix,
    /^( *)deps: deps\(\),\n/m,
    (match, indent) => `${match}${indent}compilers: [:boundary] ++ Mix.compilers(),\n`,
    "`deps: deps(),` in project/0",
  );
}

function rejectExisting(mix: string, snippet: MixSnippet): void {
  for (const [, dep] of snippet.deps.matchAll(/\{:(\w+),/g)) {
    if (mix.includes(`{:${dep},`)) throw new Error(`mix.exs already has :${dep} — merge it by hand`);
  }
  for (const [, key] of snippet.project.matchAll(/^ {6}(\w+):/gm)) {
    if (new RegExp(`^\\s*${key}:`, "m").test(mix)) throw new Error(`mix.exs already has ${key} — merge it by hand`);
  }
}

function replaceOnce(
  text: string,
  pattern: RegExp,
  replacer: (match: string, ...groups: string[]) => string,
  what: string,
): string {
  if (!pattern.test(text)) throw new Error(`mix.exs has no ${what}`);
  return text.replace(pattern, replacer as (substring: string, ...args: unknown[]) => string);
}

function trimBlankLines(lines: string[]): string {
  let start = 0;
  let end = lines.length;
  while (start < end && lines[start].trim() === "") start++;
  while (end > start && lines[end - 1].trim() === "") end--;
  return lines.slice(start, end).join("\n");
}
