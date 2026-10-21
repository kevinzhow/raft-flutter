// Web components/agentMigration/AgentMigrationDialog.tsx: the dialog that
// picks the target computer and starts a migration.

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'agent_migration_panel.dart';
import 'agent_migration_presentation.dart';

/// The target choice, the two paragraphs about what happens next and, after a
/// refused start, the error block with its recovery. The submit action reads
/// "Try again" once the refusal asks for a fix on the computers.
class AgentMigrationStartDialog extends StatefulWidget {
  const AgentMigrationStartDialog({
    super.key,
    required this.targets,
    required this.start,
    required this.openComputers,
  });

  /// Every other computer of the server (an offline one is listed; the server
  /// answers TARGET_COMPUTER_OFFLINE).
  final List<Map<String, dynamic>> targets;
  final Future<void> Function(String target) start;

  /// Opens the computer's settings (or the computer list) without leaving
  /// this dialog, so the chosen target survives a fix on the computers.
  final void Function(String? computerId) openComputers;
  @override
  State<AgentMigrationStartDialog> createState() =>
      _AgentMigrationStartDialogState();
}

class _AgentMigrationStartDialogState extends State<AgentMigrationStartDialog> {
  late String target = _firstTarget;
  MigrationPresentation? failure;

  String get _firstTarget =>
      widget.targets.isEmpty ? '' : '${widget.targets.first['id']}';

  @override
  void didUpdateWidget(AgentMigrationStartDialog old) {
    super.didUpdateWidget(old);
    // Web: a target that is no longer offered falls back to the first one.
    if (!widget.targets.any((m) => '${m['id']}' == target)) {
      target = _firstTarget;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final body = RaftTypography.body(
      t,
      size: 14,
      line: 14 * 1.625,
      color: t.strong,
    );
    return RaftFormDialog(
      title: 'Move to another computer',
      fields: const [],
      submitLabel: failure?.recoveryOpenComputers == true
          ? 'Try again'
          : 'Migrate',
      busyLabel: 'Starting migration…',
      submitEnabled: target.isNotEmpty,
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftField(
            label: raftText(context, 'Target computer'),
            uppercase: false,
            // Web asks nothing when the dialog is closed after only a target
            // change: the picker's text stays out of the unsaved-input guard.
            child: RaftUnsavedGuardIgnore(
              child: RaftAgentCombobox(
                key: const ValueKey('migration-target-computer'),
                label: 'Target computer',
                semanticLabel: raftText(context, 'Target computer'),
                emptyLabel: 'No matches',
                placeholder: raftText(context, 'No other computers available'),
                enabled: widget.targets.isNotEmpty,
                value: target,
                items: [
                  for (final m in widget.targets)
                    RaftComboboxItem('${m['id']}', '${m['name']}'),
                ],
                onSelected: (id) => setState(() => target = id),
              ),
            ),
          ),
          const SizedBox(height: RaftSpace.x4),
          Text(
            raftText(
              context,
              'Your agent will stop while it migrates, then start again on the new computer.',
            ),
            style: body,
          ),
          const SizedBox(height: RaftSpace.x2),
          Text(
            raftText(
              context,
              'Migrating moves the workspace files, including MEMORY.md and notes if any, to the new computer. The agent then starts a fresh session and picks up from MEMORY.md.',
            ),
            style: body,
          ),
        ],
      ),
      errorContent: (context, error) => error is AgentMigrationStartFailure
          ? _StartFailureView(error.presentation, widget.openComputers)
          : null,
      onSubmit: (_) async {
        try {
          await widget.start(target);
        } on AgentMigrationStartFailure catch (e) {
          if (mounted) setState(() => failure = e.presentation);
          rethrow;
        }
      },
    );
  }
}

/// A failed start request, carried from the form's submit to its error slot.
class AgentMigrationStartFailure implements Exception {
  const AgentMigrationStartFailure(this.presentation);
  final MigrationPresentation presentation;
}

/// The warning banner with the issues and technical details, and the link to
/// the computers that need a fix.
class _StartFailureView extends StatelessWidget {
  const _StartFailureView(this.presentation, this.openComputers);
  final MigrationPresentation presentation;
  final void Function(String? computerId) openComputers;

  @override
  Widget build(BuildContext context) {
    final recovery = presentation.recoveryOpenComputers;
    final computerId = presentation.recoveryComputerId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: RaftSpace.x4),
        RaftBanner(
          status: RaftBannerRecipeStatus.warning,
          size: RaftBannerRecipeSize.sm,
          descriptionBuilder: (style) =>
              MigrationErrorContent(presentation: presentation, style: style),
        ),
        if (recovery) ...[
          const SizedBox(height: RaftSpace.x4),
          Align(
            alignment: Alignment.centerLeft,
            child: RaftButton(
              label: raftText(
                context,
                computerId != null
                    ? 'Open computer settings'
                    : 'Open Computers',
              ),
              glyph: RaftGlyph.externalLink,
              tone: RaftButtonRecipeVariant.link,
              size: RaftButtonRecipeSize.sm,
              onPressed: () => openComputers(computerId),
            ),
          ),
        ],
      ],
    );
  }
}
