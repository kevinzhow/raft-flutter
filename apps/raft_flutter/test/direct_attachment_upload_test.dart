// Web utils/directAttachmentUpload.ts (v1.21.23): the presigned-session route
// of large attachments, its recovery and its fail-safe fallback.
import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_direct_upload.dart';
import 'package:raft_flutter/data/workspace_upload_route.dart';
import 'package:raft_flutter/data/workspace_uploads.dart';

class _Api implements AttachmentUploadApi {
  final calls = <String>[];
  final bodies = <String, Object?>{};
  final handlers = <String, List<Object? Function()>>{};

  /// Queues an answer (value or thrown error) for `METHOD path`.
  void on(String key, Object? Function() answer) =>
      (handlers[key] ??= []).add(answer);

  Future<dynamic> call(String method, String path, [Object? data]) async {
    final key = '$method $path';
    calls.add(key);
    if (data != null) bodies[key] = data;
    final queue = handlers[key];
    if (queue == null || queue.isEmpty) {
      throw StateError('unexpected call $key');
    }
    return queue.length == 1 ? queue.single() : queue.removeAt(0)();
  }

  @override
  Future<dynamic> get(String path, {UploadCancellation? cancellation}) =>
      call('GET', path);
  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    UploadCancellation? cancellation,
  }) => call('POST', path, data);
  @override
  Future<dynamic> delete(String path) => call('DELETE', path);
}

const _caps = '/attachments/upload-capabilities';
const _create = '/attachments/upload-sessions';
const _id = '11111111-1111-4111-8111-111111111111';
const _session = '/attachments/upload-sessions/$_id';

Map<String, Object?> _capabilities({
  bool enabled = true,
  int? threshold = 10,
  int max = 1000,
}) => {
  'directUploadEnabled': enabled,
  'directUploadThresholdBytes': threshold,
  'maxBytes': max,
  'sessionExpiresInSeconds': 900,
};

Map<String, Object?> _created() => {
  'uploadId': _id,
  'attachmentId': 'att-1',
  'state': 'pending',
  'expiresAt': '2026-10-24T00:00:00.000Z',
  'upload': {
    'method': 'PUT',
    'url': 'https://storage.invalid/bucket/key?X-Amz-Signature=secret',
    'headers': {'Content-Type': 'text/plain', 'If-None-Match': '*'},
  },
};

Map<String, Object?> _completed() => {
  'uploadId': _id,
  'state': 'completed',
  'attachment': {
    'id': 'att-1',
    'filename': 'big.txt',
    'mimeType': 'text/plain',
    'sizeBytes': 20,
    'thumbnailUrl': null,
  },
};

RaftApiException _contractFailure(
  int status,
  String code, {
  bool retryable = false,
  int? retryAfterMs,
}) => RaftApiException.response(
  'contract $code',
  status: status,
  body: {
    'code': code,
    'message': 'contract $code',
    'retryable': retryable,
    'retryAfterMs': ?retryAfterMs,
    'error': 'contract $code',
  },
);

class _Put {
  final calls = <({String url, Map<String, String> headers, int length})>[];
  final received = <int>[];
  Object? result = 200;
  Future<int> call({
    required String url,
    required Map<String, String> headers,
    required Stream<List<int>> body,
    required int length,
    required UploadCancellation? cancellation,
    required void Function(int, int)? onProgress,
  }) async {
    calls.add((url: url, headers: headers, length: length));
    var sent = 0;
    await for (final chunk in body) {
      sent += chunk.length;
      received.addAll(chunk);
      onProgress?.call(sent, length);
    }
    final value = result;
    if (value is int) return value;
    throw value!;
  }
}

Future<List<Map<String, dynamic>>> _upload(
  _Api api,
  _Put put, {
  int size = 20,
  String? previous,
  UploadCancellation? cancellation,
  List<String>? sessions,
  List<int>? progress,
  Future<List<Map<String, dynamic>>> Function()? legacy,
}) => DirectAttachmentUploader(api: api, put: put.call, sleep: (_) async {})
    .upload(
      channelId: 'channel-1',
      filename: 'big.txt',
      mimeType: 'text/plain; charset=utf-8',
      sizeBytes: size,
      openRead: () =>
          chunkedBytes(Uint8List.fromList(List.filled(size, 7)), chunk: 8),
      clientRequestId: 'req-1',
      previousSessionId: previous,
      cancellation: cancellation,
      onSession: sessions?.add,
      onProgress: progress == null ? null : (sent, total) => progress.add(sent),
      legacyUpload:
          legacy ??
          () async => [
            {'id': 'legacy'},
          ],
    );

