import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('credentials stay out of the rendered tree until revealed', (
    tester,
  ) async {
    const secret = 'only-test-credential';
    String? copied;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: RaftSecretView(
            value: secret,
            onCopy: (v) async {
              copied = v;
            },
          ),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(find.text(secret), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const Key('credential-hidden'))).label,
      isNot(contains(secret)),
    );
    await tester.tap(find.text('Copy credential'));
    await tester.pump();
    expect(copied, secret);
    expect(find.text(secret), findsNothing);
    await tester.tap(find.text('Reveal credential'));
    await tester.pump();
    expect(find.text(secret), findsOneWidget);
    expect(tester.getSemantics(find.text(secret)).label, contains(secret));
    await tester.tap(find.text('Hide credential'));
    await tester.pump();
    expect(find.text(secret), findsNothing);
    semantics.dispose();
  });
}
