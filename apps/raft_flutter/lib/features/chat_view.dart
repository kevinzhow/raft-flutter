import 'dart:convert';
import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/workspace_controller.dart';
import '../data/source_time_formatter.dart';
import '../data/personal_presentation.dart';
import '../platform/file_selection.dart';
import 'attachment_view.dart';
import 'message_presentation.dart';
import 'message_reference_directory.dart';
import 'share_message_link.dart';
import 'private_route_guard.dart';
import '../platform/native_sharing.dart';
import 'message_selection.dart';
import 'message_image_export.dart';
import 'forward_messages_dialog.dart';
import 'composer_directory.dart';
import 'sender_avatar_projection.dart';
import 'message_reaction_projection.dart';
import 'message_agent_presentation.dart';
import 'agent_metadata_projection.dart';
import 'message_task_projection.dart';

/// Controlled mounted-viewport action; no route, controller or data ownership.
class ChatViewportHandle {
  Object? _owner;
  VoidCallback? _jump;
  void jumpToBeginning() => _jump?.call();
  void bind(Object owner, VoidCallback jump) {
    _owner = owner;
    _jump = jump;
  }

  void release(Object owner) {
    if (identical(_owner, owner)) {
      _owner = null;
      _jump = null;
    }
  }
}

class RaftChatView extends StatefulWidget {
  const RaftChatView({
    super.key,
    required this.controller,
    this.thread = false,
    this.selectionHandle,
    this.viewportHandle,
  });
  final WorkspaceController controller;
  final bool thread;
  final ChatSelectionHandle? selectionHandle;
  final ChatViewportHandle? viewportHandle;
  @override
  State<RaftChatView> createState() => _RaftChatViewState();
}

