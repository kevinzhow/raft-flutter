import 'dart:io';

/// The repository root, found by walking up from the working directory, so a
/// test reads the same files whether it runs from the repository root or from
/// apps/raft_flutter, on any platform (a path suffix check missed Windows
/// back slashes and quietly scanned the wrong directory).
Directory repoRoot() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !Directory('${dir.path}/packages/raft_ui').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('repository root not found');
    dir = parent;
  }
  return dir;
}
