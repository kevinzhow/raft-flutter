#!/usr/bin/env python3
"""Fixture server of the attachment open smoke: python3 aos_server.py <data-dir> <port>

Serves what Raft's storage and API serve to a client, so the app's real HTTP path is exercised:
  /storage/<file>?X-Amz-Signature=ok|expired      presigned object-storage URL (Range, HEAD; `expired` answers 403)
  /thumb/<file>                                   server thumbnail (webp)
  /thumb-missing/<file>   404,  /thumb-expired/<file>   403
  /api/attachments/<id>?token=<t>&serverId=..     the Raft server streaming the bytes itself (local storage mode):
                                                  token `jwt-ok` accepted, `jwt-expired` answers 401. With ?redirect=1 it
                                                  answers 302 to the presigned URL instead (S3 mode).
  /__manifest   the case list (aos_fixtures.manifest)
  /__stats      {"log": [...], "files": {...}}  every request with method, path, range, user agent, status, bytes
  /__reset      clears the log
Never logs query secrets beyond the fixture's own constant tokens.
"""
import json, os, sys, threading, time
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse, parse_qs

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aos_fixtures

DATA = Path(sys.argv[1])
PORT = int(sys.argv[2])
# Run configuration the test reads at start (case filter, entry points), and where results are appended.
CONFIG = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
RESULTS = Path(sys.argv[4]) if len(sys.argv) > 4 else None
CMD = {'pending': None, 'done': True, 'result': None}
LOCK = threading.Lock()
LOG = []
MANIFEST = aos_fixtures.manifest(DATA)
BY_ID = {c['id']: c for c in MANIFEST['cases']}


def case_of(attachment_id):
    return BY_ID.get(attachment_id[4:] if attachment_id.startswith('aos-') else attachment_id)
RATE = {}  # case id -> bytes per second, set by ?rate on the manifest if wanted


MIME_OVERRIDE = {'.m4a': 'audio/mp4', '.webm': 'video/webm', '.heic': 'image/heic', '.svg': 'image/svg+xml'}


