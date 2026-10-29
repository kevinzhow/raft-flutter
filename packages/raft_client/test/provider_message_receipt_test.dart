import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, this.status);
  final Map<String, dynamic> body;
  final int status;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}

Future<RaftApiException> _rejection(Map<String, dynamic> body) async {
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = _Adapter(body, 502),
  );
  try {
    await client.request(
      'POST',
      '/agents/a1/connections/github',
      authorized: false,
    );
    throw StateError('Expected rejection');
  } on RaftApiException catch (error) {
    return error;
  } finally {
    await client.dispose();
  }
}

void main() {
  test('a cloud provider\'s own reason is kept as plain text', () async {
    final error = await _rejection({
      'error': 'The provider refused the request',
      'code': 'agent_connection_provider_refused',
      'providerMessage': 'The agent needs exactly one GitHub plugin mount',
    });
    expect(
      error.details['providerMessage'],
      'The agent needs exactly one GitHub plugin mount',
    );
    expect(error.details['code'], 'agent_connection_provider_refused');
  });

  test('a provider reason that is not text is dropped', () async {
    final error = await _rejection({
      'error': 'x',
      'providerMessage': {'nested': 'object'},
    });
    expect(error.details['providerMessage'], isNull);
  });
}
