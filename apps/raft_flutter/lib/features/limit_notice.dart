import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/attachment_limit_decision.dart';
import '../data/billing_plans.dart';
import '../data/limit_notice_queue.dart';
import '../data/workspace_controller.dart';
import 'limit_notice_history_copy.dart';
import 'workspace_web_billing.dart';

export '../data/attachment_limit_decision.dart'
    show UploadLimitContext, MonthlyUploadQuota;
export 'limit_notice_history_copy.dart' show HistoryLimitScope;

// The Free-plan limit notice (WP-BILL part C). Where Web opens its upgrade
// dialog for a limit, the app shows this: the same title and line as the
// dialog's header for that paywall (Web components/billing/upgradeGateCopy.ts
// and UpgradeDialog.tsx), one "Upgrade to Pro" that opens the Web's upgrade
// for that paywall (`WorkspaceWebBilling.openWebBilling(gate:)`), and Close.
// The upgrade dialog itself, requests to an owner and checkout are not built
// (Kevin 2654e77c: every paid action opens the Web).
//
// Callers (attachments, history, external channels, agent action cards):
//
//   final copy = limitNoticeCopy(context, w, gate: WebBillingGate.history, ...);
//   showLimitNotice(context, w, gate: gate, title: copy.title, hint: copy.hint);

/// The words of one notice.
typedef LimitNoticeCopy = ({String title, String hint});

/// Web `HistoryLimitContext`: what the history window hid where the paywall
/// was met.
class HistoryLimitNotice {
  const HistoryLimitNotice.counted({
    required this.scope,
    required int this.count,
    this.capped = false,
    this.channel = '',
  }) : date = null;

  /// A message a link opened, sent on [date] (formatted by the caller as the
  /// paywall card writes it: month and day, with the year when not this year).
  const HistoryLimitNotice.target({required String this.date})
    : scope = null,
      count = null,
      capped = false,
      channel = '';

  final HistoryLimitScope? scope;
  final int? count;
  final bool capped;

  /// A named channel as people read it (`#roadmap`); empty elsewhere.
  final String channel;
  final String? date;
}

/// Web `ExternalLimitContext`: where the Free plan's one external channel
/// was met.
class ExternalLimitNotice {
  /// This server's one external channel is in use, by [channel] (or held by an
  /// open invite to it); without a channel the gate's own words.
  const ExternalLimitNotice.slot({this.channel, this.openInvite = false})
    : connect = false;

  /// Upgrading this server to connect it to another server's [channel].
  const ExternalLimitNotice.connect({required String this.channel})
    : connect = true,
      openInvite = false;

  final String? channel;
  final bool openInvite, connect;
}

/// Web `gateValues`: the numbers the copy names, from the shared plan config.
({String single, String proSingle, String monthly, int days}) _gateValues() => (
  single: '${freeSingleFileUploadLimitBytes ~/ (1024 * 1024)} MB',
  proSingle: '${proSingleFileUploadLimitBytes ~/ (1024 * 1024)} MB',
  monthly:
      '${RaftBillingPlans.freeMonthlyFileUploadLimitBytes ~/ (1024 * 1024)} MB',
  days: RaftBillingPlans.freeMessageHistoryDays,
);

/// Web `formatUploadSize`: "63 MB", "2.4 MB"; whole megabytes without a
/// trailing ".0", as limits are written.
String formatUploadSize(BuildContext context, int bytes) {
  const mib = 1024 * 1024;
  if (bytes <= 0) return raftText(context, '0 B');
  if (bytes < 1024) {
    return raftFormat(context, '{value} B', {'value': bytes});
  }
  if (bytes < mib) {
    return raftFormat(context, '{value} KB', {
      'value': (bytes / 1024).toStringAsFixed(1),
    });
  }
  final value = double.parse((bytes / mib).toStringAsFixed(1));
  return raftFormat(context, '{value} MB', {
    'value': value == value.roundToDouble() ? value.toInt() : value,
  });
}

/// The title and line of the notice for [gate] (Web `upgradeGateCopy` with the
/// per-context lines of UpgradeDialog.tsx `uploadLimitHint`,
/// `historyLimitHint` and `externalLimitCopy`). A gate without copy here reads
/// as the general one.
LimitNoticeCopy limitNoticeCopy(
  BuildContext context,
  WorkspaceController w, {
  required String gate,
  UploadLimitContext? upload,
  HistoryLimitNotice? history,
  ExternalLimitNotice? external,
  int agentTries = 0,
}) => limitNoticeCopyFor(
  context,
  serverName: w.server?.string('name') ?? '',
  gate: gate,
  upload: upload,
  history: history,
  external: external,
  agentTries: agentTries,
);

