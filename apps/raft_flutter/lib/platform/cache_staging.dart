import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where temporary staging copies (preview inputs, share-sheet copies, save
/// and export copies) live.
///
/// Desktop: `<app cache>/staging/`, because the system temporary directory is
/// not the cache there and on Linux `/tmp` is often a RAM disk.
///
/// Android and iOS: the platform temporary directory, which already is the app
/// cache directory (`Context.cacheDir`, `Library/Caches`). The native share
/// and PDF bridges allow-list `raft-share` and `raft-previews` directly under
/// it (FileProvider paths, `ShareInboxWriter.exportFile`,
/// `NativePdfPreviewBridge`), so these two names stay at the top of it.
Future<Directory> cacheStagingDirectory() async {
  if (Platform.isAndroid || Platform.isIOS) return getTemporaryDirectory();
  return Directory(
    p.join((await getApplicationCacheDirectory()).path, 'staging'),
  );
}

/// Leftover staging older than this is deleted at start.
const Duration stagingMaxAge = Duration(hours: 1);

/// A folder written within this long is a transfer that may still be running:
/// "Clear cache" leaves it (see [clearStaging]).
const Duration stagingFreshWindow = Duration(minutes: 5);

/// Staging folders something is using right now (path -> holders).
final Map<String, int> _held = {};

/// Marks [directory] in use until the returned callback is called (once). A
/// live `SharedFileLease` holds its folder this way; [sweepStaging] callers
/// that pass [isStagingHeld] as `inUse` then leave it alone.
void Function() holdStaging(String directory) {
  final path = p.normalize(directory);
  _held[path] = (_held[path] ?? 0) + 1;
  var released = false;
  return () {
    if (released) return;
    released = true;
    final left = (_held[path] ?? 0) - 1;
    if (left > 0) {
      _held[path] = left;
    } else {
      _held.remove(path);
    }
  };
}

/// Whether [path] is, or contains, a held staging folder.
bool isStagingHeld(String path) {
  final normal = p.normalize(path);
  return _held.keys.any((held) => held == normal || p.isWithin(normal, held));
}

bool _isStagingName(String name) =>
    name == 'raft-previews' ||
    name == 'raft-share' ||
    name.startsWith('raft-attachment-') ||
    name.startsWith('raft-export-') ||
    name.startsWith('raft-gallery-');

/// Deletes staging folders that nobody can still be using: those whose newest
/// change (the folder or a file directly in it) is older than [maxAge]. Run
/// once at start, never on a timer.
///
/// Looks in [staging] and, for what earlier versions left there, in
/// [legacyTemporary] (the system temporary directory). Only the known staging
/// names are touched, never anything else: on Android, iOS and macOS the
/// temporary and cache directories are the same directory, and received
/// shares (`raft-incoming`, user data) live beside them. Returns the number of
/// folders removed.
///
/// A folder for which [inUse] says true (a live lease's) is kept whatever its
/// age.
Future<int> sweepStaging({
  required Directory staging,
  Directory? legacyTemporary,
  Duration maxAge = stagingMaxAge,
  DateTime Function()? clock,
  bool Function(String path)? inUse,
}) async {
  final now = (clock ?? DateTime.now)();
  var removed = 0;
  for (final root in {staging.path, ?legacyTemporary?.path}) {
    try {
      await for (final entity in Directory(root).list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path);
        if (!_isStagingName(name)) continue;
        if (name == 'raft-previews' || name == 'raft-share') {
          // A shared parent: each lease folder ages on its own.
          await for (final child in entity.list(followLinks: false)) {
            if (child is Directory &&
                !(inUse?.call(child.path) ?? false) &&
                await _removeIfOld(child, now, maxAge)) {
              removed++;
            }
          }
        } else if (!(inUse?.call(entity.path) ?? false) &&
            await _removeIfOld(entity, now, maxAge)) {
          removed++;
        }
      }
    } on FileSystemException {
      // No such directory or unreadable: nothing to sweep.
    }
  }
  return removed;
}

Future<bool> _removeIfOld(
  Directory folder,
  DateTime now,
  Duration maxAge,
) async {
  try {
    var newest = (await folder.stat()).modified;
    await for (final entity in folder.list(followLinks: false)) {
      final modified = (await entity.stat()).modified;
      if (modified.isAfter(newest)) newest = modified;
    }
    if (now.difference(newest) < maxAge) return false;
    await folder.delete(recursive: true);
    return true;
  } on FileSystemException {
    return false;
  }
}

/// "Clear cache": the staging sweep with the short [grace] instead of an hour,
/// leaving every folder a live lease holds ([isStagingHeld]). [staging] and
/// [legacyTemporary] are where [cacheStagingDirectory] and the system
/// temporary directory are.
Future<int> clearStaging({
  required Directory staging,
  Directory? legacyTemporary,
  Duration grace = stagingFreshWindow,
  DateTime Function()? clock,
}) => sweepStaging(
  staging: staging,
  legacyTemporary: legacyTemporary,
  maxAge: grace,
  clock: clock,
  inUse: isStagingHeld,
);
