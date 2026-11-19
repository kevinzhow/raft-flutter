// Web components/agentMigration/AgentMigrationDialog.tsx: the dialog that
// picks the target computer and starts a migration.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_hosted_runtime.dart';
import '../data/workspace_controller.dart';
import 'agent_hosted_model_choice.dart';
import 'agent_hosted_provider.dart';
import 'agent_migration_panel.dart';
import 'agent_migration_presentation.dart';

/// The target picker, move notes and recovery for a refused start.
class AgentMigrationStartDialog extends StatefulWidget {
  const AgentMigrationStartDialog({
    super.key,
    required this.targets,
    required this.start,
    required this.openComputers,
    required this.sourceMachineId,
    this.controller,
    this.hostedAvailable = false,
    this.placesWithoutSource = false,
    this.sourceName,
    this.startHosted,
    this.initialTarget,
  });

  /// A computer to preselect (a drop on the Computers rack, Web
  /// `AgentMigrationDialog.initialTarget`); ignored unless it is offered.
  final String? initialTarget;

  /// The cloud is offered as a target (`agent_migration_hosted_v0`, the cloud
  /// runtime on and configured: Web `useHostedMigrationAvailable`).
  final bool hostedAvailable;

  final String? sourceMachineId;
  final bool placesWithoutSource;

  /// Reads the models a cloud agent can start on (only with [hostedAvailable]).
  final WorkspaceController? controller;

  /// The source computer's name, for the notes about what happens to it.
  final String? sourceName;

  /// Starts the move to the cloud on [hostedModel] (null: the provider's
  /// default).
  final Future<void> Function(String? hostedModel)? startHosted;

  /// Every other computer of the server, including offline computers.
  final List<Map<String, dynamic>> targets;
  final Future<void> Function(String target) start;

  /// Opens the computer's settings (or the computer list) without leaving
  /// this dialog, so the chosen target survives a fix on the computers.
  final void Function(String? computerId) openComputers;
  @override
  State<AgentMigrationStartDialog> createState() =>
      _AgentMigrationStartDialogState();
}

/// The target picker's value for the cloud; never a machine id.
const _cloudTarget = '__cloud__';

class _AgentMigrationStartDialogState extends State<AgentMigrationStartDialog> {
  late String target = _targetIsSelectable(widget.initialTarget)
      ? widget.initialTarget!
      : _firstTarget;
  MigrationPresentation? failure;
  HostedModelsLoader? _models;
  String? _hostedPick;
  bool _picked = false;

  bool get _hasSource => widget.sourceMachineId?.isNotEmpty == true;
  bool get _placesWithoutSource => !_hasSource || widget.placesWithoutSource;
  bool get _offersHosted => widget.hostedAvailable && !_placesWithoutSource;

  bool get _hostedSelected =>
      _offersHosted &&
      widget.controller != null &&
      (target == _cloudTarget || widget.targets.isEmpty);

  @override
  void dispose() {
    _models?.dispose();
    super.dispose();
  }

  bool _isSelectable(Map<String, dynamic> machine) =>
      !_placesWithoutSource || machine['status'] == 'online';

  bool _targetIsSelectable(String? id) =>
      widget.targets.any((m) => '${m['id']}' == id && _isSelectable(m));

  String get _firstTarget {
    final first = widget.targets.where(_isSelectable).firstOrNull;
    return first == null ? '' : '${first['id']}';
  }

