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
      if (id == brutalThemePackId && dark) continue;
      for (final scale in [1.0, 2.0, 3.1]) {
        testWidgets(
          '$id/$dark/$scale Read status is below replies, token styled and accessible',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final semantics = tester.ensureSemantics();
            try {
              addTearDown(() async {
                await tester.pumpWidget(const SizedBox());
                await tester.pump(const Duration(seconds: 3));
              });
              final theme = raftTheme(pack: packForThemeId(id), dark: dark);
              final tokens = theme.extension<RaftTokens>()!;
              await tester.pumpWidget(
                MaterialApp(
                  theme: theme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: const Scaffold(
                    body: SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: 390,
                          child: RaftMessageTile(
                            key: ValueKey('public-read-tile'),
                            author: 'Alice',
                            timestamp: '10:00 AM',
                            content: 'Public DM without any mention.',
                            taskReference: SizedBox(height: 10),
                            threadPreview: SizedBox(
                              key: ValueKey('public-inline-replies'),
                              height: 30,
                            ),
                            readStatus: RaftMessageReadStatus(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              final status = tester.getRect(
                find.byKey(const ValueKey('dm-read-status')),
              );
              final replies = tester.getRect(
                find.byKey(const ValueKey('public-inline-replies')),
              );
              expect(status.top - replies.bottom, 4);
              final row = tester.getRect(
                find.byKey(const ValueKey('public-read-tile')),
              );
              final rowRecipe = RaftMessageRowRecipe(
                tokens,
                viewportWidth: 390,
              );
              expect(
                row.bottom - status.bottom,
                closeTo(
                  rowRecipe.margin.bottom +
                      rowRecipe.padding.bottom +
                      rowRecipe.borderWidth,
                  .01,
                ),
                reason: 'The preceding replies mb-px collapses into the Read line mt-1; it is not a trailing pixel after Read.',
              );
              expect(status.height, scale == 1 ? 20 : greaterThanOrEqualTo(20));
              final text = tester.widget<RaftCssText>(
                find.descendant(
                  of: find.byType(RaftMessageReadStatus),
                  matching: find.byType(RaftCssText),
                ),
              );
              expect(text.style!.fontSize, tokens.typeSlot('caption').fontSize);
              expect(text.style!.color, tokens.colors['foreground-hint']);
              expect(text.style!.fontFamily, tokens.bodyFont);
              expect(find.bySemanticsLabel('Read'), findsOneWidget);
              expect(find.byType(RaftTooltip), findsNothing);
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
