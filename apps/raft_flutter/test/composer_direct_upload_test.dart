// The composer side of direct uploads: a draft owns its session across
// retries, removing it abandons the session, a non-retryable failure offers
// no retry, and unfinished uploads of the channel show in the banner.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_direct_upload.dart';
import 'package:raft_flutter/data/upload_failure.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/recoverable_uploads_banner.dart';
import 'package:raft_ui/raft_ui.dart';

const _id = '22222222-2222-4222-8222-222222222222';
const _session = '/attachments/upload-sessions/$_id';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://direct-upload.invalid',
        sessionStore: MemorySessionStore(),
      );
  final requests = <String>[];
  final bodies = <String, Object?>{};
  final answers = <String, List<Object? Function()>>{};
  Map<String, Object?> capabilities = {
    'directUploadEnabled': true,
    'directUploadThresholdBytes': 4,
    'maxBytes': 1 << 20,
  };

  void on(String key, Object? Function() answer) =>
      (answers[key] ??= []).add(answer);

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    requests.add('GET $path');
    if (path == '/attachments/upload-capabilities') return capabilities;
    return _answer('GET $path');
  }

  @override
  Future<dynamic> delete(String path, {dynamic data}) async {
    requests.add('DELETE $path');
    return _answer('DELETE $path');
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    requests.add('$method $path');
    if (data != null) bodies['$method $path'] = data;
    return _answer('$method $path');
  }

  dynamic _answer(String key) {
    final queue = answers[key];
    if (queue == null || queue.isEmpty) return <String, Object?>{};
    return queue.length == 1 ? queue.single() : queue.removeAt(0)();
  }
}

Map<String, Object?> _created() => {
  'uploadId': _id,
  'attachmentId': 'att',
  'state': 'pending',
  'expiresAt': '2026-10-24T00:00:00.000Z',
  'upload': {
    'method': 'PUT',
    'url': 'https://storage.invalid/key',
    'headers': {'Content-Type': 'text/plain', 'If-None-Match': '*'},
  },
};

Map<String, Object?> _completed() => {
  'uploadId': _id,
  'state': 'completed',
  'attachment': {'id': 'att', 'filename': 'big.txt', 'sizeBytes': 8},
};

