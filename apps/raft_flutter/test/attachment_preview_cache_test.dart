import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/platform/attachment_preview_files.dart';

import 'fixtures/preview_samples.dart';

/// A storage host that counts every request per path.
class _Storage {
  _Storage._(this.server);
  final HttpServer server;
  final hits = <String, int>{};
  Uint8List body = previewPdf();
  Duration delay = Duration.zero;
  int status = 200;

  /// `sig` values the host refuses with 403 (a lapsed signature).
  final forbidden = <String>{};

  static Future<_Storage> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final storage = _Storage._(server);
    server.listen((request) async {
      storage.hits[request.uri.path] =
          (storage.hits[request.uri.path] ?? 0) + 1;
      await Future<void>.delayed(storage.delay);
      request.response.statusCode =
          storage.forbidden.contains(request.uri.queryParameters['sig'])
          ? 403
          : storage.status;
      request.response.add(storage.body);
      await request.response.close();
    });
    return storage;
  }

  String url(String path) => 'http://127.0.0.1:${server.port}$path';
  int get total => hits.values.fold(0, (a, b) => a + b);
  Future<void> close() => server.close(force: true);
}

class _Client extends RaftClient {
  _Client(this.storage)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final _Storage storage;
  final paths = <String>[];
  int urlRequests = 0;

  /// When set, `/preview` fails with it.
  Object? previewFailure;
  Map<String, dynamic>? previewResponse;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    paths.add(path);
    if (path.endsWith('/preview') && previewFailure != null) {
      throw previewFailure!;
    }
    if (path.endsWith('/preview') && previewResponse != null) {
      return previewResponse;
    }
    if (path.endsWith('/url')) {
      urlRequests++;
      // A new signature every time, like the real server.
      return {'url': storage.url('/blob/doc.pdf?sig=$urlRequests')};
    }
    return {
      'status': 'ok',
      'data': {'kind': 'text', 'text': 'private document'},
    };
  }
}

AttachmentImageStoreKey _key(String id) => AttachmentImageStoreKey(
  identity: AttachmentImageKey.identityOf('https://x.invalid', 'u', 's'),
  channelId: 'c1',
  entry: '["$id","rev","file"]',
);

Future<List<File>> allEntryFiles(Directory root) async => [
  await for (final e in root.list(recursive: true))
    if (e is File) e,
];

