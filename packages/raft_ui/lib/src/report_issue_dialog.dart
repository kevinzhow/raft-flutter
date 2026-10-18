// Presentation of the Web agent Report Issue dialog
// (packages/web/src/components/agent/ReportIssueDialog.tsx): a `DialogCard`
// (`max-w-sm`) with the agent card, the description field, the `Include`
// checkboxes, the sensitive-data banner with the consent checkbox, and the
// "Report Submitted" confirmation. The app adapter owns the upload (scope
// attestation, feedback-export worker, ticket) and passes it in as callbacks.
// Tailwind classes written in the Web JSX are resolved in comments.
import 'dart:async';

import 'package:flutter/material.dart';

import 'form_presentation.dart';

import 'package:flutter/foundation.dart';

import 'banner.dart';
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'error_presentation.dart';
import 'form_controls.dart' show RaftTextarea;
import 'icons.dart';
import 'indicators.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipes/button_variants.g.dart';
import 'theme.dart';

/// What the user ticked.
@immutable
class RaftReportIssueOptions {
  const RaftReportIssueOptions({
    required this.description,
    required this.includeRecentMessages,
    required this.includeActivityLog,
    required this.includeTrajectoryLog,
    required this.includeSessionTranscript,
    required this.includeMachineLogTail,
  });
  final String description;
  final bool includeRecentMessages,
      includeActivityLog,
      includeTrajectoryLog,
      includeSessionTranscript,
      includeMachineLogTail;
}

/// `SubmittedReport` of the Web dialog.
@immutable
class RaftReportIssueReceipt {
  const RaftReportIssueReceipt({
    required this.reportId,
    required this.serverId,
    this.ticketId,
    this.issueDescription,
    this.transcriptAttachmentRequested = false,
  });

  /// Null when the bundle uploaded but filing the ticket failed.
  final String? ticketId;
  final String reportId, serverId;
  final String? issueDescription;
  final bool transcriptAttachmentRequested;

  RaftReportIssueReceipt withTicket(String id) => RaftReportIssueReceipt(
    reportId: reportId,
    serverId: serverId,
    ticketId: id,
    issueDescription: issueDescription,
    transcriptAttachmentRequested: transcriptAttachmentRequested,
  );
}

/// `TranscriptRequestState`: only the HTTP result of the app's own request.
enum RaftTranscriptRequestState {
  pending,
  requested,
  requestFailed,
  requestUnconfirmed,
}

/// A step failure with the message the dialog shows (Web `stepError`).
class RaftReportIssueFailure extends RaftUserError {
  const RaftReportIssueFailure(super.message);
}

/// Web `ReportIssueDialog`. [onSubmit] resolves to the receipt or throws a
/// [RaftReportIssueFailure]; [onRetryTicket] resolves to the new ticket id or
/// null; [transcriptState] follows the session-record request started by the
/// submission.
class RaftReportIssueDialog extends StatefulWidget {
  const RaftReportIssueDialog({
    super.key,
    required this.agentName,
    required this.hasMachine,
    required this.canIncludeMachineLog,
    required this.onSubmit,
    required this.onClose,
    this.onRetryTicket,
    this.onCopyReference,
    this.onViewTicket,
    this.transcriptState,
  });
  final String agentName;

  /// `agent.machineId` is set.
  final bool hasMachine;

  /// The agent's machine is attached by the current user.
  final bool canIncludeMachineLog;
  final Future<RaftReportIssueReceipt> Function(RaftReportIssueOptions options)
  onSubmit;
  final Future<String?> Function(RaftReportIssueReceipt receipt)? onRetryTicket;
  final Future<void> Function(RaftReportIssueReceipt receipt)? onCopyReference;
  final void Function(String ticketId)? onViewTicket;
  final ValueListenable<RaftTranscriptRequestState?>? transcriptState;
  final VoidCallback onClose;
  @override
  State<RaftReportIssueDialog> createState() => _RaftReportIssueDialogState();
}