void main() {
  test('a file at the threshold goes through a session: create, PUT, complete', () async {
    final api = _Api()
      ..on('GET $_caps', _capabilities)
      ..on('POST $_create', _created)
      ..on('POST $_session/complete', _completed);
    final put = _Put();
    final sessions = <String>[], progress = <int>[];
    final files = await _upload(
      api,
      put,
      sessions: sessions,
      progress: progress,
    );
    expect(files.single['id'], 'att-1');
    expect(api.calls, [
      'GET $_caps',
      'POST $_create',
      'POST $_session/complete',
    ]);
    expect(api.bodies['POST $_create'], {
      'channelId': 'channel-1',
      'filename': 'big.txt',
      // Web mimeTypeForUpload: parameters stripped, lower case.
      'mimeType': 'text/plain',
      'sizeBytes': 20,
      'clientRequestId': 'req-1',
    });
    expect(sessions, [_id]);
    // The presigned PUT carries exactly the signed headers and the whole file.
    expect(put.calls.single.url, startsWith('https://storage.invalid/'));
    expect(put.calls.single.headers, {
      'Content-Type': 'text/plain',
      'If-None-Match': '*',
    });
    expect(put.received.length, 20);
    // Byte-level progress, whole percents 1..99 (Web putFile).
    expect(progress, isNotEmpty);
    expect(progress.every((p) => p >= 1 && p <= 99), true);
    expect(progress, orderedEquals([...progress]..sort()));
  });

  test('below the threshold, or with direct upload off, the multipart route is used', () async {
    for (final caps in [
      _capabilities(threshold: 21),
      _capabilities(enabled: false),
      _capabilities(threshold: null),
    ]) {
      final api = _Api()..on('GET $_caps', () => caps);
      final put = _Put();
      final files = await _upload(api, put);
      expect(files.single['id'], 'legacy');
      expect(api.calls, ['GET $_caps']);
      expect(put.calls, isEmpty);
    }
  });

  test(
    'an unanswered capability probe degrades to multipart; a cancel does not',
    () async {
      final api = _Api()
        ..on('GET $_caps', () => throw _contractFailure(500, 'X'));
      expect((await _upload(api, _Put())).single['id'], 'legacy');

      final garbled = _Api()..on('GET $_caps', () => {'nope': true});
      expect((await _upload(garbled, _Put())).single['id'], 'legacy');

      final cancellation = UploadCancellation();
      final cancelled = _Api()
        ..on('GET $_caps', () {
          cancellation.cancel();
          return _capabilities();
        });
      var legacyRan = false;
      await expectLater(
        _upload(
          cancelled,
          _Put(),
          cancellation: cancellation,
          legacy: () async {
            legacyRan = true;
            return [];
          },
        ),
        throwsA(isA<AttachmentUploadClientError>()),
      );
      expect(legacyRan, false);
    },
  );

  test(
    'the server ceiling and an empty file are refused before any session',
    () async {
      final api = _Api()..on('GET $_caps', () => _capabilities(max: 15));
      await expectLater(
        _upload(api, _Put()),
        throwsA(
          isA<AttachmentUploadClientError>().having(
            (e) => e.code,
            'code',
            'UPLOAD_TOO_LARGE',
          ),
        ),
      );
      final empty = _Api()..on('GET $_caps', _capabilities);
      await expectLater(
        _upload(empty, _Put(), size: 0),
        throwsA(
          isA<AttachmentUploadClientError>().having(
            (e) => e.code,
            'code',
            'UPLOAD_INVALID_REQUEST',
          ),
        ),
      );
      expect(empty.calls, ['GET $_caps']);
    },
  );

  test(
    'a lost PUT answer is checked against the session before the user retries',
    () async {
      // The object arrived: status pending, completion succeeds.
      final arrived = _Api()
        ..on('GET $_caps', _capabilities)
        ..on('POST $_create', _created)
        ..on('GET $_session', () => {'uploadId': _id, 'state': 'pending'})
        ..on('POST $_session/complete', _completed);
      final put = _Put()..result = 503;
      expect((await _upload(arrived, put)).single['id'], 'att-1');

      // The object never arrived: UPLOAD_OBJECT_NOT_FOUND on completion is a
      // retryable "uncertain" failure, and the session is kept for the retry.
      final missing = _Api()
        ..on('GET $_caps', _capabilities)
        ..on('POST $_create', _created)
        ..on('GET $_session', () => {'uploadId': _id, 'state': 'pending'})
        ..on(
          'POST $_session/complete',
          () => throw _contractFailure(
            404,
            'UPLOAD_OBJECT_NOT_FOUND',
            retryable: true,
            retryAfterMs: 5,
          ),
        );
      final transport = _Put()..result = const SocketExceptionLike();
      await expectLater(
        _upload(missing, transport),
        throwsA(
          isA<AttachmentUploadClientError>()
              .having((e) => e.code, 'code', 'UPLOAD_OBJECT_PUT_UNCERTAIN')
              .having((e) => e.retryable, 'retryable', true),
        ),
      );
      expect(missing.calls.where((c) => c.startsWith('DELETE')), isEmpty);
      // Completion was attempted three times (Web completeUpload).
      expect(
        missing.calls.where((c) => c == 'POST $_session/complete').length,
        3,
      );
    },
  );

  test('a rejected PUT abandons the session and says why', () async {
    final api = _Api()
      ..on('GET $_caps', _capabilities)
      ..on('POST $_create', _created)
      ..on('DELETE $_session', () => {});
    final put = _Put()..result = 403;
    await expectLater(
      _upload(api, put),
      throwsA(
        isA<AttachmentUploadClientError>()
            .having((e) => e.code, 'code', 'UPLOAD_OBJECT_PUT_FAILED')
            .having((e) => e.status, 'status', 403)
            .having((e) => e.retryable, 'retryable', false),
      ),
    );
    expect(api.calls.last, 'DELETE $_session');
  });

  test('412 means the object exists: completion decides', () async {
    final api = _Api()
      ..on('GET $_caps', _capabilities)
      ..on('POST $_create', _created)
      ..on('POST $_session/complete', _completed);
    final put = _Put()..result = 412;
    expect((await _upload(api, put)).single['id'], 'att-1');
  });

  test(
    'a retry resumes the session it owns instead of creating another',
    () async {
      final done = _Api()
        ..on('GET $_caps', _capabilities)
        ..on('GET $_session', () => _completed());
      final put = _Put();
      expect((await _upload(done, put, previous: _id)).single['id'], 'att-1');
      expect(done.calls, ['GET $_caps', 'GET $_session']);
      expect(put.calls, isEmpty);

      // Object present but not yet verified: complete it, still no new session.
      final pending = _Api()
        ..on('GET $_caps', _capabilities)
        ..on('GET $_session', () => {'uploadId': _id, 'state': 'pending'})
        ..on('POST $_session/complete', _completed);
      expect(
        (await _upload(pending, put, previous: _id)).single['id'],
        'att-1',
      );

      // Object never arrived (three completion attempts find nothing): a fresh
      // session with the same request id, then a new PUT and completion.
      RaftApiException notFound() =>
          _contractFailure(404, 'UPLOAD_OBJECT_NOT_FOUND', retryable: true);
      final lost = _Api()
        ..on('GET $_caps', _capabilities)
        ..on('GET $_session', () => {'uploadId': _id, 'state': 'pending'})
        ..on('POST $_create', _created)
        ..handlers['POST $_session/complete'] = [
          () => throw notFound(),
          () => throw notFound(),
          () => throw notFound(),
          () => _completed(),
        ];
      final fresh = _Put();
      final files = await _upload(lost, fresh, previous: _id);
      expect(files.single['id'], 'att-1');
      expect(
        lost.bodies['POST $_create'],
        containsPair('clientRequestId', 'req-1'),
      );
      expect(fresh.calls, hasLength(1));
    },
  );

  test('a session the server ended cannot be resumed', () async {
    for (final (state, code) in [
      ('expired', 'UPLOAD_SESSION_EXPIRED'),
      ('canceled', 'UPLOAD_SESSION_CANCELED'),
      ('failed', 'UPLOAD_OBJECT_MISMATCH'),
    ]) {
      final api = _Api()
        ..on('GET $_caps', _capabilities)
        ..on('GET $_session', () => {'uploadId': _id, 'state': state});
      await expectLater(
        _upload(api, _Put(), previous: _id),
        throwsA(
          isA<AttachmentUploadClientError>().having(
            (e) => e.code,
            'code',
            code,
          ),
        ),
      );
    }
  });

  test(
    'completion waits out a verification in progress, with the server wait',
    () async {
      final waits = <Duration>[];
      final api = _Api()
        ..on('GET $_caps', _capabilities)
        ..on('POST $_create', _created)
        ..handlers['POST $_session/complete'] = [
          () => throw _contractFailure(
            409,
            'UPLOAD_VERIFICATION_IN_PROGRESS',
            retryable: true,
            retryAfterMs: 1500,
          ),
          () => _completed(),
        ];
      final files =
          await DirectAttachmentUploader(
            api: api,
            put: _Put().call,
            sleep: (d) async => waits.add(d),
          ).upload(
            channelId: 'channel-1',
            filename: 'big.txt',
            mimeType: 'text/plain',
            sizeBytes: 20,
            openRead: () => chunkedBytes(Uint8List(20)),
            clientRequestId: 'req-1',
            legacyUpload: () async => [],
          );
      expect(files.single['id'], 'att-1');
      expect(waits, [const Duration(milliseconds: 1500)]);
    },
  );

  test('contract failures keep the server code and retryability', () async {
    final api = _Api()
      ..on('GET $_caps', _capabilities)
      ..on(
        'POST $_create',
        () => throw _contractFailure(
          429,
          'UPLOAD_RATE_LIMITED',
          retryable: true,
          retryAfterMs: 60000,
        ),
      );
    await expectLater(
      _upload(api, _Put()),
      throwsA(
        isA<AttachmentUploadClientError>()
            .having((e) => e.code, 'code', 'UPLOAD_RATE_LIMITED')
            .having((e) => e.retryable, 'retryable', true)
            .having((e) => e.retryAfterMs, 'retryAfterMs', 60000),
      ),
    );
    final forbidden = _Api()
      ..on('GET $_caps', _capabilities)
      ..on(
        'POST $_create',
        () => throw _contractFailure(403, 'UPLOAD_FORBIDDEN'),
      );
    await expectLater(
      _upload(forbidden, _Put()),
      throwsA(
        isA<AttachmentUploadClientError>()
            .having((e) => e.code, 'code', 'UPLOAD_FORBIDDEN')
            .having((e) => e.retryable, 'retryable', false),
      ),
    );
  });

  test('an upload cancelled while its session was created leaves no session behind', () async {
    final cancellation = UploadCancellation();
    final api = _Api()
      ..on('GET $_caps', _capabilities)
      ..on('POST $_create', () {
        cancellation.cancel();
        return _created();
      })
      ..on('DELETE $_session', () => {});
    final put = _Put();
    await expectLater(
      _upload(api, put, cancellation: cancellation),
      throwsA(isA<AttachmentUploadClientError>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(api.calls.last, 'DELETE $_session');
    expect(put.calls, isEmpty);
  });

  test('error copy follows Web formatAttachmentUploadClientError', () {
    String text(String code, {int? status}) => WorkspaceUploads.uploadErrorText(
      AttachmentUploadClientError(code, 'raw', status: status),
    );
    expect(text('UPLOAD_SESSION_EXPIRED'), 'Upload session expired.');
    expect(text('UPLOAD_TOO_LARGE'), 'The attachment exceeds the plan limit.');
    expect(
      text('UPLOAD_OBJECT_PUT_UNCERTAIN'),
      'The upload response was lost. Retry to safely resume this upload.',
    );
    expect(
      text('UPLOAD_OBJECT_PUT_FAILED', status: 403),
      'Direct object upload failed with HTTP {status}.',
    );
    expect(text('SOMETHING_ELSE'), 'raw');
  });

  group('multipart idle deadline', () {
    test('a stalled transfer is cancelled and reported as UPLOAD_STALLED', () {
      fakeAsync((async) {
        final caller = UploadCancellation();
        UploadCancellation? inner;
        Object? failure;
        final hold = Completer<String>();
        unawaited(
          withIdleDeadline<String>(caller, const Duration(seconds: 60), (
            cancellation,
            progress,
          ) {
            inner = cancellation;
            progress(5, 100);
            return hold.future;
          }).catchError((Object e) {
            failure = e;
            return '';
          }),
        );
        async.elapse(const Duration(seconds: 59));
        expect(inner!.cancelled, false);
        async.elapse(const Duration(seconds: 1));
        expect(inner!.cancelled, true);
        hold.completeError(StateError('aborted'));
        async.flushMicrotasks();
        expect(
          failure,
          isA<AttachmentUploadClientError>().having(
            (e) => e.code,
            'code',
            'UPLOAD_STALLED',
          ),
        );
        expect(caller.cancelled, false);
      });
    });

    test(
      'progress re-arms it, and a finished transfer is no longer watched',
      () {
        fakeAsync((async) {
          final caller = UploadCancellation();
          late void Function(int, int) report;
          UploadCancellation? inner;
          final hold = Completer<String>();
          String? result;
          unawaited(
            withIdleDeadline<String>(caller, const Duration(seconds: 60), (
              cancellation,
              progress,
            ) {
              inner = cancellation;
              report = progress;
              return hold.future;
            }).then((v) => result = v),
          );
          async.elapse(const Duration(seconds: 50));
          report(10, 100);
          async.elapse(const Duration(seconds: 50));
          expect(inner!.cancelled, false);
          // Every byte sent: the server may take its time saving the file.
          report(100, 100);
          async.elapse(const Duration(minutes: 5));
          expect(inner!.cancelled, false);
          hold.complete('saved');
          async.flushMicrotasks();
          expect(result, 'saved');
        });
      },
    );

    test('the caller cancelling cancels the request', () {
      fakeAsync((async) {
        final caller = UploadCancellation();
        UploadCancellation? inner;
        unawaited(
          withIdleDeadline<String>(caller, const Duration(seconds: 60), (
            cancellation,
            _,
          ) {
            inner = cancellation;
            return Completer<String>().future;
          }),
        );
        caller.cancel();
        async.flushMicrotasks();
        expect(inner!.cancelled, true);
      });
    });
  });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
