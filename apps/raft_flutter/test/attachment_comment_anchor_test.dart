// Web AttachmentCommentsPanel anchors: the anchor the preview captured rides
// above the composer and is sent with the comment, Remove anchor drops it, and
// an anchored comment is a card that shows its location in the preview.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_comments_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://anchors.invalid',
        sessionStore: MemorySessionStore(),
      );
  final writes = <({String path, dynamic data})>[];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {
    'comments': [
      {
        'id': 'c1',
        'content': 'Typo here',
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'createdAt': '2026-10-01T00:00:00Z',
        'anchor': {
          'type': 'lines',
          'data': {'start': 4, 'end': 6, 'quote': 'the third line'},
        },
      },
      {
        'id': 'c2',
        'content': 'General remark',
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'createdAt': '2026-10-01T00:01:00Z',
      },
      {
        'id': 'c3',
        'content': 'At the drop',
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'createdAt': '2026-10-01T00:02:00Z',
        'anchor': {
          'type': 'video-timestamp',
          'data': {'time': 83},
        },
      },
    ],
    'viewer': {'canComment': true},
  };

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    writes.add((path: path, data: data));
    return {};
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  @override
  Future<void> refreshUnread() async {}
}

void main() {
  late _Client client;
  late _Workspace w;
  late RaftAttachmentCommentState session;
  setUp(() {
    client = _Client()..user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    w = _Workspace(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'channel', 'joined': true});
    session = RaftAttachmentCommentState();
  });
  tearDown(() async {
    session.dispose();
    w.dispose();
    await client.dispose();
  });

  Future<void> pump(WidgetTester t, {RaftCommentsSheetControls? sheet}) async {
    t.view.physicalSize = const Size(800, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant)
            .copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: RaftAttachmentCommentScope(
            state: session,
            child: AttachmentCommentsView(
              controller: w,
              attachmentId: 'att',
              filename: 'notes.txt',
              sheet: sheet,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
  }

  testWidgets('the captured anchor shows above the composer and is sent', (
    t,
  ) async {
    await pump(t);
    session.pushAnchor({
      'type': 'lines',
      'data': {'start': 2, 'end': 2, 'quote': 'line two'},
    });
    await t.pump();
    // The chip in the composer's accessory row.
    // The chip in the composer's accessory row (the cards have chips too).
    expect(find.byTooltip('Remove anchor'), findsOneWidget);
    expect(find.text('L2'), findsOneWidget);
    await t.enterText(find.byType(EditableText).last, 'Check this');
    await t.pump();
    final send = t.widget<RaftComposer>(find.byType(RaftComposer)).onSend;
    expect(await send('Check this'), isTrue);
    final write = client.writes.single;
    expect(write.path, '/attachments/att/comments');
    expect(write.data['content'], 'Check this');
    expect(write.data['anchor'], {
      'type': 'lines',
      'data': {'start': 2, 'end': 2, 'quote': 'line two'},
    });
    // Sent: the anchor is spent, so the next comment carries none.
    expect(session.pendingAnchor, isNull);
    await t.pump();
    expect(find.byTooltip('Remove anchor'), findsNothing);
  });

  testWidgets('Remove anchor drops it from the session and the next comment', (
    t,
  ) async {
    await pump(t);
    session.pushAnchor({
      'type': 'csv-rows',
      'data': {'start': 3, 'end': 5},
    });
    await t.pump();
    expect(
      find.text('Rows 3–5'),
      findsNothing,
    ); // label uses "Row {start}–{end}"
    expect(find.text('Row 3–5'), findsOneWidget);
    await t.tap(find.byTooltip('Remove anchor'));
    await t.pump();
    expect(session.pendingAnchor, isNull);
    expect(find.byTooltip('Remove anchor'), findsNothing);
    final send = t.widget<RaftComposer>(find.byType(RaftComposer)).onSend;
    await send('plain');
    expect(client.writes.single.data.containsKey('anchor'), isFalse);
  });

  testWidgets('an anchored comment shows its location in the preview', (
    t,
  ) async {
    await pump(t);
    final jumps = <Map<String, dynamic>>[];
    session.jumpHandler = (anchor) {
      jumps.add(anchor);
      return true;
    };
    // Sorted by anchor: general remark first, then line 4, then 1:23.
    final texts = ['General remark', 'Typo here', 'At the drop'];
    final ys = [for (final text in texts) t.getTopLeft(find.text(text)).dy];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.text('L4–6'), findsOneWidget);
    expect(find.text('1:23'), findsOneWidget);
    await t.tap(find.text('Typo here'));
    await t.pump();
    expect(jumps.single, {
      'type': 'lines',
      'data': {'start': 4, 'end': 6, 'quote': 'the third line'},
    });
    await t.tap(find.text('At the drop'));
    await t.pump();
    expect(jumps.last['type'], 'video-timestamp');
    // An unanchored comment is not a jump.
    await t.tap(find.text('General remark'));
    await t.pump();
    expect(jumps, hasLength(2));
  });

  testWidgets('on the phone sheet a successful jump folds the panel away', (
    t,
  ) async {
    var toggled = 0;
    await pump(
      t,
      sheet: RaftCommentsSheetControls(
        expanded: true,
        onToggle: () => toggled++,
      ),
    );
    session.jumpHandler = (_) => true;
    await t.tap(find.text('Typo here'));
    await t.pump();
    expect(toggled, 1);
    // A jump that found nothing keeps the panel open.
    session.jumpHandler = (_) => false;
    await t.tap(find.text('Typo here'));
    await t.pump();
    expect(toggled, 1);
  });
}
