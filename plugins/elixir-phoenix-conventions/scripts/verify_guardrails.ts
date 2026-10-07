// plugins/elixir-phoenix-conventions/scripts/verify_guardrails.ts
/**
 * End-to-end check of the elixir-guardrails templates. Builds a throwaway Phoenix app,
 * applies the templates and baselines, expects `mix precommit` to pass, then plants
 * one violation at a time and expects `mix precommit` to fail on the check that owns it.
 *
 * Usage: deno run -A verify_guardrails.ts --work <dir> [--only <id,id>]
 * Needs Elixir 1.20.4-otp-29 with the phx_new archive, Postgres on localhost:5432 (postgres/postgres,
 * phx.new's defaults), actionlint through mise, and network access. The app stays in <dir>.
 */
import { parseArgs } from "jsr:@std/cli@1/parse-args";
import { ensureDir } from "jsr:@std/fs@1";
import { dirname, fromFileUrl, join } from "jsr:@std/path@1";
import { credoBaseline, replaceBaselineBlock } from "./lib/credo_baseline.ts";
import { parseSnippet, patchMixExs } from "./lib/patch_mix.ts";
import { type Violation, VIOLATIONS } from "./lib/violations.ts";

const here = dirname(fromFileUrl(import.meta.url));
const templates = join(here, "..", "skills", "elixir-guardrails", "templates");
const TOOL_VERSIONS = "elixir 1.20.4-otp-29\nerlang 29.0.6\n";
const PG_PORT = 5432;
const ACTIONLINT = ["mise", "exec", "ubi:rhysd/actionlint@1.7.12", "--", "actionlint"];
const GIT = ["git", "-c", "user.email=verify@example.com", "-c", "user.name=verify"];

interface Run {
  code: number;
  stdout: string;
  output: string;
}

interface Result {
  id: string;
  pass: boolean;
  detail: string;
}

async function run(cmd: string[], cwd: string, env: Record<string, string> = {}): Promise<Run> {
  try {
    const { code, stdout, stderr } = await new Deno.Command(cmd[0], {
      args: cmd.slice(1),
      cwd,
      env,
      stdout: "piped",
      stderr: "piped",
    }).output();
    const out = new TextDecoder().decode(stdout);
    return { code, stdout: out, output: out + new TextDecoder().decode(stderr) };
  } catch (error) {
    return { code: 127, stdout: "", output: String(error) };
  }
}

async function must(cmd: string[], cwd: string, env: Record<string, string> = {}): Promise<Run> {
  const result = await run(cmd, cwd, env);
  if (result.code !== 0) throw new Error(`${cmd.join(" ")} exited ${result.code}:\n${tail(result.output)}`);
  return result;
}

function tail(text: string, lines = 40): string {
  return text.trimEnd().split("\n").slice(-lines).join("\n");
}

async function edit(path: string, change: (text: string) => string): Promise<void> {
  const before = await Deno.readTextFile(path);
  const after = change(before);
  if (after === before) throw new Error(`nothing changed in ${path}`);
  await Deno.writeTextFile(path, after);
}

async function copyTemplate(from: string, to: string): Promise<void> {
  const [, ...rest] = (await Deno.readTextFile(join(templates, from))).split("\n");
  await ensureDir(dirname(to));
  await Deno.writeTextFile(to, rest.join("\n"));
}

async function preflight(work: string): Promise<void> {
  const checks: [string, string[], RegExp][] = [
    ["Elixir 1.20", ["elixir", "--version"], /Elixir 1\.20\./],
    ["the phx_new archive", ["mix", "help", "phx.new"], /phx\.new/],
    ["actionlint", [...ACTIONLINT, "--version"], /\d/],
  ];
  for (const [what, cmd, expected] of checks) {
    const result = await run(cmd, work);
    if (result.code !== 0 || !expected.test(result.output)) throw new Error(`missing prerequisite: ${what}`);
  }
  try {
    (await Deno.connect({ hostname: "localhost", port: PG_PORT })).close();
  } catch {
    throw new Error(`missing prerequisite: Postgres on localhost:${PG_PORT}`);
  }
}

async function buildApp(work: string): Promise<string> {
  await must(["mix", "phx.new", "verify_app", "--install"], work);
  return join(work, "verify_app");
}

const BOUNDARIES: [string, string, string][] = [
  ["lib/verify_app.ex", "defmodule VerifyApp do\n", "  use Boundary, deps: [], exports: []\n\n"],
  [
    "lib/verify_app_web.ex",
    "defmodule VerifyAppWeb do\n",
    "  use Boundary,\n    deps: [VerifyApp],\n    exports: [Endpoint],\n    # >>> baseline\n    dirty_xrefs: [\n      VerifyApp.DataCase,\n    ]\n    # <<< baseline\n\n",
  ],
  [
    "lib/verify_app/application.ex",
    "defmodule VerifyApp.Application do\n",
    "  use Boundary, top_level?: true, deps: [VerifyApp, VerifyAppWeb]\n\n",
  ],
];

