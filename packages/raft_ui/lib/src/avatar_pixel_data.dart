// Source: Web 26f77ef assets/avatars/pixelAvatars.json and PixelAvatar.tsx.
// Artwork palette is avatar-specific source data, independent of theme tokens.
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

@immutable
class RaftPixelAvatarData {
  const RaftPixelAvatarData(this.background, this.rows);
  final String background;
  final List<String> rows;
}

const raftDefaultPixelAvatarKey = 'robot';
const raftPixelAvatarPalette = <String, String>{
  '_': 'transparent',
  'K': '#141111',
  'W': '#FFFFFF',
  'P': '#FE7DA8',
  'O': '#F8A16F',
  'Y': '#FFD440',
  'L': '#A9D877',
  'C': '#27CCF3',
  'V': '#BBAFE6',
  'B': '#576574',
  'R': '#F97264',
  'G': '#9DCAAA',
  'D': '#B07A4E',
};
const raftPixelAvatarPresets = <String, RaftPixelAvatarData>{
  'robot': RaftPixelAvatarData('#27CCF3', [
    '_KKKKKK_',
    'KCKWWKCK',
    'KWKWWKWK',
    'KKKKKKKK',
    '_KWKKWK_',
    '_KKKKKK_',
    '_KK__KK_',
    '_KK__KK_',
  ]),
  'cat': RaftPixelAvatarData('#FFD440', [
    'K______K',
    'KK____KK',
    'KYKYYKYK',
    'KYYYYYYK',
    'KYKYYKYK',
    '_KYYYYK_',
    '__KYYK__',
    '___KK___',
  ]),
  'ghost': RaftPixelAvatarData('#BBAFE6', [
    '__KKKK__',
    '_KWWWWK_',
    'KWKWWKWK',
    'KWWWWWWK',
    'KWWWWWWK',
    'KWWKKWWK',
    'KWKWWKWK',
    'K_K__K_K',
  ]),
  'skull': RaftPixelAvatarData('#F8A16F', [
    '_KKKKKK_',
    'KWWWWWWK',
    'KWKWWKWK',
    'KWWWWWWK',
    '_KWWWWK_',
    '_KWKWKK_',
    '__KKKK__',
    '___KK___',
  ]),
  'alien': RaftPixelAvatarData('#A9D877', [
    '_KKKKKK_',
    'KGGGGGGK',
    'KGKKKKGK',
    'KGGGGGGK',
    '_KGGGGK_',
    '__KGGK__',
    '__KGGK__',
    '_KK__KK_',
  ]),
  'heart': RaftPixelAvatarData('#FE7DA8', [
    '________',
    '_KK__KK_',
    'KRRKKRRK',
    'KRRRRRRK',
    'KRRRRRRK',
    '_KRRRRK_',
    '__KRRK__',
    '___KK___',
  ]),
  'star': RaftPixelAvatarData('#FFD440', [
    '___KK___',
    '___KK___',
    'KKKKKKKK',
    '_KYYYYK_',
    '__KYYK__',
    '_KYKKYK_',
    'KYK__KYK',
    'KK____KK',
  ]),
  'flame': RaftPixelAvatarData('#F8A16F', [
    '___K____',
    '__KRK___',
    '__KRKK__',
    '_KORRRK_',
    '_KOORRK_',
    'KYOOORK_',
    'KYYOOK__',
    '_KKKK___',
  ]),
  'diamond': RaftPixelAvatarData('#27CCF3', [
    '___KK___',
    '__KCCK__',
    '_KCWCCK_',
    'KCWCCCCK',
    'KCCCCCCK',
    '_KCCCCK_',
    '__KCCK__',
    '___KK___',
  ]),
  'mushroom': RaftPixelAvatarData('#FE7DA8', [
    '__KKKK__',
    '_KRWWRK_',
    'KRRWWRRK',
    'KRRRRRRK',
    '_KKKKKK_',
    '__KWWK__',
    '__KWWK__',
    '_KKKKKK_',
  ]),
  'eye': RaftPixelAvatarData('#BBAFE6', [
    '________',
    '__KKKK__',
    '_KWWWWK_',
    'KWWKKWWK',
    'KWWKKWWK',
    '_KWWWWK_',
    '__KKKK__',
    '________',
  ]),
  'crown': RaftPixelAvatarData('#FFD440', [
    '________',
    '_K_KK_K_',
    '_KKKKKK_',
    '_KYYYYK_',
    '_KYYYYK_',
    'KKKKKKKK',
    'KYYYYYYK',
    'KKKKKKKK',
  ]),
  'cloud': RaftPixelAvatarData('#27CCF3', [
    '________',
    '__KK____',
    '_KWWKK__',
    'KWWWWWK_',
    'KWWWWWWK',
    'KWWWWWWK',
    '_KKKKKK_',
    '________',
  ]),
  'sun': RaftPixelAvatarData('#F97264', [
    '_K_KK_K_',
    'K_KYYK_K',
    '_KYYYYK_',
    'KYYYYYYK',
    'KYYYYYYK',
    '_KYYYYK_',
    'K_KYYK_K',
    '_K_KK_K_',
  ]),
  'bell': RaftPixelAvatarData('#576574', [
    '___KK___',
    '__KYYK__',
    '_KYYYYK_',
    '_KYYYYK_',
    '_KYYYYK_',
    'KYYYYYYK',
    'KKKKKKKK',
    '___KK___',
  ]),
  'tree': RaftPixelAvatarData('#A9D877', [
    '___KK___',
    '__KGGK__',
    '_KGGGGK_',
    'KGGGGGGK',
    'KGGGGGGK',
    '_KKGGKK_',
    '__KOOK__',
    '___KK___',
  ]),
  'finch': RaftPixelAvatarData('#D7F3FB', [
    '__KKKK__',
    '_KCCCCK_',
    'KCWCCWCK',
    'KCKCCKCK',
    'KCCOOCCK',
    '_KCCCCK_',
    '_KCKKCK_',
    '__K__K__',
  ]),
  'mug': RaftPixelAvatarData('#F8EEDF', [
    '___KK___',
    '__K__K__',
    'KKKKKK__',
    'KDDDDKKK',
    'KWDDKK_K',
    'KDDDDKKK',
    'KDKKDK__',
    '_KKKKK__',
  ]),
};

