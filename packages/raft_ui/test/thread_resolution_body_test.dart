import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark resolution loading has Source center and retry input',
      (tester) async {
        var retries = 0;
        Widget host(Widget body) => MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                key: const Key('surface'),
                width: 390,
                height: 360,
                child: body,
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          host(const RaftThreadResolutionBody(loadingLabel: 'Loading...')),
        );
        final surface = tester.getRect(find.byKey(const Key('surface')));
        final line = tester.getRect(find.byType(RaftCssLineBox));
        expect(line.center, surface.center);
        expect(line.height, 20);
        expect(find.byType(RaftComposer), findsNothing);
        await tester.pumpWidget(
          host(
            RaftThreadResolutionBody(
              loadingLabel: 'Loading...',
              errorTitle: "Couldn't load this thread",
              errorBody: "The thread couldn't be opened. Retry to load it.",
              onRetry: () => retries++,
            ),
          ),
        );
        expect(find.text('Loading...'), findsNothing);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(retries, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(retries, 2);
        await tester.pumpWidget(
          host(
            const RaftThreadRepliesLoadingBody(
              loadingLabel: 'Loading...',
              parent: SizedBox(height: 80, child: Text('Actual parent')),
            ),
          ),
        );
        final parent = tester.getRect(find.text('Actual parent'));
        final remainingLine = tester.getRect(find.byType(RaftCssLineBox));
        expect(remainingLine.center.dy, greaterThan(surface.center.dy));
        expect(parent.bottom, lessThan(remainingLine.top));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