/// [limitNoticeCopy] for a server name instead of a controller.
LimitNoticeCopy limitNoticeCopyFor(
  BuildContext context, {
  required String serverName,
  required String gate,
  UploadLimitContext? upload,
  HistoryLimitNotice? history,
  ExternalLimitNotice? external,
  int agentTries = 0,
}) {
  final v = _gateValues();
  final base = <String, Object?>{
    'server': serverName,
    'days': v.days,
    'monthly': v.monthly,
    'single': v.single,
    'proSingle': v.proSingle,
  };
  String fmt(String key, [Map<String, Object?> extra = const {}]) =>
      raftFormat(context, key, {...base, ...extra});
  switch (gate) {
    case WebBillingGate.history:
      final title = fmt('See your whole chat history');
      if (history == null) {
        return (
          title: title,
          hint: fmt(
            "On Free, you and your agents can only read the last {days} days of messages, while on Pro all of {server}'s history can be read and searched.",
          ),
        );
      }
      if (history.date != null) {
        return (
          title: title,
          hint: historyLimitTargetHint(
            context,
            date: history.date!,
            days: v.days,
            agentTries: agentTries,
          ),
        );
      }
      final count = history.count!;
      return (
        title: title,
        hint: historyLimitCountedHint(
          context,
          scope: history.scope!,
          capped: history.capped,
          one: count == 1,
          count: NumberFormat.decimalPattern(
            Localizations.maybeLocaleOf(context)?.toLanguageTag(),
          ).format(count),
          days: v.days,
          channel: history.channel,
          agentTries: agentTries,
        ),
      );
    case WebBillingGate.uploadMonthlyQuota:
      if (upload != null && upload.quota != null) {
        final quota = upload.quota!;
        final values = <String, Object?>{
          'monthly': formatUploadSize(context, quota.limitBytes),
          'remaining': formatUploadSize(context, quota.remainingBytes),
          // The quota counts UTC months, so its reset is a UTC date.
          'date': DateFormat.MMMd(
            Localizations.maybeLocaleOf(context)?.toLanguageTag(),
          ).format(quota.resetsAt),
        };
        // Some of the month is left, just not enough for the file: "used up"
        // would be wrong.
        final title = quota.remainingBytes >= monthlyUploadUsedUpBelowBytes
            ? fmt('Not enough uploads left this month')
            : fmt("This month's uploads are used up");
        final files = upload.files;
        final String hint;
        if (files.isEmpty) {
          hint = fmt(
            "{server} has used this month's {monthly} of uploads; it resets on {date}. Pro has no monthly limit.",
            values,
          );
        } else if (files.length == 1) {
          hint = fmt(
            "{file} is {size}, and {server} has {remaining} left of this month's {monthly} of uploads; it resets on {date}. Pro has no monthly limit.",
            {
              ...values,
              'file': files.single.name,
              'size': formatUploadSize(context, files.single.size),
            },
          );
        } else {
          hint = fmt(
            "{server} has {remaining} left of this month's {monthly} of uploads, not enough for these {count} files; it resets on {date}. Pro has no monthly limit.",
            {...values, 'count': files.length},
          );
        }
        return (title: title, hint: hint);
      }
      return (
        title: fmt("This month's uploads are used up"),
        hint: fmt(
          'Free uploads up to {monthly} a month. Pro has no monthly limit.',
        ),
      );
    case WebBillingGate.uploadFileSize:
      final files = upload?.files ?? const <LimitFile>[];
      final title = fmt('Upload larger files');
      if (upload == null) {
        return (
          title: title,
          hint: fmt(
            'Free uploads files up to {single} each. On Pro, a file can be up to {proSingle}.',
          ),
        );
      }
      return (
        title: title,
        hint: files.length == 1
            ? fmt(
                '{file} is {size}. Free uploads files up to {single} each; on Pro, a file can be up to {proSingle}.',
                {
                  'file': files.single.name,
                  'size': formatUploadSize(context, files.single.size),
                },
              )
            : fmt(
                '{count} files are over {single}. Free uploads files up to {single} each; on Pro, a file can be up to {proSingle}.',
                {'count': files.length},
              ),
      );
    case WebBillingGate.externalChannelFreeLimit:
      final channel = external?.channel;
      if (external != null && channel != null && external.connect) {
        return (
          title: fmt('Connect {server} to {channel}', {'channel': channel}),
          hint: fmt(
            "{server}'s Free plan allows 1 external channel. Pro has no limit.",
            {'channel': channel},
          ),
        );
      }
      final title = fmt('Share more channels outside {server}');
      if (channel == null || channel.isEmpty) {
        return (
          title: title,
          hint: fmt(
            'Free includes 1 external channel, and {server} already has one. On Pro, {server} can share as many as it needs.',
          ),
        );
      }
      return (
        title: title,
        hint: external!.openInvite
            ? fmt(
                'Free includes 1 external channel, and {server} has an open invite to {channel}. On Pro, {server} can share as many as it needs.',
                {'channel': channel},
              )
            : fmt(
                "Free includes 1 external channel, and {server}'s is {channel}. On Pro, {server} can share as many as it needs.",
                {'channel': channel},
              ),
      );
    default:
      return (
        title: fmt('Upgrade {server} to Pro'),
        hint: fmt(
          'Pro lifts the Free limits on chat history, file uploads and Joint Channels.',
        ),
      );
  }
}

