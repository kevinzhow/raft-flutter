// Web components/agentMigration/{MigrationProgressPanel,MigrationErrorContent,
// MigrationReference}.tsx: the live progress of one migration and its
// failure / attention content.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/migration_error.dart';
import 'agent_migration_hosted.dart';
import 'agent_migration_presentation.dart';
import 'agent_migration_retry.dart';

extension MigrationTextResolve on MigrationText {
  /// The text in the current locale with its values filled in.
  String text(BuildContext context) => resolve((s) => raftText(context, s));
}

/// Web MigrationProgressPanel. [onCancel] is null unless the viewer may cancel
/// (the panel additionally requires an active, cancellable run).
class MigrationProgressPanel extends StatelessWidget {
  const MigrationProgressPanel({
    super.key,
    required this.migration,
    required this.machines,
    required this.now,
    required this.formatTimestamp,
    this.onCancel,
    this.review,
    this.agentName = '',
    this.currentUserId,
  });
  final Map<String, dynamic> migration;
  final List<Map<String, dynamic>> machines;
  final DateTime now;
  final String Function(String value) formatTimestamp;
  final VoidCallback? onCancel;
  final String agentName;
  final String? currentUserId;

  /// A move to the cloud waiting for the user's confirm: the review, whose own
  /// Cancel sits beside Confirm (so the panel shows none).
  final Widget? review;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hosted = isHostedMigration(migration);
    final steps = hosted
        ? hostedMigrationProgressSteps
        : migrationProgressSteps;
    final state = migration['state'] as String?;
    final phase = migrationPhase(state);
    final presentation = migrationNoticePresentation(
      migration,
      machines,
      now: now,
      formatTimestamp: formatTimestamp,
    );
    final completed = phase == 'completed';
    final failed = migrationShownFailed(migration);
    final canceled = phase == 'canceled';
    final active = phase == 'active';
    final attention = migration['cancelNeedsAttention'] == true;
    final endedFailure = !hosted && !attention && phase == 'failed';
    final retry = isAgentMigrationRetry(migration)
        ? MigrationRetryDetails(migration, agentName, currentUserId)
        : null;
    final migrationRef = '${migration['migrationRef']}';
    final details = [
      ...?retry?.entries(
        context,
        failed: phase == 'failed',
        completed: completed,
      ),
      if (endedFailure)
        RaftDescriptionEntry(
          raftText(context, 'Migration ID'),
          migrationRef,
          detailsChild: MigrationReference(
            migrationRef: migrationRef,
            valueOnly: true,
          ),
        ),
    ];
    final cancelRequested =
        state != null && state.startsWith('cancel_requested_');
    final target = MigrationText('{target}', {
      'target': migrationNoticeTargetLabel(machines, migration),
    }).text(context);
    String withTarget(String source) =>
        raftFormat(context, source, {'target': target});
    final status = completed
        ? MigrationStepStatus.finish
        : failed || attention
        ? MigrationStepStatus.error
        : canceled
        ? MigrationStepStatus.wait
        : MigrationStepStatus.process;
    final body = presentation.message;
    return Semantics(
      container: true,
      label: withTarget(hosted ? 'Move to the cloud' : 'Migration to {target}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!endedFailure) ...[
            Text(
              withTarget(migrationPanelHeader(migration)),
              style: RaftTypography.heading(t, size: 14, line: 17.5),
            ),
            const SizedBox(height: RaftSpace.x3),
          ],
          MigrationSteps(
            labels: steps,
            current: completed
                ? steps.length - 1
                : migrationProgressStep(migration),
            status: status,
            spinning:
                active &&
                review == null &&
                status == MigrationStepStatus.process,
            semanticLabel: withTarget(
              hosted
                  ? 'Progress of the move to the cloud'
                  : 'Migration progress to {target}',
            ),
          ),
          const SizedBox(height: RaftSpace.x3),
          // Problems keep the warning banner; normal progress is plain text.
          if (failed || attention)
            RaftBanner(
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              glyph: endedFailure ? RaftGlyph.triangleAlert : null,
              live: !endedFailure,
              title: !endedFailure && (failed || cancelRequested)
                  ? presentation.title.text(context)
                  : null,
              descriptionBuilder: (style) => endedFailure
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (presentation.placement case final placement?)
                          Text(placement.text(context), style: style),
                        Text(body.text(context), style: style),
                        if (retry != null)
                          Text(
                            raftFormat(
                              context,
                              "This was {agent}'s one retry; a person needs to start the next migration.",
                              {'agent': agentName},
                            ),
                            style: style,
                          ),
                      ],
                    )
                  : MigrationErrorContent(
                      presentation: presentation,
                      style: style,
                    ),
            )
          else
            Semantics(
              liveRegion: true,
              child: DefaultTextStyle.merge(
                style: RaftTypography.body(
                  t,
                  size: 14,
                  line: 20,
                  color: t.muted,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cancelRequested)
                      Text(
                        presentation.title.text(context),
                        style: RaftTypography.body(
                          t,
                          size: 14,
                          line: 20,
                          weight: FontWeight.w700,
                          color: t.muted,
                        ),
                      ),
                    Text(body.text(context)),
                  ],
                ),
              ),
            ),
          if (retry != null) ...[
            const SizedBox(height: RaftSpace.x3),
            RaftCssText(
              retry.note(context),
              style: t.scale(
                RaftTypeScale.callout,
                color: t.ui.foregroundMuted,
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: RaftSpace.x3),
            RaftDescriptionList(entries: details),
          ],
          if (!endedFailure && (failed || attention)) ...[
            const SizedBox(height: RaftSpace.x3),
            MigrationReference(migrationRef: migrationRef),
          ],
          if (review != null) ...[
            const SizedBox(height: RaftSpace.x3),
            // Its own semantics node: the review's alert must not merge with the
            // status line above it (a live region).
            Semantics(container: true, explicitChildNodes: true, child: review),
          ],
          if (review == null &&
              active &&
              onCancel != null &&
              canCancelMigration(migration)) ...[
            const SizedBox(height: RaftSpace.x3),
            Align(
              alignment: Alignment.centerRight,
              child: RaftButton(
                label: raftText(context, 'Cancel Migration'),
                tone: RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.sm,
                onPressed: onCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

typedef MigrationStepStatus = RaftStepStatus;

/// raft-ui `Steps` (size sm) as the Web progress panel uses it: one row when
/// every label fits beside the others, stacked otherwise. [current] is the
/// 0-based step the migration is on; the steps before it are finished and
/// [status] applies to it.
class MigrationSteps extends StatelessWidget {
  const MigrationSteps({
    super.key,
    required this.current,
    required this.status,
    required this.semanticLabel,
    this.labels = migrationProgressSteps,
    this.spinning = false,
  });

  /// The step names (English source): the computer move's or the cloud's.
  final List<String> labels;
  final int current;
  final MigrationStepStatus status;
  final String semanticLabel;
  final bool spinning;

  @override
  Widget build(BuildContext context) => RaftSteps(
    current: current,
    status: status,
    semanticLabel: semanticLabel,
    fitLabels: true,
    finishLabel: 'done',
    errorLabel: 'failed',
    steps: [
      for (final (index, label) in labels.indexed)
        RaftStep(
          title: label,
          icon: spinning && index == current
              ? const RaftSpinner(recipeSize: RaftSpinnerRecipeSize.xs)
              : null,
        ),
    ],
  );
}

/// [base] (the banner's inherited text style) in bold.
TextStyle _bold(RaftTokens t, TextStyle base) {
  final size = base.fontSize ?? 14;
  return RaftTypography.body(
    t,
    size: size,
    line: size * (base.height ?? 20 / 14),
    weight: FontWeight.w700,
    color: base.color,
  );
}

/// Web MigrationErrorContent: where the agent is, what happened, the issues,
/// and the collapsible technical details.
class MigrationErrorContent extends StatelessWidget {
  const MigrationErrorContent({
    super.key,
    required this.presentation,
    required this.style,
  });
  final MigrationPresentation presentation;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final placement = presentation.placement;
    return DefaultTextStyle.merge(
      style: style,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (placement != null) ...[
            Text(placement.text(context), style: _bold(t, style)),
            const SizedBox(height: RaftSpace.x1_5),
          ],
          Text(presentation.message.text(context)),
          for (final issue in presentation.issues)
            Padding(
              padding: const EdgeInsets.only(
                left: RaftSpace.x2,
                top: RaftSpace.x1,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(issue.text(context))),
                ],
              ),
            ),
          if (presentation.technicalCode != null ||
              presentation.diagnosticRef != null) ...[
            const SizedBox(height: RaftSpace.x1_5),
            _TechnicalDetails(
              technicalCode: presentation.technicalCode,
              diagnosticRef: presentation.diagnosticRef,
              style: RaftTypography.body(t, size: 12, line: 16, color: t.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// `<details>`: a bold "Technical details" summary toggling the codes.
class _TechnicalDetails extends StatefulWidget {
  const _TechnicalDetails({
    required this.technicalCode,
    required this.diagnosticRef,
    required this.style,
  });
  final String? technicalCode, diagnosticRef;
  final TextStyle style;
  @override
  State<_TechnicalDetails> createState() => _TechnicalDetailsState();
}

class _TechnicalDetailsState extends State<_TechnicalDetails> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final mono = RaftTypography.mono(t, color: t.ink);
    Widget row(String label, String value) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${raftText(context, label)}: '),
          TextSpan(text: value, style: mono),
        ],
      ),
    );
    return DefaultTextStyle.merge(
      style: widget.style,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => open = !open),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftIcon(
                    open ? RaftGlyph.chevronDown : RaftGlyph.chevronRight,
                    size: 12,
                  ),
                  const SizedBox(width: RaftSpace.x1),
                  Text(
                    raftText(context, 'Technical Details'),
                    style: _bold(t, widget.style),
                  ),
                ],
              ),
            ),
          ),
          if (open) ...[
            if (widget.technicalCode != null)
              row('Error code', widget.technicalCode!),
            if (widget.diagnosticRef != null)
              row('Diagnostic reference', widget.diagnosticRef!),
          ],
        ],
      ),
    );
  }
}