async function applyTemplates(app: string): Promise<void> {
  const snippet = parseSnippet(await Deno.readTextFile(join(templates, "mix.exs.snippet")));
  await edit(join(app, "mix.exs"), (text) => patchMixExs(text, snippet));
  await copyTemplate("credo.exs", join(app, ".credo.exs"));
  await copyTemplate("sobelow-conf", join(app, ".sobelow-conf"));
  await copyTemplate("dialyzer_ignore.exs", join(app, ".dialyzer_ignore.exs"));
  for await (const entry of walkFiles(join(templates, "github"))) {
    await copyTemplate(join("github", entry), join(app, ".github", entry));
  }
  await ensureDir(join(app, "priv", "plts"));
  await Deno.writeTextFile(join(app, "priv", "plts", ".gitkeep"), "");
  await Deno.writeTextFile(join(app, ".gitignore"), "\n/priv/plts/*.plt\n/priv/plts/*.plt.hash\n", { append: true });
  await Deno.writeTextFile(join(app, ".tool-versions"), TOOL_VERSIONS);
  await Deno.writeTextFile(
    join(app, "config", "test.exs"),
    "\nconfig :phoenix_test, :endpoint, VerifyAppWeb.Endpoint\n",
    { append: true },
  );
  for (const [path, anchor, line] of BOUNDARIES) {
    await edit(join(app, path), (text) => text.replace(anchor, anchor + line));
  }
}

async function* walkFiles(root: string, prefix = ""): AsyncGenerator<string> {
  for await (const entry of Deno.readDir(join(root, prefix))) {
    const path = prefix ? join(prefix, entry.name) : entry.name;
    if (entry.isDirectory) yield* walkFiles(root, path);
    else yield path;
  }
}

async function baseline(app: string): Promise<string[]> {
  await must(["mix", "deps.get"], app);
  await must(["mix", "compile"], app, { MIX_ENV: "test" });
  await must(["mix", "format"], app);
  const credo = await run(["mix", "credo", "--strict", "--format", "json"], app, { MIX_ENV: "test" });
  const credoBlock = credoBaseline(credo.stdout);
  await edit(join(app, ".credo.exs"), (text) => replaceBaselineBlock(text, credoBlock));
  await run(["mix", "sobelow", "--mark-skip-all"], app, { MIX_ENV: "test" });
  await must(["mix", "usage_rules.sync", "--yes"], app, { MIX_ENV: "dev" });
  await must([...GIT, "init", "-q"], app);
  await must([...GIT, "add", "-A"], app);
  await must([...GIT, "commit", "-q", "-m", "clean app with guardrails"], app);
  const skips = await Deno.readTextFile(join(app, ".sobelow-skips")).catch(() => "");
  return [
    `credo baseline: ${(credoBlock.match(/^ {4}"/gm) ?? []).length} file entries`,
    `sobelow skips: ${skips.split("\n").filter((line) => line.trim()).length} lines`,
  ];
}

async function cleanRun(app: string): Promise<Result[]> {
  const precommit = await run(["mix", "precommit"], app);
  const actionlint = await run(ACTIONLINT, app);
  const usageRules = await run(["mix", "usage_rules.sync", "--check"], app, { MIX_ENV: "dev" });
  return [
    { id: "clean: mix precommit", pass: precommit.code === 0, detail: tail(precommit.output) },
    { id: "clean: actionlint", pass: actionlint.code === 0, detail: tail(actionlint.output) },
    { id: "clean: usage_rules.sync --check", pass: usageRules.code === 0, detail: tail(usageRules.output) },
  ];
}

async function seededRun(app: string, violation: Violation): Promise<Result> {
  try {
    for (const change of violation.edits ?? []) {
      await edit(join(app, change.path), (text) => text.replace(change.find, change.replace));
    }
    for (const file of violation.files ?? []) {
      await ensureDir(dirname(join(app, file.path)));
      await Deno.writeTextFile(join(app, file.path), file.content);
    }
    if (violation.precompile) await run(["mix", "compile"], app, { MIX_ENV: "test" });
    const result = await run(["mix", "precommit"], app);
    const pass = result.code !== 0 && violation.expect.test(result.output);
    return { id: violation.id, pass, detail: pass ? `matched ${violation.expect}` : tail(result.output) };
  } finally {
    await must([...GIT, "checkout", "--", "."], app);
    await must([...GIT, "clean", "-fdq"], app);
  }
}

function report(results: Result[]): boolean {
  for (const result of results) {
    console.log(`${result.pass ? "PASS" : "FAIL"} ${result.id}`);
    if (!result.pass) console.log(result.detail.replace(/^/gm, "    "));
  }
  return results.every((result) => result.pass);
}

async function main(): Promise<number> {
  const args = parseArgs(Deno.args, { string: ["work", "only"] });
  if (!args.work) {
    console.error("usage: verify_guardrails.ts --work <dir> [--only <id,id>]");
    return 2;
  }
  const work = args.work;
  await ensureDir(work);
  await Deno.writeTextFile(join(work, ".tool-versions"), TOOL_VERSIONS);
  await preflight(work);
  const app = await buildApp(work);
  await applyTemplates(app);
  for (const line of await baseline(app)) console.log(line);
  const clean = await cleanRun(app);
  if (!report(clean)) return 1;
  const only = args.only?.split(",");
  const selected = VIOLATIONS.filter((violation) => !only || only.includes(violation.id));
  const seeded: Result[] = [];
  for (const violation of selected) seeded.push(await seededRun(app, violation));
  return report(seeded) ? 0 : 1;
}

Deno.exit(await main());