void main() {
  late _Client client;
  late WorkspaceController w;
  var putStatus = 200;
  final puts = <String>[];

  setUp(() {
    putStatus = 200;
    puts.clear();
    DirectAttachmentUploader.debugPut =
        ({
          required url,
          required headers,
          required body,
          required length,
          required cancellation,
          required onProgress,
        }) async {
          puts.add(url);
          await body.drain<void>();
          return putStatus;
        };
    client = _Client();
    w = WorkspaceController(client)
      ..channel = RaftChannel({'id': 'channel', 'name': 'general'});
  });
  tearDown(() async {
    DirectAttachmentUploader.debugPut = null;
    w.dispose();
    await client.dispose();
  });

  Uint8List bytes([int n = 8]) => Uint8List.fromList(List.filled(n, 1));

  test(
    'a large file is uploaded through a session and the chip is ready',
    () async {
      client
        ..on('POST /attachments/upload-sessions', _created)
        ..on('POST $_session/complete', _completed);
      await w.attachUpload('big.txt', bytes());
      final draft = w.uploads().single;
      expect(draft.id, 'att');
      expect(draft.error, isNull);
      expect(
        directUploadOf(draft).uploadId,
        isNull,
        reason: 'a finished session is no longer owned',
      );
      expect(puts, ['https://storage.invalid/key']);
      expect(
        client.requests,
        containsAllInOrder([
          'POST /attachments/upload-sessions',
          'POST $_session/complete',
        ]),
      );
      expect(
        client.requests.any((r) => r == 'POST /attachments/upload'),
        false,
      );
    },
  );

  test('a file under the threshold keeps using the multipart route', () async {
    client.capabilities = {
      ...client.capabilities,
      'directUploadThresholdBytes': 100,
    };
    client.on(
      'POST /attachments/upload',
      () => {
        'attachments': [
          {'id': 'multipart'},
        ],
      },
    );
    await w.attachUpload('small.txt', bytes());
    expect(w.uploads().single.id, 'multipart');
    expect(client.requests.any((r) => r.contains('upload-sessions')), false);
    expect(puts, isEmpty);
  });

  test(
    'a lost PUT answer keeps the session on the chip; retry resumes it',
    () async {
      putStatus = 503;
      client
        ..on('POST /attachments/upload-sessions', _created)
        ..on('GET $_session', () => {'uploadId': _id, 'state': 'pending'})
        ..answers['POST $_session/complete'] = [
          () => throw RaftApiException.response(
            'x',
            status: 404,
            body: {
              'code': 'UPLOAD_OBJECT_NOT_FOUND',
              'message': 'x',
              'retryable': true,
              'error': 'x',
            },
          ),
          () => throw RaftApiException.response(
            'x',
            status: 404,
            body: {
              'code': 'UPLOAD_OBJECT_NOT_FOUND',
              'message': 'x',
              'retryable': true,
              'error': 'x',
            },
          ),
          () => throw RaftApiException.response(
            'x',
            status: 404,
            body: {
              'code': 'UPLOAD_OBJECT_NOT_FOUND',
              'message': 'x',
              'retryable': true,
              'error': 'x',
            },
          ),
          // The retry's recovery finds the object.
          () => _completed(),
        ];
      await w.attachUpload('big.txt', bytes());
      final draft = w.uploads().single;
      expect(
        draft.error,
        'The upload response was lost. Retry to safely resume this upload.',
      );
      expect(draft.canRetry, true);
      expect(directUploadOf(draft).uploadId, _id);
      final requestId = directUploadOf(draft).clientRequestId;
      expect(requestId, isNotNull);

      client.requests.clear();
      await w.retryUpload(draft);
      expect(draft.id, 'att');
      expect(draft.error, isNull);
      expect(
        client.requests,
        containsAllInOrder(['GET $_session', 'POST $_session/complete']),
      );
      expect(
        client.requests.where((r) => r == 'POST /attachments/upload-sessions'),
        isEmpty,
        reason: 'the retry resumes the owned session',
      );
      expect(directUploadOf(draft).clientRequestId, requestId);
    },
  );

  test(
    'a rejected PUT is not retryable and names the storage status',
    () async {
      putStatus = 403;
      client.on('POST /attachments/upload-sessions', _created);
      await w.attachUpload('big.txt', bytes());
      final draft = w.uploads().single;
      expect(draft.error, 'Direct object upload failed with HTTP {status}.');
      expect(directUploadOf(draft).errorValues, {'status': '403'});
      expect(draft.canRetry, false);
      expect(client.requests, contains('DELETE $_session'));
    },
  );

  test('removing a chip that owns an unfinished session cancels it', () async {
    putStatus = 503;
    client
      ..on('POST /attachments/upload-sessions', _created)
      ..on('GET $_session', () => {'uploadId': _id, 'state': 'pending'})
      ..on(
        'POST $_session/complete',
        () => throw RaftApiException.response(
          'x',
          status: 404,
          body: {
            'code': 'UPLOAD_OBJECT_NOT_FOUND',
            'message': 'x',
            'retryable': true,
            'error': 'x',
          },
        ),
      );
    await w.attachUpload('big.txt', bytes());
    final draft = w.uploads().single;
    final events = <UploadSessionChange>[];
    final sub = UploadSessionEvents.changes.listen(events.add);
    client.requests.clear();
    w.removeUpload(draft);
    await Future<void>.delayed(Duration.zero);
    expect(client.requests, ['DELETE $_session']);
    expect(events.single.uploadId, _id);
    expect(events.single.canceled, true);
    await sub.cancel();
  });

  testWidgets(
    'unfinished uploads of the channel show in a banner with Cancel upload',
    (tester) async {
      client.on(
        'GET /attachments/upload-sessions/channel/active',
        () => {
          'uploads': [
            {
              'uploadId': _id,
              'filename': 'movie.mov',
              'mimeType': 'video/quicktime',
              'sizeBytes': 9,
              'state': 'pending',
              'expiresAt': '2026-10-24T00:00:00.000Z',
            },
            {'uploadId': 'other', 'filename': 'bad.bin', 'state': 'weird'},
          ],
        },
      );
      client.on('DELETE $_session', () => {});
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: w,
                builder: (context, _) =>
                    recoverableUploadsFor(context, w, thread: false) ??
                    const Text('none'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('none'), findsOneWidget);
      await tester.pump();
      await tester.pump();
      expect(find.text('One unfinished upload'), findsOneWidget);
      expect(find.text('movie.mov'), findsOneWidget);
      expect(
        find.text('bad.bin'),
        findsNothing,
        reason: 'a row Web would refuse is dropped',
      );
      await tester.tap(find.text('Cancel upload'));
      await tester.pump();
      await tester.pump();
      expect(client.requests, contains('DELETE $_session'));
      expect(find.text('none'), findsOneWidget);
    },
  );
}
