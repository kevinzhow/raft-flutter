// Task v2 delete confirmation (Web v1.24 TaskDeleteConfirmDialog). The app
// owns the request; this only collects the answer and shows the outcome. The
// two reason steps are popovers (task_reason_popover.dart).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'banner.dart';
import 'icons.dart';
import 'localization.dart';
import 'overlays/dialog.dart' show RaftDialog;
import 'raft/button.dart';

/// Web `TaskDeleteConfirmDialog` (Raft DS › Feedback › Confirming: deletes
/// are confirmed): what can't be undone in a red banner, Cancel and the red
/// Delete task. [onConfirm] resolves null once deleted (the caller closes
/// the dialog), or the sentence saying what went wrong, shown here; the
/// dialog then stays open to try again.
class RaftTaskDeleteConfirmDialog extends StatefulWidget {
  const RaftTaskDeleteConfirmDialog({
    super.key,
    required this.taskNumber,
    required this.onConfirm,
    required this.onCancel,
  });
  final int taskNumber;
  final Future<String?> Function() onConfirm;
  final VoidCallback onCancel;

  @override
  State<RaftTaskDeleteConfirmDialog> createState() =>
      _RaftTaskDeleteConfirmDialogState();
}

class _RaftTaskDeleteConfirmDialogState
    extends State<RaftTaskDeleteConfirmDialog> {
  bool busy = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next Delete starts; the state is dropped when the dialog closes.
  String? error;

  Future<void> confirm() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final failure = await widget.onConfirm();
    if (!mounted) return;
    setState(() {
      busy = false;
      error = failure;
    });
  }

  void cancel() {
    // Nothing closes it while the delete runs.
    if (!busy) widget.onCancel();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): cancel},
    child: RaftDialog.shell(
      key: const ValueKey('task-delete-confirm'),
      title: raftFormat(context, 'Delete task #{taskNumber}?', {
        'taskNumber': widget.taskNumber,
      }),
      onClose: cancel,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          RaftBanner(
            status: RaftBannerRecipeStatus.destructive,
            size: RaftBannerRecipeSize.sm,
            glyph: RaftGlyph.octagonAlert,
            live: false,
            description: raftText(
              context,
              "This cannot be undone. The task's discussion is deleted with it.",
            ),
          ),
          if (error != null)
            RaftBanner(
              key: const ValueKey('task-delete-confirm-error'),
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.triangleAlert,
              description: error!,
            ),
        ],
      ),
      footer: [
        RaftButton(
          label: 'Cancel',
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.lg,
          disabled: busy,
          onPressed: cancel,
        ),
        RaftButton(
          key: const ValueKey('task-delete-confirm-action'),
          label: 'Delete task',
          uiVariant: RaftButtonVariant.danger,
          uiSize: RaftButtonSize.lg,
          busy: busy,
          loadingLabel: 'Processing',
          onPressed: confirm,
        ),
      ],
    ),
  );
}
