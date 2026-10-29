// Web components/agentMigration/HostedMigrationReview.tsx: what a move to the
// cloud brings over and what it leaves behind, with the final Confirm
// (`POST /agents/:id/migration/confirm-hosted`). The revision the review was
// shown at goes with the confirm; a stale one re-reads the status so the user
// confirms what is current.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/migration_error.dart';
import '../data/workspace_controller.dart';
import 'agent_migration_hosted.dart';
import 'agent_migration_panel.dart';
import 'agent_migration_presentation.dart';
import 'computer_detail_view.dart' show computerFileSize;
import 'private_route_guard.dart' show workspaceAuthority;

/// How many of a reason's largest skipped paths the review names.
const hostedReviewPathsPerReason = 5;

String hostedConfirmPath(String agentId) =>
    '/agents/${Uri.encodeComponent(agentId)}/migration/confirm-hosted';

class AgentMigrationHostedReview extends StatefulWidget {
  const AgentMigrationHostedReview({
    super.key,
    required this.controller,
    required this.migration,
    required this.summary,
    required this.source,
    required this.deadline,
    required this.onShowCancel,
    required this.onRefresh,
  });

  final WorkspaceController controller;
  final Map<String, dynamic> migration, summary;

  /// The source computer's name.
  final String source;

  /// The formatted transfer deadline, when the status carries one.
  final String? deadline;
  final VoidCallback onShowCancel;
  final Future<void> Function() onRefresh;

  @override
  State<AgentMigrationHostedReview> createState() =>
      _AgentMigrationHostedReviewState();
}

class _AgentMigrationHostedReviewState
    extends State<AgentMigrationHostedReview> {
  WorkspaceController get w => widget.controller;
  bool _submitting = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next Confirm starts; the review is dropped with the migration it describes.
  MigrationPresentation? _error;

  Future<void> _confirm() async {
    if (_submitting) return;
    final authority = workspaceAuthority(w);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await w.command(
        'POST',
        hostedConfirmPath('${widget.migration['agentId']}'),
        data: {
          'migrationRef': widget.migration['migrationRef'],
          'expectedRevision': widget.migration['revision'],
        },
      );
      await widget.onRefresh();
    } catch (e) {
      if (!mounted || authority != workspaceAuthority(w)) return;
      if (e is RaftApiException && e.staleScope) return;
      final code = e is RaftApiException ? e.details['code'] : null;
      setState(
        () => _error = migrationErrorPresentation(
          code: code is String ? code : null,
          context: MigrationErrorContext.status,
        ),
      );
      // Stale or no longer waiting: show what the migration is now.
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _files(BuildContext context, num files, num bytes) => raftFormat(
    context,
    files == 1 ? '{files} file ({size})' : '{files} files ({size})',
    {'files': files, 'size': computerFileSize(bytes)},
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    String tr(String s) => raftText(context, s);
    final term = RaftInfoRow.labelStyle(t);
    final detail = RaftPanelText.profileValue(t);
    final summary = widget.summary;
    final imported = summary['importedFileCount'] is num
        ? summary['importedFileCount'] as num
        : 0;
    final importedBytes = summary['importedBytes'] is num
        ? summary['importedBytes'] as num
        : 0;
    final skipped = [
      if (summary['skipped'] is List)
        for (final g in summary['skipped'] as List)
          if (g is Map && g['count'] is num && (g['count'] as num) > 0)
            Map<String, dynamic>.from(g),
    ];

    Widget row(String label, List<Widget> details, {Key? key}) => RaftGapColumn(
      key: key,
      gap: 2,
      children: [
        RaftCssText(label, style: term),
        ...details,
      ],
    );

    final cancelable = canCancelMigration(widget.migration);
    return RaftSettingsCard(
      key: const ValueKey('hosted-migration-review'),
      child: RaftGapColumn(
        gap: 12,
        children: [
          RaftCssText(
            tr('What moves to the cloud'),
            style: RaftTypography.heading(t, size: 14, line: 17.5),
          ),
          row(tr('Brought over'), [
            RaftCssText(
              key: const ValueKey('hosted-migration-review-imported'),
              _files(context, imported, importedBytes),
              style: detail,
            ),
          ]),
          if (skipped.isEmpty)
            row(tr('Left behind'), [RaftCssText(tr('No files'), style: detail)])
          else
            for (final group in skipped)
              row(
                key: const ValueKey('hosted-migration-review-skipped'),
                raftFormat(context, 'Left behind: {reason}', {
                  'reason': tr(hostedSkipReasonLabel('${group['reason']}')),
                }),
                [
                  RaftCssText(
                    _files(
                      context,
                      group['count'] as num,
                      group['bytes'] is num ? group['bytes'] as num : 0,
                    ),
                    style: detail,
                  ),
                  ..._paths(context, group, t),
                ],
              ),
          RaftCssText(
            raftFormat(
              context,
              'When you confirm, the agent switches to the cloud and the copy on {source} is archived. This can\'t be undone.',
              {'source': widget.source},
            ),
            style: RaftTypography.body(
              t,
              size: 14,
              line: 20,
              color: text.strong,
            ),
          ),
          if (widget.deadline != null)
            RaftCssText(
              raftFormat(
                context,
                'Confirm by {deadline}. After that the move stops and the agent stays on {source}.',
                {'deadline': widget.deadline, 'source': widget.source},
              ),
              style: RaftPanelText.caption(t),
            ),
          if (_error != null)
            RaftBanner(
              key: const ValueKey('hosted-migration-review-error'),
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              descriptionBuilder: (style) =>
                  MigrationErrorContent(presentation: _error!, style: style),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: RaftFlowRow(
              children: [
                RaftButton(
                  key: const ValueKey('hosted-migration-review-cancel'),
                  label: tr('Cancel'),
                  tone: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  onPressed: _submitting || !cancelable
                      ? null
                      : widget.onShowCancel,
                ),
                RaftButton(
                  key: const ValueKey('hosted-migration-review-confirm'),
                  label: _submitting ? tr('Moving…') : tr('Confirm and move'),
                  tone: RaftButtonRecipeVariant.accent,
                  size: RaftButtonRecipeSize.sm,
                  onPressed: _submitting ? null : () => unawaited(_confirm()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _paths(
    BuildContext context,
    Map<String, dynamic> group,
    RaftTokens t,
  ) {
    final all = [
      if (group['largestPaths'] is List)
        for (final p in group['largestPaths'] as List)
          if (p is String) p,
    ];
    final shown = all.take(hostedReviewPathsPerReason).toList();
    final more = (group['count'] as num).toInt() - shown.length;
    final mono = RaftPanelText.monoCaption(t);
    return [
      for (final path in shown) RaftCssText(path, style: mono),
      if (more > 0)
        RaftCssText(
          raftFormat(context, 'and {count} more', {'count': more}),
          style: RaftPanelText.caption(t),
        ),
    ];
  }
}
