// Synthetic loopback service for the unmodified production AppImage.
// No UI actions, account files, environment credentials, or external requests.
'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const {Server} = require('socket.io');
const out = process.argv[2];
if (!out || !fs.statSync(out).isDirectory()) throw Error('Existing output directory required');
const user = {id: 'optional-human', name: 'Runtime Tester', email: 'runtime@fixture.invalid', emailVerified: true};
const server = {id: 'optional-server', name: 'Optional Runtime QA', slug: 'optional-qa', role: 'owner'};
const channel = {id: 'optional-channel', name: 'general', serverId: server.id, type: 'channel', joined: true};
const messages = [], requests = [], liveDeliveries = [];
let authenticated = false, connections = 0, incoming = 0, sent = 0, sequence = 0;
const credentials = {accessToken: 'synthetic-optional-access', refreshToken: 'synthetic-optional-refresh'};
const json = (response, status, value) => {
  response.writeHead(status, {'content-type': 'application/json', 'cache-control': 'no-store'});
  response.end(JSON.stringify(value));
};
async function body(request) {
  let bytes = 0, chunks = [];
  for await (const chunk of request) {
    bytes += chunk.length;
    if (bytes > 65536) throw Error('Fixture request too large');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString() || '{}');
}
function message(content, own = false, attachments = []) {
  sequence++;
  return {id: `optional-message-${sequence}`, channelId: channel.id, serverId: server.id,
    seq: String(sequence), content, senderId: own ? user.id : 'optional-peer',
    senderType: 'user', senderName: own ? user.name : 'Fixture Peer',
    createdAt: new Date().toISOString(), attachments};
}
const html = '<!doctype html><meta charset="utf-8"><h1>Optional HTML fixture</h1>' +
  '<p>Static reading works without WebKit.</p><button onclick="this.textContent=\'HTML clicked\'">HTML counter</button>';
