// Attachment loading progress (Option A): a thin bar along the bottom edge of
// the image viewer / preview and a "1.2 / 3.4 MB" chip, fed by a real dio
// transfer (fake adapter streaming chunks) through the shared, throttled
// repository. List tiles never show it: while their image loads they show the
// neutral placeholder only, like Web's tinted image box (no "Connecting…").
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/media_image_page.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/attachment_preview_files.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';

const mib = 1024 * 1024;

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
);

class FakeClient extends RaftClient {
  FakeClient()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  int urlReads = 0;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    urlReads++;
    return {'url': 'https://storage.example.invalid/original'};
  }
}

/// One scripted download: chunks are pushed by the test, like a slow network.
class FakeRoute {
  FakeRoute({this.length, this.immediate});

  /// Content-Length sent with the response; null sends none (dio total -1).
  final int? length;

  /// Bytes returned at once (a fast thumbnail).
  final Uint8List? immediate;
  int requests = 0;
  bool cancelled = false;
  bool failNext = false;
  StreamController<Uint8List>? stream;
  void chunk(int bytes) => stream!.add(Uint8List(bytes));
  void finish() => stream!.close();
}

class FakeServer implements HttpClientAdapter {
  final routes = <String, FakeRoute>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final route = routes[options.uri.path]!;
    route.requests++;
    if (route.failNext) {
      route.failNext = false;
      return ResponseBody.fromString('nope', 500);
    }
    if (route.immediate != null) {
      return ResponseBody.fromBytes(
        route.immediate!,
        200,
        headers: {
          'content-length': ['${route.immediate!.length}'],
        },
      );
    }
    final stream = route.stream = StreamController<Uint8List>();
    cancelFuture?.then((_) {
      route.cancelled = true;
      if (!stream.isClosed) stream.close();
    });
    return ResponseBody(
      stream.stream,
      200,
      headers: {
        if (route.length != null) 'content-length': ['${route.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeStore implements AttachmentImageByteStore {
  final entries = <String, Uint8List>{};
  int reads = 0;
  String _id(AttachmentImageStoreKey key) =>
      '${key.identity}|${key.channelId}|${key.entry}';
  @override
  Future<Uint8List?> read(AttachmentImageStoreKey key) async {
    reads++;
    return entries[_id(key)];
  }

  @override
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes) async =>
      entries[_id(key)] = bytes;
  @override
  Future<void> remove(AttachmentImageStoreKey key) async =>
      entries.remove(_id(key));
  @override
  Future<void> purgeChannel(String identity, String channelId) async =>
      entries.removeWhere((k, _) => k.startsWith('$identity|$channelId|'));
  @override
  Future<void> purgeIdentity(String identity) async =>
      entries.removeWhere((k, _) => k.startsWith('$identity|'));
}

class Mounted {
  Mounted(this.client, this.w, this.server, this.store);
  final FakeClient client;
  final WorkspaceController w;
  final FakeServer server;
  final FakeStore store;
}

Future<Mounted> mount(
  WidgetTester tester, {
  Map<String, dynamic> metadata = const {},
  FakeServer? server,
  FakeStore? store,
  bool dark = false,
}) async {
  final client = FakeClient()..user = RaftRecord({'id': 'alice'});
  client.selectServer('server');
  final theStore = store ?? FakeStore();
  final w = WorkspaceController(client, attachmentImageStore: theStore)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channel = RaftChannel({'id': 'channel', 'joined': true});
  w.channels = [w.channel!];
  final theServer = server ?? FakeServer();
  final files = AttachmentFiles(dio: Dio()..httpClientAdapter = theServer);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    for (final route in theServer.routes.values) {
      if (route.stream != null && !route.stream!.isClosed) {
        route.stream!.close();
      }
    }
    w.dispose();
    await client.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: AttachmentView(
            controller: w,
            files: files,
            metadata: {
              'id': 'image',
              'filename': 'image.png',
              'mimeType': 'image/png',
              ...metadata,
            },
          ),
        ),
      ),
    ),
  );
  return Mounted(client, w, theServer, theStore);
}

/// Lets the url lookup, store read and request hops run.
Future<void> hop(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

/// Past the 100 ms throttle window so the newest chunk is published.
Future<void> tick(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 120));