/// Opens the Web's Plan & Billing page at once (no request first). A browser
/// that cannot open is a visible toast, never a silent close.
Future<void> openWebBillingOrToast(
  BuildContext context,
  WorkspaceController w, {
  String? gate,
}) async {
  if (!await w.openWebBilling(gate: gate) && context.mounted) {
    showRaftToast(
      context,
      "Stripe checkout didn't open. Try again.",
      tone: RaftToastRecipeTone.error,
    );
  }
}

/// Shows the limit notice: [title] and [hint] (from [limitNoticeCopy]), one
/// "Upgrade to Pro" that opens the Web's Plan & Billing page for [gate]
/// (Web reopens its upgrade dialog for that paywall there) and Close.
/// Completes once the notice is closed.
Future<void> showLimitNotice(
  BuildContext context,
  WorkspaceController w, {
  required String gate,
  required String title,
  required String hint,
}) async {
  await RaftConfirmDialog.show(
    context,
    RaftConfirmDialog(
      surfaceKey: const ValueKey('limit-notice'),
      confirmKey: const ValueKey('limit-notice-upgrade'),
      title: title,
      content: RaftCssText(hint),
      confirmLabel: raftText(context, 'Upgrade to Pro'),
      cancelLabel: raftText(context, 'Close'),
      confirmVariant: RaftButtonRecipeVariant.primary,
      initialFocusCancel: true,
      // No request before the browser opens (Kevin 2654e77c). A browser that
      // cannot open is a visible toast, not a silent close.
      onConfirm: () => openWebBillingOrToast(context, w, gate: gate),
    ),
  );
}

/// Shows the limit notices the data layer queued (`LimitNoticeQueue`), one at
/// a time, over the workspace it wraps. A notice for another server than the
/// current one is dropped.
class LimitNoticeHost extends StatefulWidget {
  const LimitNoticeHost({
    super.key,
    required this.controller,
    required this.queue,
    required this.child,
  });
  final WorkspaceController controller;
  final LimitNoticeQueue queue;
  final Widget child;

  @override
  State<LimitNoticeHost> createState() => _LimitNoticeHostState();
}

class _LimitNoticeHostState extends State<LimitNoticeHost> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    widget.queue.addListener(_drain);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  @override
  void didUpdateWidget(LimitNoticeHost old) {
    super.didUpdateWidget(old);
    if (old.queue != widget.queue) {
      old.queue.removeListener(_drain);
      widget.queue.addListener(_drain);
    }
  }

  @override
  void dispose() {
    widget.queue.removeListener(_drain);
    super.dispose();
  }

  void _drain() {
    if (_showing || !mounted) return;
    final w = widget.controller;
    LimitNoticeRequest? request;
    while ((request = widget.queue.take()) != null) {
      if (request!.serverId == null || request.serverId == w.server?.id) break;
      request = null;
    }
    if (request == null) return;
    final shown = request;
    _showing = true;
    final copy = limitNoticeCopy(
      context,
      w,
      gate: shown.gate,
      upload: shown.upload,
    );
    unawaited(
      showLimitNotice(
        context,
        w,
        gate: shown.gate,
        title: copy.title,
        hint: copy.hint,
      ).whenComplete(() {
        _showing = false;
        if (mounted) _drain();
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
