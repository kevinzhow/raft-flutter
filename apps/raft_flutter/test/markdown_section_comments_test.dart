import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const source =
    '# Guide\n\nIntroduction.\n\n## **Usage** `API`\n\nTap this paragraph to discuss it.\n\n## Usage API\n\nAnother section.';

class CommentsClient extends RaftClient {
  CommentsClient()
    : super(
        origin: 'https://sections.invalid',
        sessionStore: MemorySessionStore(),
      );
  final writes = <Map<String, dynamic>>[];
  bool flag = true, canComment = true;
  List<Map<String, dynamic>> comments = [];
  String markdown = source;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/preview')) {
      return {
        'status': 'ok',
        'data': {'kind': 'markdown', 'markdown': markdown},
      };
    }
    if (path.endsWith('/comments')) {
      return {
        'comments': comments,
        'viewer': {'canComment': canComment},
      };
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path == '/feature-flags/evaluate') {
      return {
        'evaluations': [
          {'key': 'attachment_comments_v0', 'enabled': flag},
        ],
      };
    }
    if (path.endsWith('/comments')) {
      writes.add(Map<String, dynamic>.from(data as Map));
    }
    return {};
  }
}

class CommentsWorkspace extends WorkspaceController {
  CommentsWorkspace(super.client);
  @override
  Future<void> refreshUnread() async {}
}

Future<CommentsClient> openProduction(
  WidgetTester t, {
  CommentsClient? provided,
  Size size = const Size(856, 944),
}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = provided ?? CommentsClient();
  client.user = RaftRecord({'id': 'alice'});
  client.selectServer('s');
  final w = CommentsWorkspace(client)
    ..server = RaftRecord({'id': 's', 'role': 'owner'})
    ..channel = RaftChannel({'id': 'c', 'joined': true});
  addTearDown(() async {
    w.dispose();
    await client.dispose();
  });
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: TargetPlatform.android),
      home: Scaffold(
        body: AttachmentPreviewDialog(
          controller: w,
          metadata: const {
            'id': 'att',
            'filename': 'guide.md',
            'mimeType': 'text/markdown',
            'channelId': 'c',
          },
          channelId: 'c',
          authorized: () => true,
          onClose: () {},
          onDownload: () async {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return client;
}

Future<void> commentMode(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('attachment-preview-mode')));
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t) async {
  await t.tap(
    find.textContaining('Tap this paragraph', findRichText: true).first,
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'production Markdown preview captures a section and posts its API anchor',
    (t) async {
      final client = await openProduction(t);
      await commentMode(t);
      await capture(t);
      expect(find.text('§ Usage API'), findsOneWidget);
      await t.enterText(find.byType(EditableText).last, 'Discuss section');
      await t.pump();
      await t.tap(find.byTooltip('Send'));
      await t.pumpAndSettle();
      expect(client.writes.single, {
        'content': 'Discuss section',
        'anchor': {
          'type': 'md-section',
          'data': {
            'headingId': 'usage-api',
            'headingTitle': 'Usage API',
            'quote': 'Tap this paragraph to discuss it.',
          },
        },
      });
      expect(find.byTooltip('Remove Anchor'), findsNothing);
    },
  );
  for (final size in [const Size(856, 944), const Size(390, 844)]) {
    testWidgets(
      'Remove Anchor and closing comments both clear the next location at $size',
      (t) async {
        final client = await openProduction(t, size: size);
        await commentMode(t);
        await capture(t);
        await t.tap(find.byTooltip('Remove Anchor'));
        await t.pump();
        expect(find.text('§ Usage API'), findsNothing);
        await capture(t);
        await t.enterText(find.byType(EditableText).last, 'Draft stays');
        await commentMode(t);
        await commentMode(t);
        expect(find.byTooltip('Remove Anchor'), findsNothing);
        expect(find.byType(EditableText).last, findsOneWidget);
        expect(
          t
              .widget<EditableText>(find.byType(EditableText).last)
              .controller
              .text,
          'Draft stays',
        );
        await t.tap(find.byTooltip('Send'));
        await t.pumpAndSettle();
        expect(client.writes.single, {'content': 'Draft stays'});
      },
    );
  }
  testWidgets(
    'flag-off has no comment capture entry and read-only never posts',
    (t) async {
      final client = CommentsClient()..flag = false;
      await openProduction(t, provided: client);
      expect(
        find.byKey(const ValueKey('attachment-preview-mode')),
        findsNothing,
      );
      await t.tap(
        find.textContaining('Tap this paragraph', findRichText: true).first,
      );
      await t.pump();
      expect(client.writes, isEmpty);
      expect(find.byType(RaftComposer), findsNothing);
    },
  );
  testWidgets(
    'server read-only comments retain stored Markdown jumps without a composer',
    (t) async {
      final client = CommentsClient()..canComment = false;
      client.comments = [
        {
          'id': 'web',
          'content': 'A Web comment',
          'senderId': 'bob',
          'senderType': 'user',
          'senderName': 'Bob',
          'createdAt': '2026-11-01T00:00:00Z',
          'anchor': {
            'type': 'md-section',
            'data': {'headingId': 'usage-api-2', 'headingTitle': 'Usage API'},
          },
        },
      ];
      await openProduction(t, provided: client);
      await commentMode(t);
      expect(find.byType(RaftComposer), findsNothing);
      await t.tap(find.text('A Web comment'));
      await t.pumpAndSettle();
      expect(client.writes, isEmpty);
    },
  );
  testWidgets(
    'Web-created section comments sort by live document position rather than time',
    (t) async {
      Map<String, dynamic> row(String id, String heading, String time) => {
        'id': id,
        'content': 'Comment $id',
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'createdAt': time,
        'anchor': {
          'type': 'md-section',
          'data': {'headingId': heading, 'headingTitle': heading},
        },
      };
      final client = CommentsClient()
        ..comments = [
          row('last', 'usage-api-2', '2026-11-01T00:00:00Z'),
          row('first', 'guide', '2026-11-01T00:02:00Z'),
          row('middle', 'usage-api', '2026-11-01T00:01:00Z'),
        ];
      await openProduction(t, provided: client);
      await commentMode(t);
      final ys = [
        for (final id in ['first', 'middle', 'last'])
          t.getTopLeft(find.text('Comment $id')).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()));
      await t.tap(find.text('Comment last'));
      await t.pumpAndSettle();
      expect(client.writes, isEmpty);
    },
  );
}
