import 'dart:io';

import 'package:path/path.dart' as p;

/// Lists cache entries even when a Windows descendant exceeds MAX_PATH.
/// Returned paths retain the caller's root, so index keys and paths handed to
/// native viewers do not acquire a Windows device-path prefix.
Stream<FileSystemEntity> listCacheDirectory(
  Directory directory, {
  bool recursive = false,
  bool followLinks = true,
}) {
  final listing = _listingDirectory(directory);
  return listing
      .list(recursive: recursive, followLinks: followLinks)
      .map((entry) => _restoreRoot(entry, directory, listing));
}

/// Synchronous counterpart for the cache's background-isolate startup scan.
Iterable<FileSystemEntity> listCacheDirectorySync(
  Directory directory, {
  bool recursive = false,
  bool followLinks = true,
}) {
  final listing = _listingDirectory(directory);
  return listing
      .listSync(recursive: recursive, followLinks: followLinks)
      .map((entry) => _restoreRoot(entry, directory, listing));
}

Directory _listingDirectory(Directory directory) {
  if (!Platform.isWindows) return directory;
  final path = p.windows.normalize(directory.absolute.path);
  if (path.startsWith(r'\\?\')) return Directory(path);
  if (path.startsWith(r'\\')) {
    return Directory(r'\\?\UNC\' + path.substring(2));
  }
  return Directory(r'\\?\' + path);
}

FileSystemEntity _restoreRoot(
  FileSystemEntity entry,
  Directory original,
  Directory listing,
) {
  if (identical(original, listing)) return entry;
  var relative = entry.path.substring(listing.path.length);
  if (relative.startsWith(p.separator)) relative = relative.substring(1);
  final path = p.join(original.path, relative);
  return switch (entry) {
    File() => File(path),
    Directory() => Directory(path),
    Link() => Link(path),
    _ => entry,
  };
}
