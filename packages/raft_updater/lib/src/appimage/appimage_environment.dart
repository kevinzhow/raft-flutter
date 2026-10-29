import 'dart:io';

import 'package:flutter/foundation.dart';

import 'update_information.dart';

/// Whether this process runs from an AppImage that can replace itself.
@immutable
class AppImageSupport {
  const AppImageSupport.unavailable(String this.reason)
    : path = null,
      information = null;
  const AppImageSupport.available(String this.path, this.information)
    : reason = null;

  /// The real path of the AppImage file (symlinks resolved); null when
  /// [reason] explains why updating in place is impossible.
  final String? path;
  final AppImageUpdateInformation? information;
  final String? reason;

  bool get available => path != null;

  /// Checks `$APPIMAGE` (set by the AppImage runtime), the update information
  /// embedded in the file and that its folder accepts a new file: the update
  /// writes `<name>.part` beside it and renames it over the original.
  static AppImageSupport detect(Map<String, String> environment) {
    final raw = environment['APPIMAGE'] ?? '';
    if (raw.isEmpty) {
      return const AppImageSupport.unavailable(
        'Not running from an AppImage (APPIMAGE is not set).',
      );
    }
    final String path;
    try {
      path = File(raw).resolveSymbolicLinksSync();
    } on FileSystemException {
      return AppImageSupport.unavailable('The AppImage file $raw is missing.');
    }
    if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) {
      return AppImageSupport.unavailable('$path is not a file.');
    }
    final information = AppImageUpdateInformation.read(path);
    if (information == null) {
      return AppImageSupport.unavailable(
        'This AppImage carries no usable update information.',
      );
    }
    final folder = File(path).parent;
    try {
      final probe = File('${folder.path}/.raft-update-probe-$pid')
        ..createSync(exclusive: true);
      probe.deleteSync();
    } on FileSystemException {
      return AppImageSupport.unavailable(
        'The folder ${folder.path} is not writable.',
      );
    }
    return AppImageSupport.available(path, information);
  }
}

/// Variables `AppRun` rewrites for the bundled libraries, and the recorded
/// host values it restores them from (`tool/appimage.py`,
/// `HOST_LAUNCH_VARIABLES` and `host_environment_capture`).
const List<String> _hostLaunchVariables = [
  'PATH',
  'LD_LIBRARY_PATH',
  'GIO_MODULE_DIR',
  'GSETTINGS_SCHEMA_DIR',
  'GIO_LAUNCH_DESKTOP',
  'GTK_IM_MODULE_FILE',
  'GDK_PIXBUF_MODULE_FILE',
];

/// The environment a process started by Raft should see: the one the user's
/// shell had, not the bundled-library one that AppRun built (the same
/// restoration `raft-gio-launch-desktop` does for desktop applications).
Map<String, String> hostEnvironment(Map<String, String> environment) {
  final out = Map<String, String>.of(environment);
  for (final key in _hostLaunchVariables) {
    if (environment['RAFT_APPIMAGE_HOST_${key}_SET'] == 'x') {
      out[key] = environment['RAFT_APPIMAGE_HOST_$key'] ?? '';
    } else if (environment.containsKey('RAFT_APPIMAGE_HOST_${key}_SET')) {
      out.remove(key);
    }
  }
  out.removeWhere((key, _) => key.startsWith('RAFT_APPIMAGE_HOST_'));
  for (final key in const ['APPDIR', 'APPIMAGE', 'ARGV0', 'OWD']) {
    out.remove(key);
  }
  return out;
}
