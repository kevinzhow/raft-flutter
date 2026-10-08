import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import '../data/attachment_image_repository.dart';
import '../data/source_channel_files_store.dart';
import '../platform/attachment_files.dart';
import 'chat_view.dart';
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
  });
  final WorkspaceController controller;
  final ChatSelectionHandle? selectionHandle;
  @override
  State<ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<ConversationPanel> {
  RaftConversationTabId tab = RaftConversationTabId.chat;
  String? scope;
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
  }

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

  Future<SourceChannelImageLease?> acquireImage(
    SourceChannelFileEntry file,
    bool Function() authorized,
    SourceChannelImageRendition rendition,
  ) async {
    if (!authorized()) return null;
    final thumbnail = file.metadata['thumbnailUrl'];
    final usesThumbnail =
        thumbnail is String &&
        thumbnail.isNotEmpty &&
        (rendition == SourceChannelImageRendition.thumbnail ||
            file.mimeType.toLowerCase().split(';').first.trim() ==
                'image/svg+xml');
    final key = AttachmentImageKey.fromMetadata(
      scope: w.attachmentImageScope,
      channelId: file.channelId,
      metadata: file.metadata,
      rendition: usesThumbnail ? 'thumbnail' : 'original',
    );
    final lease = w.acquireAttachmentImage(
      key,
      authorized: authorized,
      load: (cancel) async {
        String url;
        if (usesThumbnail) {
          url = thumbnail;
        } else {
          final result = await w.client.get(
            '/attachments/${Uri.encodeComponent(file.id)}/url',
          );
          if (cancel.isCancelled ||
              result is! Map ||
              result['url'] is! String) {
            throw const StaleAttachmentImage();
          }
          url = result['url'];
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
    return Column(
      children: [
        if (hasTabs)
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
            onChanged: (value) => setState(() => tab = value),
          ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              KeyedSubtree(
                key: chatSlot,
                child: Visibility(
                  visible: tab == RaftConversationTabId.chat,
                  maintainState: true,
                  child: RaftChatView(
                    controller: w,
                    selectionHandle: widget.selectionHandle,
                  ),
                ),
              ),
              if (channel != null && tab == RaftConversationTabId.tasks)
                ResourceView(
                  key: ValueKey('channel-tasks-$currentScope'),
                  controller: w,
                  section: 'tasks',
                  channelId: channel.id,
                  onMessage: (id, message) async {
                    setState(() => tab = RaftConversationTabId.chat);
                    w.setChatTabPresentation(this, true);
                    await w.jumpToMessage(id, message);
                  },
                ),
              if (channel != null && tab == RaftConversationTabId.files)
                SourceChannelFilesView(
                  key: ValueKey('channel-files-$currentScope'),
                  controller: w,
                  channelId: channel.id,
                  formatCreatedAt: formatter(context).shortDateTime,
                  acquireImage: acquireImage,
                  onOpenSource: (file) async {
                    setState(() => tab = RaftConversationTabId.chat);
                    w.setChatTabPresentation(this, true);
                    await w.jumpToMessage(channel.id, file.messageId);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
