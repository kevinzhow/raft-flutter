// Runs a raft-source checkout's Artifacts content Worker (packages/content-worker, its dist/ from
// `wrangler deploy --dry-run`) in Miniflare, as the Worker's own test harness does, for a local
// test stack started by tool/raft-stack. Tickets live in an in-memory D1 (reset on restart).
// Usage: node tool/raft-content-worker.mjs <content-worker dir> <bindings KEY=VALUE file> <port>
import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { createRequire } from "node:module";

const [dir, envFile, portArg] = process.argv.slice(2);
if (!dir || !envFile || !/^\d+$/.test(portArg ?? "")) {
  console.error("usage: raft-content-worker.mjs <content-worker dir> <bindings file> <port>");
  process.exit(2);
}
const require = createRequire(join(dir, "package.json"));
const { Miniflare } = require("miniflare");
const bindings = Object.fromEntries(
  (await readFile(envFile, "utf8")).split("\n").filter((l) => l.includes("=") && !l.startsWith("#"))
    .map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)]),
);
process.chdir(dir);
const dist = "dist";
const typeOf = (name) => name.endsWith(".js") ? "ESModule" : /\.min\.mjs$|LICENSE/.test(name) ? "Text" : "Data";
const modules = await Promise.all((await readdir(dist))
  .filter((name) => !name.endsWith(".map") && name !== "README.md")
  .sort((a, b) => (a === "raftContent.js" ? -1 : b === "raftContent.js" ? 1 : a.localeCompare(b)))
  .map(async (name) => ({ type: typeOf(name), path: `dist/${name}`, contents: await readFile(join(dist, name)) })));
const mf = new Miniflare({
  modules,
  compatibilityDate: "2026-07-24",
  host: "127.0.0.1",
  port: Number(portArg),
  d1Databases: { TICKETS: "raft-content-tickets-local" },
  d1Persist: false,
  // Tickets are one-time access paths: never write them to the log.
  handleStructuredLogs: ({ message }) => console.log("[worker]", message.replace(/ticket=[^\s"&]+/g, "ticket=…")),
  bindings,
});
await mf.ready;
const tickets = await mf.getD1Database("TICKETS");
for (const file of (await readdir(join(dir, "migrations"))).filter((n) => n.endsWith(".sql")).sort()) {
  const sql = await readFile(join(dir, "migrations", file), "utf8");
  for (const statement of sql.split(/;\s*(?:\n|$)/).map((s) => s.replace(/--[^\n]*/g, "").trim()).filter(Boolean))
    await tickets.prepare(statement).run();
}
console.log(`content worker on http://127.0.0.1:${portArg} (${Object.keys(bindings).join(", ")})`);
for (const signal of ["SIGTERM", "SIGINT"]) {
  process.on(signal, async () => { await mf.dispose(); process.exit(0); });
}
