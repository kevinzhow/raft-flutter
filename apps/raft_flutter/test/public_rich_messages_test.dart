// The Public server page's rich messages (Web v1.21.23): attachments from the
// public route only, `@token` mentions, reaction counts and the inline reply
// preview of a thread.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/public_attachments.dart';
import 'package:raft_flutter/features/public_server_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_ui/raft_ui.dart';

const _base = '/public/servers/raft-design';
const _api = 'https://example.invalid/api';

class _Client extends RaftClient {
  _Client(this.messages)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final List<Map<String, dynamic>> messages;
  final calls = <String>[];
  @override
  void connect() {}
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    calls.add('$method $path');
    if (path == _base) {
      return {
        'server': {'id': 's', 'name': 'Raft Design', 'slug': 'raft-design'},
        'channels': [
          {'id': 'c1', 'name': 'general', 'description': null},
        ],
        'canJoinAsGuest': true,
      };
    }
    if (path == '$_base/channels/c1/messages') return {'messages': messages};
    if (path == '$_base/threads/t1/messages') return {'messages': const []};
    throw RaftApiException('Not found', status: 404);
  }
}

Map<String, dynamic> _message(
  String id,
  String content, [
  Map<String, dynamic>? more,
]) => {
  'id': id,
  'senderType': 'user',
  'sender': {'displayName': 'Wenyi', 'avatarUrl': null, 'description': null},
  'messageType': 'chat',
  'content': content,
  'createdAt': '2026-06-18T09:12:00.000Z',
  'threadId': null,
  'replyCount': 0,
  ...?more,
};

