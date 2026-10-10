import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pasteboard/pasteboard.dart';

typedef ComposerFile = ({String name, Uint8List bytes});

/// Web `extractClipboardFiles` over the native clipboard (pasteboard plugin):
/// copied files first (desktop file managers), then a copied image. Text-only
/// clipboards yield nothing so the editor's own text paste runs.
class ClipboardAttachments {
  const ClipboardAttachments({this._files, this._image, this._desktop});
  final Future<List<String>> Function()? _files;
  final Future<Uint8List?> Function()? _image;
  final bool? _desktop;

  /// Browsers name a pasted bitmap `image.png`; keep the same attachment name.
  static const imageName = 'image.png';

  bool get desktop =>
      _desktop ?? (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

  Future<List<ComposerFile>> read() async {
    // Android clipboard file entries are content URIs that Dart cannot open;
    // the plugin's image read resolves image URIs through the resolver.
    if (desktop) {
      final paths = await _safe(_files ?? Pasteboard.files, const <String>[]);
      if (paths.isNotEmpty) return readLocalFiles(paths);
    }
    final image = await _safe(_image ?? () => Pasteboard.image, null);
    return image == null || image.isEmpty
        ? const []
        : [(name: imageName, bytes: image)];
  }

  static Future<T> _safe<T>(Future<T> Function() read, T fallback) async {
    try {
      return await read();
    } catch (error) {
      debugPrint('clipboard attachments unavailable: $error');
      return fallback;
    }
  }
}

/// Reads local regular files, skipping duplicates, directories and anything
/// unreadable. [folders] counts skipped directories (Web drop notice).
Future<({List<ComposerFile> files, int folders})> readLocalFileEntries(
  Iterable<String> paths,
) async {
  final seen = <String>{};
  final files = <ComposerFile>[];
  var folders = 0;
  for (final path in paths) {
    if (!p.isAbsolute(path) || !seen.add(p.normalize(path))) continue;
    try {
      switch (await FileSystemEntity.type(path)) {
        case FileSystemEntityType.directory:
          folders++;
        case FileSystemEntityType.file:
          files.add((
            name: p.basename(path),
            bytes: await File(path).readAsBytes(),
          ));
        default:
          break;
      }
    } on FileSystemException catch (error) {
      debugPrint('skipped unreadable file: ${error.message}');
    }
  }
  return (files: files, folders: folders);
}

Future<List<ComposerFile>> readLocalFiles(Iterable<String> paths) async =>
    (await readLocalFileEntries(paths)).files;
