// plugins/elixir-phoenix-conventions/scripts/credo_baseline.ts
// Usage: deno run --allow-read --allow-write credo_baseline.ts <credo-output.json> <.credo.exs>
// Rewrites the baseline block of .credo.exs from `mix credo --strict --format json` output.
import { credoBaseline, replaceBaselineBlock } from "./lib/credo_baseline.ts";

const [jsonPath, credoPath] = Deno.args;
if (!jsonPath || !credoPath) {
  console.error("usage: credo_baseline.ts <credo-output.json> <.credo.exs>");
  Deno.exit(2);
}
const block = credoBaseline(await Deno.readTextFile(jsonPath));
await Deno.writeTextFile(credoPath, replaceBaselineBlock(await Deno.readTextFile(credoPath), block));
console.log(`baseline: ${(block.match(/^ {4}"/gm) ?? []).length} file entries`);
