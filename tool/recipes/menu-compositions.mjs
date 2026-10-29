#!/usr/bin/env node
// Parse Web-authored menu compositions. All classes come from TSX; unsupported
// expressions fail instead of silently omitting source behavior.
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { extractMenuCompositions } from './lib/menu-compositions.mjs';

const arg = (key, fallback) => {
  const index = process.argv.indexOf(`--${key}`);
  return index < 0 ? fallback : process.argv[index + 1];
};
const css = process.env.RAFT_WEB_CSS;
const web = resolve(arg('web', css ? dirname(dirname(css)) : '.'));
const ts = createRequire(import.meta.url)('typescript');
if (!process.argv.includes('--raw')) throw new Error('Pass --raw; compile through the shared recipe pipeline');
process.stdout.write(JSON.stringify(extractMenuCompositions(web, ts)));
