import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Source dialog', size: Size(390, 500))
Widget sourceDialogPreview() => const _DialogPreview();

@RaftPreviews('Source alert dialog', size: Size(390, 500))
Widget sourceAlertDialogPreview() => const _DialogPreview(alert: true);

class _DialogPreview extends StatefulWidget {
  const _DialogPreview({this.alert = false});
  final bool alert;

  @override
  State<_DialogPreview> createState() => _DialogPreviewState();
}

class _DialogPreviewState extends State<_DialogPreview> {
  String outcome = 'No action taken';

  Future<void> open() async {
    final bool? accepted;
    if (widget.alert) {
      accepted = await showRaftAlertDialog(
        context: context,
        title: 'Delete channel?',
        description: 'This cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
      );
    } else {
      accepted = await showRaftDialog<bool>(
        context: context,
        builder: (dialogContext) => RaftDialog(
          title: 'Review changes',
          content: const RaftDialogDescription(
            'Review the pending changes before continuing.',
          ),
          actions: [
            RaftButton(
              label: 'Cancel',
              secondary: true,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            RaftButton(
              label: 'Confirm',
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        ),
      );
    }
    if (!mounted) return;
    setState(() => outcome = accepted == true ? 'Confirmed' : 'Canceled');
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftButton(
          label: widget.alert ? 'Open alert dialog' : 'Open dialog',
          onPressed: open,
        ),
        const SizedBox(height: 16),
        Text(outcome),
      ],
    ),
  );
}
