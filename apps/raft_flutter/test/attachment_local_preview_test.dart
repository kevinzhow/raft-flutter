// Kevin's rule: a user who opens an attachment wants to read it; the server's
// preview limits are not their problem. When the preview service answers
// HTTP 200 `{"status":"unsupported","reason":...}`, the app reads the original
// itself (text, Markdown, CSV), shows the first part of a very large file with
// a notice, hands formats it cannot draw to the system app, and only as the
// last resort says specifically why nothing could be shown.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_disk_cache.dart';
import 'package:raft_flutter/data/attachment_image_store.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/platform/attachment_preview_files.dart';

/// The real cache and HTTP client, run in the root zone (the fake-async zone
/// of a widget test never delivers socket events).
class _RealFiles extends AttachmentPreviewFiles {
  _RealFiles() : super(dio: Dio());
  @override
  Future<SharedFileLease?> loadCached({
    required AttachmentDiskCache? cache,
    required AttachmentImageStoreKey key,
    required Future<String> Function() resolveUrl,
    Future<String> Function()? refreshUrl,
    required String filename,
    int? expectedBytes,
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int received, int total)? onProgress,
  }) {
    final result = Completer<SharedFileLease?>();
    Zone.root.run(() {
      super
          .loadCached(
            cache: cache,
            key: key,
            resolveUrl: resolveUrl,
            refreshUrl: refreshUrl,
            filename: filename,
            expectedBytes: expectedBytes,
            cancel: cancel,
            authorized: authorized,
            onProgress: onProgress,
          )
          .then(result.complete, onError: result.completeError);
    });
    return result.future;
  }
}

class _Storage {
  _Storage._(this.server);
  final HttpServer server;
  int hits = 0;
  int status = 200;
  Uint8List body = Uint8List(0);

  static Future<_Storage> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final storage = _Storage._(server);
    server.listen((request) async {
      storage.hits++;
      request.response.statusCode = storage.status;
      request.response.add(storage.status == 200 ? storage.body : const []);
      await request.response.close();
    });
    return storage;
  }

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
  Map<String, dynamic> refusal = {
    'status': 'unsupported',
    'reason': 'too_large',
  };
  Object? urlFailure;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    paths.add(path);
    if (path.endsWith('/preview')) return refusal;
    if (urlFailure != null) throw urlFailure!;
    return {'url': 'http://127.0.0.1:${storage.server.port}/blob/file'};
  }

  int get previews => paths.where((p) => p.endsWith('/preview')).length;
}

String _markdown(int bytes) {
  final out = StringBuffer('# Quarterly report\n\n');
  var i = 0;
  while (out.length < bytes) {
    i++;
    out.write(
      '## Section $i\n\nParagraph $i of the report with some **bold** words '
      'and `code`, long enough to look like prose written by a person.\n\n'
      '- item one of $i\n- item two of $i\n\n',
    );
  }
  return out.toString();
}

