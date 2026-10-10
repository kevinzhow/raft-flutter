import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_translation_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/locale_settings_page.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;

const _batch = 'POST /message-translations:batch';

/// A signed-in viewer `alice` with the given `/auth/me` translation fields,
/// in server s1 whose `/translation-settings` gate is [gate].
Future<(WorkspaceController, MessageAdapter)> _fixture({
  Map<String, dynamic> user = const {},
  Map<String, dynamic> gate = const {
    'translationEnabled': true,
    'translationAvailable': true,
    'canManageTranslation': false,
  },
}) async {
  final a = MessageAdapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice', ...user},
  };
  a.routes['GET /servers/s1/translation-settings'] = (_) => gate;
  a.routes['GET /agents'] = (_) => [];
  a.routes['GET /servers/s1/members'] = (_) => [];
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'member'});
  w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
  w.channels = [w.channel!];
  return (w, a);
}

void _ingest(WorkspaceController w, List<(String, String, String)> rows) {
  w.ledger.switchServer('s1');
  var seq = 0;
  w.ledger.ingest([
    for (final (id, sender, content) in rows)
      {
        'id': id,
        'channelId': 'c1',
        'seq': ++seq,
        'senderId': sender,
        'senderType': 'user',
        'senderName': sender,
        'content': content,
        'createdAt': '2026-06-22T02:30:00Z',
      },
  ], expectedGeneration: w.ledger.generation);
  w.visibleIds['c1'] = {for (final (id, _, _) in rows) id};
}

/// Translates every requested id to `EN <id>`.
Map<String, dynamic> _translated(RequestOptions o) => {
  'results': [
    for (final id in (o.data as Map)['messageIds'] as List)
      {
        'messageId': id,
        'status': 'translated',
        'translatedContent': 'EN $id',
        'targetLanguage': (o.data as Map)['targetLanguage'],
      },
  ],
};

List<Map> _batches(MessageAdapter a) => [
  for (final o in a.calls)
    if ('${o.method} ${o.path}' == _batch) o.data as Map,
];

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 150));
  }
}

Widget _host(WorkspaceController w, {RaftFamily family = RaftFamily.elegant}) =>
    MaterialApp(
      theme: raftTheme(family),
      home: Scaffold(body: RaftChatView(controller: w)),
    );

Finder _placeholder(String id) =>
    find.byKey(ValueKey('message-translation-placeholder-$id'));
Finder _indicator(String id) =>
    find.byKey(ValueKey('message-translation-indicator-$id'));

