import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/upload_mime.dart';
import '../data/upload_failure.dart';
import '../data/upload_reorder.dart';
import '../data/workspace_controller.dart';

// Web MessageInput pending attachments (SortableAttachment + failed-upload
// rows) over the controller's per-draft-scope uploads. Presentation is
// raft_ui's `RaftComposerAttachments`; this file only maps upload state.

/// Web `isBillingUploadQuotaError`.
bool isBillingUploadQuotaError(String? error) =>
    error != null && error.contains('Monthly file upload quota exceeded');

/// The view model of one draft, with fixed copy localized.
RaftComposerAttachment composerAttachmentFor(
  BuildContext context,
  UploadDraft draft,
) {
  final status = draft.checking
      ? RaftComposerAttachmentStatus.checking
      : draft.error != null
      ? RaftComposerAttachmentStatus.failed
      : draft.id != null || draft.queued
      ? RaftComposerAttachmentStatus.ready
      : RaftComposerAttachmentStatus.uploading;
  final mime = draft.mimeType;
  return RaftComposerAttachment(
    id: '${draft.key}',
    name: draft.filename,
    mimeType: mime,
    preview: isPreviewableImageMime(mime) && draft.bytes.isNotEmpty
        ? draft.bytes
        : null,
    status: status,
    // Web clamps a live progress event to 1..99 and shows "Uploading" at 0.
    progress: draft.progress > 0
        ? (draft.progress * 100).round().clamp(1, 99)
        : 0,
    error: draft.error == null
        ? null
        : raftFormat(context, draft.error!, directUploadOf(draft).errorValues),
    canRetry: draft.canRetry,
    quotaBlocked: isBillingUploadQuotaError(draft.error),
  );
}

/// The `ComposerAttachments` slot for the composer of [thread]'s scope, or
/// null while nothing is pending.
Widget? composerAttachmentsFor(
  BuildContext context,
  WorkspaceController w, {
  required bool thread,
  required ValueChanged<UploadDraft> onPreview,
}) {
  final drafts = w.uploads(thread: thread);
  if (drafts.isEmpty) return null;
  final byId = {
    for (final draft in drafts) composerAttachmentFor(context, draft).id: draft,
  };
  return RaftComposerAttachments(
    items: [for (final draft in drafts) composerAttachmentFor(context, draft)],
    onRemove: (item) {
      final draft = byId[item.id];
      if (draft != null) w.removeUpload(draft, thread: thread);
    },
    onRetry: (item) {
      final draft = byId[item.id];
      if (draft != null) w.retryUpload(draft, thread: thread);
    },
    onPreview: (item) {
      final draft = byId[item.id];
      if (draft != null) onPreview(draft);
    },
    // Web `SortableAttachment`: chips drag into a new send order.
    onReorder: (ids) {
      final scope = w.draftScope(thread: thread);
      final keys = [for (final id in ids) ?int.tryParse(id)];
      if (scope == null || !reorderUploadDrafts(drafts, keys)) return;
      // Staged files are persisted in the new order.
      if (drafts.any((d) => d.local != null)) {
        unawaited(w.composer.saveScope(scope));
      }
      w.composer.uploads.changed(scope);
    },
  );
}

/// Why the files of a draft keep Send from going out, in Web's precedence.
enum ComposerSendBlock { checking, uploading, failed }

/// The block [drafts] impose on sending now, or null when they allow it. The
/// send title, the blocked-send notice and the notice's lifetime all read this
/// one derivation, so they cannot disagree.
ComposerSendBlock? composerSendBlockOf(List<UploadDraft> drafts) {
  if (drafts.any((d) => d.checking)) return ComposerSendBlock.checking;
  if (drafts.any((d) => d.error == null && d.id == null && !d.queued)) {
    return ComposerSendBlock.uploading;
  }
  if (drafts.any((d) => d.error != null)) return ComposerSendBlock.failed;
  return null;
}

/// Web `message.composer.*` title for the send action while files are not
/// sendable, or null when none applies.
String? composerSendBlockTitle(BuildContext context, List<UploadDraft> drafts) =>
    switch (composerSendBlockOf(drafts)) {
      ComposerSendBlock.checking => raftText(context, 'Checking attachments…'),
      ComposerSendBlock.uploading => raftText(
        context,
        'Uploading attachments…',
      ),
      ComposerSendBlock.failed => raftText(
        context,
        'Retry or remove failed attachments',
      ),
      null => null,
    };

/// Web `handleSubmit`: the notice a blocked send leaves in the banner.
String? composerSendBlockNotice(
  BuildContext context,
  List<UploadDraft> drafts,
) => switch (composerSendBlockOf(drafts)) {
  ComposerSendBlock.checking => raftText(
    context,
    'Wait for attachment checks to finish before sending.',
  ),
  ComposerSendBlock.uploading => raftText(
    context,
    'Wait for attachments to finish uploading before sending.',
  ),
  ComposerSendBlock.failed => raftText(
    context,
    'Remove or retry failed attachments before sending.',
  ),
  null => null,
};

/// Raises the blocked-send notice for the composer of [thread]. The notice is
/// derived from the uploads that caused it: it disappears when they finish,
/// are removed or retried into a different state, when the draft is sent, and
/// when the channel changes - nothing needs to clear it.
void raiseComposerSendBlockNotice(
  BuildContext context,
  WorkspaceController w, {
  required bool thread,
}) {
  final block = composerSendBlockOf(w.uploads(thread: thread));
  // ignore: raft_lints/avoid_imperative_notice_state -- Blocked-send notice raised with a whileTrue predicate over the live uploads: gone when they finish, are removed or change state; also ends on send and channel change.
  w.setComposerError(
    composerSendBlockNotice(context, w.uploads(thread: thread)),
    thread: thread,
    whileTrue: () => composerSendBlockOf(w.uploads(thread: thread)) == block,
  );
}
