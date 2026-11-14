// Recreates only the managed RisingWave of a running raftdev environment and provisions it
// again from Postgres, the way `./raftdev start` does: the same container arguments and
// config (imported from the source's scripts/dev/raftdev.ts, so the reviewed reference
// patches apply), then packages/server/scripts/bootstrap-risingwave-local.ts (CDC source and
// the serving materialized views). Postgres data, Redis, RustFS and the server are not
// touched; the bootstrap only drops this environment's inactive replication slot and
// recreates its publication, as on every start.
//
// Run by `tool/raft-stack restart risingwave`:
//   pnpm exec node --import @oxc-node/core/register tool/raft-risingwave.ts <sourceDir> <environment>
// (cwd <sourceDir>/packages/server, so the server's own pg and oxc-node resolve).
import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [sourceDir, environment] = process.argv.slice(2);
if (!sourceDir || !environment || !/^[A-Za-z0-9._-]{1,128}$/.test(environment)) {
  console.error("usage: raft-risingwave.ts <sourceDir> <environment>");
  process.exit(2);
}
const raftdev = await import(pathToFileURL(join(sourceDir, "scripts/dev/raftdev.ts")).href);
const { Client } = createRequire(join(sourceDir, "packages/server/package.json"))("pg");

const offset: number = raftdev.computeOffset(environment);
const container = `slock-dev-${environment}-risingwave`;
const network = `slock-dev-${environment}-risingwave-net`;
const slockdevDir = join(sourceDir, ".slockdev", environment);
const rwPort: number = raftdev.risingWavePort(offset);
const rwUrl = `postgresql://root@127.0.0.1:${rwPort}/dev`;
const pgPassword = `slock-dev-${environment}`;
const pgUrl = `postgresql://postgres:${pgPassword}@localhost:${15432 + offset}/slock`;
const image: string = process.env.RAFTDEV_RISINGWAVE_IMAGE?.trim() || raftdev.DEFAULT_RISINGWAVE_IMAGE;
const owner: string = raftdev.raftdevOwner(sourceDir);

function docker(args: string[], quiet = true): { code: number; stdout: string } {
  const r = spawnSync("docker", args, { encoding: "utf8", stdio: ["ignore", "pipe", quiet ? "pipe" : "inherit"] });
  return { code: r.status ?? 1, stdout: (r.stdout ?? "").trim() };
}

function step(message: string): void {
  console.log(`[restart-risingwave] ${message}`);
}

// 1. Only a RisingWave this checkout's raftdev created is replaced.
const labels = docker(["inspect", "-f", "{{json .Config.Labels}}", container]);
if (labels.code === 0) {
  const parsed = JSON.parse(labels.stdout || "{}") as Record<string, string>;
  if (parsed[raftdev.RAFTDEV_OWNER_LABEL] !== owner) {
    console.error(`refusing: ${container} was not created by this checkout's raftdev`);
    process.exit(1);
  }
}
if (docker(["network", "inspect", network]).code !== 0) {
  console.error(`refusing: network ${network} is missing (is the environment running with --risingwave=full?)`);
  process.exit(1);
}
const startedAt = Date.now();
step(`replacing ${container}`);
if (labels.code === 0 && docker(["rm", "-fv", container]).code !== 0) {
  console.error(`could not remove ${container}`);
  process.exit(1);
}

// 2. Same container as raftdev start.
mkdirSync(slockdevDir, { recursive: true });
const configFile = join(slockdevDir, "risingwave.toml");
writeFileSync(configFile, raftdev.RISINGWAVE_CONFIG);
const runArgs: string[] = raftdev.risingWaveDockerRunArgs(
  { RISINGWAVE_CONTAINER: container, RISINGWAVE_PORT: rwPort, RISINGWAVE_DASHBOARD_PORT: raftdev.risingWaveDashboardPort(offset) },
  image,
  network,
  { owner, memoryBytes: raftdev.parseRisingWaveMemoryBytes(process.env.RAFTDEV_RW_MEMORY_BYTES), configFile },
);
if (docker(runArgs, false).code !== 0) {
  console.error(`could not start ${container}`);
  process.exit(1);
}
// tool/raft-stack's containerCpus: bound the container before the CPU-heavy bootstrap.
const cpus = process.env.RAFT_STACK_CONTAINER_CPUS?.trim();
if (cpus && cpus !== "0" && docker(["update", "--cpus", cpus, container]).code !== 0) {
  console.error(`could not limit ${container} to ${cpus} CPUs`);
  process.exit(1);
}

// 3. pgwire SELECT 1.
async function sqlReady(): Promise<boolean> {
  const client = new Client({ connectionString: rwUrl, connectionTimeoutMillis: 1500, query_timeout: 1500 });
  try {
    await client.connect();
    return (await client.query("SELECT 1")).rowCount === 1;
  } catch {
    return false;
  } finally {
    await client.end().catch(() => undefined);
  }
}
let ready = false;
for (let attempt = 0; attempt < 90 && !ready; attempt++) {
  ready = await sqlReady();
  if (!ready) await new Promise((resolve) => setTimeout(resolve, 1000));
}
if (!ready) {
  console.error(`RisingWave did not answer SELECT 1; docker logs --tail 100 ${container}`);
  process.exit(1);
}
step(`pgwire ready after ${((Date.now() - startedAt) / 1000).toFixed(0)} s; bootstrapping CDC and views`);

// 4. The same bootstrap raftdev start runs (runManagedRisingWaveBootstrap).
const bootstrap = spawnSync("pnpm", ["exec", "node", "--import", "@oxc-node/core/register", "scripts/bootstrap-risingwave-local.ts"], {
  cwd: join(sourceDir, "packages/server"),
  env: {
    ...process.env,
    DATABASE_URL: pgUrl,
    RISINGWAVE_DATABASE_URL: rwUrl,
    RISINGWAVE_CDC_HOST: `slock-dev-${environment}-pg`,
    RISINGWAVE_CDC_PORT: "5432",
    RISINGWAVE_CDC_USERNAME: "postgres",
    RISINGWAVE_CDC_PASSWORD: pgPassword,
    RAFTDEV_RISINGWAVE_BOOTSTRAP: "1",
  },
  stdio: "inherit",
});
if ((bootstrap.status ?? 1) !== 0) {
  console.error("RisingWave bootstrap failed; the server keeps answering Activity reads with 503 until it succeeds");
  process.exit(bootstrap.status ?? 1);
}

// 5. raftdev status reads this file.
const stateFile = join(slockdevDir, "risingwave-state.json");
let state: Record<string, unknown> = {};
try {
  state = JSON.parse(readFileSync(stateFile, "utf8"));
} catch {
  // A missing or unreadable state file is written fresh.
}
writeFileSync(stateFile, `${JSON.stringify({
  schemaVersion: 1, mode: "local", profile: "full", managed: true, databaseName: "dev",
  ...state,
  status: "serving-ready",
  configuredImage: image,
  actualImageId: docker(["inspect", "-f", "{{.Image}}", container]).stdout || undefined,
}, null, 2)}\n`, { mode: 0o600 });
step(`serving-ready after ${((Date.now() - startedAt) / 1000).toFixed(0)} s`);
