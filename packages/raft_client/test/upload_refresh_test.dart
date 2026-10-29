import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Adapter implements HttpClientAdapter {
  final uploadBodies = <String>[];
  final directoryServers = <String>[];
  Completer<void>? refreshGate;
  bool refreshStarted = false;
  ResponseBody json(Map<String, dynamic> value, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/login') {
      return json({
        'accessToken': 'fixture-old',
        'refreshToken': 'fixture-rotate',
        'user': {'id': 'fixture'},
      });
    }
    if (options.path == '/auth/refresh') {
      refreshStarted = true;
      await refreshGate?.future;
      return json({
        'accessToken': 'fixture-fresh',
        'refreshToken': 'fixture-new',
      });
    }
    if (options.path == '/channels') {
      directoryServers.add(options.headers['X-Server-Id'] as String);
      return options.headers['Authorization'] == 'Bearer fixture-old'
          ? json({'error': 'expired'}, 401)
          : json({'ok': true});
    }
    if (options.path == '/attachments/upload') {
      final bytes = await stream!.fold<List<int>>(
        [],
        (all, next) => all..addAll(next),
      );
      uploadBodies.add(utf8.decode(bytes));
      if (options.headers['Authorization'] == 'Bearer fixture-old') {
        return json({'error': 'expired'}, 401);
      }
      return json({
        'attachments': [
          {'id': 'uploaded'},
        ],
      });
    }
    return json({});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('picker directory server is preserved through auth retry and active workspace changes', () async {
    final adapter = _Adapter()..refreshGate = Completer<void>();
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = adapter,
    );
    await client.login('fixture', 'fixture');
    client.selectServer('active');
    final pending = client.getForServer('picker', '/channels');
    for (var i = 0; i < 100 && !adapter.refreshStarted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(adapter.refreshStarted, true);
    client.selectServer('another');
    adapter.refreshGate!.complete();
    expect(await pending, {'ok': true});
    expect(adapter.directoryServers, ['picker', 'picker']);
    expect(client.serverId, 'another');
    await client.dispose();
  });

  test('stream upload reopens the private file after refresh without buffering in the client', () async {
    final adapter = _Adapter();
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = adapter,
    );
    await client.login('fixture', 'fixture');
    client.selectServer('server');
    var opens = 0;
    final bytes = utf8.encode('local queued attachment');
    final result = await client.uploadStream(
      'channel',
      () {
        opens++;
        return Stream.value(bytes);
      },
      bytes.length,
      'shared.txt',
    );
    expect(result.single['id'], 'uploaded');
    expect(opens, 2);
    expect(adapter.uploadBodies, hasLength(2));
    expect(
      adapter.uploadBodies.every((b) => b.contains('local queued attachment')),
      true,
    );
    await client.dispose();
  });

  test('the file part carries the browser MIME type of the picked file, so the server can tell a picture', () async {
    final adapter = _Adapter();
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = adapter,
    );
    await client.login('fixture', 'fixture');
    client.selectServer('server');
    await client.upload(
      'channel',
      Uint8List.fromList(utf8.encode('png bytes')),
      'screen.png',
      mimeType: 'image/png',
    );
    await client.upload(
      'channel',
      Uint8List.fromList(utf8.encode('plain')),
      'noext',
    );
    final typed = adapter.uploadBodies.first.toLowerCase();
    expect(typed, contains('content-type: image/png'));
    final untyped = adapter.uploadBodies.last.toLowerCase();
    expect(untyped, contains('content-type: application/octet-stream'));
    await client.dispose();
  });

  test('an expired login retries a fresh multipart body with the original selected filename and bytes', () async {
    final adapter = _Adapter();
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = adapter,
    );
    await client.login('fixture', 'fixture');
    client.selectServer('server');
    final result = await client.upload(
      'channel',
      Uint8List.fromList(utf8.encode('native upload 中文 日本語')),
      '日本語.txt',
    );
    expect(result.single['id'], 'uploaded');
    expect(adapter.uploadBodies, hasLength(2));
    for (final body in adapter.uploadBodies) {
      expect(body, contains('filename="日本語.txt"'));
      expect(body, contains('native upload 中文 日本語'));
      expect(body, contains('channel'));
    }
    await client.dispose();
  });
  test(
    'cancel during authentication refresh never starts the retry upload',
    () async {
      final adapter = _Adapter()..refreshGate = Completer<void>();
      final client = RaftClient(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
      await client.login('fixture', 'fixture');
      client.selectServer('server');
      final cancel = UploadCancellation();
      final pending = client.upload(
        'channel',
        Uint8List.fromList([1, 2]),
        'cancel.bin',
        cancellation: cancel,
      );
      final rejected = expectLater(pending, throwsA(isA<RaftApiException>()));
      for (var i = 0; i < 100 && !adapter.refreshStarted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(adapter.refreshStarted, true);
      cancel.cancel();
      adapter.refreshGate!.complete();
      await rejected;
      expect(adapter.uploadBodies, hasLength(1));
      await client.dispose();
    },
  );
}
