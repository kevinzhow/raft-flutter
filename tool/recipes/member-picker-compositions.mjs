#!/usr/bin/env node
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { extractMemberPickerCompositions } from './lib/member-picker-compositions.mjs';
const index = process.argv.indexOf('--web');
const web = resolve(index < 0 ? dirname(dirname(process.env.RAFT_WEB_CSS ?? '.')) : process.argv[index + 1]);
if (!process.argv.includes('--raw')) throw Error('Pass --raw; compile through the shared recipe pipeline');
const ts = createRequire(import.meta.url)('typescript');
process.stdout.write(JSON.stringify(extractMemberPickerCompositions(web, ts)));