Future<void> _openMenu(WidgetTester t, String text) async {
  final row = find.ancestor(
    of: find.text(text),
    matching: find.byType(RaftMessageRow),
  );
  await t.tapAt(
    t.getCenter(row.first),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await t.pump();
}

void main() {
  setUp(() => MessageTranslationStore.deviceLanguages = () => ['en-US']);

  for (final family in [RaftFamily.brutal, RaftFamily.elegant]) {
    testWidgets(
      '$family auto mode: skeleton, one batched request, translated text and Show original',
      (t) async {
        t.view.physicalSize = const Size(1200, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, a) = (await t.runAsync(_fixture))!;
        addTearDown(w.dispose);
        final reply = Completer<dynamic>();
        a.routes[_batch] = (o) async {
          await reply.future;
          return _translated(o);
        };
        _ingest(w, [
          ('m1', 'bob', '你好 m1'),
          ('m2', 'bob', '你好 m2'),
          ('own', 'alice', 'My own words'),
        ]);
        await t.pumpWidget(_host(w, family: family));
        await _settle(t);
        // Auto mode, nothing cached: the body is a one-line skeleton (Web
        // MessageItem isTranslationPending) while the request is pending.
        expect(_placeholder('m1'), findsOneWidget);
        expect(_placeholder('m2'), findsOneWidget);
        expect(find.text('你好 m1'), findsNothing);
        expect(find.text('Translating…'), findsNWidgets(2));
        // The viewer's own message is not auto-translated.
        expect(_placeholder('own'), findsNothing);
        expect(find.text('My own words'), findsOneWidget);
        final batches = _batches(a);
        expect(batches, hasLength(1));
        expect(batches.single['messageIds'], unorderedEquals(['m1', 'm2']));
        expect(batches.single['targetLanguage'], 'en');
        expect(batches.single['mode'], 'auto');
        // The skeleton keeps exactly one 14/20 body line.
        expect(t.getSize(_placeholder('m1')).height, closeTo(20, .001));

        reply.complete();
        await _settle(t);
        expect(_placeholder('m1'), findsNothing);
        expect(find.text('EN m1'), findsOneWidget);
        expect(find.text('EN m2'), findsOneWidget);
        expect(find.text('Translating…'), findsNothing);
        expect(
          find.descendant(
            of: _indicator('m1'),
            matching: find.text('Show original'),
          ),
          findsOneWidget,
        );
        // Show original / Show translation is a per-message toggle.
        await t.tap(
          find.descendant(
            of: _indicator('m1'),
            matching: find.text('Show original'),
          ),
        );
        await t.pump();
        expect(find.text('你好 m1'), findsOneWidget);
        expect(find.text('EN m1'), findsNothing);
        expect(find.text('EN m2'), findsOneWidget);
        expect(
          find.descendant(
            of: _indicator('m1'),
            matching: find.text('Show translation'),
          ),
          findsOneWidget,
        );
        await t.tap(find.text('Show translation'));
        await t.pump();
        expect(find.text('EN m1'), findsOneWidget);
        // Rebuilds and new controller events do not request again.
        w.notifyListeners();
        await _settle(t);
        expect(_batches(a), hasLength(1));
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('cache hit on revisit: first frame is translated, no request', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    a.routes[_batch] = _translated;
    _ingest(w, [('m1', 'bob', 'Bonjour')]);
    await t.pumpWidget(_host(w));
    await _settle(t);
    expect(find.text('EN m1'), findsOneWidget);
    expect(_batches(a), hasLength(1));
    // Leave (the chat view unmounts) and come back.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_host(w));
    // The first frame that shows the row already shows the translation.
    for (
      var i = 0;
      i < 5 && find.byType(RaftMessageRow).evaluate().isEmpty;
      i++
    ) {
      expect(_placeholder('m1'), findsNothing);
      await t.pump();
    }
    expect(find.text('EN m1'), findsOneWidget);
    expect(_placeholder('m1'), findsNothing);
    await _settle(t);
    expect(_batches(a), hasLength(1));
    expect(
      a.calls.where((o) => o.path == '/servers/s1/translation-settings'),
      hasLength(1),
    );
    // An edit is a new revision: it is requested again.
    _ingest(w, [('m1', 'bob', 'Bonjour encore')]);
    w.notifyListeners();
    await _settle(t);
    expect(_batches(a), hasLength(2));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'bilingual default view shows the original under the translation',
    (t) async {
      final (w, a) = (await t.runAsync(
        () => _fixture(user: {'preferredTranslationDisplay': 'bilingual'}),
      ))!;
      addTearDown(w.dispose);
      a.routes[_batch] = _translated;
      _ingest(w, [('m1', 'bob', 'Hola')]);
      await t.pumpWidget(_host(w));
      await _settle(t);
      expect(find.text('EN m1'), findsOneWidget);
      final original = find.byKey(
        const ValueKey('message-translation-bilingual-original-m1'),
      );
      expect(original, findsOneWidget);
      expect(
        find.descendant(of: original, matching: find.text('Hola')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: original, matching: find.text('Original')),
        findsOneWidget,
      );
      // Show original hides the translation and the bilingual block.
      await t.tap(find.text('Show original'));
      await t.pump();
      expect(original, findsNothing);
      expect(find.text('EN m1'), findsNothing);
      expect(find.text('Hola'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'original default view starts on the original with Show translation',
    (t) async {
      final (w, a) = (await t.runAsync(
        () => _fixture(user: {'preferredTranslationDisplay': 'original'}),
      ))!;
      addTearDown(w.dispose);
      a.routes[_batch] = _translated;
      _ingest(w, [('m1', 'bob', 'Hola')]);
      await t.pumpWidget(_host(w));
      await _settle(t);
      // Auto mode still fetches, but the original view has no skeleton.
      expect(_batches(a), hasLength(1));
      expect(find.text('Hola'), findsOneWidget);
      expect(find.text('Show translation'), findsOneWidget);
      await t.tap(find.text('Show translation'));
      await t.pump();
      expect(find.text('EN m1'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('manual mode: menu Translate → pending → translated', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (w, a) = (await t.runAsync(
      () => _fixture(user: {'preferredTranslationMode': 'manual'}),
    ))!;
    addTearDown(w.dispose);
    final reply = Completer<dynamic>();
    a.routes[_batch] = (o) async {
      await reply.future;
      return _translated(o);
    };
    _ingest(w, [('m1', 'bob', 'Hallo'), ('own', 'alice', 'Mine')]);
    await t.pumpWidget(_host(w));
    await _settle(t);
    // Manual mode never requests or shows a skeleton on its own.
    expect(_batches(a), isEmpty);
    expect(_placeholder('m1'), findsNothing);
    expect(find.text('Hallo'), findsOneWidget);
    await _openMenu(t, 'Hallo');
    final item = find.byKey(const ValueKey('message-menu-translate'));
    expect(item, findsOneWidget);
    await t.tap(item);
    await _settle(t);
    final batches = _batches(a);
    expect(batches, hasLength(1));
    expect(batches.single['messageIds'], ['m1']);
    expect(batches.single['mode'], 'manual');
    // Pending: the original stays (no skeleton) with a Translating… status.
    expect(find.text('Hallo'), findsOneWidget);
    expect(_placeholder('m1'), findsNothing);
    expect(
      find.descendant(
        of: _indicator('m1'),
        matching: find.text('Translating…'),
      ),
      findsOneWidget,
    );
    reply.complete();
    await _settle(t);
    expect(find.text('EN m1'), findsOneWidget);
    expect(find.text('Show original'), findsOneWidget);
    // Translated rows no longer offer Translate; own rows still do (manual).
    await _openMenu(t, 'EN m1');
    expect(find.byKey(const ValueKey('message-menu-translate')), findsNothing);
    await t.tapAt(const Offset(5, 5));
    await t.pump();
    await _openMenu(t, 'Mine');
    expect(
      find.byKey(const ValueKey('message-menu-translate')),
      findsOneWidget,
    );
    await t.tapAt(const Offset(5, 5));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('admin toggle off hides every translation affordance', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (w, a) = (await t.runAsync(
      () => _fixture(
        user: {'preferredTranslationMode': 'manual'},
        gate: {
          'translationEnabled': false,
          'translationAvailable': true,
          'canManageTranslation': true,
        },
      ),
    ))!;
    addTearDown(w.dispose);
    a.routes[_batch] = _translated;
    _ingest(w, [('m1', 'bob', 'Hallo')]);
    await t.pumpWidget(_host(w));
    await _settle(t);
    expect(find.text('Hallo'), findsOneWidget);
    await _openMenu(t, 'Hallo');
    expect(find.byKey(const ValueKey('message-menu-copy-markdown')), findsOne);
    expect(find.byKey(const ValueKey('message-menu-translate')), findsNothing);
    await t.tapAt(const Offset(5, 5));
    await t.pump();
    // The admin's accepted toggle opens the gate without a reload.
    w.translations.adoptServerSettings({
      'translationEnabled': true,
      'translationAvailable': true,
      'canManageTranslation': true,
    });
    await t.pump();
    await _openMenu(t, 'Hallo');
    expect(find.byKey(const ValueKey('message-menu-translate')), findsOne);
    await t.tapAt(const Offset(5, 5));
    await t.pump();
    w.translations.adoptServerSettings({
      'translationEnabled': false,
      'translationAvailable': true,
    });
    await _settle(t);
    expect(_batches(a), isEmpty);
    expect(_indicator('m1'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('auto mode off on the server: no skeleton and no request', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(
      () => _fixture(
        gate: {'translationEnabled': true, 'translationAvailable': false},
      ),
    ))!;
    addTearDown(w.dispose);
    a.routes[_batch] = _translated;
    _ingest(w, [('m1', 'bob', 'Hallo')]);
    await t.pumpWidget(_host(w));
    await _settle(t);
    expect(find.text('Hallo'), findsOneWidget);
    expect(_placeholder('m1'), findsNothing);
    expect(_batches(a), isEmpty);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('failed request: Translation unavailable, Retry translates', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    a.routes[_batch] = (_) => throw StateError('provider down');
    _ingest(w, [('m1', 'bob', 'Hallo')]);
    await t.pumpWidget(_host(w));
    await _settle(t);
    expect(_batches(a), hasLength(1));
    expect(_placeholder('m1'), findsNothing);
    expect(find.text('Hallo'), findsOneWidget);
    expect(
      find.descendant(
        of: _indicator('m1'),
        matching: find.text('Translation unavailable'),
      ),
      findsOneWidget,
    );
    a.routes[_batch] = _translated;
    await t.tap(find.text('Retry'));
    await _settle(t);
    expect(_batches(a), hasLength(2));
    expect(_batches(a).last['mode'], 'manual');
    expect(find.text('EN m1'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a channel of 40 rows opens with one deduplicated batch', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    final reply = Completer<dynamic>();
    a.routes[_batch] = (o) async {
      await reply.future;
      return _translated(o);
    };
    _ingest(w, [for (var i = 0; i < 40; i++) ('m$i', 'bob', 'Zeile $i')]);
    await t.pumpWidget(_host(w));
    await _settle(t);
    // Rebuilds while the batch is in flight must not repeat it.
    for (var i = 0; i < 3; i++) {
      w.notifyListeners();
      await t.pump(const Duration(milliseconds: 200));
    }
    final batches = _batches(a);
    expect(batches, hasLength(1));
    final ids = batches.single['messageIds'] as List;
    // Only the built window (the latest rows) is requested, not the channel.
    expect(ids, contains('m39'));
    expect(ids.length, lessThan(40));
    reply.complete();
    await _settle(t);
    expect(_batches(a), hasLength(1));
    expect(find.text('EN m39'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Language & Region: translation mode, target, view and gate notice',
    (t) async {
      t.view.physicalSize = const Size(900, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final (w, a) = (await t.runAsync(
        () => _fixture(
          gate: {
            'translationEnabled': false,
            'translationAvailable': true,
            'canManageTranslation': true,
          },
        ),
      ))!;
      addTearDown(w.dispose);
      final patches = <Map>[];
      a.routes['PATCH /auth/me'] = (o) {
        patches.add(o.data as Map);
        return {'id': 'alice'};
      };
      a.routes['GET /auth/me'] = (_) => {
        'id': 'alice',
        'preferredTranslationMode': 'manual',
      };
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: SingleChildScrollView(
              child: LocaleSettingsPage(controller: w),
            ),
          ),
        ),
      );
      await _settle(t);
      expect(
        find.text(
          'Translation is not enabled on this server yet. Turn it on under Administration → Translation.',
        ),
        findsOneWidget,
      );
      // Auto (the default) shows the target and the default view.
      expect(find.text('Translation target'), findsWidgets);
      expect(find.text('Default view'), findsOneWidget);
      await t.tap(find.text('Manual'));
      await _settle(t);
      expect(patches.single, {'preferredTranslationMode': 'manual'});
      expect(w.translations.settings.mode, MessageTranslationMode.manual);
      a.routes['GET /auth/me'] = (_) => {
        'id': 'alice',
        'preferredTranslationMode': 'off',
      };
      await t.tap(find.text('Off'));
      await _settle(t);
      expect(patches.last, {'preferredTranslationMode': 'off'});
      // Off keeps originals only: no target or default view controls.
      expect(find.text('Default view'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );

  test('language normalization follows raft-shared', () {
    expect(normalizeTranslationLanguage('zh-CN'), 'zh-cn');
    expect(normalizeTranslationLanguage('zh-Hant'), 'zh-tw');
    expect(normalizeTranslationLanguage('zh'), 'zh-cn');
    expect(normalizeTranslationLanguage('pt-BR'), 'pt-br');
    expect(normalizeTranslationLanguage('fr-CA'), 'fr');
    expect(normalizeTranslationLanguage('nl'), isNull);
    expect(normalizeTranslationLanguage(' '), isNull);
  });
}
