import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/message_translation_store.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'app_global_server_selector_test.dart' show RootFixture, RootCache;

const _memory = 'raft.server-surface.https%3A%2F%2Ffixture.invalid.alice';
const _origin = 'https://fixture.invalid';
const _batch = 'POST /message-translations:batch';
const _gate = 'GET /servers/a/translation-settings';

/// Every network read a cold start makes, including the translation gate.
const _startupReads = [
  'GET /auth/me',
  'GET /servers',
  'GET /channels',
  'GET /channels/dm',
  'GET /channels/unread',
  'GET /messages/channel/ca',
  'GET /agents',
  'GET /servers/a/members',
  'GET /servers/b/members',
  _gate,
];

/// Channel `ca` of server a holds one row of bob in Chinese; the provider
/// translates every requested id to `EN <id>`.
void _routes(RootFixture f, {String content = '你好 mb'}) {
  f.overrides[_gate] = (_) => {
    'translationEnabled': true,
    'translationAvailable': true,
    'canManageTranslation': true,
  };
  f.overrides[_batch] = (RequestOptions o) => {
    'results': [
      for (final id in (o.data as Map)['messageIds'] as List)
        {
          'messageId': id,
          'status': 'translated',
          'translatedContent': 'EN $id',
          'sourceLanguage': 'zh-cn',
          'targetLanguage': (o.data as Map)['targetLanguage'],
        },
    ],
  };
  f.overrides['GET /messages/channel/ca'] = (_) => {
    'messages': [
      {
        'id': 'mb',
        'channelId': 'ca',
        'seq': '1',
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'content': content,
        'createdAt': '2026-10-10T00:00:00Z',
      },
    ],
    'hasMore': false,
    'hasNewer': false,
  };
}

int _batches(RootFixture f) =>
    f.adapter.calls.where((c) => '${c.method} ${c.path}' == _batch).length;

Finder get _placeholder =>
    find.byKey(const ValueKey('message-translation-placeholder-mb'));

/// First process: the channel was opened and its row translated, so the
/// translation and the server gate are on disk.
Future<(RootCache, String)> _firstProcess(WidgetTester t) async {
  final f = RootFixture();
  _routes(f);
  await f.mount(t, 'elegant-light', 1280);
  await t.tap(find.byKey(const ValueKey('global-server-a')));
  await f.flush(t);
  expect(find.text('EN mb'), findsOneWidget);
  expect(_batches(f), 1);
  final uri = f.router(t).currentConfiguration.toString();
  await f.workspace(t).flushCache();
  await f.close(t);
  final saved = await f.cache.readTranslations(_origin, 'alice', 'a');
  expect(saved, hasLength(1));
  expect(saved.single, containsPair('translatedContent', 'EN mb'));
  expect(saved.single, containsPair('originalContent', '你好 mb'));
  expect(saved.single, containsPair('targetLanguage', 'en'));
  expect(saved.single, containsPair('channelId', 'ca'));
  expect(
    await f.cache.read(_origin, 'alice', 'a', 'translation-settings', ''),
    containsPair('role', 'owner'),
  );
  return (f.cache, uri);
}

/// What the row showed in each painted frame in which it is shown:
/// `translation`, `original` or `skeleton`.
final _frames = <String>[];

Future<RootFixture> _restart(
  WidgetTester t,
  RootCache cache,
  String uri, {
  String content = '你好 mb',
}) async {
  _frames.clear();
  final f = RootFixture(cache: cache);
  _routes(f, content: content);
  for (final key in [..._startupReads, _batch]) {
    f.holds[key] = Completer<dynamic>();
  }
  f.onFrame = () {
    if (_placeholder.evaluate().isNotEmpty) _frames.add('skeleton');
    if (find.text('EN mb').evaluate().isNotEmpty) _frames.add('translation');
    if (find.text('你好 mb').evaluate().isNotEmpty) _frames.add('original');
  };
  await f.mount(
    t,
    'elegant-light',
    1280,
    cachedSession: true,
    preferences: {'$_memory.last': 'alpha', '$_memory.a': uri},
  );
  return f;
}

Future<void> _release(WidgetTester t, RootFixture f) async {
  for (final entry in f.holds.values) {
    if (!entry.isCompleted) entry.complete(null);
  }
  await f.flush(t);
}

void main() {
  setUp(() => MessageTranslationStore.deviceLanguages = () => ['en-US']);

  testWidgets(
    'restart shows a cached translation at the row\'s first frame and does not ask again',
    (t) async {
      final (cache, uri) = await _firstProcess(t);
      final f = await _restart(t, cache, uri);
      // No response has arrived: the gate and the translation come from the
      // device, so every frame showing the row shows the translation.
      expect(f.surfaces, everyElement('workspace'));
      expect(_frames, isNotEmpty);
      expect(_frames, everyElement('translation'));
      expect(_batches(f), 0);
      _frames.clear();
      await _release(t, f);
      await f.flush(t);
      // The gate is revalidated once; the cached row is never re-requested
      // and never swaps.
      expect(
        f.adapter.calls.where(
          (c) => c.path == '/servers/a/translation-settings',
        ),
        hasLength(1),
      );
      expect(_batches(f), 0);
      expect(_frames, everyElement('translation'));
      expect(find.text('EN mb'), findsOneWidget);
      await f.close(t);
    },
  );

  testWidgets('restart after an edit requests the edited content again', (
    t,
  ) async {
    final (cache, uri) = await _firstProcess(t);
    // The window saved on disk carries the edited content.
    final key = cache.rows.keys.singleWhere(
      (k) => k.startsWith('$_origin|alice|a|window|'),
    );
    final window = cache.rows[key] as Map;
    cache.rows[key] = {
      ...window,
      'messages': [
        for (final m in window['messages'] as List)
          {...(m as Map), 'content': '你好 edited'},
      ],
    };
    final f = await _restart(t, cache, uri, content: '你好 edited');
    // The saved translation belongs to the old content: never painted. The
    // row is requested again and waits as an auto-mode skeleton.
    expect(_frames, isNotEmpty);
    expect(_frames, everyElement('skeleton'));
    expect(find.text('EN mb'), findsNothing);
    expect(_batches(f), 1);
    await _release(t, f);
    await f.flush(t);
    expect(_batches(f), 1);
    expect(find.text('EN mb'), findsOneWidget);
    await f.workspace(t).flushCache();
    final saved = await cache.readTranslations(_origin, 'alice', 'a');
    expect(saved.single, containsPair('originalContent', '你好 edited'));
    await f.close(t);
  });

  testWidgets('logout clears saved translations and the gate', (t) async {
    final (cache, uri) = await _firstProcess(t);
    final f = await _restart(t, cache, uri);
    await _release(t, f);
    expect(find.text('EN mb'), findsOneWidget);
    // A late (debounced) change is scheduled just before the logout.
    f.workspace(t).translations.setShowOriginal('mb', true);
    final view = t.widget<WorkspaceView>(find.byType(WorkspaceView));
    unawaited(view.onLogout());
    await f.flush(t);
    await t.runAsync(
      () => Future<void>.delayed(MessageTranslationStore.persistDelay * 2),
    );
    await f.flush(t);
    expect(find.byType(WorkspaceView), findsNothing);
    expect(await cache.readTranslations(_origin, 'alice', 'a'), isEmpty);
    expect(
      await cache.read(_origin, 'alice', 'a', 'translation-settings', ''),
      isNull,
    );
    await f.close(t);
  });
}
