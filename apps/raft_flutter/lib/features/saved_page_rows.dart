// Web v1.24 components/saved/SavedPanel.tsx: the Saved page's row, context
// menu, load-more sentinel and history-window banner. The page state stays in
// ResourceView; this file only draws and composes.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../platform/content_links.dart';
import 'icu_message.dart';
import 'sender_avatar_projection.dart';

/// Opens a Web address. Tests replace it.
Future<bool> Function(Uri) savedOpenWeb = (uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// `PLAN_CONFIG.free.limits.messageHistoryDays` (SavedPanel `FREE_HISTORY_DAYS`).
const savedFreeHistoryDays = 30;

/// Web `HistoryWindowBanner surface="saved"`: one info line at the top of the
/// list, with an Upgrade to Pro link. Payment happens on the Web (Kevin
/// decision 7), so the link opens Plan & Billing there.
class SavedHistoryBanner extends StatelessWidget {
  const SavedHistoryBanner({
    super.key,
    required this.count,
    required this.listEmpty,
    required this.onUpgrade,
  });

  final int count;
  final bool listEmpty;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final source = listEmpty
        ? "{count, plural, =1 {Your saved message is older than {days} days.} other {All # of your saved messages are older than {days} days.}}"
        : "{count, plural, one {# more saved message is older than {days} days and isn't listed.} other {# more saved messages are older than {days} days and aren't listed.}}";
    // `px-(--column-margin) pb-1 pt-2`.
    return Padding(
      // ds-allow: HistoryWindowBanner wrapper inset, not a Banner token
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: RaftBanner(
        key: const ValueKey('saved-history-hidden'),
        status: RaftBannerRecipeStatus.info,
        size: RaftBannerRecipeSize.sm,
        live: false,
        glyph: RaftGlyph.info,
        description: icuText(context, source, {
          'count': count,
          'days': savedFreeHistoryDays,
        }),
        descriptionTail: (
          label: raftText(context, 'Upgrade to Pro'),
          onPressed: onUpgrade,
        ),
      ),
    );
  }
}

/// The Web Plan & Billing page of this server.
Uri? savedBillingUri({required String origin, required String slug}) {
  if (slug.isEmpty) return null;
  final web = ContentLinks.originFor(origin);
  return web.replace(path: '/s/$slug/settings/billing');
}

/// SavedItem: meta row (`SAVED_ROW_META_CLASS`), message up to three lines and
/// the unsave toggle (`self-center`).
class SavedRowCard extends StatelessWidget {
  const SavedRowCard({
    super.key,
    required this.row,
    required this.label,
    required this.sender,
    required this.projection,
    required this.time,
    required this.onOpen,
    required this.onContextMenu,
    required this.popupOpen,
    required this.onRemove,
    this.topRule = false,
  });

  final Map<String, dynamic> row;
  final String label, sender, time;
  final SenderAvatarProjection projection;
  final VoidCallback onOpen, onRemove;
  final void Function(Offset) onContextMenu;
  final bool popupOpen, topRule;

  @override
  Widget build(BuildContext context) {
    final recipe = RaftConversationCardRecipe(
      RaftTokens.of(context),
      saved: true,
    );
    return RaftConversationCard(
      key: ValueKey('saved-${row['messageId']}'),
      saved: true,
      topRule: topRule,
      onOpen: onOpen,
      onContextMenu: onContextMenu,
      popupOpen: popupOpen,
      child: Row(
        // ds-allow: SavedItem row `gap-3` between text column and toggle
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // ds-allow: SavedItem meta line `mb-1` above the message
              spacing: 4,
              children: [
                RaftSavedItemMeta(
                  channelLabel: label,
                  thread: row['channelType'] == 'thread',
                  sender: sender,
                  time: time,
                  avatar: RaftAvatarSlot(
                    name: sender,
                    slot: RaftAvatarSlotContext.previewMini,
                    agent: projection.kind == 'agent',
                    avatarUrl: projection.uploadedUrl,
                    content: RaftAvatarContent(
                      name: sender,
                      kind: switch (projection.kind) {
                        'agent' => RaftAvatarContentKind.agent,
                        'app' => RaftAvatarContentKind.app,
                        _ => RaftAvatarContentKind.human,
                      },
                      pixelKey: projection.pixelKey,
                      uploadedUrl: projection.uploadedUrl,
                      fallback: projection.kind == 'human'
                          ? Center(
                              child: RaftIcon(
                                RaftGlyph.user,
                                size: 10,
                                color: RaftTokens.of(context).muted,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                Text(
                  '${row['content'] ?? ''}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.body,
                ),
              ],
            ),
          ),
          RaftSavedToggle(label: 'Remove Saved Message', onPressed: onRemove),
        ],
      ),
    );
  }
}

/// SavedPanel `saved-infinite-scroll-sentinel`: `flex min-h-10
/// items-center justify-center py-3`, "Loading" while a page is in flight.
Widget savedSentinel({
  required bool loading,
  required bool hasMore,
  required bool Function() mounted,
  required VoidCallback loadMore,
}) {
  if (!loading && hasMore) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted()) loadMore();
    });
  }
  return RaftInfiniteScrollSentinel(loading: loading);
}

/// SavedPanel `ContextMenuContent`: Copy link, Copy Markdown, a separator,
/// Remove from Saved (BookmarkMinus). [onCopyLink] is null while the server
/// has no slug.
Widget savedMenuContent(
  BuildContext context, {
  required VoidCallback onDismiss,
  required VoidCallback? onCopyLink,
  required VoidCallback onCopyMarkdown,
  required VoidCallback onRemove,
}) => RaftContextMenuContent(
  onDismiss: onDismiss,
  entries: [
    RaftContextMenuContentItem(
      label: raftText(context, 'Copy link'),
      glyph: RaftGlyph.link,
      onPressed: onCopyLink,
    ),
    RaftContextMenuContentItem(
      label: raftText(context, 'Copy Markdown'),
      glyph: RaftGlyph.copy,
      onPressed: onCopyMarkdown,
    ),
    const RaftContextMenuContentSeparator(),
    RaftContextMenuContentItem(
      label: raftText(context, 'Remove from Saved'),
      glyph: RaftGlyph.bookmarkMinus,
      onPressed: onRemove,
    ),
  ],
);
