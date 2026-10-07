// plugins/elixir-phoenix-conventions/scripts/lib/patch_mix_test.ts
import { assert, assertEquals, assertStringIncludes, assertThrows } from "jsr:@std/assert@1";
import { dirname, fromFileUrl, join } from "jsr:@std/path@1";
import { parseSnippet, patchMixExs } from "./patch_mix.ts";

const here = dirname(fromFileUrl(import.meta.url));
const fixture = () => Deno.readTextFileSync(join(here, "testdata", "phx_mix.exs"));

const SNIPPET = [
  "# a comment above the first marker is ignored",
  "# >>> project",
  "      test_coverage: [tool: ExCoveralls],",
  "# >>> deps",
  `      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},`,
  "# >>> precommit",
  "      precommit: [",
  `        "credo --strict"`,
  "      ]",
  "# >>> cli",
  "      preferred_envs: [precommit: :test, coveralls: :test]",
  "",
].join("\n");

Deno.test("parseSnippet splits the four sections", () => {
  const snippet = parseSnippet(SNIPPET);
  assertEquals(snippet.project, "      test_coverage: [tool: ExCoveralls],");
  assertEquals(snippet.cli, "      preferred_envs: [precommit: :test, coveralls: :test]");
  assertStringIncludes(snippet.precommit, `"credo --strict"`);
});

Deno.test("parseSnippet rejects a snippet missing a section", () => {
  assertThrows(() => parseSnippet("# >>> project\n  a: 1,\n"), Error, `no "deps" section`);
});

Deno.test("patchMixExs adds project keys after deps: deps()", () => {
  assertStringIncludes(
    patchMixExs(fixture(), parseSnippet(SNIPPET)),
    "deps: deps(),\n      test_coverage: [tool: ExCoveralls],\n",
  );
});

Deno.test("patchMixExs puts :boundary first in an existing compilers list", () => {
  assertStringIncludes(
    patchMixExs(fixture(), parseSnippet(SNIPPET)),
    "compilers: [:boundary, :phoenix_live_view] ++ Mix.compilers()",
  );
});

Deno.test("patchMixExs adds a compilers line when there is none", () => {
  const mix = fixture().replace("      compilers: [:phoenix_live_view] ++ Mix.compilers(),\n", "");
  assertStringIncludes(patchMixExs(mix, parseSnippet(SNIPPET)), "compilers: [:boundary] ++ Mix.compilers(),");
});

Deno.test("patchMixExs adds deps at the top of the deps list", () => {
  assertStringIncludes(patchMixExs(fixture(), parseSnippet(SNIPPET)), `defp deps do\n    [\n      {:credo, "~> 1.7"`);
});

Deno.test("patchMixExs replaces the generated precommit alias", () => {
  const patched = patchMixExs(fixture(), parseSnippet(SNIPPET));
  assertStringIncludes(patched, `      precommit: [\n        "credo --strict"\n      ]\n    ]`);
  assert(!patched.includes("deps.unlock --unused"));
});

Deno.test("patchMixExs replaces preferred_envs", () => {
  assertStringIncludes(
    patchMixExs(fixture(), parseSnippet(SNIPPET)),
    "preferred_envs: [precommit: :test, coveralls: :test]\n",
  );
});

Deno.test("patchMixExs refuses a dep the file already has", () => {
  const mix = fixture().replace(`{:phoenix, "~> 1.8.1"},`, `{:phoenix, "~> 1.8.1"},\n      {:credo, "~> 1.7"},`);
  assertThrows(() => patchMixExs(mix, parseSnippet(SNIPPET)), Error, "already has :credo");
});

Deno.test("patchMixExs refuses a project key the file already has", () => {
  const mix = fixture().replace("deps: deps(),", "deps: deps(),\n      test_coverage: [tool: Other],");
  assertThrows(() => patchMixExs(mix, parseSnippet(SNIPPET)), Error, "already has test_coverage");
});

Deno.test("patchMixExs refuses a file with no precommit alias", () => {
  const mix = fixture().replace(/,\n\s*precommit: \[[^\]]*\]/, "");
  assertThrows(() => patchMixExs(mix, parseSnippet(SNIPPET)), Error, "precommit");
});

Deno.test("the patched file is valid Elixir", async () => {
  const path = await Deno.makeTempFile({ suffix: ".exs" });
  await Deno.writeTextFile(path, patchMixExs(fixture(), parseSnippet(SNIPPET)));
  const { code, stderr } = await new Deno.Command("elixir", {
    args: ["-e", `Code.string_to_quoted!(File.read!("${path}"))`],
    stderr: "piped",
  }).output();
  assertEquals(code, 0, new TextDecoder().decode(stderr));
});
