import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final narrow in [true, false]) {
      testWidgets(
        '[N24e] $family/$dark unavailable Source selection shell ${narrow ? 'mobile Back' : 'desktop'}',
        (tester) async {
          var backs = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
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
          expect(find.text('SELECT A CHANNEL'), findsOneWidget);
          expect(
            find.byType(RaftPanelIconButton),
            narrow ? findsOneWidget : findsNothing,
          );
          if (narrow) {
            final button = tester.getRect(find.byType(RaftPanelIconButton));
            final line = tester.getRect(find.byType(RaftCssLineBox));
            expect(button.size, const Size(28, 28));
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
      '[N24e] $family/$dark actual channel placeholder has Source linebox and no borrowed controls',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
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
        expect(find.text('LOADING CHANNEL'), findsOneWidget);
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
