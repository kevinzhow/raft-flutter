import 'dart:io';
import 'dart:typed_data';

/// Which face of the Noto CJK collection stands in for each family the theme's
/// fallback chains name (raft_ui `RaftTokens.fontFallback`).
///
/// flutter_test has no system fonts, and resolves a family it does not know to
/// its own box-drawing test font rather than skipping it. A chain entry that
/// only exists on a device — `PingFang SC` on Apple, `Microsoft YaHei` on
/// Windows — therefore swallows the glyph before the chain reaches a real CJK
/// face, and the render shows tofu boxes a user never sees. Every name in a
/// chain needs a file here.
const cjkStandInFaces = <String, String>{
  'Noto Sans CJK JP': 'Noto Sans CJK JP',
  'Noto Sans CJK KR': 'Noto Sans CJK KR',
  'Noto Sans CJK SC': 'Noto Sans CJK SC',
  'Noto Sans CJK TC': 'Noto Sans CJK TC',
  'PingFang SC': 'Noto Sans CJK SC',
  'Hiragino Sans GB': 'Noto Sans CJK SC',
  'Microsoft YaHei': 'Noto Sans CJK SC',
  'Noto Sans SC': 'Noto Sans CJK SC',
};

/// The generic family keywords a recipe declaration can end in, and the faces
/// a capture host resolves them to through fontconfig.
///
/// These need files for the same reason [cjkStandInFaces] does: an
/// unregistered name is answered by flutter_test's own box font instead of
/// being skipped, so it swallows the glyph before the chain reaches a face
/// that has it. The mono pair is the one that bites in practice — the channel
/// date divider is `font-mono`, so a Japanese date resolved `ui-monospace`
/// first and drew boxes.
///
/// None of these faces carries CJK, which is deliberate: Latin and digits keep
/// the right shape, and a CJK character falls past them to the Noto CJK
/// families the chain appends.
const genericStandInFonts = <String, List<String>>{
  'system-ui': [
    'truetype/noto/NotoSans-Regular.ttf',
    'truetype/noto/NotoSans-Bold.ttf',
  ],
  'ui-sans-serif': [
    'truetype/noto/NotoSans-Regular.ttf',
    'truetype/noto/NotoSans-Bold.ttf',
  ],
  'ui-monospace': [
    'truetype/noto/NotoSansMono-Regular.ttf',
    'truetype/noto/NotoSansMono-Bold.ttf',
  ],
  'monospace': [
    'truetype/noto/NotoSansMono-Regular.ttf',
    'truetype/noto/NotoSansMono-Bold.ttf',
  ],
};

ByteData cjkTestFontData(File file, String family) {
  final data = ByteData.sublistView(file.readAsBytesSync());
  final index = const [
    'Noto Sans CJK JP',
    'Noto Sans CJK KR',
    'Noto Sans CJK SC',
    'Noto Sans CJK TC',
  ].indexOf(family);
  if (index < 0 ||
      data.getUint32(0) != 0x74746366 ||
      data.getUint32(8) <= index) {
    throw ArgumentError('Expected a Noto Sans CJK collection for $family');
  }
  // FontLoader selects face zero. Noto's TTC orders JP, KR, SC, TC, HK.
  final offset = data.getUint32(12);
  data.setUint32(12, data.getUint32(12 + index * 4));
  data.setUint32(12 + index * 4, offset);
  return data;
}

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
