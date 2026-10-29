#!/usr/bin/env python3
"""End-to-end check of the AppImage in-place delta update, against a fake GitHub.

Needs two isolated AppImages built from this tree with the same
RAFT_APPIMAGE_UPDATE_INFO test feed and the same throwaway SPARKLE_ED_PUBLIC_KEY
(see docs/auto-update.md, "Test override and smoke test"): the old one (lower
build number) and the new one, plus the new one's .zsync and receipt next to it.
The harness signs the new AppImage like the release publisher does (Ed25519
over the file, `edSignature` in the manifest) with the matching throwaway
private key file (`python3 tool/appcast.py keygen --out DIR`); it never prints it. The harness serves a GitHub-shaped release (302 from the
asset URL to a CDN-like URL that honours Range), runs the old AppImage under
Xvfb with a throwaway HOME, lets the app's test hook (RAFT_UPDATE_SMOKE=1)
update itself, restart and report the build it now runs, and prints the bytes
that crossed the wire.

    python3 tool/appimage-update-smoke.py --old OLD.AppImage --new NEW.AppImage --output DIR
"""
import argparse
import base64
import hashlib
import http.server
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse

sys.path.insert(0, str(Path(__file__).resolve().parent))
import appcast  # noqa: E402  (the release signer)

OWNER_REPOSITORY = 'kevinzhow/raft-flutter'
# What the app must report for each negative case (AppImageUpdateFailureKind).
REFUSALS = {'wrong-sha256': 'verification', 'wrong-key': 'badSignature', 'missing': 'missingSignature'}


class FakeGitHub:
    """`/<owner>/<repo>/releases/(latest/)download/<name>` redirects to
    `/objects/<n>/<name>`, which serves the bytes with single-range support."""

    def __init__(self, files, port=0):
        self.files = files  # name -> bytes
        self.log = []  # (kind, name, range header, bytes sent)
        self.lock = threading.Lock()
        fake = self

        class Handler(http.server.BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'

            def log_message(self, *args):
                pass

            def reply(self, code, body=b'', headers=()):
                self.send_response(code)
                for key, value in headers:
                    self.send_header(key, value)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def do_GET(self):
                path = urllib.parse.unquote(urllib.parse.urlsplit(self.path).path)
                release = re.fullmatch(rf'/{OWNER_REPOSITORY}/releases/(?:latest/download|download/[^/]+)/(.+)', path)
                if release:
                    name = release[1]
                    with fake.lock:
                        fake.log.append(('redirect', name, self.headers.get('Range'), 0))
                    if name not in fake.files:
                        return self.reply(404, b'not found')
                    return self.reply(302, headers=[('Location', f'/objects/{len(fake.log)}/{urllib.parse.quote(name)}')])
                served = re.fullmatch(r'/objects/\d+/(.+)', path)
                if not served or urllib.parse.unquote(served[1]) not in fake.files:
                    return self.reply(404, b'not found')
                name = urllib.parse.unquote(served[1])
                data = fake.files[name]
                header = self.headers.get('Range')
                start, end, code = 0, len(data) - 1, 200
                extra = [('Accept-Ranges', 'bytes'), ('Content-Type', 'application/octet-stream')]
                if header:
                    match = re.fullmatch(r'bytes=(\d+)-(\d*)', header)
                    if not match or int(match[1]) >= len(data):
                        return self.reply(416, headers=[('Content-Range', f'bytes */{len(data)}')])
                    start = int(match[1])
                    end = min(int(match[2]) if match[2] else len(data) - 1, len(data) - 1)
                    code = 206
                    extra.append(('Content-Range', f'bytes {start}-{end}/{len(data)}'))
                body = data[start:end + 1]
                with fake.lock:
                    fake.log.append(('object', name, header, len(body)))
                self.reply(code, body, extra)

        self.server = http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    @property
    def origin(self):
        return f'http://127.0.0.1:{self.server.server_address[1]}'

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *exc):
        self.server.shutdown()
        self.server.server_close()

    def bytes_for(self, name, ranged=None):
        with self.lock:
            return sum(sent for kind, n, header, sent in self.log
                       if kind == 'object' and n == name and (ranged is None or bool(header) == ranged))