/// Matches JavaScript UTF-16 hashString + mulberry32, including overflow.
RaftPixelAvatarData? raftPixelAvatarData(String key) {
  if (!key.startsWith('random:')) return raftPixelAvatarPresets[key];
  const mask = 0xffffffff;
  var hash = 0;
  for (final unit in key.substring(7).codeUnits) {
    hash = (hash * 31 + unit) & mask;
  }
  double random() {
    hash = (hash + 0x6d2b79f5) & mask;
    var value = ((hash ^ (hash >>> 15)) * (1 | hash)) & mask;
    value =
        ((value + (((value ^ (value >>> 7)) * (61 | value)) & mask)) ^ value) &
        mask;
    return ((value ^ (value >>> 14)) & mask) / 4294967296;
  }

  final c = raftPixelAvatarPalette;
  final schemes = <(String, String)>[
    (c['C']!, 'K'),
    (c['Y']!, 'K'),
    (c['L']!, 'K'),
    (c['P']!, 'W'),
    (c['V']!, 'K'),
    ('#1E1E1C', 'C'),
    ('#1E1E1C', 'G'),
    ('#1E1E1C', 'P'),
    ('#1E1E1C', 'Y'),
    ('#1E1E1C', 'V'),
    (c['O']!, 'K'),
    (c['C']!, 'W'),
  ];
  final scheme = schemes[(random() * schemes.length).floor()];
  final rows = <String>[];
  for (var y = 0; y < 8; y++) {
    final left = List.generate(4, (_) => random() < .45 ? scheme.$2 : '_');
    rows.add([...left, ...left.reversed].join());
  }
  return RaftPixelAvatarData(scheme.$1, List.unmodifiable(rows));
}

Color raftPixelAvatarColor(String value) =>
    Color(0xff000000 | int.parse(value.substring(1), radix: 16));
