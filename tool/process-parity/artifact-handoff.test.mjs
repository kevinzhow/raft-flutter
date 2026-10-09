// Transport admission and durable receipt tests, not a physical-device claim.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { createHash } from 'node:crypto';
import { deflateSync } from 'node:zlib';
import { mkdtempSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createArtifactHandoff, validatePng } from './artifact-handoff.mjs';

const binding = { fixtureSha: 'f'.repeat(64), sourceInputSha: 'c'.repeat(64), runtimeSha: 'd'.repeat(64) };
const registration = run => ({ run, fixtureSha: binding.fixtureSha, productSha: 'a'.repeat(64), testSha: 'b'.repeat(64), platform: 'android', device: 'emulator-fixture' });
const sha = data => createHash('sha256').update(data).digest('hex');
function crc(data) {
  let value = 0xffffffff;
  for (const byte of data) { value ^= byte; for (let i = 0; i < 8; i++) value = (value >>> 1) ^ ((value & 1) ? 0xedb88320 : 0); }
  return (value ^ 0xffffffff) >>> 0;
}
function chunk(type, bytes) {
  const name = Buffer.from(type), length = Buffer.alloc(4), checksum = Buffer.alloc(4);
  length.writeUInt32BE(bytes.length); checksum.writeUInt32BE(crc(Buffer.concat([name,bytes])));
  return Buffer.concat([length,name,bytes,checksum]);
}
function png() {
  const header = Buffer.alloc(13); header.writeUInt32BE(1); header.writeUInt32BE(1,4); header[8]=8; header[9]=6;
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',deflateSync(Buffer.from([0,255,0,0,255]))),chunk('IEND',Buffer.alloc(0))]);
}
function payload(run) {
  const result = { ...registration(run), ...binding, result:'PASS', rendererFrameCount:1 };
  delete result.run;
  const bytes = { 'result.json': Buffer.from(JSON.stringify(result)), 'renderer-frames.json': Buffer.from(JSON.stringify([{index:0,file:'0000.png'}])), 'frames.jsonl': Buffer.from('{"frame":0}\n'), 'renderer-frames/0000.png': png() };
  return { run,fixtureSha:binding.fixtureSha,files:Object.fromEntries(Object.entries(bytes).map(([name,bytes]) => [name,{base64:bytes.toString('base64'),sha256:sha(bytes)}])) };
}
async function host(t) {
  const out = mkdtempSync(join(tmpdir(),'raft-android-handoff-'));
  const events=[];
  const handle = createArtifactHandoff({out,...binding,record:event=>events.push(event)});
  const server=createServer(async(req,res)=>{
    if (!await handle(req,res,new URL(req.url,'http://fixture.invalid'))) {res.statusCode=404;res.end();}
  });
  server.listen(0,'127.0.0.1');await once(server,'listening');
  const base='http://127.0.0.1:'+server.address().port;
  t.after(async()=>{await new Promise(resolve=>server.close(resolve));rmSync(out,{recursive:true,force:true});});
  const post=(path,body)=>fetch(base+path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  return {out,events,base,post};
}

test('Android host ACK follows exact complete files; output remains after client lifetime ends', async t => {
  const {out,events,base,post}=await host(t),run='current-android-run';
  assert.equal((await post('/__process/artifacts/register',registration(run))).status,200);
  const input=payload(run),response=await post(`/__process/artifacts/${run}/upload`,input);
  assert.equal(response.status,200);
  const receipt=await response.json();
  assert.equal(receipt.fileCount,4);assert.equal(receipt.rendererFrameCount,1);
  const path=join(out,'native-artifacts',run);
  assert.deepEqual(JSON.parse(readFileSync(join(path,'handoff.json'))),receipt);
  for (const [name,file] of Object.entries(input.files)) assert.equal(sha(readFileSync(join(path,'files',name))),file.sha256);
  // Host collection does not depend on a surviving package/run-as process.
  const readback=await(await fetch(`${base}/__process/artifacts/${run}`)).json();
  assert.deepEqual(readback.receipt,receipt);assert.deepEqual(readback.files,input.files);
  assert.equal(events.at(-1).kind,'artifact-persisted');
  assert.equal((await post('/__process/artifacts/register',registration(run))).status,409);
  assert.equal((await post(`/__process/artifacts/${run}/upload`,input)).status,409);
  assert.equal((await fetch(`${base}/__process/artifacts/stale-other-run`)).status,404);
});

test('unknown, mismatched and incomplete runs never get ACK or old-run fallback', async t=>{
  const {out,base,post}=await host(t);
  assert.equal((await post('/__process/artifacts/unknown-run/upload',payload('unknown-run'))).status,404);
  assert.equal((await post('/__process/artifacts/register',{...registration('wrong-fixture'),fixtureSha:'0'.repeat(64)})).status,400);
  for (const [run,edit] of [
    ['incomplete-png',p=>delete p.files['renderer-frames/0000.png']],
    ['wrong-device',p=>{const r=JSON.parse(Buffer.from(p.files['result.json'].base64,'base64'));r.device='other-device';const data=Buffer.from(JSON.stringify(r));p.files['result.json']={base64:data.toString('base64'),sha256:sha(data)};}],
    ['malformed-png',p=>{const data=png().subarray(0,40);p.files['renderer-frames/0000.png']={base64:data.toString('base64'),sha256:sha(data)};}],
    ['stale-payload',p=>p.run='previous-run'],
  ]) {
    assert.equal((await post('/__process/artifacts/register',registration(run))).status,200);
    const input=payload(run);edit(input);
    const response=await post(`/__process/artifacts/${run}/upload`,input);
    assert.equal(response.status,400,await response.text());
    const path=join(out,'native-artifacts',run);
    assert.equal(existsSync(join(path,'handoff.json')),false);
    assert.equal(existsSync(join(path,'upload.partial.json')),true);
    assert.equal(existsSync(join(path,'upload-error.json')),true);
    assert.equal((await fetch(`${base}/__process/artifacts/${run}`)).status,409);
  }
});

test('renderer PNG admission validates chunks, pixels and CRC, not just a filename',()=>{
  assert.doesNotThrow(()=>validatePng(png()));
  const bad=Buffer.from(png());bad[36]^=1;
  assert.throws(()=>validatePng(bad),/CRC/);
  assert.throws(()=>validatePng(png().subarray(0,-1)),/incomplete|truncated/);
});
