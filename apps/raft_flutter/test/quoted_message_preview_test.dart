import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_permalink.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

const slug = 'acme';
const channelId = '0a0a0a0a-0000-0000-0000-000000000001';
const targetId = '0b0b0b0b-0000-0000-0000-000000000002';
String link([String extra = '']) =>
    'https://app.slock.ai/s/$slug/channel/$channelId?msg=$targetId$extra';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('parseRaftPermalink follows the shared Web parser', () {
    final p = parseRaftPermalink(link())!;
    expect(
      (p.serverSlug, p.routeKind, p.channelId, p.messageId),
      (slug, 'channel', channelId, targetId),
    );
    expect(p.threadParentMessageId, isNull);
    final dm = parseRaftPermalink(
      'https://app.raft.build/s/$slug/dm/$channelId?msg=$targetId',
    )!;
    expect(dm.isDm, isTrue);
    // A thread param must name the same channel; without `msg` the thread
    // parent is the target.
    final thread = parseRaftPermalink(
      'https://app.slock.ai/s/$slug/channel/$channelId?thread=$channelId:$targetId',
    )!;
    expect(thread.messageId, targetId);
    expect(thread.threadParentMessageId, targetId);
    expect(
      parseRaftPermalink(
        'https://app.slock.ai/s/$slug/channel/$channelId?thread=other:$targetId',
      ),
      isNull,
    );
    expect(
      parseRaftPermalink(
        'https://example.com/s/$slug/channel/$channelId?msg=$targetId',
      ),
      isNull,
    );
    expect(
      parseRaftPermalink(
        'https://example.com/s/$slug/channel/$channelId?msg=$targetId',
        hostnames: ['example.com'],
      ),
      isNotNull,
    );
    expect(
      parseRaftPermalink('https://app.slock.ai/s/$slug/channel/$channelId'),
      isNull,
    );
    expect(parseRaftPermalink('not a url'), isNull);
  });

  test(
    'the first quotable permalink skips code, markdown links and other servers',
    () {
      expect(
        extractFirstQuotedPermalink(
          'see `${link()}` and ${link('&x=1')}.',
          serverSlug: slug,
        )?.rawUrl,
        link('&x=1'),
      );
      expect(
        extractFirstQuotedPermalink('[here](${link()})', serverSlug: slug),
        isNull,
      );
      expect(
        extractFirstQuotedPermalink(
          'https://app.slock.ai/s/other/channel/$channelId?msg=$targetId',
          serverSlug: slug,
        ),
        isNull,
      );
      expect(extractFirstQuotedPermalink('no link', serverSlug: slug), isNull);
      // Trailing sentence punctuation is not part of the URL.
      expect(
        extractFirstQuotedPermalink(
          'Look: ${link()}!',
          serverSlug: slug,
        )?.rawUrl,
        link(),
      );
    },
  );

  test('attachment labels', () {
    expect(quotedAttachmentLabel(const []), isNull);
    expect(
      quotedAttachmentLabel([
        {'mimeType': 'image/png'},
      ])?.key,
      '1 image',
    );
    expect(
      quotedAttachmentLabel([
        {'mimeType': 'application/pdf'},
      ])?.key,
      '1 file',
    );
    final images = quotedAttachmentLabel([
      {'mimeType': 'image/png'},
      {'mimeType': 'image/jpeg'},
    ]);
    expect((images?.key, images?.count), ('{count} images', 2));
    final mixed = quotedAttachmentLabel([
      {'mimeType': 'image/png'},
      {'mimeType': 'text/plain'},
    ]);
    expect((mixed?.key, mixed?.count), ('{count} attachments', 2));
  });

  Future<MessageAdapter> mount(
    WidgetTester tester, {
    required Map<String, dynamic> Function() context,
  }) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.server = RaftRecord({'id': 's1', 'role': 'owner', 'slug': slug});
    w.channels = [
      RaftChannel({'id': channelId, 'name': 'product', 'joined': true}),
    ];
    w.channel = w.channels.first;
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      {
        'id': 'quoter',
        'channelId': channelId,
        'seq': '2',
        'senderId': 'alice',
        'senderType': 'user',
        'senderName': 'Alice',
        'messageType': 'chat',
        'content': 'Context: ${link()}',
        'createdAt': '2026-06-22T02:30:00.000Z',
      },
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds[channelId] = {'quoter'};
    api.routes['GET /messages/context/$targetId'] = (_) => context();
    api.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
    };
    api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /channels/$channelId/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return api;
  }

  testWidgets(
    'a permalink becomes a chip and a quoted card; tapping opens it',
    (tester) async {
      final api = await mount(
        tester,
        context: () => {
          'messages': [
            {
              'id': targetId,
              'channelId': channelId,
              'seq': '1',
              'senderId': 'bob',
              'senderType': 'user',
              'senderName': 'Bob',
              'content': 'The **release** gates are green',
              'createdAt': '2026-06-22T02:10:00.000Z',
              'attachments': [
                {
                  'id': 'a1',
                  'filename': 'n.pdf',
                  'mimeType': 'application/pdf',
                },
              ],
            },
          ],
          'channelArchived': true,
        },
      );
      // The in-body link reads as a channel chip instead of the URL.
      expect(
        find.textContaining('app.slock.ai', findRichText: true),
        findsNothing,
      );
      expect(find.text('#product', findRichText: true), findsWidgets);
      final card = find.byKey(const Key('quoted-message-card'));
      expect(card, findsOneWidget);
      expect(find.text('Bob'), findsWidgets);
      expect(find.text('1 file'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      expect(find.byKey(const Key('quoted-message-skeleton')), findsNothing);
      await tester.tap(card);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // Opening jumps to the linked message through its context window.
      expect(
        api.calls.where((c) => c.path == '/messages/context/$targetId').length,
        greaterThanOrEqualTo(2),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'an unreadable target drops the card and the chip reads unavailable',
    (tester) async {
      await mount(tester, context: () => {'messages': []});
      expect(find.byKey(const Key('quoted-message-card')), findsNothing);
      expect(find.byKey(const Key('quoted-message-skeleton')), findsNothing);
      expect(
        find.text('Unavailable linked message', findRichText: true),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
