import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('large agreement actions wrap, remain reachable and act once', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(560, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    var agreed = 0;
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(3.1)),
          child: child!,
        ),
        home: Scaffold(
          body: RaftCommunityAgreementDialog(
            title: 'Community agreement',
            version: 3,
            bodyMarkdown: 'Welcome. Be kind and assume good intent.',
            onAgree: () async {
              agreed++;
            },
            onClose: () {
              closed++;
            },
            errorMessage: (_, _) => 'Could not join',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final agree = find.byKey(const ValueKey('community-agreement-agree'));
    final cancel = find.byKey(const ValueKey('community-agreement-cancel'));
    expect(tester.getRect(agree).top, greaterThan(tester.getRect(cancel).top));
    await tester.ensureVisible(agree);
    await tester.pumpAndSettle();
    expect(agree.hitTestable(), findsOneWidget);
    await tester.tap(agree);
    await tester.pumpAndSettle();
    expect(agreed, 1);
    expect(closed, 0);
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    expect(cancel.hitTestable(), findsOneWidget);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(agreed, 1);
    expect(closed, 1);
    expect(tester.takeException(), isNull);
  });
}
