import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

// Real sockets exercise Dio's response timer. A short normal-API timeout keeps
// the regression fast; the upload must outlive it without changing that policy
// for other requests. The separate incident replay uses the real 30s default.
const _normalTimeout = Duration(milliseconds: 250);
const _processingTime = Duration(milliseconds: 750);

class _UploadServer {
  _UploadServer(this.server);
  final HttpServer server;
  final bodies = <String>[];
  final uploadStarted = Completer<void>();
  bool expireFirstUpload = false;
  int refreshes = 0;

  String get origin => 'http://127.0.0.1:${server.port}';

  static Future<_UploadServer> start() async {
    final result = _UploadServer(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    result.server.listen(result.handle);
    return result;
  }

  Future<void> handle(HttpRequest request) async {
    Object response = <String, Object>{};
    final body = await request.fold<List<int>>(
      [],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    switch (request.uri.path) {
      case '/api/auth/login':
        response = {
          'accessToken': 'fixture-old',
          'refreshToken': 'fixture-refresh',
          'user': {'id': 'fixture-user'},
        };
      case '/api/auth/refresh':
        refreshes++;
        response = {
          'accessToken': 'fixture-new',
          'refreshToken': 'fixture-new-refresh',
        };
      case '/api/attachments/upload':
        bodies.add(utf8.decode(body));
        if (!uploadStarted.isCompleted) uploadStarted.complete();
        if (expireFirstUpload && bodies.length == 1) {
          request.response.statusCode = HttpStatus.unauthorized;
          response = {'error': 'expired'};
        } else {
          await Future<void>.delayed(_processingTime);
          response = {
            'attachments': [
              {'id': 'slow-picture', 'filename': 'picture.png'},
            ],
          };
        }
      case '/api/slow-read':
        await Future<void>.delayed(_processingTime);
    }
    try {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    } on SocketException {
      // Expected when the negative-control read times out or a user cancels.
    } on HttpException {
      // The peer may close while the delayed response is being written.
    }
  }
}

void main() {
  late _UploadServer server;
  late RaftClient client;
  late Dio transport;

  setUp(() async {
    server = await _UploadServer.start();
    transport = Dio(BaseOptions(receiveTimeout: _normalTimeout));
    client = RaftClient(
      origin: server.origin,
      sessionStore: MemorySessionStore(),
      transport: transport,
    );
    addTearDown(() async {
      await client.dispose();
      await server.server.close(force: true);
    });
    await client.login('fixture', 'fixture');
    client.selectServer('fixture-server');
  });

  final bytes = Uint8List.fromList(utf8.encode('slow image fixture'));
  Future<List<Map<String, dynamic>>> upload({
    required bool streamed,
    UploadCancellation? cancellation,
  }) => streamed
      ? client.uploadStream(
          'fixture-channel',
          () => Stream.value(bytes),
          bytes.length,
          'picture.png',
          mimeType: 'image/png',
          cancellation: cancellation,
        )
      : client.upload(
          'fixture-channel',
          bytes,
          'picture.png',
          mimeType: 'image/png',
          cancellation: cancellation,
        );

  for (final streamed in [false, true]) {
    final route = streamed ? 'stream' : 'bytes';
    test(
      '$route upload waits for processing beyond the normal API timeout',
      () async {
        final accepted = await upload(streamed: streamed);
        expect(accepted.single['id'], 'slow-picture');
        expect(server.bodies, hasLength(1));
        expect(server.bodies.single, contains('slow image fixture'));
        expect(
          server.bodies.single.toLowerCase(),
          contains('content-type: image/png'),
        );
        expect(transport.options.receiveTimeout, _normalTimeout);
      },
    );

    test('$route upload keeps the longer wait after an auth refresh', () async {
      server.expireFirstUpload = true;
      final accepted = await upload(streamed: streamed);
      expect(accepted.single['id'], 'slow-picture');
      expect(server.refreshes, 1);
      expect(server.bodies, hasLength(2));
      expect(
        server.bodies.every((body) => body.contains('slow image fixture')),
        isTrue,
      );
    });

    test(
      '$route upload can be cancelled while awaiting the response',
      () async {
        final cancellation = UploadCancellation();
        final pending = upload(streamed: streamed, cancellation: cancellation);
        final rejected = expectLater(pending, throwsA(isA<RaftApiException>()));
        await server.uploadStarted.future;
        cancellation.cancel();
        await rejected.timeout(const Duration(seconds: 1));
        expect(
          server.bodies,
          hasLength(1),
          reason: 'cancellation must not retry',
        );
      },
    );
  }

  test('ordinary API reads still time out', () async {
    await expectLater(
      client.get('/slow-read'),
      throwsA(isA<RaftApiException>()),
    );
    expect(transport.options.receiveTimeout, _normalTimeout);
    expect(server.bodies, isEmpty);
  });
}
