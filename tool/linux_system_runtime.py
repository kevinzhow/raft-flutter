"""One distribution-owned GTK/WebKit/media ABI; no bundled system libraries."""
from pathlib import Path
import os
import re
import shlex

POLICY = 'system-gtk3-webkitgtk-4.1-v1'
APP_LIBRARIES = {'libflutter_linux_gtk.so', 'libapp.so', 'libsqlite3.so'}
WEB_EXTENSION = 'raft-webview/libraft_system_webview_extension.so'
OBSOLETE_PLUGINS = {'libflutter_inappwebview_linux_plugin.so', 'libmedia_kit_libs_linux_plugin.so'}
LINKED_SYSTEM_ABIS = {'libmedia_kit_video_plugin.so': 'libmpv.so.2',
                      'libraft_system_webview_plugin.so': 'libwebkit2gtk-4.1.so.0'}
PACKAGES = {
    'ubuntu-24.04': ['libgtk-3-0t64', 'libwebkit2gtk-4.1-0', 'libsoup-3.0-0',
                    'libsecret-1-0', 'libmpv2', 'poppler-utils', 'glib-networking',
                    'librsvg2-common', 'gstreamer1.0-plugins-base', 'gstreamer1.0-plugins-good'],
    'fedora-44': ['gtk3', 'webkit2gtk4.1', 'libsoup3', 'libsecret', 'mpv-libs',
                  'poppler-utils', 'glib-networking', 'librsvg2',
                  'gstreamer1-plugins-base', 'gstreamer1-plugins-good'],
}
INSTRUCTIONS = ('This is a thin Linux package. Install the distribution GTK3, WebKitGTK4.1, '
                'libsoup3, libsecret, libmpv2, Poppler and GStreamer runtime packages. '
                'Ubuntu24.04 and Fedora44 are the declared runtime targets; codec support '
                'follows the installed distribution packages. No browser or system ABI is bundled.')


def inventory(stage, executable='raft_flutter'):
    """Reject stale thick bundles before a packager patches or probes any ELF."""
    stage = Path(stage).resolve()
    libraries, elfs = [], []
    for path in stage.rglob('*'):
        relative = path.relative_to(stage)
        if path.is_symlink() and (not path.resolve().is_relative_to(stage) or not path.resolve().is_file()):
            raise ValueError('Linux system runtime bundle contains an external/broken symlink')
        if not path.is_file():
            continue
        name = path.name
        if relative.parts[0] == 'lib':
            library = path.relative_to(stage / 'lib').as_posix()
            owned = (library in APP_LIBRARIES or library == WEB_EXTENSION
                     or re.fullmatch(r'lib[A-Za-z0-9_]+_plugin\.so', library))
            if not owned or name in OBSOLETE_PLUGINS:
                raise ValueError('System libraries/obsolete renderers must not be bundled: ' + relative.as_posix())
            libraries.append(library)
        if any(value in relative.as_posix().lower() for value in ('raft-html-webview', 'lib-fallback', 'loaders.cache')):
            raise ValueError('Stale private system runtime data must not be bundled: ' + relative.as_posix())
        with path.open('rb') as stream:
            is_elf = stream.read(4) == b'\x7fELF'
        if is_elf:
            if relative.as_posix() != executable and relative.parts[0] != 'lib':
                raise ValueError('Unowned ELF in thin Linux bundle: ' + relative.as_posix())
            elfs.append(path)
    if 'libraft_system_webview_plugin.so' in libraries and WEB_EXTENSION not in libraries:
        raise ValueError('System WebView plugin lacks its required native WebExtension')
    if not (stage / executable).is_file():
        raise ValueError('Thin Linux bundle lacks its application executable')
    return sorted(set(libraries)), sorted(elfs)


def verify_linked_system_abi(path, needed):
    """Refuse a stub video plugin or a browser linked to the retired engine."""
    required = LINKED_SYSTEM_ABIS.get(Path(path).name)
    if required and required not in {name.strip() for name in needed.splitlines()}:
        raise ValueError(Path(path).name + ' must link the distribution ' + required)


def rpath(path, stage):
    relative = os.path.relpath(Path(stage) / 'lib', Path(path).parent)
    return '$ORIGIN' if relative == '.' else '$ORIGIN/' + Path(relative).as_posix()


HOST_LAUNCH_VARIABLES = ('PATH', 'LD_LIBRARY_PATH', 'GIO_MODULE_DIR',
                         'GSETTINGS_SCHEMA_DIR', 'GIO_LAUNCH_DESKTOP', 'GTK_IM_MODULE_FILE',
                         'GDK_PIXBUF_MODULE_FILE')


def host_environment_capture():
    # Dart's existing host-child sanitizer consumes these markers. No system
    # environment value is rewritten and GIO keeps its distribution launcher.
    return ''.join('export RAFT_APPIMAGE_HOST_' + key + '_SET="${' + key + '+x}"\n'
                   'export RAFT_APPIMAGE_HOST_' + key + '="${' + key + '-}"\n'
                   for key in HOST_LAUNCH_VARIABLES)


def launcher(executable='raft_flutter', prefix='$app_dir'):
    if not re.fullmatch(r'[A-Za-z0-9_]+', executable) or prefix not in ('$app_dir', '$app_dir/raft'):
        raise ValueError('Launcher needs a fixed application path')
    return ('#!/bin/sh\nset -eu\n'
            'app_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\n' +
            host_environment_capture() +
            '# System GTK/WebKit/media and their child processes keep host module paths.\n'
            'if ! command -v ldd >/dev/null 2>&1; then\n'
            '  printf "%s\\n" ' + shlex.quote(INSTRUCTIONS) + ' "Missing distribution ldd tool" >&2; exit 1\nfi\n'
            # Include app-owned dynamically loaded modules, not just the runner.
            'for runtime_elf in "' + prefix + '/' + executable + '" "' + prefix + '/lib/"*.so "' + prefix + '/lib/raft-webview/"*.so; do\n'
            '  [ -f "$runtime_elf" ] || continue\n'
            '  if ! runtime_check=$(LC_ALL=C ldd "$runtime_elf" 2>&1); then\n'
            '    printf "%s\\n" ' + shlex.quote(INSTRUCTIONS) + ' "$runtime_check" >&2\n    exit 1\n  fi\n'
            '  case "$runtime_check" in\n'
            '    *"not found"*) printf "%s\\n" ' + shlex.quote(INSTRUCTIONS) + ' "$runtime_check" >&2; exit 1;;\n'
            '  esac\ndone\n'
            'exec "' + prefix + '/' + executable + '" "$@"\n')


def receipt(libraries, dependencies):
    return {'policy': POLICY, 'engine': 'distribution WebKitGTK API4.1 (GTK3/libsoup3)',
            'appPrivateLibraries': libraries, 'bundledSystemLibraries': [],
            'systemSONAMEs': sorted(dependencies), 'distributionPackages': PACKAGES,
            'requiredPluginSONAMEs': LINKED_SYSTEM_ABIS,
            'launchDependencyChecks': 'runner plus every app-owned shared module, including WebExtension',
            'runtimePrerequisites': INSTRUCTIONS,
            'privateSQLite': 'Dart native asset libsqlite3.so has no system SONAME; libsqlite3.so.0 is not shipped',
            'nativeWebExtension': {'path': 'lib/' + WEB_EXTENSION, 'kind': 'app-owned adapter, not browser engine',
                                   'installed': WEB_EXTENSION in libraries, 'systemSONAMEShadowing': False},
            'runtimeAcceptance': 'NOT_RUN by static packaging'}
