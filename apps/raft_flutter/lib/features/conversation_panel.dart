import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/raft_navigation_history.dart';
import 'channel_files_media.dart';
import 'channel_announcement_host.dart';
import 'channel_side_area.dart' show insideChannelSideArea;
import 'channel_side_flags.dart';
import 'chat_view.dart';
import 'conversation_tab_reorder.dart';
import 'message_selection.dart';
import 'resource_view.dart';
import 'source_channel_files_view.dart';

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
  late ChannelFilesMedia media = ChannelFilesMedia(w);
  WorkspaceController get w => widget.controller;
  late ChannelSideFlags sideFlags;

  @override
  void initState() {
    super.initState();
    sideFlags = ChannelSideFlags.of(w)..addListener(sideFlagsChanged);
  }

  /// Task v2: Tasks and Files are cards beside the chat, so no tab row.
  void sideFlagsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ConversationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != w) {
      sideFlags.removeListener(sideFlagsChanged);
      sideFlags = ChannelSideFlags.of(w)..addListener(sideFlagsChanged);
      oldWidget.controller.releaseChatTabPresentation(this);
      scope = null;
      media = ChannelFilesMedia(w);
    }
    if (oldWidget.controller != w ||
        oldWidget.selectionHandle != widget.selectionHandle ||
        (oldWidget.onTask == null) != (widget.onTask == null) ||
        (oldWidget.onMessageTask == null) != (widget.onMessageTask == null) ||
        (oldWidget.onViewBilling == null) != (widget.onViewBilling == null) ||
        oldWidget.hideHeader != widget.hideHeader) {
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
    sideFlags.removeListener(sideFlagsChanged);
    w.releaseChatTabPresentation(this);
    super.dispose();
  }

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
    // Task v2 moves Tasks and Files into cards beside the chat; a panel with
    // no side area around it (the Search / Activity detail pane) keeps them
    // as tabs, so they stay reachable.
    final hasTabs =
        channel != null &&
        channel.type != 'thread' &&
        !(sideFlags.taskV2 && insideChannelSideArea(context));
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
    // raft-ui ConversationPanelContent is `bg-layer-canvas` (the panel role);
    // in dark the Tasks and Files pages are transparent over it.
    final surface = tokens.colors['layer-conversation-tab-page']!;
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
              // Web v1.24: these tabs switch by tap only; a sideways drag on
              // the chat is the time reveal's (Kevin, #raft-flutter e99dbd89).
              swipeEnabled: false,
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
                    child: Column(
                      children: [
                        if (!widget.hideHeader && channel != null)
                          ChannelAnnouncementHost(
                            controller: w,
                            channel: channel,
                            onOpenSettings: widget.onOpenChannelSettings,
                          ),
                        Expanded(
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
                      ],
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
                    formatCreatedAt: media.formatter(context).shortDateTime,
                    acquireImage: media.acquireImage,
                    peekImage: media.peekImage,
                    beforeOpenSource: (file) {
                      if (file.sourceType == 'task') return;
                      setState(() => tab = RaftConversationTabId.chat);
                      w.setChatTabPresentation(this, true);
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
