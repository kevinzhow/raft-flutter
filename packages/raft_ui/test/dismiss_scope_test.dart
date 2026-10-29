import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final closeWithBack in [true, false]) {
    testWidgets(
      'nested root popup publishes Back state and removes it after '
      '${closeWithBack ? 'system Back' : 'explicit close'}',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        final first = OverlayPortalController();
        final second = OverlayPortalController();
        final dismissed = <String>[];
        late ModalRoute<dynamic> outerRoute;
        var routedBacks = 0;
        Widget popup(String name, OverlayPortalController controller) =>
            OverlayPortal(
              controller: controller,
              overlayChildBuilder: (_) => Align(
                alignment: Alignment.center,
                child: RaftBackDismiss(
                  onDismiss: () {
                    dismissed.add(name);
                    controller.hide();
                  },
                  child: Text('$name popup'),
                ),
              ),
              child: TextButton(
                onPressed: controller.show,
                child: Text('Open $name'),
              ),
            );
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                outerRoute = ModalRoute.of(context)!;
                return NavigatorPopHandler<void>(
                  onPopWithResult: (_) {
                    routedBacks++;
                    navigator.currentState!.maybePop();
                  },
                  child: Navigator(
                    key: navigator,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: Column(
                          children: [
                            popup('first', first),
                            popup('second', second),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(outerRoute.popDisposition, RoutePopDisposition.bubble);
        await tester.tap(find.text('Open first'));
        await tester.pumpAndSettle();
        expect(find.text('first popup'), findsOneWidget);
        expect(navigator.currentState!.canPop(), isTrue);
        expect(outerRoute.popDisposition, RoutePopDisposition.doNotPop);

        // A second popup consumes one Back without dismissing the first.
        await tester.tap(find.text('Open second'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(dismissed, ['second']);
        expect(find.text('second popup'), findsNothing);
        expect(find.text('first popup'), findsOneWidget);
        expect(outerRoute.popDisposition, RoutePopDisposition.doNotPop);

        if (closeWithBack) {
          await tester.binding.handlePopRoute();
        } else {
          first.hide();
        }
        await tester.pumpAndSettle();
        expect(dismissed, closeWithBack ? ['second', 'first'] : ['second']);
        expect(find.text('first popup'), findsNothing);
        expect(navigator.currentState!.canPop(), isFalse);
        expect(outerRoute.popDisposition, RoutePopDisposition.bubble);
        expect(routedBacks, closeWithBack ? 2 : 1);
        expect(find.text('Open first'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
