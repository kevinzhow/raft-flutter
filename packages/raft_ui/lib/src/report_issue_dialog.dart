import 'overlays/dialog.dart' show RaftDialog;

// Presentation of the Web agent Report Issue dialog
// (packages/web/src/components/agent/ReportIssueDialog.tsx): a `DialogCard`
// (`max-w-sm`, `narrow="sheet"`) with the agent Card, the description field,
// the `Include` checkboxes, the sensitive-data banner with the consent
// checkbox, and the "Report submitted" confirmation. The app adapter owns the
// upload (scope attestation, feedback-export worker, ticket) and passes it in
// as callbacks.
import 'raft/checkbox.dart' show RaftCheckbox;

import 'dart:async';

import 'package:flutter/material.dart';

import 'form_presentation.dart';

import 'package:flutter/foundation.dart';

import 'banner.dart';
import 'card.dart' show RaftCard;
import 'design_primitives.dart' show RaftLayoutMetrics;
import 'dialog_card.dart';
import 'error_presentation.dart';
import 'form_controls.dart' show RaftTextarea;
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/button.dart' show RaftButton, RaftButtonSize, RaftButtonVariant;
import 'raft/css_box.dart' show raftControlBorderPx;
import 'raft/ui_tokens.dart';
import 'stacked_actions.dart' show RaftActionRow;
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale, RaftTypeStyle;

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
    this.serverSlug,
  });

  /// `feedbackTicketPath` links into `/s/<slug>/settings/feedback`: without a
  /// slug the ticket has no link and the dialog offers no View ticket button.
  final String? serverSlug;

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
    serverSlug: serverSlug,
  );
}

/// `TranscriptRequestState` (feedback/transcriptRequestState.ts): the first
/// four are about the app's own request and claim nothing about the record;
/// [attached] and [notAttached] are what the agent's computer answered (the
/// `feedback_report:session_record` push).
enum RaftTranscriptRequestState {
  pending,
  requested,
  requestFailed,
  requestUnconfirmed,
  attached,
  notAttached;

  /// Whether this is the agent's computer's answer.
  bool get isAnswer => this == attached || this == notAttached;
}

