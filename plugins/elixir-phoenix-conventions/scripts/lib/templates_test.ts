// plugins/elixir-phoenix-conventions/scripts/lib/templates_test.ts
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { dirname, fromFileUrl, join } from "jsr:@std/path@1";
import { parse } from "jsr:@std/yaml@1";
import { credoBaseline, replaceBaselineBlock } from "./credo_baseline.ts";
import { parseSnippet, patchMixExs } from "./patch_mix.ts";

const here = dirname(fromFileUrl(import.meta.url));
const templates = join(here, "..", "..", "skills", "elixir-guardrails", "templates");
const read = (path: string) => Deno.readTextFileSync(join(templates, path));
const decode = (bytes: Uint8Array) => new TextDecoder().decode(bytes);

async function sh(cmd: string[], cwd: string, env: Record<string, string> = {}) {
  const { code, stdout, stderr } = await new Deno.Command(cmd[0], {
    args: cmd.slice(1),
    cwd,
    env,
    stdout: "piped",
    stderr: "piped",
  }).output();
  return { code, out: decode(stdout) + decode(stderr) };
}

// ---- mix.exs.snippet ----

Deno.test("the mix snippet patches a Phoenix app into valid Elixir", async () => {
  const mix = patchMixExs(
    Deno.readTextFileSync(join(here, "testdata", "phx_mix.exs")),
    parseSnippet(read("mix.exs.snippet")),
  );
  for (
    const step of [
      "compile --all-warnings --warnings-as-errors",
      "deps.unlock --check-unused",
      "credo --strict",
      "xref graph --label compile-connected --fail-above 0",
      "sobelow",
      "deps.audit",
      "cmd mix hex.audit",
      "MIX_ENV=dev mix dialyzer",
      "MIX_ENV=dev mix docs --warnings-as-errors",
      "test --warnings-as-errors",
    ]
  ) {
    assertStringIncludes(mix, step);
  }
  const path = await Deno.makeTempFile({ suffix: ".exs" });
  await Deno.writeTextFile(path, mix);
  const { code, out } = await sh(["elixir", "-e", `Code.string_to_quoted!(File.read!("${path}"))`], Deno.cwd());
  assertEquals(code, 0, out);
});

// ---- credo.exs ----

const INSPECT_CONFIG = `
{config, _} = Code.eval_file(".credo.exs")
[c] = config.configs
IO.puts("strict=#{c.strict}")
IO.puts("requires=#{Enum.join(c.requires, ",")}")
IO.puts("migrations=#{Enum.member?(c.files.included, "priv/repo/migrations/")}")
for {check, params} <- c.checks.extra do
  files = Keyword.get(params, :files, %{})
  IO.puts("check=#{inspect(check)} included=#{Enum.join(Map.get(files, :included, []), ",")} excluded=#{Enum.join(Map.get(files, :excluded, []), ",")}")
end
`;

const INSPECT_PARAMS = `
{config, _} = Code.eval_file(".credo.exs")
[c] = config.configs
for {check, params} <- c.checks.extra, do: IO.puts("#{inspect(check)} params=#{inspect(params)}")
`;

async function evalCredo(
  opts: { phoenixTest: boolean; issues?: { check: string; filename: string }[]; script?: string },
) {
  const dir = await Deno.makeTempDir();
  const block = credoBaseline(JSON.stringify({ issues: opts.issues ?? [] }));
  await Deno.writeTextFile(join(dir, ".credo.exs"), replaceBaselineBlock(read("credo.exs"), block));
  if (opts.phoenixTest) await Deno.mkdir(join(dir, "deps", "phoenix_test"), { recursive: true });
  const { code, out } = await sh(["elixir", "-e", opts.script ?? INSPECT_CONFIG], dir);
  assertEquals(code, 0, out);
  return out;
}

