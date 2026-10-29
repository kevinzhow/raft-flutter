// Load raft-ui's compiled component bundle as ONE source text.
//
// Up to 0.5.27 `dist/index.mjs` was a single file. Later releases hoist the
// shared core (tv wrapper, theme context, Spinner, Button, Dialog) into a hashed
// chunk (`dist/dialog-<hash>.mjs`) that index.mjs imports under minified
// aliases (`import { S as tv, f as Button } from "./dialog-<hash>.mjs"`).
// The recipe pipeline analyses a flat module, so the chunk is inlined: its
// imports stay (they hold the tailwind-variants import), its trailing
// `export { local as alias }` is dropped, and every alias that index.mjs
// uses becomes a `const alias = local;` binding. The result has the same
// shape as the old single-file bundle.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const IMPORT_LINE = /^import [^\n]*;[ \t]*$/;
const CHUNK_IMPORT = /^import \{([^}]*)\} from "\.\/([^"]+\.mjs)";[ \t]*$/;

function pairs(list) {
  return list.split(',').map((s) => s.trim()).filter(Boolean).map((s) => {
    const [local, alias] = s.split(/\s+as\s+/);
    return [local.trim(), (alias ?? local).trim()];
  });
}

export function loadBundle(sourceRoot) {
  const indexText = readFileSync(join(sourceRoot, 'dist/index.mjs'), 'utf8');
  const lines = indexText.split('\n');
  const chunkImports = [];
  for (const line of lines) {
    const m = CHUNK_IMPORT.exec(line);
    if (m && m[2] !== 'cn.mjs') chunkImports.push({ specifiers: pairs(m[1]).map(([a, b]) => [a, b]), file: m[2] });
  }
  const files = ['dist/index.mjs'];
  if (chunkImports.length === 0) {
    return { code: indexText, files, aliasToLocal: new Map(), texts: [indexText] };
  }
  if (chunkImports.length > 1) throw new Error(`bundle: expected one shared chunk, found ${chunkImports.map((c) => c.file)}`);
  const [{ file, specifiers }] = chunkImports;
  const chunkText = readFileSync(join(sourceRoot, 'dist', file), 'utf8');
  files.push(`dist/${file}`);
  const exportMatch = /^export \{([^}]*)\};[ \t]*$/m.exec(chunkText);
  if (!exportMatch) throw new Error(`bundle: ${file} has no export list`);
  const exportedAs = new Map(pairs(exportMatch[1]).map(([local, alias]) => [alias, local]));
  const aliasToLocal = new Map();
  const aliasDecls = [];
  // Names the chunk itself imports (`tv` from tailwind-variants/lite): an
  // index alias with the same spelling cannot be a binding in the merged
  // module, so its uses are renamed to the chunk local instead.
  const chunkImportLocals = new Set();
  for (const m of chunkText.matchAll(/^import (?:\{([^}]*)\}|(\w+)) from /gm)) {
    for (const [, l] of m[1] ? pairs(m[1]) : [[0, m[2]]]) chunkImportLocals.add(l);
  }
  const renames = [];
  for (const [exported, alias] of specifiers) {
    const local = exportedAs.get(exported);
    if (!local) throw new Error(`bundle: index.mjs imports ${exported} which ${file} does not export`);
    if (local === alias) continue;
    if (chunkImportLocals.has(alias)) renames.push([alias, local]);
    else {
      aliasToLocal.set(alias, local);
      aliasDecls.push(`const ${alias} = ${local};`);
    }
  }
  const chunkBody = chunkText.replace(exportMatch[0], '');
  let indexBody = lines.filter((l) => !IMPORT_LINE.test(l)).join('\n');
  for (const [alias, local] of renames) {
    indexBody = indexBody.replace(new RegExp(`(?<![\\w$.])${alias.replace(/\$/g, '\\$')}(?![\\w$])`, 'g'), local);
  }
  const code = `${chunkBody}\n//#region (index.mjs aliases of ${file})\n${aliasDecls.join('\n')}\n//#endregion\n${indexBody}`;
  return { code, files, aliasToLocal, texts: [indexText, chunkText] };
}
