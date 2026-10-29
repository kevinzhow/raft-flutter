/// The environment host programs (xdg-mime, update-desktop-database, a browser
/// or file manager) must see when Raft runs from an AppImage.
///
/// AppRun prepends the image's libraries and GIO/GTK data to the process
/// environment so Raft finds them; a host program that inherits them loads the
/// image's libraries and fails or misbehaves. AppRun exports the original
/// values (tool/appimage.py `host_environment_capture`) as
/// `RAFT_APPIMAGE_HOST_<NAME>` plus `RAFT_APPIMAGE_HOST_<NAME>_SET`: `x` when
/// the variable existed on the host (even as an empty string), empty when it
/// was unset. A plain `RAFT_HOST_<NAME>` value is also honoured. Without any
/// of them (an older AppRun) the polluted variables are dropped and entries
/// under `$APPDIR` are stripped from path lists.
library;

const _hostPrefix = 'RAFT_APPIMAGE_HOST_';
const _plainHostPrefix = 'RAFT_HOST_';
const _setSuffix = '_SET';

/// Variables AppRun rewrites for the image.
const linuxPollutedVariables = <String>[
  'PATH',
  'LD_LIBRARY_PATH',
  'GIO_MODULE_DIR',
  'GSETTINGS_SCHEMA_DIR',
  'GIO_LAUNCH_DESKTOP',
  'GTK_IM_MODULE_FILE',
  'GDK_PIXBUF_MODULE_FILE',
];

/// Removed when no host value can be restored: they only ever point into the
/// image. PATH is handled separately (it is filtered, not dropped).
const _droppedWithoutHostValue = <String>[
  'LD_LIBRARY_PATH',
  'GIO_MODULE_DIR',
  'GSETTINGS_SCHEMA_DIR',
  'GIO_LAUNCH_DESKTOP',
  'GTK_IM_MODULE_FILE',
  'GDK_PIXBUF_MODULE_FILE',
];

/// Always removed: they describe the AppImage runtime itself.
const _runtimeVariables = <String>['APPDIR', 'APPIMAGE', 'ARGV0', 'OWD'];

/// Path lists that may carry image directories even when the host value is
/// unknown.
const _pathLists = <String>['PATH', 'XDG_DATA_DIRS', 'XDG_CONFIG_DIRS'];

/// A copy of [environment] suitable for host child processes.
Map<String, String> linuxHostEnvironment(Map<String, String> environment) {
  final env = Map<String, String>.of(environment);
  final appDir = environment['APPDIR'] ?? '';
  final restored = <String>{};

  // Current contract: <NAME>_SET says whether the host had the variable.
  for (final key in environment.keys) {
    if (!key.startsWith(_hostPrefix) || !key.endsWith(_setSuffix)) continue;
    final name = key.substring(
      _hostPrefix.length,
      key.length - _setSuffix.length,
    );
    if (name.isEmpty) continue;
    restored.add(name);
    if (environment[key] == 'x') {
      env[name] = environment['$_hostPrefix$name'] ?? '';
    } else {
      env.remove(name);
    }
  }
  // Value-only exports (no _SET marker): restore a non-empty value, for the
  // variables AppRun is known to rewrite.
  for (final prefix in const [_hostPrefix, _plainHostPrefix]) {
    for (final entry in environment.entries) {
      final key = entry.key;
      if (!key.startsWith(prefix) || key.endsWith(_setSuffix)) continue;
      final name = key.substring(prefix.length);
      if (!linuxPollutedVariables.contains(name) || restored.contains(name)) {
        continue;
      }
      if (prefix == _hostPrefix &&
          environment.containsKey('$prefix$name$_setSuffix')) {
        continue;
      }
      restored.add(name);
      if (entry.value.isNotEmpty) {
        env[name] = entry.value;
      } else {
        env.remove(name);
      }
    }
  }

  // Older AppRun: nothing to restore, so drop what points into the image.
  for (final name in _droppedWithoutHostValue) {
    if (!restored.contains(name)) env.remove(name);
  }
  if (appDir.isNotEmpty) {
    for (final name in _pathLists) {
      if (restored.contains(name)) continue;
      final value = env[name];
      if (value == null) continue;
      final kept = value
          .split(':')
          .where((entry) => !_under(entry, appDir))
          .join(':');
      if (kept.isEmpty) {
        env.remove(name);
      } else {
        env[name] = kept;
      }
    }
  }

  env.removeWhere(
    (key, _) =>
        key.startsWith(_hostPrefix) ||
        key.startsWith(_plainHostPrefix) ||
        _runtimeVariables.contains(key),
  );
  return env;
}

bool _under(String entry, String directory) {
  final base = directory.endsWith('/')
      ? directory.substring(0, directory.length - 1)
      : directory;
  return entry == base || entry.startsWith('$base/');
}
