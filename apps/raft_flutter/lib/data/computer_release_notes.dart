// Release notes for the latest published Raft Computer version (Web
// packages/shared computerReleaseNotes.ts). The server caches them next to
// `latestComputerVersion` and sends them as `latestComputerReleaseNotes` on the
// machines read; display only.

/// Per-locale cap: anything far larger is not a changelog.
const computerReleaseNotesMaxChars = 16000;
const _maxVersionChars = 64;

class ComputerReleaseNotes {
  const ComputerReleaseNotes({required this.version, this.en, this.zhCn});

  /// The Computer version these notes describe.
  final String version;
  final String? en, zhCn;

  /// The notes for a UI language: the matching one first, else whichever
  /// exists (Web pickComputerReleaseNotesText).
  String? text({required bool chinese}) => chinese ? zhCn ?? en : en ?? zhCn;

  Map<String, dynamic> toJson() => {
    'version': version,
    if (en != null) 'en': en,
    if (zhCn != null) 'zh-CN': zhCn,
  };

  @override
  bool operator ==(Object other) =>
      other is ComputerReleaseNotes &&
      other.version == version &&
      other.en == en &&
      other.zhCn == zhCn;

  @override
  int get hashCode => Object.hash(version, en, zhCn);
}

/// normalizeComputerReleaseNotes: only non-empty strings of the known locales
/// within the cap survive; null when no locale does or the shape is wrong.
ComputerReleaseNotes? normalizeComputerReleaseNotes(
  Object? version,
  Object? notes,
) {
  if (version is! String || notes is! Map) return null;
  final trimmedVersion = version.trim();
  if (trimmedVersion.isEmpty || trimmedVersion.length > _maxVersionChars) {
    return null;
  }
  String? locale(String key) {
    final value = notes[key];
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty || text.length > computerReleaseNotesMaxChars
        ? null
        : text;
  }

  final en = locale('en'), zhCn = locale('zh-CN');
  return en == null && zhCn == null
      ? null
      : ComputerReleaseNotes(version: trimmedVersion, en: en, zhCn: zhCn);
}

/// The notes in the machines envelope (`{machines, latestComputerReleaseNotes}`);
/// a bare list has none.
ComputerReleaseNotes? computerReleaseNotesOf(Object? envelope) {
  final notes = envelope is Map ? envelope['latestComputerReleaseNotes'] : null;
  return notes is Map
      ? normalizeComputerReleaseNotes(notes['version'], notes)
      : null;
}
