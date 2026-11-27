import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';

enum DocumentPreviewUnavailableReason {
  tooLarge,
  temporarilyUnavailable,
  unsupported;

  static DocumentPreviewUnavailableReason fromServer(String reason) =>
      switch (reason) {
        'too_large' => tooLarge,
        'unavailable' => temporarilyUnavailable,
        _ => unsupported,
      };
}

class DocumentPreviewDownloadFallback {
  bool _started = false;

  Future<void> run({
    required BuildContext context,
    required String filename,
    required DocumentPreviewUnavailableReason reason,
    required bool Function() current,
    required Future<bool> Function()? allowed,
    required VoidCallback close,
    required Future<void> Function() download,
  }) async {
    if (_started || !current()) return;
    _started = true;
    if (allowed != null && !await allowed()) return;
    if (!context.mounted || !current()) return;
    final values = {'filename': filename};
    final title = switch (reason) {
      DocumentPreviewUnavailableReason.tooLarge => raftFormat(
        context,
        '{filename} is too large to preview',
        values,
      ),
      DocumentPreviewUnavailableReason.temporarilyUnavailable => raftFormat(
        context,
        'Preview of {filename} is temporarily unavailable',
        values,
      ),
      DocumentPreviewUnavailableReason.unsupported => raftFormat(
        context,
        "{filename} can't be previewed",
        values,
      ),
    };
    showRaftToast(
      context,
      title,
      description: 'Downloading the file instead.',
      tone: RaftToastRecipeTone.warning,
    );
    close();
    try {
      await download();
    } catch (error) {
      logUserError(error, where: 'document preview download');
    }
  }
}
