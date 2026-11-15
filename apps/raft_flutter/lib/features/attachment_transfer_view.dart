import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/attachment_transfer.dart';

/// Presents a data-layer [AttachmentTransferProgress] feed as the raft_ui
/// draw model. A thin view: no copy, no extra notifications; listeners attach
/// straight to the (already throttled) source.
class AttachmentTransferView
    implements ValueListenable<RaftTransferProgress?> {
  const AttachmentTransferView(this.source);
  final ValueListenable<AttachmentTransferProgress?> source;

  @override
  RaftTransferProgress? get value {
    final progress = source.value;
    return progress == null
        ? null
        : RaftTransferProgress(
            received: progress.received,
            total: progress.total,
          );
  }

  @override
  void addListener(VoidCallback listener) => source.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      source.removeListener(listener);
}
