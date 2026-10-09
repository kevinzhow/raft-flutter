// Android integration artifacts must reach the host before test app uninstall.
// Only a newly registered, exact input-bound run may publish a complete receipt.
import { createHash } from 'node:crypto';
import { inflateSync } from 'node:zlib';
import { mkdirSync, existsSync, readFileSync, writeFileSync, openSync, closeSync, fsyncSync } from 'node:fs';
import { resolve } from 'node:path';

const sha = data => createHash('sha256').update(data).digest('hex');
const hex = /^[0-9a-f]{64}$/;
const runId = /^[A-Za-z0-9][A-Za-z0-9._-]{1,120}$/;
const allowedFile = /^(?:renderer-frames\/)?[A-Za-z0-9][A-Za-z0-9._-]*\.(json|jsonl|png)$/;

function durable(path, bytes) {
  const fd = openSync(path, 'wx');
  try { writeFileSync(fd, bytes); fsyncSync(fd); } finally { closeSync(fd); }
}
function syncDirectory(path) {
  const fd = openSync(path, 'r');
  try { fsyncSync(fd); } finally { closeSync(fd); }
}
function crc32(data) {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
export function validatePng(bytes) {
  if (bytes.length < 45 || !bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) throw new Error('PNG signature missing');
  let offset = 8, header, ended = false;
  const idat = [];
  while (offset + 12 <= bytes.length) {
    const length = bytes.readUInt32BE(offset);
    if (length > bytes.length - offset - 12) throw new Error('PNG chunk truncated');
    const type = bytes.toString('ascii', offset + 4, offset + 8);
    const data = bytes.subarray(offset + 8, offset + 8 + length);
    if (crc32(bytes.subarray(offset + 4, offset + 8 + length)) !== bytes.readUInt32BE(offset + 8 + length)) throw new Error('PNG chunk CRC mismatch');
    if (offset === 8 && type !== 'IHDR') throw new Error('PNG IHDR missing');
    if (type === 'IHDR') {
      if (header || length !== 13) throw new Error('Invalid PNG IHDR');
      header = data;
    }
    if (type === 'IDAT') idat.push(data);
    offset += length + 12;
    if (type === 'IEND') { if (length !== 0 || offset !== bytes.length) throw new Error('PNG trailing or invalid IEND'); ended = true; break; }
  }
  if (!header || !ended || !idat.length) throw new Error('PNG incomplete');
  const width = header.readUInt32BE(0), height = header.readUInt32BE(4);
  const channels = { 0: 1, 2: 3, 4: 2, 6: 4 }[header[9]];
  if (!width || !height || width > 10000 || height > 10000 || header[8] !== 8 || !channels || header[10] || header[11] || header[12]) throw new Error('Unsupported PNG layout');
  const expected = height * (1 + width * channels);
  const decoded = inflateSync(Buffer.concat(idat), { maxOutputLength: expected });
  if (decoded.length !== expected) throw new Error('PNG pixel data length mismatch');
  for (let row = 0; row < height; row++) if (decoded[row * (1 + width * channels)] > 4) throw new Error('PNG row filter invalid');
}

export function createArtifactHandoff({ out, fixtureSha, sourceInputSha, runtimeSha, record }) {
  const root = resolve(out, 'native-artifacts');
  const runs = new Map();
  const json = (res, body, status = 200) => {
    res.statusCode = status; res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify(body));
  };
  async function body(req, partialPath) {
    const chunks = []; let size = 0;
    const fd = partialPath ? openSync(partialPath, 'wx') : null;
    try {
      for await (const chunk of req) {
        size += chunk.length;
        if (size > 64 * 1024 * 1024) throw new Error('Artifact payload exceeds 64MiB');
        chunks.push(chunk);
        if (fd !== null) writeFileSync(fd, chunk);
      }
      if (fd !== null) fsyncSync(fd);
      return JSON.parse(Buffer.concat(chunks).toString());
    } finally { if (fd !== null) closeSync(fd); }
  }
  return async function handle(req, res, url) {
    if (!url.pathname.startsWith('/__process/artifacts')) return false;
    if (url.pathname === '/__process/artifacts/register' && req.method === 'POST') {
      try {
        const registration = await body(req);
        const { run, device, productSha, testSha } = registration;
        if (!runId.test(run ?? '') || run.includes('..') || !device || typeof device !== 'string' || device === 'linux-xvfb' || !hex.test(productSha ?? '') || !hex.test(testSha ?? '') || registration.fixtureSha !== fixtureSha || registration.platform !== 'android') return json(res, { error: 'Invalid current Android run binding' }, 400), true;
        const path = resolve(root, run);
        if (runs.has(run) || existsSync(path)) return json(res, { error: 'Run already registered; use a new output/run ID' }, 409), true;
        mkdirSync(path, { recursive: true });
        const entry = { ...registration, sourceInputSha, runtimeSha, path, status: 'REGISTERED' };
        runs.set(run, entry);
        durable(resolve(path, 'registration.json'), JSON.stringify(entry)); syncDirectory(path);
        record({ kind: 'artifact-registered', run, fixtureSha, productSha, testSha, device });
        json(res, { run, registered: true, fixtureSha, sourceInputSha, runtimeSha });
      } catch (error) { json(res, { error: String(error) }, 400); }
      return true;
    }
    const match = /^\/__process\/artifacts\/([^/]+)(\/upload)?$/.exec(url.pathname);
    const run = match?.[1], entry = runs.get(run);
    if (!entry) return json(res, { error: 'Unknown current run ID' }, 404), true;
    if (req.method === 'GET' && !match[2]) {
      if (entry.status !== 'COMPLETE') return json(res, { error: 'Current run artifacts incomplete', run, status: entry.status }, 409), true;
      json(res, { receipt: entry.receipt, files: entry.files }); return true;
    }
    if (req.method !== 'POST' || !match[2]) return json(res, { error: 'Unsupported artifact operation' }, 405), true;
    if (entry.status !== 'REGISTERED') return json(res, { error: 'Run upload already attempted; no stale retry' }, 409), true;
    entry.status = 'UPLOADING';
    record({ kind: 'artifact-upload-started', run });
    try {
      const payload = await body(req, resolve(entry.path, 'upload.partial.json'));
      if (payload.run !== run || payload.fixtureSha !== fixtureSha) throw new Error('Upload run/fixture mismatch');
      const files = payload.files;
      if (!files || Array.isArray(files) || typeof files !== 'object' || !files['result.json'] || !files['renderer-frames.json'] || !files['frames.jsonl']) throw new Error('Complete result/manifests/layout observations required');
      const buffers = {};
      for (const [name, value] of Object.entries(files)) {
        if (!allowedFile.test(name) || name.includes('..') || !hex.test(value?.sha256 ?? '') || typeof value?.base64 !== 'string' || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value.base64)) throw new Error('Malformed artifact file');
        const bytes = Buffer.from(value.base64, 'base64');
        if (sha(bytes) !== value.sha256) throw new Error(`Artifact hash mismatch: ${name}`);
        if (name.endsWith('.png')) validatePng(bytes);
        buffers[name] = bytes;
      }
      const result = JSON.parse(buffers['result.json'].toString());
      for (const key of ['fixtureSha', 'productSha', 'testSha', 'device', 'platform', 'sourceInputSha', 'runtimeSha']) if (result[key] !== entry[key]) throw new Error(`Result input mismatch: ${key}`);
      if (!['PASS', 'FAIL'].includes(result.result)) throw new Error('Incomplete result status');
      const renderer = JSON.parse(buffers['renderer-frames.json'].toString());
      if (!Array.isArray(renderer) || !renderer.length || renderer.length !== result.rendererFrameCount) throw new Error('Renderer manifest/count mismatch');
      const expectedPngs = new Set(renderer.map(row => `renderer-frames/${row.file}`));
      if (expectedPngs.size !== renderer.length || renderer.some(row => row.error || !/^\d{4,}\.png$/.test(row.file))) throw new Error('Invalid renderer manifest');
      const actualPngs = Object.keys(buffers).filter(name => name.startsWith('renderer-frames/') && name.endsWith('.png'));
      if (actualPngs.length !== expectedPngs.size || actualPngs.some(name => !expectedPngs.has(name))) throw new Error('Renderer PNG inventory mismatch');
      for (const name of expectedPngs) if (!buffers[name]) throw new Error('Renderer PNG missing');
      if (!buffers['frames.jsonl'].toString().trim()) throw new Error('Layout observations missing');
      for (const line of buffers['frames.jsonl'].toString().trim().split('\n')) JSON.parse(line);
      const filesPath = resolve(entry.path, 'files'); mkdirSync(filesPath); mkdirSync(resolve(filesPath, 'renderer-frames'));
      for (const [name, bytes] of Object.entries(buffers)) durable(resolve(filesPath, name), bytes);
      syncDirectory(resolve(filesPath, 'renderer-frames')); syncDirectory(filesPath);
      const receipt = { run, fixtureSha, productSha: entry.productSha, testSha: entry.testSha, sourceInputSha, runtimeSha, platform: 'android', device: entry.device, result: result.result, rendererFrameCount: renderer.length, fileCount: Object.keys(files).length, files: Object.fromEntries(Object.entries(files).map(([name, value]) => [name, value.sha256])), persistedAt: Date.now() };
      durable(resolve(entry.path, 'handoff.json'), JSON.stringify(receipt)); syncDirectory(entry.path);
      entry.status = 'COMPLETE'; entry.receipt = receipt; entry.files = files;
      record({ kind: 'artifact-persisted', ...receipt });
      // ACK follows fsync of every validated file and the binding receipt.
      json(res, receipt);
    } catch (error) {
      entry.status = 'FAILED'; entry.error = String(error);
      durable(resolve(entry.path, 'upload-error.json'), JSON.stringify({ run, error: String(error), failedAt: Date.now() })); syncDirectory(entry.path);
      record({ kind: 'artifact-upload-failed', run, error: String(error) });
      json(res, { run, error: String(error) }, 400);
    }
    return true;
  };
}
