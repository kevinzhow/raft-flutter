import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.24 / raft-ui 0.95.3 `styles.css`: from 768px with a mouse or
/// trackpad (`@media (width >= 48rem) and (pointer: fine)`) body is 14/22,
/// headline 16/24, footnote 12/18; a phone and a touch screen at any width
/// keep 16/24, 17/22 and 13/18. The public `typeSlot` and `scale` read that
/// from the context, so no call site passes the window or the input.
Future<RaftTokens> _tokensAt(
  WidgetTester t, {
  required Size size,
  required TargetPlatform platform,
  RaftThemePack? pack,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  late RaftTokens tokens;
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(pack: pack).copyWith(platform: platform),
      home: Builder(
        builder: (context) {
          tokens = RaftTokens.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return tokens;
}

void main() {
  const wide = Size(1000, 800);
  const narrow = Size(600, 800);

  testWidgets('a wide window with a mouse takes the desktop scale', (t) async {
    final tokens = await _tokensAt(
      t,
      size: wide,
      platform: TargetPlatform.linux,
    );
    expect(tokens.desktop, isTrue);
    expect(tokens.typeSlot('body').fontSize, 14);
    expect(tokens.typeSlot('body').lineHeight, 22);
    expect(tokens.typeSlot('headline').fontSize, 16);
    expect(tokens.typeSlot('headline').lineHeight, 24);
    expect(tokens.typeSlot('footnote').fontSize, 12);
    expect(tokens.typeSlot('title').fontSize, 22, reason: 'title is unchanged');
    final style = tokens.scale(RaftTypeScale.body);
    expect(style.fontSize, 14);
    expect(style.height, closeTo(22 / 14, 1e-9));
    expect(tokens.scale(RaftTypeScale.label).fontSize, 11);
  });

  testWidgets('a touch screen keeps the base scale at any width', (t) async {
    final tokens = await _tokensAt(
      t,
      size: wide,
      platform: TargetPlatform.android,
    );
    expect(tokens.desktop, isFalse);
    expect(tokens.typeSlot('body').fontSize, 16);
    expect(tokens.scale(RaftTypeScale.body).fontSize, 16);
  });

  testWidgets('a narrow window with a mouse keeps the base scale', (t) async {
    final tokens = await _tokensAt(
      t,
      size: narrow,
      platform: TargetPlatform.linux,
    );
    expect(tokens.desktop, isFalse);
    expect(tokens.typeSlot('body').fontSize, 16);
    expect(tokens.scale(RaftTypeScale.headline).fontSize, 17);
  });

  testWidgets('the desktop variant is one stable instance', (t) async {
    final a = await _tokensAt(t, size: wide, platform: TargetPlatform.linux);
    final b = await _tokensAt(t, size: wide, platform: TargetPlatform.linux);
    expect(identical(a, b), isTrue);
  });

  testWidgets('Elegant keeps its frozen scale on desktop', (t) async {
    final tokens = await _tokensAt(
      t,
      size: wide,
      platform: TargetPlatform.linux,
      pack: packForThemeId(elegantThemePackId),
    );
    expect(tokens.desktop, isFalse);
    expect(tokens.typeSlot('body').fontSize, 16);
  });

  testWidgets('a user pack\'s own slot wins over the desktop scale', (t) async {
    final pack = RaftThemePack.parse(
      jsonEncode({
        'format': 'raft-theme/1',
        'id': 'user:desktop-type',
        'name': 'Desktop type',
        'version': '1.0.0',
        'extends': 'raft',
        'modes': {
          'light': {
            'type': {
              'body': [19, 26, 400, 0],
            },
          },
          'dark': <String, Object?>{},
        },
      }),
    );
    final tokens = await _tokensAt(
      t,
      size: wide,
      platform: TargetPlatform.linux,
      pack: pack,
    );
    expect(tokens.typeSlot('body').fontSize, 19);
    expect(tokens.typeSlot('callout').fontSize, 14);
    expect(tokens.typeSlot('footnote').fontSize, 12);
  });
}
