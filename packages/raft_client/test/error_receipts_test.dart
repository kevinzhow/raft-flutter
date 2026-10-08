import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:raft_client/raft_client.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, this.status);
  final dynamic body;
  final int status;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    jsonEncode(body is Future ? await body : body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}

Future<RaftApiException> rejection(
  Map<String, dynamic> body,
  int status,
) async {
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = _Adapter(body, status),
  );
  try {
    await client.request(
      'POST',
      '/channels/c1/convert-to-joint',
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
  test('upload admission conflict preserves only immutable necessary recovery coordinates', () async {
    final error = await rejection({
      'error': 'Attachment uploads are still in flight',
      'code': 'channel_conversion_uploads_in_flight',
      'uploadCount': 1,
      'uploadScope': {
        'sessionIds': ['u1'],
        'transferIntentIds': [],
        'reservationIds': [],
      },
      'accessToken': 'unexpected-do-not-retain',
    }, 409);
    expect(error.status, 409);
    expect(error.details['code'], 'channel_conversion_uploads_in_flight');
    expect(error.details['uploadCount'], 1);
    expect(error.details.containsKey('accessToken'), false);
    expect(error.toString(), 'Attachment uploads are still in flight');
    expect(() => error.details['code'] = 'changed', throwsUnsupportedError);
    expect(
      () => error.details['uploadScope']['sessionIds'].add('u2'),
      throwsUnsupportedError,
    );
  });
  test(
    'admitted failed job preserves receipt without opaque raw server payload',
    () async {
      final error = await rejection({
        'error': 'Conversion needs repair',
        'code': 'channel_conversion_awaiting_retry',
        'conversionJob': {
          'id': 'j1',
          'status': 'failed',
          'phase': 'verify',
          'canCancel': false,
          'error': 'Verification failed',
          'progress': {
            'errorCode': 'verify_failed',
            'rollbackState': 'restored',
            'failedAt': '2026-10-08T22:00:00Z',
            'apiKey': 'unexpected-do-not-retain',
          },
          'serverSecret': 'unexpected-do-not-retain',
        },
        'rawRequest': {'password': 'unexpected-do-not-retain'},
      }, 409);
      expect(error.details['conversionJob']['status'], 'failed');
      expect(
        error.details['conversionJob']['progress']['rollbackState'],
        'restored',
      );
      expect(error.details['conversionJob'].containsKey('serverSecret'), false);
      expect(
        error.details['conversionJob']['progress'].containsKey('apiKey'),
        false,
      );
      expect(error.details.containsKey('rawRequest'), false);
      expect(
        () => error.details['conversionJob']['progress']['rollbackState'] =
            'mutated',
        throwsUnsupportedError,
      );
    },
  );
  test('late private failure cannot disclose its error receipt into a new workspace', () async {
    final delayed = Completer<Map<String, dynamic>>();
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = _Adapter(delayed.future, 409),
    );
    addTearDown(client.dispose);
    client.selectServer('old');
    final request = client.request(
      'POST',
      '/channels/private/convert-to-joint',
    );
    await Future<void>.delayed(Duration.zero);
    client.selectServer('new');
    delayed.complete({
      'error': 'Private conversion failure',
      'code': 'channel_conversion_failed',
      'conversionJob': {
        'id': 'private-job',
        'status': 'failed',
        'phase': 'verify',
      },
    });
    await expectLater(
      request,
      throwsA(
        isA<RaftApiException>()
            .having((e) => e.details, 'scope-safe receipt', isEmpty)
            .having(
              (e) => e.message,
              'scope-safe message',
              'The account or workspace changed. Please retry.',
            ),
      ),
    );
  });
  test('explicit receipt constructor snapshots caller mutation and keeps printable error concise', () {
    final input = {
      'conversionJob': {
        'id': 'j1',
        'status': 'running',
        'phase': 'prepare',
        'progress': {'failedAt': 'old'},
      },
    };
    final error = RaftApiException.response(
      'Request failed',
      status: 409,
      body: input,
    );
    (input['conversionJob']!['progress'] as Map)['failedAt'] = 'new';
    expect(error.details['conversionJob']['progress']['failedAt'], 'old');
    expect(error.toString(), 'Request failed');
    expect(const RaftApiException('Legacy').details, isEmpty);
  });
}