Future<_Client> _mount(
  WidgetTester t,
  List<Map<String, dynamic>> messages, {
  Size size = const Size(1280, 900),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = _Client(messages);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: PublicServerView(
          client: client,
          slug: 'raft-design',
          onUnavailable: () {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return client;
}

class _Files extends AttachmentFiles {
  final saved = <String>[];
  @override
  Future<String?> save({
    required String url,
    required String filename,
    required String mimeType,
    required CancelToken cancel,
    required bool Function() authorized,
    required void Function(int, int) onProgress,
  }) async {
    saved.add('$url|$filename|$mimeType');
    return '/tmp/$filename';
  }
}

const _urls = PublicAttachmentUrls(api: _api, slug: 'raft-design');

PublicAttachment _file(String name, String mime, {int size = 1000}) =>
    PublicAttachment(
      id: 'a-$name',
      filename: name,
      mimeType: mime,
      sizeBytes: size,
    );

Future<void> _pumpAttachments(
  WidgetTester t,
  List<PublicAttachment> list, {
  _Files? files,
  PublicTextFetch? fetch,
}) async {
  t.view.physicalSize = const Size(1000, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: PublicAttachments(
            attachments: list,
            urls: _urls,
            files: files,
            fetchText: fetch ?? (_, _) async => null,
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  group('what a file card opens (Web readOnlyPreviewKind)', () {
    PublicPreviewKind? kind(String name, String mime, {int size = 100}) =>
        publicPreviewKind(_file(name, mime, size: size));
    test('documents preview, active content never does', () {
      expect(kind('a.pdf', 'application/pdf'), PublicPreviewKind.pdf);
      expect(kind('a.md', 'text/markdown'), PublicPreviewKind.markdown);
      expect(kind('notes', 'text/plain'), PublicPreviewKind.text);
      expect(kind('x.py', 'application/octet-stream'), PublicPreviewKind.text);
      expect(kind('t.csv', 'text/csv'), PublicPreviewKind.text);
      expect(kind('a.html', 'text/html'), isNull);
      expect(kind('a.txt', 'text/html'), isNull);
      expect(kind('a.svg', 'image/svg+xml'), isNull);
      expect(kind('a.svg', 'text/plain'), isNull);
      expect(kind('a.xls', 'application/vnd.ms-excel'), isNull);
      expect(kind('a.zip', 'application/zip'), isNull);
    });
    test(
      'a file over the preview cap is a download, not a truncated preview',
      () {
        expect(
          kind('a.md', 'text/markdown', size: 64 * 1024),
          PublicPreviewKind.markdown,
        );
        expect(kind('a.md', 'text/markdown', size: 64 * 1024 + 1), isNull);
        expect(
          kind('a.txt', 'text/plain', size: 96 * 1024),
          PublicPreviewKind.text,
        );
        expect(kind('a.txt', 'text/plain', size: 96 * 1024 + 1), isNull);
      },
    );
    test('only the raster types the public route serves are inline images', () {
      for (final mime in [
        'image/jpeg',
        'image/png',
        'image/gif',
        'image/webp; x=1',
      ]) {
        expect(publicInlineImage(_file('i', mime)), isTrue, reason: mime);
      }
      for (final mime in ['image/svg+xml', 'image/heic', 'image/bmp']) {
        expect(publicInlineImage(_file('i', mime)), isFalse, reason: mime);
      }
    });
  });

  test('bytes come from the public attachment route only', () {
    expect(_urls.inline('a 1'), '$_api$_base/attachments/a%201');
    expect(_urls.download('a1'), '$_api$_base/attachments/a1?download=1');
    expect(
      _urls.pdfPreview('a1'),
      '$_api$_base/attachments/a1?disposition=inline',
    );
  });

  testWidgets('a file card downloads from the public route', (t) async {
    final files = _Files();
    await _pumpAttachments(t, [
      _file('data.zip', 'application/zip'),
    ], files: files);
    await t.tap(find.byKey(const ValueKey('public-attachment-a-data.zip')));
    await t.pumpAndSettle();
    expect(files.saved, [
      '$_api$_base/attachments/a-data.zip?download=1|data.zip|application/zip',
    ]);
  });

  testWidgets(
    'a markdown file previews its public text; a larger or unreadable one downloads',
    (t) async {
      final asked = <String>[];
      final files = _Files();
      await _pumpAttachments(
        t,
        [_file('readme.md', 'text/markdown')],
        files: files,
        fetch: (url, limit) async {
          asked.add('$url|$limit');
          return '# Hello public\n';
        },
      );
      await t.tap(find.byKey(const ValueKey('public-attachment-a-readme.md')));
      await t.pumpAndSettle();
      expect(asked, ['$_api$_base/attachments/a-readme.md|${64 * 1024}']);
      expect(find.text('Hello public'), findsOneWidget);
      expect(files.saved, isEmpty);
      // Close the preview with its own Download untouched.
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Hello public'), findsNothing);

      // Nothing readable (over the cap or not UTF-8): the download it would have been.
      await _pumpAttachments(
        t,
        [_file('big.txt', 'text/plain')],
        files: files,
        fetch: (_, _) async => null,
      );
      await t.tap(find.byKey(const ValueKey('public-attachment-a-big.txt')));
      await t.pumpAndSettle();
      expect(files.saved, [
        '$_api$_base/attachments/a-big.txt?download=1|big.txt|text/plain',
      ]);
    },
  );

  testWidgets(
    'an image opens the lightbox on the public URL and pages through the message',
    (t) async {
      final files = _Files();
      final images = [
        for (final n in ['one.png', 'two.png'])
          PublicAttachment(
            id: 'a-$n',
            filename: n,
            mimeType: 'image/png',
            sizeBytes: 10,
            width: 400,
            height: 300,
          ),
      ];
      await _pumpAttachments(t, images, files: files);
      await t.tap(find.byKey(const ValueKey('public-attachment-a-two.png')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('public-image-a-two.png')),
        findsOneWidget,
      );
      final shown = t.widget<Image>(
        find.byKey(const ValueKey('public-image-a-two.png')),
      );
      expect(
        ((shown.image as ResizeImage).imageProvider as NetworkImage).url,
        '$_api$_base/attachments/a-two.png',
      );
      await t.tap(find.byKey(const ValueKey('public-image-previous')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('public-image-a-one.png')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('public-image-download')));
      await t.pumpAndSettle();
      expect(
        files.saved.single,
        startsWith('$_api$_base/attachments/a-one.png?download=1'),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('public-image-a-one.png')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the page shows attachments, reactions and mentions of a message',
    (t) async {
      await _mount(t, [
        _message('m1', 'Ping @bob see the file', {
          'attachments': [
            {
              'id': 'f1',
              'filename': 'spec.zip',
              'mimeType': 'application/zip',
              'sizeBytes': 2048,
              'width': null,
              'height': null,
            },
            {
              'id': 'i1',
              'filename': 'shot.png',
              'mimeType': 'image/png',
              'sizeBytes': 10,
              'width': 320,
              'height': 200,
            },
          ],
          'reactions': [
            {'emoji': '👍', 'count': 3},
          ],
          'mentions': [
            {'type': 'user', 'name': 'bob', 'displayName': 'Bob B.'},
          ],
        }),
      ]);
      expect(
        find.byKey(const ValueKey('public-attachment-f1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('public-attachment-i1')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('reaction-👍')), findsOneWidget);
      expect(find.textContaining('3'), findsWidgets);
      // Counts render; nobody can react from here.
      final reaction = t.widget<RaftMountedReaction>(
        find.byKey(const ValueKey('reaction-👍')),
      );
      expect(reaction.count, 3);
      expect(reaction.onPressed, isNull);
    },
  );

  testWidgets(
    'a server without the rich projection still renders the message',
    (t) async {
      await _mount(t, [_message('m1', 'Just text')]);
      expect(find.text('Just text'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('public-message-attachments')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the latest replies show as the inline preview that opens the thread',
    (t) async {
      final client = await _mount(t, [
        _message('m1', 'Parent', {
          'threadId': 't1',
          'replyCount': 2,
          'lastReplyAt': '2026-06-18T10:00:00.000Z',
          'latestReplies': [
            {
              'messageId': 'r1',
              'seq': 1,
              'preview': 'First reply text',
              'senderType': 'agent',
              'senderName': 'Helper',
              'senderAvatarUrl': null,
              'createdAt': '2026-06-18T09:30:00.000Z',
            },
          ],
        }),
        _message('m2', 'Old server row', {'threadId': 't1', 'replyCount': 1}),
      ]);
      expect(
        find.byKey(const ValueKey('public-inline-thread-m1')),
        findsOneWidget,
      );
      expect(find.text('First reply text'), findsOneWidget);
      expect(find.text('2 replies ›'), findsOneWidget);
      // The badge is what the inline preview replaces; a row without previews keeps it.
      expect(find.byKey(const ValueKey('public-thread-open-m1')), findsNothing);
      expect(
        find.byKey(const ValueKey('public-thread-open-m2')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('public-inline-thread-m1')));
      await t.pumpAndSettle();
      expect(client.calls, contains('GET $_base/threads/t1/messages'));
    },
  );
}
