"""Windows SDK launch after the official entrypoint has bootstrapped it."""
import hashlib
import json
import os
from pathlib import Path
import re


def _probe_stream(value):
    """Bound SDK diagnostics without relaying URLs or credential-shaped text."""
    value = value or ''
    text = re.sub(r'(?i)\b(?:https?|socks5?|ssh)://[^\s\"\'<>]+', '<url>', value)
    text = re.sub(r'(?im)([^\r\n]*?(?:token|secret|password|passwd|authorization|api[_ -]?key)'
                  r'[^\r\n:=]*[:=])[^\r\n]*', r'\1 <redacted>', text)
    text = re.sub(r'(?i)\b(Bearer|Basic)\s+[A-Za-z0-9+/=._-]+', r'\1 <redacted>', text)
    text = re.sub(r'(?<![A-Za-z0-9])(?:[A-Za-z0-9_+/=-]{24,})(?![A-Za-z0-9])',
                  '<opaque>', text)
    truncated = len(text) > 2048
    return {'characters': len(value), 'sha256': hashlib.sha256(value.encode('utf-8')).hexdigest(),
            'head': text[:1024] if truncated else text,
            'tail': text[-1024:] if truncated else '', 'truncated': truncated}


def sdk_probe_report(result):
    """Report the official probe, never interpret noise as a version result."""
    return json.dumps({'returnCode': result.returncode,
                       'stdout': _probe_stream(result.stdout),
                       'stderr': _probe_stream(result.stderr)}, ensure_ascii=True, sort_keys=True)


def windows_arguments(value):
    """Parse FLUTTER_TOOL_ARGS as Windows argv, including quoted SDK paths."""
    if not value.strip():
        return []
    import ctypes
    from ctypes import wintypes

    parse = ctypes.WinDLL('shell32', use_last_error=True).CommandLineToArgvW
    parse.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(ctypes.c_int)]
    parse.restype = ctypes.POINTER(wintypes.LPWSTR)
    free = ctypes.WinDLL('kernel32', use_last_error=True).LocalFree
    free.argtypes = [wintypes.HLOCAL]
    free.restype = wintypes.HLOCAL
    count = ctypes.c_int()
    arguments = parse(f'dart {value}', ctypes.byref(count))
    if not arguments:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        return [arguments[index] for index in range(1, count.value)]
    finally:
        free(ctypes.cast(arguments, wintypes.HLOCAL))


def windows_sdk_command(executable, arguments, environment):
    """Match pinned flutter.bat's final Dart command without cmd.exe's 8K limit.

    The caller must first run flutter.bat --version --machine successfully:
    that official short command owns SDK installation, locking and snapshot
    rebuilding. Custom launchers without this SDK layout retain their entrypoint.
    """
    executable = Path(executable).absolute()
    sdk = executable.parent.parent
    dart = sdk / 'bin/cache/dart-sdk/bin/dart.exe'
    snapshot = sdk / 'bin/cache/flutter_tools.snapshot'
    packages = sdk / 'packages/flutter_tools/.dart_tool/package_config.json'
    child_env = dict(environment)
    if (executable.name.lower() != 'flutter.bat'
            or executable.parent.name.lower() != 'bin'
            or not all(path.is_file() for path in (dart, snapshot, packages))):
        return [str(executable), *arguments], child_env

    # flutter.bat uses SETLOCAL, so its SDK root and bundled Git do not survive
    # the bootstrap process. Reproduce those two settings for the native launch.
    child_env['FLUTTER_ROOT'] = str(sdk)
    mingit = sdk / 'bin/mingit/cmd'
    if mingit.is_dir():
        child_env['PATH'] = child_env.get('PATH', '') + os.pathsep + str(mingit)
    return [str(dart), f'--packages={packages}',
            *windows_arguments(child_env.get('FLUTTER_TOOL_ARGS', '')),
            str(snapshot), *arguments], child_env
