import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      for (final scale in [2.0, 3.1]) {
        testWidgets('RTL icon chrome stays finite at $scale/$id/$dark', (
          t,
        ) async {
          addTearDown(() => t.pumpWidget(const SizedBox()));
          var presses = 0;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: packForThemeId(id), dark: dark),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: Column(
                        children: [
                          RaftWorkspaceRailAction(
                            label: 'Settings',
                            glyph: RaftGlyph.settings,
                            extent: 38,
                            showTooltip: false,
                            onPressed: () => presses++,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(t.takeException(), isNull);
          final face = find.byType(RaftRecipeBox);
          expect(face, findsOneWidget);
          expect(t.getSize(face), const Size(38, 38));
          final semantics = t.ensureSemantics();
          expect(find.bySemanticsLabel('Settings'), findsOneWidget);
          await t.tap(find.byType(RaftWorkspaceRailAction));
          expect(presses, 1);
          expect(t.takeException(), isNull);
          semantics.dispose();
        }, variant: TargetPlatformVariant.only(TargetPlatform.android));
      }
    }
  }
}
