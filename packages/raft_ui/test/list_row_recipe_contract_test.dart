import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child, {RaftThemePack? pack, bool dark = false}) =>
    MaterialApp(
      theme: raftTheme(pack: pack, dark: dark),
      home: Scaffold(body: SizedBox(width: 360, child: child)),
    );

void main() {
  testWidgets('list group consumes the active container radius', (
    tester,
  ) async {
    final pack = RaftThemePack.parse(
      jsonEncode({
        'format': 'raft-theme/1',
        'id': 'list-row-radius-contract',
        'name': {'en': 'List row radius contract'},
        'version': '1.0.0',
        'extends': 'raft',
        'modes': {
          for (final mode in ['light', 'dark'])
            mode: {
              'geometry': {'radius.container': 27},
            },
        },
      }),
    );
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        _host(
          const RaftListRowGroup(
            children: [
              RaftListRow(
                children: [
                  RaftListRowBody(children: [RaftListRowTitle('Row')]),
                ],
              ),
            ],
          ),
          pack: pack,
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(RaftListRowGroup),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>();
      expect(
        decorations.any((box) => box.borderRadius == BorderRadius.circular(27)),
        isTrue,
        reason: 'the published group uses rounded-container, including packs',
      );
    }
  });

  testWidgets('row inks follow tone and disabled changes in existing parts', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      for (final disabled in [false, true]) {
        for (final tone in RaftListRowTone.values) {
          await tester.pumpWidget(
            _host(
              RaftListRow(
                tone: tone,
                disabled: disabled,
                onPressed: () {},
                children: const [
                  RaftListRowIcon(RaftGlyph.search),
                  RaftListRowBody(
                    children: [
                      RaftListRowTitle('Title'),
                      RaftListRowDescription('Description'),
                    ],
                  ),
                  RaftListRowMeta('12:00'),
                ],
              ),
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          final ui = RaftUiColors.of(dark);
          Color ink(String text) =>
              tester.widget<Text>(find.text(text)).style!.color!;
          expect(
            ink('Title'),
            disabled
                ? ui.foregroundDisabled
                : switch (tone) {
                    RaftListRowTone.muted => ui.foregroundMuted,
                    RaftListRowTone.away => ui.foregroundHint,
                    _ => ui.foreground,
                  },
          );
          expect(
            ink('Description'),
            disabled
                ? ui.foregroundDisabled
                : switch (tone) {
                    RaftListRowTone.unread => ui.foreground,
                    RaftListRowTone.away => ui.foregroundHint,
                    _ => ui.foregroundMuted,
                  },
          );
          expect(
            ink('12:00'),
            disabled ? ui.foregroundDisabled : ui.foregroundHint,
          );
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets('row retains keyboard activation and rejects disabled actions', (
    tester,
  ) async {
    var activations = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    Widget row(bool disabled) => _host(
      RaftListRow(
        disabled: disabled,
        focusNode: focus,
        onPressed: () => activations++,
        children: const [
          RaftListRowBody(children: [RaftListRowTitle('Open')]),
        ],
      ),
    );
    await tester.pumpWidget(row(false));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activations, 1);
    await tester.pumpWidget(row(true));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.tap(find.text('Open'));
    expect(activations, 1);
  });
}