const GUARDRAIL_CHECKS = [
  "Jump.CredoChecks.VacuousTest",
  "Jump.CredoChecks.TestHasNoAssertions",
  "Jump.CredoChecks.WeakAssertion",
  "Jump.CredoChecks.UnusedLiveViewAssign",
  "Jump.CredoChecks.AssertElementSelectorCanNeverFail",
  "OeditusCredo.Check.Warning.UnmanagedTask",
  "OeditusCredo.Check.Warning.BlockingInPlug",
  "OeditusCredo.Check.Warning.SyncOverAsync",
  "OeditusCredo.Check.Warning.MissingHandleAsync",
  "OeditusCredo.Check.Warning.SwallowingException",
  "OeditusCredo.Check.Warning.NPlusOneQuery",
  "OeditusCredo.Check.Warning.MissingPreload",
  "OeditusCredo.Check.Warning.InefficientFilter",
  "ExSlop.Check.Refactor.CaseTrueFalse",
  "ExcellentMigrations.CredoCheck.MigrationsSafety",
];

Deno.test("credo.exs is strict, includes migrations and adds every guardrail check", async () => {
  const out = await evalCredo({ phoenixTest: false });
  assertStringIncludes(out, "strict=true");
  assertStringIncludes(out, "migrations=true");
  for (const check of GUARDRAIL_CHECKS) assertStringIncludes(out, `check=${check} `);
});

Deno.test("credo.exs without phoenix_test needs no requires and skips NoOpenBrowser", async () => {
  const out = await evalCredo({ phoenixTest: false });
  assertStringIncludes(out, "requires=\n");
  assert(!out.includes("NoOpenBrowser"));
});

Deno.test("credo.exs with phoenix_test loads NoOpenBrowser for test files", async () => {
  const out = await evalCredo({ phoenixTest: true });
  assertStringIncludes(out, "requires=./deps/phoenix_test/lib/phoenix_test/credo/**/*.ex");
  assertStringIncludes(out, "check=PhoenixTest.Credo.NoOpenBrowser included=test/ excluded=\n");
});

Deno.test("credo.exs keeps Credo's own params for a baselined default check", async () => {
  // Credo's `extra:` replaces a check's params instead of merging them.
  const out = await evalCredo({
    phoenixTest: false,
    issues: [{ check: "Credo.Check.Design.AliasUsage", filename: "lib/a.ex" }],
    script: INSPECT_PARAMS,
  });
  assertStringIncludes(
    out,
    `Credo.Check.Design.AliasUsage params=[priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0, files: %{excluded: ["lib/a.ex"]}]\n`,
  );
});

Deno.test("credo.exs merges the baseline into existing files params", async () => {
  const out = await evalCredo({
    phoenixTest: true,
    issues: [
      { check: "PhoenixTest.Credo.NoOpenBrowser", filename: "test/old_test.exs" },
      { check: "Credo.Check.Readability.ModuleDoc", filename: "lib/a.ex" },
      { check: "Credo.Check.Readability.ModuleDoc", filename: "lib/b.ex" },
    ],
  });
  assertStringIncludes(out, "check=PhoenixTest.Credo.NoOpenBrowser included=test/ excluded=test/old_test.exs\n");
  assertStringIncludes(out, "check=Credo.Check.Readability.ModuleDoc included= excluded=lib/a.ex,lib/b.ex\n");
});

Deno.test("the shipped credo.exs has one empty baseline block", () => {
  const credoExs = read("credo.exs");
  assertStringIncludes(credoExs, "\nbaseline = %{}\n# <<< baseline\n");
  assertEquals(replaceBaselineBlock(credoExs, "BLOCK").includes("BLOCK"), true);
});

// ---- code-quality.yml ----

type Workflow = { jobs: Record<string, { if: string; steps: { run?: string; uses?: string }[] }> };
const gateJob = () => (parse(read("github/workflows/code-quality.yml")) as Workflow).jobs["guardrails-changed"];

Deno.test("the guardrails-changed job is skipped by the label and sets up Deno", () => {
  const job = gateJob();
  assertStringIncludes(job.if, "!contains(github.event.pull_request.labels.*.name, 'guardrails-changed')");
  assert(job.steps.some((step) => step.uses === "denoland/setup-deno@v2"));
});

