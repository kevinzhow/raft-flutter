// Web `components/message/HistoryPaywall.tsx` host side: what the Free plan's
// history cutoff hides at the start of a channel, DM, thread or task
// conversation (the counted card, a faded glimpse, target mode for a jump
// behind the window), and the one paid action: Upgrade to Pro opens the Web
// billing page with the history gate. The visuals are raft_ui's
// [RaftHistoryPaywall]; this file picks the sentences and the data.
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/plan_history.dart';
import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';

import 'sender_avatar_projection.dart';
import 'workspace_web_billing.dart';

/// Web `HistoryPaywallScope`: the words differ by where the count sits in the
/// zh sentence, so each scope has its own keys.
enum HistoryPaywallScope { channel, dm, thread, task }

/// Web `historyPaywallPlace`: a DM, a thread shown as a channel, or a channel.
HistoryPaywallScope historyPaywallScopeOf(RaftChannel? channel) =>
    switch (channel?.string('type')) {
      'dm' => HistoryPaywallScope.dm,
      'thread' => HistoryPaywallScope.thread,
      _ => HistoryPaywallScope.channel,
    };

String _plural(
  BuildContext context,
  int count,
  String one,
  String other,
  Map<String, Object?> values,
) => raftFormat(context, count == 1 ? one : other, values);

/// Web `titleFor` + `message.historyPaywall.*`: the card's title.
String historyPaywallTitle(
  BuildContext context, {
  required HistoryPaywallScope scope,
  required HiddenHistory? hidden,
  required bool allHidden,
  required int days,
}) {
  String f(String key, [int? count]) =>
      raftFormat(context, key, {'days': days, 'count': ?count});
  final replies = scope == HistoryPaywallScope.thread;
  if (hidden == null || (hidden.hiddenCount == 0 && !hidden.parentHidden)) {
    return replies
        ? f('Replies older than {days} days are hidden')
        : f('Messages older than {days} days are hidden');
  }
  final count = hidden.hiddenCount, capped = hidden.hiddenCountCapped;
  final v = {'days': days, 'count': count};
  if (replies && hidden.parentHidden) {
    if (count == 0) return f('The first message is older than {days} days');
    if (allHidden) {
      return capped
          ? f(
              'The first message and all of its over {count} replies are older than {days} days',
              count,
            )
          : _plural(
              context,
              count,
              'The first message and its {count} reply are older than {days} days',
              'The first message and all {count} replies are older than {days} days',
              v,
            );
    }
    return capped
        ? f(
            'The first message and over {count} replies are older than {days} days',
            count,
          )
        : _plural(
            context,
            count,
            'The first message and {count} reply are older than {days} days',
            'The first message and {count} replies are older than {days} days',
            v,
          );
  }
  if (replies) {
    return capped
        ? f('Over {count} replies are older than {days} days', count)
        : _plural(
            context,
            count,
            '{count} reply is older than {days} days',
            '{count} replies are older than {days} days',
            v,
          );
  }
  if (allHidden) {
    return switch (scope) {
      HistoryPaywallScope.dm =>
        capped
            ? f(
                'All of the over {count} messages here are older than {days} days',
                count,
              )
            : _plural(
                context,
                count,
                'The {count} message here is older than {days} days',
                'All {count} messages here are older than {days} days',
                v,
              ),
      HistoryPaywallScope.task =>
        capped
            ? f(
                "All of this task's over {count} messages are older than {days} days",
                count,
              )
            : _plural(
                context,
                count,
                "This task's {count} message is older than {days} days",
                'All {count} messages in this task are older than {days} days',
                v,
              ),
      _ =>
        capped
            ? f(
                "All of this channel's over {count} messages are older than {days} days",
                count,
              )
            : _plural(
                context,
                count,
                "This channel's {count} message is older than {days} days",
                'All {count} messages in this channel are older than {days} days',
                v,
              ),
    };
  }
  return capped
      ? f('Over {count} earlier messages are older than {days} days', count)
      : _plural(
          context,
          count,
          '{count} earlier message is older than {days} days',
          '{count} earlier messages are older than {days} days',
          v,
        );
}

