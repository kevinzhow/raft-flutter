import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:raft_client/raft_client.dart';
import 'package:raft_client/system_proxy.dart';

// Web `utils/directAttachmentUpload.ts` (v1.21.23): a file at or above the
// server's advertised threshold goes straight to object storage through a
// short-lived presigned PUT, bracketed by an upload session
// (`POST /attachments/upload-sessions`, `.../complete`). The server owns every
// number: when the capability probe fails or says "not enabled" the upload
// degrades to the multipart route that always works, and a cancelled upload
// never degrades.

/// A failure Web's `AttachmentUploadClientError` carries: the contract `code`
/// ([uploadErrorText] maps it to catalog copy), whether a retry can help, and
/// the wait the server asked for.
class AttachmentUploadClientError implements Exception {
  const AttachmentUploadClientError(
    this.code,
    this.message, {
    this.retryable = false,
    this.retryAfterMs,
    this.status,
  });
  final String code, message;
  final bool retryable;
  final int? retryAfterMs;

  /// `UPLOAD_OBJECT_PUT_FAILED`: the storage host's HTTP status.
  final int? status;
  @override
  String toString() => message;
}

/// `GET /attachments/upload-capabilities`.
class AttachmentUploadCapabilities {
  const AttachmentUploadCapabilities({
    required this.directUploadEnabled,
    required this.directUploadThresholdBytes,
    required this.maxBytes,
  });
  final bool directUploadEnabled;
  final int? directUploadThresholdBytes;
  final int maxBytes;

  /// Null when the body is not a usable rule.
  static AttachmentUploadCapabilities? parse(dynamic value) {
    if (value is! Map) return null;
    final max = value['maxBytes'],
        threshold = value['directUploadThresholdBytes'];
    if (max is! num || !max.isFinite || max <= 0) return null;
    return AttachmentUploadCapabilities(
      directUploadEnabled: value['directUploadEnabled'] == true,
      directUploadThresholdBytes: threshold is num && threshold > 0
          ? threshold.toInt()
          : null,
      maxBytes: max.toInt(),
    );
  }

  /// Web: the direct route only when the server says so, and only for a file
  /// at or above its threshold.
  bool takesDirectRoute(int sizeBytes) =>
      directUploadEnabled &&
      directUploadThresholdBytes != null &&
      sizeBytes >= directUploadThresholdBytes!;
}

/// One unfinished upload of the viewer in a channel
/// (`GET /attachments/upload-sessions/:channelId/active`).
class RecoverableUpload {
  const RecoverableUpload({
    required this.uploadId,
    required this.filename,
    required this.state,
  });
  final String uploadId, filename, state;

  /// Null for a row Web's schema would refuse.
  static RecoverableUpload? parse(dynamic value) {
    if (value is! Map) return null;
    final id = value['uploadId'],
        name = value['filename'],
        state = value['state'];
    if (id is! String || id.isEmpty || name is! String) return null;
    if (state != 'pending' && state != 'verifying') return null;
    return RecoverableUpload(
      uploadId: id,
      filename: name,
      state: state as String,
    );
  }
}

/// Web `store/attachmentUploadEvents.ts`: a direct upload finished or was
/// cancelled, so every unfinished-uploads list refreshes.
class UploadSessionChange {
  const UploadSessionChange(this.uploadId, {required this.canceled});
  final String uploadId;
  final bool canceled;
}

class UploadSessionEvents {
  UploadSessionEvents._();
  // ignore: raft_lints/avoid_unreleased_resource -- Process-lifetime event bus (Web module store): listeners cancel themselves; the controller lives as long as the app.
  static final _changes = StreamController<UploadSessionChange>.broadcast();
  static Stream<UploadSessionChange> get changes => _changes.stream;
  static void notify(String uploadId, {required bool canceled}) =>
      _changes.add(UploadSessionChange(uploadId, canceled: canceled));
}

/// The API calls the upload needs. [RaftClient] by default; tests substitute.
abstract interface class AttachmentUploadApi {
  Future<dynamic> get(String path, {UploadCancellation? cancellation});
  Future<dynamic> post(
    String path, {
    Object? data,
    UploadCancellation? cancellation,
  });
  Future<dynamic> delete(String path);
}

class ClientAttachmentUploadApi implements AttachmentUploadApi {
  const ClientAttachmentUploadApi(this.client);
  final RaftClient client;
  // Reads carry no cancellation: the caller checks it after the answer.
  @override
  Future<dynamic> get(String path, {UploadCancellation? cancellation}) =>
      client.get(path);
  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    UploadCancellation? cancellation,
  }) => client.request('POST', path, data: data, cancellation: cancellation);
  @override
  Future<dynamic> delete(String path) => client.delete(path);
}

