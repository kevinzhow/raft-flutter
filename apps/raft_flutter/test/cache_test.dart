import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/platform/workspace_cache.dart';

void main() {
  test(
    'cache survives reopening and isolates account, server and origin',
    () async {
      final dir = await Directory.systemTemp.createTemp('raft-cache-test');
      final file = File(p.join(dir.path, 'workspace.sqlite'));
      var db = DriftWorkspaceCache(NativeDatabase(file));
      await db.write(
        'https://one.invalid',
        'alice',
        'server-a',
        'messages',
        'channel',
        [
          {'id': 'm1', 'content': '中文 日本語'},
        ],
      );
      await db.close();
      db = DriftWorkspaceCache(NativeDatabase(file));
      expect(
        await db.read(
          'https://one.invalid',
          'alice',
          'server-a',
          'messages',
          'channel',
        ),
        [
          {'id': 'm1', 'content': '中文 日本語'},
        ],
      );
      expect(
        await db.read(
          'https://two.invalid',
          'alice',
          'server-a',
          'messages',
          'channel',
        ),
        isNull,
      );
      expect(
        await db.read(
          'https://one.invalid',
          'bob',
          'server-a',
          'messages',
          'channel',
        ),
        isNull,
      );
      expect(
        await db.read(
          'https://one.invalid',
          'alice',
          'server-b',
          'messages',
          'channel',
        ),
        isNull,
      );
      await db.close();
      await dir.delete(recursive: true);
    },
  );
  test('revocation purges private messages and drafts; credentials and signed URLs are never cached', () async {
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    await db.write('origin', 'alice', 'server', 'messages', 'private', {
      'content': 'message',
      'accessToken': 'test-only',
      'bootstrapToken': 'test-only',
      'previewToken': 'test-only',
      'localUrl': 'http://localhost/storage/file?token=test-only',
      'previewUrl': 'https://example.invalid/file?previewToken=test-only',
      'attachment': {
        'filename': 'test.png',
        'url': 'https://example.invalid/file?X-Amz-Signature=test-only',
      },
    });
    expect(await db.read('origin', 'alice', 'server', 'messages', 'private'), {
      'content': 'message',
      'localUrl': null,
      'previewUrl': null,
      'attachment': {'filename': 'test.png', 'url': null},
    });
    await db.write('origin', 'alice', 'server', 'draft', 'private', 'draft');
    await db.write(
      'origin',
      'alice',
      'server',
      'draft',
      'thread:parent',
      'reply',
    );
    await db.revokeChannel('origin', 'alice', 'server', 'private');
    expect(
      await db.read('origin', 'alice', 'server', 'messages', 'private'),
      isNull,
    );
    expect(
      await db.read('origin', 'alice', 'server', 'draft', 'private'),
      isNull,
    );
    expect(
      await db.read('origin', 'alice', 'server', 'draft', 'thread:parent'),
      'reply',
    );
    await db.clearAccount('origin', 'alice');
    expect(
      await db.read('origin', 'alice', 'server', 'draft', 'thread:parent'),
      isNull,
    );
    await db.close();
  });
}