/// Web MigrationReference: the support reference with a copy action.
class MigrationReference extends StatefulWidget {
  const MigrationReference({
    super.key,
    required this.migrationRef,
    this.valueOnly = false,
  });
  final String migrationRef;
  final bool valueOnly;
  @override
  State<MigrationReference> createState() => _MigrationReferenceState();
}

class _MigrationReferenceState extends State<MigrationReference> {
  bool copied = false;
  Timer? resetCopyStatus;

  Future<void> copy() async {
    final reference = widget.migrationRef;
    try {
      await Clipboard.setData(ClipboardData(text: reference));
    } on PlatformException {
      if (mounted && copied) setState(() => copied = false);
      return;
    }
    if (!mounted || reference != widget.migrationRef) return;
    setState(() => copied = true);
    resetCopyStatus?.cancel();
    resetCopyStatus = Timer(
      const Duration(seconds: 2),
      () => setState(() => copied = false),
    );
  }

  @override
  void dispose() {
    resetCopyStatus?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = copied ? 'Migration ID Copied' : 'Copy Migration ID';
    final glyph = copied ? RaftGlyph.check : RaftGlyph.copy;
    final semanticLabel = copied
        ? raftText(context, label)
        : raftFormat(context, 'Copy migration ID {ref}', {
            'ref': widget.migrationRef,
          });
    return Row(
      children: [
        if (!widget.valueOnly) ...[
          Text(
            raftText(context, 'Migration ID'),
            style: RaftTypography.body(
              t,
              size: 11,
              line: 16,
              weight: FontWeight.w700,
              color: t.muted,
            ),
          ),
          const SizedBox(width: RaftSpace.x1_5),
        ],
        Flexible(
          child: RaftSelectionArea(
            child: Text(
              widget.migrationRef,
              style: RaftTypography.mono(t, size: 11, line: 16, color: t.ink),
            ),
          ),
        ),
        const SizedBox(width: RaftSpace.x1_5),
        RaftButton(
          glyph: glyph,
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.iconMd,
          tooltip: raftText(context, label),
          semanticLabel: semanticLabel,
          onPressed: copy,
        ),
      ],
    );
  }
}
