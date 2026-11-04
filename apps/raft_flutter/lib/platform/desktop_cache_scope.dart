import 'dart:io';

import 'package:path/path.dart' as p;

/// Set only by child-engine bootstrap before any app/cache code runs.
/// Each engine owns its files, so retiring it cannot tear down another
/// window's SQLite, staging, media or attachment cache.
class DesktopCacheScope {
  DesktopCacheScope._();
  static Directory? _root;
  static bool get isChild => _root != null;
  static Future<void> initializeChild() async {
    _root ??= await Directory.systemTemp.createTemp('raft-window-');
  }

  static Future<Directory>? directory(String name) => _root == null
      ? null
      : Directory(p.join(_root!.path, name)).create(recursive: true);
}
