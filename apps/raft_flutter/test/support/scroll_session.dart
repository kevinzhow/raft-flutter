import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_image_store.dart';
import 'package:raft_flutter/data/attachment_url_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/inline_attachment_media.dart';
import 'package:raft_flutter/platform/attachment_http.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake Raft server + fake storage host for scripted-session tests. Every
/// request goes through [RequestMeter], whose clock is the test's fake clock.
class FakeServer implements HttpClientAdapter {
  FakeServer(this.now, {DateTime Function()? signClock})
    : signClock = signClock ?? now;
  final DateTime Function() now;

  /// The clock URL signatures are issued against: the same clock the URL cache
  /// reads (the real one, when the app builds its own cache).
  final DateTime Function() signClock;
  final Map<String, FutureOr<dynamic> Function(RequestOptions)> routes = {};
  final List<(RegExp, FutureOr<dynamic> Function(RequestOptions))> patterns = [];
  final misses = <String, int>{};

  /// Per-limiter request budget (requests per window) the fake server
  /// enforces: beyond it the answer is a real-shaped 429.
  final Map<String, List<DateTime>> hits = {};
  var enforce = true;
  final rateLimited = <String, int>{};

  String stamp(DateTime t) =>
      '${t.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';

  String signed(String base) =>
      '$base?X-Amz-Date=${stamp(signClock())}&X-Amz-Expires=300&X-Amz-Signature=sig';