/// Sends one PUT of a presigned upload. Returns the HTTP status; a transport
/// failure throws (a cancellation throws [DioException] of type cancel).
typedef PresignedPut = Future<int> Function({
  required String url,
  required Map<String, String> headers,
  required Stream<List<int>> body,
  required int length,
  required UploadCancellation? cancellation,
  required void Function(int sent, int total)? onProgress,
});

/// Slices [bytes] into stream chunks so a PUT reports byte-level progress.
Stream<List<int>> chunkedBytes(
  Uint8List bytes, {
  int chunk = 256 * 1024,
}) async* {
  for (var offset = 0; offset < bytes.length; offset += chunk) {
    yield Uint8List.sublistView(
      bytes,
      offset,
      math.min(offset + chunk, bytes.length),
    );
  }
}

class DirectAttachmentUploader {
  DirectAttachmentUploader({
    required this.api,
    PresignedPut? put,
    Future<void> Function(Duration)? sleep,
  }) : _put = put ?? debugPut ?? presignedStoragePut,
       _sleep = sleep ?? ((d) => Future<void>.delayed(d));

  /// Tests replace the storage PUT.
  @visibleForTesting
  static PresignedPut? debugPut;

  final AttachmentUploadApi api;
  final PresignedPut _put;
  final Future<void> Function(Duration) _sleep;

  static String sessionPath(String uploadId) =>
      '/attachments/upload-sessions/${Uri.encodeComponent(uploadId)}';

  /// Web `listActiveAttachmentUploads`.
  Future<List<RecoverableUpload>> listActive(
    String channelId, {
    UploadCancellation? cancellation,
  }) async {
    final body = await api.get(
      '/attachments/upload-sessions/${Uri.encodeComponent(channelId)}/active',
      cancellation: cancellation,
    );
    final rows = body is Map ? body['uploads'] : null;
    return [
      if (rows is List)
        for (final row in rows) ?RecoverableUpload.parse(row),
    ];
  }

  /// Web `cancelAttachmentUploadSession`.
  Future<void> cancel(String uploadId) async {
    await api.delete(sessionPath(uploadId));
  }

  /// Web `uploadAttachmentFile`. Returns the accepted attachment record(s) the
  /// way `POST /attachments/upload` does, so callers treat both routes alike.
  Future<List<Map<String, dynamic>>> upload({
    required String channelId,
    required String filename,
    required String mimeType,
    required int sizeBytes,
    required Stream<List<int>> Function() openRead,
    required String clientRequestId,
    required Future<List<Map<String, dynamic>>> Function() legacyUpload,
    String? previousSessionId,
    UploadCancellation? cancellation,
    void Function(String uploadId)? onSession,
    void Function(int sent, int total)? onProgress,
  }) async {
    AttachmentUploadCapabilities capability;
    try {
      final parsed = AttachmentUploadCapabilities.parse(
        await api.get(
          '/attachments/upload-capabilities',
          cancellation: cancellation,
        ),
      );
      if (cancellation?.cancelled ?? false) throw _cancelError();
      if (parsed == null) throw const FormatException('capabilities');
      capability = parsed;
    } catch (error) {
      // Task #187: fail SAFE. An unanswered probe says nothing about direct
      // upload, so it resolves to the path that always works; the one
      // exception is the user's own cancel.
      if (_cancelled(error, cancellation)) rethrow;
      return legacyUpload();
    }
    if (sizeBytes <= 0) {
      throw const AttachmentUploadClientError(
        'UPLOAD_INVALID_REQUEST',
        'The attachment is empty.',
      );
    }
    if (sizeBytes > capability.maxBytes) {
      throw const AttachmentUploadClientError(
        'UPLOAD_TOO_LARGE',
        'The attachment exceeds the plan limit.',
      );
    }
    if (!capability.takesDirectRoute(sizeBytes)) return legacyUpload();

    if (previousSessionId != null) {
      final recovered = await _recover(previousSessionId, cancellation);
      if (recovered != null) return [recovered];
    }
    final session = await _createSession({
      'channelId': channelId,
      'filename': filename,
      'mimeType': _normalizedMime(mimeType),
      'sizeBytes': sizeBytes,
      'clientRequestId': clientRequestId,
    }, cancellation);
    final uploadId = session.uploadId;
    onSession?.call(uploadId);
    if (cancellation?.cancelled ?? false) {
      // Removed while the session was being created: nothing may linger.
      unawaited(cancel(uploadId).catchError((Object _) {}));
      throw _cancelError();
    }

    final _PutOutcome outcome;
    try {
      outcome = await _putFile(
        session,
        openRead,
        sizeBytes,
        cancellation,
        onProgress,
      );
    } catch (error) {
      if (cancellation?.cancelled ?? false) rethrow;
      await cancel(uploadId).catchError((Object _) {});
      rethrow;
    }
    if (outcome == _PutOutcome.objectMayExist) {
      final recovered = await _recover(uploadId, cancellation);
      if (recovered != null) return [recovered];
      throw const AttachmentUploadClientError(
        'UPLOAD_OBJECT_PUT_UNCERTAIN',
        'The upload response was lost. Retry to safely resume this upload.',
        retryable: true,
      );
    }
    return [await _complete(uploadId, cancellation)];
  }

