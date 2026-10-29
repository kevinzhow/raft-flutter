import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

/// A pack that extends the built-in one, with the values a theme is expected to
/// reach: one colour, one radius, one shadow.
String childPack() {
  final base = jsonDecode(raftThemePackJson) as Map<String, dynamic>;
  final light = (base['modes'] as Map)['light'] as Map<String, dynamic>;
  final dark = (base['modes'] as Map)['dark'] as Map<String, dynamic>;
  final child = <String, dynamic>{
    'format': raftThemePackFormat,
    'id': 'user:test',
    'name': {'en': 'Test'},
    'version': '1.0.0',
    'extends': 'raft',
    'modes': {
      'light': {
        'colors': {
          'foreground': '#123456',
          'layer-canvas': '{palette.cream.100}',
        },
        'palette': {'palette-cream-100': '#fdf7e3'},
        'geometry': {'radius.control': 0, 'stroke.container': 2},
        'shadows': {'shadow.float': 'none'},
      },
      'dark': {
        'colors': {'foreground': '#abcdef'},
      },
    },
  };
  // Touch the parsed modes so a malformed base pack fails here, not later.
  expect(light, isNotEmpty);
  expect(dark, isNotEmpty);
  return jsonEncode(child);
}

void main() {
  testWidgets('a pack reaches RaftTokens: colours, radii and shadows', (
    tester,
  ) async {
    final pack = RaftThemePack.parse(childPack(), origin: 'test');
    final theme = raftTheme(pack: pack);

    late RaftTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            tokens = RaftTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(tokens.ink, const Color(0xFF123456));
    expect(tokens.canvas, const Color(0xFFFDF7E3), reason: 'palette reference');
    expect(tokens.radius, 0);
    expect(tokens.border, 2);
    expect(tokens.shadows, isEmpty, reason: 'shadow.float is none');
    // A value the pack does not set still comes from the theme it extends.
    expect(tokens.card, const Color(0xFFFFFFFF));
  });

  testWidgets('the ported components follow the pack through RaftTokens.ui', (
    tester,
  ) async {
    final pack = RaftThemePack.parse(childPack(), origin: 'test');
    late RaftTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: pack),
        home: Builder(
          builder: (context) {
            tokens = RaftTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    // RaftUiColors is what the 11 ported core components read; it must come
    // from the active tokens, not from the generated RaftLight/RaftDark maps.
    expect(tokens.ui.foreground, const Color(0xFF123456));
    expect(tokens.ui.layerCanvas, const Color(0xFFFDF7E3));
    expect(tokens.ui.stickerInk, tokens.colors['sticker-ink']);
  });

  testWidgets('RaftTokens.ui is stable and compares by mode and colour map', (
    tester,
  ) async {
    late RaftTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Builder(
          builder: (context) {
            tokens = RaftTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    // Read in build, so repeated reads must not hand out new objects: a widget
    // comparing old and new colours would otherwise repaint every frame.
    expect(identical(tokens.ui, tokens.ui), isTrue);
    expect(tokens.ui, tokens.ui);
    expect(tokens.ui.hashCode, tokens.ui.hashCode);
    // Different mode over the same map is a different set of colours.
    expect(
      RaftUiColors.fromMap(true, tokens.colors),
      isNot(RaftUiColors.fromMap(false, tokens.colors)),
    );
  });

  testWidgets('dark mode resolves its own values', (tester) async {
    final pack = RaftThemePack.parse(childPack(), origin: 'test');
    late RaftTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: pack, dark: true),
        home: Builder(
          builder: (context) {
            tokens = RaftTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tokens.ink, const Color(0xFFABCDEF));
    expect(tokens.dark, isTrue);
  });

  test('the built-in pack parses in a few milliseconds', () {
    final watch = Stopwatch()..start();
    RaftThemePack.parse(raftThemePackJson, origin: 'raft');
    watch.stop();
    // A loose bound on purpose: this is a smoke test that the pack is not a
    // startup cost, not a benchmark (the startup paths are timed elsewhere).
    expect(
      watch.elapsedMilliseconds,
      lessThan(200),
      reason:
          'parsing ${raftThemePackJson.length} bytes took '
          '${watch.elapsedMilliseconds} ms',
    );
  });
}
