import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_translation_store.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'message_presentation_test.dart' show MessageAdapter;

const _origin = 'https://example.invalid';
const _batch = 'POST /message-translations:batch';

/// The schema of version 1 (before message translations), as shipped.
class _V1Cache extends DriftWorkspaceCache {
  _V1Cache(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement('''CREATE TABLE workspace_cache (
      origin TEXT NOT NULL, principal TEXT NOT NULL, server TEXT NOT NULL,
      kind TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL,
      PRIMARY KEY (origin, principal, server, kind, id))'''),
  );
}

Map<String, dynamic> _saved(
  String id, {
  String channel = 'c1',
  String content = '你好',
  String target = 'en',
  String status = 'translated',
  String? reason,
}) => {
  'messageId': id,
  'channelId': channel,
  'status': status,
  'reason': ?reason,
  if (status == 'translated') 'translatedContent': 'EN $id',
  'targetLanguage': target,
  'originalContent': content,
};

/// Signed-in `alice` (member of s1, gate on) with [cache].
Future<(WorkspaceController, MessageAdapter)> _fixture(
  WorkspaceCache cache, {
  Map<String, dynamic> user = const {},
}) async {
  final a = MessageAdapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice', ...user},
  };
  a.routes['GET /servers/s1/translation-settings'] = (_) => {
    'translationEnabled': true,
    'translationAvailable': true,
    'canManageTranslation': false,
  };
  a.routes[_batch] = (o) => {
    'results': [
      for (final id in (o.data as Map)['messageIds'] as List)
        if (id == 'quota')
          {
            'messageId': id,
            'status': 'skipped',
            'skipReason': 'quota_exceeded',
            'targetLanguage': (o.data as Map)['targetLanguage'],
          }
        else if (id == 'same')
          {
            'messageId': id,
            'status': 'skipped',
            'skipReason': 'same_language',
            'targetLanguage': (o.data as Map)['targetLanguage'],
          }
        else if (id == 'broken')
          {
            'messageId': id,
            'status': 'failed',
            'failureReason': 'provider_failed',
            'targetLanguage': (o.data as Map)['targetLanguage'],
          }
        else
          {
            'messageId': id,
            'status': 'translated',
            'translatedContent': 'EN $id',
            'targetLanguage': (o.data as Map)['targetLanguage'],
          },
    ],
  };
  final client = RaftClient(
    origin: _origin,
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client, cache: cache);
  w.server = RaftRecord({'id': 's1', 'role': 'member'});
  return (w, a);
}

RaftMessage _message(String id, String content, {String channel = 'c1'}) =>
    RaftMessage({
      'id': id,
      'channelId': channel,
      'senderId': 'bob',
      'senderType': 'user',
      'content': content,
    });

Future<void> _gate(DriftWorkspaceCache db, {String role = 'member'}) =>
    db.write(_origin, 'alice', 's1', 'translation-settings', '', {
      'translationEnabled': true,
      'translationAvailable': true,
      'canManageTranslation': false,
      'role': role,
    });

