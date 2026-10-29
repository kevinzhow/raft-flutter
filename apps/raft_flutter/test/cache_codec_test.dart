import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_cache_codec.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

Map<String, dynamic> window() => {
  'channelId': 'private',
  'messages': [
    for (var i = 0; i < 600; i++)
      {
        'id': '$i',
        'content': '中文 日本語 ${'body ' * 500}',
        'accessToken': 'test-only',
        'attachment': {
          'filename': 'test.png',
          'url': 'https://example.invalid/file?X-Amz-Signature=test-only',
          'preview': 'https://example.invalid/file?PREVIEWTOKEN=test-only',
        },
      },
  ],
};

void main() {
  for (final count in [1, 600]) {
    test('codec preserves Unicode and privacy for $count rows', () async {
      final value = window();
      value['messages'] = (value['messages'] as List).take(count).toList();
      final payload = await encodeWorkspaceCache(value);
      final decoded = await decodeWorkspaceCache(payload);
      final messages = decoded['messages'] as List;
      expect(messages, hasLength(count));
      expect(messages.first['content'], contains('中文 日本語'));
      expect(messages.first.containsKey('accessToken'), isFalse);
      expect(messages.first['attachment'], {
        'filename': 'test.png',
        'url': null,
        'preview': null,
      });
      expect(payload, isNot(contains('test-only')));
      // Sanitization must not mutate the source shared with the live model.
      expect(value['messages'][0]['accessToken'], 'test-only');
    });
  }
  test('the public unsigned thumbnailUrl survives the cache; a signed URL does not', () async {
    // The server builds thumbnailUrl from its public CDN base and the
    // thumbnail key (no signature), so a restored message keeps it.
    final payload = await encodeWorkspaceCache({
      'attachments': [
        {
          'id': 'a1',
          'thumbnailUrl': 'https://cdn.example.invalid/thumbs/s1/a1.webp',
          'downloadUrl': 'https://example.invalid/a1?X-Amz-Signature=test-only',
        },
      ],
    });
    final attachment = (await decodeWorkspaceCache(payload))['attachments'][0];
    expect(attachment['thumbnailUrl'], 'https://cdn.example.invalid/thumbs/s1/a1.webp');
    expect(attachment.containsKey('downloadUrl'), isFalse);
  });

  test('translation batches retain order and sanitize every row', () async {
    final entries = [
      for (var i = 0; i < 300; i++)
        {
          'messageId': '$i',
          'channelId': 'private',
          'content': '中文 $i',
          'refreshToken': 'test-only',
        },
    ];
    final encoded = await encodeWorkspaceTranslations(entries);
    final decoded = await decodeWorkspaceTranslations(encoded);
    expect(
      decoded.map((e) => e['messageId']),
      entries.map((e) => e['messageId']),
    );
    expect(decoded.every((e) => !e.containsKey('refreshToken')), isTrue);
  });

  for (final revoke in ['channel', 'server', 'account']) {
    test(
      'queued $revoke purge cannot be overtaken by a large pending write',
      () async {
        final db = DriftWorkspaceCache(NativeDatabase.memory());
        addTearDown(db.close);
        final write = db.write('o', 'u', 's', 'window', 'private', window());
        final translations = db.writeTranslations('o', 'u', 's', [
          for (var i = 0; i < 300; i++)
            {
              'messageId': '$i',
              'channelId': 'private',
              'content': 'text ' * 300,
            },
        ]);
        final purge = switch (revoke) {
          'channel' => db.revokeChannel('o', 'u', 's', 'private'),
          'server' => db.revokeServer('o', 'u', 's'),
          _ => db.clearAccount('o', 'u'),
        };
        // Enqueue reads before awaiting earlier operations: the FIFO is the fence.
        final read = db.read('o', 'u', 's', 'window', 'private');
        final readTranslations = db.readTranslations('o', 'u', 's');
        await Future.wait([write, translations, purge]);
        expect(await read, isNull);
        expect(await readTranslations, isEmpty);
      },
    );
  }
  test(
    'serialization failure does not poison later cache operations',
    () async {
      final db = DriftWorkspaceCache(NativeDatabase.memory());
      addTearDown(db.close);
      await expectLater(
        db.write('o', 'u', 's', 'window', 'bad', {
          'content': 'large ' * 10000,
          'invalid': Object(),
        }),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      await db.write('o', 'u', 's', 'draft', 'good', 'draft');
      expect(await db.read('o', 'u', 's', 'draft', 'good'), 'draft');
    },
  );
  test('close drains pending work and rejects new operations', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    final write = db.write('o', 'u', 's', 'window', 'private', window());
    final read = db.read('o', 'u', 's', 'window', 'private');
    final close = db.close();
    await expectLater(
      db.write('o', 'u', 's', 'draft', 'late', 'late'),
      throwsStateError,
    );
    await write;
    expect((await read)['messages'], hasLength(600));
    await close;
    await db.close();
  });
}
