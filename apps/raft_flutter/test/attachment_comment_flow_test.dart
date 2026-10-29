// The whole flow in a preview: with attachment comments on, the toggle opens
// the panel (comment mode), a tap on a line of a text preview becomes the
// pending anchor (chip "L2"), the comment is posted with it, and a comment's
// anchor card scrolls the preview back to the line. With the flag off the
// preview has no comments at all.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://comment-flow.invalid',
        sessionStore: MemorySessionStore(),
      );
  bool flag = true;
  final posts = <({String path, dynamic data})>[];
  final comments = <Map<String, dynamic>>[];
  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path == '/feature-flags/evaluate') {
      return {
        'evaluations': [
          {'key': 'attachment_comments_v0', 'enabled': flag},
        ],
      };
    }
    posts.add((path: path, data: data));
    return {};
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/enabled')) return {'enabled': true};
    if (path.endsWith('/comments')) {
      return {
        'comments': comments,
        'viewer': {'canComment': true},
      };
    }
    if (path.endsWith('/preview')) {
      return {
        'status': 'ok',
        'data': {
          'kind': 'text',
          'text': [for (var i = 1; i <= 120; i++) 'row $i of the notes']
              .join('\n'),
        },
      };
    }
    return {'url': 'https://storage.example.invalid/x'};
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
  setUp(() {
    client = _Client()..user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    w = _Workspace(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'channel', 'joined': true});
    w.channels = [w.channel!];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: AttachmentView(
              controller: w,
              files: AttachmentFiles(),
              metadata: const {
                'id': 'notes',
                'filename': 'notes.txt',
                'mimeType': 'text/plain',
                'sizeBytes': 4096,
                'commentCount': 2,
              },
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    await t.tap(find.text('notes.txt'));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the card shows how many comments the attachment has', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: AttachmentView(
            controller: w,
            files: AttachmentFiles(),
            metadata: const {
              'id': 'notes',
              'filename': 'notes.txt',
              'mimeType': 'text/plain',
              'sizeBytes': 4096,
              'commentCount': 2,
            },
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('flag off: the preview has no comments', (t) async {
    client.flag = false;
    await open(t);
    expect(
      find.byKey(const ValueKey('attachment-preview-download')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('attachment-preview-mode')), findsNothing);
  });

  testWidgets('capture a line, comment on it, and jump back to it', (t) async {
    client.comments.add({
      'id': 'c1',
      'content': 'See this one',
      'senderId': 'bob',
      'senderType': 'user',
      'senderName': 'Bob',
      'createdAt': '2026-10-01T00:00:00Z',
      'anchor': {
        'type': 'lines',
        'data': {'start': 90, 'end': 90, 'quote': 'row 90 of the notes'},
      },
    });
    await open(t);
    final toggle = find.byKey(const ValueKey('attachment-preview-mode'));
    expect(toggle, findsOneWidget);
    // Not in comment mode: a tap on the text anchors nothing.
    expect(find.byTooltip('Remove Anchor'), findsNothing);
    await t.tap(toggle);
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.tap(find.text('row 2 of the notes'));
    await t.pump();
    await t.pump();
    expect(find.byTooltip('Remove Anchor'), findsOneWidget);
    // Post it: the anchor travels with the comment.
    final send = t.widget<RaftComposer>(find.byType(RaftComposer)).onSend;
    await send('good line');
    final write = client.posts.single;
    expect(write.path, '/attachments/notes/comments');
    expect(write.data['anchor']['type'], 'lines');
    expect(write.data['anchor']['data']['start'], 2);
    expect(write.data['anchor']['data']['quote'], 'row 2 of the notes');
    // The existing comment sits on line 90: its card scrolls the text there.
    final line = find.descendant(
      of: find.byType(RaftDocumentPreview),
      matching: find.text('row 90 of the notes'),
    );
    expect(t.getTopLeft(line).dy, greaterThan(800));
    await t.tap(find.text('See this one'));
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.getTopLeft(line).dy, inInclusiveRange(0, 800));
    await t.pump(const Duration(seconds: 3));
  });
}
