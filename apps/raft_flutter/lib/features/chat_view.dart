import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/workspace_controller.dart';
import '../platform/file_selection.dart';
import 'attachment_view.dart';
import 'thread_actions.dart';
import 'message_presentation.dart';
import 'message_reference_directory.dart';
import 'share_message_link.dart';
import 'private_route_guard.dart';
import '../platform/native_sharing.dart';
import 'message_selection.dart';
import 'message_image_export.dart';
import 'forward_messages_dialog.dart';
import 'composer_directory.dart';

class RaftChatView extends StatefulWidget {
  const RaftChatView({
    super.key,
    required this.controller,
    this.thread = false,
    this.selectionHandle,
  });
  final WorkspaceController controller;
  final bool thread;
  final ChatSelectionHandle? selectionHandle;
  @override
  State<RaftChatView> createState() => _RaftChatViewState();
}

class _RaftChatViewState extends State<RaftChatView> {
  late MessageReferenceDirectory referenceDirectory;
  late ComposerDirectory composerDirectory;
  late MessageSelection selection;
  bool capturingSelection = false;
  String? selectionError;
  final adapter = chat.InMemoryChatController();
  final viewport = ScrollController();
  String? scope;
  String? scrolledHighlight;
  int? scrolledWindow, adapterWindow;
  int bindingRevision = 0;
  final focusAnchors = <String, GlobalKey>{};
  Future<void> updates = Future.value();
  WorkspaceController get w => widget.controller;
  List<RaftMessage> get rows => widget.thread ? w.replies : w.messages;
  @override
  void initState() {
    super.initState();
    referenceDirectory = MessageReferenceDirectory(w)
      ..addListener(referencesChanged);
    composerDirectory = ComposerDirectory(w)..addListener(referencesChanged);
    selection = MessageSelection(w, thread: widget.thread)
      ..addListener(selectionChanged);
    w.addListener(sync);
    sync();
  }

  @override
  void didUpdateWidget(covariant RaftChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != w;
    final scopeChanged = controllerChanged || oldWidget.thread != widget.thread;
    if (scopeChanged) {
      bindingRevision++;
      // The mobile shell reuses this State when replacing its full-screen
      // thread with the channel. Every controller/role-bound model must follow
      // the new widget, even when no controller event follows that layout.
      oldWidget.selectionHandle?.update(false, null);
      selection.dispose();
      if (controllerChanged) {
        oldWidget.controller.removeListener(sync);
        referenceDirectory.dispose();
        composerDirectory.dispose();
        referenceDirectory = MessageReferenceDirectory(w)
          ..addListener(referencesChanged);
        composerDirectory = ComposerDirectory(w)
          ..addListener(referencesChanged);
        w.addListener(sync);
      }
      selection = MessageSelection(w, thread: widget.thread)
        ..addListener(selectionChanged);
      selectionError = null;
      capturingSelection = false;
      scope = null;
      adapterWindow = null;
      scrolledHighlight = null;
      scrolledWindow = null;
      focusAnchors.clear();
      sync();
    } else if (oldWidget.selectionHandle != widget.selectionHandle) {
      oldWidget.selectionHandle?.update(false, null);
      widget.selectionHandle?.update(selection.active, selection.exit);
    }
  }

  void selectionChanged() {
    widget.selectionHandle?.update(selection.active, selection.exit);
    if (mounted) setState(() {});
  }

