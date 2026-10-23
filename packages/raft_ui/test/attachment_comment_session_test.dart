// Web PreviewCommentModeContext: the preview shell, the comments panel and
// the body share one comment session. Comment mode is the panel being open;
// a pushed anchor opens the panel; closing it ends the session.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

class _Probe extends StatelessWidget {
  const _Probe(this.name);
  final String name;
  @override
  Widget build(BuildContext context) {
    final session = RaftAttachmentCommentScope.maybeOf(context)!;
    final anchor = session.pendingAnchor;
    return Column(
      children: [
        Text('$name mode=${session.commentMode} anchor=${anchor?['type']}'),
        TextButton(
          key: ValueKey('$name-push'),
          onPressed: () => session.pushAnchor({
            'type': 'lines',
            'data': {'start': 2, 'end': 2},
          }),
          child: const Text('push'),
        ),
      ],
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  RaftAttachmentCommentState? session,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: RaftAttachmentPreviewShell(
        filename: 'notes.txt',
        onClose: () {},
        commentSession: session,
        commentsBuilder: (_, _) => const _Probe('panel'),
        child: const _Probe('body'),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'comment mode is the panel being open, for body and panel alike',
    (tester) async {
      await _pump(tester);
      expect(find.text('body mode=false anchor=null'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('attachment-preview-mode')));
      await tester.pumpAndSettle();
      expect(find.text('body mode=true anchor=null'), findsOneWidget);
      expect(find.text('panel mode=true anchor=null'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('attachment-preview-mode')));
      await tester.pumpAndSettle();
      expect(find.text('body mode=false anchor=null'), findsOneWidget);
    },
  );

  testWidgets('a pushed anchor opens a closed panel and reaches the panel', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('panel mode=false anchor=null'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('body-push')));
    await tester.pumpAndSettle();
    expect(find.text('panel mode=true anchor=lines'), findsOneWidget);
    expect(find.text('body mode=true anchor=lines'), findsOneWidget);
  });

  testWidgets('closing the panel ends the session: the anchor dies with it', (
    tester,
  ) async {
    final session = RaftAttachmentCommentState();
    addTearDown(session.dispose);
    await _pump(tester, session: session);
    await tester.tap(find.byKey(const ValueKey('body-push')));
    await tester.pumpAndSettle();
    expect(session.pendingAnchor, isNotNull);
    expect(session.commentMode, isTrue);
    await tester.tap(find.byKey(const ValueKey('attachment-preview-mode')));
    await tester.pumpAndSettle();
    expect(session.commentMode, isFalse);
    expect(session.pendingAnchor, isNull);
  });

  testWidgets('the owner reaches the session it passed in', (tester) async {
    final session = RaftAttachmentCommentState();
    addTearDown(session.dispose);
    var jumped = 0;
    session.jumpHandler = (anchor) {
      jumped++;
      return true;
    };
    await _pump(tester, session: session);
    expect(
      session.jump({
        'type': 'video-timestamp',
        'data': {'time': 4},
      }),
      isTrue,
    );
    expect(jumped, 1);
    session.pushAnchor({
      'type': 'lines',
      'data': {'start': 1},
    });
    await tester.pumpAndSettle();
    expect(find.text('panel mode=true anchor=lines'), findsOneWidget);
  });
}