  static String _normalizedMime(String mimeType) {
    final normalized = mimeType.split(';').first.trim().toLowerCase();
    return normalized.isEmpty ? 'application/octet-stream' : normalized;
  }

  Future<_Session> _createSession(
    Map<String, Object?> request,
    UploadCancellation? cancellation,
  ) async {
    final dynamic body;
    try {
      body = await api.post(
        '/attachments/upload-sessions',
        data: request,
        cancellation: cancellation,
      );
    } catch (error) {
      throw _contractError(
        error,
        cancellation,
        'UPLOAD_SESSION_CREATE_FAILED',
        'The upload session could not be created.',
      );
    }
    final upload = body is Map ? body['upload'] : null;
    final id = body is Map ? body['uploadId'] : null;
    final url = upload is Map ? upload['url'] : null;
    final headers = upload is Map ? upload['headers'] : null;
    if (id is! String || url is! String || headers is! Map) {
      throw const AttachmentUploadClientError(
        'UPLOAD_SESSION_CREATE_FAILED',
        'The upload session could not be created.',
        retryable: true,
      );
    }
    return _Session(id, url, {
      for (final entry in headers.entries) '${entry.key}': '${entry.value}',
    });
  }

  Future<_PutOutcome> _putFile(
    _Session session,
    Stream<List<int>> Function() openRead,
    int length,
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
  ) async {
    var reported = 0;
    void progress(int sent, int total) {
      if (onProgress == null || length <= 0 || sent <= 0) return;
      final percent = math.max(1, math.min(99, (sent / length * 100).round()));
      if (percent <= reported) return;
      reported = percent;
      onProgress(percent, 100);
    }

    final int status;
    try {
      status = await _put(
        url: session.url,
        headers: session.headers,
        body: openRead(),
        length: length,
        cancellation: cancellation,
        onProgress: progress,
      );
    } catch (error) {
      if (_cancelled(error, cancellation)) rethrow;
      // A lost response is not replayed blindly; the caller checks the
      // session before asking the user to retry.
      return _PutOutcome.objectMayExist;
    }
    if (status >= 200 && status < 300) return _PutOutcome.uploaded;
    if (status == 412) return _PutOutcome.alreadyExists;
    if (status == 408 || status == 429 || status >= 500) {
      return _PutOutcome.objectMayExist;
    }
    throw AttachmentUploadClientError(
      'UPLOAD_OBJECT_PUT_FAILED',
      'Direct object upload failed with HTTP $status.',
      status: status,
    );
  }