  /// The server's limiters (real-shaped 429) or null when [o] is admitted.
  ResponseBody? admit(RequestOptions o) {
    final apiPath = o.uri.path.startsWith('/api/')
        ? o.uri.path.substring(4)
        : o.path;
    if (!enforce) return null;
    for (final limit in ServerRateLimits.forRequest(o.method, apiPath)) {
      final list = hits.putIfAbsent(limit.id, () => []);
      final t = now();
      list.removeWhere((x) => t.difference(x) >= limit.window);
      if (list.length >= limit.max) {
        rateLimited.update(limit.id, (n) => n + 1, ifAbsent: () => 1);
        final reset = limit.window - t.difference(list.first);
        return ResponseBody.fromString(
          jsonEncode({'error': 'Too many requests'}),
          429,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
            'retry-after': ['${reset.inSeconds + 1}'],
            'ratelimit-limit': ['${limit.max}'],
            'ratelimit-remaining': ['0'],
            'ratelimit-reset': ['${reset.inSeconds + 1}'],
          },
        );
      }
      list.add(t);
    }
    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    final limited = admit(o);
    if (limited != null) return limited;
    final key = '${o.method} ${o.path}';
    var route = routes[key];
    if (route == null) {
      for (final (pattern, handler) in patterns) {
        if (pattern.hasMatch(key)) {
          route = handler;
          break;
        }
      }
    }
    if (route == null) {
      misses.update(key, (n) => n + 1, ifAbsent: () => 1);
    }
    final body = route == null ? {'error': 'Unexpected endpoint'} : await route(o);
    return ResponseBody.fromString(
      jsonEncode(body),
      route == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Answers every storage URL with a tiny PNG (or a few bytes for media).
class FakeStorage implements HttpClientAdapter {
  FakeStorage(this.png, [this.server]);
  final Uint8List png;

  /// Set when the Raft server itself streams attachment bytes (local storage):
  /// those requests are counted by the server's limiters.
  final FakeServer? server;
  var bytesServed = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    if (o.uri.host == 'example.invalid') {
      final limited = server?.admit(o);
      if (limited != null) return limited;
    }
    final media = o.uri.path.contains('/media/') || o.uri.path.contains('/vid-');
    final bytes = media ? Uint8List.fromList(List.filled(2048, 7)) : png;
    bytesServed += bytes.length;
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: [media ? 'video/mp4' : 'image/png'],
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<Uint8List> tinyPng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 64, 48),
    ui.Paint()..color = const ui.Color(0xff3366cc),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 48);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// A history of [count] messages mixing the attachment kinds a busy channel
/// has: thumbnailed images (1-3 per message), images without a thumbnail,
/// videos, audio, documents and plain files.
List<Map<String, dynamic>> attachmentHistory(
  FakeServer server, {
  int count = 160,
  String channel = 'c1',
  bool local = false,
}) {
  Map<String, dynamic> image(String id, int n, {bool thumbnail = true}) => {
    'id': id,
    'channelId': channel,
    'filename': 'shot-$n.png',
    'mimeType': 'image/png',
    'width': 800,
    'height': 600,
    'sizeBytes': 90000,
    if (thumbnail)
      'thumbnailUrl': local
          ? 'https://example.invalid/api/attachments/$id/thumbnail?token=t&serverId=s1'
          : server.signed('https://storage.invalid/t/$id.webp'),
  };
  return [
    for (var i = 0; i < count; i++)
      {
        'id': 'm$i',
        'channelId': channel,
        'seq': '${i + 1}',
        'senderId': 'alice',
        'senderType': 'user',
        'content': 'Message $i',
        'createdAt': DateTime.utc(2026, 10, 1).add(Duration(minutes: i)).toIso8601String(),
        'attachments': switch (i % 8) {
          0 || 1 => [for (var a = 0; a < 1 + i % 3; a++) image('img-$i-$a', i)],
          2 => [image('raw-$i', i, thumbnail: false)],
          3 => [
            {
              'id': 'vid-$i',
              'channelId': channel,
              'filename': 'clip-$i.mp4',
              'mimeType': 'video/mp4',
              'sizeBytes': 2048,
            },
          ],
          4 => [
            {
              'id': 'doc-$i',
              'channelId': channel,
              'filename': 'report-$i.pdf',
              'mimeType': 'application/pdf',
              'sizeBytes': 240000,
            },
          ],
          5 => [
            {
              'id': 'zip-$i',
              'channelId': channel,
              'filename': 'logs-$i.zip',
              'mimeType': 'application/zip',
              'sizeBytes': 1800000,
            },
          ],
          _ => <Map<String, dynamic>>[],
        },
      },
  ];
}

/// Installs the attachment routes of [rows] on [server].
void installAttachmentRoutes(
  FakeServer server,
  List<Map<String, dynamic>> rows, {
  bool local = false,
}) {
  final byId = <String, Map<String, dynamic>>{
    for (final row in rows)
      for (final a in (row['attachments'] as List).cast<Map<String, dynamic>>()) a['id']: a,
  };
  String urlFor(String id) => local
      ? 'https://example.invalid/api/attachments/$id?token=t&serverId=s1&disposition=inline'
      : server.signed(
          'https://storage.invalid/${id.startsWith('vid') ? 'media' : 'o'}/$id',
        );
  server.routes['POST /attachments/urls'] = (o) {
    final ids = ((o.data as Map)['attachmentIds'] as List).cast<String>();
    return {
      'urls': [
        for (final id in ids)
          if (byId.containsKey(id)) {'id': id, 'url': urlFor(id), 'expiresAt': null},
      ],
    };
  };
  server.patterns.add((
    RegExp(r'^GET /attachments/[^/]+/url$'),
    (o) {
      final id = o.path.split('/')[2];
      return {
        'url': urlFor(id),
        'expiresAt': local
            ? null
            : server.signClock().add(const Duration(seconds: 300)).toIso8601String(),
      };
    },
  ));
}

/// The persistent image-bytes store (the app installs a disk cache), in memory.
class MemoryImageStore implements AttachmentImageByteStore {
  final entries = <String, Uint8List>{};
  String _k(AttachmentImageStoreKey k) => '${k.identity}|${k.channelId}|${k.entry}';
  @override
  Future<Uint8List?> read(AttachmentImageStoreKey key) async => entries[_k(key)];
  @override
  Future<void> write(AttachmentImageStoreKey key, Uint8List bytes) async =>
      entries[_k(key)] = bytes;
  @override
  Future<void> remove(AttachmentImageStoreKey key) async =>
      entries.remove(_k(key));
  @override
  Future<void> purgeChannel(String identity, String channelId) async {}
  @override
  Future<void> purgeIdentity(String identity) async {}
}

/// Stands in for the platform player of inline media: opening it reads the
/// streamed URL once through the (metered) storage client, like the first
/// ranged request of ExoPlayer or AVPlayer does.
class FakeMediaFiles {
  FakeMediaFiles(this.dir);
  final Directory dir;
  var loads = 0;
  AttachmentPlayer player() => _StreamPlayer(this);
}

class _StreamPlayer implements AttachmentPlayer {
  _StreamPlayer(this.owner);
  final FakeMediaFiles owner;
  final _events = StreamController<AttachmentPlayback>.broadcast();
  @override
  Stream<AttachmentPlayback> get changes => _events.stream;
  @override
  AttachmentPlayback get playback => const AttachmentPlayback();
  @override
  bool get usesPlatformView => false;
  @override
  Widget video() => const SizedBox.shrink();
  @override
  Future<void> open(AttachmentSource source) async {
    owner.loads++;
    await AttachmentHttp.shared.getUri<List<int>>(
      source.url!,
      options: Options(responseType: ResponseType.bytes),
    );
  }

