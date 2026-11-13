// Web AttachmentCommentRefChip + handleJumpToCommentHost: a comment message
// reads "re: file · anchor" above its body and its chip jumps to the
// attachment's message. Web 1.24 retired the `attachment_comments_v0` gate
// (the comment routes, attachments.ts:1016-1083, no longer check it).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_comment_ref.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://comment-ref.invalid',
        sessionStore: MemorySessionStore(),
      );
  bool flag = true;
  bool failing = false;
  final evaluations = <Object?>[];
  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path == '/feature-flags/evaluate') {
      evaluations.add(data);
      if (failing) throw const RaftApiException('down');
      return {
        'evaluations': [
          {'key': 'attachment_comments_v0', 'enabled': flag},
        ],
      };
    }
    return {};
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final calls = <String>[];
  @override
  Future<void> jumpToMessage(
    String channelId,
    String? messageId, {
    bool navigate = true,
    bool replaceEntry = false,
  }) async => calls.add('jump $channelId $messageId');
  @override
  Future<void> openThreadIdentity({
    required String parentChannelId,
    required String parentMessageId,
    String? focusedMessageId,
    String? initialThreadChannelId,
    bool navigate = true,
  }) async =>
      calls.add('thread $parentChannelId $parentMessageId $focusedMessageId');
  @override
  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    VoidCallback? onDraftRestored,
  }) async => calls.add('select ${next.id}');
}

Map<String, dynamic> _message(Map<String, dynamic>? ref) => {
  'id': 'm1',
  'channelId': 'c1',
  'content': 'Looks wrong',
  'commentRef': ?ref,
};

void main() {
  group('commentHostOf', () {
    test('a channel or DM message', () {
      final host = commentHostOf({
        'hostMessageId': 'm9',
        'hostSource': {
          'channelId': 'c2',
          'type': 'channel',
          'routeKind': 'channel',
        },
      })!;
      expect(
        (host.channelId, host.messageId, host.parentMessageId),
        ('c2', 'm9', null),
      );
    });

    test('a message inside a thread opens that thread', () {
      final host = commentHostOf({
        'hostMessageId': 'm9',
        'hostSource': {
          'channelId': 'c2',
          'type': 'thread',
          'parentMessageId': 'p1',
          'threadChannelId': 't1',
        },
      })!;
      expect((host.messageId, host.parentMessageId), ('m9', 'p1'));
    });

    test('a thread root opens its own thread', () {
      final host = commentHostOf({
        'hostMessageId': 'm9',
        'hostSource': {
          'channelId': 'c2',
          'type': 'channel',
          'rootThreadChannelId': 't9',
        },
      })!;
      expect(host.parentMessageId, 'm9');
    });

    test('an unresolved host never jumps', () {
      expect(
        commentHostOf({'hostMessageId': null, 'hostSource': null}),
        isNull,
      );
      expect(commentHostOf({'hostMessageId': 'm', 'hostSource': {}}), isNull);
    });
  });

  group('the message row', () {
    late _Client client;
    late _Workspace w;
    setUp(() {
      client = _Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      w = _Workspace(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channel = RaftChannel({'id': 'c1', 'joined': true});
      w.channels = [
        w.channel!,
        RaftChannel({'id': 'c2', 'joined': true}),
      ];
    });
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    Future<void> pump(WidgetTester t, Map<String, dynamic> message) =>
        t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: TargetPlatform.linux),
            home: Scaffold(
              body: Builder(
                builder: (context) => withAttachmentCommentRef(
                  context,
                  w,
                  RaftMessage(message),
                  const Text('the body'),
                ),
              ),
            ),
          ),
        );

    final channelRef = {
      'attachmentId': 'att-1',
      'filename': 'report.csv',
      'anchorLabel': 'Row 3',
      'anchorQuote': 'north 40 41',
      'hostMessageId': 'm9',
      'hostSource': {
        'channelId': 'c2',
        'type': 'channel',
        'routeKind': 'channel',
      },
    };

    testWidgets('the chip and the quote sit above the body', (t) async {
      await pump(t, _message(channelRef));
      await t.pump();
      await t.pump();
      expect(find.text('re: report.csv · Row 3'), findsOneWidget);
      expect(find.text('north 40 41'), findsOneWidget);
      expect(find.text('the body'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('re: report.csv · Row 3')).dy,
        lessThan(t.getTopLeft(find.text('the body')).dy),
      );
    });

    testWidgets(
      'a server answering the retired flag off still shows the chip, unasked',
      (t) async {
        client.flag = false;
        await pump(t, _message(channelRef));
        await t.pump();
        await t.pump();
        expect(find.text('re: report.csv · Row 3'), findsOneWidget);
        expect(find.text('the body'), findsOneWidget);
        expect(client.evaluations, isEmpty);
      },
    );

    testWidgets('the chip of a channel message jumps to it', (t) async {
      await pump(t, _message(channelRef));
      await t.pump();
      await t.pump();
      await t.tap(find.text('re: report.csv · Row 3'));
      await t.pump();
      expect(w.calls, ['jump c2 m9']);
    });

    testWidgets('the chip of a thread message opens the thread on it', (
      t,
    ) async {
      await pump(
        t,
        _message({
          ...channelRef,
          'hostSource': {
            'channelId': 'c2',
            'type': 'thread',
            'parentMessageId': 'p1',
            'threadChannelId': 't1',
          },
        }),
      );
      await t.pump();
      await t.pump();
      await t.tap(find.text('re: report.csv · Row 3'));
      await t.pump();
      expect(w.calls, ['select c2', 'thread c2 p1 m9']);
    });

    testWidgets('a video comment opens the video at the commented time', (
      t,
    ) async {
      await pump(
        t,
        _message({
          ...channelRef,
          'attachmentId': 'vid-1',
          'anchorLabel': '1:23',
        }),
      );
      await t.pump();
      await t.pump();
      await t.tap(find.text('re: report.csv · 1:23'));
      await t.pump();
      expect(
        AttachmentPendingSeek.consume('vid-1'),
        const Duration(seconds: 83),
      );
      expect(AttachmentPendingOpen.instance.take('vid-1'), isTrue);
    });

    testWidgets('an unresolved host leaves the chip inert', (t) async {
      await pump(
        t,
        _message({...channelRef, 'hostMessageId': null, 'hostSource': null}),
      );
      await t.pump();
      await t.pump();
      await t.tap(find.text('re: report.csv · Row 3'));
      await t.pump();
      expect(w.calls, isEmpty);
    });
  });
}