const csp = "sandbox allow-scripts; default-src 'none'; script-src 'unsafe-inline'; connect-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; worker-src 'none'";
const attachmentTypes = {html: ['report.html', 'text/html'], audio: ['tone.wav', 'audio/wav'], pdf: ['page.pdf', 'application/pdf']};
function attachment(id) {
  const [filename, mimeType] = attachmentTypes[id];
  return {id, filename, originalFilename: filename, mimeType, size: 256, status: 'ready'};
}
function audio() {
  const samples = 22050, buffer = Buffer.alloc(44 + samples * 2);
  buffer.write('RIFF'); buffer.writeUInt32LE(buffer.length - 8, 4); buffer.write('WAVEfmt ', 8);
  buffer.writeUInt32LE(16, 16); buffer.writeUInt16LE(1, 20); buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(22050, 24); buffer.writeUInt32LE(44100, 28); buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34); buffer.write('data', 36); buffer.writeUInt32LE(samples * 2, 40);
  for (let i = 0; i < samples; i++) buffer.writeInt16LE(Math.round(4000 * Math.sin(2 * Math.PI * 440 * i / 22050)), 44 + i * 2);
  return buffer;
}
function pdf() {
  const drawing = '0 0 1 rg 10 10 80 80 re f\n';
  const objects = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Contents 4 0 R >>',
    `<< /Length ${drawing.length} >>\nstream\n${drawing}endstream`];
  let data = '%PDF-1.4\n', offsets = [0];
  objects.forEach((object, index) => { offsets.push(Buffer.byteLength(data)); data += `${index + 1} 0 obj\n${object}\nendobj\n`; });
  const start = Buffer.byteLength(data);
  data += 'xref\n0 5\n0000000000 65535 f \n' + offsets.slice(1).map(offset => `${String(offset).padStart(10, '0')} 00000 n \n`).join('');
  return Buffer.from(data + `trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n${start}\n%%EOF\n`);
}
const service = http.createServer(async (request, response) => {
  const route = new URL(request.url, 'http://fixture.invalid').pathname;
  requests.push({method: request.method, path: route});
  if (requests.length > 500) requests.shift();
  try {
    if (route === '/qa/state') return json(response, 200, {authenticated, connections, incoming, sent, messages, liveDeliveries, requests});
    if (route === '/qa/receive' && request.method === 'POST') {
      const value = await body(request);
      const row = message(value.content || 'Optional incoming message');
      // This proof message is intentionally absent from HTTP history. Seeing
      // it in the real application must require the Socket.IO delivery.
      liveDeliveries.push({id: row.id, content: row.content, connectedRecipients: io.sockets.sockets.size});
      incoming++; io.emit('message:new', row);
      return json(response, 200, {id: row.id, content: row.content});
    }
    if (route === '/qa/attachment' && request.method === 'POST') {
      const {id} = await body(request);
      if (!Object.hasOwn(attachmentTypes, id)) return json(response, 400, {error: 'Unknown attachment'});
      const row = message('Optional attachment fixture', false, [attachment(id)]);
      messages.push(row); io.emit('message:new', row);
      return json(response, 200, {id: row.id});
    }
    if (route === '/api/auth/providers') return json(response, 200, {providers: []});
    if (route === '/api/auth/login' && request.method === 'POST') {
      const value = await body(request);
      if (value.email !== user.email || value.password !== 'synthetic-password') return json(response, 401, {error: 'Invalid fixture credentials'});
      authenticated = true;
      return json(response, 200, {...credentials, user});
    }
    if (route === '/api/auth/refresh') return json(response, 200, credentials);
    if (route.startsWith('/files/')) {
      const id = route.slice('/files/'.length);
      const value = id === 'html' ? Buffer.from(html) : id === 'audio' ? audio() : pdf();
      response.writeHead(200, {'content-type': attachmentTypes[id]?.[1] || 'application/octet-stream', 'content-length': value.length});
      return response.end(value);
    }
    if (route === '/api/attachments/html/html-preview') {
      response.writeHead(200, {'content-type': 'text/html', 'content-security-policy': csp});
      return response.end(html);
    }
    if (request.headers.authorization !== `Bearer ${credentials.accessToken}`) return json(response, 401, {error: 'Synthetic fixture login required'});
    if (route === '/api/auth/me') return json(response, 200, user);
    if (route === '/api/servers') return json(response, 200, [server]);
    if (route === '/api/channels') return json(response, 200, [{...channel, latestSeq: String(sequence)}]);
    if (route === `/api/channels/${channel.id}`) return json(response, 200, {...channel, latestSeq: String(sequence)});
    if (route === `/api/messages/channel/${channel.id}`) return json(response, 200, {messages, hasMore: false, hasNewer: false});
    if (route === '/api/v2/messages' && request.method === 'POST') {
      const value = await body(request);
      if (value.channelId !== channel.id || typeof value.content !== 'string' || !value.content.trim()) return json(response, 400, {error: 'Invalid message'});
      const row = {...message(value.content, true), randomId: value.randomId};
      messages.push(row); sent++; io.emit('message:new', row);
      return json(response, 200, {message: row});
    }
    const file = /^\/api\/attachments\/(html|audio|pdf)(?:\/(url|html-preview-url|comments))?$/.exec(route);
    if (file) {
      if (file[2] === 'url') return json(response, 200, {url: `${origin}/files/${file[1]}`});
      if (file[2] === 'html-preview-url') return json(response, 200, {url: `${origin}/api/attachments/html/html-preview?previewToken=synthetic`});
      if (file[2] === 'comments') return json(response, 200, {comments: [], viewer: {canComment: true}});
      return json(response, 200, attachment(file[1]));
    }
    if (route === '/api/attachments/urls') {
      const value = await body(request);
      return json(response, 200, {urls: Object.fromEntries((value.attachmentIds || []).map(id => [id, `${origin}/files/${id}`]))});
    }
    if (route === '/api/channels/unread') return json(response, 200, {channels: {}});
    if (route === '/api/channels/inbox') return json(response, 200, {items: [], hasMore: false, totalUnreadCount: 0});
    if (route === `/api/servers/${server.id}/setup`) return json(response, 200, {phase: 'ready', blocksChat: false});
    if (route === '/api/feature-flags/evaluate') return json(response, 200, {evaluations: [{key: 'attachment_comments_v0', enabled: true}]});
    if (['/api/agents', '/api/machines', '/api/channels/dm', '/api/channels/public'].includes(route) || route.endsWith('/members')) return json(response, 200, []);
    if (route.endsWith('/read') || route === '/api/auth/me/timezone-observation') return json(response, 200, {ok: true});
    return json(response, 404, {error: 'Unimplemented isolated fixture route', path: route});
  } catch (error) { return json(response, 400, {error: error.message}); }
});
const io = new Server(service, {serveClient: false});
io.use((socket, next) => socket.handshake.auth.token === credentials.accessToken || socket.handshake.auth.accessToken === credentials.accessToken ? next() : next(Error('Invalid synthetic token')));
io.on('connection', socket => {
  connections++;
  socket.onAny((name, ...args) => { const ack = args.at(-1); if (typeof ack === 'function') ack({ok: true}); });
});
let origin;
service.listen(0, '127.0.0.1', () => {
  origin = `http://127.0.0.1:${service.address().port}`;
  messages.push(message('Core messaging is independent of optional libraries.'));
  fs.writeFileSync(path.join(out, 'fixture.json'), JSON.stringify({origin, pid: process.pid, scope: 'loopback synthetic test only'}) + '\n', {flag: 'wx'});
});