def sha256(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def wait_for(predicate, seconds, what):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.25)
    raise ValueError(f'Timed out waiting for {what}')


def smoke_lines(path):
    return path.read_text().splitlines() if path.exists() else []


def field(line, name):
    match = re.search(rf'\b{name}=(\S+)', line)
    return match[1] if match else None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--old', type=Path, required=True)
    parser.add_argument('--new', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--tag', default='v0.1.0+72', help='release tag the fake manifest names')
    parser.add_argument('--ed-private-key-file', type=Path, required=True,
                        help='throwaway Ed25519 private key (base64 seed) matching the public key built into both AppImages')
    parser.add_argument('--wrong-manifest-sha256', action='store_true',
                        help='negative case: the manifest names another SHA-256, so the app must refuse the '
                             'verified-looking download and leave the installed AppImage untouched')
    parser.add_argument('--signature', choices=['valid', 'wrong-key', 'missing'], default='valid',
                        help='negative cases: sign with another key, or publish no edSignature; the app must '
                             'refuse and leave the installed AppImage untouched')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    new = args.new.resolve()
    receipt = json.loads(new.with_suffix('.json').read_text())
    if sha256(new) != receipt['sha256']:
        raise ValueError('The new AppImage differs from its receipt')
    zsync = new.with_name(new.name + '.zsync')
    seed = appcast.decode_seed(args.ed_private_key_file.read_text())
    if args.signature == 'wrong-key':
        seed = os.urandom(32)
    signed = {}
    if args.signature != 'missing':
        signed['edSignature'] = base64.b64encode(appcast.sign_file(seed, new)[0]).decode('ascii')
    manifest = [dict(receipt, releaseTag=args.tag, **signed,
                     **({'sha256': '0' * 64} if args.wrong_manifest_sha256 else {}))]
    refusal = REFUSALS['wrong-sha256'] if args.wrong_manifest_sha256 else \
        REFUSALS.get(args.signature) if args.signature != 'valid' else None
    files = {new.name: new.read_bytes(), zsync.name: zsync.read_bytes(),
             f"build-manifest-{receipt['platform']}-{receipt['arch']}.json": json.dumps(manifest).encode()}
    started = []  # (name, Popen/pid) of everything we start, killed at the end
    with tempfile.TemporaryDirectory(prefix='raft-update-smoke-') as temporary, FakeGitHub(files) as github:
        root = Path(temporary)
        folder = root / 'apps'
        folder.mkdir()
        installed = folder / 'Raft.AppImage'
        shutil.copy2(args.old, installed)
        installed.chmod(0o755)
        old_sha = sha256(installed)
        env = dict(os.environ, HOME=str(root / 'home'),
                   XDG_DATA_HOME=str(root / 'data'), XDG_CONFIG_HOME=str(root / 'config'),
                   XDG_CACHE_HOME=str(root / 'cache'), XDG_RUNTIME_DIR=str(root / 'run'))
        for key in ('HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR'):
            Path(env[key]).mkdir(parents=True)
        Path(env['XDG_RUNTIME_DIR']).chmod(0o700)
        log = root / 'smoke.log'
        env.update(RAFT_UPDATE_ORIGIN=github.origin, RAFT_UPDATE_SMOKE='1', RAFT_UPDATE_SMOKE_RESTART='1',
                   RAFT_UPDATE_SMOKE_LOG=str(log), GDK_SCALE='1')
        display = f':{90 + os.getpid() % 100}'
        try:
            xvfb = subprocess.Popen(['Xvfb', display, '-screen', '0', '1280x800x24'],
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            started.append(xvfb.pid)
            env['DISPLAY'] = display
            # One session bus and keyring that outlive the first process, as on a desktop,
            # so the restarted app finds them again.
            bus = subprocess.run(['dbus-daemon', '--session', '--fork', '--print-address=1', '--print-pid=1'],
                                 env=env, text=True, capture_output=True, check=True).stdout.split()
            env['DBUS_SESSION_BUS_ADDRESS'] = bus[0]
            started.append(int(bus[1]))
            keyring = subprocess.run(['gnome-keyring-daemon', '--unlock', '--components=secrets'],
                                     input='', text=True, capture_output=True, env=env)
            if keyring.returncode:
                raise ValueError(f'keyring startup failed: {keyring.stderr.strip()}')
            for line in keyring.stdout.splitlines():
                if line.startswith('GNOME_KEYRING_PID='):
                    started.append(int(line.split('=')[1]))
            app_log = (args.output / 'app.log').open('w')
            clock = time.monotonic()
            first = subprocess.Popen([str(installed)], env=env, stdout=app_log, stderr=subprocess.STDOUT,
                                     start_new_session=True)
            started.append(first.pid)
            ready = wait_for(lambda: next((l for l in smoke_lines(log) if ' ready ' in l or ' failed ' in l
                                           or ' unavailable ' in l or ' uptodate ' in l), None), 240, 'the update to finish')
            if refusal:
                time.sleep(1)
                result = {'refusedLine': ready, 'installedUntouched': sha256(installed) == old_sha,
                          'leftoverFiles': sorted(p.name for p in folder.iterdir() if p.name != installed.name),
                          'rangeBytesDownloaded': github.bytes_for(new.name, ranged=True)}
                (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
                print(json.dumps(result, indent=2))
                if ' failed ' not in ready or refusal not in ready or not result['installedUntouched'] \
                        or result['leftoverFiles']:
                    sys.exit('Negative update smoke test failed')
                return
            if ' ready ' not in ready:
                raise ValueError(f'Update did not complete: {ready}')
            # The old process exits, the new one starts and reports its build.
            second_line = wait_for(lambda: next((l for l in smoke_lines(log)[smoke_lines(log).index(ready):]
                                                 if ' running ' in l), None), 120, 'the restarted app')
            second_pid = int(field(second_line, 'pid'))
            started.append(second_pid)
            wait_for(lambda: any(' uptodate ' in l for l in smoke_lines(log)), 60, 'the restarted app to check')
            elapsed = time.monotonic() - clock
            first.wait(timeout=30)
            full = len(files[new.name])
            ranged = github.bytes_for(new.name, ranged=True)
            result = {
                'oldBuild': field(smoke_lines(log)[0], 'build'), 'newBuild': field(second_line, 'build'),
                'oldAppImageBytes': args.old.stat().st_size, 'newAppImageBytes': full,
                'rangeBytesDownloaded': ranged,
                'rangeRequests': sum(1 for kind, n, h, _ in github.log if kind == 'object' and n == new.name and h),
                'fullDownloadBytes': github.bytes_for(new.name, ranged=False),
                'controlFileBytes': len(files[zsync.name]),
                'deltaFractionOfFullFile': round(ranged / full, 4),
                'appReport': {k: field(ready, k) for k in
                              ('downloaded', 'reused', 'target', 'control', 'requests', 'scanMs', 'downloadMs', 'verifyMs', 'totalMs')},
                'endToEndSeconds': round(elapsed, 1),
                'signedWith': 'edSignature in the manifest, verified by the app before replacing the file',
                'replacedFileMatchesNewSha256': sha256(installed) == receipt['sha256'],
                'oldSha256': old_sha, 'newSha256': receipt['sha256'],
                'leftoverFiles': sorted(p.name for p in folder.iterdir() if p.name != installed.name),
                'installedMode': oct(installed.stat().st_mode & 0o777),
                'restartedPid': second_pid, 'oldProcessExited': first.poll() is not None,
                'smokeLog': smoke_lines(log),
            }
            (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps(result, indent=2))
            if not (result['replacedFileMatchesNewSha256'] and result['newBuild'] != result['oldBuild']
                    and not result['leftoverFiles'] and result['fullDownloadBytes'] == 0
                    and ranged < full // 2):
                sys.exit('Update smoke test failed')
        finally:
            for pid in reversed(started):
                try:
                    os.kill(pid, signal.SIGTERM)
                except (ProcessLookupError, PermissionError):
                    pass


if __name__ == '__main__':
    main()
