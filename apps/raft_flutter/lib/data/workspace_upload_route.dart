import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'attachment_direct_upload.dart';
import 'upload_mime.dart';
import 'upload_failure.dart';
import 'workspace_uploads.dart';

// The transfer of one composer draft: the direct (presigned) route for a file
// at or above the server's threshold, else the multipart route, with Web's
// `uploadLegacyAttachmentWithIdleTimeout` guarding the latter.

/// Web `LEGACY_ATTACHMENT_UPLOAD_IDLE_TIMEOUT_MS`.
const legacyUploadIdleTimeout = Duration(seconds: 60);

/// Uploads [draft] into [channelId] and returns the accepted record(s).
Future<List<Map<String, dynamic>>> uploadDraft(
  RaftClient client,
  String channelId,
  UploadDraft draft,
  void Function(int, int) progress, {
  AttachmentUploadApi? api,
  Duration idleTimeout = legacyUploadIdleTimeout,
}) {
  final mimeType = composerMimeType(draft.filename);
  final local = draft.local;
  Future<List<Map<String, dynamic>>> multipart() =>
      withIdleDeadline(draft.cancel, idleTimeout, (cancellation, onProgress) {
        void report(int sent, int total) {
          onProgress(sent, total);
          progress(sent, total);
        }

        return local != null
            ? client.uploadStream(
                channelId,
                local.openRead,
                draft.sizeBytes,
                draft.filename,
                cancellation: cancellation,
                onProgress: report,
                mimeType: mimeType,
              )
            : client.upload(
                channelId,
                draft.bytes,
                draft.filename,
                cancellation: cancellation,
                onProgress: report,
                mimeType: mimeType,
              );
      });

  final uploader = DirectAttachmentUploader(
    api: api ?? ClientAttachmentUploadApi(client),
  );
  final requestId = directUploadOf(draft).clientRequestId ??= client
      .newRandomId();
  final ownedSession = directUploadOf(draft).uploadId;
  return uploader
      .upload(
        channelId: channelId,
        filename: draft.filename,
        mimeType: mimeType,
        sizeBytes: draft.sizeBytes,
        openRead: local?.openRead ?? () => chunkedBytes(draft.bytes),
        clientRequestId: requestId,
        previousSessionId: directUploadOf(draft).uploadId,
        cancellation: draft.cancel,
        legacyUpload: multipart,
        onProgress: progress,
        onSession: (uploadId) {
          directUploadOf(draft).uploadId = uploadId;
          // Removing the chip abandons the session (Web `removeFile`).
          directUploadOf(draft).discard = () async {
            await uploader.cancel(uploadId);
            UploadSessionEvents.notify(uploadId, canceled: true);
          };
        },
      )
      .then((files) {
        // The session is done: the chip stops owning it (Web clears
        // `directUploadSession`) and the unfinished-uploads lists refresh.
        final finished = directUploadOf(draft).uploadId ?? ownedSession;
        directUploadOf(draft).uploadId = null;
        directUploadOf(draft).discard = null;
        if (finished != null) {
          UploadSessionEvents.notify(finished, canceled: false);
        }
        return files;
      });
}

/// Web `uploadLegacyAttachmentWithIdleTimeout`: a transfer that stops moving
/// for [idle] is cancelled and reported as `UPLOAD_STALLED`; once every byte
/// is sent the deadline stops (the server may still be saving the file).
Future<T> withIdleDeadline<T>(
  UploadCancellation caller,
  Duration idle,
  Future<T> Function(
    UploadCancellation cancellation,
    void Function(int sent, int total) onProgress,
  )
  run,
) async {
  final request = UploadCancellation();
  caller.whenCancelled(request.cancel);
  var expired = false, complete = false;
  Timer? deadline;
  void arm() {
    deadline?.cancel();
    if (expired || complete || request.cancelled) return;
    deadline = Timer(idle, () {
      expired = true;
      request.cancel();
    });
  }

  AttachmentUploadClientError stalled() => const AttachmentUploadClientError(
    'UPLOAD_STALLED',
    'The upload stopped making progress. Check your connection and try again.',
    retryable: true,
  );
  arm();
  try {
    final result = await run(request, (sent, total) {
      if (expired || complete) return;
      if (total > 0 && sent >= total) {
        complete = true;
        deadline?.cancel();
        return;
      }
      arm();
    });
    if (expired) throw stalled();
    return result;
  } catch (_) {
    if (expired) throw stalled();
    rethrow;
  } finally {
    deadline?.cancel();
  }
}
