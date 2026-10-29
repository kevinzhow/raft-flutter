#!/usr/bin/env node
// Generates lib/features/agent_metadata_catalog.dart from the pinned Raft source
// (packages/shared/src): the display label of every model id of every runtime
// (`RUNTIME_MODELS`, Built-in / Pi / Kimi SDK included, which agent_runtime_catalog.dart
// skips), and the agent activity / activity detail kind sets. Ported from the
// agent-metadata-presence generator (generate_catalog.ts) that produced the
// first version of the file; the output format is unchanged.
//
//   RAFT_SOURCE=<raft-source checkout> [DART=<dart>] node tool/gen_agent_metadata_catalog.mjs
//
// The source checkout is only read (esbuild bundles packages/shared/src/index.ts
// into a temp file). The result is run through `dart format` (DART, default
// `dart` on PATH; use the pinned SDK's dart) so the committed file is stable.
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, readdirSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = process.env.RAFT_SOURCE;
if (!root) throw new Error("set RAFT_SOURCE to the raft-source checkout");
const pnpm = join(root, "node_modules/.pnpm");
const esbuildDir = readdirSync(pnpm).filter((d) => d.startsWith("esbuild@")).sort().at(-1);
const esbuild = join(pnpm, esbuildDir, "node_modules/esbuild/bin/esbuild");
const out = join(mkdtempSync(join(tmpdir(), "raft-shared-")), "shared.cjs");
execFileSync(esbuild, [join(root, "packages/shared/src/index.ts"), "--bundle", "--platform=node", "--format=cjs", `--outfile=${out}`, "--log-level=error"]);
const { RUNTIME_MODELS, AGENT_ACTIVITIES, AGENT_ACTIVITY_DETAIL_KINDS } = createRequire(import.meta.url)(out);

const models = Object.fromEntries(
  Object.entries(RUNTIME_MODELS).map(([runtime, values]) => [runtime, Object.fromEntries(values.map((m) => [m.id, m.label]))]),
);
const literal = (s) => "'" + s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$") + "'";

let dart = "// Generated from pinned shared RUNTIME_MODELS. Regenerate with tool/gen_agent_metadata_catalog.mjs.\nconst sourceRuntimeModelLabels = <String, Map<String, String>>{\n";
for (const [runtime, rows] of Object.entries(models)) {
  dart += `  ${literal(runtime)}: {\n`;
  for (const [id, label] of Object.entries(rows)) dart += `    ${literal(id)}: ${literal(label)},\n`;
  dart += "  },\n";
}
dart += "};\n";
dart += `const sourceAgentActivities = <String>{${AGENT_ACTIVITIES.map(literal).join(", ")}};\n`;
dart += `const sourceAgentDetailKinds = <String>{${AGENT_ACTIVITY_DETAIL_KINDS.map(literal).join(", ")}};\n`;

const dest = join(dirname(fileURLToPath(import.meta.url)), "../lib/features/agent_metadata_catalog.dart");
writeFileSync(dest, dart);
execFileSync(process.env.DART ?? "dart", ["format", dest], { stdio: "inherit" });
console.log(JSON.stringify({
  runtimes: Object.keys(models).length,
  models: Object.values(models).reduce((s, m) => s + Object.keys(m).length, 0),
  wrote: dest,
}));
