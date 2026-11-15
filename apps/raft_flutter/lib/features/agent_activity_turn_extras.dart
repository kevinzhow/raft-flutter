// The parts of one turn of the Activity overview that are not its heading and
// action line (Web components/agent/AgentActivityOverview.tsx): the agent's
// own last text, the app events it received, and the messages it sent.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_activity_summaries.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'icu_message.dart';

/// Web `TurnOutput`: the last text the runtime output in the turn (`lastText`),
/// the agent's own account of what it did, which went to no one. It must never
/// read as a message: no card, a dashed message icon, the muted tier, two lines
/// until clicked (the cut text is the button that shows the rest). Plain text,
/// line breaks kept.
class TurnOutput extends StatefulWidget {
  const TurnOutput({super.key, required this.text});
  final String text;

  @override
  State<TurnOutput> createState() => _TurnOutputState();
}

class _TurnOutputState extends State<TurnOutput> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hint = t.colors['foreground-hint'] ?? t.muted;
    final style = t.scale(RaftTypeScale.callout, color: t.ui.foregroundMuted);
    return Row(
      key: const ValueKey('activity-overview-output'),
      crossAxisAlignment: CrossAxisAlignment.start,
      // ds-allow: Web output row `gap-1.5`
      spacing: 6,
      children: [
        Padding(
          // `mt-[calc((1lh-14px)/2)]`: the icon is centred on the first line.
          // ds-allow: Web icon offset `mt-[calc((1lh-14px)/2)]`
          padding: EdgeInsets.only(
            top: (style.fontSize! * (style.height ?? 1.4) - 14) / 2,
          ),
          child: RaftIcon(RaftGlyph.messageSquareDashed, size: 14, color: hint),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final painter = TextPainter(
                text: TextSpan(text: widget.text, style: style),
                maxLines: 2,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: box.maxWidth);
              final cut = painter.didExceedMaxLines;
              painter.dispose();
              final text = Semantics(
                label: raftText(context, "Agent's output (not sent)"),
                child: Text(
                  widget.text,
                  key: const ValueKey('activity-overview-output-text'),
                  maxLines: expanded ? null : 2,
                  overflow: expanded
                      ? TextOverflow.clip
                      : TextOverflow.ellipsis,
                  style: style,
                ),
              );
              if (!cut && !expanded) return text;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => expanded = !expanded),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: text,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A message fetched by id under its own permissions
/// (`GET /messages/context/:id`): the loaded row, or why there is none.
class _FetchedMessage {
  Map<String, dynamic>? message;
  bool unavailable = false;
}

Future<_FetchedMessage> _fetchMessage(WorkspaceController w, String id) async {
  final out = _FetchedMessage();
  try {
    final data = await w.query(
      '/messages/context/$id',
      query: {'before': '0', 'after': '0'},
    );
    final target = data is Map ? (data['targetMessageId'] ?? id) : id;
    final found = data is Map
        ? (data['messages'] as List? ?? const [])
              .whereType<Map>()
              .where((m) => m['id'] == target)
              .firstOrNull
        : null;
    out.message = found == null ? null : Map<String, dynamic>.from(found);
    out.unavailable = found == null;
  } catch (_) {
    out.unavailable = true;
  }
  return out;
}

/// The turn's last reply, fetched by id under the message's own permissions.
class TurnLastReply extends StatefulWidget {
  const TurnLastReply({
    super.key,
    required this.controller,
    required this.messageId,
    required this.count,
  });
  final WorkspaceController controller;
  final String messageId;
  final int count;
  @override
  State<TurnLastReply> createState() => _TurnLastReplyState();
}

class _TurnLastReplyState extends State<TurnLastReply> {
  _FetchedMessage? fetched;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = widget.messageId;
    final result = await _fetchMessage(widget.controller, id);
    if (mounted && id == widget.messageId) setState(() => fetched = result);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final f = agentTimeFormatter(context, widget.controller);
    final message = fetched?.message;
    final loaded = message != null;
    final label = loaded
        ? raftFormat(context, 'Last reply · {time}', {
            'time': f.clock(message['createdAt']),
          })
        : raftText(context, 'Last reply');
    final hint = t.colors['foreground-hint'] ?? t.muted;
    return RaftCard.item(
      key: const ValueKey('activity-overview-reply'),
      interactive: false,
      // ds-allow: Web reply Card `p-3`
      padding: const EdgeInsets.all(12),
      child: RaftGapColumn(
        gap: 4,
        children: [
          RaftCssText(
            widget.count > 1
                ? '$label ${icuText(context, '· {count, plural, one {# message} other {# messages}} sent this turn', {'count': widget.count})}'
                : label,
            style: RaftPanelText.caption(t).copyWith(color: hint),
          ),
          RaftCssText(
            loaded
                ? '${message['content'] ?? ''}'
                : raftText(
                    context,
                    fetched?.unavailable == true
                        ? "The reply is in a conversation you can't see."
                        : 'Loading the reply…',
                  ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: RaftPanelText.value(t),
          ),
        ],
      ),
    );
  }
}

/// How many sent messages show before "Show N more".
const sentMessagesShown = 3;

/// Web `SentMessageRow`: one message the turn sent, fetched by id under its
/// own permissions: the time, then the message cut to two lines; the whole row
/// opens the message.
class _SentMessageRow extends StatefulWidget {
  const _SentMessageRow({required this.controller, required this.messageId});
  final WorkspaceController controller;
  final String messageId;
  @override
  State<_SentMessageRow> createState() => _SentMessageRowState();
}

class _SentMessageRowState extends State<_SentMessageRow> {
  _FetchedMessage? fetched;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = widget.messageId;
    final result = await _fetchMessage(widget.controller, id);
    if (mounted && id == widget.messageId) setState(() => fetched = result);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final f = agentTimeFormatter(context, widget.controller);
    final message = fetched?.message;
    final body = RaftCssText(
      message != null
          ? '${message['content'] ?? ''}'
          : raftText(
              context,
              fetched?.unavailable == true
                  ? "The reply is in a conversation you can't see."
                  : 'Loading the reply…',
            ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: t.scale(RaftTypeScale.footnote, color: t.ui.foreground),
    );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      // ds-allow: Web sent row `gap-2`
      spacing: 8,
      children: [
        RaftIcon(
          RaftGlyph.messageSquare,
          size: 14,
          color: t.colors['foreground-hint'] ?? t.muted,
        ),
        Expanded(child: body),
        if (message != null)
          RaftCssText(
            f.clock(message['createdAt']),
            style: t.scale(RaftTypeScale.caption, color: t.ui.foregroundHint),
          ),
      ],
    );
    final open = message == null
        ? null
        : () => unawaited(
            widget.controller.jumpToMessage(
              '${message['channelId'] ?? ''}',
              '${message['id']}',
            ),
          );
    return RaftCard.item(
      key: ValueKey('activity-overview-sent-message-${widget.messageId}'),
      interactive: open != null,
      onTap: open,
      // ds-allow: Web sent row `px-3 py-2`
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: row,
    );
  }
}

/// Web `SentMessages`: every message the turn sent, the first few shown and
/// the rest a click away.
class TurnSentMessages extends StatefulWidget {
  const TurnSentMessages({
    super.key,
    required this.controller,
    required this.ids,
    required this.visible,
    required this.hidden,
  });
  final WorkspaceController controller;
  final List<String> ids;

  /// How many the viewer can see (the id list is capped).
  final int visible;

  /// Sent where the viewer cannot see: counted, never named.
  final int hidden;

  @override
  State<TurnSentMessages> createState() => _TurnSentMessagesState();
}

class _TurnSentMessagesState extends State<TurnSentMessages> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hint = t.colors['foreground-hint'] ?? t.muted;
    final ids = widget.ids;
    final shown = expanded ? ids : ids.take(sentMessagesShown).toList();
    final note = RaftPanelText.caption(t).copyWith(color: hint);
    return Column(
      key: const ValueKey('activity-overview-sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // ds-allow: Web `gap-2`
      spacing: 8,
      children: [
        for (final id in shown)
          _SentMessageRow(controller: widget.controller, messageId: id),
        if (!expanded && ids.length > sentMessagesShown)
          Align(
            alignment: Alignment.centerLeft,
            child: RaftTextLink(
              key: const ValueKey('activity-overview-sent-more'),
              label: raftFormat(context, 'Show {count} more', {
                'count': ids.length - sentMessagesShown,
              }),
              onPressed: () => setState(() => expanded = true),
            ),
          ),
        if (widget.visible > ids.length)
          RaftCssText(
            icuText(
              context,
              '{count, plural, one {# more not listed} other {# more not listed}}',
              {'count': widget.visible - ids.length},
            ),
            style: note,
          ),
        if (widget.hidden > 0)
          RaftCssText(
            icuText(
              context,
              "{count, plural, one {# more in a conversation you can't see} other {# more in conversations you can't see}}",
              {'count': widget.hidden},
            ),
            style: note,
          ),
      ],
    );
  }
}

/// How many app events show before "Show N more".
const appEventsShown = 5;

/// Web `AppEvents`: the app events delivered in the turn, oldest first, the
/// first few shown and the rest a click away.
class TurnAppEvents extends StatefulWidget {
  const TurnAppEvents({
    super.key,
    required this.controller,
    required this.events,
    required this.count,
  });
  final WorkspaceController controller;
  final List<TurnAppEvent> events;
  final int count;

  @override
  State<TurnAppEvents> createState() => _TurnAppEventsState();
}

class _TurnAppEventsState extends State<TurnAppEvents> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final f = agentTimeFormatter(context, widget.controller);
    final hint = t.colors['foreground-hint'] ?? t.muted;
    final events = widget.events;
    final shown = expanded ? events : events.take(appEventsShown).toList();
    return Column(
      key: const ValueKey('activity-overview-app-events'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // ds-allow: Web `gap-2`
      spacing: 8,
      children: [
        RaftCssText(
          icuText(
            context,
            '{count, plural, one {Received # app notification} other {Received # app notifications}}',
            {'count': widget.count},
          ),
          style: RaftPanelText.caption(t).copyWith(color: hint),
        ),
        for (final e in shown)
          RaftCard.item(
            key: ValueKey('activity-overview-app-event-${e.id}'),
            interactive: false,
            // ds-allow: Web app event row `px-3 py-2`
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              // ds-allow: Web app event row `gap-2`
              spacing: 8,
              children: [
                RaftIcon(RaftGlyph.appWindow, size: 14, color: hint),
                Expanded(
                  child: RaftGapColumn(
                    gap: 0,
                    children: [
                      RaftCssText(
                        e.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.scale(
                          RaftTypeScale.footnote,
                          weight: FontWeight.w600,
                          color: t.ui.foreground,
                        ),
                      ),
                      RaftCssText(
                        e.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.scale(
                          RaftTypeScale.footnote,
                          color: t.ui.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                RaftCssText(
                  f.clock(e.deliveredAt),
                  style: t.scale(
                    RaftTypeScale.caption,
                    color: t.ui.foregroundHint,
                  ),
                ),
              ],
            ),
          ),
        if (!expanded && events.length > appEventsShown)
          Align(
            alignment: Alignment.centerLeft,
            child: RaftTextLink(
              key: const ValueKey('activity-overview-app-events-more'),
              label: raftFormat(context, 'Show {count} more', {
                'count': events.length - appEventsShown,
              }),
              onPressed: () => setState(() => expanded = true),
            ),
          ),
        if (widget.count > events.length)
          RaftCssText(
            icuText(
              context,
              '{count, plural, one {# more not listed} other {# more not listed}}',
              {'count': widget.count - events.length},
            ),
            style: RaftPanelText.caption(t).copyWith(color: hint),
          ),
      ],
    );
  }
}
