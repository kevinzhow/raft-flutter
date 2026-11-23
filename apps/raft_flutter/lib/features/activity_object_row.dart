// An Artifact's Activity row (Web v1.24 `ObjectInboxRow.tsx`), in a conversation
// row's anatomy on `RaftInboxItem`: the kind's tile, the object's title, then who
// did what (their face and name, then the comment's text or the sentence), what
// else is new, and where it lives; the time ends the first line, the mention
// marker and unread count the second. Opening goes to the object; Done takes it
// out; there is no Mark as unread and no right swipe.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:raft_ui/raft_ui.dart';

import 'activity_inbox_row.dart';
import 'activity_object_text.dart';
import 'activity_row_host.dart';
import 'activity_row_time.dart';
import 'sender_avatar_projection.dart';

/// The key of an object row: `activity-object-<objectId>`.
ValueKey<String> activityObjectRowKey(Map row) =>
    ValueKey('activity-object-${row['objectId']}');

class ActivityObjectRow extends StatelessWidget {
  const ActivityObjectRow({super.key, required this.row, required this.host});
  final Map<String, dynamic> row;
  final ActivityRowHost host;

  @override
  Widget build(BuildContext context) {
    final w = host.controller;
    final excerpt = artifactActivityExcerpt(row);
    final latest = row['latestEvent'] is Map
        ? row['latestEvent'] as Map
        : const {};
    // A comment's text is its author's, who may not be the newest event's actor.
    final actor =
        (excerpt?['author'] is Map ? excerpt!['author'] as Map : null) ??
        (latest['actor'] is Map ? latest['actor'] as Map : const {});
    final actorType = '${actor['type'] ?? 'user'}';
    final actorId = '${actor['id'] ?? ''}';
    String? name;
    if (actorType == 'agent') {
      final agent = host.agentFor(actorId);
      name = agent == null
          ? null
          : '${agent['displayName'] ?? ''}'.trim().isNotEmpty
          ? '${agent['displayName']}'
          : '${agent['name'] ?? ''}';
    } else {
      final member = host.people
          .where((p) => p['userId'] == actorId || p['id'] == actorId)
          .firstOrNull;
      name = member == null
          ? null
          : '${member['displayName'] ?? ''}'.trim().isNotEmpty
          ? '${member['displayName']}'
          : '${member['name'] ?? ''}';
    }
    name = (name == null || name.isEmpty)
        ? (actor['name'] is String && (actor['name'] as String).isNotEmpty
              ? actor['name'] as String
              : null)
        : name;
    final parts = objectRowParts(context, row, name);
    final home = objectRowHome(row);
    final unread = (row['unreadCount'] as num? ?? 0).toInt();
    final mention =
        host.filter != 'mentions' && row['hasMention'] == true && unread > 0;
    final images = excerpt == null
        ? null
        : artifactActivityImagesOnly(context, excerpt);
    final text = excerpt == null
        ? parts.event
        : images ?? '${excerpt['text'] ?? ''}'.trim();
    final shownName = name ?? raftText(context, 'Someone');
    final homeText = home == null
        ? null
        : raftFormat(context, '· {home}', {'home': home});
    final done = activityRowDone(
      context,
      host,
      label: raftFormat(context, 'Mark {conversation} as Done', {
        'conversation': parts.title,
      }),
      offered: true,
    );
    final face = RaftAvatarSlot(
      name: shownName,
      slot: RaftAvatarSlotContext.compactList,
      agent: actorType == 'agent',
      content: _faceContent(
        context,
        w.client.origin,
        actorType,
        actorId,
        shownName,
      ),
    );
    return ActivityRowTimeBuilder(
      at: row['lastActivityAt'],
      user: w.client.user?.json,
      builder: (context, time) {
        final bodyText = [
          if (excerpt != null) '$shownName: $text' else text,
          ...parts.news,
          ?homeText,
        ].join(' ');
        return ActivityRowActivation(
          host: host,
          builder: (context, onOpen) => RaftInboxItem(
            key: activityObjectRowKey(row),
            semanticLabel: [
              parts.title,
              bodyText,
              ?time?.words,
            ].where((p) => p.isNotEmpty).join(' '),
            leading: RaftIconTile(glyph: parts.glyph),
            title: Text(
              parts.title,
              key: const ValueKey('conversation-card-primary'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            timestamp: time == null
                ? null
                : Text(
                    time.shown,
                    key: const ValueKey('conversation-card-timestamp'),
                  ),
            timestampAtRest: time != null && !time.older,
            timestampTooltip: time?.words,
            body: _ObjectLine(
              key: const ValueKey('object-card-line'),
              face: face,
              actor: excerpt != null ? '$shownName: ' : null,
              text: text,
              news: parts.news,
              home: homeText,
              strong: unread > 0,
            ),
            marks: [
              if (mention)
                RaftSidebarMentionMarker(
                  key: const ValueKey('inbox-mention-badge'),
                  label: raftText(context, 'Mentioned you'),
                ),
              if (unread > 0)
                KeyedSubtree(
                  key: const ValueKey('conversation-card-new-badge'),
                  child: RaftSidebarUnreadCount(count: unread),
                ),
            ],
            actions: done.actions,
            semanticActions: done.semanticActions,
            selected: host.selected,
            unread: unread > 0,
            located: host.located,
            onOpen: () {
              final open = host.onOpenObject;
              if (open != null) {
                open(row);
              } else {
                onOpen();
              }
            },
            onLongPress: host.onLongPress ?? host.menu,
            onSecondaryTap: host.onSecondaryTap ?? host.menu,
          ),
        );
      },
    );
  }

  Widget _faceContent(
    BuildContext context,
    String origin,
    String type,
    String id,
    String name,
  ) {
    final avatar = projectSenderAvatar(
      origin: origin,
      senderId: id,
      senderType: type,
      agents: host.agents,
      members: host.people,
      currentUser: host.controller.client.user?.json,
    );
    return RaftAvatarContent(
      name: name,
      kind: switch (avatar.kind) {
        'agent' => RaftAvatarContentKind.agent,
        'app' => RaftAvatarContentKind.app,
        _ => RaftAvatarContentKind.human,
      },
      pixelKey: avatar.pixelKey,
      uploadedUrl: avatar.uploadedUrl,
    );
  }
}

/// The object row's one line: the actor's face, then "{name}: " and the
/// comment's text (or the sentence), what else is new, and where it lives. As
/// it narrows, where it lives truncates first, then the text, down to about a
/// dozen characters it always shows, then the name and what else is new (that
/// down to its count, a floor of 9ch).
/// The gap between the line's pieces (`ml-1`).
const double _pieceGap = 4;

class _ObjectLine extends StatelessWidget {
  const _ObjectLine({
    super.key,
    required this.face,
    required this.actor,
    required this.text,
    required this.news,
    required this.home,
    required this.strong,
  });
  final Widget face;
  final String? actor;
  final String text;
  final List<String> news;
  final String? home;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = DefaultTextStyle.of(context).style;
    final textStyle = strong ? style.copyWith(color: t.strong) : style;
    final actorStyle = style.merge(RaftListRowSender.name(context, '').style);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String s, TextStyle st) {
      final p = TextPainter(
        text: TextSpan(text: s, style: st),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const faceWidth = 19.0 + _pieceGap;
        final charWidth = measure('0', style);
        final avail = constraints.maxWidth - faceWidth;
        final actorW = actor == null ? 0.0 : measure(actor!, actorStyle);
        final textW = measure(text, textStyle);
        final newsW = [for (final n in news) measure(n, style)];
        final homeW = home == null ? 0.0 : measure(home!, style);
        final newsTotal =
            newsW.fold(0.0, (a, b) => a + b) + _pieceGap * news.length;
        final shared =
            avail - actorW - newsTotal - (home == null ? 0 : _pieceGap);
        // Where it lives truncates first, then the text, down to 12 characters.
        var textShown = textW, homeShown = homeW;
        if (shared < textW + homeW) {
          final floor = textW < 12 * charWidth ? textW : 12 * charWidth;
          textShown = shared >= textW
              ? textW
              : (shared < floor ? floor : shared);
          homeShown = (shared - textShown).clamp(0.0, homeW);
        }
        // Laid out at its own width and clipped: a line narrower than its
        // floors cuts off at the edge, as Web's overflow does.
        return ClipRect(
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            maxWidth: double.infinity,
            fit: OverflowBoxFit.deferToChild,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: _pieceGap,
              children: [
                face,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actor != null)
                      Text(
                        actor!,
                        key: const ValueKey('object-card-actor'),
                        maxLines: 1,
                        softWrap: false,
                        style: actorStyle,
                      ),
                    SizedBox(
                      width: textShown,
                      child: Text(
                        text,
                        key: const ValueKey('object-card-text'),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle,
                      ),
                    ),
                  ],
                ),
                for (final (i, n) in news.indexed)
                  SizedBox(
                    width: newsW[i],
                    child: Text(
                      n,
                      key: const ValueKey('object-card-news'),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (home != null && homeShown > 0)
                  SizedBox(
                    width: homeShown,
                    child: Text(
                      home!,
                      key: const ValueKey('object-card-home'),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