  @override
  Future<void> toggle() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration value) async {}
  @override
  Future<void> volume(double value) async {}
  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

class ScrollSession {
  ScrollSession(
    this.tester,
    this.w,
    this.server,
    this.storage,
    this.meter,
    this.cache,
    this.media,
  );
  final WidgetTester tester;
  final WorkspaceController w;
  final FakeServer server;
  final FakeStorage storage;
  final RequestMeter meter;
  final AttachmentUrlCache cache;
  final FakeMediaFiles media;

  ScrollController get viewport =>
      (tester.state(find.byType(RaftChatView).first) as dynamic).viewport
          as ScrollController;

  /// One user "pass": scrolls [pixels] toward history over [seconds], at
  /// 60 frames per second, then the same distance back.
  Future<void> back(double pixels, int seconds) => _sweep(-pixels, seconds);
  Future<void> forth(double pixels, int seconds) => _sweep(pixels, seconds);

  Future<void> _sweep(double pixels, int seconds) async {
    final frames = seconds * 20;
    final step = pixels / frames;
    for (var i = 0; i < frames; i++) {
      final v = viewport;
      v.jumpTo((v.offset + step).clamp(v.position.minScrollExtent, v.position.maxScrollExtent));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> idle(Duration d) async {
    for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

/// Mounts a chat of [attachmentHistory] on a fake server and runs [body].
Future<void> withScrollSession(
  WidgetTester tester,
  Future<void> Function(ScrollSession session) body, {
  int count = 160,
  bool desktop = true,
  bool local = false,
  bool withGovernor = true,
  AttachmentUrlCache Function(DateTime Function() now)? makeCache,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = desktop ? const Size(1280, 800) : const Size(420, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  DateTime now() => tester.binding.clock.now();
  final meter = RequestMeter.instance
    ..reset()
    ..enable(clock: now);
  addTearDown(() {
    meter
      ..disable()
      ..reset();
    meter.clock = DateTime.now;
  });
  final png = (await tester.runAsync(tinyPng))!;
  final server = FakeServer(now);
  late final FakeStorage storage;
  storage = FakeStorage(png, server);
  final storageDio = Dio()
    ..httpClientAdapter = storage
    ..interceptors.add(meter.interceptor());
  AttachmentHttp.debugReplace(storageDio);
  addTearDown(() => AttachmentHttp.debugReplace(null));
  final mediaDir = Directory.systemTemp.createTempSync('scroll-session');
  final media = FakeMediaFiles(mediaDir);
  InlineMediaTestHooks.playerFactory = media.player;
  addTearDown(() {
    InlineMediaTestHooks.playerFactory = null;
    if (mediaDir.existsSync()) mediaDir.deleteSync(recursive: true);
  });
  server.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final rows = attachmentHistory(server, count: count, local: local);
  installAttachmentRoutes(server, rows, local: local);
  server.routes['GET /messages/channel/c1'] = (_) => {
    'messages': rows,
    'hasMore': false,
  };
  server.routes['POST /channels/c1/read'] = (_) => {};
  // Created and signed in outside the fake-async zone, like the product.
  final client = (await tester.runAsync(() async {
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = server,
    );
    await client.login('fixture', 'fixture');
    return client;
  }))!;
  client.selectServer('s1');
  // The product's transfer client shares the API client's limiter view.
  if (withGovernor) {
    storageDio.interceptors.add(RateLimitInterceptor(client.governor, storageDio));
  }
  final cache = makeCache?.call(now) ?? AttachmentUrlCache(now: now);
  final w = WorkspaceController(
    client,
    attachmentUrls: cache,
    attachmentImageStore: MemoryImageStore(),
  );
  addTearDown(w.dispose);
  w.server = RaftRecord({'id': 's1', 'role': 'member'});
  w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
  w.channels = [w.channel!];
  w.messageDomain.ledger.switchServer('s1');
  w.messageDomain.ledger.ingest(rows, expectedGeneration: w.messageDomain.ledger.generation);
  w.messageDomain.visibleIds['c1'] = rows.map((r) => r['id'] as String).toSet();
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(body: RaftChatView(controller: w)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  meter.reset();
  await body(ScrollSession(tester, w, server, storage, meter, cache, media));
  await tester.pumpWidget(const SizedBox());
  // Let anything the limiter was still pacing run out.
  for (var i = 0; i < 70; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  try {
    (w as dynamic).playerSessions.clear();
  } on NoSuchMethodError {
    // The baseline has no player sessions.
  }
  await tester.pump(const Duration(seconds: 1));
}
