import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_uploads.dart';
import 'package:raft_flutter/data/shared_draft_attachment.dart';
import 'package:raft_flutter/platform/desktop_windows.dart';
import 'package:raft_flutter/platform/desktop_drafts.dart';
import 'package:raft_flutter/platform/desktop_window_exit.dart';
import 'package:raft_flutter/platform/cache_exit.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'app_global_server_selector_test.dart' show RootCache, RootFixture;
import 'desktop_server_windows_test.dart' show WindowsFixture;
import 'desktop_window_broker_test.dart' show Peer, owner, beta;

class DraftWindow extends WindowsFixture {
  DraftWindow(this.draftCache);
  @override
  final WorkspaceCache draftCache;
  @override
  bool get isChild => true;
  @override
  String? get startupServerId => 'b';
}

class HeldCache extends RootCache {
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    await super.write(origin, principal, server, kind, id, value);
  }
}

DesktopDraftCache childCache(DesktopDraftOwner owner) => DesktopDraftCache(
  readRecord: (o, p, s, k, id) => owner.read(o, p, s, k, id, () => true),
  writeRecord: (o, p, s, k, id, v) =>
      owner.write(o, p, s, k, id, v, () => true),
);

void main() {
  testWidgets(
    'production child Root uses the primary draft facade and restores its unsent text after close and reopen',
    (t) async {
      final disk = RootCache(), primary = DesktopDraftOwner();
      primary.cache = disk;
      var f = RootFixture();
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri(path: '/s/beta'),
        desktopWindows: DraftWindow(childCache(primary)),
        productionCache: true,
      );
      final w = f.workspace(t), scope = f.workspace(t).channel!.id;
      w.composer.drafts[scope] = 'Unsent child text';
      await t.runAsync(
        () => prepareDesktopComposerClose(w.composer, cache: w.cache),
      );
      await f.close(t);
      f = RootFixture();
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri(path: '/s/beta'),
        desktopWindows: DraftWindow(childCache(primary)),
        productionCache: true,
      );
      try {
        expect(f.workspace(t).composer.drafts[scope], 'Unsent child text');
      } finally {
        await f.close(t);
      }
    },
  );

  test('a real SQLite restart retains child text and attempts without overwriting primary, other server, account or origin drafts', () async {
    final dir = await Directory.systemTemp.createTemp(
      'raft-window-draft-test-',
    );
    final file = File(p.join(dir.path, 'drafts.sqlite'));
    var db = DriftWorkspaceCache(NativeDatabase(file));
    var primary = DesktopDraftOwner()..cache = db;
    var child = childCache(primary);
    await db.write('https://one.invalid', 'alice', 'a', 'draft', 'c', {
      'text': 'Primary',
    });
    await child.write('https://one.invalid', 'alice', 'a', 'draft', 'c', {
      'text': 'Child A',
      'channelId': 'c',
    });
    await child.write('https://one.invalid', 'alice', 'b', 'draft', 'c', {
      'text': 'Child B',
      'channelId': 'c',
    });
    await child.write('https://two.invalid', 'bob', 'a', 'draft', 'c', {
      'text': 'Other',
      'channelId': 'c',
    });
    await child.write('https://one.invalid', 'alice', 'a', 'attempt', 'c', {
      'fingerprint': 'fingerprint',
      'randomId': 'same-id',
      'channelId': 'c',
    });
    await primary.settled;
    await db.close();
    db = DriftWorkspaceCache(NativeDatabase(file));
    primary = DesktopDraftOwner()..cache = db;
    child = childCache(primary);
    expect(
      (await child.read(
        'https://one.invalid',
        'alice',
        'a',
        'draft',
        'c',
      ))['text'],
      'Child A',
    );
    expect(
      (await child.read(
        'https://one.invalid',
        'alice',
        'b',
        'draft',
        'c',
      ))['text'],
      'Child B',
    );
    expect(
      (await child.read(
        'https://two.invalid',
        'bob',
        'a',
        'draft',
        'c',
      ))['text'],
      'Other',
    );
    expect(
      (await db.read(
        'https://one.invalid',
        'alice',
        'a',
        'draft',
        'c',
      ))['text'],
      'Primary',
    );
    expect(
      (await child.read(
        'https://one.invalid',
        'alice',
        'a',
        'attempt',
        'c',
      ))['randomId'],
      'same-id',
    );
    await db.close();
    await dir.delete(recursive: true);
  });

  test('held accepted write drains before logout purge and late queued/IPC writes cannot recreate logged-out data', () async {
    final (client, _) = await owner();
    final cache = HeldCache();
    late Peer peer;
    final broker = DesktopSessionBroker(
      createWindow: (id, s, b) async => peer = Peer(b, id),
      focusPrimary: () async {},
    );
    broker.bind(client, null, cache: cache);
    await broker.openServer(beta);
    final writing = broker.writeDraft(
      peer.id,
      client.origin,
      'human',
      'b',
      'draft',
      'c',
      {'text': 'held', 'channelId': 'c'},
    );
    await cache.entered.future;
    broker.bind(null, null);
    var drained = false;
    final purge = broker.retireDrafts().then((_) async {
      drained = true;
      await cache.clearAccount(client.origin, 'human');
    });
    await Future<void>.delayed(Duration.zero);
    expect(drained, isFalse);
    await expectLater(
      broker.writeDraft(peer.id, client.origin, 'human', 'b', 'draft', 'c', {
        'text': 'late',
        'channelId': 'c',
      }),
      throwsA(isA<RaftApiException>()),
    );
    cache.release.complete();
    await writing;
    await purge;
    expect(cache.rows, isEmpty);
    await broker.dispose();
    await client.dispose();
    await peer.stream.close();
  });

  test(
    'a missing durable database refuses a new native window clearly',
    () async {
      final (client, _) = await owner();
      var creates = 0;
      final broker = DesktopSessionBroker(
        createWindow: (id, s, b) async {
          creates++;
          return Peer(b, id);
        },
        focusPrimary: () async {},
      );
      broker.bind(client, null);
      await expectLater(
        broker.openServer(beta),
        throwsA(
          isA<RaftApiException>().having(
            (e) => e.message,
            'database recovery message',
            contains('draft database'),
          ),
        ),
      );
      expect(creates, 0);
      await broker.dispose();
      await client.dispose();
    },
  );

  test(
    'retired server drafts cannot reappear after a held write finishes',
    () async {
      final disk = HeldCache(), owner = DesktopDraftOwner()..cache = null;
      owner.cache = disk;
      final writing = owner.write('o', 'p', 's', 'draft', 'c', {
        'text': 'old',
        'channelId': 'c',
      }, () => true);
      await disk.entered.future;
      owner.revokeServer('o', 'p', 's');
      disk.release.complete();
      await writing;
      await owner.settled;
      expect(
        await disk.read('o', 'p', 's', 'draft', 'desktop-window:c'),
        isNull,
      );
      await expectLater(
        () => owner.write('o', 'p', 's', 'draft', 'c', {
          'text': 'late',
          'channelId': 'c',
        }, () => true),
        throwsA(isA<RaftApiException>()),
      );
    },
  );

  testWidgets(
    'unsent attachments veto child close with an actionable send/remove/retry explanation while the primary remains unaffected',
    (t) async {
      final f = RootFixture();
      await f.mount(t, 'light', 1280, uri: Uri(path: '/s/alpha'));
      final w = f.workspace(t), scope = f.workspace(t).channel!.id;
      w.composer.uploads.byScope[scope] = [
        UploadDraft.shared(
          SharedDraftAttachment(
            reference: {'type': 'fixture'},
            filename: 'keep.txt',
            mimeType: 'text/plain',
            sizeBytes: 1,
            openRead: () => Stream.value([1]),
            release: () async {},
          ),
          key: 1,
        ),
      ];
      bool? closed;
      // Use a mounted Navigator's context, as the production AppServicesHost does.
      final active = t.element(find.byType(Navigator).first);
      final saving = saveDesktopWindow(
        active,
        w,
        child: true,
      ).then((v) => closed = v);
      await t.pumpAndSettle();
      expect(closed, isNull);
      expect(find.text('This window still has unsaved drafts'), findsOneWidget);
      expect(
        find.textContaining('Send or remove unsent attachments'),
        findsOneWidget,
      );
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await saving;
      expect(closed, isFalse);
      expect(await saveDesktopWindow(active, w, child: false), isTrue);
      w.composer.uploads.byScope.remove(scope);
      expect(await saveDesktopWindow(active, w, child: true), isTrue);
      await f.close(t);
    },
  );

  test(
    'the existing single-window cache close failure still permits normal exit',
    () async {
      resetCacheExitForTest();
      expect(
        await desktopExitResponse(
          null,
          () async => throw StateError('old cache error'),
        ),
        AppExitResponse.exit,
      );
      resetCacheExitForTest();
    },
  );
}
