// Web components/agentMigration/{MigrationProgressPanel,MigrationErrorContent,
// MigrationReference}.tsx: the live progress of one migration and its
// failure / attention content.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/migration_error.dart';
import 'agent_migration_presentation.dart';

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
  });
  final Map<String, dynamic> migration;
  final List<Map<String, dynamic>> machines;
  final DateTime now;
  final String Function(String value) formatTimestamp;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
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
    final cancelRequested =
        state != null && state.startsWith('cancel_requested_');
    final target = MigrationText('{target}', {
      'target': migrationComputerLabel(machines, migration['targetMachineId']),
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
      label: withTarget('Migration to {target}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            withTarget(migrationPanelHeader(migration)),
            style: RaftTypography.heading(t, size: 14, line: 17.5),
          ),
          const SizedBox(height: RaftSpace.x3),
          MigrationSteps(
            current: completed
                ? migrationProgressSteps.length - 1
                : migrationProgressStep(migration),
            status: status,
            semanticLabel: withTarget('Migration progress to {target}'),
          ),
          const SizedBox(height: RaftSpace.x3),
          // Problems keep the warning banner; normal progress is plain text.
          if (failed || attention)
            RaftBanner(
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              title: failed || cancelRequested
                  ? presentation.title.text(context)
                  : null,
              descriptionBuilder: (style) => MigrationErrorContent(
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
          // The reference is for support, so it only appears when something
          // needs attention.
          if (failed || attention) ...[
            const SizedBox(height: RaftSpace.x3),
            MigrationReference(migrationRef: '${migration['migrationRef']}'),
          ],
          if (active && onCancel != null && canCancelMigration(migration)) ...[
            const SizedBox(height: RaftSpace.x3),
            Align(
              alignment: Alignment.centerRight,
              child: RaftButton(
                label: raftText(context, 'Cancel'),
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

enum MigrationStepStatus { wait, process, finish, error }

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
  });
  final int current;
  final MigrationStepStatus status;
  final String semanticLabel;

  static const _indicator = 20.0, _gap = 8.0, _connectorMin = 16.0;
  static const _connectorGap = 8.0;

  MigrationStepStatus _statusOf(int index) => index < current
      ? MigrationStepStatus.finish
      : index == current
      ? status
      : MigrationStepStatus.wait;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final labels = [
      for (final s in migrationProgressSteps) raftText(context, s),
    ];
    final style = RaftTypography.body(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w500,
    );
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: LayoutBuilder(
        builder: (context, box) {
          var needed =
              (labels.length - 1) * (_connectorMin + 2 * _connectorGap);
          for (final label in labels) {
            final painter = TextPainter(
              text: TextSpan(text: label, style: style),
              textDirection: Directionality.of(context),
              textScaler: scaler,
            )..layout();
            needed += _indicator + _gap + painter.width;
            painter.dispose();
          }
          final row = needed <= box.maxWidth;
          Widget step(int i) => _Step(
            index: i,
            label: labels[i],
            status: _statusOf(i),
            style: style,
            doneLabel: raftText(context, 'done'),
            failedLabel: raftText(context, 'failed'),
          );
          if (!row) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(height: RaftSpace.x2),
                  step(i),
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _connectorGap,
                      ),
                      child: Container(
                        height: t.border,
                        color: _statusOf(i - 1) == MigrationStepStatus.finish
                            ? t.accent
                            : t.line,
                      ),
                    ),
                  ),
                step(i),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.label,
    required this.status,
    required this.style,
    required this.doneLabel,
    required this.failedLabel,
  });
  final int index;
  final String label, doneLabel, failedLabel;
  final MigrationStepStatus status;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final fill = switch (status) {
      MigrationStepStatus.finish => t.colors['success'],
      MigrationStepStatus.error => t.colors['danger'],
      MigrationStepStatus.process => t.accent,
      MigrationStepStatus.wait => null,
    };
    final mark = switch (status) {
      MigrationStepStatus.finish => const RaftIcon(RaftGlyph.check, size: 12),
      MigrationStepStatus.error => const RaftIcon(RaftGlyph.x, size: 12),
      _ => null,
    };
    final suffix = switch (status) {
      MigrationStepStatus.finish => doneLabel,
      MigrationStepStatus.error => failedLabel,
      _ => null,
    };
    return Semantics(
      label: suffix == null ? label : '$label, $suffix',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: MigrationSteps._indicator,
            height: MigrationSteps._indicator,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: fill == null ? Border.all(color: t.line) : null,
            ),
            child: mark == null
                ? Text(
                    '${index + 1}',
                    // The digit fills a fixed-size indicator: it grows with
                    // the text size only up to the chrome bound.
                    textScaler: RaftChrome.boundedScalerOf(context),
                    style:
                        RaftTypography.body(
                          t,
                          size: 12,
                          // The line box is the font size so it always fits the 20px circle
                          // (a taller one is clamped by the circle and slides down).
                          line: 12,
                          weight: FontWeight.w500,
                          color: status == MigrationStepStatus.process
                              ? t.canvas
                              : t.muted,
                        ).copyWith(
                          // CSS half-leading, as the Web 20px line box does.
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                  )
                : IconTheme(
                    data: IconThemeData(color: t.canvas),
                    child: mark,
                  ),
          ),
          const SizedBox(width: MigrationSteps._gap),
          Flexible(
            child: Text(
              label,
              style: style.copyWith(
                color: status == MigrationStepStatus.wait
                    ? t.muted
                    : status == MigrationStepStatus.error
                    ? t.colors['danger-strong']
                    : t.strong,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
                    raftText(context, 'Technical details'),
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
  const MigrationReference({super.key, required this.migrationRef});
  final String migrationRef;
  @override
  State<MigrationReference> createState() => _MigrationReferenceState();
}

class _MigrationReferenceState extends State<MigrationReference> {
  bool copied = false;

  Future<void> copy() async {
    await Clipboard.setData(ClipboardData(text: widget.migrationRef));
    if (!mounted) return;
    setState(() => copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Row(
      children: [
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
        Flexible(
          child: RaftSelectionArea(
            child: Text(
              widget.migrationRef,
              style: RaftTypography.mono(t, size: 11, line: 16),
            ),
          ),
        ),
        const SizedBox(width: RaftSpace.x1_5),
        RaftIconButton(
          glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
          visualSize: 20,
          glyphSize: 12,
          tooltip: copied ? 'Migration ID copied' : 'Copy migration ID',
          onPressed: copy,
        ),
      ],
    );
  }
}

/// The agent detail's view of the agent's migration (Web renders the whole
/// progress panel there): the state's header and notice, opening the migration
/// page, which owns the steps, Cancel and the failure details.
class MigrationInlineStatus extends StatelessWidget {
  const MigrationInlineStatus({
    super.key,
    required this.migration,
    required this.machines,
    required this.now,
    required this.formatTimestamp,
    this.onOpen,
  });
  final Map<String, dynamic> migration;
  final List<Map<String, dynamic>> machines;
  final DateTime now;
  final String Function(String value) formatTimestamp;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final presentation = migrationNoticePresentation(
      migration,
      machines,
      now: now,
      formatTimestamp: formatTimestamp,
    );
    final target = MigrationText('{target}', {
      'target': migrationComputerLabel(machines, migration['targetMachineId']),
    }).text(context);
    final header = raftFormat(context, migrationPanelHeader(migration), {
      'target': target,
    });
    final attention =
        migrationShownFailed(migration) ||
        migration['cancelNeedsAttention'] == true;
    final body = presentation.placement == null
        ? presentation.message.text(context)
        : '${presentation.placement!.text(context)} ${presentation.message.text(context)}';
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(header, style: RaftTypography.heading(t, size: 14, line: 20)),
        // The banner is already an alert; plain progress is a live region.
        Semantics(
          liveRegion: !attention,
          child: Text(
            body,
            style: RaftTypography.body(t, size: 14, line: 20, color: t.muted),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: RaftSpace.x3),
      child: attention
          ? RaftBanner(
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              descriptionBuilder: (_) => _tappable(content),
            )
          : _tappable(content),
    );
  }

  Widget _tappable(Widget child) => onOpen == null
      ? child
      : Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: child,
          ),
        );
}
