import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    if (options.path == '/auth/me') {
      return ResponseBody.fromString(
        '{"id":"u","name":"person"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path == '/missing') {
      return ResponseBody.fromString(
        '{"error":"nope"}',
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromBytes(
      [137, 80, 78, 71, 1, 2, 3],
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  late RaftClient client;
  setUp(() async {
    adapter = _Adapter();
    final store = MemorySessionStore();
    await store.write(
      'https://example.invalid',
      Session(accessToken: 'access', refreshToken: 'refresh'),
    );
    client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: store,
      transport: Dio()..httpClientAdapter = adapter,
    );
    await client.restore();
    adapter.calls.clear();
  });
  tearDown(() => client.dispose());

  test('reads the response as bytes with the session', () async {
    final bytes = await client.getBytes(
      '/product-feedback/tickets/t/attachments/a',
    );
    expect(bytes, [137, 80, 78, 71, 1, 2, 3]);
    final call = adapter.calls.single;
    expect(call.responseType, ResponseType.bytes);
    expect(call.headers['Authorization'], 'Bearer access');
  });

  test('ordinary requests are still decoded as JSON', () async {
    await client.getBytes('/x');
    await client.get('/y').catchError((_) => null);
    expect(adapter.calls.last.responseType, isNot(ResponseType.bytes));
  });

  test('a failure is a RaftApiException with its status', () async {
    await expectLater(
      client.getBytes('/missing'),
      throwsA(isA<RaftApiException>().having((e) => e.status, 'status', 404)),
    );
  });
}
