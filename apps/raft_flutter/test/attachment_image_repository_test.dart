import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:flutter/material.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';

AttachmentImageScope scope([String principal = 'alice']) =>
    AttachmentImageScope(
      origin: 'https://example.invalid',
      principal: principal,
      server: 'server',
      generation: principal == 'alice' ? 1 : 2,
      role: 'member',
    );
AttachmentImageKey key(
  String id, {
  String revision = 'A',
  AttachmentImageScope? owner,
}) => AttachmentImageKey(
  scope: owner ?? scope(),
  channelId: 'channel',
  attachmentId: id,
  revision: revision,
);

class _Harness {
  _Harness({
    int maxEntries = 64,
    int maxEncodedBytes = 64,
    int maxDecodedBytes = 96,
    int maxConcurrentLoads = 4,
  }) {
    repository = AttachmentImageRepository(
      scope: scope(),
      retainedAuthority: (key) => allowed && key.scope == current,
      maxEntries: maxEntries,
      maxEncodedBytes: maxEncodedBytes,
      maxDecodedBytes: maxDecodedBytes,
      maxConcurrentLoads: maxConcurrentLoads,
      decoder: (bytes) async {
        decodes++;
        return DecodedAttachmentImage(
          provider: MemoryImage(bytes),
          encodedBytes: bytes.length,
          decodedBytes: 4,
          release: () async {
            disposals++;
          },
        );
      },
    );
  }
  bool allowed = true;
  AttachmentImageScope current = scope();
  late final AttachmentImageRepository repository;
  int loads = 0, decodes = 0, disposals = 0;
  AttachmentImageLease acquire(
    AttachmentImageKey id, {
    Future<Uint8List> Function(CancelToken)? load,
    bool Function()? authorized,
  }) => repository.acquire(
    id,
    authorized: authorized ?? () => true,
    load: (cancel) {
      loads++;
      return load?.call(cancel) ?? Future.value(Uint8List(4));
    },
  );
}

class _RasterClient extends RaftClient {
  _RasterClient()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  int resolutions = 0;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    resolutions++;
    return {'url': 'https://storage.example.invalid/owned-public-fixture'};
  }
}

class _RasterFiles extends AttachmentFiles {
  int downloads = 0;
  @override
  Future<Uint8List> image(String url, {required CancelToken cancel}) async {
    downloads++;
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
    );
  }
}

