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
  test('the 502 partial disconnect keeps its revoke-on-GitHub word', () async {
    final error = await _rejection({
      'error': 'Partly disconnected',
      'code': 'agent_connection_connector_disconnect_partial',
      'revokeOnGithub': true,
    });
    expect(error.details['revokeOnGithub'], true);
  });

  test('revokeOnGithub is only ever true', () async {
    final error = await _rejection({'error': 'x', 'revokeOnGithub': 'yes'});
    expect(error.details['revokeOnGithub'], isNull);
  });

  test('a top-level provider code and status are kept, typed', () async {
    final error = await _rejection({
      'error': 'x',
      'providerCode': 'bad_scope',
      'providerStatus': 422,
    });
    expect(error.details['providerCode'], 'bad_scope');
    expect(error.details['providerStatus'], 422);
    final wrong = await _rejection({
      'error': 'x',
      'providerCode': 5,
      'providerStatus': '422',
    });
    expect(wrong.details['providerCode'], isNull);
    expect(wrong.details['providerStatus'], isNull);
  });
}