/// The card of a jump to a message behind the window (target mode).
({String title, String description}) historyPaywallTargetText(
  BuildContext context, {
  required HistoryPaywallScope scope,
  required HiddenTarget target,
  required String date,
  required int days,
}) {
  final v = <String, Object?>{'days': days, 'date': date};
  if (scope == HistoryPaywallScope.thread ||
      scope == HistoryPaywallScope.task) {
    final counts = target.threadCounts;
    final count = counts?.count ?? 1;
    v['count'] = count;
    final capped = counts?.capped == true;
    final description = counts?.parentHidden == true
        ? capped
              ? raftFormat(
                  context,
                  "It was sent on {date}; only its start shows here. This thread's first message and over {count} replies are older than {days} days; on Pro you can read them all.",
                  v,
                )
              : _plural(
                  context,
                  count,
                  "It was sent on {date}; only its start shows here. This thread's first message and {count} reply are older than {days} days; on Pro you can read them all.",
                  "It was sent on {date}; only its start shows here. This thread's first message and {count} replies are older than {days} days; on Pro you can read them all.",
                  v,
                )
        : capped
        ? raftFormat(
            context,
            'It was sent on {date}; only its start shows here. Over {count} replies in this thread are older than {days} days; on Pro you can read them all.',
            v,
          )
        : _plural(
            context,
            count,
            'It was sent on {date}; only its start shows here. {count} reply in this thread is older than {days} days; on Pro you can read them all.',
            'It was sent on {date}; only its start shows here. {count} replies in this thread are older than {days} days; on Pro you can read them all.',
            v,
          );
    return (
      title: raftFormat(
        context,
        "The reply you're looking for is older than {days} days",
        v,
      ),
      description: description,
    );
  }
  return (
    title: target.replies != null
        ? raftFormat(
            context,
            "This thread's first message is older than {days} days",
            v,
          )
        : raftFormat(
            context,
            "The message you're looking for is older than {days} days",
            v,
          ),
    description: raftFormat(
      context,
      'It was sent on {date}; only its start shows here. Free shows only the last {days} days; on Pro you can read it and all history.',
      v,
    ),
  );
}

/// The days the plan shows (Web `FREE_HISTORY_DAYS`: only Free is cut).
int historyPaywallDays(WorkspaceController w) {
  final limit = planHistoryLimit(w.server?.string('plan')).days;
  return limit < 0 ? 30 : limit;
}

/// The one paid action of every history surface: the Web's billing page with
/// the history gate (Web: the upgrade dialog). Web's dialog cannot fail to
/// open; the browser can, and that is said, not swallowed.
Future<void> openHistoryUpgrade(
  BuildContext context,
  WorkspaceController w,
) async {
  final opened = await w.openWebBilling(gate: WebBillingGate.history);
  if (!opened && context.mounted) {
    showRaftToast(context, 'Couldn\'t open the billing page. Try again.');
  }
}

/// Web `DateDivider recentHistory`: the first day divider under the paywall
/// reads "Last 30 days · day".
String historyDividerLabel(
  BuildContext context,
  WorkspaceController w,
  String day, {
  required bool first,
}) => first && RaftHistoryPaywallView.atTop(w)
    ? raftFormat(context, 'Last {days} days · {date}', {
        'days': historyPaywallDays(w),
        'date': day,
      })
    : day;

/// Web `HistoryPaywall`: reads what the store holds for the open channel (or
/// thread) and draws it. [allHidden]: nothing sits in the window. [recentDivider]:
/// visible messages follow and no date divider says "last N days" (threads).
class RaftHistoryPaywallView extends StatelessWidget {
  const RaftHistoryPaywallView({
    super.key,
    required this.controller,
    this.thread = false,
    this.allHidden = false,
    this.recentDivider = false,
    this.fill = false,
    this.inset = false,
  });

  final WorkspaceController controller;
  final bool thread, allHidden, recentDivider;

  /// The channel's empty body: the card sits on the composer, scrollable when
  /// tall (Web `ScrollArea` with `mt-auto`).
  final bool fill;

  /// The thread panel's gutter around an all-hidden paywall.
  final bool inset;

  /// Web `showsHiddenTarget`: a jump to a message behind the window.
  static bool showsTarget(WorkspaceController w) =>
      w.messageDomain.contextLoadError != null &&
      w.client.hiddenHistory.targetOf(w.channel?.id) != null;

  /// The paywall leads the channel's list: target mode, or the start of what
  /// the plan shows (`getHistoryTopState == history_limited`).
  static bool atTop(WorkspaceController w) =>
      showsTarget(w) ||
      !w.messageDomain.state.hasMore && w.messageDomain.state.historyLimited;

  /// Nothing in the window and the cutoff is why (not an empty channel).
  static bool hidesAll(WorkspaceController w) =>
      w.messageDomain.state.historyLimited ||
      w.messageDomain.contextLoadError == MessageContextLoadError.beyondHistory;

