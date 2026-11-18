import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'artifacts/artifact_models.dart';
import 'artifacts/artifact_text.dart' show artifactRelativeTime;
import 'channel_announcement_store.dart';

class ChannelAnnouncementStrip extends StatelessWidget {
  const ChannelAnnouncementStrip({
    super.key,
    required this.announcement,
    required this.webOrigin,
    required this.onOpen,
    this.author,
    this.formatDate,
    this.onOpenSettings,
  });

  final ChannelAnnouncement announcement;
  final RaftRecord? author;
  final String Function(DateTime)? formatDate;
  final Uri webOrigin;
  final VoidCallback onOpen;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final actor = author ?? RaftRecord(announcement.updatedBy);
    final name = actor.name.isNotEmpty
        ? actor.name
        : raftText(context, 'Someone');
    final unread = !announcement.seen;
    final line = unread
        ? announcement.note == null || announcement.note!.isEmpty
              ? raftFormat(context, '{name} updated it', {'name': name})
              : raftFormat(context, '{name}: {note}', {
                  'name': name,
                  'note': announcement.note,
                })
        : announcement.excerpt?.isNotEmpty == true
        ? announcement.excerpt!
        : raftFormat(context, 'Updated by {name}', {'name': name});
    final options = raftText(context, 'Announcement options');
    final wide = !RaftAdaptiveWorkspace.compactOf(context);
    final date = DateTime.tryParse(announcement.updatedAt);
    final time = date == null
        ? ''
        : unread
        ? artifactRelativeTime(context, date)
        : formatDate?.call(date) ??
              MaterialLocalizations.of(context).formatShortDate(date.toLocal());
    return DecoratedBox(
      key: const ValueKey('channel-announcement-strip'),
      decoration: BoxDecoration(
        color: t.colors['layer-canvas'],
        border: Border(bottom: BorderSide(color: t.colors['line-seam']!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: RaftListRow(
              variant: RaftListRowVariant.plain,
              onPressed: onOpen,
              semanticLabel: raftFormat(context, 'Announcement: {title}', {
                'title': announcement.title,
              }),
              children: [
                const RaftIcon(RaftGlyph.megaphone, size: 16),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          announcement.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.scale(
                            unread
                                ? RaftTypeScale.subhead
                                : RaftTypeScale.callout,
                          ),
                        ),
                      ),
                      const SizedBox(width: RaftSpace.x2),
                      if (wide && unread && actor.name.isNotEmpty) ...[
                        RaftAvatar(
                          name: actor.name,
                          imageUrl: actor.json['avatarUrl'] as String?,
                          mountedContext: RaftMountedAvatarContext.previewMini,
                          kind: announcement.updatedBy['type'] == 'agent'
                              ? RaftAvatarKind.agent
                              : RaftAvatarKind.human,
                        ),
                        const SizedBox(width: RaftSpace.x1_5),
                      ],
                      Flexible(
                        child: Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.scale(RaftTypeScale.callout, color: t.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Semantics(
                    label: raftText(
                      context,
                      'Updated since you last opened it',
                    ),
                    child: const RaftStatus(variant: RaftStatusVariant.accent),
                  ),
                if (wide && time.isNotEmpty)
                  Text(
                    time,
                    maxLines: 1,
                    style: t.scale(
                      RaftTypeScale.monoMeta,
                      color: t.colors['foreground-hint'],
                    ),
                  ),
              ],
            ),
          ),
          RaftDropdownMenu(
            label: options,
            surfaceKey: const ValueKey('channel-announcement-strip-menu'),
            kind: RaftMenuKind.dropdownMenu,
            align: RaftDropdownAlign.end,
            entries: [
              RaftMenuEntry(
                label: raftText(context, 'Copy link'),
                glyph: RaftGlyph.link,
                onPressed: () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(
                        text: artifactUrl(
                          webOrigin,
                          announcement.artifactId,
                        ).toString(),
                      ),
                    );
                    if (context.mounted) {
                      showRaftToast(
                        context,
                        'Link copied.',
                        tone: RaftToastRecipeTone.success,
                      );
                    }
                  } on PlatformException {
                    // Match the Web clipboard rejection: no success toast.
                  }
                },
              ),
              if (onOpenSettings != null) ...[
                const RaftMenuEntry.separator(),
                RaftMenuEntry(
                  label: raftText(context, 'Announcement settings'),
                  glyph: RaftGlyph.settings,
                  onPressed: onOpenSettings,
                ),
              ],
            ],
            triggerBuilder: (context, focus, open) => RaftButton(
              key: const ValueKey('channel-announcement-strip-options'),
              focusNode: focus,
              semanticLabel: options,
              tooltip: options,
              glyph: RaftGlyph.ellipsisVertical,
              uiVariant: RaftButtonVariant.ghost,
              uiSize: RaftButtonSize.iconSm,
              onPressed: open,
            ),
          ),
        ],
      ),
    );
  }
}