  Future<void> copySelection() async {
    if (!selection.active || selection.selected.isEmpty) return;
    final authority = workspaceAuthority(w), snapshot = selection.selected;
    try {
      await Clipboard.setData(
        ClipboardData(text: selectedMessagesMarkdown(snapshot)),
      );
      if (mounted && authority == workspaceAuthority(w)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(raftText(context, 'Copied Markdown'))),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => selectionError = raftText(
            context,
            'Could not copy the selected messages.',
          ),
        );
      }
    }
  }

  bool ordinary(RaftMessage m) =>
      m.string('messageType') == 'chat' && m.json['actionMetadata'] == null;
  Future<void> forwardSelection() async {
    final messages = selection.selected.map((r) => r.message).toList();
    if (capturingSelection ||
        messages.isEmpty ||
        messages.length > 20 ||
        !messages.every(ordinary)) {
      return;
    }
    final authority = workspaceAuthority(w);
    try {
      final done = await forwardMessages(context, w, messages);
      if (mounted && authority == workspaceAuthority(w) && done) {
        selection.exit();
      }
    } catch (e) {
      if (mounted && authority == workspaceAuthority(w)) {
        setState(() => selectionError = '$e');
      }
    }
  }

  Future<void> previewSelection() async {
    if (capturingSelection || !selection.active || selection.selected.isEmpty) {
      return;
    }
    final scope = selection.scope;
    setState(() {
      capturingSelection = true;
      selectionError = null;
    });
    try {
      final saved = await previewMessageImage(
        context,
        w,
        messages: selection.selected,
        thread: widget.thread,
        width: (context.size?.width ?? MediaQuery.sizeOf(context).width) - 48,
        references: referenceDirectory.references,
        clock: clock,
      );
      if (saved == true && mounted && scope == selection.scope) {
        selection.exit();
      }
    } catch (e) {
      if (mounted && scope == selection.scope) {
        setState(() => selectionError = raftText(context, '$e'));
      }
    } finally {
      if (mounted) setState(() => capturingSelection = false);
    }
  }

  void referencesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.selectionHandle?.update(false, null);
    selection.dispose();
    referenceDirectory.dispose();
    composerDirectory.dispose();
    w.removeListener(sync);
    adapter.dispose();
    viewport.dispose();
    super.dispose();
  }

  void sync() {
    // Upload drafts and composer authority are independent of the chat
    // adapter's message diff. Rebuild them on this view's own listener even
    // when an adaptive/setup parent retains the same child instance.
    if (mounted) setState(() {});
    final revision = bindingRevision, controller = w, thread = widget.thread;
    bool currentBinding() =>
        mounted &&
        revision == bindingRevision &&
        identical(controller, w) &&
        thread == widget.thread;
    updates = updates.then((_) async {
      if (!currentBinding()) return;
      final id = widget.thread ? w.threadChannelId : w.channel?.id;
      for (final row in rows) {
        if ((row.json['reactions'] as List? ?? []).isNotEmpty) {
          w.hydrateReactionViewer(row);
        }
      }
      final projected = rows
          .map(
            (m) => chat.Message.custom(
              id: m.id,
              authorId: m.senderId.isEmpty ? 'system' : m.senderId,
              createdAt: m.createdAt,
              metadata: m.json,
            ),
          )
          .toList();
      final window = widget.thread ? w.threadGeneration : w.channelGeneration;
      final loading = widget.thread ? w.threadLoading : w.channelLoading;
      final target = w.highlightedMessageId;
      focusAnchors.removeWhere((id, _) => id != target);
      if (scope != id ||
          (!loading && target != null && adapterWindow != window)) {
        scope = id;
        // A context replacement has different scroll bounds. Carrying the old
        // history offset into its first layout can leave the sliver entirely
        // outside the viewport, preventing the observer from finding a target.
        // Ordinary diffs and history prepend do not enter this branch.
        if (viewport.hasClients) viewport.jumpTo(0);
        await adapter.setMessages(projected, animated: false);
        if (!currentBinding()) return;
        scrolledHighlight = null;
        adapterWindow = window;
      }
      final wanted = projected.map((m) => m.id).toSet();
      for (final old in List<chat.Message>.of(adapter.messages)) {
        if (!wanted.contains(old.id)) {
          await adapter.removeMessage(old, animated: false);
          if (!currentBinding()) return;
        }
      }
      for (var i = 0; i < projected.length; i++) {
        final next = projected[i];
        final existing = adapter.messages
            .where((m) => m.id == next.id)
            .firstOrNull;
        if (existing == null) {
          await adapter.insertMessage(next, index: i, animated: false);
        } else if (jsonEncode(existing.metadata) != jsonEncode(next.metadata)) {
          await adapter.updateMessage(existing, next);
        }
        if (!currentBinding()) return;
      }
      if (!loading &&
          target != null &&
          (target != scrolledHighlight || window != scrolledWindow) &&
          adapter.messages.any((m) => m.id == target)) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!currentBinding() ||
              target != w.highlightedMessageId ||
              window !=
                  (widget.thread ? w.threadGeneration : w.channelGeneration)) {
            return;
          }
          // ChatAnimatedList consumes controller operations asynchronously.
          // Allow its next layout to attach the message observer before jumping.
          await WidgetsBinding.instance.endOfFrame;
          if (!currentBinding() ||
              target != w.highlightedMessageId ||
              window !=
                  (widget.thread ? w.threadGeneration : w.channelGeneration)) {
            return;
          }
          // A pending list animation may have used the previous bounds. Repair
          // only this committed context before asking its observer to focus.
          if (viewport.hasClients && viewport.position.outOfRange) {
            viewport.jumpTo(
              viewport.offset.clamp(
                viewport.position.minScrollExtent,
                viewport.position.maxScrollExtent,
              ),
            );
            await WidgetsBinding.instance.endOfFrame;
          }
          if (!currentBinding() ||
              target != w.highlightedMessageId ||
              window !=
                  (widget.thread ? w.threadGeneration : w.channelGeneration)) {
            return;
          }
          // The package's void focus receipt also covers an unattached list
          // or a target not yet consumed by its operation listener. Confirm
          // the actual lazy row, and retry only this authorized context.
          for (var attempt = 0; attempt < 8; attempt++) {
            if (!currentBinding() ||
                target != w.highlightedMessageId ||
                window !=
                    (widget.thread
                        ? w.threadGeneration
                        : w.channelGeneration)) {
              return;
            }
            await adapter.scrollToMessage(
              target,
              duration: Duration.zero,
              alignment: .3,
            );
            WidgetsBinding.instance.scheduleFrame();
            await WidgetsBinding.instance.endOfFrame;
            if (!currentBinding() ||
                target != w.highlightedMessageId ||
                window !=
                    (widget.thread
                        ? w.threadGeneration
                        : w.channelGeneration)) {
              return;
            }
            if (focusReceiptVisible(target)) {
              scrolledHighlight = target;
              scrolledWindow = window;
              return;
            }
          }
        });
      }
    });
  }

  bool focusReceiptVisible(String target) {
    if (!viewport.hasClients) return false;
    final row = focusAnchors[target]?.currentContext?.findRenderObject();
    final view = viewport.position.context.storageContext.findRenderObject();
    if (row is! RenderBox ||
        view is! RenderBox ||
        !row.attached ||
        !view.attached ||
        !row.hasSize ||
        !view.hasSize) {
      return false;
    }
    return (row.localToGlobal(Offset.zero) & row.size).overlaps(
      view.localToGlobal(Offset.zero) & view.size,
    );
  }

  Future<void> link(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && ['https', 'http', 'mailto'].contains(uri.scheme)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> attach() async {
    final scope = w.draftScope(thread: widget.thread),
        generation = w.ledger.generation;
    try {
      final files = await selectUploads();
      if (files.isEmpty || !mounted) return;
      if (generation != w.ledger.generation ||
          scope != w.draftScope(thread: widget.thread)) {
        return;
      }
      if (files.length + w.uploads(thread: widget.thread).length > 10) {
        throw const RaftApiException('Attach up to 10 files per message.');
      }
      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (!mounted ||
            generation != w.ledger.generation ||
            scope != w.draftScope(thread: widget.thread)) {
          return;
        }
        await w.attachUpload(file.name, bytes, thread: widget.thread);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> actions(RaftMessage message) async {
    final authority = workspaceAuthority(w);
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(raftText(context, 'Select messages')),
                onTap: () => Navigator.pop(context, 'select'),
              ),
              if (ordinary(message))
                ListTile(
                  leading: const Icon(Icons.forward),
                  title: Text(raftText(context, 'Forward')),
                  onTap: () => Navigator.pop(context, 'forward'),
                ),
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: Text(raftText(context, 'Reply in thread')),
                onTap: () => Navigator.pop(context, 'thread'),
              ),
              if (NativeSharing().supported)
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: Text(raftText(context, 'Share link')),
                  onTap: () => Navigator.pop(context, 'share-link'),
                ),
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(raftText(context, 'Copy link')),
                onTap: () => Navigator.pop(context, 'copy-link'),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: Text(raftText(context, 'Save message')),
                onTap: () => Navigator.pop(context, 'save'),
              ),
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: Text(raftText(context, 'React 👍')),
                onTap: () => Navigator.pop(context, 'react'),
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outlined),
                title: Text(raftText(context, 'Create task from message')),
                onTap: () => Navigator.pop(context, 'task'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || authority != workspaceAuthority(w) || result == null) {
      return;
    }
    try {
      if (result == 'share-link' || result == 'copy-link') {
        await shareMessageLink(
          context,
          w,
          message,
          copy: result == 'copy-link',
        );
      }
      if (result == 'forward' &&
          mounted &&
          authority == workspaceAuthority(w)) {
        await forwardMessages(context, w, [message]);
      }
      if (result == 'select') selection.enter(message.id);
      if (result == 'thread') await w.openThread(message);
      if (result == 'save') {
        await w.command(
          'POST',
          '/channels/saved',
          data: {'messageId': message.id},
        );
      }
      if (result == 'react') {
        await w.toggleReaction(message, '👍');
      }
      if (result == 'task') {
        await w.command(
          'POST',
          '/tasks/convert-message',
          data: {'messageId': message.id},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> react(RaftMessage m, String emoji) async {
    try {
      await w.toggleReaction(m, emoji);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String clock(DateTime stamp) {
    final time = TimeOfDay.fromDateTime(stamp.toLocal());
    final preference = w.client.user?.string('preferredTimeFormat');
    if (preference == '24h') {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    if (preference == '12h') {
      return '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}:${time.minute.toString().padLeft(2, '0')} ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
    }
    return time.format(context);
  }

  Widget? inlineThreadReplies(RaftMessage parent, {required bool parentTile}) {
    if (parentTile ||
        widget.thread ||
        w.channel == null ||
        !w.can('viewChannel', resource: w.channel)) {
      return null;
    }
    final summary = w.threadSummaries[parent.id];
    if (summary is! Map || summary['latestReplies'] is! List) return null;
    final count = int.tryParse('${summary['replyCount']}') ?? 0;
    final projected = <RaftThreadReplyPreview>[];
    for (final value in summary['latestReplies'] as List) {
      if (value is! Map ||
          value['messageId'] is! String ||
          value['preview'] is! String ||
          !{
            'user',
            'agent',
            'external_projection',
          }.contains(value['senderType'])) {
        continue;
      }
      final display = value['senderDisplayName'], name = value['senderName'];
      final author = display is String && display.isNotEmpty
          ? display
          : name is String
          ? name
          : '';
      final time = DateTime.tryParse('${value['createdAt']}');
      projected.add(
        RaftThreadReplyPreview(
          id: value['messageId'] as String,
          author: author,
          preview: value['preview'] as String,
          senderType: value['senderType'] as String,
          timestamp: time == null ? '' : clock(time),
        ),
      );
    }
    if (count <= 0 || projected.isEmpty) return null;
    final authority = workspaceAuthority(w);
    void open(String? replyId, {bool preview = false}) {
      if (!mounted ||
          authority != workspaceAuthority(w) ||
          !w.messages.any((m) => m.id == parent.id) ||
          !w.can('viewChannel', resource: w.channel)) {
        return;
      }
      if (preview && replyId != null) {
        final live = w.threadSummaries[parent.id];
        if (live is! Map ||
            live['latestReplies'] is! List ||
            !(live['latestReplies'] as List).whereType<Map>().any(
              (r) => r['messageId'] == replyId && r['senderType'] != 'system',
            )) {
          return;
        }
      }
      w.openThread(parent, focusedMessageId: replyId);
    }

    return RaftThreadReplies(
      replies: projected,
      replyCount: count,
      unreadCount: int.tryParse('${summary['unreadCount']}') ?? 0,
      hasDraft: w.drafts['thread:${parent.id}']?.trim().isNotEmpty == true,
      onOpen: () => open(
        summary['firstUnreadMessageId'] is String
            ? summary['firstUnreadMessageId'] as String
            : null,
      ),
      onOpenReply: (id) => open(id, preview: true),
    );
  }

  Widget messageTile(RaftMessage m, {bool parent = false}) => RaftMessageTile(
    key: ValueKey('message-${m.id}'),
    author: m.author,
    content: m.content,
    body: MessagePresentation(
      controller: w,
      message: m,
      onExternalLink: link,
      directoryReferences: referenceDirectory.references,
      fontSize: switch (w.client.user?.string('preferredMessageBodyFontSize')) {
        'sm' => 12,
        'lg' => 16,
        _ => 14,
      },
    ),
    bodyFontSize: switch (w.client.user?.string(
      'preferredMessageBodyFontSize',
    )) {
      'sm' => 12,
      'lg' => 16,
      _ => 14,
    },
    collapseLongMessages:
        (m.json['actionMetadata'] is! Map ||
            m.json['actionMetadata']['kind'] != 'action-card') &&
        w.channel?.json['collapseLongMessages'] != false,
    timestamp: m.createdAt == null ? '' : clock(m.createdAt!),
    badge: m.string('senderType') == 'agent'
        ? raftText(context, 'Agent')
        : null,
    onActions: () => actions(m),
    onThread: parent || widget.thread ? null : () => w.openThread(m),
    threadPreview: inlineThreadReplies(m, parentTile: parent),
    threadLabel: w.threadSummaries[m.id] is Map
        ? raftFormat(context, '{count} replies', {
            'count': w.threadSummaries[m.id]['replyCount'] ?? 0,
          })
        : null,
    onLink: link,
    attachments:
        m.json['actionMetadata'] is Map &&
            m.json['actionMetadata']['kind'] == 'forwarded-bundle'
        ? []
        : m.attachments,
    attachmentBuilder: (metadata) => AttachmentView(
      key: ValueKey('attachment-${metadata['id']}'),
      controller: w,
      metadata: metadata,
      messageId: m.id,
    ),
    reactions: (m.json['reactions'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
    reactedEmojis: w.reactionViewer.reacted(m.id) ?? const {},
    onReaction: (emoji) => react(m, emoji),
  );
  Widget tile(RaftMessage m, {bool parent = false}) {
    final body = messageTile(m, parent: parent);
    final child = !parent && m.id == w.highlightedMessageId
        ? KeyedSubtree(
            key: focusAnchors.putIfAbsent(m.id, GlobalKey.new),
            child: body,
          )
        : body;
    if (!selection.active) return child;
    final checked = selection.ids.contains(m.id);
    return Semantics(
      selected: checked,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Checkbox(
              value: checked,
              semanticLabel: raftFormat(context, 'Select message by {name}', {
                'name': m.author,
              }),
              onChanged: capturingSelection
                  ? null
                  : (_) => selection.toggle(m.id),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: capturingSelection ? null : () => selection.toggle(m.id),
              child: AbsorbPointer(child: child),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.thread ? w.threadLoading : w.channelLoading;
    final composeScope = w.draftScope(thread: widget.thread),
        composeAuthority = workspaceAuthority(w);
    var composeWindow = widget.thread
        ? w.threadGeneration
        : w.channelGeneration;
    bool currentComposer() =>
        mounted &&
        composeScope == w.draftScope(thread: widget.thread) &&
        composeAuthority == workspaceAuthority(w) &&
        composeWindow ==
            (widget.thread ? w.threadGeneration : w.channelGeneration);
    Future<bool> sendCurrent(
      String text,
      List<Map<String, dynamic>> mentions,
    ) async {
      if (!currentComposer()) return false;
      final accepted = await w.send(
        text,
        thread: widget.thread,
        mentions: mentions,
        onWindowRefreshed: (window) {
          if (mounted &&
              composeScope == w.draftScope(thread: widget.thread) &&
              composeAuthority == workspaceAuthority(w)) {
            composeWindow = window;
          }
        },
      );
      return accepted && currentComposer();
    }

    if (!widget.thread && w.channel == null) {
      return RaftEmptyState(
        title: raftText(context, 'Welcome to Raft'),
        detail: raftText(
          context,
          'Choose a channel or direct message to start.',
        ),
      );
    }
    if (loading && rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        if (widget.thread && w.threadParent != null)
          ThreadActions(
            key: ValueKey('thread-actions-${w.threadParent!.id}'),
            controller: w,
            parent: w.threadParent!,
          ),
        if (widget.thread && w.threadParent != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: tile(w.threadParent!, parent: true),
            ),
          ),
        if (widget.thread ? w.threadHasMore : w.hasMore)
          TextButton.icon(
            onPressed: w.loadingOlder
                ? null
                : () => w.older(thread: widget.thread),
            icon: const Icon(Icons.history, size: 16),
            label: Text(
              raftText(
                context,
                w.loadingOlder ? 'Loading history…' : 'Load earlier messages',
              ),
            ),
          ),
        Expanded(
          child: Chat(
            currentUserId: w.client.user?.id ?? '',
            resolveUser: (id) async => chat.User(id: id),
            chatController: adapter,
            backgroundColor: RaftTokens.of(context).canvas,
            builders: chat.Builders(
              composerBuilder: (_) => const SizedBox.shrink(),
              chatMessageBuilder: (
                context,
                message,
                index,
                animation,
                child, {
                isRemoved,
                required isSentByMe,
                groupStatus,
              }) => child,
              customMessageBuilder: (
                context,
                message,
                index, {
                required isSentByMe,
                groupStatus,
              }) => tile(RaftMessage(message.metadata!)),
              chatAnimatedListBuilder: (context, item) => ChatAnimatedList(
                scrollController: viewport,
                key: ValueKey(
                  'chat-list-${widget.thread ? 'thread' : 'channel'}',
                ),
                itemBuilder: item,
                onEndReached: () => w.older(thread: widget.thread),
                initialScrollToEndMode: w.highlightedMessageId == null
                    ? InitialScrollToEndMode.jump
                    : InitialScrollToEndMode.none,
              ),
              emptyChatListBuilder: (_) => RaftEmptyState(
                title: raftText(context, 'Start the conversation'),
                detail: raftText(context, 'Send a message to this channel.'),
              ),
            ),
          ),
        ),
        if (!selection.active && w.uploads(thread: widget.thread).isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: w
                  .uploads(thread: widget.thread)
                  .map(
                    (draft) => RaftUploadChip(
                      name: draft.filename,
                      progress: draft.progress,
                      ready: draft.id != null,
                      error: draft.error,
                      onRetry: () =>
                          w.retryUpload(draft, thread: widget.thread),
                      onRemove: () =>
                          w.removeUpload(draft, thread: widget.thread),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (selection.active)
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): selection.exit,
            },
            child: Focus(
              autofocus: true,
              child: RaftSelectionToolbar(
                selected: selection.ids.length,
                total: selection.available.length,
                onExit: selection.exit,
                onSelectAll: selection.selectAll,
                onCopyMarkdown: copySelection,
                onPreview: previewSelection,
                onForward:
                    selection.selected.length <= 20 &&
                        selection.selected.every((r) => ordinary(r.message))
                    ? forwardSelection
                    : null,
                busy: capturingSelection,
                error:
                    selectionError ??
                    (selection.error == null
                        ? null
                        : raftText(context, selection.error!)),
              ),
            ),
          )
        else if (w.conversationPaused)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(raftText(context, 'Channel conversion in progress')),
          )
        else
          RaftComposer(
            initialDraft: w.drafts[w.draftScope(thread: widget.thread)] ?? '',
            onDraftChanged: (text) {
              if (currentComposer()) w.saveDraft(text, thread: widget.thread);
            },
            key: ValueKey(
              'compose-${widget.thread ? w.threadParent?.id : w.channel?.id}',
            ),
            onAttach: attach,
            pendingLabel: w.uploads(thread: widget.thread).isEmpty
                ? null
                : raftFormat(context, '{count} attachment(s)', {
                    'count': w.uploads(thread: widget.thread).length,
                  }),
            hint: widget.thread
                ? raftText(context, 'Reply in thread')
                : raftFormat(context, 'Message #{name}', {
                    'name': w.channel?.name ?? '',
                  }),
            enabled:
                !w.conversationPaused &&
                (widget.thread
                    ? w.threadParent != null && w.channel?.archived != true
                    : w.channel?.archived != true),
            canSend: w.uploadsReady(thread: widget.thread),
            suggestions: composerDirectory.suggestions,
            onSuggestionsRequested: (prefix) {
              if (currentComposer()) composerDirectory.request(prefix);
            },
            onSendWithMentions: sendCurrent,
            onSend: (text) => sendCurrent(text, const []),
          ),
      ],
    );
  }
}