void main() {
  setUp(() => MessageTranslationStore.deviceLanguages = () => ['en-US']);

  group('device cache', () {
    test('migrates a version 1 database and keeps its rows', () async {
      final dir = await Directory.systemTemp.createTemp('raft-translation');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'workspace.sqlite'));
      final v1 = _V1Cache(NativeDatabase(file));
      await v1.write(_origin, 'alice', 's1', 'channels', '', {'channels': []});
      final version = await v1.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 1);
      await v1.close();

      final db = DriftWorkspaceCache(NativeDatabase(file));
      addTearDown(db.close);
      expect(await db.read(_origin, 'alice', 's1', 'channels', ''), {
        'channels': [],
      });
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        2,
      );
      await db.writeTranslations(_origin, 'alice', 's1', [_saved('m1')]);
      expect(await db.readTranslations(_origin, 'alice', 's1'), [_saved('m1')]);
    });

    test(
      'keeps the most recently used entries per server and isolates scopes',
      () async {
        final db = DriftWorkspaceCache(
          NativeDatabase.memory(),
          translationRetention: 3,
        );
        addTearDown(db.close);
        for (final id in ['m1', 'm2', 'm3']) {
          await db.writeTranslations(_origin, 'alice', 's1', [_saved(id)]);
        }
        // Using m1 again makes it the most recent; m2 is now the oldest.
        await db.writeTranslations(_origin, 'alice', 's1', [_saved('m1')]);
        await db.writeTranslations(_origin, 'alice', 's1', [
          _saved('m4'),
          _saved('m5'),
        ]);
        expect(
          [
            for (final e in await db.readTranslations(_origin, 'alice', 's1'))
              e['messageId'],
          ],
          ['m5', 'm4', 'm1'],
        );
        // Another server's bound is its own; other scopes see nothing.
        await db.writeTranslations(_origin, 'alice', 's2', [_saved('x1')]);
        expect(await db.readTranslations(_origin, 'alice', 's1'), hasLength(3));
        expect(await db.readTranslations(_origin, 'bob', 's1'), isEmpty);
        expect(
          await db.readTranslations('https://o.invalid', 'alice', 's1'),
          isEmpty,
        );
      },
    );

    test('channel, server and account revocation delete entries', () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory());
      addTearDown(db.close);
      await db.writeTranslations(_origin, 'alice', 's1', [
        _saved('m1'),
        _saved('m2', channel: 'c2'),
      ]);
      await db.writeTranslations(_origin, 'alice', 's2', [_saved('m3')]);
      await db.writeTranslations(_origin, 'bob', 's1', [_saved('m4')]);
      await db.revokeChannel(_origin, 'alice', 's1', 'c2');
      expect(await db.readTranslations(_origin, 'alice', 's1'), [_saved('m1')]);
      await db.revokeServer(_origin, 'alice', 's2');
      expect(await db.readTranslations(_origin, 'alice', 's2'), isEmpty);
      await db.clearAccount(_origin, 'alice');
      expect(await db.readTranslations(_origin, 'alice', 's1'), isEmpty);
      expect(await db.readTranslations(_origin, 'bob', 's1'), hasLength(1));
    });
  });

  group('store', () {
    test(
      'restored entries paint without a request; an edit or another target reads as absent',
      () async {
        final db = DriftWorkspaceCache(NativeDatabase.memory());
        addTearDown(db.close);
        await _gate(db);
        await db.writeTranslations(_origin, 'alice', 's1', [
          _saved('kept'),
          _saved('edited', content: 'before'),
          _saved('japanese', target: 'ja'),
        ]);
        final (w, a) = await _fixture(db);
        addTearDown(w.dispose);
        await w.translations.restore();
        final settings = w.translations.settings;
        expect(settings.loaded, isTrue, reason: 'gate restored');
        expect(settings.targetLanguage, 'en');

        final kept = w.translations.present(_message('kept', '你好'));
        expect(kept.translatedContent, 'EN kept');
        expect(kept.skeleton, isFalse);
        expect(kept.needsRequest, isFalse);

        // Edited since: the saved translation is not for this content.
        final edited = w.translations.present(_message('edited', 'after'));
        expect(edited.entry, isNull);
        expect(edited.translatedContent, isNull);
        expect(edited.needsRequest, isTrue);

        // Saved for another target language.
        final japanese = w.translations.present(_message('japanese', '你好'));
        expect(japanese.entry, isNull);
        expect(japanese.needsRequest, isTrue);
        expect(a.calls.where((c) => c.path.contains('translation')), isEmpty);

        // The new answer for the edit replaces the saved entry.
        await w.translations.requestTranslations([_message('edited', 'after')]);
        await w.flushCache();
        final saved = {
          for (final e in await db.readTranslations(_origin, 'alice', 's1'))
            e['messageId']: e,
        };
        expect(saved['edited'], containsPair('originalContent', 'after'));
      },
    );

    test(
      'a target language change hides restored entries until asked again',
      () async {
        final db = DriftWorkspaceCache(NativeDatabase.memory());
        addTearDown(db.close);
        await _gate(db);
        await db.writeTranslations(_origin, 'alice', 's1', [_saved('m1')]);
        final (w, _) = await _fixture(db);
        addTearDown(w.dispose);
        await w.translations.restore();
        expect(
          w.translations.present(_message('m1', '你好')).translatedContent,
          'EN m1',
        );
        w.client.user = RaftRecord({'id': 'alice', 'preferredLanguage': 'ja'});
        final after = w.translations.present(_message('m1', '你好'));
        expect(w.translations.settings.targetLanguage, 'ja');
        expect(after.entry, isNull);
        expect(after.needsRequest, isTrue);
        // Mode off: nothing is presented.
        w.client.user = RaftRecord({
          'id': 'alice',
          'preferredTranslationMode': 'off',
        });
        expect(
          w.translations.present(_message('m1', '你好')).translatedContent,
          isNull,
        );
      },
    );

    test('only stable answers are saved, debounced into one write', () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory());
      addTearDown(db.close);
      final (w, _) = await _fixture(db);
      addTearDown(w.dispose);
      w.translations.ensureSettings();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await w.translations.requestTranslations([
        _message('m1', '你好'),
        _message('same', 'hello'),
        _message('quota', '你好吗'),
        _message('broken', '再见'),
      ]);
      // Not written before the debounce.
      expect(await db.readTranslations(_origin, 'alice', 's1'), isEmpty);
      await Future<void>.delayed(MessageTranslationStore.persistDelay * 2);
      await w.flushCache();
      expect(
        {
          for (final e in await db.readTranslations(_origin, 'alice', 's1'))
            e['messageId'],
        },
        {'m1', 'same'},
      );
      expect(
        await db.read(_origin, 'alice', 's1', 'translation-settings', ''),
        containsPair('role', 'member'),
      );
    });

    test(
      'a gate saved under another role is not adopted and is deleted',
      () async {
        final db = DriftWorkspaceCache(NativeDatabase.memory());
        addTearDown(db.close);
        await _gate(db, role: 'admin');
        final (w, _) = await _fixture(db);
        addTearDown(w.dispose);
        await w.translations.restore();
        expect(w.translations.settings.loaded, isFalse);
        await w.flushCache();
        expect(
          await db.read(_origin, 'alice', 's1', 'translation-settings', ''),
          isNull,
        );
      },
    );

    test(
      'a retired cache (logout) writes nothing more; clearing the account purges entries',
      () async {
        final db = DriftWorkspaceCache(NativeDatabase.memory());
        addTearDown(db.close);
        await _gate(db);
        await db.writeTranslations(_origin, 'alice', 's1', [_saved('m1')]);
        final (w, _) = await _fixture(db);
        addTearDown(w.dispose);
        await w.translations.restore();
        await w.translations.requestTranslations([_message('m2', '早上好')]);
        await w.retireCache();
        await db.clearAccount(_origin, 'alice');
        await w.flushCache();
        await Future<void>.delayed(MessageTranslationStore.persistDelay * 2);
        await w.flushCache();
        expect(await db.readTranslations(_origin, 'alice', 's1'), isEmpty);
        expect(
          await db.read(_origin, 'alice', 's1', 'translation-settings', ''),
          isNull,
        );
      },
    );

    test('a restored entry shown again becomes most recently used', () async {
      final db = DriftWorkspaceCache(
        NativeDatabase.memory(),
        translationRetention: 2,
      );
      addTearDown(db.close);
      await _gate(db);
      await db.writeTranslations(_origin, 'alice', 's1', [_saved('old')]);
      await db.writeTranslations(_origin, 'alice', 's1', [_saved('newer')]);
      final (w, _) = await _fixture(db);
      addTearDown(w.dispose);
      await w.translations.restore();
      // `old` is shown in this session; `newer` is not.
      expect(
        w.translations.present(_message('old', '你好')).translatedContent,
        'EN old',
      );
      await w.flushCache();
      await w.translations.requestTranslations([_message('fresh', '晚上好')]);
      await w.flushCache();
      expect(
        {
          for (final e in await db.readTranslations(_origin, 'alice', 's1'))
            e['messageId'],
        },
        {'old', 'fresh'},
      );
    });
  });
}
