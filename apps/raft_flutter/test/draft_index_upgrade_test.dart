import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/data/workspace_composer.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

void main() {
  test('enumerates the previous disk format and a new composer draft after restart', () async {
    final dir = await Directory.systemTemp.createTemp('raft-draft-upgrade-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'workspace.sqlite'));
    const origin = 'https://example.test',
        principal = 'reader',
        server = 'workspace';

    final old = DriftWorkspaceCache(NativeDatabase(file));
    await old.customStatement(
      'INSERT INTO workspace_cache VALUES(?,?,?,?,?,?)',
      [
        origin,
        principal,
        server,
        'draft',
        'channel-1',
        '{"text":"old release text","channelId":"channel-1","shareTokens":null,"files":[]}',
      ],
    );
    await old.write(origin, 'other-reader', server, 'draft', 'private', {
      'text': 'other account text',
      'channelId': 'private',
      'files': [],
    });
    await old.close();

    final cache = DriftWorkspaceCache(NativeDatabase(file));
    final owner = Object();
    final composer = WorkspaceComposer(
      owner: owner,
      read: (kind, scope) => cache.read(origin, principal, server, kind, scope),
      write: (kind, scope, value, {required requiredSuccess}) =>
          cache.write(origin, principal, server, kind, scope, value),
    );
    composer.drafts['channel-2'] = 'new composer text';
    await composer.saveScope('channel-2');
    composer.disposeOwnedBy(owner);
    await cache.close();

    final restarted = DriftWorkspaceCache(NativeDatabase(file));
    addTearDown(restarted.close);
    final rows = await restarted.readDrafts(origin, principal, server);
    expect(rows.map((r) => (r.scope, r.text)), [
      ('channel-2', 'new composer text'),
      ('channel-1', 'old release text'),
    ]);
    expect(rows.first.updatedAt, isNotNull);
    expect(rows.last.updatedAt, isNull);
    await restarted.write(
      origin,
      principal,
      server,
      'draft',
      'channel-2',
      null,
    );
    expect(
      (await restarted.readDrafts(origin, principal, server)).single.scope,
      'channel-1',
    );
    expect(
      await restarted.readDrafts(origin, principal, 'other-server'),
      isEmpty,
    );
  });
}
