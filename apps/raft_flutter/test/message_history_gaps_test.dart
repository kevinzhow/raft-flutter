import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_history_gaps.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  // Automatic action, stable anchor and reconnect are exercised end-to-end
  // in history_automatic_gap_view_test; this matrix covers passive states.
  for (final dark in [false, true]) {
    for (final scale in [1.0, 3.1]) {
      testWidgets(
        'saved gap and retry controls fit ${dark ? 'dark' : 'light'} at $scale',
        (t) async {
          t.view.physicalSize = const Size(360, 700);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          Future<void> pump({bool failed = false}) async {
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(dark: dark),
                locale: const Locale('zh', 'CN'),
                supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: Scaffold(
                    body: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(RaftSpace.x2),
                        child: HistoryGapNotice(failed: failed, onRetry: () {}),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          }

          final semantics = t.ensureSemantics();
          try {
            await pump();
            expect(find.byType(Text), findsNothing);
            expect(find.byType(RaftSpinner), findsOneWidget);
            expect(find.byType(RaftRecipeButton), findsNothing);
            await pump(failed: true);
            expect(find.text('无法加载消息。'), findsOneWidget);
            expect(find.text('重试'), findsOneWidget);
            expect(find.byType(RaftRecipeButton), findsOneWidget);
            await t.pumpWidget(const SizedBox.shrink());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