  Future<Map<String, dynamic>> _complete(
    String uploadId,
    UploadCancellation? cancellation,
  ) async {
    Object? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final body = await api.post(
          '${sessionPath(uploadId)}/complete',
          cancellation: cancellation,
        );
        final attachment = body is Map ? body['attachment'] : null;
        if (attachment is Map && attachment['id'] is String) {
          return Map<String, dynamic>.from(attachment);
        }
        throw const AttachmentUploadClientError(
          'UPLOAD_COMPLETE_FAILED',
          'The upload could not be completed.',
        );
      } catch (error) {
        final failure = error is AttachmentUploadClientError
            ? error
            : _contractError(
                error,
                cancellation,
                'UPLOAD_COMPLETE_FAILED',
                'The upload could not be completed.',
              );
        last = failure;
        if (failure is! AttachmentUploadClientError) throw failure;
        final retryable =
            failure.code == 'UPLOAD_OBJECT_NOT_FOUND' ||
            failure.code == 'UPLOAD_VERIFICATION_IN_PROGRESS';
        if (!retryable || attempt == 2) throw failure;
        await _sleep(
          Duration(milliseconds: failure.retryAfterMs ?? 250 * (attempt + 1)),
        );
        if (cancellation?.cancelled ?? false) throw _cancelError();
      }
    }
    throw last ??
        const AttachmentUploadClientError(
          'UPLOAD_COMPLETE_FAILED',
          'The upload could not be completed.',
        );
  }

  /// Web `recoverExistingSession`: the attachment when the session already
  /// finished or its object is there, null when the object never arrived.
  Future<Map<String, dynamic>?> _recover(
    String uploadId,
    UploadCancellation? cancellation,
  ) async {
    final dynamic session;
    try {
      session = await api.get(
        sessionPath(uploadId),
        cancellation: cancellation,
      );
      if (cancellation?.cancelled ?? false) throw _cancelError();
    } catch (error) {
      throw _contractError(
        error,
        cancellation,
        'UPLOAD_SESSION_STATUS_FAILED',
        'The upload session could not be checked.',
      );
    }
    final state = session is Map ? session['state'] : null;
    final attachment = session is Map ? session['attachment'] : null;
    if (state == 'completed' && attachment is Map) {
      return Map<String, dynamic>.from(attachment);
    }
    switch (state) {
      case 'expired':
        throw const AttachmentUploadClientError(
          'UPLOAD_SESSION_EXPIRED',
          'Upload session expired.',
        );
      case 'canceled':
        throw const AttachmentUploadClientError(
          'UPLOAD_SESSION_CANCELED',
          'Upload session was canceled.',
        );
      case 'failed':
        throw const AttachmentUploadClientError(
          'UPLOAD_OBJECT_MISMATCH',
          'Uploaded object failed verification.',
        );
    }
    try {
      return await _complete(uploadId, cancellation);
    } on AttachmentUploadClientError catch (error) {
      if (error.code == 'UPLOAD_OBJECT_NOT_FOUND') return null;
      rethrow;
    }
  }

  static AttachmentUploadClientError _cancelError() =>
      const AttachmentUploadClientError(
        'UPLOAD_CANCELED',
        'The upload was canceled.',
      );

  /// Did the caller cancel, rather than something fail?
  static bool _cancelled(Object error, UploadCancellation? cancellation) =>
      (cancellation?.cancelled ?? false) ||
      (error is DioException && error.type == DioExceptionType.cancel) ||
      (error is AttachmentUploadClientError && error.code == 'UPLOAD_CANCELED');

  /// Web `contractError`: the server's `{code, message, retryable}`, else the
  /// call site's fallback. A cancel stays a cancel.
  static Object _contractError(
    Object error,
    UploadCancellation? cancellation,
    String fallbackCode,
    String fallbackMessage,
  ) {
    if (_cancelled(error, cancellation)) return error;
    if (error is AttachmentUploadClientError) return error;
    if (error is RaftApiException) {
      final code = error.details['code'];
      final retryable = error.details['retryable'];
      final wait = error.details['retryAfterMs'];
      return AttachmentUploadClientError(
        code is String ? code : fallbackCode,
        error.structured ? error.message : fallbackMessage,
        retryable: retryable is bool ? retryable : true,
        retryAfterMs: wait is num ? wait.toInt() : null,
      );
    }
    return AttachmentUploadClientError(
      fallbackCode,
      fallbackMessage,
      retryable: true,
    );
  }
}

enum _PutOutcome { uploaded, alreadyExists, objectMayExist }

class _Session {
  const _Session(this.uploadId, this.url, this.headers);
  final String uploadId, url;
  final Map<String, String> headers;
}

Dio? _storageDio;

/// The storage host is a different origin from the API: its own client, no
/// interceptors and no API credentials, following the system proxy.
Dio _storageClient() => _storageDio ??= createProxiedDio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    // The verification pass after the last byte can take a while.
    receiveTimeout: const Duration(minutes: 2),
    validateStatus: (_) => true,
    responseType: ResponseType.plain,
  ),
);

/// The default [PresignedPut]: a plain PUT of the signed headers and the body.
Future<int> presignedStoragePut({
  required String url,
  required Map<String, String> headers,
  required Stream<List<int>> body,
  required int length,
  required UploadCancellation? cancellation,
  required void Function(int sent, int total)? onProgress,
}) async {
  final response = await _storageClient().put<Object?>(
    url,
    data: body,
    options: Options(
      headers: {...headers, Headers.contentLengthHeader: length},
      followRedirects: false,
    ),
    cancelToken: cancellation?.cancelToken,
    onSendProgress: onProgress,
  );
  return response.statusCode ?? 0;
}
