// Node side of tool/raft_source.py: the same resolver, asked through `tool/raft-source path`, so Node and Python
// tools always read the same checkout (PARITY_RAFT_SOURCE, else the commit pinned in docs/source-reference.json).
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const cli = fileURLToPath(new URL('./raft-source', import.meta.url));

// `needs`: files the caller reads, relative to the checkout (default: everything a prepared checkout has).
// Throws with the resolver's message (path, expected/actual commit, the prepare command) when it is not usable.
export function raftSourceDir({ needs = [] } = {}) {
  const args = [cli, 'path', ...needs.flatMap((need) => ['--need', need])];
  try {
    return execFileSync(process.env.PYTHON ?? 'python3', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  } catch (error) {
    throw new Error(String(error.stderr || error.message).trim());
  }
}
