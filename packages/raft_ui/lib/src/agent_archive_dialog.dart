// Web components/agentArchive/AgentArchiveDialog.tsx: archive an agent (the
// former delete). Presentation only: the app owns the request and its errors.
import 'package:flutter/material.dart';

import 'agent_dialogs.dart' show RaftRadioMark;
import 'banner.dart';
import 'design_primitives.dart' show RaftTypography;
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipes/button_variants.g.dart';
import 'settings_controls.dart' show RaftConfirmDialog;
import 'theme.dart';

/// `ConfirmDialog` (`max-w-md`, plain message) holding the description, for an
/// agent with a workspace on a Computer a keep / delete radio group, and the
/// red-soft warning banner once "delete" is chosen. The confirm button is the
/// `warning` "Archive Agent" (`danger` for a workspace delete).
class RaftAgentArchiveDialog extends StatefulWidget {
  const RaftAgentArchiveDialog({
    super.key,
    required this.agentName,
    required this.computer,
    required this.hasComputerWorkspace,
    required this.onConfirm,
  });
  final String agentName;

  /// The agent's Computer name (the option descriptions name it).
  final String computer;

  /// `Boolean(agent.machineId) && !external`: only then is there a workspace
  /// to keep or delete.
  final bool hasComputerWorkspace;

  /// Runs the archive; `deleteWorkspace` is false for the keep choice and for
  /// an agent without a Computer workspace.
  final Future<void> Function(bool deleteWorkspace) onConfirm;

  @override
  State<RaftAgentArchiveDialog> createState() => _RaftAgentArchiveDialogState();
}

class _RaftAgentArchiveDialogState extends State<RaftAgentArchiveDialog> {
  bool deleteWorkspace = false;

  @override
  void didUpdateWidget(RaftAgentArchiveDialog old) {
    super.didUpdateWidget(old);
    // The choice only exists with a workspace; losing it resets to keep.
    if (!widget.hasComputerWorkspace) deleteWorkspace = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final options = [
      (
        false,
        'keep',
        raftText(context, 'Keep it on the Computer'),
        raftFormat(
          context,
          'Nothing is deleted. You can browse it read-only while {computer} is online, and delete it later.',
          {'computer': widget.computer},
        ),
      ),
      (
        true,
        'delete',
        raftText(context, 'Delete the workspace'),
        raftFormat(
          context,
          'The workspace is removed from {computer}. The profile and messages stay.',
          {'computer': widget.computer},
        ),
      ),
    ];
    return RaftConfirmDialog(
      surfaceKey: const ValueKey('agent-dialog'),
      title: raftFormat(context, 'Archive {name}?', {'name': widget.agentName}),
      maxWidth: 448,
      confirmLabel: raftText(context, 'Archive Agent'),
      loadingLabel: raftText(context, 'Archiving…'),
      confirmGlyph: RaftGlyph.archive,
      confirmKey: const ValueKey('agent-archive-confirm'),
      confirmVariant: deleteWorkspace
          ? RaftButtonRecipeVariant.danger
          : RaftButtonRecipeVariant.warning,
      onConfirm: () =>
          widget.onConfirm(widget.hasComputerWorkspace && deleteWorkspace),
      content: Column(
        key: const ValueKey('agent-archive-dialog'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftCssText(
            raftText(
              context,
              "The agent stops and no longer counts toward your plan's agent limit. Its profile and message history stay visible, read-only.",
            ),
          ),
          if (widget.hasComputerWorkspace) ...[
            const SizedBox(height: 12),
            Semantics(
              container: true,
              label: raftText(context, 'What should happen to its workspace?'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (remove, id, label, description) in options)
                    // DS Radio row: min 44 tall, the whole row clicks.
                    GestureDetector(
                      key: ValueKey('agent-archive-option-$id'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => deleteWorkspace = remove),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: RaftRadioMark(
                                  checked: deleteWorkspace == remove,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // `text-subhead font-semibold`: 15 / 20.
                                    RaftCssText(
                                      label,
                                      style: RaftTypography.body(
                                        t,
                                        size: 15,
                                        line: 20,
                                        weight: FontWeight.w600,
                                        color: t.brutal
                                            ? Colors.black
                                            : t.strong,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // `text-footnote font-normal` 13 / 18, muted.
                                    RaftCssText(
                                      description,
                                      style: RaftTypography.body(
                                        t,
                                        size: 13,
                                        line: 18,
                                        color: t.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          // Deleting the workspace cannot be undone: the destructive banner.
          if (deleteWorkspace) ...[
            const SizedBox(height: 12),
            RaftBanner(
              status: RaftBannerRecipeStatus.destructive,
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.triangleAlert,
              description: raftText(
                context,
                'Deleting the workspace cannot be undone.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
