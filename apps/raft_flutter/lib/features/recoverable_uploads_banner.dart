import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/attachment_direct_upload.dart';
import '../data/upload_failure.dart';
import '../data/workspace_controller.dart';

// Web MessageInput "unfinished uploads" banner. Direct-upload sessions outlive
// a restart or a channel switch, but without the original bytes this app
// cannot continue them, so the banner lists the viewer's active sessions of
// the channel that no pending chip owns and offers "Cancel upload".

/// The unfinished uploads of the channels whose composers were shown, read
/// from `GET /attachments/upload-sessions/:channelId/active`.
class RecoverableUploads {
  RecoverableUploads._(this.w, this.uploader) {
    final self = WeakReference(this);
    late final StreamSubscription<UploadSessionChange> sub;
    sub = UploadSessionEvents.changes.listen((change) {
      final model = self.target;
      if (model == null) {
        unawaited(sub.cancel());
      } else {
        model._changed(change);
      }
    });
  }

  static final _models = Expando<RecoverableUploads>('recoverable uploads');

  /// The model of [w]. [uploader] is for tests (first call only).
  static RecoverableUploads of(
    WorkspaceController w, {
    DirectAttachmentUploader? uploader,
  }) => _models[w] ??= RecoverableUploads._(
    w,
    uploader ??
        DirectAttachmentUploader(api: ClientAttachmentUploadApi(w.client)),
  );

  final WorkspaceController w;
  final DirectAttachmentUploader uploader;
  final _rows = <String, List<RecoverableUpload>>{};
  // Cancelled here: hidden until the server stops listing them, so a refresh
  // racing the DELETE cannot bring the row back.
  final _canceled = <String>{};
  final _generation = <String, int>{};

  /// The rows to show above [channelId]'s composer: not owned by a pending
  /// chip, not cancelled. First sight of a channel starts its load.
  List<RecoverableUpload> visible(String? channelId, Set<String> owned) {
    if (channelId == null) return const [];
    if (!_rows.containsKey(channelId) && !_generation.containsKey(channelId)) {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- One load per channel (guarded by the generation map), started from build; never repeats.
      scheduleMicrotask(() => refresh(channelId));
    }
    return [
      for (final row in _rows[channelId] ?? const <RecoverableUpload>[])
        if (!owned.contains(row.uploadId) && !_canceled.contains(row.uploadId))
          row,
    ];
  }

  Future<void> refresh(String channelId) async {
    final mine = _generation[channelId] = (_generation[channelId] ?? 0) + 1;
    List<RecoverableUpload> rows;
    try {
      rows = await uploader.listActive(channelId);
    } catch (_) {
      rows = const [];
    }
    if (_generation[channelId] != mine) return;
    final listed = rows.map((r) => r.uploadId).toSet();
    _canceled.removeWhere((id) => !listed.contains(id));
    final before = {for (final r in _rows[channelId] ?? const []) r.uploadId};
    _rows[channelId] = rows;
    if (before.length != listed.length || !before.containsAll(listed)) {
      w.notifyListeners();
    }
  }

  Future<void> cancel(RecoverableUpload upload) async {
    try {
      await uploader.cancel(upload.uploadId);
    } catch (_) {
      // Keep the row so a transient failure stays actionable.
      return;
    }
    _changed(UploadSessionChange(upload.uploadId, canceled: true));
  }

  void _changed(UploadSessionChange change) {
    if (change.canceled) {
      _canceled.add(change.uploadId);
      for (final entry in _rows.entries) {
        entry.value.removeWhere((r) => r.uploadId == change.uploadId);
      }
      w.notifyListeners();
    }
    for (final channelId in _rows.keys.toList()) {
      unawaited(refresh(channelId));
    }
  }
}

/// The banner slot of [thread]'s composer, or null when nothing is unfinished.
Widget? recoverableUploadsFor(
  BuildContext context,
  WorkspaceController w, {
  required bool thread,
  RecoverableUploads? model,
}) {
  final owned = {
    for (final draft in w.uploads(thread: thread))
      ?directUploadOf(draft).uploadId,
  };
  final channelId = thread ? w.threadChannelId : w.channel?.id;
  final uploads = (model ?? RecoverableUploads.of(w)).visible(channelId, owned);
  if (uploads.isEmpty) return null;
  final target = model ?? RecoverableUploads.of(w);
  return RaftComposerRecoverableUploads(
    items: [
      for (final u in uploads)
        RaftComposerRecoverableUpload(id: u.uploadId, name: u.filename),
    ],
    onCancel: (item) {
      for (final u in uploads) {
        if (u.uploadId == item.id) unawaited(target.cancel(u));
      }
    },
  );
}
