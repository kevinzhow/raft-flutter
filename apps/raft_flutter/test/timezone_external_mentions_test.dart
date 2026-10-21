import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/composer_directory.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'message_presentation_test.dart' show fixture;

const external = {
  'id': 'projection-1',
  'provider': 'slack',
  'displayName': 'Ada Slack',
  'handles': ['', 'ada.slack'],
  'actorKind': 'human',
  'workspaceName': 'Synthetic workspace',
};

void main() {
  const channel = MethodChannel('flutter_timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('channel sends read the native IANA zone on every dispatch', () async {
    final (w, api) = await fixture('owner');
    addTearDown(w.dispose);
    var reads = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getLocalTimezone');
      return {
        'identifier': reads++ == 0 ? 'Asia/Shanghai' : 'America/New_York',
      };
    });
    api.routes['POST /v2/messages'] = (r) => {
      'id': 'm$reads',
      'channelId': 'c1',
      'content': r.data['content'],
      'seq': '$reads',
    };
    expect(await w.send('first'), isTrue);
    expect(await w.send('second'), isTrue);
    final bodies = api.calls
        .where((r) => r.path == '/v2/messages')
        .map((r) => r.data as Map)
        .toList();
    expect(bodies.map((r) => r['timezone']), [
      'Asia/Shanghai',
      'America/New_York',
    ]);
    expect(reads, 2);
  });
  test(
    'unavailable device zone does not block delivery or invent an offset',
    () async {
      final (w, api) = await fixture('owner');
      addTearDown(w.dispose);
      messenger.setMockMethodCallHandler(
        channel,
        (_) => throw PlatformException(code: 'unavailable'),
      );
      api.routes['POST /v2/messages'] = (r) => {
        'id': 'm',
        'channelId': 'c1',
        'content': r.data['content'],
      };
      expect(await w.send('still send'), isTrue);
      expect(
        (api.calls.singleWhere((r) => r.path == '/v2/messages').data as Map)
            .containsKey('timezone'),
        isFalse,
      );
    },
  );
  test(
    'thread replies send the device zone; direct client sends stay plain',
    () async {
      final (w, api) = await fixture('owner');
      addTearDown(w.dispose);
      var reads = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        reads++;
        return 'Asia/Shanghai';
      });
      api.routes['POST /v2/messages'] = (r) => {
        'id': 'm',
        'channelId': r.data['channelId'],
        'content': r.data['content'],
      };
      w.messageDomain.state.threadParent = RaftMessage({
        'id': 'parent',
        'channelId': 'c1',
        'content': 'Parent',
      });
      w.threadChannelId = 'thread-1';
      expect(await w.send('thread reply', thread: true), isTrue);
      await w.client.send('comments', 'attachment comment');
      expect(reads, 1);
      final bodies = api.calls
          .where((r) => r.path == '/v2/messages')
          .map((r) => r.data as Map)
          .toList();
      expect(bodies.first['timezone'], 'Asia/Shanghai');
      expect(bodies.last.containsKey('timezone'), isFalse);
    },
  );

  test(
    'native metadata cannot dispatch into a replacement client generation',
    () async {
      final (w, api) = await fixture('owner');
      addTearDown(w.dispose);
      final entered = Completer<void>(), zone = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (_) {
        entered.complete();
        return zone.future;
      });
      final sent = w.send('old server');
      await Future.any([entered.future, sent.then((_) {})]);
      w.client.selectServer('s2');
      zone.complete('Asia/Shanghai');
      expect(await sent, isFalse);
      expect(api.calls.where((r) => r.path == '/v2/messages'), isEmpty);
    },
  );

  test(
    'attachment ids remain a private snapshot during native metadata reads',
    () async {
      final (w, api) = await fixture('owner');
      addTearDown(w.dispose);
      final entered = Completer<void>(), zone = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (_) {
        entered.complete();
        return zone.future;
      });
      api.routes['POST /v2/messages'] = (r) => {
        'id': 'm',
        'channelId': 'c1',
        'content': r.data['content'],
      };
      final ids = ['original-attachment'];
      final sent = w.send('', attachments: ids);
      await Future.any([entered.future, sent.then((_) {})]);
      ids[0] = 'changed-by-caller';
      zone.complete('Asia/Shanghai');
      expect(await sent, isTrue);
      expect(
        api.calls
            .singleWhere((r) => r.path == '/v2/messages')
            .data['attachmentIds'],
        ['original-attachment'],
      );
    },
  );

  test('native read keeps optimistic feedback immediate and fences a changed destination', () async {
    final (w, api) = await fixture('owner');
    addTearDown(w.dispose);
    final entered = Completer<void>(), zone = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (_) {
      entered.complete();
      return zone.future;
    });
    final sent = w.send('retained draft');
    await Future.any([entered.future, sent.then((_) {})]);
    expect(api.calls.where((r) => r.path == '/v2/messages'), isEmpty);
    expect(w.messageDomain.timeline().single.json['pendingSend'], isTrue);
    w.channel = RaftChannel({'id': 'c2', 'joined': true});
    w.notifyListeners();
    zone.complete('Asia/Shanghai');
    expect(await sent, isFalse);
    expect(api.calls.where((r) => r.path == '/v2/messages'), isEmpty);
    expect(w.drafts['c1'], 'retained draft');
  });

  test(
    'external candidates sanitize handles and obey channel authority',
    () async {
      final (w, api) = await fixture('owner');
      addTearDown(w.dispose);
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [],
        'agents': [],
        'externalMembers': [
          external,
          {
            ...external,
            'id': 'fallback',
            'handles': [],
            'displayName': '王 小明!',
          },
        ],
      };
      final directory = ComposerDirectory(w);
      addTearDown(directory.dispose);
      final loaded = Completer<void>();
      directory.addListener(() {
        if (cachedChannelRoster(w, 'c1') != null && !loaded.isCompleted) {
          loaded.complete();
        }
      });
      await loaded.future.timeout(const Duration(seconds: 10));
      final choices = directory.people
          .where((p) => p.type == 'external')
          .toList();
      expect(choices.map((p) => p.name), ['ada-slack', '王小明-']);
      expect(choices.first.mention, {
        'type': 'external',
        'id': 'projection-1',
        'name': 'ada-slack',
      });
      expect(choices.first.inChannel, isTrue);
      w.server = RaftRecord({'id': 's1', 'role': 'guest'});
      w.notifyListeners();
      expect(directory.people.where((p) => p.type == 'external'), isEmpty);
    },
  );
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ], full: true)) {
    testWidgets(
      'external selection and deletion preserve the projection $family/$dark',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        api.routes['POST /v2/messages'] = (r) => {
          'id': r.data['randomId'],
          'channelId': 'c1',
          'content': r.data['content'],
          'randomId': r.data['randomId'],
        };
        final sends = <List<Map<String, dynamic>>>[];
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  const Spacer(),
                  RaftComposer(
                    suggestions: const [
                      RaftComposerSuggestion(
                        type: 'external',
                        id: 'projection-1',
                        name: 'ada-slack',
                        title: 'Ada Slack',
                        detail: 'Slack',
                      ),
                    ],
                    onSend: (_) async => false,
                    onSendWithMentions: (body, mentions) async {
                      sends.add(mentions);
                      await w.send(body, mentions: mentions);
                      return false;
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        await t.enterText(find.byType(TextField), '@ada');
        await t.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (w) => w is RaftActorTypeBadge && w.label == 'Slack',
          ),
          findsOneWidget,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(
          t.widget<TextField>(find.byType(TextField)).controller!.text,
          '@ada-slack ',
        );
        await t.tap(find.byTooltip('Send'));
        await t.pumpAndSettle();
        expect(sends.single, [
          {'type': 'external', 'id': 'projection-1', 'name': 'ada-slack'},
        ]);
        await t.enterText(find.byType(TextField), 'removed');
        await t.tap(find.byTooltip('Send'));
        await t.pumpAndSettle();
        expect(sends.last, isEmpty);
        final requests = api.calls
            .where((r) => r.path == '/v2/messages')
            .toList();
        expect(requests, hasLength(2));
        expect(requests.first.data['mentions'], sends.first);
        expect((requests.last.data as Map).containsKey('mentions'), isFalse);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'external mention navigation and safe plain fallbacks $family/$dark',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        api.routes['GET /channels/c1/members'] = (_) => {
          'humans': [],
          'agents': [],
          'externalMembers': [external],
        };
        final directory = (await t.runAsync(() async {
          final directory = ComposerDirectory(w);
          final ready = Completer<void>();
          directory.addListener(() {
            if (cachedChannelRoster(w, 'c1') != null && !ready.isCompleted) {
              ready.complete();
            }
          });
          await ready.future.timeout(const Duration(seconds: 10));
          return directory;
        }))!;
        addTearDown(directory.dispose);
        MessagePresentation view({
          String sender = 'user',
          String id = 'projection-1',
        }) => MessagePresentation(
          controller: w,
          message: RaftMessage({
            'id': 'm1',
            'channelId': 'c1',
            'senderType': sender,
            'content': 'Hello @ada-slack',
            'mentions': [
              {'type': 'external', 'id': id, 'name': 'ada-slack'},
            ],
          }),
          onExternalLink: (_) {},
        );
        final reads = api.calls.length;
        final presentation = view();
        expect(
          presentation.references.single.href,
          'raft-ref://mention/external/projection-1',
        );
        // Web MentionLink: styled before the roster knows the projection
        // (and for guests); only the click needs the roster entry.
        expect(
          view(id: 'missing').references.single.href,
          'raft-ref://mention/external/missing',
        );
        expect(view(sender: 'external_projection').references, isEmpty);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: presentation),
          ),
        );
        final pointer = await t.createGesture(kind: PointerDeviceKind.mouse);
        await pointer.addPointer(location: Offset.zero);
        await pointer.moveTo(
          t.getCenter(find.text('@ada-slack', findRichText: true)),
        );
        await t.pump(const Duration(seconds: 1));
        expect(
          find.byKey(const ValueKey('external-identity-preview')),
          findsOneWidget,
        );
        expect(find.text('Slack · Human'), findsOneWidget);
        expect(find.text('From Synthetic workspace'), findsOneWidget);
        await pointer.removePointer();
        await t.pump(const Duration(seconds: 1));
        await t.tap(find.text('@ada-slack', findRichText: true));
        await t.pump();
        expect(w.location.profile?.kind, RaftProfileKind.external);
        expect(w.location.profile?.isMention, isTrue);
        expect(w.location.profile?.id, 'projection-1');
        expect(w.externalProfile('projection-1')?['displayName'], 'Ada Slack');
        expect(api.calls.length, reads);
        w.closeProfile();
        w.server = RaftRecord({'id': 's1', 'role': 'guest'});
        w.notifyListeners();
        expect(presentation.references.single.identityBacked, isTrue);
        await presentation.open(
          t.element(find.byType(MessagePresentation)),
          'raft-ref://mention/external/projection-1',
        );
        expect(w.location.profile, isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
