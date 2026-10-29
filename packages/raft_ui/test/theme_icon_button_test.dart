import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/tap_slop.dart';
import 'package:raft_ui/test_themes.dart';

import 'control_paint.dart';

const _button = Key('small-icon');

Widget _host({
  String id = raftThemePackId,
  bool dark = false,
  RaftDensity density = RaftDensity.touch,
  double? minimum,
  double visualSize = RaftMetrics.buttonXs,
  VoidCallback? onPressed,
  bool busy = false,
  String? tooltip = 'Add',
  RaftThemePack? pack,
}) => MaterialApp(
  themeAnimationDuration: Duration.zero,
  theme: raftTheme(
    pack: pack ?? packForThemeId(id),
    dark: dark,
    platform: TargetPlatform.android,
  ),
  home: Scaffold(
    body: RaftTapSlopHost(
      child: Center(
        child: RaftDensityScope(
          density: density,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                container: true,
                child: RaftIconButton(
                  key: _button,
                  glyph: RaftGlyph.plus,
                  visualSize: visualSize,
                  minimumTargetSize: minimum,
                  tooltip: tooltip,
                  onPressed: onPressed,
                  busy: busy,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets(
        '$id dark=$dark small icon layout follows source touch policy',
        (t) async {
          final semantics = t.ensureSemantics();
          try {
            for (final density in RaftDensity.values) {
              await t.pumpWidget(
                _host(id: id, dark: dark, density: density, onPressed: () {}),
              );
              await t.pumpAndSettle();
              final visual = id == raftThemePackId ? 32.0 : 24.0;
              final expected =
                  density == RaftDensity.touch && id != raftThemePackId
                  ? 48.0
                  : visual;
              expect(t.getSize(find.byKey(_button)), Size.square(expected));
              final paint = controlFace(find.byKey(_button));
              expect(t.getSize(paint), Size.square(visual));
              final buttons = <SemanticsNode>[];
              void collect(SemanticsNode node) {
                if (node.flagsCollection.isButton) buttons.add(node);
                node.visitChildren((child) {
                  collect(child);
                  return true;
                });
              }

              collect(t.getSemantics(find.byKey(_button)));
              expect(buttons, hasLength(1));
              expect(
                buttons.single.rect.size,
                Size.square(density == RaftDensity.touch ? 48 : visual),
              );
            }
          } finally {
            await t.pumpWidget(const SizedBox.shrink());
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets(
    'user pack controls the minimum without a built-in id; no tooltip',
    (t) async {
      final pack = RaftThemePack.parse(
        jsonEncode({
          'format': raftThemePackFormat,
          'id': 'user:small-icons',
          'name': {'en': 'Small icons'},
          'version': '1',
          'extends': 'raft',
          'modes': {
            'light': {
              'geometry': {'size.touchLayoutMin': 37},
            },
            'dark': {},
          },
        }),
      );
      var calls = 0;
      await t.pumpWidget(
        _host(pack: pack, tooltip: null, onPressed: () => calls++),
      );
      expect(t.getSize(find.byKey(_button)), const Size.square(37));
      final center = t.getCenter(find.byKey(_button));
      await t.tapAt(center + const Offset(0, -22));
      await t.pump();
      expect(calls, 1);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'explicit minimum wins; larger icons retain their existing layout',
    (t) async {
      for (final id in raftThemeMatrix([
        raftThemePackId,
        elegantThemePackId,
        brutalThemePackId,
      ], look: raftLookOf)) {
        for (final minimum in [0.0, 36.0, 60.0]) {
          await t.pumpWidget(_host(id: id, minimum: minimum, onPressed: () {}));
          expect(
            t.getSize(find.byKey(_button)),
            Size.square(
              minimum < (id == raftThemePackId ? 32 : 24)
                  ? (id == raftThemePackId ? 32 : 24)
                  : minimum,
            ),
          );
        }
        for (final visual in [28.0, 32.0]) {
          await t.pumpWidget(
            _host(id: id, visualSize: visual, onPressed: () {}),
          );
          expect(t.getSize(find.byKey(_button)), const Size.square(48));
        }
      }
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'touch outside the visual row activates once; keyboard and inert states',
    (t) async {
      for (final id in raftThemeMatrix([
        raftThemePackId,
        elegantThemePackId,
        brutalThemePackId,
      ], look: raftLookOf)) {
        var calls = 0;
        await t.pumpWidget(_host(id: id, onPressed: () => calls++));
        await t.pumpAndSettle();
        final center = t.getCenter(find.byKey(_button));
        final touch = await t.startGesture(center + const Offset(0, -20));
        await touch.up();
        await t.pumpAndSettle();
        expect(calls, 1, reason: '$id touch hit slop');
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(calls, 3, reason: '$id keyboard');
        await t.pumpWidget(_host(id: id));
        await t.tapAt(center + const Offset(0, -20));
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(calls, 3, reason: '$id disabled');
        await t.pumpWidget(_host(id: id, onPressed: () => calls++, busy: true));
        await t.tapAt(center + const Offset(0, -20));
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump(const Duration(milliseconds: 200));
        expect(calls, 3, reason: '$id busy');
        await t.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