class H(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *a):
        pass

    def note(self, status, sent, **extra):
        entry = {'t': round(time.time(), 3), 'method': self.command, 'path': urlparse(self.path).path,
                 'query': urlparse(self.path).query, 'range': self.headers.get('Range'),
                 'ua': self.headers.get('User-Agent', ''), 'auth': bool(self.headers.get('Authorization')),
                 'status': status, 'bytes': sent}
        entry.update(extra)
        with LOCK:
            LOG.append(entry)

    def reply(self, status, body=b'', headers=None, head=False):
        self.send_response(status)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def do_POST(self):
        u = urlparse(self.path)
        length = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(length) if length else b''
        if u.path == '/__result' and RESULTS is not None:
            with LOCK, RESULTS.open('ab') as f:
                f.write(body.replace(b'\n', b' ') + b'\n')
            return self.reply(200, b'{}', {'Content-Type': 'application/json'})
        self.note(404, 0)
        self.reply(404, b'')

    def do_HEAD(self):
        self._serve(True)

    def do_GET(self):
        self._serve(False)

    def serve_file(self, path: Path, head, *, disposition=None):
        size = path.stat().st_size
        start, end, status = 0, size - 1, 200
        rng = self.headers.get('Range')
        headers = {'Accept-Ranges': 'bytes', 'Content-Type': MIME_OVERRIDE.get(path.suffix.lower()) or
                   __import__('mimetypes').guess_type(str(path))[0] or 'application/octet-stream'}
        if disposition:
            headers['Content-Disposition'] = f'{disposition}; filename="{path.name}"'
        if rng and rng.startswith('bytes='):
            a, _, b = rng[6:].partition('-')
            try:
                if a == '':
                    start = max(0, size - int(b))
                else:
                    start = int(a)
                    end = int(b) if b else size - 1
            except ValueError:
                start, end = 0, size - 1
            end = min(end, size - 1)
            if start > end or start >= size:
                self.note(416, 0)
                return self.reply(416, b'', {'Content-Range': f'bytes */{size}'}, head)
            status = 206
            headers['Content-Range'] = f'bytes {start}-{end}/{size}'
        length = end - start + 1
        headers['Content-Length'] = str(length)
        self.send_response(status)
        for k, v in headers.items():
            self.send_header(k, v)
        self.end_headers()
        sent = 0
        if not head:
            try:
                with path.open('rb') as f:
                    f.seek(start)
                    left = length
                    while left > 0:
                        chunk = f.read(min(256 * 1024, left))
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                        sent += len(chunk)
                        left -= len(chunk)
            except (BrokenPipeError, ConnectionResetError):
                pass
        self.note(status, sent)

    def _serve(self, head):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        parts = [p for p in u.path.split('/') if p]
        if u.path == '/__manifest':
            body = json.dumps(MANIFEST).encode()
            return self.reply(200, body, {'Content-Type': 'application/json'}, head)
        if u.path == '/__config':
            return self.reply(200, json.dumps(CONFIG).encode(), {'Content-Type': 'application/json'}, head)
        if u.path == '/__cmd':
            with LOCK:
                if 'set' in q:
                    CMD.update(pending=q['set'][0], done=False, result=None)
                if 'ack' in q:
                    CMD.update(pending=None, done=True, result=q['ack'][0] or None)
                out = dict(CMD)
            return self.reply(200, json.dumps(out).encode(), {'Content-Type': 'application/json'}, head)
        if u.path == '/__reset':
            with LOCK:
                LOG.clear()
            return self.reply(200, b'{}', {'Content-Type': 'application/json'}, head)
        if u.path == '/__stats':
            with LOCK:
                body = json.dumps({'log': list(LOG)}).encode()
            return self.reply(200, body, {'Content-Type': 'application/json'}, head)
        if len(parts) == 2 and parts[0] == 'storage':
            path = DATA / 'storage' / os.path.basename(parts[1])
            sig = (q.get('X-Amz-Signature') or [''])[0]
            if sig != 'ok':
                self.note(403, 0, why='signature ' + sig)
                return self.reply(403, b'<Error><Code>ExpiredToken</Code></Error>', {'Content-Type': 'application/xml'}, head)
            if not path.is_file():
                self.note(404, 0)
                return self.reply(404, b'', None, head)
            disposition = 'attachment' if (q.get('response-content-disposition') or [''])[0].startswith('attachment') else None
            return self.serve_file(path, head, disposition=disposition)
        if len(parts) == 2 and parts[0] in ('thumb', 'thumb-missing', 'thumb-expired'):
            if parts[0] == 'thumb-missing':
                self.note(404, 0)
                return self.reply(404, b'', None, head)
            if parts[0] == 'thumb-expired':
                self.note(403, 0)
                return self.reply(403, b'', None, head)
            path = DATA / 'thumb' / os.path.basename(parts[1])
            if not path.is_file():
                self.note(404, 0)
                return self.reply(404, b'', None, head)
            return self.serve_file(path, head)
        if len(parts) == 4 and parts[:2] == ['api', 'attachments'] and parts[3] == 'html-preview':
            case = case_of(parts[2])
            if case is None or not (q.get('previewToken') or [''])[0]:
                self.note(404, 0)
                return self.reply(404, b'', None, head)
            body = (DATA / 'storage' / case['file']).read_bytes()
            csp = "sandbox allow-scripts; default-src 'none'; connect-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; worker-src 'none'; style-src 'unsafe-inline'; img-src data:"
            self.note(200, 0 if head else len(body))
            return self.reply(200, body, {'Content-Type': 'text/html; charset=utf-8', 'Content-Security-Policy': csp}, head)
        if len(parts) == 3 and parts[:2] == ['api', 'attachments']:
            case = case_of(parts[2])
            token = (q.get('token') or [''])[0]
            if case is None:
                self.note(404, 0)
                return self.reply(404, b'', None, head)
            if token != 'jwt-ok':
                self.note(401, 0, why='token ' + token)
                return self.reply(401, b'{"error":"Unauthorized"}', {'Content-Type': 'application/json'}, head)
            if case['url'] == 'redirect':
                self.note(302, 0)
                return self.reply(302, b'', {'Location': f"http://{self.headers.get('Host')}/storage/{case['file']}?X-Amz-Signature=ok"}, head)
            disposition = (q.get('disposition') or [None])[0]
            return self.serve_file(DATA / 'storage' / case['file'], head, disposition=disposition)
        self.note(404, 0)
        self.reply(404, b'', None, head)


class Server(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 64


if __name__ == '__main__':
    print(f'attachment-open-smoke server on {PORT}, {len(MANIFEST["cases"])} cases', file=sys.stderr, flush=True)
    Server(('127.0.0.1', PORT), H).serve_forever()