  @override
  void didUpdateWidget(AgentMigrationStartDialog old) {
    super.didUpdateWidget(old);
    // Web: a target that is no longer offered falls back to the first one.
    if (target == _cloudTarget
        ? !_offersHosted
        : !_targetIsSelectable(target)) {
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
    final cloud = _hostedSelected;
    final models = cloud
        ? (_models ??= HostedModelsLoader(widget.controller!)
            ..addListener(() {
              if (mounted) setState(() {});
            }))
        : null;
    models?.ensure(true);
    final view = models?.view;
    final shownPick =
        view == null || view.locked || !hostedModelPickerShown(view)
        ? null
        : (_picked ? _hostedPick : null);
    final source = widget.sourceName ?? raftText(context, 'Unknown computer');
    return RaftFormDialog(
      title: _offersHosted
          ? 'Move Agent'
          : _placesWithoutSource
          ? 'Move to another computer'
          : 'Move to Another Computer',
      fields: const [],
      submitLabel: failure?.recoveryOpenComputers == true
          ? 'Try again'
          : cloud
          ? 'Move to the Cloud'
          : _placesWithoutSource
          ? 'Move'
          : 'Move to Another Computer',
      busyLabel: 'Starting migration…',
      submitEnabled:
          (cloud || target.isNotEmpty) &&
          !(cloud && models?.status == HostedModelsStatus.loading),
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftField(
            label: raftText(
              context,
              _offersHosted ? 'Move to' : 'Target computer',
            ),
            // Web asks nothing when the dialog is closed after only a target
            // change: the picker's text stays out of the unsaved-input guard.
            child: RaftUnsavedGuardIgnore(
              child: RaftAgentCombobox(
                key: const ValueKey('migration-target-computer'),
                label: 'Target computer',
                semanticLabel: raftText(context, 'Target computer'),
                emptyLabel: 'No matches',
                placeholder: raftText(context, 'No other computers available'),
                enabled: widget.targets.isNotEmpty || _offersHosted,
                value: cloud ? _cloudTarget : target,
                items: [
                  for (final m in widget.targets)
                    RaftComboboxItem(
                      '${m['id']}',
                      '${m['name']}',
                      enabled: _isSelectable(m),
                      description: _isSelectable(m)
                          ? null
                          : raftText(context, 'Offline'),
                    ),
                  if (_offersHosted)
                    RaftComboboxItem(_cloudTarget, raftText(context, 'Cloud')),
                ],
                onSelected: (id) => setState(() => target = id),
              ),
            ),
          ),
          if (cloud && hostedModelPickerShown(view)) ...[
            const SizedBox(height: RaftSpace.x4),
            RaftField(
              label: raftText(context, 'Model'),
              child: RaftUnsavedGuardIgnore(
                child: HostedModelChoice(
                  loader: models!,
                  value: shownPick,
                  onChanged: (id) => setState(() {
                    _hostedPick = id;
                    _picked = true;
                  }),
                ),
              ),
            ),
          ],
          const SizedBox(height: RaftSpace.x4),
          if (cloud)
            // Said before starting: the move to the cloud is final once
            // confirmed.
            Column(
              key: const ValueKey('agent-migration-hosted-notes'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, note) in [
                  'The agent stops on {source} while the cloud checks its files and you review what moves.',
                  'Its workspace files will be stored in the cloud, and the copy on {source} will be archived.',
                  "The current session context isn't carried over: the agent starts a new session in the cloud.",
                  "You'll need to reconnect GitHub once after the move.",
                  "Once you confirm the move, it can't be undone.",
                ].indexed) ...[
                  if (i > 0) const SizedBox(height: RaftSpace.x2),
                  Text(
                    '• ${raftFormat(context, note, {'source': source})}',
                    style: body,
                  ),
                ],
              ],
            )
          else if (_placesWithoutSource)
            Text(
              raftText(
                context,
                _hasSource
                    ? "This agent's Computer lost its access to the server, so its files can't be brought over. It moves to the computer you choose and starts a fresh session there the next time it gets a message."
                    : 'This agent is not on any computer, so there is nothing to bring over. It moves to the computer you choose and starts a fresh session there the next time it gets a message.',
              ),
              style: body,
            )
          else ...[
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
        ],
      ),
      errorContent: (context, error) => error is AgentMigrationStartFailure
          ? _StartFailureView(error.presentation, widget.openComputers)
          : null,
      onSubmit: (_) async {
        try {
          if (cloud) {
            await widget.startHosted!(hostedModelToSend(view, shownPick));
          } else {
            await widget.start(target);
          }
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
                    ? 'Open Computer Settings'
                    : 'Open Computers',
              ),
              glyph: RaftGlyph.externalLink,
              uiVariant: RaftButtonVariant.link,
              size: RaftButtonRecipeSize.sm,
              onPressed: () => openComputers(computerId),
            ),
          ),
        ],
      ],
    );
  }
}
