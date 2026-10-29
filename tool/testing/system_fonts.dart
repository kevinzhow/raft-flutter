import 'dart:io';

// Preserve the capture host's tree and bytes without requiring system installs.
File systemTestFont(String relativePath, {Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final override = env['RAFT_TEST_FONT_DIR'];
  final directory = Directory(
    override == null || override.isEmpty ? '/usr/share/fonts' : override,
  );
  return File.fromUri(directory.uri.resolve(relativePath));
}

List<File> cjkTestFonts({Map<String, String>? environment}) => [
  for (final face in ['Regular', 'Bold'])
    systemTestFont(
      'opentype/noto/NotoSansCJK-$face.ttc',
      environment: environment,
    ),
];

String? missingTestFontReason(Iterable<File> files) {
  final missing = files.where((file) => !file.existsSync()).toList();
  if (missing.isEmpty) return null;
  return 'Screenshot skipped: required test fonts are missing: '
      '${missing.map((file) => file.path).join(', ')}. '
      'Set RAFT_TEST_FONT_DIR to a font tree containing opentype/noto and '
      'truetype/noto; no screenshot was captured.';
}
