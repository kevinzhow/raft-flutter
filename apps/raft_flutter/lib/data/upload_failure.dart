import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'attachment_direct_upload.dart';
import 'user_error.dart';
import 'workspace_uploads.dart';

// What a composer draft remembers about a direct upload and how a failed
// transfer is presented. Kept beside [UploadDraft], not in it: the draft's
// owner module is a structure-audit hotspot.

/// The direct-upload facts of one [UploadDraft].
class DirectUploadState {
  /// Web `uploadClientRequestId`: one idempotency key for every attempt of the
  /// draft, so a retried session create finds the first one.
  String? clientRequestId;

  /// Web `directUploadSession`: the unfinished upload the draft owns, resumed
  /// (not recreated) by the next attempt.
  String? uploadId;

  /// Abandons the session on the server; run when the draft is removed.
  Future<void> Function()? discard;

  /// Values for the placeholders of the draft's error (`{status}`).
  Map<String, Object> errorValues = const {};
}

final _states = Expando<DirectUploadState>('direct upload state');

/// The direct-upload facts of [draft] (created on first use).
DirectUploadState directUploadOf(UploadDraft draft) =>
    _states[draft] ??= DirectUploadState();

/// A direct upload outlives its chip until the server is told (Web
/// `removeFile`); a failed cancel leaves it in the unfinished-uploads banner.
void discardDirectUpload(UploadDraft draft) {
  final state = _states[draft];
  if (state?.uploadId == null) return;
  final discard = state!.discard;
  if (discard != null) unawaited(discard().catchError((Object _) {}));
}

/// Records why [draft]'s transfer failed: the copy, its values and whether a
/// retry can help (Web `uploadCanRetry`).
void recordUploadFailure(UploadDraft draft, Object failure) {
  draft.error = uploadFailureText(failure);
  directUploadOf(draft).errorValues =
      failure is AttachmentUploadClientError && failure.status != null
      ? {'status': '${failure.status}'}
      : const {};
  draft.canRetry = failure is! AttachmentUploadClientError || failure.retryable;
}

/// Web `utils/attachmentUploadErrorPresentation.ts`: the contract `UPLOAD_*`
/// code, the "storage timed out" mapping, else `uploadRetryHint`.
String uploadFailureText(Object failure) {
  if (failure is AttachmentUploadClientError) {
    // Web `formatAttachmentUploadClientError`.
    return failure.code == 'UPLOAD_OBJECT_PUT_FAILED'
        ? 'Direct object upload failed with HTTP {status}.'
        : _uploadCodeText[failure.code] ?? failure.message;
  }
  if (failure is RaftApiException &&
      failure.message == 'Attachment storage timed out') {
    // Web `SERVER_UPLOAD_ERROR_MESSAGE_ID`.
    return 'The file reached Raft, but saving it timed out.';
  }
  return userErrorText(
    failure,
    fallback: 'File no longer available or upload failed. Tap to retry.',
    codeText: _uploadCodeText,
    where: 'upload attachment',
  );
}

const _uploadCodeText = {
  'UPLOAD_COMPLETE_FAILED': 'The upload could not be completed.',
  'UPLOAD_SESSION_EXPIRED': 'Upload session expired.',
  'UPLOAD_SESSION_CANCELED': 'Upload session was canceled.',
  'UPLOAD_OBJECT_MISMATCH': 'Uploaded object failed verification.',
  'UPLOAD_SESSION_STATUS_FAILED': 'The upload session could not be checked.',
  'UPLOAD_SESSION_CREATE_FAILED': 'The upload session could not be created.',
  'UPLOAD_CAPABILITY_FAILED': 'Upload capability could not be checked.',
  'UPLOAD_INVALID_REQUEST': 'The attachment is empty.',
  'UPLOAD_TOO_LARGE': 'The attachment exceeds the plan limit.',
  'UPLOAD_OBJECT_PUT_UNCERTAIN':
      'The upload response was lost. Retry to safely resume this upload.',
  'UPLOAD_STALLED': 'The upload stopped making progress. Check your connection and try again.',
};