void main() {
  late Directory root;
  late _Storage storage;
  late AttachmentDiskCache cache;
  setUpAll(() => HttpOverrides.global = null);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('raft-local-preview');
    storage = await _Storage.start();
    cache = AttachmentDiskCache(() async => root);
  });
  tearDown(() async {
    await storage.close();
    await root.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 600 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }
  }

  Future<(WorkspaceController, _Client)> open(
    WidgetTester tester,
    Map<String, dynamic> metadata, {
    Future<void> Function(String, String)? opener,
    void Function()? onDownload,
  }) async {
    final client = _Client(storage);
    final w = WorkspaceController(client, attachmentImageStore: cache);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: AttachmentPreviewDialog(
          controller: w,
          metadata: {'id': 'a', 'channelId': 'c1', ...metadata},
          channelId: 'c1',
          authorized: () => true,
          onClose: () {},
          onDownload: () async => onDownload?.call(),
          opener: opener,
          files: _RealFiles(),
        ),
      ),
    );
    return (w, client);
  }

  Future<void> close(WidgetTester tester, WorkspaceController w) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    w.dispose();
  }

  testWidgets('a 184 KB Markdown the server calls too large is rendered', (
    tester,
  ) async {
    final text = _markdown(184 * 1024);
    storage.body = Uint8List.fromList(utf8.encode(text));
    final (w, client) = await open(tester, {
      'filename': 'report.md',
      'sizeBytes': storage.body.length,
    });
    await settle(
      tester,
      () => find.text('Quarterly report').evaluate().isNotEmpty,
    );
    expect(find.text('Quarterly report'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('preview-unavailable-reason')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('preview-notice')), findsNothing);
    expect(client.previews, 1);
    expect(storage.hits, 1);
    // The lazy layout: far-away blocks are not built.
    expect(find.textContaining('Paragraph 900 of the report'), findsNothing);
    // Stored like a server preview: the second open needs nothing.
    int? stored = 0;
    for (var i = 0; i < 80 && stored != 2; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      stored = await tester.runAsync(cache.entryCount);
    }
    await close(tester, w);
    final (w2, client2) = await open(tester, {
      'filename': 'report.md',
      'sizeBytes': storage.body.length,
    });
    await settle(
      tester,
      () => find.text('Quarterly report').evaluate().isNotEmpty,
    );
    expect(find.text('Quarterly report'), findsOneWidget);
    expect(client2.paths, isEmpty, reason: 'no request on the second open');
    expect(storage.hits, 1);
    await close(tester, w2);
  });

  testWidgets('a huge text file shows its first part, a notice and a way on', (
    tester,
  ) async {
    final lines = StringBuffer();
    for (var i = 1; lines.length < 3 * 1024 * 1024; i++) {
      lines.writeln('line $i of a very long log file with some text');
    }
    storage.body = Uint8List.fromList(utf8.encode(lines.toString()));
    final opened = <(String, String)>[];
    var downloads = 0;
    final (w, _) = await open(
      tester,
      {'filename': 'build.log', 'sizeBytes': storage.body.length},
      opener: (path, mime) async => opened.add((path, mime)),
      onDownload: () => downloads++,
    );
    await settle(
      tester,
      () => find.textContaining('line 1 of').evaluate().isNotEmpty,
    );
    expect(
      find.text('line 1 of a very long log file with some text'),
      findsOneWidget,
    );
    final notice = find.byKey(const ValueKey('preview-notice'));
    expect(notice, findsOneWidget);
    expect(
      find.textContaining('Large file: showing the first '),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('lazy-text-lines')), findsOneWidget);
    // Far lines are not built.
    expect(find.textContaining('line 40000 of'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('preview-open-system')));
    await tester.pump();
    await settle(tester, () => opened.isNotEmpty);
    expect(opened, hasLength(1));
    expect(opened.single.$1, endsWith('build.log'));
    expect(
      File(opened.single.$1).lengthSync(),
      storage.body.length,
      reason: 'the whole original is opened, not the shown part',
    );
    await tester.tap(find.byKey(const ValueKey('preview-download')));
    expect(downloads, 1);
    await close(tester, w);
  });

  testWidgets('a CSV over the server limit is a table of its rows', (
    tester,
  ) async {
    final csv = StringBuffer('id,name,amount\n');
    for (var i = 1; i <= 5000; i++) {
      csv.writeln('$i,"Name, $i",${i * 3}');
    }
    storage.body = Uint8List.fromList(utf8.encode(csv.toString()));
    final (w, _) = await open(tester, {
      'filename': 'sales.csv',
      'sizeBytes': storage.body.length,
    });
    await settle(tester, () => find.text('amount').evaluate().isNotEmpty);
    expect(find.text('amount'), findsOneWidget);
    expect(find.text('Name, 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('lazy-csv-rows')), findsOneWidget);
    expect(find.text('Name, 4000'), findsNothing);
    await close(tester, w);
  });

  testWidgets('an unreadable text file says why and offers another app', (
    tester,
  ) async {
    storage.body = Uint8List.fromList([0, 1, 2, 3, 0xff, 0xfe, 0, 0]);
    final opened = <String>[];
    final (w, client) = await open(tester, {
      'filename': 'notes.txt',
      'sizeBytes': 8,
    }, opener: (path, mime) async => opened.add(path));
    client.refusal = {'status': 'unsupported', 'reason': 'unreadable'};
    await settle(
      tester,
      () => find
          .byKey(const ValueKey('preview-unavailable-reason'))
          .evaluate()
          .isNotEmpty,
    );
    expect(
      find.text(
        'The file could not be read and may be damaged. Download the original file to view it.',
      ),
      findsOneWidget,
    );
    expect(storage.hits, 0, reason: 'nothing is fetched until the user asks');
    await tester.tap(find.byKey(const ValueKey('preview-open-system')));
    await settle(tester, () => opened.isNotEmpty);
    expect(opened.single, endsWith('notes.txt'));
    await close(tester, w);
  });

  testWidgets('a binary file labelled text is unreadable after the fetch', (
    tester,
  ) async {
    storage.body = Uint8List.fromList(List.generate(4000, (i) => i % 7));
    final client = _Client(storage)
      ..refusal = {'status': 'unsupported', 'reason': 'unsupported'};
    final w = WorkspaceController(client, attachmentImageStore: cache);
    await tester.pumpWidget(
      MaterialApp(
        home: AttachmentPreviewDialog(
          controller: w,
          metadata: const {'id': 'a', 'channelId': 'c1', 'filename': 'x.txt'},
          channelId: 'c1',
          authorized: () => true,
          onClose: () {},
          onDownload: () async {},
          files: _RealFiles(),
        ),
      ),
    );
    await settle(
      tester,
      () => find
          .byKey(const ValueKey('preview-unavailable-reason'))
          .evaluate()
          .isNotEmpty,
    );
    expect(
      find.byKey(const ValueKey('preview-unavailable-reason')),
      findsOneWidget,
    );
    expect(storage.hits, 1);
    await close(tester, w);
  });

  testWidgets('a spreadsheet the server declines opens in the system app', (
    tester,
  ) async {
    storage.body = Uint8List.fromList(utf8.encode('PK-not-really'));
    final opened = <(String, String)>[];
    final (w, _) = await open(tester, {
      'filename': 'budget.xlsx',
      'mimeType':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'sizeBytes': storage.body.length,
    }, opener: (path, mime) async => opened.add((path, mime)));
    await settle(
      tester,
      () => find
          .byKey(const ValueKey('preview-open-system'))
          .evaluate()
          .isNotEmpty,
    );
    expect(
      find.text(
        'This file exceeds the server preview size limit. Download the original file to view it.',
      ),
      findsOneWidget,
    );
    expect(storage.hits, 0);
    await tester.tap(find.byKey(const ValueKey('preview-open-system')));
    await settle(tester, () => opened.isNotEmpty);
    expect(opened, hasLength(1));
    expect(opened.single.$1, endsWith('budget.xlsx'));
    expect(
      opened.single.$2,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    expect(File(opened.single.$1).readAsBytesSync(), storage.body);
    expect(storage.hits, 1);
    await close(tester, w);
  });

  group('the download itself fails', () {
    for (final (status, text) in [
      (404, 'This file is no longer available.'),
      (403, 'This link has expired or access was denied. Try again.'),
      (500, 'The file could not be downloaded. Try again.'),
    ]) {
      testWidgets('HTTP $status: the reason, then Retry works', (tester) async {
        storage
          ..body = Uint8List.fromList(utf8.encode('# Title\n\nbody text'))
          ..status = status;
        final (w, _) = await open(tester, {
          'filename': 'report.md',
          'sizeBytes': 18,
        });
        await settle(tester, () => find.text(text).evaluate().isNotEmpty);
        expect(find.text(text), findsOneWidget);
        expect(find.byKey(const ValueKey('preview-download')), findsOneWidget);
        storage.status = 200;
        await tester.tap(find.byKey(const ValueKey('preview-retry')));
        await settle(tester, () => find.text('Title').evaluate().isNotEmpty);
        expect(find.text('Title'), findsOneWidget);
        await close(tester, w);
      });
    }

    testWidgets('no route to the host: says the server cannot be reached', (
      tester,
    ) async {
      final port = (await tester.runAsync(() async {
        final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final port = dead.port;
        await dead.close(force: true);
        return port;
      }))!;
      // Point the signed URL at the closed port.
      final offline = _OfflineClient(port);
      final wo = WorkspaceController(offline, attachmentImageStore: cache);
      await tester.pumpWidget(
        MaterialApp(
          home: AttachmentPreviewDialog(
            controller: wo,
            metadata: const {'id': 'a', 'channelId': 'c1', 'filename': 'r.md'},
            channelId: 'c1',
            authorized: () => true,
            onClose: () {},
            onDownload: () async {},
            files: _RealFiles(),
          ),
        ),
      );
      const text =
          'Cannot reach the server. Check your connection and try again.';
      await settle(tester, () => find.text(text).evaluate().isNotEmpty);
      expect(find.text(text), findsOneWidget);
      await close(tester, wo);
    });
  });
}

class _OfflineClient extends RaftClient {
  _OfflineClient(this.port)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final int port;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      path.endsWith('/preview')
      ? {'status': 'unsupported', 'reason': 'too_large'}
      : {'url': 'http://127.0.0.1:$port/blob/file'};
}