Future<void> decoded(WidgetTester tester) async {
  final dynamic state = tester.state(find.byType(AttachmentView));
  for (var i = 0; i < 100 && state.imageProvider == null; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
  expect(state.imageProvider, isA<ImageProvider>());
}

Finder get bars => find.byType(RaftTransferBar);
double? barValue(WidgetTester tester, [int index = 0]) =>
    tester.widget<RaftTransferBar>(bars.at(index)).value;

void main() {
  testWidgets('timeline: a loading original shows only the placeholder', (
    tester,
  ) async {
    final server = FakeServer()
      ..routes['/original'] = FakeRoute(length: 4 * mib);
    await mount(tester, server: server, metadata: {'sizeBytes': 4 * mib});
    await hop(tester);
    void expectPlaceholderOnly() {
      expect(find.byType(RaftTransferPlaceholder), findsOneWidget);
      expect(bars, findsNothing);
      expect(find.byType(RaftTransferChip), findsNothing);
      expect(find.text('Connecting…'), findsNothing);
      expect(find.textContaining(' MB'), findsNothing);
    }

    // Waiting for the first byte, then while bytes arrive: placeholder only.
    expectPlaceholderOnly();
    final route = server.routes['/original']!;
    expect(route.requests, 1);
    route.chunk(mib);
    await hop(tester);
    await tick(tester);
    expectPlaceholderOnly();
    route.chunk(2 * mib);
    await hop(tester);
    await tick(tester);
    expectPlaceholderOnly();
    // The bytes complete (the fixture is not an image, so decoding fails):
    // the transfer is over and the failed tile offers a retry.
    route.chunk(mib);
    route.finish();
    await hop(tester, 10);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await hop(tester, 4);
    expect(find.text('Download failed · tap to retry'), findsOneWidget);
  });

  testWidgets('a thumbnail loads directly: placeholder only, no URL lookup', (
    tester,
  ) async {
    final server = FakeServer()..routes['/thumb.webp'] = FakeRoute();
    final m = await mount(
      tester,
      server: server,
      metadata: {
        'sizeBytes': 40 * mib,
        'thumbnailUrl': 'https://cdn.example.invalid/thumb.webp',
      },
    );
    await hop(tester);
    server.routes['/thumb.webp']!.chunk(20 * 1024);
    await hop(tester);
    await tick(tester);
    expect(server.routes['/thumb.webp']!.requests, 1);
    expect(m.client.urlReads, 0, reason: 'the thumbnail is public');
    expect(find.byType(RaftTransferPlaceholder), findsOneWidget);
    expect(bars, findsNothing);
    expect(find.text('Connecting…'), findsNothing);
    expect(find.text('20 KB'), findsNothing);
  });

  testWidgets('cache hit: no bar at any point, no request', (tester) async {
    final store = FakeStore();
    // First visit downloads and persists the bytes.
    final server1 = FakeServer()
      ..routes['/original'] = FakeRoute(immediate: png);
    await mount(tester, server: server1, store: store);
    await hop(tester);
    await decoded(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    expect(store.entries, isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    // Second visit (a new controller, so no decoded image is retained).
    final server2 = FakeServer()..routes['/original'] = FakeRoute(length: mib);
    await mount(tester, server: server2, store: store);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 1));
      expect(bars, findsNothing, reason: 'frame $i');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
    }
    await decoded(tester);
    expect(bars, findsNothing);
    expect(server2.routes['/original']!.requests, 0);
  });

  testWidgets('failure shows the retry chip; retry refetches', (tester) async {
    final server = FakeServer()
      ..routes['/original'] = FakeRoute(length: 4 * mib);
    server.routes['/original']!.failNext = true;
    await mount(tester, server: server);
    await hop(tester);
    await tick(tester);
    expect(find.text('Download failed · tap to retry'), findsOneWidget);
    expect(find.byKey(const ValueKey('attachment-retry')), findsOneWidget);
    expect(server.routes['/original']!.requests, 1);
    await tester.tap(find.byKey(const ValueKey('attachment-retry')));
    await hop(tester);
    expect(server.routes['/original']!.requests, 2);
    // The second attempt is live again: connecting, then bytes.
    expect(find.text('Download failed · tap to retry'), findsNothing);
    expect(find.text('Connecting…'), findsNothing);
    expect(find.byType(RaftTransferPlaceholder), findsOneWidget);
    server.routes['/original']!.chunk(mib);
    await hop(tester);
    await tick(tester);
    expect(find.text('1.0 / 4.0 MB'), findsNothing);
    expect(bars, findsNothing);
  });

  testWidgets('viewer opened mid-download shares the timeline download', (
    tester,
  ) async {
    final server = FakeServer()
      ..routes['/original'] = FakeRoute(length: 4 * mib);
    final m = await mount(
      tester,
      server: server,
      metadata: {'sizeBytes': 4 * mib, 'width': 4000, 'height': 3000},
    );
    await hop(tester);
    server.routes['/original']!.chunk(mib);
    await hop(tester);
    await tick(tester);
    await tester.tap(find.byTooltip('Preview image.png'));
    await hop(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Close Preview'), findsOneWidget);
    // One request in total, one url lookup for the original.
    expect(server.routes['/original']!.requests, 1);
    expect(m.client.urlReads, 1);
    // The viewer's bar picked up the numbers already received; the timeline
    // tile behind it still shows nothing but its placeholder.
    expect(bars, findsOneWidget);
    expect(find.text('1.0 / 4.0 MB'), findsOneWidget);
    server.routes['/original']!.chunk(2 * mib);
    await hop(tester);
    await tick(tester);
    expect(find.text('3.0 / 4.0 MB'), findsOneWidget);
    expect(barValue(tester), closeTo(.75, 1e-9));
    // Leaving the viewer does not cancel what the timeline still waits for.
    await tester.tap(find.byTooltip('Close Preview'));
    // The dialog fades out, then the route (and the viewer) is gone.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(server.routes['/original']!.cancelled, isFalse);
    expect(bars, findsNothing);
    expect(find.text('Connecting…'), findsNothing);
  });

  testWidgets(
    'viewer: thumbnail under the bar with an original-size chip; closing cancels',
    (tester) async {
      final server = FakeServer()
        ..routes['/thumb.webp'] = FakeRoute(immediate: png)
        ..routes['/original'] = FakeRoute(length: 4 * mib);
      await mount(
        tester,
        server: server,
        metadata: {
          'sizeBytes': 4 * mib,
          'width': 4000,
          'height': 3000,
          'thumbnailUrl': 'https://cdn.example.invalid/thumb.webp',
        },
      );
      await hop(tester);
      await decoded(tester);
      // The timeline shows the thumbnail without any bar.
      expect(bars, findsNothing);
      await tester.tap(find.byTooltip('Preview image.png'));
      await hop(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Close Preview'), findsOneWidget);
      expect(bars, findsOneWidget);
      expect(find.text('Connecting…'), findsOneWidget);
      server.routes['/original']!.chunk(mib);
      await hop(tester);
      await tick(tester);
      expect(find.text('Original image 1.0 / 4.0 MB'), findsOneWidget);
      expect(barValue(tester), closeTo(.25, 1e-9));
      expect(server.routes['/original']!.cancelled, isFalse);
      // Back out of the viewer: the original download is cancelled.
      await tester.tap(find.byTooltip('Close Preview'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await hop(tester);
      expect(server.routes['/original']!.cancelled, isTrue);
      expect(server.routes['/original']!.requests, 1);
    },
  );

  testWidgets('viewer: a failed original keeps the thumbnail; tap retries', (
    tester,
  ) async {
    final server = FakeServer()
      ..routes['/thumb.webp'] = FakeRoute(immediate: png)
      ..routes['/original'] = FakeRoute(length: 4 * mib);
    server.routes['/original']!.failNext = true;
    await mount(
      tester,
      server: server,
      metadata: {
        'sizeBytes': 4 * mib,
        'width': 4000,
        'height': 3000,
        'thumbnailUrl': 'https://cdn.example.invalid/thumb.webp',
      },
    );
    await hop(tester);
    await decoded(tester);
    await tester.tap(find.byTooltip('Preview image.png'));
    await hop(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(server.routes['/original']!.requests, 1);
    final failed = find.descendant(
      of: find.byType(AttachmentLightboxImage),
      matching: find.text('Download failed · tap to retry'),
    );
    expect(failed, findsOneWidget);
    // The thumbnail is still there under the red bar.
    expect(
      find.descendant(
        of: find.byType(AttachmentLightboxImage),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    await tester.tap(failed);
    await hop(tester);
    expect(server.routes['/original']!.requests, 2);
    expect(failed, findsNothing);
    server.routes['/original']!.chunk(mib);
    await hop(tester);
    // The chip of the new attempt waits out its delay like the first one.
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Original image 1.0 / 4.0 MB'), findsOneWidget);
  });

  testWidgets('viewer without a thumbnail: placeholder in the image aspect', (
    tester,
  ) async {
    final server = FakeServer()
      ..routes['/original'] = FakeRoute(length: 4 * mib);
    await mount(
      tester,
      server: server,
      metadata: {'sizeBytes': 4 * mib, 'width': 4000, 'height': 2000},
    );
    await hop(tester);
    await tester.tap(find.byTooltip('Preview image.png'));
    await hop(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final placeholders = find.descendant(
      of: find.byType(AttachmentLightboxImage),
      matching: find.byType(RaftTransferPlaceholder),
    );
    expect(placeholders, findsOneWidget);
    final box = tester.getSize(placeholders);
    expect(box.width / box.height, closeTo(2, .01));
    // On the dark stage: not the cream / light fill of the timeline.
    expect(tester.widget<RaftTransferPlaceholder>(placeholders).onDark, isTrue);
    server.routes['/original']!.chunk(mib);
    await hop(tester);
    await tick(tester);
    // No thumbnail: the chip carries no "Original image" prefix.
    expect(find.text('1.0 / 4.0 MB'), findsOneWidget);
    expect(find.textContaining('Original image'), findsNothing);
  });

  group('throttle', () {
    testWidgets('a fast download notifies about ten times per second', (
      tester,
    ) async {
      final transfer = AttachmentTransfer();
      var notifications = 0;
      transfer.addListener(() => notifications++);
      // 2000 chunks over two seconds (a gigabit burst).
      for (var i = 1; i <= 2000; i++) {
        transfer.report(i * 1024, 2000 * 1024);
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(notifications, lessThanOrEqualTo(22));
      expect(notifications, greaterThanOrEqualTo(15));
      expect(transfer.value!.received, 2000 * 1024);
      transfer.dispose();
    });

    testWidgets('the first update is immediate; the newest is never lost', (
      tester,
    ) async {
      final transfer = AttachmentTransfer();
      transfer.report(10, 100);
      expect(transfer.value!.received, 10);
      transfer.report(50, 100);
      transfer.report(60, 100);
      expect(transfer.value!.received, 10);
      await tester.pump(const Duration(milliseconds: 100));
      expect(transfer.value!.received, 60);
      // dio's -1 total means unknown.
      transfer.report(70, -1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(transfer.value!.total, isNull);
      transfer.dispose();
    });
  });

  group('file preview', () {
    testWidgets('downloading shows file head, bar and size; Cancel leaves', (
      tester,
    ) async {
      final client = FakeClient();
      final w = WorkspaceController(client);
      final files = _PreviewFiles();
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.linux),
          home: AttachmentPreviewDialog(
            controller: w,
            metadata: const {
              'id': 'a',
              'filename': '2026Q3-report.pdf',
              'mimeType': 'application/pdf',
              'sizeBytes': 2936012,
            },
            authorized: () => true,
            onClose: () => closed++,
            onDownload: () async {},
            files: files,
            page: true,
          ),
        ),
      );
      await hop(tester);
      expect(find.byType(RaftFileTransferPanel), findsOneWidget);
      expect(find.text('2026Q3-report.pdf'), findsWidgets);
      expect(find.text('PDF · 2.8 MB'), findsOneWidget);
      expect(find.text('Connecting…'), findsOneWidget);
      expect(
        tester.widget<RaftTransferBar>(bars).value,
        isNull,
        reason: 'indeterminate until the first chunk',
      );
      files.onProgress!(1800000, 2936012);
      await tick(tester);
      expect(find.text('1.7 / 2.8 MB · 61%'), findsOneWidget);
      expect(tester.widget<RaftTransferBar>(bars).value, closeTo(.613, .001));
      await tester.tap(find.text('Cancel'));
      expect(closed, 1);
      await tester.pumpWidget(const SizedBox());
      // Leaving the preview cancels the transfer.
      expect(files.cancel!.isCancelled, isTrue);
      files.release.complete();
      w.dispose();
      await client.dispose();
    });

    testWidgets('a failed fetch offers Retry, which downloads again', (
      tester,
    ) async {
      final client = FakeClient();
      final w = WorkspaceController(client);
      final files = _PreviewFiles()..failFirst = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.linux),
          home: AttachmentPreviewDialog(
            controller: w,
            metadata: const {
              'id': 'a',
              'filename': 'report.pdf',
              'sizeBytes': 2936012,
            },
            authorized: () => true,
            onClose: () {},
            onDownload: () async {},
            files: files,
            page: true,
          ),
        ),
      );
      await hop(tester);
      expect(files.loads, 1);
      expect(find.text('Download failed · tap to retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await hop(tester);
      expect(files.loads, 2);
      expect(find.text('Download failed · tap to retry'), findsNothing);
      expect(find.text('Connecting…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      files.release.complete();
      w.dispose();
      await client.dispose();
    });
  });
}

class _PreviewFiles extends AttachmentPreviewFiles {
  int loads = 0;
  bool failFirst = false;
  void Function(int, int)? onProgress;
  CancelToken? cancel;
  final release = Completer<void>();
  @override
  Future<SharedFileLease?> load(
    String url,
    String filename, {
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int, int)? onProgress,
  }) async {
    loads++;
    this.cancel = cancel;
    this.onProgress = onProgress;
    if (failFirst && loads == 1) throw const SocketException('offline');
    await release.future;
    return null;
  }
}