/// `nextTranscriptRequestState`: an answer from the agent's computer is final.
/// The push can arrive before the app has processed its own request's 202 (or
/// before the cap fires), and a request state that comes after it must not
/// replace it.
RaftTranscriptRequestState raftNextTranscriptRequestState(
  RaftTranscriptRequestState? current,
  RaftTranscriptRequestState incoming,
) => current != null && current.isAnswer && !incoming.isAnswer
    ? current
    : incoming;

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
      if (mounted && id != null) {
        setState(() => receipt = current.withTicket(id));
      }
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

  TextStyle _type(
    RaftTokens t,
    RaftTypeStyle role, {
    FontWeight? weight,
    Color? color,
    bool mono = false,
  }) => t
      .scale(role, weight: weight, color: color, mono: mono)
      .copyWith(leadingDistribution: TextLeadingDistribution.even);

  Widget _checkRow(
    RaftTokens t, {
    required Key key,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required String label,
    CrossAxisAlignment align = CrossAxisAlignment.center,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    Widget? labelWidget,
    TextStyle? style,
  }) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 32),
    child: Padding(
      padding: padding,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: Row(
          key: key,
          crossAxisAlignment: align,
          children: [
            RaftCheckbox(
              value: value,
              onChanged: onChanged,
              semanticLabel: label,
            ),
            const SizedBox(width: 8),
            Expanded(
              child:
                  labelWidget ??
                  RaftCssText(
                    label,
                    style:
                        style ??
                        _type(
                          t,
                          RaftTypeScale.callout,
                          weight: FontWeight.w600,
                          color: t.ui.foreground,
                        ),
                  ),
            ),
          ],
        ),
      ),
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
    final hint12 = _type(t, RaftTypeScale.caption, color: t.ui.foregroundHint);
    final inHead = RaftFormFrame.sheetOf(context);
    final submitButton = RaftButton(
      key: const ValueKey('report-issue-submit'),
      label: tr(loading ? 'Submitting…' : 'Report'),
      uiVariant: RaftButtonVariant.primary,
      uiSize: inHead ? RaftButtonSize.md : RaftButtonSize.lg,
      disabled: loading || !consented,
      onPressed: submit,
    );
    return RaftDialog.card(
      key: const ValueKey('report-issue-dialog'),
      title: 'Report issue',
      footerGap: 0,
      maxWidth: 384,
      onClose: widget.onClose,
      sheetCommit: submitButton,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `Card className="mb-4 block px-3 py-2"`
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RaftCard(
              key: const ValueKey('report-issue-agent'),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RaftDialogSectionEyebrow(tr('Agent')),
                  // `mt-0.5 text-subhead font-semibold text-foreground`
                  const SizedBox(height: 4),
                  RaftCssText(
                    widget.agentName,
                    style: _type(
                      t,
                      RaftTypeScale.subhead,
                      weight: FontWeight.w600,
                      color: t.ui.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RaftProductFormField(
              label: 'Describe the issue',
              optional: true,
              // `<Textarea rows={3} className="w-full resize-none">`
              child: RaftTextarea(
                key: const ValueKey('report-issue-description'),
                controller: description,
                rows: 3,
                minHeight:
                    MediaQuery.sizeOf(context).width >=
                        RaftLayoutMetrics.desktopBreakpoint
                    ? 90
                    : 96,
                enabled: !loading,
                hintText: tr('What went wrong? What did you expect?'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // `SectionEyebrow as="div" className="mb-1"`
                RaftDialogSectionEyebrow(
                  tr('Include'),
                  padding: const EdgeInsets.only(bottom: 6),
                ),
                // `flex flex-col gap-1`
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
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
                    if (widget.hasMachine)
                      _checkRow(
                        t,
                        key: const ValueKey('report-issue-transcript'),
                        value: includeSessionTranscript,
                        onChanged: loading
                            ? null
                            : (v) =>
                                  setState(() => includeSessionTranscript = v),
                        label: tr('Runtime session transcript'),
                      ),
                    if (includeSessionTranscript && widget.hasMachine)
                      Padding(
                        // `ml-7 text-caption text-foreground-hint`
                        padding: const EdgeInsets.only(left: 28),
                        child: RaftCssText(
                          tr(
                            "Taken from the agent's computer; it may not have one.",
                          ),
                          style: hint12,
                        ),
                      ),
                    if (widget.canIncludeMachineLog)
                      _checkRow(
                        t,
                        key: const ValueKey('report-issue-machine-log'),
                        align: CrossAxisAlignment.start,
                        padding: const EdgeInsets.symmetric(vertical: 6),
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
                              style: _type(
                                t,
                                RaftTypeScale.callout,
                                weight: FontWeight.w600,
                                color: t.ui.foreground,
                              ),
                            ),
                            RaftCssText(
                              tr(
                                "The last lines of this computer's log. They may include lines from other agents on it.",
                              ),
                              style: hint12,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // `Banner intent="warning" withIcon density="sm" className="mb-4"`
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RaftBanner(
              key: const ValueKey('report-issue-warning'),
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.triangleAlert,
              descriptionBuilder: (style) {
                final lineStyle = _type(
                  t,
                  RaftTypeScale.callout,
                  color: style.color,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _strongText(
                        tr(
                          'This report may contain <strong>prompt history, file paths, and command output</strong>. Sensitive data redaction is best-effort and not guaranteed.',
                        ),
                        lineStyle,
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
                        'I agree to send this report to the Raft team.',
                      ),
                      style: lineStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                );
              },
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
      footer: RaftActionRow(
        gap: 8,
        children: [
          RaftButton(
            key: const ValueKey('report-issue-cancel'),
            label: tr('Cancel'),
            uiVariant: RaftButtonVariant.ghost,
            uiSize: RaftButtonSize.lg,
            disabled: loading,
            onPressed: raftExplicitClose(context, widget.onClose),
          ),
          submitButton,
        ],
      ),
    );
  }

  // ---------------------------------------------------------- submitted

  Widget _submitted(BuildContext context, RaftReportIssueReceipt r) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final hint12 = _type(t, RaftTypeScale.caption, color: t.ui.foregroundHint);
    final ticket = r.ticketId;
    final stickerInk = t.colors['sticker-ink']!;
    final stickerRadius = t.size('radius.sticker', fallback: 4);
    return RaftDialog.card(
      key: const ValueKey('report-issue-submitted'),
      title: 'Report submitted',
      footerGap: 0,
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
                // `size-12 rounded-sticker border-[1.5px] border-sticker-ink
                // bg-success text-sticker-ink`
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.colors['success'],
                    border: Border.all(
                      color: stickerInk,
                      width: raftControlBorderPx(context, 1.5),
                    ),
                    borderRadius: BorderRadius.all(
                      Radius.circular(stickerRadius),
                    ),
                  ),
                  child: RaftIcon(
                    RaftGlyph.circleCheck,
                    size: 24,
                    color: stickerInk,
                  ),
                ),
                Column(
                  children: [
                    RaftCssText(
                      tr('Feedback export uploaded.'),
                      textAlign: TextAlign.center,
                      style: _type(
                        t,
                        RaftTypeScale.subhead,
                        weight: FontWeight.w700,
                        color: t.ui.foreground,
                      ),
                    ),
                    // `mt-1 text-callout text-foreground-muted`
                    const SizedBox(height: 4),
                    RaftCssText(
                      tr(
                        ticket != null
                            ? 'We opened a feedback ticket for this report. Replies from the Raft team will show up there.'
                            : 'The bundle includes the issue description plus the client-side context you selected.',
                      ),
                      textAlign: TextAlign.center,
                      style: _type(
                        t,
                        RaftTypeScale.callout,
                        color: t.ui.foregroundMuted,
                      ),
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
                                RaftTranscriptRequestState.requested => "The agent's computer was asked for its session record. Whether one was attached shows here if it answers.",
                                RaftTranscriptRequestState.requestFailed =>
                                  'Session record request failed.',
                                RaftTranscriptRequestState.requestUnconfirmed => "Couldn't confirm that the session record request reached the server.",
                                RaftTranscriptRequestState.attached =>
                                  'Session record attached.',
                                RaftTranscriptRequestState.notAttached => "Sent without a session record: the agent's computer didn't provide one.",
                              }),
                              style: hint12,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
      footer: RaftActionRow(
        gap: 8,
        children: [
          if (ticket != null &&
              r.serverSlug != null &&
              widget.onViewTicket != null)
            RaftButton(
              key: const ValueKey('report-issue-view-ticket'),
              label: tr('View ticket'),
              uiVariant: RaftButtonVariant.outline,
              uiSize: RaftButtonSize.lg,
              onPressed: () => widget.onViewTicket!(ticket),
            ),
          RaftButton(
            key: const ValueKey('report-issue-done'),
            label: tr('Done'),
            uiVariant: RaftButtonVariant.primary,
            uiSize: RaftButtonSize.lg,
            onPressed: widget.onClose,
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
          tr(label),
          style: _type(
            t,
            RaftTypeScale.caption,
            weight: FontWeight.w600,
            color: t.ui.foregroundMuted,
          ),
        ),
        RaftCssText(
          value,
          style: _type(
            t,
            RaftTypeScale.monoMeta,
            mono: true,
            color: t.ui.foreground,
          ),
        ),
      ],
    );
    return RaftCard(
      key: const ValueKey('report-issue-reference'),
      padding: const EdgeInsets.all(12),
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
              RaftButton(
                key: const ValueKey('report-issue-copy-reference'),
                label: tr(referenceCopied ? 'Copied' : 'Copy report reference'),
                uiVariant: RaftButtonVariant.outline,
                uiSize: RaftButtonSize.md,
                onPressed: copyReference,
              ),
              RaftButton(
                key: const ValueKey('report-issue-retry-ticket'),
                label: tr(ticketRetrying ? 'Retrying…' : 'Retry ticket'),
                uiVariant: RaftButtonVariant.outline,
                uiSize: RaftButtonSize.md,
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