  @override
  Widget build(BuildContext context) {
    final w = controller;
    final channelId = thread ? w.threadChannelId : w.channel?.id;
    final store = w.client.hiddenHistory;
    final hidden = store.of(channelId);
    final scope = thread
        ? (w.messageDomain.state.threadIdentity?.taskId != null
              ? HistoryPaywallScope.task
              : HistoryPaywallScope.thread)
        : historyPaywallScopeOf(w.channel);
    final target = !thread && showsTarget(w) ? store.targetOf(channelId) : null;
    final days = historyPaywallDays(w);
    final times = SourceTimeFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      preferredTimezone:
          w.client.user?.string('preferredTimezone') ??
          w.client.user?.string('timezone'),
      preferredTimeFormat: sourceTimeFormatPreference(
        w.client.user?.string('preferredTimeFormat') ??
            w.client.user?.string('timeFormat'),
      ),
      systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
          ? SourceTimeFormat.twentyFourHour
          : null,
      todayLabel: raftText(context, 'Today'),
      yesterdayLabel: raftText(context, 'Yesterday'),
    );
    RaftHiddenMessagePreview row(HiddenHistoryMessage m) =>
        _preview(context, w, times, m);
    var title = historyPaywallTitle(
      context,
      scope: scope,
      hidden: hidden,
      allHidden: allHidden,
      days: days,
    );
    var description = raftFormat(
      context,
      'Free shows only the last {days} days. On Pro, all history can be read and searched.',
      {'days': days},
    );
    RaftHiddenTargetReplies? replies;
    if (target != null) {
      final sent = DateTime.tryParse(target.target.createdAt);
      final wall = sent == null ? null : times.wallTime(sent.toLocal());
      final locale = Localizations.localeOf(context).toLanguageTag();
      final sameYear = sent != null && sent.year == DateTime.now().year;
      final date = wall == null
          ? ''
          : (sameYear ? DateFormat.MMMMd(locale) : DateFormat.yMMMMd(locale))
                .format(wall);
      final text = historyPaywallTargetText(
        context,
        scope: scope,
        target: target,
        date: date,
        days: days,
      );
      title = text.title;
      description = text.description;
      final box = target.replies;
      if (box != null) {
        final latest = box.latest;
        replies = RaftHiddenTargetReplies(
          summary: raftFormat(
            context,
            box.count == 1 ? '{count} reply' : '{count} replies',
            {'count': box.count},
          ),
          semanticLabel: raftFormat(
            context,
            box.count == 1 ? '{count} reply' : '{count} replies',
            {'count': box.count},
          ),
          onOpen: () => w.openThreadIdentity(
            parentChannelId: channelId!,
            parentMessageId: target.target.id,
          ),
          reply: RaftInlineReply(
            id: latest.id,
            author: _author(context, latest),
            preview: latest.preview ?? raftText(context, 'Sent an attachment'),
            senderType: latest.senderType,
            timestamp: times.shortDateTime(latest.createdAt),
            avatar: _avatar(w, latest, mini: true),
          ),
        );
      }
    }
    return RaftHistoryPaywall(
      fill: fill,
      inset: inset,
      title: title,
      description: description,
      upgradeLabel: raftText(context, 'Upgrade to Pro'),
      onUpgrade: () => openHistoryUpgrade(context, w),
      glimpse: target == null && hidden != null
          ? [for (final m in hidden.latest) row(m)]
          : const [],
      target: target == null ? null : row(target.target),
      before: target == null
          ? const []
          : [for (final m in target.before) row(m)],
      after: target == null ? const [] : [for (final m in target.after) row(m)],
      targetReplies: replies,
      noRecentLabel: allHidden
          ? raftFormat(
              context,
              scope == HistoryPaywallScope.thread
                  ? 'No new replies in the last {days} days'
                  : 'No new messages in the last {days} days',
              {'days': days},
            )
          : null,
      recentDividerLabel: !allHidden && recentDivider
          ? raftFormat(context, 'Last {days} days', {'days': days})
          : null,
    );
  }
}

String _author(BuildContext context, HiddenHistoryMessage m) =>
    (m.senderName == null || m.senderName!.isEmpty)
    ? raftText(context, 'Unknown')
    : m.senderName!;

RaftHiddenMessagePreview _preview(
  BuildContext context,
  WorkspaceController w,
  SourceTimeFormatter times,
  HiddenHistoryMessage m,
) => RaftHiddenMessagePreview(
  id: m.id,
  author: _author(context, m),
  timestamp: times.shortDateTime(m.createdAt),
  text: (m.preview == null || m.preview!.isEmpty)
      ? raftText(context, 'Sent an attachment')
      : m.preview!,
  avatar: _avatar(w, m),
);

/// Web `HiddenAvatar`: only what the page carried (an external projection is
/// an app avatar, an agent an agent one, anyone else a person).
Widget _avatar(
  WorkspaceController w,
  HiddenHistoryMessage m, {
  bool mini = false,
}) {
  final external = m.senderType == 'external_projection';
  final agent = m.senderType == 'agent';
  final source = projectSenderAvatar(
    origin: w.client.origin,
    senderId: m.senderId,
    senderType: m.senderType,
    agents: const [],
    members: const [],
    carriedAvatarUrl: m.senderAvatarUrl,
  );
  final name = m.senderName ?? '';
  final context = mini
      ? RaftMountedAvatarContext.compactList
      : RaftMountedAvatarContext.messageRow;
  final identity = external
      ? RaftMountedAvatarIdentity.app
      : agent
      ? RaftMountedAvatarIdentity.agent
      : RaftMountedAvatarIdentity.human;
  return RaftAvatar(
    name: name,
    kind: external
        ? RaftAvatarKind.app
        : agent
        ? RaftAvatarKind.agent
        : RaftAvatarKind.human,
    mountedContext: context,
    content: RaftAvatarContent(
      name: name,
      kind: external
          ? RaftAvatarContentKind.app
          : agent
          ? RaftAvatarContentKind.agent
          : RaftAvatarContentKind.human,
      uploadedUrl: source.uploadedUrl,
      pixelKey: source.pixelKey,
      fallback: RaftMountedAvatarFallback(
        avatarContext: context,
        initials: name,
        identity: identity,
      ),
    ),
  );
}
