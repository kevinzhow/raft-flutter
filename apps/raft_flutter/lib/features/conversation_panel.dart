import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import '../data/raft_navigation_history.dart';
import '../data/attachment_image_repository.dart';
import '../data/source_channel_files_store.dart';
import '../platform/attachment_files.dart';
import 'chat_view.dart';
import 'conversation_tab_reorder.dart';
import 'message_selection.dart';
import 'resource_view.dart';
import 'source_channel_files_view.dart';
import 'source_channel_files_actions.dart';

/// Mounted ChatPanel tabs. The editor remains owned by the same element while
/// data-only tab bodies mount on demand; each owner keeps its authority fences.
class ConversationPanel extends StatefulWidget {
  const ConversationPanel({
    super.key,
    required this.controller,
    this.selectionHandle,
    this.onTask,
    this.onMessageTask,
    this.onViewBilling,
    this.onOpenChannelSettings,
    this.hideHeader = false,
  });
  final WorkspaceController controller;

  /// Forwarded to the timeline's history-limit banner link.
  final VoidCallback? onViewBilling;
  final VoidCallback? onOpenChannelSettings;

  /// Source workspace ChatPanel hides both its channel header and tab controls.
  /// Its URI-selected task/files body and retained editor still belong to it.
  final bool hideHeader;
  final ChatSelectionHandle? selectionHandle;
  final void Function(Map<String, dynamic>, Future<void> Function())? onTask;
  final void Function(Map<String, dynamic>, Future<void> Function())?
  onMessageTask;
  @override
  State<ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<ConversationPanel> {
  RaftConversationTabId tab = RaftConversationTabId.chat;
  String? scope;
  final sectionBodies = <RaftConversationTabId, Widget>{};
  Object? fileFormatting;
  final chatSlot = GlobalKey();
  final files = AttachmentFiles();
  WorkspaceController get w => widget.controller;

  @override
  void didUpdateWidget(ConversationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != w) {
      oldWidget.controller.releaseChatTabPresentation(this);
      scope = null;
    }
    if (oldWidget.controller != w ||
        oldWidget.selectionHandle != widget.selectionHandle ||
        (oldWidget.onTask == null) != (widget.onTask == null) ||
        (oldWidget.onMessageTask == null) != (widget.onMessageTask == null) ||
        (oldWidget.onViewBilling == null) != (widget.onViewBilling == null)) {
      sectionBodies.clear();
    }
  }

  void openTask(Map<String, dynamic> task, Future<void> Function() refresh) =>
      widget.onTask?.call(task, refresh);
  void openMessageTask(
    Map<String, dynamic> task,
    Future<void> Function() refresh,
  ) => widget.onMessageTask?.call(task, refresh);
  void viewBilling() => widget.onViewBilling?.call();

  @override
  void dispose() {
    w.releaseChatTabPresentation(this);
    super.dispose();
  }

  SourceTimeFormatter formatter(BuildContext context) => SourceTimeFormatter(
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
  );

  void selectTab(RaftConversationTabId value) {
    setState(() => tab = value);
    if (w.server != null) {
      w.navigation.navigate(
        w.location.withQuery({
          'chatTab': value == RaftConversationTabId.chat ? null : value.name,
        }),
        kind: RaftNavigationKind.replace,
      );
      w.notifyListeners();
    }
  }

  bool _usesThumbnail(
    SourceChannelFileEntry file,
    SourceChannelImageRendition rendition,
  ) {
    final thumbnail = file.metadata['thumbnailUrl'];
    return thumbnail is String &&
        thumbnail.isNotEmpty &&
        (rendition == SourceChannelImageRendition.thumbnail ||
            file.mimeType.toLowerCase().split(';').first.trim() ==
                'image/svg+xml');
  }

  AttachmentImageKey _imageKey(
    SourceChannelFileEntry file,
    SourceChannelImageRendition rendition,
  ) => AttachmentImageKey.fromMetadata(
    scope: w.attachmentImageScope,
    channelId: file.channelId,
    metadata: file.metadata,
    rendition: _usesThumbnail(file, rendition) ? 'thumbnail' : 'original',
    // The Files row tile is 56px: never decode the original for it (bounded
    // for the densest displays, 3x). Previews decode at full size.
    target: rendition == SourceChannelImageRendition.thumbnail
        ? AttachmentDecodeTarget.box(56, 56, devicePixelRatio: 3, cover: true)
        : null,
  );

  /// Already decoded Files images (tab revisit) paint in the first frame.
  SourceChannelImageLease? peekImage(
    SourceChannelFileEntry file,
    bool Function() authorized,
    SourceChannelImageRendition rendition,
  ) {
    if (!authorized()) return null;
    final lease = w.attachmentMedia.peekImage(
      _imageKey(file, rendition),
      authorized: authorized,
    );
    final provider = lease?.lease.value;
    if (lease == null) return null;
    if (provider == null) {
      lease.release();
      return null;
    }
    return SourceChannelImageLease(
      provider: provider,
      release: () async => lease.release(),
    );
  }

