import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('explicit dialog geometry survives source recipes dark=$dark', (
      t,
    ) async {
      final values = {
        'geometry': {
          'space.dialogHeaderInline': 28,
          'space.dialogBodyTop': 11,
          'space.dialogFooterGap': 14,
          'type.dialogTitle.size': 19,
          'type.dialogTitle.line': 26,
          'radius.dialog': 23,
          'stroke.dialogRing': 3,
          'size.dialogClose': 37,
          'size.dialogCloseGlyph': 21,
        },
        'options': {'dialog.close': 'outline'},
      };
      final pack = RaftThemePack.parse(
        jsonEncode({
          'format': raftThemePackFormat,
          'id': 'user:dialog',
          'name': {'en': 'Custom dialog'},
          'version': '1',
          'extends': 'raft',
          'modes': {'light': values, 'dark': values},
        }),
      );
      addTearDown(() => t.pumpWidget(const SizedBox()));
      late RaftDialogSlots slots;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: pack, dark: dark),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                slots = RaftDialogSlots.of(context);
                return const RaftDialog(title: 'Custom', content: Text('Body'));
              },
            ),
          ),
        ),
      );
      expect(slots.header.padding.left, 28);
      expect(slots.body.padding.top, 11);
      expect(slots.footer.columnGap, 14);
      expect(
        slots.title
            .textStyle(RaftTokens.theme(pack: pack, dark: dark).recipeTokens)
            .fontSize,
        19,
      );
      expect(slots.content.borderRadius, BorderRadius.circular(23));
      final rings = slots.content.boxShadow
          .whereType<RaftLiteralShadow>()
          .where((s) => s.offset == Offset.zero && s.blur == 0 && s.spread > 0);
      expect(rings.map((s) => s.spread), [3]);
      final close = find.descendant(
        of: find.byType(RaftDialogClose),
        matching: find.byType(RaftButton),
      );
      expect(t.getSize(close), const Size.square(37));
      expect(t.widget<RaftButton>(close).uiVariant, RaftButtonVariant.outline);
      expect(t.widget<RaftButton>(close).glyphSize, 21);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    'an explicit default-valued override wins over first-child seam',
    (t) async {
      final pack = RaftThemePack.parse(
        jsonEncode({
          'format': raftThemePackFormat,
          'id': 'user:seam',
          'name': {'en': 'Explicit seam'},
          'version': '1',
          'extends': 'raft',
          'modes': {
            'light': {
              'geometry': {'space.dialogBodyTop': 6},
            },
            'dark': {},
          },
        }),
      );
      addTearDown(() => t.pumpWidget(const SizedBox()));
      late RaftDialogSlots slots;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: pack),
          home: Builder(
            builder: (context) {
              slots = RaftDialogSlots.of(context, first: true);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(slots.body.padding.top, 6);
    },
  );
}