void main() {
  late Directory root;
  late _Storage storage;
  late AttachmentDiskCache cache;
  setUpAll(() => HttpOverrides.global = null);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('raft-preview-cache');
    storage = await _Storage.start();
    cache = AttachmentDiskCache(() async => root);
  });
  tearDown(() async {
    await storage.close();
    await root.delete(recursive: true);
  });

  group('AttachmentPreviewFiles.loadCached', () {
    test('the second open, also after a restart, makes no request', () async {
      final files = AttachmentPreviewFiles();
      var signed = 0;
      Future<String> sign() async {
        signed++;
        return storage.url('/blob/a.pdf?sig=$signed');
      }

      final first = await files.loadCached(
        cache: cache,
        key: _key('a'),
        resolveUrl: sign,
        filename: 'a.pdf',
        expectedBytes: storage.body.length,
        cancel: CancelToken(),
        authorized: () => true,
      );
      expect(first, isNotNull);
      expect(await first!.file.readAsBytes(), storage.body);
      await first.dispose();
      expect((signed, storage.total), (1, 1));

      final second = await files.loadCached(
        cache: cache,
        key: _key('a'),
        resolveUrl: sign,
        filename: 'a.pdf',
        expectedBytes: storage.body.length,
        cancel: CancelToken(),
        authorized: () => true,
      );
      expect(await second!.file.readAsBytes(), storage.body);
      await second.dispose();
      expect(
        (signed, storage.total),
        (1, 1),
        reason: 'no URL signing and no storage request on a hit',
      );
      // Disposing the lease never deletes the cached file.
      expect(second.file.existsSync(), isTrue);

      final restarted = AttachmentDiskCache(() async => root);
      final third = await files.loadCached(
        cache: restarted,
        key: _key('a'),
        resolveUrl: sign,
        filename: 'a.pdf',
        expectedBytes: storage.body.length,
        cancel: CancelToken(),
        authorized: () => true,
      );
      expect(third, isNotNull);
      await third!.dispose();
      expect((signed, storage.total), (1, 1));
    });

    test('real Poppler renders the cached PDF on a hit (Linux)', () async {
      if (!Platform.isLinux) return;
      final files = AttachmentPreviewFiles();
      for (var open = 1; open <= 2; open++) {
        final lease = await files.loadCached(
          cache: cache,
          key: _key('pdf'),
          resolveUrl: () async => storage.url('/blob/r.pdf'),
          filename: 'r.pdf',
          expectedBytes: storage.body.length,
          cancel: CancelToken(),
          authorized: () => true,
        );
        final page = await NativePdfRenderer().render(
          lease!.file,
          1,
          cancel: CancelToken(),
          authorized: () => true,
        );
        expect(page.pageCount, 2);
        expect(page.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        await lease.dispose();
        expect(storage.total, 1, reason: 'open $open: one download in total');
      }
      // Rendering leaves no raster behind in the cache.
      expect(await cache.entryCount(), 1);
      expect((await allEntryFiles(root)).length, 1);
    });

    test('two simultaneous opens of one attachment download once', () async {
      storage.delay = const Duration(milliseconds: 80);
      final files = AttachmentPreviewFiles();
      var signed = 0;
      Future<String> sign() async {
        signed++;
        return storage.url('/blob/a.pdf');
      }

      final leases = await Future.wait([
        for (var i = 0; i < 3; i++)
          files.loadCached(
            cache: cache,
            key: _key('a'),
            resolveUrl: sign,
            filename: 'a.pdf',
            cancel: CancelToken(),
            authorized: () => true,
          ),
      ]);
      expect(leases.every((l) => l != null), isTrue);
      expect((signed, storage.total), (1, 1));
      for (final l in leases) {
        await l!.dispose();
      }
    });

    test('a failed download leaves nothing and the retry fetches', () async {
      final files = AttachmentPreviewFiles();
      storage.status = 500;
      await expectLater(
        files.loadCached(
          cache: cache,
          key: _key('a'),
          resolveUrl: () async => storage.url('/blob/a.pdf'),
          filename: 'a.pdf',
          cancel: CancelToken(),
          authorized: () => true,
        ),
        throwsA(isA<DioException>()),
      );
      expect(await cache.sizeBytes(), 0);
      storage.status = 200;
      final ok = await files.loadCached(
        cache: cache,
        key: _key('a'),
        resolveUrl: () async => storage.url('/blob/a.pdf'),
        filename: 'a.pdf',
        cancel: CancelToken(),
        authorized: () => true,
      );
      expect(ok, isNotNull);
      await ok!.dispose();
      expect(await cache.sizeBytes(), storage.body.length);
    });

    test('a signature the host refuses is signed again once', () async {
      final files = AttachmentPreviewFiles();
      storage.forbidden.add('1');
      var signed = 0;
      Future<String> sign() async {
        signed++;
        return storage.url('/blob/a.pdf?sig=$signed');
      }

      final lease = await files.loadCached(
        cache: cache,
        key: _key('a'),
        resolveUrl: sign,
        refreshUrl: sign,
        filename: 'a.pdf',
        expectedBytes: storage.body.length,
        cancel: CancelToken(),
        authorized: () => true,
      );
      expect(lease, isNotNull, reason: 'the second signature is accepted');
      expect((signed, storage.total), (2, 2));
      await lease!.dispose();
      // Without a way to sign again the refusal is the failure it was.
      storage.forbidden.add('9');
      await expectLater(
        files.loadCached(
          cache: cache,
          key: _key('b'),
          resolveUrl: () async => storage.url('/blob/b.pdf?sig=9'),
          filename: 'b.pdf',
          cancel: CancelToken(),
          authorized: () => true,
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('a signature refused twice is a failure, not a loop', () async {
      final files = AttachmentPreviewFiles();
      storage.forbidden.addAll({'1', '2', '3'});
      var signed = 0;
      Future<String> sign() async => storage.url('/blob/a.pdf?sig=${++signed}');
      await expectLater(
        files.loadCached(
          cache: cache,
          key: _key('a'),
          resolveUrl: sign,
          refreshUrl: sign,
          filename: 'a.pdf',
          cancel: CancelToken(),
          authorized: () => true,
        ),
        throwsA(isA<DioException>()),
      );
      expect(signed, 2);
      expect(await cache.sizeBytes(), 0);
    });

    test('a revoked caller gets nothing', () async {
      final files = AttachmentPreviewFiles();
      expect(
        await files.loadCached(
          cache: cache,
          key: _key('a'),
          resolveUrl: () async => storage.url('/x'),
          filename: 'a.pdf',
          cancel: CancelToken(),
          authorized: () => false,
        ),
        isNull,
      );
      expect(storage.total, 0);
    });

    test('without a cache it behaves like load', () async {
      final folder = await Directory.systemTemp.createTemp('raft-nocache');
      addTearDown(() => folder.delete(recursive: true));
      final files = AttachmentPreviewFiles(
        stagingDirectory: () async => folder,
      );
      final lease = await files.loadCached(
        cache: null,
        key: _key('a'),
        resolveUrl: () async => storage.url('/blob/a.pdf'),
        filename: 'a.pdf',
        cancel: CancelToken(),
        authorized: () => true,
      );
      expect(lease!.file.path.startsWith(folder.path), isTrue);
      await lease.dispose();
      expect(lease.file.existsSync(), isFalse);
    });
  });

  group('the preview dialog', () {
    /// Pumps, giving real file I/O turns to finish, until [done].
    Future<void> settle(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 80 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await tester.pump();
      }
    }

    testWidgets('a PDF held on the device opens with no request', (
      tester,
    ) async {
      final client = _Client(storage);
      final w = WorkspaceController(client, attachmentImageStore: cache);
      final metadata = {
        'id': 'a',
        'channelId': 'c1',
        'filename': 'a.pdf',
        'mimeType': 'application/pdf',
        'sizeBytes': storage.body.length,
      };
      // An earlier open stored it.
      final stored = await tester.runAsync(
        () => cache.fetchFile(
          w.attachmentMedia.cacheKey(metadata, 'file', channelId: 'c1'),
          filename: 'a.pdf',
          expectedBytes: storage.body.length,
          download: (file, cancel, progress) => file.writeAsBytes(storage.body),
        ),
      );
      stored!.release();
      final pages = <String>[];
      for (var open = 1; open <= 2; open++) {
        await tester.pumpWidget(
          MaterialApp(
            home: AttachmentPreviewDialog(
              controller: w,
              metadata: metadata,
              channelId: 'c1',
              authorized: () => true,
              onClose: () {},
              onDownload: () async {},
              pdf: _Pdf(pages),
            ),
          ),
        );
        await settle(tester, () => pages.length == open);
        expect(pages, hasLength(open), reason: 'open $open rendered');
        await tester.pumpWidget(const SizedBox());
      }
      expect(client.urlRequests, 0, reason: 'no signed-URL request');
      expect(storage.total, 0, reason: 'no storage request');
      expect(pages.toSet(), hasLength(1), reason: 'the cached file twice');
      // Closing the dialog released the hold, not the file.
      await settle(tester, () => false);
      expect(File(pages.first).existsSync(), isTrue);
      w.dispose();
      await client.dispose();
    });

    testWidgets(
      'a document the server refuses says why, not just "unavailable"',
      (tester) async {
        final client = _Client(storage)
          ..previewFailure = RaftApiException.response(
            'Too many requests, please try again later.',
            status: 429,
            body: {'error': 'Too many requests, please try again later.'},
          );
        final w = WorkspaceController(client, attachmentImageStore: cache);
        const metadata = {
          'id': 'n',
          'channelId': 'c1',
          'filename': 'report.md',
        };
        await tester.pumpWidget(
          MaterialApp(
            home: AttachmentPreviewDialog(
              controller: w,
              metadata: metadata,
              channelId: 'c1',
              authorized: () => true,
              onClose: () {},
              onDownload: () async {},
            ),
          ),
        );
        await settle(
          tester,
          () => find.textContaining('Too many requests').evaluate().isNotEmpty,
        );
        expect(find.textContaining('Too many requests'), findsOneWidget);
        // Anything the server did not say in its own words stays the generic text.
        client.previewFailure = const FormatException(
          'The file cannot be previewed.',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            home: AttachmentPreviewDialog(
              key: UniqueKey(),
              controller: w,
              metadata: metadata,
              channelId: 'c1',
              authorized: () => true,
              onClose: () {},
              onDownload: () async {},
            ),
          ),
        );
        await settle(
          tester,
          () =>
              find.textContaining('Preview unavailable').evaluate().isNotEmpty,
        );
        expect(
          find.text('Preview unavailable. Download the original file.'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
        w.dispose();
        await client.dispose();
      },
    );

    // A spreadsheet the server would not preview cannot be drawn by the app:
    // the reason, and the ways to the content (system app, Download). Text
    // kinds the server refuses are read from the original instead, see
    // attachment_local_preview_test.dart.
    for (final entry in <String, String>{
      'too_large': 'This file exceeds the server preview size limit. Download the original file to view it.',
      'unreadable': 'The file could not be read and may be damaged. Download the original file to view it.',
      'unsupported': 'This file format is not supported for preview. Download the original file to view it.',
      'future_reason': 'Preview unavailable. Download the original file.',
    }.entries) {
      testWidgets('HTTP 200 preview refusal ${entry.key} says why', (
        tester,
      ) async {
        final client = _Client(storage)
          ..previewResponse = {'status': 'unsupported', 'reason': entry.key};
        final w = WorkspaceController(client, attachmentImageStore: cache);
        var downloads = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: AttachmentPreviewDialog(
              controller: w,
              metadata: const {
                'id': 'refused',
                'channelId': 'c1',
                'filename': 'report.xlsx',
              },
              channelId: 'c1',
              authorized: () => true,
              onClose: () {},
              onDownload: () async {
                downloads++;
              },
            ),
          ),
        );
        await settle(
          tester,
          () => find.text(entry.value).evaluate().isNotEmpty,
        );
        expect(find.text(entry.value), findsOneWidget);
        expect(
          raftChinese[entry.value],
          isNotNull,
          reason: 'failure copy is available in Chinese',
        );
        expect(
          find.byKey(const ValueKey('preview-open-system')),
          findsOneWidget,
          reason: 'another app can still open it',
        );
        final download = find.byKey(
          const ValueKey('attachment-preview-download'),
        );
        expect(download, findsOneWidget);
        await tester.tap(download);
        expect(downloads, 1);
        expect(
          find.byKey(const ValueKey('preview-download')),
          findsOneWidget,
          reason: 'the panel offers Download as well',
        );
        expect(
          await cache.entryCount(),
          0,
          reason: 'a refusal must never be cached as a document',
        );
        expect(
          storage.total,
          0,
          reason: 'does not silently download the original',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
        w.dispose();
        await client.dispose();
      });
    }

    testWidgets('a document preview opens from the cache and is stored', (
      tester,
    ) async {
      final client = _Client(storage);
      final w = WorkspaceController(client, attachmentImageStore: cache);
      const metadata = {'id': 'n', 'channelId': 'c1', 'filename': 'note.txt'};
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: AttachmentPreviewDialog(
              controller: w,
              metadata: metadata,
              channelId: 'c1',
              authorized: () => true,
              onClose: () {},
              onDownload: () async {},
            ),
          ),
        );
        await settle(
          tester,
          () => find.text('private document').evaluate().isNotEmpty,
        );
        expect(find.text('private document'), findsOneWidget);
      }

      int previews() =>
          client.paths.where((p) => p.endsWith('/preview')).length;
      await open();
      expect(previews(), 1);
      // The store finishes in the background.
      int? stored = 0;
      for (var i = 0; i < 80 && stored == 0; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await tester.pump();
        stored = await tester.runAsync(cache.entryCount);
      }
      expect(stored, 1);
      await tester.pumpWidget(const SizedBox());
      await open();
      expect(previews(), 1, reason: 'the second open reads the stored copy');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      w.dispose();
      await client.dispose();
    });
  });
}

/// Records the path of each rendered file.
class _Pdf extends NativePdfRenderer {
  _Pdf(this.pages);
  final List<String> pages;
  @override
  Future<NativePdfPage> render(
    File file,
    int page, {
    required CancelToken cancel,
    required bool Function() authorized,
  }) async {
    pages.add(file.path);
    return NativePdfPage(
      Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      1,
    );
  }
}