/** Runs the gate step's script in a repo whose base and head commits hold the given gate scripts. */
async function runGateStep(baseGate: string | null, headGate: string) {
  const repo = await Deno.makeTempDir();
  const runnerTemp = await Deno.makeTempDir();
  const git = (...args: string[]) => sh(["git", "-c", "user.email=t@example.com", "-c", "user.name=t", ...args], repo);
  const gatePath = join(repo, ".github", "scripts", "guardrails_gate.ts");
  await git("init", "-q", "-b", "main");
  await Deno.writeTextFile(join(repo, "README.md"), "app\n");
  if (baseGate !== null) {
    await Deno.mkdir(dirname(gatePath), { recursive: true });
    await Deno.writeTextFile(gatePath, baseGate);
  }
  await git("add", "-A");
  await git("commit", "-q", "-m", "base");
  const baseSha = (await git("rev-parse", "HEAD")).out.trim();
  await Deno.mkdir(dirname(gatePath), { recursive: true });
  await Deno.writeTextFile(gatePath, headGate);
  await git("add", "-A");
  await git("commit", "-q", "-m", "change");
  const steps = gateJob().steps;
  const path = `${dirname(Deno.execPath())}:${Deno.env.get("PATH")}`;
  return await sh(["bash", "-e", "-c", steps[steps.length - 1].run!], repo, {
    BASE_SHA: baseSha,
    RUNNER_TEMP: runnerTemp,
    PATH: path,
  });
}

Deno.test("the gate step runs the base branch's copy of the gate, not the PR's", async () => {
  const { code, out } = await runGateStep(`console.log("base gate");`, `console.log("pr gate");`);
  assertEquals(code, 0, out);
  assertStringIncludes(out, "base gate");
  assert(!out.includes("pr gate"), out);
});

Deno.test("the gate step runs the PR's copy when the base has none (the install PR)", async () => {
  const { code, out } = await runGateStep(null, `console.log("pr gate");`);
  assertEquals(code, 0, out);
  assertStringIncludes(out, "pr gate");
});

// ---- dependabot.yml ----

interface DependabotUpdate {
  "package-ecosystem": string;
  schedule: { interval: string };
  groups: Record<string, { patterns: string[] }>;
  "commit-message": { prefix: string };
  labels?: string[];
}

Deno.test("dependabot: mix and github-actions, monthly, grouped, titles pass lint-pr", () => {
  const config = parse(read("github/dependabot.yml")) as { updates: DependabotUpdate[] };
  const byEcosystem = Object.fromEntries(config.updates.map((u) => [u["package-ecosystem"], u]));
  for (const ecosystem of ["mix", "github-actions"]) {
    const update = byEcosystem[ecosystem];
    assertEquals(update.schedule.interval, "monthly");
    assert(Object.values(update.groups).some((g) => g.patterns.includes("*")));
    assertEquals(update["commit-message"].prefix, "chore");
  }
  assert(byEcosystem["github-actions"].labels?.includes("guardrails-changed"));
});

// ---- action pins ----

Deno.test("workflows pin the agreed action versions", () => {
  const files = ["build-and-test", "code-quality", "dialyzer", "actionlint", "lint-pr"].map((name) =>
    read(`github/workflows/${name}.yml`)
  );
  const uses = [...files, read("github/actions/elixir-setup/action.yml")].join("\n").match(/uses: \S+/g) ?? [];
  for (const use of uses) {
    const ref = use.slice("uses: ".length);
    if (ref.startsWith("./")) continue;
    assert(
      [
        "actions/checkout@v7",
        "actions/cache@v6",
        "actions/cache/restore@v6",
        "actions/cache/save@v6",
        "erlef/setup-beam@v1",
        "denoland/setup-deno@v2",
        "amannn/action-semantic-pull-request@48f256284bd46cdaab1048c3721360e808335d50",
      ].includes(ref),
      `unexpected action ${ref}`,
    );
  }
});
