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

import 'reading_anchor.dart';

import '../data/workspace_controller.dart';
import '../data/source_time_formatter.dart';
import '../data/personal_presentation.dart';
import '../platform/file_selection.dart';
import 'attachment_view.dart';
import 'message_presentation.dart';
import 'pending_mention_actions.dart';
import 'message_reference_directory.dart';
import 'share_message_link.dart';
import 'private_route_guard.dart';
import 'message_selection.dart';
import 'copy_selection_links.dart';
import 'message_image_export.dart';
import 'forward_messages_dialog.dart';
import 'composer_directory.dart';
import 'sender_avatar_projection.dart';
import 'message_reaction_projection.dart';
import 'message_agent_presentation.dart';
import 'agent_metadata_projection.dart';
import 'agent_avatar_projection.dart';
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
    this.threadParentSlot,
    this.hideThreadParent = false,
    this.selectionHandle,
    this.viewportHandle,
    this.onTask,
  });
  final WorkspaceController controller;
  final bool thread;

  /// Source TaskModalHead is an independent task subject above the replies.
  final Widget? threadParentSlot;
  final bool hideThreadParent;
  final ChatSelectionHandle? selectionHandle;
  final ChatViewportHandle? viewportHandle;
  final void Function(Map<String, dynamic>, Future<void> Function())? onTask;
  @override
  State<RaftChatView> createState() => _RaftChatViewState();
}

