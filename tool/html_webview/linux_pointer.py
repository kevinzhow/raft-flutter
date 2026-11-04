"""Prepare a pinned Pub path override with one reviewed Linux pointer adapter."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import tarfile
import urllib.request

VERSION = '0.1.0-beta.1'
PACKAGE = 'flutter_inappwebview_linux'
URL = f'https://pub.dev/api/archives/{PACKAGE}-{VERSION}.tar.gz'
ARCHIVE_SHA256 = '2e1a3b09bb911fb5a8bb155cb7f1eb1428a19b6e20363b9db48beef428b8cef5'
TARGET = 'lib/src/in_app_webview/custom_platform_view.dart'
RECEIPT = '.raft-pointer-adapter.json'
MAX_ARCHIVE = 8 * 1024 * 1024
WORKSPACE_PATH = Path('.dart_tool/raft_plugins/flutter_inappwebview_linux')


def linked_path(path):
    return path.is_symlink() or (hasattr(path, 'is_junction') and path.is_junction())


def package_mode_matches(path):
    # NTFS does not round-trip POSIX permission bits through chmod/stat.
    # File identity, single-link ownership and every byte are checked there too.
    return os.name != 'posix' or path.stat().st_mode & 0o7777 == 0o644


def sha(data):
    return hashlib.sha256(data).hexdigest()


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('The pinned Linux pointer patch site changed')
    return text.replace(old, new, 1)


def patch(text):
    text = replace_once(text, '  final _downButtons = <int, PointerButton>{};', '''  final _downButtons = <int, PointerButton>{};
  Future<void> _pointerEvents = Future<void>.value();
  final _pointerDisposed = Completer<void>();
  bool _pointerDispatchFailed = false;

  // Preserve the complete input sequence while native focus is pending. In
  // particular Up/Cancel/Move must not overtake the first asynchronous Down.
  void _dispatchPointerEvent(Future<void> Function() send,
      {bool beginsGesture = false}) {
    _pointerEvents = _pointerEvents.then((_) async {
      if (!mounted || !_controller.value.isInitialized) return;
      if (_pointerDispatchFailed && !beginsGesture) return;
      if (beginsGesture) _pointerDispatchFailed = false;
      try {
        await send();
      } catch (error, stack) {
        _downButtons.clear();
        _activeTouchPoints.clear();
        _pointerDispatchFailed = true;
        FlutterError.reportError(FlutterErrorDetails(
          exception: error, stack: stack,
          library: 'flutter_inappwebview_linux pointer dispatch',
        ));
      }
    });
  }''')
    # Match complete pinned callback boundaries, preserving every original body.
    callbacks = [
        ('onPointerHover', 'ev', 'onPointerDown'),
        ('onPointerDown', 'ev', 'onPointerUp'),
        ('onPointerUp', 'ev', 'onPointerCancel'),
        ('onPointerCancel', 'ev', 'onPointerMove'),
        ('onPointerMove', 'ev', 'onPointerSignal'),
        ('onPointerSignal', 'signal', 'onPointerPanZoomUpdate'),
        ('onPointerPanZoomUpdate', 'ev', 'child'),
        ('onEnter', 'ev', 'onExit'),
        ('onExit', 'ev', 'child'),
    ]
    for name, argument, following in callbacks:
        opener = f'{name}: ({argument})' + (' async' if name == 'onPointerDown' else '') + ' {'
        start = text.index(opener)
        end = text.index(f'                {following}:', start)
        chunk = text[start:end]
        last = chunk.rfind('},')
        if last < 0:
            raise ValueError('Missing pinned pointer callback boundary')
        chunk = chunk[:last] + ('}, beginsGesture: true),' if name == 'onPointerDown' else '}),') + chunk[last + 2:]
        chunk = replace_once(chunk, opener, f'{name}: ({argument}) => _dispatchPointerEvent(() async {{')
        text = text[:start] + chunk + text[end:]
    text = replace_once(text, 'await _controller._setFocused(true);', '''await Future.any<void>([
                        _controller._setFocused(true), _pointerDisposed.future,
                      ]);
                      if (!mounted) return;''')
    return replace_once(text, '    super.dispose();\n    _cursorSubscription?.cancel();',
                        '    super.dispose();\n    _pointerDisposed.complete();\n    _cursorSubscription?.cancel();')


def entries(archive):
    """Authenticate before extraction; reject links and all non-regular entries."""
    if archive.stat().st_size > MAX_ARCHIVE or sha(archive.read_bytes()) != ARCHIVE_SHA256:
        raise ValueError('The Linux Pub archive does not match its fixed SHA256')
    output = {}
    with tarfile.open(archive, 'r:gz') as tar:
        for member in tar:
            name = PurePosixPath(member.name)
            if (name.is_absolute() or '..' in name.parts or '\\' in member.name
                    or ':' in member.name or name.as_posix() != member.name):
                raise ValueError('Unsafe Pub archive path')
            if member.isdir():
                continue
            if (not member.isfile() or member.name in output or member.size > MAX_ARCHIVE
                    or member.mode != 0o644):
                raise ValueError('Unsupported Pub archive entry')
            output[member.name] = tar.extractfile(member).read()
            if sum(map(len, output.values())) > 2 * MAX_ARCHIVE:
                raise ValueError('Expanded Pub archive exceeds its bound')
    if TARGET not in output or not output.get('pubspec.yaml', b'').startswith(b'name: flutter_inappwebview_linux\n'):
        raise ValueError('Unexpected Linux plugin package layout')
    return output


def prepare(archive, destination):
    archive, destination = Path(archive), Path(destination).absolute()
    if any(linked_path(parent) for parent in [destination, *destination.parents]):
        raise ValueError('Generated plugin paths cannot traverse symbolic links')
    original = entries(archive)
    adapted = {**original, TARGET: patch(original[TARGET].decode()).encode()}
    receipt = {'package': PACKAGE, 'version': VERSION, 'url': URL,
               'archiveSha256': ARCHIVE_SHA256, 'adapterSha256': sha(Path(__file__).read_bytes()),
               'patchedFiles': [TARGET], 'original': {n: sha(v) for n, v in original.items()},
               'output': {n: sha(v) for n, v in adapted.items()},
               'fileModes': {n: 0o644 for n in original}}
    if os.path.lexists(destination):
        if linked_path(destination) or not destination.is_dir():
            raise ValueError('Existing generated plugin is not a private directory; preserve it')
        contents = list(destination.rglob('*'))
        files = {p.relative_to(destination).as_posix(): p for p in contents if not p.is_dir()}
        if (set(files) != {*adapted, RECEIPT} or any(linked_path(p) for p in contents)
                or any(p.stat().st_nlink != 1 or not package_mode_matches(p)
                       for p in files.values())):
            raise ValueError('Existing generated plugin differs; preserve it and use a new destination')
        if json.loads(files[RECEIPT].read_text()) != receipt or any(sha(files[n].read_bytes()) != sha(v) for n, v in adapted.items()):
            raise ValueError('Existing generated plugin differs; preserve it and use a new destination')
        return receipt
    destination.mkdir(parents=True)
    for name, data in adapted.items():
        file = destination / name
        file.parent.mkdir(parents=True, exist_ok=True)
        with file.open('xb') as output:
            output.write(data)
        file.chmod(0o644)
    (destination / RECEIPT).write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    (destination / RECEIPT).chmod(0o644)
    return receipt


def download(destination):
    """Explicit official-source fetch only; no untrusted cache supplies the pin."""
    destination = Path(destination)
    if os.path.lexists(destination):
        entries(destination)
        return
    with urllib.request.urlopen(URL, timeout=30) as response:
        data = response.read(MAX_ARCHIVE + 1)
    if len(data) > MAX_ARCHIVE or sha(data) != ARCHIVE_SHA256:
        raise ValueError('Official Pub download did not match the pinned archive')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open('xb') as output:
        output.write(data)


def ensure_workspace(root, arguments):
    """Materialize Pub's declared local override before commands that use it."""
    if not arguments:
        return
    command = arguments[0]
    package_command = command == 'pub' and len(arguments) > 1 and arguments[1] in {
        'get', 'upgrade', 'downgrade', 'deps', 'outdated',
    }
    if not package_command and command not in {'analyze', 'test', 'build', 'run', 'drive', 'gen-l10n'}:
        return
    root = Path(root)
    archive = root / '.local/pub-archives' / f'{PACKAGE}-{VERSION}.tar.gz'
    if not os.path.lexists(archive):
        if '--offline' in arguments or '--no-pub' in arguments:
            raise ValueError('Pinned Linux plugin archive is absent; prepare it with tool/flutter pub get before offline use')
        download(archive)
    return prepare(archive, root / WORKSPACE_PATH)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--destination', required=True, type=Path)
    parser.add_argument('--download', action='store_true')
    arguments = parser.parse_args()
    if arguments.download:
        download(arguments.archive)
    result = prepare(arguments.archive, arguments.destination)
    print(json.dumps({'package': result['package'], 'version': result['version'],
                      'archiveSha256': result['archiveSha256'], 'patchedFiles': result['patchedFiles'],
                      'files': len(result['output'])}, indent=2))
