import 'dart:io';

import 'package:flutter/foundation.dart';

/// The AppImage update-information string embedded in the runtime's
/// `.upd_info` ELF section (AppImageSpec, "update information").
///
/// `tool/appimage.py` embeds [official] with `appimagetool --updateinformation`
/// and `tool/tests/test_appimage.py` fails if the two differ. Isolated test
/// builds embed nothing, so [AppImageUpdateInformation.read] finds no
/// information and they never update into the official build.
@immutable
sealed class AppImageUpdateInformation {
  const AppImageUpdateInformation();

  static const String official =
      'gh-releases-zsync|kevinzhow|raft-flutter|latest|raft-flutter-*-appimage-x64.AppImage.zsync';

  /// Null when [text] is not a supported `zsync|URL` or
  /// `gh-releases-zsync|owner|repo|latest|pattern` string.
  static AppImageUpdateInformation? parse(String text) {
    final parts = text.trim().split('|');
    switch (parts.first) {
      case 'zsync':
        if (parts.length != 2) return null;
        final url = Uri.tryParse(parts[1]);
        if (url == null ||
            !(url.isScheme('https') || url.isScheme('http')) ||
            url.host.isEmpty) {
          return null;
        }
        return DirectZsyncInformation(url);
      case 'gh-releases-zsync':
        if (parts.length != 5) return null;
        final safe = RegExp(r'^[A-Za-z0-9._-]+$');
        // Only the newest stable release is followed: the app learns its tag
        // from the same `releases/latest` manifest that drives the red dot.
        if (!safe.hasMatch(parts[1]) ||
            !safe.hasMatch(parts[2]) ||
            parts[3] != 'latest' ||
            parts[4].isEmpty ||
            parts[4].contains('/')) {
          return null;
        }
        return GithubReleasesInformation(
          owner: parts[1],
          repository: parts[2],
          pattern: parts[4],
        );
    }
    return null;
  }

  /// The string stored in the AppImage at [path], or null when the file is not
  /// an ELF AppImage or has an empty `.upd_info` section.
  static AppImageUpdateInformation? read(String path) {
    final text = readUpdateInformationText(path);
    return text == null ? null : parse(text);
  }
}

/// `zsync|URL`: a fixed `.zsync` URL (the AppImage it describes is the one the
/// control file's `URL:` header names).
@immutable
class DirectZsyncInformation extends AppImageUpdateInformation {
  const DirectZsyncInformation(this.url);
  final Uri url;
}

/// `gh-releases-zsync|owner|repo|latest|pattern`.
@immutable
class GithubReleasesInformation extends AppImageUpdateInformation {
  const GithubReleasesInformation({
    required this.owner,
    required this.repository,
    required this.pattern,
  });
  final String owner, repository, pattern;

  /// Whether the release asset [name] is the `.zsync` this string selects
  /// (`*` matches any run of characters, as in AppImageUpdate).
  bool matches(String name) {
    final expression = RegExp(
      '^${pattern.split('*').map(RegExp.escape).join('.*')}\$',
    );
    return expression.hasMatch(name);
  }

  /// `https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>`.
  Uri assetUrl(String tag, String asset, {Uri? origin}) {
    final base = origin ?? Uri.parse('https://github.com');
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        owner,
        repository,
        'releases',
        'download',
        tag,
        asset,
      ],
    );
  }
}

/// Reads `.upd_info` from the ELF file at [path]; null when absent or empty.
///
/// The type-2 runtime is a 64-bit little-endian ELF followed by the squashfs
/// image, so only the section header table at the end of the runtime is read.
String? readUpdateInformationText(String path) {
  final RandomAccessFile file;
  try {
    file = File(path).openSync();
  } on FileSystemException {
    return null;
  }
  try {
    final header = _readExactly(file, 0, 64);
    if (header == null ||
        header[0] != 0x7f ||
        header[1] != 0x45 ||
        header[2] != 0x4c ||
        header[3] != 0x46 ||
        header[4] != 2 || // ELFCLASS64
        header[5] != 1) {
      // ELFDATA2LSB
      return null;
    }
    final view = ByteData.sublistView(header);
    final sectionTable = view.getUint64(0x28, Endian.little);
    final entrySize = view.getUint16(0x3a, Endian.little);
    final entries = view.getUint16(0x3c, Endian.little);
    final namesIndex = view.getUint16(0x3e, Endian.little);
    if (sectionTable == 0 ||
        entrySize < 64 ||
        entries == 0 ||
        namesIndex >= entries) {
      return null;
    }
    final table = _readExactly(file, sectionTable, entrySize * entries);
    if (table == null) return null;
    final sections = ByteData.sublistView(table);
    ({int name, int offset, int size}) section(int index) {
      final at = index * entrySize;
      return (
        name: sections.getUint32(at, Endian.little),
        offset: sections.getUint64(at + 0x18, Endian.little),
        size: sections.getUint64(at + 0x20, Endian.little),
      );
    }

    final names = section(namesIndex);
    if (names.size > 1 << 20) return null;
    final nameBytes = _readExactly(file, names.offset, names.size);
    if (nameBytes == null) return null;
    for (var index = 0; index < entries; index++) {
      final candidate = section(index);
      if (candidate.name >= nameBytes.length) continue;
      var end = candidate.name;
      while (end < nameBytes.length && nameBytes[end] != 0) {
        end++;
      }
      if (String.fromCharCodes(nameBytes.sublist(candidate.name, end)) !=
          '.upd_info') {
        continue;
      }
      if (candidate.size == 0 || candidate.size > 4096) return null;
      final data = _readExactly(file, candidate.offset, candidate.size);
      if (data == null) return null;
      final stop = data.indexOf(0);
      final text = String.fromCharCodes(stop < 0 ? data : data.sublist(0, stop))
          .trim();
      return text.isEmpty ? null : text;
    }
    return null;
  } on Object {
    return null;
  } finally {
    file.closeSync();
  }
}

Uint8List? _readExactly(RandomAccessFile file, int at, int length) {
  if (at < 0 || length < 0 || at + length > file.lengthSync()) return null;
  file.setPositionSync(at);
  final data = Uint8List(length);
  var read = 0;
  while (read < length) {
    final count = file.readIntoSync(data, read, length);
    if (count <= 0) return null;
    read += count;
  }
  return data;
}