class _RaftChatViewState extends State<RaftChatView>
    with WidgetsBindingObserver {
  late MessageReferenceDirectory referenceDirectory;
  late ComposerDirectory composerDirectory;
  late MessageAgentPresentation agentPresentation;
  late MessageTaskProjection taskProjection;
  final composerHandle = RaftComposerHandle();
  OverlayEntry? reactionPicker;
  String? pickerMessageId, pickerAuthority;

  /// Message whose context menu is open (row shows its popup-open state).
  String? menuMessageId;
  Timer? pickerCloseTimer;
  late MessageSelection selection;
  bool capturingSelection = false;
  bool copiedSelectionMarkdown = false;
  final selectionToast = RaftToastController();
  Timer? copiedSelectionTimer;
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
  String? scope, adapterParent, preservedContextTarget;
  double? preservedContextTop;
  String? scrolledHighlight;
  int? scrolledWindow, adapterWindow;
  int bindingRevision = 0;
  int selectionCaptureTicket = 0;
  bool presentationActive = true;
  int presentationRevision = 0;
  final timelineKeys = <int, GlobalKey>{};
  Widget? displayedTimeline, retainedTimeline;
  bool focusStaging = false;
  int focusSeekAttempts = 0;
  bool atBottom = true, returningLatest = false;

  /// Channels are bottom-anchored (reversed scroll view, newest message at
  /// scroll offset 0): opening lays out one screen, never the whole window.
  /// Threads keep the top-anchored timeline.
  bool get bottomAnchored => !widget.thread;
  final readingAnchor = RaftReadingAnchorController();

  /// Records a fully visible row so the next layout keeps it in place when
  /// rows are inserted at the latest end while the reader is scrolled up.
  void captureReadingAnchor() {
    final host = readingAnchor.host;
    if (host is! RenderBox ||
        !host.attached ||
        !viewport.hasClients ||
        viewport.positions.length != 1) {
      return;
    }
    RenderSliverMultiBoxAdaptor? list;
    void visit(RenderObject node) {
      if (node is RenderSliverMultiBoxAdaptor &&
          (list == null ||
              (node.geometry?.scrollExtent ?? 0) >
                  (list!.geometry?.scrollExtent ?? 0))) {
        list = node;
      }
      node.visitChildren(visit);
    }

    host.visitChildren(visit);
    // A row fully inside the viewport (scroll space; no transforms needed).
    final position = viewport.position;
    final low = position.pixels,
        high = position.pixels + position.viewportDimension;
    for (
      var child = list?.firstChild;
      child != null;
      child = list!.childAfter(child)
    ) {
      if (!child.hasSize) continue;
      final offset = RaftReadingAnchorController.scrollOffsetOf(child);
      if (offset != null &&
          offset >= low &&
          offset + child.size.height <= high) {
        readingAnchor.capture(child, position);
        return;
      }
    }
  }

  double latestOffset(ScrollPosition p) =>
      bottomAnchored ? p.minScrollExtent : p.maxScrollExtent;
  double oldestOffset(ScrollPosition p) =>
      bottomAnchored ? p.maxScrollExtent : p.minScrollExtent;
  double distanceFromLatest(ScrollPosition p) => bottomAnchored
      ? p.pixels - p.minScrollExtent
      : p.maxScrollExtent - p.pixels;
  int newMessageCount = 0;
  Timer? highlightTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    // Close the anchored reaction picker on window metric changes without a
    // MediaQuery size dependency: that dependency rebuilt the whole timeline
    // on every frame of a window resize.
    WidgetsBinding.instance.addObserver(this);
    viewport.addListener(timelineScrolled);
    if (!widget.thread &&
        w.channelLoading &&
        w.pendingMessageContextChannelId == w.channel?.id &&
        rows.isNotEmpty) {
      // The accepted bucket is available before the first preview layout.
      // Seed its real Flyer adapter synchronously: there is no earlier view
      // to retain underneath a hidden replacement at this first mount.
      adapter.dispose();
      adapter = chat.InMemoryChatController(
        messages: [
          for (final m in rows)
            chat.Message.custom(
              id: m.id,
              authorId: m.senderId.isEmpty ? 'system' : m.senderId,
              createdAt: m.createdAt,
              metadata: m.json,
            ),
        ],
      );
      scope = w.channel?.id;
      // A later accepted response must use its own staging adapter.
      adapterWindow = null;
      initialEndPending = false;
      viewport.removeListener(timelineScrolled);
      viewport.dispose();
      // A bottom-anchored timeline starts at its latest end (offset 0).
      viewport =
          (bottomAnchored
                ? ScrollController()
                : RaftInitialEndScrollController())
            ..addListener(timelineScrolled);
    }
    widget.viewportHandle?.bind(this, jumpToBeginning);
    referenceDirectory = MessageReferenceDirectory(w)
      ..addListener(referencesChanged);
    agentPresentation = MessageAgentPresentation(w, referenceDirectory)
      ..addListener(referencesChanged);
    composerDirectory = ComposerDirectory(
      w,
      agentPresentation: agentPresentation,
    )..addListener(referencesChanged);
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
      selection.removeListener(selectionChanged);
      selection.dispose();
      if (controllerChanged) {
        oldWidget.controller.removeListener(sync);
        taskProjection.dispose();
        composerDirectory.dispose();
        agentPresentation.dispose();
        referenceDirectory.dispose();
        referenceDirectory = MessageReferenceDirectory(w)
          ..addListener(referencesChanged);
        agentPresentation = MessageAgentPresentation(w, referenceDirectory)
          ..addListener(referencesChanged);
        composerDirectory = ComposerDirectory(
          w,
          agentPresentation: agentPresentation,
        )..addListener(referencesChanged);
        taskProjection = MessageTaskProjection(w)
          ..addListener(referencesChanged);
        w.addListener(sync);
      }
      selection = MessageSelection(w, thread: widget.thread)
        ..addListener(selectionChanged);
      selectionError = null;
      copiedSelectionTimer?.cancel();
      copiedSelectionMarkdown = false;
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
    if (!selection.active) {
      copiedSelectionTimer?.cancel();
      copiedSelectionMarkdown = false;
    }
    widget.selectionHandle?.update(selection.active, selection.exit);
    if (mounted) setState(() {});
  }

  Widget selectionToolbar() {
    final owner = selection,
        authority = workspaceAuthority(w),
        revision = selection.revision;
    bool current() =>
        mounted &&
        identical(owner, selection) &&
        owner.active &&
        revision == owner.revision &&
        authority == workspaceAuthority(w) &&
        w.can('viewChannel', resource: w.channel);
    VoidCallback guard(VoidCallback callback) => () {
      if (current()) callback();
    };
    final canForward =
        owner.selected.length <= 20 &&
        owner.selected.every((r) => ordinary(r.message));
    return RaftSelectionToolbar(
      selected: owner.ids.length,
      total: owner.available.length,
      onExit: guard(owner.exit),
      onSelectAll: widget.thread ? guard(owner.selectAll) : null,
      onCopyMarkdown: guard(() {
        copySelection();
      }),
      onCopyLinks: guard(() {
        copySelectionLinks();
      }),
      onPreview: guard(() {
        previewSelection();
      }),
      onForward: guard(() {
        forwardSelection();
      }),
      forwardDisabledReason: canForward
          ? null
          : raftText(
              context,
              "One or more selected items can't be forwarded. Select regular messages instead.",
            ),
      busy: capturingSelection,
      copied: copiedSelectionMarkdown,
      error:
          selectionError ??
          (owner.error == null ? null : raftText(context, owner.error!)),
    );
  }

  Future<void> copySelectionLinks() async {
    final authority = workspaceAuthority(w), revision = selection.revision;
    try {
      final copied = await copySelectedMessageLinks(
        w,
        selection,
        () => mounted,
      );
      if (copied &&
          mounted &&
          authority == workspaceAuthority(w) &&
          revision == selection.revision) {
        selectionToast.show(raftText(context, 'Copied'));
      }
    } catch (_) {
      if (mounted &&
          authority == workspaceAuthority(w) &&
          revision == selection.revision &&
          selection.active) {
        setState(
          () => selectionError = raftText(
            context,
            'The message link could not be shared.',
          ),
        );
      }
    }
  }

  Future<void> copySelection() async {
    if (!selection.active || selection.selected.isEmpty) return;
    final authority = workspaceAuthority(w), snapshot = selection.selected;
    final owner = selection, revision = selection.revision;
    bool current() =>
        mounted &&
        identical(owner, selection) &&
        owner.active &&
        revision == owner.revision &&
        authority == workspaceAuthority(w);
    try {
      await Clipboard.setData(
        ClipboardData(text: selectedMessagesMarkdown(snapshot)),
      );
      if (mounted && current()) {
        copiedSelectionTimer?.cancel();
        setState(() => copiedSelectionMarkdown = true);
        copiedSelectionTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted &&
              identical(owner, selection) &&
              authority == workspaceAuthority(w)) {
            setState(() => copiedSelectionMarkdown = false);
          }
        });
        selectionToast.show(raftText(context, 'Copied Markdown'));
      }
    } catch (_) {
      if (current()) {
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
    final owner = selection, revision = selection.revision;
    bool current() =>
        mounted &&
        identical(owner, selection) &&
        owner.active &&
        owner.revision == revision &&
        authority == workspaceAuthority(w);
    try {
      final done = await forwardMessages(context, w, messages);
      if (current() && done) {
        selection.exit();
      }
    } catch (e) {
      if (current()) {
        setState(() => selectionError = '$e');
      }
    }
  }

  Future<void> previewSelection() async {
    if (capturingSelection || !selection.active || selection.selected.isEmpty) {
      return;
    }
    final scope = selection.scope, revision = selection.revision;
    final ticket = ++selectionCaptureTicket, binding = bindingRevision;
    final owner = selection;
    final authority = workspaceAuthority(w);
    bool current() =>
        mounted &&
        binding == bindingRevision &&
        ticket == selectionCaptureTicket &&
        identical(owner, selection) &&
        selection.active &&
        revision == selection.revision &&
        scope == selection.scope &&
        authority == workspaceAuthority(w);
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
        authorized: current,
        authorityChanges: selection,
      );
      if (saved == true && current()) {
        selection.exit();
      }
    } catch (e) {
      if (current()) {
        setState(() => selectionError = raftText(context, '$e'));
      }
    } finally {
      if (mounted &&
          ticket == selectionCaptureTicket &&
          binding == bindingRevision) {
        setState(() => capturingSelection = false);
      }
    }
  }

  void jumpToBeginning() {
    if (presentationActive && viewport.positions.length == 1) {
      viewport.jumpTo(oldestOffset(viewport.position));
    }
  }

  void timelineScrolled() {
    closePickerOnScroll();
    if (!mounted || focusStaging || viewport.positions.length != 1) return;
    // MessageTimeline.tsx AT_BOTTOM_THRESHOLD.
    final next = distanceFromLatest(viewport.position) <= 100;
    if (next != atBottom || (next && newMessageCount != 0)) {
      setState(() {
        atBottom = next;
        if (next) newMessageCount = 0;
      });
    }
  }

  Future<void> returnToBottom() async {
    newMessageCount = 0;
    returningLatest = w.hasNewer;
    await w.returnToLatest(navigate: w.section == 'chat');
    if (!mounted || returningLatest || viewport.positions.length != 1) return;
    viewport.jumpTo(latestOffset(viewport.position));
    timelineScrolled();
  }

  void referencesChanged() {
    if (mounted) setState(() {});
  }

  @override
  @override
  void didChangeMetrics() {
    if (reactionPicker != null) closeReactionPicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.viewportHandle?.release(this);
    copiedSelectionTimer?.cancel();
    highlightTimer?.cancel();
    selectionToast.dispose();
    widget.selectionHandle?.update(false, null);
    closeReactionPicker(rebuild: false);
    selection.removeListener(selectionChanged);
    selection.dispose();
    taskProjection.dispose();
    composerDirectory.dispose();
    agentPresentation.dispose();
    referenceDirectory.dispose();
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

  void replaceContext(
    List<chat.Message> messages, {
    String? preserveTarget,
    double? preserveTop,
  }) {
    for (final timer in reactionFailureTimers.values) {
      timer.cancel();
    }
    reactionFailureTimers.clear();
    reactionFailures.clear();
    final oldAdapter = adapter, oldViewport = viewport;
    retainedTimeline ??= displayedTimeline;
    retiredAdapters.add(oldAdapter);
    retiredViewports.add(oldViewport);
    adapter = chat.InMemoryChatController(messages: messages);
    viewport = ScrollController()..addListener(timelineScrolled);
    listRevision++;
    initialEndPending = !bottomAnchored && w.highlightedMessageId == null;
    positionQueued = false;
    focusStaging = messages.isNotEmpty;
    focusSeekAttempts = 0;
    preservedContextTarget = preserveTarget;
    preservedContextTop = preserveTop;
    setState(() {});
    // A keyed Chat owns a new observer and controller. The retired list's
    // dispose can only detach its own focus methods, never the new observer.
    if (!focusStaging) retirePreviousTimelines();
  }

  void retirePreviousTimelines() {
    retainedTimeline = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final oldAdapter in retiredAdapters.toList()) {
        if (retiredAdapters.remove(oldAdapter)) oldAdapter.dispose();
      }
      for (final oldViewport in retiredViewports.toList()) {
        if (retiredViewports.remove(oldViewport)) oldViewport.dispose();
      }
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
      // A newly mounted preview can own a still-accepted same-channel window
      // while its permalink GET waits. Publish that accepted window at its
      // actual end; the pending target is not part of it. Cross-channel rows
      // are already excluded by the controller's projection.
      final pendingAcceptedMount =
          !widget.thread &&
          loading &&
          scope != id &&
          w.pendingMessageContextChannelId == id &&
          projected.isNotEmpty;
      if (loading && scope == id) return;
      focusAnchors.removeWhere(
        (id, _) => id != target && id != scrolledHighlight,
      );
      if (scope == id &&
          adapterWindow == window &&
          !atBottom &&
          adapter.messages.isNotEmpty &&
          projected.isNotEmpty) {
        final priorTail = projected.indexWhere(
          (m) => m.id == adapter.messages.last.id,
        );
        final appended = projected.length - priorTail - 1;
        if (priorTail >= 0 && appended > 0 && appended <= 5) {
          newMessageCount += appended;
        }
      }
      final parentProjection = widget.thread
          ? jsonEncode(w.presentedThreadParent?.json)
          : null;
      if (widget.thread &&
          !loading &&
          scope == id &&
          adapterWindow == window &&
          adapterParent != null &&
          adapterParent != parentProjection &&
          adapter.messages.isNotEmpty) {
        final focus = scrolledHighlight ?? target;
        final row = focusAnchors[focus]?.currentContext?.findRenderObject();
        final Object? clip = row == null
            ? null
            : RenderAbstractViewport.maybeOf(row);
        if (row is RenderBox &&
            clip is RenderBox &&
            row.hasSize &&
            clip.hasSize) {
          final top =
              row.localToGlobal(Offset.zero).dy -
              clip.localToGlobal(Offset.zero).dy;
          replaceContext(projected, preserveTarget: focus, preserveTop: top);
        }
      }
      adapterParent = parentProjection;
      if (scope != id ||
          (!loading &&
              (adapterWindow != window ||
                  adapter.messages.isEmpty && projected.isNotEmpty))) {
        if (scope != id) {
          alsoCreateTask = false;
          selectionToast.clear();
        }
        scope = id;
        // A context replacement has different scroll bounds. Carrying the old
        // history offset into its first layout can leave the sliver entirely
        // outside the viewport, preventing the observer from finding a target.
        // Ordinary diffs and history prepend do not enter this branch.
        replaceContext(projected);
        scrolledHighlight = null;
        // Acceptance of the pending response must still enter atomic staging,
        // even though its controller generation matches this retained mount.
        adapterWindow = pendingAcceptedMount ? null : window;
      }
      final ownedAdapter = adapter, ownedViewport = viewport;
      bool currentContext() =>
          currentBinding() &&
          identical(adapter, ownedAdapter) &&
          identical(viewport, ownedViewport);
      if (bottomAnchored &&
          !atBottom &&
          !focusStaging &&
          identical(adapter, ownedAdapter)) {
        captureReadingAnchor();
      }
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
      if (presentationActive &&
          (!loading || pendingAcceptedMount) &&
          (focusStaging ||
              (target != null &&
                  (target != scrolledHighlight || window != scrolledWindow)))) {
        positionContext(
          ownedAdapter,
          ownedViewport,
          window,
          !pendingAcceptedMount &&
                  adapter.messages.any(
                    (m) => m.id == (preservedContextTarget ?? target),
                  )
              ? preservedContextTarget ?? target
              : null,
        );
      }
    });
  }

  bool positionQueued = false;

  void positionContext(
    chat.InMemoryChatController owner,
    ScrollController scroll,
    int window,
    String? target,
  ) {
    if (positionQueued) return;
    positionQueued = true;
    final revision = presentationRevision;
    final preservingAnchor = preservedContextTop != null;
    bool current() =>
        mounted &&
        presentationActive &&
        revision == presentationRevision &&
        identical(owner, adapter) &&
        identical(scroll, viewport) &&
        window == (widget.thread ? w.threadGeneration : w.channelGeneration);
    void reveal() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        positionQueued = false;
        if (!current()) return;
        if (target != null && !focusReceiptVisible(target)) return;
        setState(() {
          focusStaging = false;
          returningLatest = false;
          scrolledHighlight = target;
          scrolledWindow = window;
          initialEndPending = false;
          preservedContextTarget = null;
          preservedContextTop = null;
          atBottom = distanceFromLatest(scroll.position) <= 100;
        });
        retirePreviousTimelines();
        if (!preservingAnchor) {
          highlightTimer?.cancel();
          if (target != null && w.highlightedMessageId == target) {
            final binding = bindingRevision,
                ownedScope = scope,
                authority = workspaceAuthority(w),
                navigationWindow = w.navigationRevision;
            highlightTimer = Timer(const Duration(seconds: 2), () {
              if (mounted &&
                  binding == bindingRevision &&
                  scope == ownedScope &&
                  authority == workspaceAuthority(w) &&
                  window ==
                      (widget.thread
                          ? w.threadGeneration
                          : w.channelGeneration)) {
                w.clearHighlightedMessage(
                  target,
                  expectedNavigationRevision: navigationWindow,
                );
              }
            });
          }
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }

    void center() {
      void again() {
        WidgetsBinding.instance.addPostFrameCallback((_) => center());
        WidgetsBinding.instance.ensureVisualUpdate();
      }

      if (!current() || scroll.positions.length != 1) {
        positionQueued = false;
        return;
      }
      final position = scroll.position;
      double offset;
      if (target == null) {
        // A lazy list estimates its extent from the rows it has built.
        // Jumping to the end builds the last rows and corrects the extent,
        // so repeat until the end is stable before publishing.
        final latest = latestOffset(position);
        if ((position.pixels - latest).abs() > .5 && focusSeekAttempts < 12) {
          focusSeekAttempts++;
          scroll.jumpTo(latest);
          again();
          return;
        }
        offset = latest;
      } else {
        final row = focusAnchors[target]?.currentContext?.findRenderObject();
        final view = row == null ? null : RenderAbstractViewport.maybeOf(row);
        if (row == null || !row.attached || view == null) {
          // Only rows near the viewport are built. While the staged list is
          // hidden, estimate the target position from the built rows and
          // refine it on the next frame.
          final seek = seekOffset(owner, scroll, target);
          if (focusSeekAttempts >= 16) {
            positionQueued = false;
            return;
          }
          focusSeekAttempts++;
          // No rows yet: the list builds its first rows on the next frame.
          if (seek != null) {
            scroll.jumpTo(
              seek.clamp(position.minScrollExtent, position.maxScrollExtent),
            );
          }
          again();
          return;
        }
        // Source scrollIntoView({block: "center"}); actual laid-out geometry.
        offset = preservedContextTop == null
            ? view.getOffsetToReveal(row, .5).offset
            : view.getOffsetToReveal(row, 0).offset - preservedContextTop!;
      }
      final clamped = offset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - clamped).abs() > .5) {
        scroll.jumpTo(clamped);
        // Rows above the target may correct their estimated extent once built.
        if (focusSeekAttempts < 12) {
          focusSeekAttempts++;
          again();
          return;
        }
      }
      reveal();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!current()) {
        positionQueued = false;
        return;
      }
      center();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Estimated scroll offset of [target], from the rows the lazy message
  /// sliver has currently built. Refined on each frame until the row exists.
  double? seekOffset(
    chat.InMemoryChatController owner,
    ScrollController scroll,
    String target,
  ) {
    final found = owner.messages.indexWhere((m) => m.id == target);
    if (found < 0) return null;
    // A reversed list builds the newest message at sliver index 0.
    final index = bottomAnchored ? owner.messages.length - 1 - found : found;
    final root = scroll.position.context.storageContext.findRenderObject();
    // The message list is the lazy sliver with the largest scroll extent;
    // header and footer slivers are small.
    RenderSliverMultiBoxAdaptor? list;
    void visit(RenderObject node) {
      if (node is RenderSliverMultiBoxAdaptor &&
          (list == null ||
              (node.geometry?.scrollExtent ?? 0) >
                  (list!.geometry?.scrollExtent ?? 0))) {
        list = node;
      }
      node.visitChildren(visit);
    }

    if (root == null) return null;
    visit(root);
    final sliver = list;
    final first = sliver?.firstChild, last = sliver?.lastChild;
    if (sliver == null || first == null || last == null) return null;
    final lo = sliver.indexOf(first), hi = sliver.indexOf(last);
    final loTop = sliver.childScrollOffset(first),
        hiTop = sliver.childScrollOffset(last);
    if (loTop == null || hiTop == null) return null;
    final base = sliver.constraints.precedingScrollExtent;
    final perRow = hi > lo ? (hiTop - loTop) / (hi - lo) : last.size.height;
    final top = index < lo
        ? loTop - (lo - index) * perRow
        : hiTop + (index - hi) * perRow;
    // Center the estimated row like the final scrollIntoView step.
    return base + top - scroll.position.viewportDimension / 2;
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
    // Source centers the row even when it is taller than the viewport. Such a
    // row cannot expose its header at the top, but covering the full viewport
    // is a valid receipt. A small intersection from an obsolete offset is not.
    if (rowRect.height > viewRect.height &&
        rowRect.top <= viewRect.top + .5 &&
        rowRect.bottom >= viewRect.bottom - .5) {
      return true;
    }
    // Preserve the existing receipt for ordinary rows and retained top anchors.
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

  /// Web MessageInput rows above the composer card: the error banner, then
  /// the pending-mention strip.
  Widget? composerAccessory() =>
      raftComposerAccessory(w, thread: widget.thread);

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
      final picked = <({String name, Uint8List bytes})>[];
      for (final file in files) {
        picked.add((name: file.name, bytes: await file.readAsBytes()));
        if (!mounted ||
            generation != w.ledger.generation ||
            scope != w.draftScope(thread: widget.thread)) {
          return;
        }
      }
      await w.attachSelection(
        picked,
        thread: widget.thread,
        text: (key, args) => raftFormat(context, key, args),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  /// Web MessageItem.tsx context menu (desktop right-click and mobile
  /// long-press share it): quick reactions; Copy Link / Copy Markdown /
  /// Select Message; Open Thread / Save / Follow Thread; task action.
  /// [anchor] is the global press point (`ctxMenu.anchorX/Y`).
  Future<void> actions(
    RaftMessage message, {
    Offset? anchor,
    bool parentTile = false,
  }) async {
    if (message.string('messageType') == 'system') return;
    if (selection.active) return;
    final authority = workspaceAuthority(w);
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        anchor ??
        (box == null
            ? Offset.zero
            : box.localToGlobal(box.size.center(Offset.zero)));
    final summary = w.threadSummaries[message.id];
    // `hideThreadActions`: thread panel rows (parent and replies).
    final hideThreadActions = widget.thread || parentTile;
    final threadReply = widget.thread && !parentTile;
    final hasThreadConversation =
        (summary is Map &&
            (summary['threadChannelId'] != null ||
                (int.tryParse('${summary['replyCount']}') ?? 0) > 0)) ||
        message.json['threadChannelId'] != null;
    Map? followed;
    if (!hideThreadActions && hasThreadConversation) {
      try {
        final response = await w.query('/channels/threads/followed');
        final rows = response is Map ? response['threads'] : null;
        if (rows is List) {
          followed = rows.whereType<Map>().firstWhere(
            (row) => row['parentMessageId'] == message.id,
            orElse: () => const {},
          );
          if (followed.isEmpty) followed = null;
        }
      } catch (_) {}
      if (!mounted || authority != workspaceAuthority(w)) return;
    }
    final task = taskProjection.taskFor(message);
    final guest = w.server?.string('role') == 'guest';
    final supportsTasks = w.channel?.type != 'thread';
    String? result;
    void pick(BuildContext menuContext, String value) {
      result = value;
      Navigator.of(menuContext).pop();
    }

    setState(() => menuMessageId = message.id);
    await showRaftMessageContextMenu<void>(
      context: context,
      anchor: origin,
      builder: (menuContext) {
        RaftMessageContextMenuItem item(
          String value,
          String label,
          Widget icon,
        ) => RaftMessageContextMenuItem(
          key: ValueKey('message-menu-$value'),
          label: raftText(menuContext, label),
          icon: icon,
          onPressed: () => pick(menuContext, value),
        );
        final follow = !hideThreadActions && hasThreadConversation;
        final taskItems = [
          if (!threadReply && supportsTasks)
            task == null
                ? item(
                    'task',
                    'Convert to Task',
                    raftMessageMenuIcon(RaftGlyph.clipboardCheck),
                  )
                : task['status'] == 'done'
                ? item(
                    'task-reopen',
                    'Reopen Task',
                    raftMessageMenuIcon(RaftGlyph.rotateCcw),
                  )
                : item(
                    'task-done',
                    'Mark as Done',
                    raftMessageMenuIcon(RaftGlyph.checkCircle),
                  ),
        ];
        return RaftMessageContextMenu(
          onDismiss: () => Navigator.of(menuContext).pop(),
          reactionLabel: (emoji) =>
              raftFormat(menuContext, 'React with {emoji}', {'emoji': emoji}),
          onReact: canReact
              ? (emoji) {
                  result = 'react:$emoji';
                  Navigator.of(menuContext).pop();
                }
              : null,
          sections: [
            [
              item(
                'copy-link',
                'Copy Link',
                raftMessageMenuIcon(RaftGlyph.link),
              ),
              item(
                'copy-markdown',
                'Copy Markdown',
                raftMessageMenuIcon(RaftGlyph.copy),
              ),
              if (!guest)
                item(
                  'select',
                  'Select Message',
                  raftMessageMenuIcon(RaftGlyph.checkCircle),
                ),
            ],
            [
              if (!hideThreadActions)
                item(
                  'thread',
                  'Open Thread',
                  Builder(
                    builder: (c) => RaftMessageThreadGlyph(
                      size: 14,
                      color: DefaultTextStyle.of(c).style.color,
                    ),
                  ),
                ),
              item(
                'save',
                'Save Message',
                raftMessageMenuIcon(RaftGlyph.bookmark),
              ),
              if (follow)
                followed != null
                    ? item(
                        'unfollow',
                        'Unfollow Thread',
                        raftMessageMenuIcon(RaftGlyph.messageCircleOff),
                      )
                    : item(
                        'follow',
                        'Follow Thread',
                        raftMessageMenuIcon(RaftGlyph.messageCirclePlus),
                      ),
              // Without the follow divider the task row joins this group.
              if (!follow) ...taskItems,
            ],
            if (follow) taskItems,
          ],
        );
      },
    );
    if (mounted) setState(() => menuMessageId = null);
    final choice = result;
    if (!mounted || authority != workspaceAuthority(w) || choice == null) {
      return;
    }
    try {
      if (choice == 'copy-link') {
        await shareMessageLink(context, w, message, copy: true);
      }
      if (choice == 'copy-markdown') {
        await Clipboard.setData(ClipboardData(text: message.content));
      }
      if (choice == 'select') selection.enter(message.id);
      if (choice == 'thread') await w.openThread(message);
      if (choice == 'save') await saveMessage(message);
      if (choice == 'follow') {
        await w.command(
          'POST',
          '/channels/threads/follow',
          data: {'parentMessageId': message.id},
        );
      }
      if (choice == 'unfollow' && followed?['threadChannelId'] is String) {
        await w.command(
          'POST',
          '/channels/threads/unfollow',
          data: {'threadChannelId': followed!['threadChannelId']},
        );
      }
      if (choice.startsWith('react:')) {
        await react(message, choice.substring(6));
      }
      if (choice == 'task') {
        await w.command(
          'POST',
          '/tasks/convert-message',
          data: {'messageId': message.id},
        );
      }
      if ((choice == 'task-done' || choice == 'task-reopen') && task != null) {
        await w.command(
          'PATCH',
          '/tasks/${task['id']}/status',
          data: {'status': choice == 'task-done' ? 'done' : 'todo'},
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
          !w.presentsMessage(parent.id) ||
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
    if (senderDepartureLabel(message) != null) return null;
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

  String? senderDepartureLabel(RaftMessage message) =>
      switch (messageSenderIdentityKind(message)) {
        'agent' =>
          senderAgent(message)?.deleted == true
              ? raftText(context, 'Deleted')
              : null,
        'human' => switch (message.string('senderMembershipStatus')) {
          'left' => raftText(context, 'Left'),
          'removed' => raftText(context, 'Removed'),
          _ => null,
        },
        _ => null,
      };

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
          : agentAvatarPresence(agentPresentation.display(message.senderId)),
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
                // Source MessageItem3685–3700: the footer task chip opens the
                // independent task slot; the replies action keeps side intent.
                if (widget.onTask case final open?) {
                  open(task, () async {
                    if (mounted && authority == workspaceAuthority(w)) {
                      taskProjection.refresh();
                    }
                  });
                } else {
                  w.openThread(message);
                }
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
        taskByNumber: taskProjection.taskByNumber,
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
      popupOpen: pickerMessageId == m.id || menuMessageId == m.id,
      highlighted: w.highlightedMessageId == m.id,
      collapseLongMessages:
          (m.json['actionMetadata'] is! Map ||
              m.json['actionMetadata']['kind'] != 'action-card') &&
          w.channel?.json['collapseLongMessages'] != false,
      timestamp: m.createdAt == null ? '' : clock(m.createdAt!),
      // Source renders a badge only for deactivated/departed identities.
      // Sender type is already represented by the scoped avatar, not an Agent badge.
      departureLabel: senderDepartureLabel(m),
      onActions: () => actions(m, parentTile: parent),
      onActionsAt: (anchor) => actions(m, anchor: anchor, parentTile: parent),
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
    parentSlot: widget.threadParentSlot,
    parent: widget.hideThreadParent || w.presentedThreadParent == null
        ? null
        : tile(w.presentedThreadParent!, parent: true),
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

  Widget datedTile(RaftMessage message, {bool captureFocus = true}) {
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
          child: tile(message, captureFocus: captureFocus),
        ),
      ],
    );
  }

  Widget tile(RaftMessage m, {bool parent = false, bool captureFocus = true}) {
    final body = messageTile(m, parent: parent);
    final child =
        captureFocus &&
            !parent &&
            (m.id == w.highlightedMessageId || m.id == scrolledHighlight)
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

  Widget buildTimeline(
    chat.InMemoryChatController timelineAdapter,
    ScrollController timelineViewport,
    int revision,
  ) {
    final anchorRevision = revision, anchorViewport = timelineViewport;
    final loading = widget.thread ? w.threadLoading : w.channelLoading;
    final empty = rows.isEmpty;
    final threadHeader = widget.thread
        ? threadTopSliver(loading: loading)
        : null;
    final hasOlder = w.hasMore,
        limited = w.historyLimited,
        fetchingOlder = w.loadingOlder;
    return Chat(
      key: timelineKeys.putIfAbsent(revision, GlobalKey.new),
      currentUserId: w.client.user?.id ?? '',
      resolveUser: (id) async => chat.User(id: id),
      chatController: timelineAdapter,
      backgroundColor: RaftConversationSurfaceRecipe(RaftTokens.of(context))
          .background(
            widget.thread
                ? RaftConversationSurfaceRole.threadTimeline
                : RaftConversationSurfaceRole.channelTimeline,
          ),
      builders: chat.Builders(
        scrollToBottomBuilder: (_, animation, callback) =>
            const SizedBox.shrink(),
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
        customMessageBuilder:
            (context, message, index, {required isSentByMe, groupStatus}) =>
                datedTile(
                  RaftMessage(message.metadata!),
                  captureFocus: identical(timelineAdapter, adapter),
                ),
        chatAnimatedListBuilder: (context, item) => RaftInitialEndAnchor(
          controller: timelineViewport,
          presentationActive: presentationActive,
          // A reversed timeline already starts at its end (offset 0).
          enabled:
              !widget.thread &&
              !bottomAnchored &&
              (w.highlightedMessageId == null ||
                  loading && timelineAdapter.messages.isNotEmpty),
          contentReady: !loading || timelineAdapter.messages.isNotEmpty,
          onInitialReady: () {
            if (mounted &&
                listRevision == anchorRevision &&
                identical(viewport, anchorViewport) &&
                initialEndPending) {
              setState(() => initialEndPending = false);
            }
          },
          child: RaftReadingAnchor(
            controller: readingAnchor,
            child: ChatAnimatedList(
              scrollController: timelineViewport,
              reversed: bottomAnchored,
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
                    reversed: bottomAnchored,
                  ),
              topSliver: widget.thread
                  ? SliverMainAxisGroup(
                      slivers: [
                        threadHeader!,
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
                  // Fills the space above a short timeline so the history state
                  // stays at the top while messages sit at the bottom (Source
                  // flex-grow spacer), and is just its own height otherwise.
                  : SliverFillRemaining(
                      hasScrollBody: false,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: empty
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const RaftTimelineCompositionRecipe()
                                    .channelHeaderInset,
                                child: RaftThreadHistoryTopState(
                                  hasMore: hasOlder,
                                  historyLimited: limited,
                                  loadingOlder: fetchingOlder,
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
                    ),
              onEndReached:
                  !presentationActive || (!widget.thread && initialEndPending)
                  ? null
                  : () => w.older(thread: widget.thread),
              initialScrollToEndMode: InitialScrollToEndMode.none,
              // The app positions and publishes a replacement window atomically.
              // An arrival in its hidden preparation cannot race that positioning
              // with Flyer's independent scroll-to-end callback.
              shouldScrollToEndWhenSendingMessage: !focusStaging,
              shouldScrollToEndWhenAtBottom: !focusStaging && atBottom,
            ),
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
                detail: raftText(context, 'Send a message to this channel.'),
              ),
      ),
    );
  }

  /// A long expanded task history stays scrollable while replies resolve;
  /// the fixed task bar and composer stay outside this viewport.
  Widget taskLoadingBody(Widget body) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: widget.threadParentSlot!),
      SliverFillRemaining(hasScrollBody: false, child: body),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (widget.thread &&
        w.threadChannelId == null &&
        (w.threadResolutionLoading || w.threadResolutionError != null)) {
      final body = RaftThreadResolutionBody(
        loadingLabel: raftText(context, 'Loading...'),
        errorTitle: w.threadResolutionError == null
            ? null
            : raftText(context, "Couldn't load this thread"),
        errorBody: raftText(
          context,
          "The thread couldn't be opened. If this channel just became public, retrying usually fixes it.",
        ),
        retryLabel: raftText(context, 'Retry'),
        onRetry: () {
          final identity = w.threadIdentity;
          if (identity != null && presentationActive) {
            w.openThreadIdentity(
              parentChannelId: identity.parentChannelId,
              parentMessageId: identity.parentMessageId,
              focusedMessageId: identity.focusedMessageId,
              navigate: false,
            );
          }
        },
      );
      return widget.threadParentSlot == null ? body : taskLoadingBody(body);
    }
    final loadingBody = RaftThreadRepliesLoadingBody(
      loadingLabel: raftText(context, 'Loading...'),
      parent: widget.hideThreadParent || w.presentedThreadParent == null
          ? null
          : tile(w.presentedThreadParent!, parent: true),
    );
    final currentTimeline = widget.thread && w.threadLoading
        ? widget.threadParentSlot == null
              ? loadingBody
              : taskLoadingBody(loadingBody)
        : buildTimeline(adapter, viewport, listRevision);
    // Task properties belong to the active discussion, including while a new
    // reply window is being positioned. Retaining a second properties tree
    // would paint a disabled History row and hide the interactive replacement.
    final preserveTimeline = focusStaging && widget.threadParentSlot == null;
    if (!preserveTimeline) displayedTimeline = currentTimeline;
    final bottomCount = w.hasNewer
        ? (w.unread[w.channel?.id] ?? 0)
        : newMessageCount;
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
    // Rows read breakpoint bands, not the raw window width, so a resize
    // within a band does not rebuild every mounted message.
    return RaftViewportBreakpointScope(
      child: Column(
        children: [
          RaftToastPortal(controller: selectionToast),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Keys keep the staged timeline's element when the retained
                // copy above it is removed. Without them the staged list moves
                // to a new Stack slot, remounts at its end offset and lays out
                // every message from the top in one frame.
                if (preserveTimeline && retainedTimeline != null)
                  IgnorePointer(
                    key: const ValueKey('retained-timeline'),
                    child: ExcludeSemantics(child: retainedTimeline!),
                  ),
                IgnorePointer(
                  key: const ValueKey('current-timeline'),
                  ignoring: preserveTimeline,
                  child: Opacity(
                    opacity: preserveTimeline ? 0 : 1,
                    child: currentTimeline,
                  ),
                ),
                if (!widget.thread &&
                    !focusStaging &&
                    (w.hasNewer || !atBottom || newMessageCount > 0))
                  RaftTimelineBottomButton(
                    label: bottomCount > 0
                        ? raftFormat(context, '{count} new messages', {
                            'count': bottomCount,
                          })
                        : raftText(context, 'Back to bottom'),
                    onPressed: returnToBottom,
                  ),
              ],
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
                const SingleActivator(LogicalKeyboardKey.escape):
                    selection.exit,
              },
              child: Focus(autofocus: true, child: selectionToolbar()),
            )
          else if (w.conversationPaused)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(raftText(context, 'Channel conversion in progress')),
            )
          else
            RaftComposer(
              accessoryRow: composerAccessory(),
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
                'compose-${widget.thread ? w.threadParentMessageId : w.channel?.id}',
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
                      ? w.threadParentMessageId != null &&
                            w.threadSourceChannel?.archived != true &&
                            w.threadSourceChannel?.joined == true
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
      ),
    );
  }
}