void main() {
  test(
    'simultaneous consumers share one load and stable decoded provider',
    () async {
      final h = _Harness();
      addTearDown(h.repository.dispose);
      final a = h.acquire(key('file'));
      final b = h.acquire(key('file'));
      final first = await a.ready;
      expect(await b.ready, same(first));
      expect(h.loads, 1);
      expect(h.decodes, 1);
      a.release();
      b.release();
      final remount = h.acquire(key('file'));
      expect(await remount.ready, same(first));
      expect(h.loads, 1);
      expect(h.decodes, 1);
      remount.release();
    },
  );

  test(
    'one released consumer cannot cancel another pending subscriber',
    () async {
      final h = _Harness();
      addTearDown(h.repository.dispose);
      final pending = Completer<Uint8List>();
      CancelToken? token;
      final a = h.acquire(
        key('file'),
        load: (cancel) {
          token = cancel;
          return pending.future;
        },
      );
      final b = h.acquire(key('file'));
      await Future<void>.delayed(Duration.zero);
      a.release();
      expect(token!.isCancelled, false);
      pending.complete(Uint8List(4));
      await b.ready;
      await expectLater(a.ready, throwsA(isA<StaleAttachmentImage>()));
      expect(h.loads, 1);
      b.release();
    },
  );

  test(
    'last release cancels pending work and rejects its late bytes',
    () async {
      final h = _Harness();
      addTearDown(h.repository.dispose);
      final pending = Completer<Uint8List>();
      CancelToken? token;
      final a = h.acquire(
        key('file'),
        load: (cancel) {
          token = cancel;
          return pending.future;
        },
      );
      final expectation = expectLater(
        a.ready,
        throwsA(isA<StaleAttachmentImage>()),
      );
      await Future<void>.delayed(Duration.zero);
      a.release();
      expect(token!.isCancelled, true);
      pending.complete(Uint8List(4));
      await expectation;
      await Future<void>.delayed(Duration.zero);
      expect(h.decodes, 0);
      expect(h.repository.entryCount, 0);
    },
  );

  test('changed revision retires old shared work without publishing into the replacement', () async {
    final h = _Harness();
    addTearDown(h.repository.dispose);
    final pending = Completer<Uint8List>();
    final old = h.acquire(key('file'), load: (_) => pending.future);
    final oldResult = expectLater(
      old.ready,
      throwsA(isA<StaleAttachmentImage>()),
    );
    await Future<void>.delayed(Duration.zero);
    final replacement = h.acquire(key('file', revision: 'B'));
    await replacement.ready;
    pending.complete(Uint8List(4));
    await oldResult;
    await Future<void>.delayed(Duration.zero);
    expect(h.loads, 2); // Both requests started; old late bytes are rejected.
    expect(h.decodes, 1);
    expect(h.repository.entryCount, 1);
    old.release();
    replacement.release();
  });

  test(
    'identity replacement clears loaded bytes and cancels pending old work',
    () async {
      final h = _Harness();
      addTearDown(h.repository.dispose);
      final loaded = h.acquire(key('loaded'));
      await loaded.ready;
      final pending = Completer<Uint8List>();
      CancelToken? token;
      final waiting = h.acquire(
        key('waiting'),
        load: (cancel) {
          token = cancel;
          return pending.future;
        },
      );
      final oldResult = expectLater(
        waiting.ready,
        throwsA(isA<StaleAttachmentImage>()),
      );
      await Future<void>.delayed(Duration.zero);
      h.current = scope('bob');
      h.repository.synchronize(h.current);
      expect(token!.isCancelled, true);
      expect(h.repository.entryCount, 0);
      expect(h.repository.encodedByteCount, 0);
      expect(h.repository.decodedByteCount, 0);
      expect(loaded.active, false);
      final fresh = h.acquire(key('loaded', owner: h.current));
      await fresh.ready;
      pending.complete(Uint8List(4));
      await oldResult;
      expect(h.decodes, 2);
      loaded.release();
      waiting.release();
      fresh.release();
    },
  );

  test(
    'a decoder completing after revocation releases its owned resource',
    () async {
      final decoded = Completer<DecodedAttachmentImage>();
      var allowed = true, disposed = 0;
      final repository = AttachmentImageRepository(
        scope: scope(),
        retainedAuthority: (_) => allowed,
        decoder: (_) => decoded.future,
      );
      addTearDown(repository.dispose);
      final lease = repository.acquire(
        key('file'),
        authorized: () => true,
        load: (_) async => Uint8List(4),
      );
      final rejected = expectLater(
        lease.ready,
        throwsA(isA<StaleAttachmentImage>()),
      );
      await Future<void>.delayed(Duration.zero);
      allowed = false;
      repository.synchronize(scope());
      decoded.complete(
        DecodedAttachmentImage(
          provider: MemoryImage(Uint8List(4)),
          encodedBytes: 4,
          decodedBytes: 4,
          release: () async {
            disposed++;
          },
        ),
      );
      await rejected;
      await Future<void>.delayed(Duration.zero);
      expect(disposed, 1);
      expect(repository.entryCount, 0);
      expect(repository.encodedByteCount, 0);
      lease.release();
    },
  );

  test(
    'same-identity membership or projection revocation evicts idle bytes',
    () async {
      final h = _Harness();
      addTearDown(h.repository.dispose);
      final lease = h.acquire(key('file'));
      await lease.ready;
      lease.release();
      h.allowed = false;
      h.repository.synchronize(h.current);
      expect(h.repository.entryCount, 0);
      expect(h.repository.encodedByteCount, 0);
      expect(h.disposals, 1);
      expect(
        () => h.acquire(key('file')),
        throwsA(isA<StaleAttachmentImage>()),
      );
    },
  );

  test('an LRU hit cannot grant a no-longer-visible consumer access', () async {
    final h = _Harness();
    addTearDown(h.repository.dispose);
    final a = h.acquire(key('file'));
    await a.ready;
    a.release();
    expect(
      () => h.acquire(key('file'), authorized: () => false),
      throwsA(isA<StaleAttachmentImage>()),
    );
    expect(h.loads, 1);
  });

  test('failed load is not cached and explicit retry owns new work', () async {
    final h = _Harness();
    addTearDown(h.repository.dispose);
    final failed = h.acquire(
      key('file'),
      load: (_) => Future.error(StateError('fixture error')),
    );
    await expectLater(failed.ready, throwsStateError);
    failed.release();
    final retry = h.acquire(key('file'));
    await retry.ready;
    expect(h.loads, 2);
    expect(h.decodes, 1);
    retry.release();
  });

  test(
    'entry LRU evicts idle providers while active lease stays valid',
    () async {
      final h = _Harness(maxEntries: 2);
      addTearDown(h.repository.dispose);
      final pinned = h.acquire(key('pinned'));
      await pinned.ready;
      final idle = h.acquire(key('idle'));
      await idle.ready;
      idle.release();
      final replacement = h.acquire(key('next'));
      await replacement.ready;
      expect(pinned.active, true);
      expect(h.repository.entryCount, 2);
      expect(h.disposals, 1);
      expect(
        () => h.acquire(key('too-many')),
        throwsA(isA<AttachmentImageBudgetExceeded>()),
      );
      pinned.release();
      replacement.release();
    },
  );

  test('encoded/decoded resident budget cannot evict active readers', () async {
    final h = _Harness(maxEncodedBytes: 4, maxDecodedBytes: 4);
    addTearDown(h.repository.dispose);
    final pinned = h.acquire(key('pinned'));
    await pinned.ready;
    final rejected = h.acquire(key('next'));
    await expectLater(
      rejected.ready,
      throwsA(isA<AttachmentImageBudgetExceeded>()),
    );
    expect(pinned.active, true);
    expect(h.repository.encodedByteCount, 4);
    expect(h.repository.decodedByteCount, 4);
    expect(h.disposals, 1);
    pinned.release();
    rejected.release();
  });

  test(
    'queue bounds in-flight work and never loads a released queued consumer',
    () async {
      final h = _Harness(maxConcurrentLoads: 1);
      addTearDown(h.repository.dispose);
      final pending = Completer<Uint8List>();
      final first = h.acquire(key('first'), load: (_) => pending.future);
      final second = h.acquire(key('second'));
      final abandoned = h.acquire(key('abandoned'));
      final abandonedResult = expectLater(
        abandoned.ready,
        throwsA(isA<StaleAttachmentImage>()),
      );
      await Future<void>.delayed(Duration.zero);
      abandoned.release();
      expect(h.loads, 1);
      pending.complete(Uint8List(4));
      await first.ready;
      await second.ready;
      await abandonedResult;
      expect(h.loads, 2);
      first.release();
      second.release();
    },
  );

  testWidgets(
    'decoded provider survives remount even when global LRU capacity is zero',
    (tester) async {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
      );
      var loads = 0, preparations = 0;
      final repository = AttachmentImageRepository(
        scope: scope(),
        retainedAuthority: (_) => true,
        decoder: (bytes) {
          preparations++;
          return decodeAttachmentImage(bytes);
        },
      );
      final oldSize = PaintingBinding.instance.imageCache.maximumSize;
      PaintingBinding.instance.imageCache.maximumSize = 0;
      try {
        final loaded = await tester.runAsync(() async {
          final lease = repository.acquire(
            key('file'),
            authorized: () => true,
            load: (_) async {
              loads++;
              return bytes;
            },
          );
          return (lease, await lease.ready);
        });
        final result = loaded!;
        final first = result.$1, provider = result.$2;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Image(image: provider),
          ),
        );
        await tester.pump();
        expect(find.byType(Image), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        first.release();
        final remount = repository.acquire(
          key('file'),
          authorized: () => true,
          load: (_) async {
            loads++;
            return bytes;
          },
        );
        final reused = await tester.runAsync(() => remount.ready);
        expect(reused, same(provider));
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Image(image: reused!),
          ),
        );
        await tester.pump();
        expect(loads, 1);
        expect(preparations, 1);
        expect((provider as AttachmentMemoryImage).codecCreations, 1);
        expect(repository.decodedByteCount, 16 * 16 * 4);
        remount.release();
        await tester.pumpWidget(const SizedBox());
      } finally {
        repository.dispose();
        PaintingBinding.instance.imageCache.maximumSize = oldSize;
        await tester.pump();
      }
    },
  );
  testWidgets(
    'actual AttachmentView recycle reuses requests and owned codec; revoke clears the row',
    (tester) async {
      final client = _RasterClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channel = RaftChannel({'id': 'channel', 'joined': true});
      w.channels = [w.channel!];
      w.ledger.switchServer('server');
      w.ledger.ingest([
        {
          'id': 'host',
          'channelId': 'channel',
          'seq': '1',
          'content': 'public diagnostic',
          'attachments': [
            {
              'id': 'file',
              'filename': 'fixture.png',
              'mimeType': 'image/png',
              'width': 16,
              'height': 16,
            },
          ],
        },
      ], expectedGeneration: w.ledger.generation);
      w.visibleIds['channel'] = {'host'};
      final files = _RasterFiles();
      Widget mountedView() => MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: AttachmentView(
            controller: w,
            files: files,
            messageId: 'host',
            metadata: const {
              'id': 'file',
              'filename': 'fixture.png',
              'mimeType': 'image/png',
              'width': 16,
              'height': 16,
            },
          ),
        ),
      );
      Future<void> waitImage() async {
        for (var i = 0; i < 30 && find.byType(Image).evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(find.byType(Image), findsOneWidget);
      }

      try {
        await tester.pumpWidget(mountedView());
        await waitImage();
        final provider =
            tester.widget<Image>(find.byType(Image)).image
                as AttachmentMemoryImage;
        expect(provider.codecCreations, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(mountedView());
        await waitImage();
        expect(tester.widget<Image>(find.byType(Image)).image, same(provider));
        expect(client.resolutions, 1);
        expect(files.downloads, 1);
        expect(provider.codecCreations, 1);
        w.revokeServer('server');
        await tester.pump();
        expect(
          tester
              .widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard))
              .preview,
          isNull,
        );
        expect(w.retainedImageCount, 0);
        expect(w.retainedImageEncodedBytes, 0);
        await tester.pumpWidget(const SizedBox());
      } finally {
        w.dispose();
        await client.dispose();
        await tester.pump();
      }
    },
  );
}