class _RaftChatViewState extends State<RaftChatView> {
  late MessageReferenceDirectory referenceDirectory;
  late ComposerDirectory composerDirectory;
  late MessageAgentPresentation agentPresentation;
  late MessageTaskProjection taskProjection;
  final composerHandle = RaftComposerHandle();
  OverlayEntry? reactionPicker;
  String? pickerMessageId, pickerAuthority;
  Timer? pickerCloseTimer;
  Size? pickerViewport;
  late MessageSelection selection;
  bool capturingSelection = false;
  bool alsoCreateTask = false;
  int taskChoiceRevision = 0;
  final Map<String, String> reactionFailures = {};
  final Map<String, Timer> reactionFailureTimers = {};
  String? selectionError;
  var adapter = chat.InMemoryChatController();
  var viewport = ScrollController();
  final retiredAdapters = <chat.InMemoryChatController>{};
  final retiredViewports = <ScrollController>{};
  int listRevision = 0;
  bool initialEndPending = true;
  String? scope;
  String? scrolledHighlight;
  int? scrolledWindow, adapterWindow;
  int bindingRevision = 0;
  bool presentationActive = true;
  int presentationRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextViewport = MediaQuery.sizeOf(context);
    if (pickerViewport != null && pickerViewport != nextViewport) {
      closeReactionPicker(rebuild: false);
    }
    pickerViewport = nextViewport;
    final active = Visibility.of(context);
    if (active != presentationActive) {
      presentationActive = active;
      ++presentationRevision;
      if (!active) closeReactionPicker();
      if (active) sync();
    }
  }

  final focusAnchors = <String, GlobalKey>{};
  Future<void> updates = Future.value();
  WorkspaceController get w => widget.controller;
  List<RaftMessage> get rows => widget.thread ? w.replies : w.messages;
  @override
  void initState() {
    super.initState();
    viewport.addListener(closePickerOnScroll);
    widget.viewportHandle?.bind(this, jumpToBeginning);
    referenceDirectory = MessageReferenceDirectory(w)
      ..addListener(referencesChanged);
    composerDirectory = ComposerDirectory(w)..addListener(referencesChanged);
    agentPresentation = MessageAgentPresentation(w, referenceDirectory)
      ..addListener(referencesChanged);
    taskProjection = MessageTaskProjection(w)..addListener(referencesChanged);
    selection = MessageSelection(w, thread: widget.thread)
      ..addListener(selectionChanged);
    w.addListener(sync);
    sync();
  }

  @override
  void didUpdateWidget(covariant RaftChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportHandle != widget.viewportHandle) {
      oldWidget.viewportHandle?.release(this);
      widget.viewportHandle?.bind(this, jumpToBeginning);
    }
    final controllerChanged = oldWidget.controller != w;
    final scopeChanged = controllerChanged || oldWidget.thread != widget.thread;
    if (scopeChanged) {
      closeReactionPicker();
      bindingRevision++;
      // The mobile shell reuses this State when replacing its full-screen
      // thread with the channel. Every controller/role-bound model must follow
      // the new widget, even when no controller event follows that layout.
      oldWidget.selectionHandle?.update(false, null);
      selection.dispose();
      if (controllerChanged) {
        oldWidget.controller.removeListener(sync);
        taskProjection.dispose();
        agentPresentation.dispose();
        referenceDirectory.dispose();
        composerDirectory.dispose();
        referenceDirectory = MessageReferenceDirectory(w)
          ..addListener(referencesChanged);
        composerDirectory = ComposerDirectory(w)
          ..addListener(referencesChanged);
        agentPresentation = MessageAgentPresentation(w, referenceDirectory)
          ..addListener(referencesChanged);
        taskProjection = MessageTaskProjection(w)
          ..addListener(referencesChanged);
        w.addListener(sync);
      }
      selection = MessageSelection(w, thread: widget.thread)
        ..addListener(selectionChanged);
      selectionError = null;
      capturingSelection = false;
      alsoCreateTask = false;
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

  void jumpToBeginning() {
    if (presentationActive && viewport.positions.length == 1) {
      viewport.jumpTo(viewport.position.minScrollExtent);
    }
  }

  void referencesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.viewportHandle?.release(this);
    widget.selectionHandle?.update(false, null);
    closeReactionPicker(rebuild: false);
    selection.dispose();
    taskProjection.dispose();
    agentPresentation.dispose();
    referenceDirectory.dispose();
    composerDirectory.dispose();
    w.removeListener(sync);
    adapter.dispose();
    viewport.dispose();
    for (final retired in retiredAdapters) {
      retired.dispose();
    }
    for (final retired in retiredViewports) {
      retired.dispose();
    }
    for (final timer in reactionFailureTimers.values) {
      timer.cancel();
    }
    reactionFailureTimers.clear();
    retiredAdapters.clear();
    retiredViewports.clear();
    super.dispose();
  }

  void replaceContext(List<chat.Message> messages) {
    for (final timer in reactionFailureTimers.values) {
      timer.cancel();
    }
    reactionFailureTimers.clear();
    reactionFailures.clear();
    final oldAdapter = adapter, oldViewport = viewport;
    if (oldViewport.hasClients) oldViewport.jumpTo(0);
    retiredAdapters.add(oldAdapter);
    retiredViewports.add(oldViewport);
    adapter = chat.InMemoryChatController(messages: messages);
    viewport = ScrollController()..addListener(closePickerOnScroll);
    listRevision++;
    initialEndPending = w.highlightedMessageId == null;
    setState(() {});
    // A keyed Chat owns a new observer and controller. The retired list's
    // dispose can only detach its own focus methods, never the new observer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (retiredAdapters.remove(oldAdapter)) oldAdapter.dispose();
      if (retiredViewports.remove(oldViewport)) oldViewport.dispose();
    });
  }

  void sync() {
    if (reactionPicker != null && pickerAuthority != workspaceAuthority(w)) {
      closeReactionPicker();
    }
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
        if (scope != id) alsoCreateTask = false;
        scope = id;
        // A context replacement has different scroll bounds. Carrying the old
        // history offset into its first layout can leave the sliver entirely
        // outside the viewport, preventing the observer from finding a target.
        // Ordinary diffs and history prepend do not enter this branch.
        replaceContext(projected);
        scrolledHighlight = null;
        adapterWindow = window;
      }
      final ownedAdapter = adapter, ownedViewport = viewport;
      bool currentContext() =>
          currentBinding() &&
          identical(adapter, ownedAdapter) &&
          identical(viewport, ownedViewport);
      final wanted = projected.map((m) => m.id).toSet();
      for (final old in List<chat.Message>.of(adapter.messages)) {
        if (!wanted.contains(old.id)) {
          await adapter.removeMessage(old, animated: false);
          if (!currentContext()) return;
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
        if (!currentContext()) return;
      }
      final focusRevision = presentationRevision;
      bool currentFocus() =>
          currentContext() &&
          presentationActive &&
          focusRevision == presentationRevision;
      if (presentationActive &&
          !loading &&
          target != null &&
          (target != scrolledHighlight || window != scrolledWindow) &&
          adapter.messages.any((m) => m.id == target)) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!currentFocus() ||
              target != w.highlightedMessageId ||
              window !=
                  (widget.thread ? w.threadGeneration : w.channelGeneration)) {
            return;
          }
          // ChatAnimatedList consumes controller operations asynchronously.
          // Allow its next layout to attach the message observer before jumping.
          await WidgetsBinding.instance.endOfFrame;
          if (!currentFocus() ||
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
          if (!currentFocus() ||
              target != w.highlightedMessageId ||
              window !=
                  (widget.thread ? w.threadGeneration : w.channelGeneration)) {
            return;
          }
          // The package's void focus receipt also covers an unattached list
          // or a target not yet consumed by its operation listener. Confirm
          // the actual lazy row, and retry only this authorized context.
          for (var attempt = 0; attempt < 8; attempt++) {
            if (!currentFocus() ||
                target != w.highlightedMessageId ||
                window !=
                    (widget.thread
                        ? w.threadGeneration
                        : w.channelGeneration)) {
              return;
            }
            await ownedAdapter.scrollToMessage(
              target,
              duration: Duration.zero,
              alignment: .3,
            );
            WidgetsBinding.instance.scheduleFrame();
            await WidgetsBinding.instance.endOfFrame;
            if (!currentFocus() ||
                target != w.highlightedMessageId ||
                window !=
                    (widget.thread
                        ? w.threadGeneration
                        : w.channelGeneration)) {
              return;
            }
            if (!focusReceiptVisible(target)) {
              // Observer estimates can be stale after a variable-height row
              // replaces its content. Recover from the committed row's actual
              // viewport transform, never from a previously retained offset.
              final row = focusAnchors[target]?.currentContext
                  ?.findRenderObject();
              final renderedViewport = row == null
                  ? null
                  : RenderAbstractViewport.maybeOf(row);
              if (row != null &&
                  row.attached &&
                  renderedViewport != null &&
                  ownedViewport.hasClients) {
                final position = ownedViewport.position;
                final offset = renderedViewport
                    .getOffsetToReveal(row, .3)
                    .offset;
                ownedViewport.jumpTo(
                  offset.clamp(
                    position.minScrollExtent,
                    position.maxScrollExtent,
                  ),
                );
                WidgetsBinding.instance.scheduleFrame();
                await WidgetsBinding.instance.endOfFrame;
                if (!currentFocus() ||
                    target != w.highlightedMessageId ||
                    window !=
                        (widget.thread
                            ? w.threadGeneration
                            : w.channelGeneration)) {
                  return;
                }
              }
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
    if (!presentationActive ||
        !viewport.hasClients ||
        viewport.position.outOfRange) {
      return false;
    }
    final row = focusAnchors[target]?.currentContext?.findRenderObject();
    final Object? view = row == null
        ? null
        : RenderAbstractViewport.maybeOf(row);
    if (row is! RenderBox ||
        view is! RenderBox ||
        !row.attached ||
        !view.attached ||
        !row.hasSize ||
        !view.hasSize) {
      return false;
    }
    final rowRect = row.localToGlobal(Offset.zero) & row.size;
    final viewRect = view.localToGlobal(Offset.zero) & view.size;
    if (!rowRect.overlaps(viewRect)) {
      return false;
    }
    // A partial intersection under a page header is not a focus receipt. Short
    // messages must fit; tall messages expose their header and half a viewport.
    final requiredHeight = rowRect.height.clamp(0.0, viewRect.height * .5);
    return rowRect.top >= viewRect.top - .5 &&
        rowRect.top + requiredHeight <= viewRect.bottom + .5;
  }

  Future<void> link(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && ['https', 'http', 'mailto'].contains(uri.scheme)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> attach({bool imagesOnly = false}) async {
    final scope = w.draftScope(thread: widget.thread),
        generation = w.ledger.generation;
    try {
      final files = await selectUploads(imagesOnly: imagesOnly);
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

  bool get canReact =>
      presentationActive &&
      w.client.user != null &&
      w.server?.string('role') != 'guest' &&
      !w.conversationPaused &&
      w.channel?.archived != true &&
      w.channel?.json['readOnlyReason'] == null &&
      (w.channel?.joined == true ||
          ['dm', 'thread'].contains(w.channel?.type)) &&
      w.can('viewChannel', resource: w.channel);

  Future<void> react(RaftMessage m, String emoji) async {
    if (!canReact) return;
    final authority = workspaceAuthority(w), revision = bindingRevision;
    bool current() =>
        mounted &&
        revision == bindingRevision &&
        authority == workspaceAuthority(w);
    try {
      await w.toggleReaction(m, emoji);
      if (current() && reactionFailures[m.id] == emoji) {
        reactionFailureTimers.remove(m.id)?.cancel();
        setState(() => reactionFailures.remove(m.id));
      }
    } catch (e) {
      if (mounted && current()) {
        reactionFailureTimers.remove(m.id)?.cancel();
        setState(() => reactionFailures[m.id] = emoji);
        reactionFailureTimers[m.id] = Timer(
          const Duration(milliseconds: 400),
          () {
            if (current()) setState(() => reactionFailures.remove(m.id));
          },
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  SourceTimeFormatter get timeFormatter => SourceTimeFormatter(
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

  String clock(DateTime stamp) => timeFormatter.messageTime(stamp);

  /// Web MessageItem `shouldShowThreadRepliesBadge`: replies or a thread
  /// draft, unless the inline reply surface already replaces the badge.
  Widget? threadRepliesBadge(RaftMessage m, {required bool parentTile}) {
    if (parentTile || widget.thread) return null;
    final summary = w.threadSummaries[m.id];
    final replies = summary is Map
        ? int.tryParse('${summary['replyCount']}') ?? 0
        : 0;
    final unread = summary is Map
        ? int.tryParse('${summary['unreadCount']}') ?? 0
        : 0;
    final hasDraft = (w.drafts['thread:${m.id}'] ?? '').trim().isNotEmpty;
    if (replies <= 0 && !hasDraft) return null;
    if (inlineThreadReplies(m, parentTile: parentTile) != null) return null;
    return RaftThreadRepliesBadge(
      key: ValueKey('thread-replies-badge-${m.id}'),
      replyCount: replies,
      unreadCount: unread,
      hasDraft: hasDraft,
      onPressed: () => w.openThread(m),
    );
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
    final projected = <RaftInlineReply>[];
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
        RaftInlineReply(
          id: value['messageId'] as String,
          author: author,
          preview: value['preview'] as String,
          senderType: value['senderType'] as String,
          timestamp: time == null ? '' : clock(time),
          avatar: senderAvatar(
            RaftMessage({
              'id': value['messageId'],
              'senderId': value['senderId'],
              'senderType': value['senderType'],
              'senderName': author,
              if (value['senderType'] == 'external_projection')
                'externalAuthor': {
                  'displayName': author,
                  'avatarUrl': value['senderAvatarUrl'],
                },
            }),
            compact: true,
          ),
        ),
      );
    }
    if (count <= 0 || projected.isEmpty) return null;
    final authority = workspaceAuthority(w);
    void open() {
      if (!mounted ||
          authority != workspaceAuthority(w) ||
          !w.messages.any((m) => m.id == parent.id) ||
          !w.can('viewChannel', resource: w.channel)) {
        return;
      }
      // All previews are one parent-thread action. Focus an authoritative unread
      // target only; clicking a preview does not create a different route.
      final live = w.threadSummaries[parent.id];
      final unread = live is Map && live['firstUnreadMessageId'] is String
          ? live['firstUnreadMessageId'] as String
          : null;
      w.openThread(parent, focusedMessageId: unread);
    }

    final unread = int.tryParse('${summary['unreadCount']}') ?? 0;
    final draft = w.drafts['thread:${parent.id}']?.trim().isNotEmpty == true;
    final countLabel = raftFormat(context, '{count} replies', {'count': count});
    final unreadLabel = unread > 0
        ? ' · ${raftFormat(context, '{count} new', {'count': unread})}'
        : '';
    final draftLabel = draft ? ' · ${raftText(context, 'draft')}' : '';
    return RaftInlineThreadSurface(
      key: ValueKey('inline-thread-${parent.id}'),
      replies: projected,
      replyCount: count,
      semanticLabel: '$countLabel$unreadLabel$draftLabel',
      summary: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$countLabel$unreadLabel'),
            if (draft) ...[
              const TextSpan(text: ' · '),
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: RaftIcon(RaftGlyph.pencil, size: 12),
                ),
              ),
              TextSpan(text: raftText(context, 'draft')),
            ],
            const TextSpan(text: ' ›'),
          ],
        ),
      ),
      onOpen: open,
    );
  }

  Widget? attachmentGallery(RaftMessage message) {
    final all = message.attachments;
    bool raster(Map<String, dynamic> metadata) {
      final type = '${metadata['mimeType']}'
          .toLowerCase()
          .split(';')
          .first
          .trim();
      return type.startsWith('image/') && type != 'image/svg+xml';
    }

    final images = all.where(raster).toList();
    if (images.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftAttachmentGallery(
          dimensions: [
            for (final a in images)
              (
                width: a['width'] is num
                    ? (a['width'] as num).toDouble()
                    : null,
                height: a['height'] is num
                    ? (a['height'] as num).toDouble()
                    : null,
              ),
          ],
          itemBuilder: (index, extent, fit) => AttachmentView(
            key: ValueKey('attachment-${images[index]['id']}'),
            controller: w,
            metadata: images[index],
            messageId: message.id,
            imageExtent: extent,
            imageFit: fit,
          ),
        ),
        if (all.any((a) => !raster(a))) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in all.where((a) => !raster(a)))
                AttachmentView(
                  key: ValueKey('attachment-${a['id']}'),
                  controller: w,
                  metadata: a,
                  messageId: message.id,
                ),
            ],
          ),
        ],
      ],
    );
  }

  AgentPresentationIdentity? senderAgent(RaftMessage message) =>
      message.string('senderType') == 'agent' &&
          (message.json['sourceServerId'] == null ||
              message.json['sourceServerId'] == w.server?.id)
      ? agentPresentation.identity(message.string('senderId'))
      : null;

  String? currentAgentModel(RaftMessage message) {
    final identity = senderAgent(message);
    return identity == null
        ? null
        : agentPresentationModelLabel(
            scope: agentPresentation.currentScope,
            identity: identity,
            showModelName:
                PersonalPresentationScope.maybeOf(context)?.value.modelName ??
                true,
          );
  }

  String? senderSubtitle(RaftMessage message) {
    if (message.json['sourceServerId'] != null &&
        message.json['sourceServerId'] != w.server?.id) {
      return null;
    }
    final agent = senderAgent(message);
    if (agent != null) {
      return agentPresentationSubtitle(agent) ??
          (message.json['senderDescription'] as String?);
    }
    if (messageSenderIdentityKind(message) != 'human' ||
        referenceDirectory.scope != workspaceAuthority(w)) {
      return null;
    }
    final member = referenceDirectory.members
        .where((row) => (row['userId'] ?? row['id']) == message.senderId)
        .firstOrNull;
    final description =
        member?['description'] ?? message.json['senderDescription'];
    final role = member?['role'];
    return humanPresentationSubtitle(
      description: description is String ? description : null,
      localizedRole: role is String
          ? raftText(context, switch (role) {
              'owner' => 'Owner',
              'admin' => 'Admin',
              'guest' => 'Guest',
              _ => 'Member',
            })
          : null,
    );
  }

  VoidCallback? senderMention(RaftMessage message) {
    if (message.json['sourceServerId'] != null &&
        message.json['sourceServerId'] != w.server?.id) {
      return null;
    }
    if (!presentationActive ||
        selection.active ||
        referenceDirectory.scope != workspaceAuthority(w)) {
      return null;
    }
    final type = messageSenderIdentityKind(message);
    if (type == null) return null;
    final entry =
        (type == 'agent'
                ? referenceDirectory.agents
                : referenceDirectory.members)
            .where((row) => (row['userId'] ?? row['id']) == message.senderId)
            .firstOrNull;
    final name = entry?['name'];
    if (name is! String || name.isEmpty || entry?['deletedAt'] != null) {
      return null;
    }
    final authority = workspaceAuthority(w);
    return () {
      if (authority == workspaceAuthority(w) && presentationActive) {
        composerHandle.insertMention(
          RaftComposerSuggestion(
            type: type == 'human' ? 'user' : 'agent',
            id: message.senderId,
            name: name,
          ),
        );
      }
    };
  }

  void closePickerOnScroll() {
    if (reactionPicker != null) closeReactionPicker();
  }

  void closeReactionPicker({bool rebuild = true}) {
    pickerCloseTimer?.cancel();
    pickerCloseTimer = null;
    reactionPicker?.remove();
    reactionPicker?.dispose();
    reactionPicker = null;
    pickerMessageId = pickerAuthority = null;
    if (rebuild && mounted) setState(() {});
  }

  void openReactionPicker(RaftMessage message, BuildContext anchor) {
    if (!canReact) return;
    if (pickerMessageId == message.id) {
      closeReactionPicker();
      return;
    }
    closeReactionPicker(rebuild: false);
    final box = anchor.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    final bounds =
        box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
    final size = overlayBox.size;
    final x = (bounds.right - 224).clamp(
      8.0,
      (size.width - 232).clamp(8.0, double.infinity),
    );
    final below = bounds.bottom + 4;
    final y = below + 42 > size.height - 8 && bounds.top > 54
        ? bounds.top - 46
        : below.clamp(8.0, (size.height - 50).clamp(8.0, double.infinity));
    pickerMessageId = message.id;
    pickerAuthority = workspaceAuthority(w);
    reactionPicker = OverlayEntry(
      builder: (context) => Positioned(
        left: x,
        top: y,
        child: TapRegion(
          onTapOutside: (_) => closeReactionPicker(),
          child: RaftQuickReactionPicker(
            glyphBuilder: (emoji) => RaftReactionGlyph(emoji),
            labelBuilder: (emoji) => emoji,
            onSelect: (emoji) {
              closeReactionPicker();
              react(message, emoji);
            },
            onDismiss: closeReactionPicker,
            onBoundaryEnter: () => pickerCloseTimer?.cancel(),
            onBoundaryLeave: () {
              pickerCloseTimer?.cancel();
              pickerCloseTimer = Timer(
                const Duration(milliseconds: 120),
                closeReactionPicker,
              );
            },
          ),
        ),
      ),
    );
    overlay.insert(reactionPicker!);
    setState(() {});
  }

  Widget messageToolbar(RaftMessage message, {required bool parent}) =>
      RaftMessageToolbar(
        children: [
          if (!parent && !widget.thread)
            RaftMessageToolbarAction(
              key: ValueKey('message-thread-${message.id}'),
              label: raftText(context, 'Reply in thread'),
              icon: const RaftMessageThreadGlyph(),
              onPressed: presentationActive
                  ? () => w.openThread(message)
                  : null,
            ),
          if (canReact)
            Builder(
              builder: (anchor) => RaftMessageToolbarAction(
                key: ValueKey('message-react-${message.id}'),
                label: raftText(context, 'Add reaction'),
                icon: const RaftMessageAddReactionGlyph(),
                popupOpen: pickerMessageId == message.id,
                onPressed: () => openReactionPicker(message, anchor),
              ),
            ),
          RaftMessageToolbarAction(
            key: ValueKey('message-save-${message.id}'),
            label: raftText(context, 'Save message'),
            icon: const RaftIcon(RaftGlyph.bookmark, size: 13),
            onPressed: presentationActive ? () => saveMessage(message) : null,
          ),
        ],
      );

  Future<void> saveMessage(RaftMessage message) async {
    final authority = workspaceAuthority(w);
    try {
      await w.command(
        'POST',
        '/channels/saved',
        data: {'messageId': message.id},
      );
    } catch (e) {
      if (mounted && authority == workspaceAuthority(w)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget senderAvatar(RaftMessage message, {bool compact = false}) {
    final local =
        message.json['sourceServerId'] == null ||
        message.json['sourceServerId'] == w.server?.id;
    final source = projectSenderAvatar(
      origin: w.client.origin,
      senderId: message.string('senderId'),
      senderType: message.string('senderType'),
      agents: local ? referenceDirectory.agents : const [],
      members: local ? referenceDirectory.members : const [],
      currentUser: local ? w.client.user?.json : null,
      externalAuthor: message.json['externalAuthor'] is Map
          ? Map<String, dynamic>.from(message.json['externalAuthor'])
          : null,
    );
    final kind = switch (source.kind) {
      'agent' => RaftAvatarKind.agent,
      'app' => RaftAvatarKind.app,
      _ => RaftAvatarKind.human,
    };
    final avatarContext = compact
        ? RaftMountedAvatarContext.compactList
        : RaftMountedAvatarContext.panelHeader;
    final avatarContent = RaftAvatarContent(
      name: message.author,
      kind: switch (kind) {
        RaftAvatarKind.agent => RaftAvatarContentKind.agent,
        RaftAvatarKind.app => RaftAvatarContentKind.app,
        _ => RaftAvatarContentKind.human,
      },
      uploadedUrl: source.uploadedUrl,
      gravatarUrl: source.gravatarUrl,
      pixelKey: source.pixelKey,
      fallback: RaftMountedAvatarFallback(
        avatarContext: avatarContext,
        gravatar: source.gravatarUrl != null,
        identity: switch (kind) {
          RaftAvatarKind.agent => RaftMountedAvatarIdentity.agent,
          RaftAvatarKind.app => RaftMountedAvatarIdentity.app,
          _ => RaftMountedAvatarIdentity.human,
        },
      ),
    );
    return RaftAvatar(
      key: ValueKey('message-avatar-${message.id}-${source.identity}'),
      name: message.author,
      kind: kind,
      content: avatarContent,
      mountedContext: avatarContext,
      deactivated: senderAgent(message)?.deleted ?? false,
      presence: compact || senderAgent(message) == null
          ? null
          : (() {
              final display = agentPresentation.display(message.senderId);
              if (display == null || !display.showPresence) return null;
              return RaftAvatarPresence(
                activity: switch (display.activity) {
                  'working' => RaftAvatarActivity.working,
                  'thinking' => RaftAvatarActivity.thinking,
                  'error' => RaftAvatarActivity.error,
                  'offline' => RaftAvatarActivity.offline,
                  _ => RaftAvatarActivity.online,
                },
                online: display.online,
                external: display.external,
                label: display.detail.isEmpty ? null : display.detail,
              );
            })(),
    );
  }

  Widget? taskReference(RaftMessage message) {
    final task = taskProjection.taskFor(message);
    if (task == null) return null;
    final status = switch (task['status']) {
      'todo' => RaftMessageTaskStatus.todo,
      'in_progress' => RaftMessageTaskStatus.inProgress,
      'in_review' => RaftMessageTaskStatus.inReview,
      'done' => RaftMessageTaskStatus.done,
      'closed' => RaftMessageTaskStatus.closed,
      _ => null,
    };
    if (status == null) return null;
    final claimant = task['claimedByName'] as String?;
    final number = task['taskNumber'] as int;
    final authority = workspaceAuthority(w);
    return RaftMountedMessageTaskChip(
      key: ValueKey('message-task-${message.id}'),
      number: number,
      status: status,
      title: task['title'],
      claimant: claimant,
      openLabel: raftFormat(context, 'Open task #{number}: {title}', {
        'number': number,
        'title': task['title'],
      }),
      tooltipLabel: 'task #$number${claimant == null ? '' : ' @$claimant'}',
      onOpen: presentationActive
          ? () {
              if (authority == workspaceAuthority(w) &&
                  identical(taskProjection.taskFor(message), task)) {
                w.openThread(message);
              }
            }
          : null,
    );
  }

  Widget messageTile(RaftMessage m, {bool parent = false}) {
    if (m.string('messageType') == 'system') {
      return RaftSystemMessage(
        key: ValueKey('message-${m.id}'),
        content: m.content,
        timestamp: m.createdAt == null ? '' : clock(m.createdAt!),
      );
    }
    return RaftMessageTile(
      key: ValueKey('message-${m.id}'),
      rowContext: widget.thread
          ? RaftMessageRowContext.thread
          : RaftMessageRowContext.main,
      author: m.author,
      avatar: senderAvatar(m),
      content: m.content,
      body: MessagePresentation(
        controller: w,
        message: m,
        onExternalLink: link,
        directoryReferences: referenceDirectory.references,
        fontSize: PersonalPresentationScope.bodyFontSize(
          context,
          w.client.user?.string('preferredMessageBodyFontSize'),
        ),
      ),
      bodyFontSize: PersonalPresentationScope.bodyFontSize(
        context,
        w.client.user?.string('preferredMessageBodyFontSize'),
      ),
      modelLabel: currentAgentModel(m),
      subtitle: senderSubtitle(m),
      onAuthor: senderMention(m),
      hoverToolbar: messageToolbar(m, parent: parent),
      coarsePointer: RaftDensityScope.of(context) == RaftDensity.touch,
      popupOpen: pickerMessageId == m.id,
      highlighted: w.highlightedMessageId == m.id,
      collapseLongMessages:
          (m.json['actionMetadata'] is! Map ||
              m.json['actionMetadata']['kind'] != 'action-card') &&
          w.channel?.json['collapseLongMessages'] != false,
      timestamp: m.createdAt == null ? '' : clock(m.createdAt!),
      // Source renders a badge only for deactivated/departed identities.
      // Sender type is already represented by the scoped avatar, not an Agent badge.
      onActions: () => actions(m),
      onThread: parent || widget.thread ? null : () => w.openThread(m),
      threadPreview: inlineThreadReplies(m, parentTile: parent),
      taskReference: taskReference(m),
      threadRepliesBadge: threadRepliesBadge(m, parentTile: parent),
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
      attachmentGallery: attachmentGallery(m),
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
      reactedEmojis: projectedOwnReactions(
        principal: w.client.user?.id,
        reactions: m.json['reactions'] as List? ?? const [],
        completeViewer: w.reactionViewer.reacted(m.id),
      ),
      failedReactionEmojis: reactionFailures[m.id] == null
          ? const {}
          : {reactionFailures[m.id]!},
      onReaction: canReact ? (emoji) => react(m, emoji) : null,
      onReactionAdd: canReact
          ? (anchor) => openReactionPicker(m, anchor)
          : null,
    );
  }

  Widget threadTopSliver({bool loading = false}) => RaftThreadTimelineTopSliver(
    parent: w.threadParent == null ? null : tile(w.threadParent!, parent: true),
    hasMore: loading || w.threadHasMore,
    historyLimited: w.threadHistoryLimited,
    loadingOlder: loading || w.loadingOlder,
    loadingOlderLabel: raftText(context, 'Loading...'),
    historyLimitedLabel: raftText(
      context,
      'Earlier messages are unavailable due to plan limits.',
    ),
    beginningLabel: raftText(context, 'Beginning of replies'),
    replyCountLabel: raftFormat(context, '{count} replies', {
      'count': w.replies.length,
    }),
  );

  Widget datedTile(RaftMessage message) {
    final stamp = message.createdAt;
    final current = rows;
    final index = current.indexWhere((row) => row.id == message.id);
    final previous = index > 0 ? current[index - 1].createdAt : null;
    final showDay =
        stamp != null &&
        (previous == null ||
            timeFormatter.dayKey(previous) != timeFormatter.dayKey(stamp));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDay &&
            const RaftTimelineCompositionRecipe().emitsDayDivider(
              widget.thread
                  ? RaftTimelineHost.threadPanel
                  : RaftTimelineHost.chatPanel,
            ))
          RaftConversationDateHeader(
            key: ValueKey('message-day-${message.id}'),
            label: timeFormatter.dayLabel(stamp),
          ),
        Padding(
          key: ValueKey('message-wrapper-${message.id}'),
          padding: const RaftTimelineCompositionRecipe().messageInset,
          child: tile(message),
        ),
      ],
    );
  }

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
    final anchorRevision = listRevision, anchorViewport = viewport;
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
      List<Map<String, dynamic>> mentions, {
      bool forceTask = false,
    }) async {
      if (!presentationActive || !currentComposer()) return false;
      final submittedTask = !widget.thread && (alsoCreateTask || forceTask);
      final submittedTaskRevision = taskChoiceRevision;
      final accepted = await w.send(
        text,
        thread: widget.thread,
        mentions: mentions,
        asTask: submittedTask,
        onWindowRefreshed: (window) {
          if (mounted &&
              composeScope == w.draftScope(thread: widget.thread) &&
              composeAuthority == workspaceAuthority(w)) {
            composeWindow = window;
          }
        },
      );
      if (accepted &&
          currentComposer() &&
          submittedTask &&
          submittedTaskRevision == taskChoiceRevision &&
          alsoCreateTask) {
        setState(() => alsoCreateTask = false);
      }
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
    return Column(
      children: [
        Expanded(
          child: Chat(
            key: ValueKey('chat-context-$listRevision'),
            currentUserId: w.client.user?.id ?? '',
            resolveUser: (id) async => chat.User(id: id),
            chatController: adapter,
            backgroundColor:
                RaftConversationSurfaceRecipe(RaftTokens.of(context))
                    .background(
                      widget.thread
                          ? RaftConversationSurfaceRole.threadTimeline
                          : RaftConversationSurfaceRole.channelTimeline,
                    ),
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
              }) => datedTile(RaftMessage(message.metadata!)),
              chatAnimatedListBuilder: (context, item) => RaftInitialEndAnchor(
                controller: viewport,
                presentationActive: presentationActive,
                enabled: !widget.thread && w.highlightedMessageId == null,
                contentReady: !loading,
                onInitialReady: () {
                  if (mounted &&
                      listRevision == anchorRevision &&
                      identical(viewport, anchorViewport) &&
                      initialEndPending) {
                    setState(() => initialEndPending = false);
                  }
                },
                child: ChatAnimatedList(
                  scrollController: viewport,
                  key: ValueKey(
                    'chat-list-${widget.thread ? 'thread' : 'channel'}',
                  ),
                  itemBuilder: item,
                  // Mounted MessageTimeline owns its two sentinels and natural
                  // footer. Generic Flyer padding/safe-area must not duplicate
                  // that spacing or the external composer's OS inset.
                  topPadding: 0,
                  bottomPadding: 0,
                  handleSafeArea: false,
                  messageSliverWrapper: (context, messageSliver) =>
                      RaftTimelineCompositionSliver(
                        anchor: const RaftTimelineCompositionRecipe().anchorFor(
                          widget.thread
                              ? RaftTimelineHost.threadPanel
                              : RaftTimelineHost.chatPanel,
                        ),
                        messagesSliver: messageSliver,
                        footer: const RaftTimelineFooter(),
                      ),
                  topSliver: widget.thread
                      ? SliverMainAxisGroup(
                          slivers: [
                            threadTopSliver(loading: loading),
                            if (!loading && w.replies.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: RaftEmptyState(
                                  title: raftText(context, 'No replies yet'),
                                  detail: raftText(
                                    context,
                                    'Reply to start a thread.',
                                  ),
                                ),
                              ),
                          ],
                        )
                      : SliverToBoxAdapter(
                          child: loading || rows.isEmpty
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const RaftTimelineCompositionRecipe()
                                      .channelHeaderInset,
                                  child: RaftThreadHistoryTopState(
                                    hasMore: w.hasMore,
                                    historyLimited: w.historyLimited,
                                    loadingOlder: w.loadingOlder,
                                    loadingOlderLabel: raftText(
                                      context,
                                      'Loading...',
                                    ),
                                    historyLimitedLabel: raftText(
                                      context,
                                      'Earlier messages are unavailable due to plan limits.',
                                    ),
                                    beginningLabel: raftText(
                                      context,
                                      'Beginning of messages',
                                    ),
                                  ),
                                ),
                        ),
                  onEndReached:
                      !presentationActive ||
                          (!widget.thread && initialEndPending)
                      ? null
                      : () => w.older(thread: widget.thread),
                  initialScrollToEndMode: InitialScrollToEndMode.none,
                ),
              ),
              emptyChatListBuilder: (_) => widget.thread
                  ? const SizedBox.shrink()
                  : loading
                  ? Center(
                      child: Text(
                        raftText(context, 'Loading...'),
                        style: RaftTypography.mono(
                          RaftTokens.of(context),
                          size: 14,
                          line: 20,
                        ),
                      ),
                    )
                  : RaftEmptyState(
                      title: raftText(context, 'Start the conversation'),
                      detail: raftText(
                        context,
                        'Send a message to this channel.',
                      ),
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
            autofocus:
                widget.thread &&
                RaftDensityScope.of(context) == RaftDensity.desktop,
            canAutofocus: () =>
                presentationActive &&
                currentComposer() &&
                w.client.user != null &&
                w.can('viewChannel', resource: w.channel),
            handle: composerHandle,
            initialDraft: w.drafts[w.draftScope(thread: widget.thread)] ?? '',
            onDraftChanged: (text) {
              if (currentComposer()) w.saveDraft(text, thread: widget.thread);
            },
            key: ValueKey(
              'compose-${widget.thread ? w.threadParent?.id : w.channel?.id}',
            ),
            taskAction: !widget.thread && w.channel?.type != 'thread'
                ? RaftComposerTaskToggle(
                    key: const Key('composer-as-task'),
                    checked: alsoCreateTask,
                    label: raftText(context, 'As Task'),
                    onChanged:
                        presentationActive &&
                            currentComposer() &&
                            !w.conversationPaused &&
                            w.channel?.archived != true
                        ? (checked) => setState(() {
                            taskChoiceRevision++;
                            alsoCreateTask = checked;
                          })
                        : null,
                  )
                : null,
            onAttach: () {
              if (presentationActive && currentComposer()) attach();
            },
            onImagePick: () {
              if (presentationActive && currentComposer()) {
                attach(imagesOnly: true);
              }
            },
            pendingLabel: w.uploads(thread: widget.thread).isEmpty
                ? null
                : raftFormat(context, '{count} attachment(s)', {
                    'count': w.uploads(thread: widget.thread).length,
                  }),
            hint: widget.thread
                ? raftText(context, 'Message thread')
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
              if (presentationActive && currentComposer()) {
                composerDirectory.request(prefix);
              }
            },
            onForceTaskSendWithMentions: !widget.thread
                ? (text, mentions) =>
                      sendCurrent(text, mentions, forceTask: true)
                : null,
            onSendWithMentions: sendCurrent,
            onSend: (text) => sendCurrent(text, const []),
          ),
      ],
    );
  }
}
