#!/usr/bin/env node
// Parse the pinned Web choice compositions; compile through the shared pipeline.
import {createRequire} from 'node:module';
import {dirname, resolve} from 'node:path';
import {extractChoiceCompositions} from './lib/choice-compositions.mjs';
const index=process.argv.indexOf('--web');
const web=resolve(index<0 ? (process.env.RAFT_WEB_CSS ? dirname(dirname(process.env.RAFT_WEB_CSS)) : '.') : process.argv[index+1]);
if(!process.argv.includes('--raw')) throw Error('Pass --raw; compile through the shared recipe pipeline');
const ts=createRequire(import.meta.url)('typescript');
process.stdout.write(JSON.stringify(extractChoiceCompositions(web,ts)));