  Future<SourceChannelImageLease?> acquireImage(
    SourceChannelFileEntry file,
    bool Function() authorized,
    SourceChannelImageRendition rendition,
  ) async {
    if (!authorized()) return null;
    final usesThumbnail = _usesThumbnail(file, rendition);
    final thumbnail = file.metadata['thumbnailUrl'];
    final key = _imageKey(file, rendition);
    final lease = w.attachmentMedia.acquireImage(
      key,
      authorized: authorized,
      // The 56px row tile takes whichever version is already on disk; a
      // preview (no decode target) needs its own full-size rendition.
      bestAvailable: rendition == SourceChannelImageRendition.thumbnail,
      load: (cancel) async {
        String url;
        if (usesThumbnail) {
          url = thumbnail;
        } else {
          url = await w.attachmentMedia.url(
            file.id,
            disposition: null,
            channelId: file.channelId,
          );
          if (cancel.isCancelled) throw const StaleAttachmentImage();
        }
        return files.image(url, cancel: cancel);
      },
    );
    try {
      final provider = await lease.lease.ready;
      return SourceChannelImageLease(
        provider: provider,
        release: () async => lease.release(),
      );
    } catch (_) {
      lease.release();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentScope =
        '${identityHashCode(w)}:${w.client.generation}:'
        '${w.client.user?.id}:${w.server?.id}:${w.server?.string('role')}:${w.channel?.id}';
    if (scope != currentScope) {
      scope = currentScope;
      tab = RaftConversationTabId.chat;
      sectionBodies.clear();
    }
    final formatting = (
      Localizations.localeOf(context),
      MediaQuery.alwaysUse24HourFormatOf(context),
      w.client.user?.string('preferredTimezone'),
      w.client.user?.string('timezone'),
      w.client.user?.string('preferredTimeFormat'),
      w.client.user?.string('timeFormat'),
    );
    if (fileFormatting != formatting) {
      fileFormatting = formatting;
      sectionBodies.remove(RaftConversationTabId.files);
    }
    if (w.server != null) {
      final requested = w.location.chatTab ?? 'chat';
      // ignore: raft_lints/avoid_render_where_without_or_else -- RaftLocation.chatTab only returns chat, tasks or files, all enum names.
      tab = RaftConversationTabId.values.firstWhere(
        (id) => id.name == requested,
      );
    }
    final channel = w.channel;
    final hasTabs = channel != null && channel.type != 'thread';
    if (!hasTabs) tab = RaftConversationTabId.chat;
    w.setChatTabPresentation(this, tab == RaftConversationTabId.chat);
    final order = <RaftConversationTabId>[];
    for (final value in w.sidebarOrder['channelPanelTabOrder'] as List? ?? []) {
      for (final id in RaftConversationTabId.values) {
        if (id.name == value && !order.contains(id)) order.add(id);
      }
    }
    for (final id in RaftConversationTabId.values) {
      if (!order.contains(id)) order.add(id);
    }
    final tokens = RaftTokens.of(context);
    // ConversationPanelContent paints the card surface; Elegant dark tab pages
    // (Tasks `dark:bg-transparent`, Files) show it rather than the canvas.
    final surface = tokens.dark && !tokens.brutal
        ? tokens.card
        : tokens.card.withAlpha(0);
    return Column(
      children: [
        if (hasTabs && !widget.hideHeader)
          RaftConversationTabs(
            key: const Key('conversation-tabs'),
            tabs: [
              for (final id in order)
                RaftConversationTab(
                  id: id,
                  label: raftText(context, switch (id) {
                    RaftConversationTabId.chat => 'Chat',
                    RaftConversationTabId.tasks => 'Tasks',
                    RaftConversationTabId.files => 'Files',
                  }),
                ),
            ],
            value: tab,
            onChanged: selectTab,
            // Web `SortableTabsList`: the new order is saved for every device.
            reorderWrapper: conversationTabReorder(
              order: order,
              touch: RaftInteraction.of(context).touch,
              onReorder: (next) => unawaited(
                w.updateSidebarOrder({
                  'channelPanelTabOrder': [for (final id in next) id.name],
                }),
              ),
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: surface,
            child: RaftSectionPager<RaftConversationTabId>(
            key: ValueKey(currentScope),
            sections: hasTabs ? order : const [RaftConversationTabId.chat],
            value: tab,
            initiallyMounted: const [RaftConversationTabId.chat],
            swipeEnabled:
                hasTabs &&
                !widget.hideHeader &&
                RaftInteraction.of(context).touch,
            onChanged: selectTab,
            // Reuse the same widget for a visited data owner. Changing only
            // the selected section must not update every page's root widget.
            // Each page still listens to data, theme and permission changes.
            builder: (context, id) => sectionBodies.putIfAbsent(
              id,
              () => switch (id) {
                RaftConversationTabId.chat => KeyedSubtree(
                  key: chatSlot,
                  // PageView retains the laid-out chat, so swiping back paints
                  // the cached rows immediately. Pager TickerMode gates its
                  // presentation; hiding it with Offstage forced relayout.
                  child: RaftChatView(
                    controller: w,
                    selectionHandle: widget.selectionHandle,
                    onTask: widget.onMessageTask == null
                        ? null
                        : openMessageTask,
                    onViewBilling: widget.onViewBilling == null
                        ? null
                        : viewBilling,
                    onOpenChannelSettings: widget.onOpenChannelSettings,
                  ),
                ),
                RaftConversationTabId.tasks => ResourceView(
                  key: ValueKey('channel-tasks-$currentScope'),
                  controller: w,
                  section: 'tasks',
                  channelId: channel!.id,
                  onTask: widget.onTask == null ? null : openTask,
                  onMessage: (id, message) async {
                    setState(() => tab = RaftConversationTabId.chat);
                    w.setChatTabPresentation(this, true);
                    await w.jumpToMessage(id, message);
                  },
                ),
                RaftConversationTabId.files => SourceChannelFilesView(
                  key: ValueKey('channel-files-$currentScope'),
                  controller: w,
                  channelId: channel!.id,
                  formatCreatedAt: formatter(context).shortDateTime,
                  acquireImage: acquireImage,
                  peekImage: peekImage,
                  onOpenSource: (file) async {
                    setState(() => tab = RaftConversationTabId.chat);
                    w.setChatTabPresentation(this, true);
                    await w.jumpToMessage(channel.id, file.messageId);
                  },
                ),
              },
            ),
          ),
          ),
        ),
      ],
    );
  }
}
