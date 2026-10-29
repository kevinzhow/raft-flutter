import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final narrow in [true, false]) {
      testWidgets(
        '[N24e] ${dark ? 'dark' : 'light'} unavailable Source selection shell ${narrow ? 'mobile Back' : 'desktop'}',
        (tester) async {
          var backs = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: SizedBox(
                  width: narrow ? 390 : 900,
                  height: 360,
                  child: RaftChannelResolutionBody(
                    label: 'Select a channel',
                    onBack: () => backs++,
                  ),
                ),
              ),
            ),
          );
          expect(find.text('Select a channel'), findsOneWidget);
          expect(
            find.byType(RaftPanelIconButton),
            narrow ? findsOneWidget : findsNothing,
          );
          if (narrow) {
            final button = tester.getRect(find.byType(RaftPanelIconButton));
            final line = tester.getRect(find.byType(RaftCssLineBox));
            // The Android input profile uses the touch PanelAction.
            expect(button.size, const Size(44, 44));
            expect(line.top - button.bottom, 16);
            await tester.tap(find.byType(RaftPanelIconButton));
            expect(backs, 1);
          }
          expect(find.byType(RaftComposer), findsNothing);
          expect(find.byType(RaftConversationTabs), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      '[N24e] ${dark ? 'dark' : 'light'} actual channel placeholder has Source linebox and no borrowed controls',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: const Scaffold(
              body: SizedBox(
                key: Key('surface'),
                width: 400,
                height: 360,
                child: RaftChannelResolutionBody(label: 'Loading channel'),
              ),
            ),
          ),
        );
        expect(find.text('Loading channel'), findsOneWidget);
        final surface = tester.getRect(find.byKey(const Key('surface')));
        final line = tester.getRect(find.byType(RaftCssLineBox));
        expect(line.center, surface.center);
        expect(line.height, 28);
        final text = tester.widget<RaftCssText>(find.byType(RaftCssText));
        expect(text.style!.fontSize, 18);
        expect(text.style!.fontWeight, FontWeight.w700);
        expect(find.byType(RaftComposer), findsNothing);
        expect(find.byType(RaftConversationTabs), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
