#!/usr/bin/env python3
"""Exercise the downloaded production AppImage in a disposable CI desktop."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import sys
import subprocess
import tempfile
import time


def capture(args):
    return subprocess.check_output([str(x) for x in args], text=True).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--artifact', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mode', choices=['direct', 'extract', 'wayland'], required=True)
    args = parser.parse_args()
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('Production startup checks are limited to disposable CI environments')
    args.output.mkdir(parents=True, exist_ok=True)
    artifact = args.artifact.resolve()
    receipt = json.loads(artifact.with_suffix('.json').read_text())
    if hashlib.sha256(artifact.read_bytes()).hexdigest() != receipt['sha256']:
        raise ValueError('Downloaded AppImage differs from the source-bound receipt')
    if args.mode == 'extract':
        with tempfile.TemporaryDirectory(prefix='raft-appimage-pdf-ci-') as temporary:
            subprocess.run([str(artifact), '--appimage-extract'], cwd=temporary,
                           stdout=subprocess.DEVNULL, check=True)
            payload = Path(temporary) / 'squashfs-root/raft'
            checked = 0
            for path in payload.rglob('*'):
                if not path.is_file():
                    continue
                with path.open('rb') as stream:
                    if stream.read(4) != b'\x7fELF':
                        continue
                listing = capture(['ldd', path])
                if 'not found' in listing or 'version `' in listing:
                    raise ValueError(f'Downloaded payload cannot resolve {path}: {listing}')
                checked += 1
            for name in ('pdfinfo', 'pdftoppm'):
                subprocess.run([str(payload / 'bin' / name), '-v'], check=True)
            # A real page conversion, rather than accepting a helper's existence.
            pdf = Path(temporary) / 'page.pdf'
            objects = [b'<< /Type /Catalog /Pages 2 0 R >>',
                       b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
                       b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Contents 4 0 R >>']
            drawing = b'0 0 1 rg 10 10 80 80 re f\n'
            objects.append(b'<< /Length ' + str(len(drawing)).encode() + b' >>\nstream\n' + drawing + b'endstream')
            data = b'%PDF-1.4\n'
            offsets = [0]
            for index, obj in enumerate(objects, 1):
                offsets.append(len(data))
                data += str(index).encode() + b' 0 obj\n' + obj + b'\nendobj\n'
            startxref = len(data)
            data += b'xref\n0 5\n0000000000 65535 f \n'
            data += b''.join(f'{offset:010d} 00000 n \n'.encode() for offset in offsets[1:])
            data += f'trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n{startxref}\n%%EOF\n'.encode()
            pdf.write_bytes(data)
            subprocess.run([str(payload / 'bin/pdftoppm'), '-png', '-singlefile', str(pdf), str(Path(temporary) / 'page')], check=True)
            colors = int(capture(['identify', '-format', '%k', Path(temporary) / 'page.png']))
            if colors < 2:
                raise ValueError('Bundled PDF tool did not render the colored page')
            # Reproduce the Fedora failure using the actual bundled GLib and
            # launcher, without opening a browser or accessing any account.
            desktop_env = dict(os.environ,
                LD_LIBRARY_PATH=str(payload / 'lib'),
                GIO_MODULE_DIR=str(payload / 'lib/gio/modules'),
                GSETTINGS_SCHEMA_DIR=str(payload.parent / 'usr/share/glib-2.0/schemas'),
                GIO_LAUNCH_DESKTOP=str(payload / 'bin/raft-gio-launch-desktop'))
            for key in ('PATH', 'LD_LIBRARY_PATH', 'GIO_MODULE_DIR',
                        'GSETTINGS_SCHEMA_DIR', 'GIO_LAUNCH_DESKTOP', 'GTK_IM_MODULE_FILE', 'GDK_PIXBUF_MODULE_FILE'):
                prefix = 'RAFT_APPIMAGE_HOST_' + key
                desktop_env[prefix + '_SET'] = 'x' if key in os.environ else ''
                desktop_env[prefix] = os.environ.get(key, '')
            for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
                folder = Path(temporary) / key
                folder.mkdir()
                desktop_env[key] = str(folder)
            subprocess.run([sys.executable, str(Path(__file__).with_name('appimage-gio-smoke.py')),
                            str(payload)], env=desktop_env, check=True)
            subprocess.run([sys.executable, str(Path(__file__).with_name('appimage-image-smoke.py')),
                            str(payload)], env=desktop_env, check=True)
            (args.output / 'payload-check.json').write_text(json.dumps({
                'commit': receipt['commit'], 'elfFilesChecked': checked,
                'pdfPageRendered': True, 'pdfColors': colors,
                'desktopLauncherSpawned': True, 'desktopEnvironmentRestored': True,
                'nativeSvgDecoded': True}, indent=2) + '\n')
    if args.mode != 'direct' and Path('/dev/fuse').exists():
        # Extract mode still never opens /dev/fuse; containers additionally prove
        # it works when the device itself does not exist.
        fuse_state = 'present; explicit extract-and-run'
    else:
        fuse_state = 'absent' if not Path('/dev/fuse').exists() else 'present'
    with tempfile.TemporaryDirectory(prefix='raft-appimage-ci-') as temporary:
        env = dict(os.environ, GDK_SCALE='2', GDK_DPI_SCALE='1',
                   XDG_DATA_HOME=str(Path(temporary) / 'data'),
                   XDG_CONFIG_HOME=str(Path(temporary) / 'config'),
                   XDG_CACHE_HOME=str(Path(temporary) / 'cache'))
        for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
            Path(env[key]).mkdir(parents=True)
        keyring = subprocess.run(['gnome-keyring-daemon', '--unlock', '--components=secrets'],
                                 input='', text=True, capture_output=True, env=env)
        if keyring.returncode:
            raise ValueError(f'CI keyring startup failed: {keyring.stderr.strip()}')
        command = [str(artifact)]
        if args.mode != 'direct':
            command.append('--appimage-extract-and-run')
        if args.mode == 'wayland':
            env.update(GDK_BACKEND='wayland', WAYLAND_DEBUG='1')
        logfile = args.output / f'{args.mode}-launch.log'
        with logfile.open('w') as log:
            process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                deadline = time.monotonic() + 40
                window = None
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        raise ValueError(f'AppImage exited before painting: {process.returncode}')
                    if args.mode == 'wayland':
                        log.flush()
                        text = logfile.read_text()
                        # Tie the painted surface to Raft's toplevel, not a cursor buffer.
                        surfaces = re.findall(r'get_xdg_surface\(new id xdg_surface[#@](\d+), wl_surface[#@](\d+)\)', text)
                        toplevels = dict(re.findall(r'xdg_surface[#@](\d+)\.get_toplevel\(new id xdg_toplevel[#@](\d+)\)', text))
                        for surface, wl_surface in surfaces:
                            toplevel = toplevels.get(surface)
                            if toplevel and re.search(rf'xdg_toplevel[#@]{toplevel}\.set_app_id\("app\.raft\.raft_flutter"\)', text) and \
                                    re.search(rf'wl_surface[#@]{wl_surface}\.attach\(wl_buffer', text) and \
                                    re.search(rf'wl_surface[#@]{wl_surface}\.commit\(', text):
                                window = f'Raft toplevel {toplevel}, painted Wayland surface {wl_surface}'
                    else:
                        matches = re.findall(r'(0x[0-9a-f]+) "Raft"', capture(['xwininfo', '-root', '-tree']))
                        if matches:
                            window = matches[0]
                    if window:
                        break
                    time.sleep(0.25)
                if window is None:
                    raise ValueError('No production Raft window/frame appeared')
                time.sleep(5)
                if process.poll() is not None:
                    raise ValueError('AppImage exited after creating the window')
                log.flush()
                text = logfile.read_text()
                if 'libsecret_error:' in text or 'error while loading shared libraries:' in text:
                    raise ValueError('AppImage startup contains a missing library or secure-storage failure')
                result = {'artifact': artifact.name, 'commit': receipt['commit'], 'sha256': receipt['sha256'],
                          'mode': args.mode, 'fuseDevice': fuse_state,
                          'window': window, 'GDK_SCALE': 2, 'GDK_DPI_SCALE': 1,
                          'osRelease': Path('/etc/os-release').read_text(),
                          'scope': 'production first screen; no account or messaging acceptance',
                          'softwareRenderingForced': env.get('LIBGL_ALWAYS_SOFTWARE') == '1'}
                png = args.output / f'raft-linux-appimage-{args.mode}-hidpi.png'
                if args.mode == 'wayland':
                    tree = capture(['xwininfo', '-root', '-tree'])
                    outputs = re.findall(r'(0x[0-9a-f]+) "[^"\n]*(?:KDE Wayland Compositor|KWin)[^"\n]*"', tree)
                    if len(outputs) != 1:
                        raise ValueError(f'Expected one nested KWin output window: {tree}')
                    if not re.search(r'wl_output[#@]\d+\.scale\(2\)', text):
                        raise ValueError('The native Wayland client did not receive a 2x output scale')
                    subprocess.run(['import', '-window', outputs[0], png], check=True)
                    result.update(captureWindow=outputs[0], waylandOutputScale=2)
                else:
                    subprocess.run(['import', '-window', window, png], check=True)
                width, height, colors = map(int, capture(['identify', '-format', '%w %h %k', png]).split())
                if width < 1000 or height < 600 or colors < 32:
                    raise ValueError('Screenshot lacks a full painted HiDPI window')
                result.update(file=png.name, width=width, height=height, colors=colors,
                              capture='Nested KWin rendered output (native Wayland client)' if args.mode == 'wayland' else 'X11 Raft window')
                (args.output / f'{args.mode}.json').write_text(json.dumps(result, indent=2) + '\n')
            finally:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=10)


if __name__ == '__main__':
    main()
