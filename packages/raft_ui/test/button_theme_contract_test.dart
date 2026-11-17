import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([raftThemePackId])) {
    for (final dark in [false, true]) {
      testWidgets('actual button size and label from source $id/$dark', (
        t,
      ) async {
        addTearDown(() => t.pumpWidget(const SizedBox()));
        final expected = <RaftButtonRecipeSize, (double, double, FontWeight)>{
          RaftButtonRecipeSize.xs: (32, 13, FontWeight.w700),
          RaftButtonRecipeSize.sm: (32, 13, FontWeight.w700),
          RaftButtonRecipeSize.md: (32, 13, FontWeight.w700),
          RaftButtonRecipeSize.lg: (44, 15, FontWeight.w700),
        };
        for (final entry in expected.entries) {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: packForThemeId(id), dark: dark),
              home: Scaffold(
                body: Center(
                  child: RaftButton(
                    key: const ValueKey('button'),
                    label: 'Send',
                    tone: RaftButtonRecipeVariant.danger,
                    size: entry.key,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          );
          expect(
            t.getSize(find.byKey(const ValueKey('button'))).width,
            lessThan(200),
            reason: 'source inline-flex button keeps its natural width',
          );
          final label = find.text('Send');
          final style = DefaultTextStyle.of(t.element(label)).style;
          expect(
            t.getSize(find.byKey(const ValueKey('button'))).height,
            entry.value.$1,
            reason: entry.key.name,
          );
          expect(style.fontSize, entry.value.$2, reason: entry.key.name);
          expect(style.fontWeight, entry.value.$3, reason: entry.key.name);
        }
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'button geometry reads component values independent of identity',
    (t) async {
      addTearDown(() => t.pumpWidget(const SizedBox()));
      final pack = RaftThemePack(
        id: 'custom-controls',
        name: {'en': 'Custom controls'},
        version: '1.0.0',
        light: const RaftModeValues(
          geometry: {'radius.control': 13, 'stroke.control': 2},
        ).mergedWith(builtInRaftTheme.light),
        dark: builtInRaftTheme.dark,
      );
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: pack),
          home: Scaffold(
            body: RaftButton(label: 'Send', onPressed: () {}),
          ),
        ),
      );
      final box = find
          .descendant(
            of: find.byType(RaftButton),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final decoration =
          t.widget<DecoratedBox>(box).decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(13));
      expect((decoration.border! as Border).top.width, 2);
    },
  );
}