class _RaftReportIssueDialogState extends State<RaftReportIssueDialog> {
  final description = TextEditingController();
  bool includeRecentMessages = true,
      includeActivityLog = true,
      includeTrajectoryLog = true;
  late bool includeSessionTranscript = widget.hasMachine;
  // Derived from ownership until the user touches the box.
  bool? machineLogTailChoice;
  bool consented = false, loading = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next submit starts; the dialog state is dropped when it closes.
  String? error;
  RaftReportIssueReceipt? receipt;
  bool referenceCopied = false, ticketRetrying = false;

  bool get includeMachineLogTail =>
      machineLogTailChoice ?? widget.canIncludeMachineLog;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!consented || loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.onSubmit(
        RaftReportIssueOptions(
          description: description.text,
          includeRecentMessages: includeRecentMessages,
          includeActivityLog: includeActivityLog,
          includeTrajectoryLog: includeTrajectoryLog,
          includeSessionTranscript: includeSessionTranscript,
          includeMachineLogTail:
              widget.canIncludeMachineLog && includeMachineLogTail,
        ),
      );
      if (mounted) setState(() => receipt = result);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = raftErrorMessage(
          context,
          e,
          fallback: 'Failed to submit issue report',
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> retryTicket() async {
    final current = receipt;
    if (current == null || current.ticketId != null || ticketRetrying) return;
    setState(() => ticketRetrying = true);
    try {
      final id = await widget.onRetryTicket?.call(current);
      if (mounted && id != null)
        setState(() => receipt = current.withTicket(id));
    } finally {
      if (mounted) setState(() => ticketRetrying = false);
    }
  }

  Future<void> copyReference() async {
    final current = receipt;
    if (current == null) return;
    await widget.onCopyReference?.call(current);
    if (mounted) setState(() => referenceCopied = true);
  }

  @override
  Widget build(BuildContext context) {
    final submitted = receipt;
    return RaftModalBackdrop(
      child: Material(
        type: MaterialType.transparency,
        child: submitted != null
            ? _submitted(context, submitted)
            : _form(context),
      ),
    );
  }

  // ------------------------------------------------------------ helpers

  TextStyle _text(
    RaftTokens t, {
    double size = 14,
    double line = 20,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => RaftTypography.inherited(
    t,
    size: size,
    line: line,
    weight: weight,
    color: color,
  ).copyWith(leadingDistribution: TextLeadingDistribution.even);

  /// `text-foreground-muted theme-brutal:text-black/60`.
  Color _muted(RaftTokens t) => t.brutal
      ? Colors.black.withValues(alpha: .6)
      : t.colors['foreground-muted']!;

  Color _strong(RaftTokens t) => t.brutal ? Colors.black : t.strong;

  /// `border-2 border-line-muted theme-brutal:border-black bg-layer-panel
  /// theme-brutal:bg-white`.
  BoxDecoration _panelBox(RaftTokens t) => BoxDecoration(
    color: t.brutal ? Colors.white : t.colors['layer-panel'],
    border: Border.all(
      color: t.brutal ? Colors.black : t.colors['line-muted']!,
      width: 2,
    ),
  );

  Widget _checkRow(
    RaftTokens t, {
    required Key key,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required String label,
    CrossAxisAlignment align = CrossAxisAlignment.center,
    Widget? labelWidget,
    TextStyle? style,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onChanged == null ? null : () => onChanged(!value),
    child: Row(
      key: key,
      crossAxisAlignment: align,
      children: [
        RaftCheckbox(value: value, onChanged: onChanged, semanticLabel: label),
        const SizedBox(width: 8),
        Expanded(
          child:
              labelWidget ??
              RaftCssText(label, style: style ?? _text(t, color: t.ink)),
        ),
      ],
    ),
  );

  /// `<strong>` runs of a catalog message.
  Widget _strongText(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    final tag = RegExp(r'<strong>(.*?)</strong>', dotAll: true);
    var at = 0;
    for (final m in tag.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      spans.add(
        TextSpan(
          text: m[1],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(children: spans), style: style);
  }

  // --------------------------------------------------------------- form

  Widget _form(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final muted12 = _text(t, size: 12, line: 16, color: _muted(t));
    return RaftDialogCard(
      key: const ValueKey('report-issue-dialog'),
      title: 'Report Issue',
      footerGap: 0,
      titleGlyph: RaftGlyph.bug,
      maxWidth: 384,
      onClose: widget.onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `mb-4 border-2 ... px-3 py-2`
          Container(
            key: const ValueKey('report-issue-agent'),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: _panelBox(t),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // `<SectionEyebrow>` is an inline span: its 12px text sits in
                // the card's 24px line box.
                SizedBox(
                  height: 24,
                  child: Padding(
                    // Baseline of the 16px strut: 5px below the box top.
                    // ds-allow: Web ReportIssueDialog.tsx SectionEyebrow inline span in the 24px line box (browser baseline offset, no class)
                    padding: const EdgeInsets.only(top: 5),
                    child: RaftDialogSectionEyebrow(tr('Agent')),
                  ),
                ),
                // `mt-0.5 font-bold`
                const SizedBox(height: 2),
                RaftCssText(
                  widget.agentName,
                  style: _text(
                    t,
                    size: 16,
                    line: 24,
                    weight: FontWeight.w700,
                    color: _strong(t),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RaftProductFormField(
              label: 'Describe the issue',
              optional: true,
              // `<Textarea rows={3} className="w-full resize-none p-2 text-sm">`
              child: RaftTextarea(
                key: const ValueKey('report-issue-description'),
                controller: description,
                rows: 3,
                enabled: !loading,
                hintText: tr('What went wrong? What did you expect?'),
                textStyle: const TextStyle(fontSize: 14, height: 20 / 14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // `SectionEyebrow as="div" mb-1`
                RaftDialogSectionEyebrow(
                  tr('Include'),
                  padding: const EdgeInsets.only(bottom: 4),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RaftCssText(
                    tr(
                      "These are included by default — untick anything you don't want to send.",
                    ),
                    style: muted12,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RaftCssText(
                    tr(
                      'The machine summary sent with every report (versions, failure counts, trace fields) is structured data with no free text.',
                    ),
                    style: muted12,
                  ),
                ),
                // `flex flex-col gap-1.5`
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 6,
                  children: [
                    _checkRow(
                      t,
                      key: const ValueKey('report-issue-recent-messages'),
                      value: includeRecentMessages,
                      onChanged: loading
                          ? null
                          : (v) => setState(() => includeRecentMessages = v),
                      label: tr('Recent DM messages with this agent'),
                    ),
                    _checkRow(
                      t,
                      key: const ValueKey('report-issue-live-activity'),
                      value: includeActivityLog,
                      onChanged: loading
                          ? null
                          : (v) => setState(() => includeActivityLog = v),
                      label: tr('Recent live agent activity'),
                    ),
                    _checkRow(
                      t,
                      key: const ValueKey('report-issue-activity-history'),
                      value: includeTrajectoryLog,
                      onChanged: loading
                          ? null
                          : (v) => setState(() => includeTrajectoryLog = v),
                      label: tr('Activity tab history'),
                    ),
                    _checkRow(
                      t,
                      key: const ValueKey('report-issue-transcript'),
                      value: includeSessionTranscript,
                      onChanged: loading || !widget.hasMachine
                          ? null
                          : (v) => setState(() => includeSessionTranscript = v),
                      label: tr('Runtime session transcript'),
                    ),
                    if (includeSessionTranscript && widget.hasMachine)
                      Padding(
                        // `ml-6 text-xs`
                        padding: const EdgeInsets.only(left: 24),
                        child: RaftCssText(
                          tr(
                            "The agent's computer is asked for its session record; it may not have one.",
                          ),
                          style: muted12,
                        ),
                      ),
                    if (widget.canIncludeMachineLog)
                      _checkRow(
                        t,
                        key: const ValueKey('report-issue-machine-log'),
                        align: CrossAxisAlignment.start,
                        value: includeMachineLogTail,
                        onChanged: loading || !includeSessionTranscript
                            ? null
                            : (v) => setState(() => machineLogTailChoice = v),
                        label: tr(
                          'Machine runner log tail (your own machine only)',
                        ),
                        labelWidget: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RaftCssText(
                              tr(
                                'Machine runner log tail (your own machine only)',
                              ),
                              style: _text(t, color: t.ink),
                            ),
                            RaftCssText(
                              tr(
                                "Last lines of this machine's runner log — free text, including lines from other agents on it. Size-bounded; visible to everyone who can read this report, including agents. Secret masking covers known credential shapes only — a floor, not a guarantee. Requires the runtime transcript above.",
                              ),
                              style: muted12,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (!widget.hasMachine)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: RaftCssText(
                      tr(
                        'Runtime transcript upload is unavailable until the agent is assigned to a machine.',
                      ),
                      style: muted12,
                    ),
                  ),
              ],
            ),
          ),
          // `Banner intent="warning" withIcon density="sm" mb-5`
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: RaftBanner(
              key: const ValueKey('report-issue-warning'),
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.circleAlert,
              descriptionBuilder: (style) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _strongText(
                      tr(
                        'This report may contain <strong>prompt history, file paths, and command output</strong>. Sensitive data redaction is best-effort and not guaranteed.',
                      ),
                      style.copyWith(
                        color: t.brutal
                            ? Colors.black.withValues(alpha: .8)
                            : t.colors['foreground-muted'],
                      ),
                    ),
                  ),
                  _checkRow(
                    t,
                    key: const ValueKey('report-issue-consent'),
                    value: consented,
                    onChanged: loading
                        ? null
                        : (v) => setState(() => consented = v),
                    label: tr(
                      'I understand that everyone in the Botiverse workspace, including agents, can read this report and its selected diagnostic data, and I consent to submit it.',
                    ),
                    // No colour class: the label inherits the banner's text.
                    style: _text(
                      t,
                      size: 12,
                      line: 16,
                      weight: FontWeight.w700,
                      color: style.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RaftErrorBanner(
                error!,
                key: const ValueKey('report-issue-error'),
                bold: true,
              ),
            ),
        ],
      ),
      footer: Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 8,
        children: [
          RaftRecipeButton(
            key: const ValueKey('report-issue-cancel'),
            label: tr('Cancel'),
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStep: RaftTextSteps.sm,
            disabled: loading,
            disabledOpacity: .5,
            onPressed: raftExplicitClose(context, widget.onClose),
          ),
          RaftRecipeButton(
            key: const ValueKey('report-issue-submit'),
            label: tr(loading ? 'Submitting…' : 'Report Issue'),
            variant: RaftButtonRecipeVariant.accent,
            size: RaftButtonRecipeSize.sm,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStep: RaftTextSteps.sm,
            disabled: loading || !consented,
            disabledOpacity: .5,
            onPressed: submit,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- submitted

  Widget _submitted(BuildContext context, RaftReportIssueReceipt r) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final muted12 = _text(t, size: 12, line: 16, color: _muted(t));
    final ticket = r.ticketId;
    return RaftDialogCard(
      key: const ValueKey('report-issue-submitted'),
      title: 'Report Submitted',
      maxWidth: 384,
      onClose: widget.onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `flex flex-col items-center gap-4 py-4`
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              spacing: 16,
              children: [
                // `size-12 border-2 border-line-muted theme-brutal:border-black
                // bg-brutal-lime`
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.product.brutalLime,
                    border: Border.all(
                      color: t.brutal ? Colors.black : t.colors['line-muted']!,
                      width: 2,
                    ),
                  ),
                  child: RaftIcon(
                    RaftGlyph.checkCircle,
                    size: 24,
                    color: t.ink,
                  ),
                ),
                Column(
                  children: [
                    RaftCssText(
                      tr('Feedback export uploaded.'),
                      textAlign: TextAlign.center,
                      style: _text(
                        t,
                        size: 16,
                        line: 24,
                        weight: FontWeight.w700,
                        color: _strong(t),
                      ),
                    ),
                    // `mt-1 text-sm`
                    const SizedBox(height: 4),
                    RaftCssText(
                      tr(
                        ticket != null
                            ? 'We opened a feedback ticket for this report. Replies from the Raft team will show up there.'
                            : 'The bundle includes the issue description plus the client-side context you selected.',
                      ),
                      textAlign: TextAlign.center,
                      style: _text(t, color: _muted(t)),
                    ),
                  ],
                ),
                if (ticket == null) _reference(context, t, r),
                if (r.transcriptAttachmentRequested &&
                    widget.transcriptState != null)
                  ValueListenableBuilder<RaftTranscriptRequestState?>(
                    valueListenable: widget.transcriptState!,
                    builder: (context, state, _) => state == null
                        ? const SizedBox.shrink()
                        : Semantics(
                            liveRegion: true,
                            child: RaftCssText(
                              key: const ValueKey(
                                'report-issue-transcript-state',
                              ),
                              tr(switch (state) {
                                RaftTranscriptRequestState.pending => "Requesting the session record from the agent's computer…",
                                RaftTranscriptRequestState.requested => "The agent's computer was asked for its session record. This screen can't tell whether one was found.",
                                RaftTranscriptRequestState.requestFailed =>
                                  'Session record request failed.',
                                RaftTranscriptRequestState.requestUnconfirmed => "Couldn't confirm that the session record request reached the server.",
                              }),
                              style: muted12,
                            ),
                          ),
                  ),
              ],
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (ticket != null && widget.onViewTicket != null)
                RaftRecipeButton(
                  key: const ValueKey('report-issue-view-ticket'),
                  label: tr('View ticket'),
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStep: RaftTextSteps.sm,
                  onPressed: () => widget.onViewTicket!(ticket),
                ),
              RaftRecipeButton(
                key: const ValueKey('report-issue-done'),
                label: tr('Done'),
                variant: RaftButtonRecipeVariant.success,
                size: RaftButtonRecipeSize.sm,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                textStep: RaftTextSteps.sm,
                onPressed: widget.onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The report reference card shown when the ticket could not be filed.
  Widget _reference(
    BuildContext context,
    RaftTokens t,
    RaftReportIssueReceipt r,
  ) {
    String tr(String s) => raftText(context, s);
    Widget term(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftCssText(
          tr(label).toUpperCase(),
          style: _text(
            t,
            size: 12,
            line: 16,
            weight: FontWeight.w700,
            color: _muted(t),
          ),
        ),
        RaftCssText(
          value,
          style: _text(t, size: 12, line: 16, color: _strong(t)).copyWith(
            fontFamily: t.monoFont,
            fontFamilyFallback: t.fontFallback,
          ),
        ),
      ],
    );
    return Container(
      key: const ValueKey('report-issue-reference'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelBox(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RaftBanner(
              size: RaftBannerRecipeSize.sm,
              description: tr(
                "The report was uploaded, but we couldn't open a feedback ticket for it. Share the reference below with the Raft team.",
              ),
            ),
          ),
          RaftDialogSectionEyebrow(
            tr('Report reference'),
            padding: const EdgeInsets.only(bottom: 4),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
              term('Report ID', r.reportId),
              term('Server ID', r.serverId),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: [
              RaftRecipeButton(
                key: const ValueKey('report-issue-copy-reference'),
                label: tr(referenceCopied ? 'Copied' : 'Copy report reference'),
                variant: RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.sm,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                textStep: RaftTextSteps.xs,
                onPressed: copyReference,
              ),
              RaftRecipeButton(
                key: const ValueKey('report-issue-retry-ticket'),
                label: tr(ticketRetrying ? 'Retrying…' : 'Retry ticket'),
                variant: RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.sm,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                textStep: RaftTextSteps.xs,
                disabled: ticketRetrying,
                onPressed: retryTicket,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
