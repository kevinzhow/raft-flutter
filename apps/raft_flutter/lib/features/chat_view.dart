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

import 'message_timeline.dart';
import 'row_extents.dart';

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
import 'composer_attachment_input.dart';
import 'sender_avatar_projection.dart';
import 'message_reaction_projection.dart';
import 'message_agent_presentation.dart';
import 'agent_metadata_projection.dart';
import 'agent_avatar_projection.dart';
import 'message_task_projection.dart';
import 'saved_sidebar_entry.dart';

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
  late RaftTimelineScrollController viewport = RaftTimelineScrollController(
    bottomAnchored: bottomAnchored,
  );
  final retiredAdapters = <chat.InMemoryChatController>{};
  final retiredViewports = <ScrollController>{};
  int listRevision = 0;
  String? scope, adapterParent;
  String? scrolledHighlight;
  int? scrolledWindow, adapterWindow;
  int bindingRevision = 0;
  int selectionCaptureTicket = 0;
  bool presentationActive = true;
  int presentationRevision = 0;
  final timelineKeys = <int, GlobalKey>{};
  bool atBottom = true, returningLatest = false;

  /// Channels keep their bottom edge (latest end) fixed; threads their top.
  bool get bottomAnchored => !widget.thread;

  /// The timeline's center: rows from [centerFirst] on (or after
  /// [centerAfter]) are in the forward sliver, older rows in the history
  /// sliver. Only an explicit jump moves it ([centerEpoch]).
  String? centerFirst, centerAfter;
  int centerEpoch = 0, lastCenterIndex = 0;

  int centerIndex() {
    final list = adapter.messages;
    final first = centerFirst, after = centerAfter;
    int? at;
    if (first != null) {
      at = windowIndexOf(first);
    } else if (after != null) {
      final i = windowIndexOf(after);
      at = i == null ? null : i + 1;
    }
    return lastCenterIndex = (at ?? lastCenterIndex).clamp(0, list.length);
  }

  /// Keeps the center on a surviving row when its row leaves the window.
  void retainCenter(List<chat.Message> before, Set<String> kept) {
    String? survivor(int from, int step) {
      for (var i = from; i >= 0 && i < before.length; i += step) {
        if (kept.contains(before[i].id)) return before[i].id;
      }
      return null;
    }

    final first = centerFirst, after = centerAfter;
    if (first != null && !kept.contains(first)) {
      final at = before.indexWhere((m) => m.id == first);
      centerFirst = survivor(at + 1, 1);
      if (centerFirst == null) centerAfter = survivor(at - 1, -1);
    } else if (after != null && !kept.contains(after)) {
      final at = before.indexWhere((m) => m.id == after);
      centerAfter = survivor(at - 1, -1);
      if (centerAfter == null) centerFirst = survivor(at + 1, 1);
    }
  }

  /// Moves the center (one rebuild) and positions the next layout.
  void recenter({
    String? first,
    String? after,
    required RaftTimelineAlignment alignment,
  }) {
    centerFirst = first;
    centerAfter = first == null ? after : null;
    centerEpoch++;
    viewport.align(alignment);
    if (mounted) setState(() {});
  }

  /// Back at the latest end: a jump within a couple of screens, otherwise a
  /// fresh center at the end (never laying out the distance in between).
  void showLatest() {
    if (!viewport.hasClients || viewport.positions.length != 1) return;
    final position = viewport.position;
    if (position.hasContentDimensions &&
        distanceFromLatest(position) <= position.viewportDimension * 2) {
      viewport.followEnd();
      if (position.pixels != position.maxScrollExtent) {
        viewport.jumpTo(position.maxScrollExtent);
      }
      return;
    }
    recenter(
      after: adapter.messages.lastOrNull?.id,
      alignment: RaftTimelineAlignment.end,
    );
  }

  RaftTimelineAlignment alignOn(String target, {double? leading}) =>
      RaftTimelineAlignment.row(
        find: () {
          final box = focusAnchors[target]?.currentContext?.findRenderObject();
          return box is RenderBox ? box : null;
        },
        leading: leading,
      );

  double distanceFromLatest(ScrollPosition p) => p.maxScrollExtent - p.pixels;
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
  List<RaftMessage> get rows => w.timeline(thread: widget.thread);
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
        messages: [for (final m in rows) project(m)],
      );
      scope = w.channel?.id;
      // A later accepted response must use its own staging adapter.
      adapterWindow = null;
      centerAfter = adapter.messages.lastOrNull?.id;
      ++windowRevision;
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

  /// Thread "jump to start": a fresh center at the oldest loaded row.
  void jumpToBeginning() {
    if (presentationActive && adapter.messages.isNotEmpty) {
      recenter(
        first: adapter.messages.first.id,
        alignment: RaftTimelineAlignment.start,
      );
    }
  }

  void timelineScrolled() {
    closePickerOnScroll();
    if (!mounted || viewport.positions.length != 1) return;
    final position = viewport.position;
    if (!position.hasContentDimensions) return;
    // MessageTimeline.tsx AT_BOTTOM_THRESHOLD.
    final next = distanceFromLatest(position) <= 100;
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
    if (!mounted || returningLatest) return;
    showLatest();
    timelineScrolled();
  }

  // Projections of the presented rows, reused while a row is unchanged (the
  // controller returns the same RaftMessage for an unchanged ledger row).
  final projections = Expando<chat.Message>('chat projections');
  final sources = Expando<RaftMessage>('projected rows');
  chat.Message project(RaftMessage m) {
    final key = w.messageKey(m);
    final cached = projections[m];
    if (cached != null && cached.id == key) return cached;
    final projected = chat.Message.custom(
      id: key,
      authorId: m.senderId.isEmpty ? 'system' : m.senderId,
      createdAt: m.createdAt,
      metadata: m.json,
    );
    sources[projected] = m;
    return projections[m] = projected;
  }

  /// The presented row of a projection, without copying its fields again.
  RaftMessage source(chat.Message message) =>
      sources[message] ?? RaftMessage(message.metadata!);

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

  /// Publishes a new window in one rebuild, positioned inside its first
  /// layout: at [focus] (centered, or with its top [focusTop] below the
  /// viewport top) when it is in the window, otherwise at the latest end.
  void replaceContext(
    List<chat.Message> messages, {
    String? focus,
    double? focusTop,
  }) {
    for (final timer in reactionFailureTimers.values) {
      timer.cancel();
    }
    reactionFailureTimers.clear();
    reactionFailures.clear();
    retiredAdapters.add(adapter);
    retiredViewports.add(viewport);
    adapter = chat.InMemoryChatController(messages: messages);
    ++windowRevision;
    final target = focus == null
        ? null
        : messages.where((m) => m.metadata?['id'] == focus).firstOrNull;
    centerFirst = target?.id;
    centerAfter = target == null ? messages.lastOrNull?.id : null;
    lastCenterIndex = target == null ? messages.length : 0;
    centerEpoch++;
    viewport = RaftTimelineScrollController(
      bottomAnchored: bottomAnchored,
      initial: target != null
          ? alignOn(focus!, leading: focusTop)
          // An empty thread (e.g. a task's discussion) shows its head.
          : messages.isEmpty && !bottomAnchored
          ? RaftTimelineAlignment.start
          : RaftTimelineAlignment.end,
    )..addListener(timelineScrolled);
    listRevision++;
    revealPending = messages.isNotEmpty;
    preservingFocus = focusTop != null;
    setState(() {});
    retirePreviousTimelines();
  }

  void retirePreviousTimelines() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final oldAdapter in retiredAdapters.toList()) {
        if (retiredAdapters.remove(oldAdapter)) oldAdapter.dispose();
      }
      for (final oldViewport in retiredViewports.toList()) {
        if (retiredViewports.remove(oldViewport)) oldViewport.dispose();
      }
    });
  }

  /// Applies the presented rows to the current window in place. Unchanged
  /// rows are the same projection objects, so an unchanged window costs one
  /// identity pass (no per-row search or encoding). Returns whether it changed.
  bool applyWindow(List<chat.Message> projected) {
    final current = adapter.messages;
    final wanted = {for (final m in projected) m.id};
    final next = ordered(current, projected, wanted);
    var same = current.length == next.length;
    for (var i = 0; same && i < next.length; i++) {
      final a = current[i], b = next[i];
      same =
          identical(a, b) ||
          (a.id == b.id && identical(a.metadata, b.metadata));
    }
    if (same) return false;
    final previousLast = current.lastOrNull?.id;
    retainCenter(current, wanted);
    adapter.setMessages(next, animated: false);
    ++windowRevision;
    // Rows that arrived after the previous latest row.
    final from = previousLast == null
        ? 0
        : next.indexWhere((m) => m.id == previousLast) + 1;
    if (from > 0 || previousLast == null) {
      final appended = next.skip(from);
      final me = w.client.user?.id;
      if (appended.isNotEmpty) {
        if (me != null && appended.last.authorId == me) {
          // An own message returns to the latest end, wherever the reader is.
          showLatest();
        } else if (atBottom) {
          viewport.followEnd();
        }
      }
    }
    if (mounted) setState(() {});
    return true;
  }

  /// [projected], except that rows already shown keep their order: a row
  /// whose position changes (e.g. a confirmed send sorting by its server seq)
  /// stays where the reader saw it; new rows enter at their projected index.
  static List<chat.Message> ordered(
    List<chat.Message> current,
    List<chat.Message> projected,
    Set<String> wanted,
  ) {
    final shown = {for (final m in current) m.id};
    final keptOrder = [
      for (final m in current)
        if (wanted.contains(m.id)) m.id,
    ];
    var k = 0, inOrder = true;
    for (final m in projected) {
      if (!shown.contains(m.id)) continue;
      if (k >= keptOrder.length || keptOrder[k] != m.id) {
        inOrder = false;
        break;
      }
      k++;
    }
    if (inOrder) return projected;
    final next = {for (final m in projected) m.id: m};
    final list = [for (final id in keptOrder) next[id]!];
    for (var i = 0; i < projected.length; i++) {
      if (!shown.contains(projected[i].id)) {
        list.insert(i.clamp(0, list.length), projected[i]);
      }
    }
    return list;
  }

  int windowRevision = 0;
  bool revealPending = false, preservingFocus = false;
  int revealTicket = 0;
  String? revealing;
  int? revealingWindow;

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
      final presented = rows;
      for (final row in presented) {
        if (!WorkspaceController.isPendingSend(row) &&
            (row.json['reactions'] as List? ?? []).isNotEmpty) {
          w.hydrateReactionViewer(row);
        }
      }
      final projected = [for (final m in presented) project(m)];
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
      var replaced = false;
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
          replaceContext(projected, focus: focus, focusTop: top);
          replaced = true;
        }
      }
      adapterParent = parentProjection;
      // Optimistic sends are ordinary diffs at the latest end, also in an
      // empty timeline; the first reply creating its thread channel keeps the
      // same timeline instead of staging a new context.
      bool optimisticOnly(List<chat.Message> list) =>
          list.isNotEmpty &&
          list.every((m) => m.metadata?['pendingSend'] == true);
      if (widget.thread &&
          scope == null &&
          id != null &&
          adapterWindow == window &&
          optimisticOnly(adapter.messages)) {
        scope = id;
      }
      if (scope != id ||
          (!loading &&
              (adapterWindow != window ||
                  adapter.messages.isEmpty &&
                      projected.isNotEmpty &&
                      !optimisticOnly(projected)))) {
        if (scope != id) {
          alsoCreateTask = false;
          selectionToast.clear();
        }
        scope = id;
        // A context replacement has different scroll bounds and its own
        // center; ordinary diffs and history prepends never enter here.
        replaceContext(projected, focus: pendingAcceptedMount ? null : target);
        replaced = true;
        scrolledHighlight = null;
        // Acceptance of the pending response must still enter atomic staging,
        // even though its controller generation matches this retained mount.
        adapterWindow = pendingAcceptedMount ? null : window;
      } else if (!replaced) {
        applyWindow(projected);
      }
      // A plain channel switch publishes its retained/cached window at once
      // (Web shows the channel's cached bucket, then refetches); the network
      // page updates rows in place.
      final showCachedLatest =
          bottomAnchored && target == null && adapter.messages.isNotEmpty;
      if (!presentationActive ||
          (loading && !pendingAcceptedMount && !showCachedLatest)) {
        return;
      }
      final loaded =
          !pendingAcceptedMount &&
          target != null &&
          adapter.messages.any((m) => m.metadata?['id'] == target);
      if (revealPending) {
        reveal(window, loaded ? target : null);
      } else if (loaded &&
          (target != scrolledHighlight || window != scrolledWindow) &&
          (revealing != target || revealingWindow != window)) {
        // A new target inside the current window: one re-centered rebuild.
        recenter(
          first: adapter.messages
              .firstWhere((m) => m.metadata?['id'] == target)
              .id,
          alignment: alignOn(target),
        );
        reveal(window, target);
      }
    });
  }

  /// Records a published position once its first frame shows it.
  void reveal(int window, String? target) {
    final ticket = ++revealTicket;
    revealing = target;
    revealingWindow = window;
    final owner = adapter, scroll = viewport, revision = presentationRevision;
    final preserving = preservingFocus;
    bool current() =>
        mounted &&
        ticket == revealTicket &&
        presentationActive &&
        revision == presentationRevision &&
        identical(owner, adapter) &&
        identical(scroll, viewport) &&
        window == (widget.thread ? w.threadGeneration : w.channelGeneration);
    var attempts = 0;
    void check(Duration _) {
      if (!current()) {
        if (mounted && ticket == revealTicket) revealing = null;
        return;
      }
      if (target != null && !focusReceiptVisible(target) && attempts++ < 8) {
        WidgetsBinding.instance.addPostFrameCallback(check);
        WidgetsBinding.instance.ensureVisualUpdate();
        return;
      }
      revealing = null;
      setState(() {
        revealPending = false;
        preservingFocus = false;
        returningLatest = false;
        scrolledHighlight = target;
        scrolledWindow = window;
        final position = scroll.positions.length == 1 ? scroll.position : null;
        atBottom =
            position == null ||
            !position.hasContentDimensions ||
            distanceFromLatest(position) <= 100;
      });
      if (preserving) return;
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
                  (widget.thread ? w.threadGeneration : w.channelGeneration)) {
            w.clearHighlightedMessage(
              target,
              expectedNavigationRevision: navigationWindow,
            );
          }
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback(check);
    WidgetsBinding.instance.ensureVisualUpdate();
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
    // Source MessageItem reads the server-scoped followed list synchronously.
    final followedThreads = w.followedThreads;
    if (!hideThreadActions && hasThreadConversation) followedThreads.ensure();
    final followed = followedThreads.isFollowing(message.id);
    final task = taskProjection.taskFor(message);
    final guest = w.server?.string('role') == 'guest';
    final supportsTasks = w.channel?.type != 'thread';
    final saved = SavedCountStore.of(w).isSaved(message.id);
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
                saved ? 'Remove from Saved' : 'Save Message',
                raftMessageMenuIcon(RaftGlyph.bookmark),
              ),
              if (follow)
                followed
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
      // Optimistic in the shared store; it reverts before rethrowing.
      if (choice == 'follow') await followedThreads.follow(message.id);
      if (choice == 'unfollow') {
        final threadId =
            followedThreads.threadChannelIdFor(message.id) ??
            (summary is Map ? summary['threadChannelId'] : null) ??
            message.json['threadChannelId'];
        if (threadId is String) {
          await followedThreads.unfollow(message.id, threadChannelId: threadId);
        }
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
    } catch (_) {
      if (mounted && current()) {
        reactionFailureTimers.remove(m.id)?.cancel();
        setState(() => reactionFailures[m.id] = emoji);
        reactionFailureTimers[m.id] = Timer(
          const Duration(milliseconds: 400),
          () {
            if (current()) setState(() => reactionFailures.remove(m.id));
          },
        );
        // Web surfaces a failed toggle as the 400ms chip flash only.
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
              'senderAvatarUrl': value['senderAvatarUrl'],
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
    final pending = WorkspaceController.isPendingSend(message);
    final messageId = pending ? null : message.id;
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
          itemBuilder: (index, extent, fit) => sendStateAttachment(
            pending,
            AttachmentView(
              key: ValueKey('attachment-${images[index]['id']}'),
              controller: w,
              metadata: images[index],
              messageId: messageId,
              imageExtent: extent,
              imageFit: fit,
            ),
          ),
        ),
        if (all.any((a) => !raster(a))) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in all.where((a) => !raster(a)))
                sendStateAttachment(
                  pending,
                  AttachmentView(
                    key: ValueKey('attachment-${a['id']}'),
                    controller: w,
                    metadata: a,
                    messageId: messageId,
                  ),
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
    final carried = message.json['senderDescription'];
    final agent = senderAgent(message);
    if (agent != null) {
      return agentPresentationSubtitle(agent) ??
          (carried is String && carried.isNotEmpty ? carried : null);
    }
    final kind = messageSenderIdentityKind(message);
    if (kind == 'agent') {
      // First paint (or no directory access) uses the message-carried field.
      return carried is String && carried.isNotEmpty ? carried : null;
    }
    if (kind != 'human') return null;
    if (referenceDirectory.scope != directoryAuthority(w)) {
      return humanPresentationSubtitle(
        description: carried is String ? carried : null,
      );
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
        referenceDirectory.scope != directoryAuthority(w)) {
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

  Widget messageToolbar(RaftMessage message, {required bool parent}) {
    final saved = SavedCountStore.of(w).isSaved(message.id);
    return RaftMessageToolbar(
      children: [
        if (!parent && !widget.thread)
          RaftMessageToolbarAction(
            key: ValueKey('message-thread-${message.id}'),
            label: raftText(context, 'Reply in thread'),
            icon: const RaftMessageThreadGlyph(),
            onPressed: presentationActive ? () => w.openThread(message) : null,
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
          label: raftText(
            context,
            saved ? 'Remove from Saved' : 'Save message',
          ),
          icon: const RaftIcon(RaftGlyph.bookmark, size: 13),
          active: saved,
          onPressed: presentationActive ? () => saveMessage(message) : null,
        ),
      ],
    );
  }

  /// Screen-reader row actions: the hover toolbar's actions (same conditions),
  /// copy, and the message menu that holds every other action.
  List<RaftMessageSemanticsAction> messageSemanticsActions(
    RaftMessage message, {
    required bool parent,
    required bool pending,
  }) {
    if (pending) return const [];
    final saved = SavedCountStore.of(w).isSaved(message.id);
    return [
      if (!parent && !widget.thread && presentationActive)
        RaftMessageSemanticsAction(
          raftText(context, 'Reply in thread'),
          (_) => w.openThread(message),
        ),
      if (canReact)
        RaftMessageSemanticsAction(
          raftText(context, 'Add reaction'),
          (row) => openReactionPicker(message, row),
        ),
      if (presentationActive)
        RaftMessageSemanticsAction(
          raftText(context, saved ? 'Remove from Saved' : 'Save message'),
          (_) => saveMessage(message),
        ),
      RaftMessageSemanticsAction(
        raftText(context, 'Copy Markdown'),
        (_) => Clipboard.setData(ClipboardData(text: message.content)),
      ),
      RaftMessageSemanticsAction(raftText(context, 'Message actions'), (row) {
        final box = row.findRenderObject();
        actions(
          message,
          anchor: box is RenderBox && box.hasSize
              ? box.localToGlobal(box.size.center(Offset.zero))
              : null,
          parentTile: parent,
        );
      }),
    ];
  }

  /// Source MessageItem `handleToggleSave`: the saved state and the Saved
  /// badge change at once; a failed request puts them back.
  Future<void> saveMessage(RaftMessage message) async {
    final authority = workspaceAuthority(w);
    final store = SavedCountStore.of(w);
    try {
      await store.setSaved(message.id, !store.isSaved(message.id));
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
      carriedAvatarUrl: message.json['senderAvatarUrl'] is String
          ? message.json['senderAvatarUrl'] as String
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
    // Only this avatar follows the sender's live presence: an agent heartbeat
    // rebuilds the avatars showing that agent, not the row or the timeline.
    // Human rows (a fixed property of the message) never subscribe.
    final presentation = agentPresentation;
    Widget avatar() {
      final agent = senderAgent(message);
      return RaftAvatar(
        key: ValueKey(
          'message-avatar-${w.messageKey(message)}-${source.identity}',
        ),
        name: message.author,
        kind: kind,
        content: avatarContent,
        mountedContext: avatarContext,
        deactivated: agent?.deleted ?? false,
        presence: compact || agent == null
            ? null
            : agentAvatarPresence(presentation.display(message.senderId)),
      );
    }

    if (message.string('senderType') != 'agent') return avatar();
    return ListenableBuilder(
      listenable: presentation.presenceOf(message.senderId),
      builder: (context, _) => avatar(),
    );
  }

  Widget? taskReference(RaftMessage message) {
    final presented = taskProjection.presentFor(message);
    if (presented == null) return null;
    final task = presented.task;
    RaftMessageTaskStatus? statusOf(Object? value) => switch (value) {
      'todo' => RaftMessageTaskStatus.todo,
      'in_progress' => RaftMessageTaskStatus.inProgress,
      'in_review' => RaftMessageTaskStatus.inReview,
      'done' => RaftMessageTaskStatus.done,
      'closed' => RaftMessageTaskStatus.closed,
      _ => null,
    };
    if (presented.presence == MessageTaskPresence.reserved) {
      // A message known to be a task whose details are pending keeps the
      // chip's footer space from the first frame; the row never grows later.
      return Visibility(
        key: ValueKey('message-task-reserved-${message.id}'),
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: RaftMountedMessageTaskChip(
          number: task?['taskNumber'] as int? ?? 0,
          status: RaftMessageTaskStatus.todo,
          title: '',
          openLabel: '',
        ),
      );
    }
    final status = statusOf(task!['status']);
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
      onOpen: presentationActive
          ? () {
              // Open the accepted task current at tap time; a chip built from
              // the message's own fields waits for the channel's task rows.
              final current = taskProjection.taskFor(message);
              if (authority == workspaceAuthority(w) &&
                  current != null &&
                  current['id'] == task['id']) {
                // Source MessageItem3685–3700: the footer task chip opens the
                // independent task slot; the replies action keeps side intent.
                if (widget.onTask case final open?) {
                  open(current, () async {
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

  /// Web AttachmentChip `isOptimistic`: dimmed and inert until the message
  /// exists. One wrapper shape for every row keeps the attachment state when
  /// the server copy replaces the optimistic row.
  Widget sendStateAttachment(bool pending, Widget child) => IgnorePointer(
    ignoring: pending,
    child: Opacity(opacity: pending ? .7 : 1, child: child),
  );

  Widget messageTile(
    RaftMessage m, {
    bool parent = false,
    Widget? selectionLeading,
  }) {
    // Optimistic rows share the final row's key and widget shape; only the
    // actions that need a server message id stay inert until it arrives.
    final key = w.messageKey(m);
    final pending = WorkspaceController.isPendingSend(m);
    if (m.string('messageType') == 'system') {
      return RaftSystemMessage(
        key: ValueKey('message-$key'),
        content: m.content,
        timestamp: m.createdAt == null ? '' : clock(m.createdAt!),
      );
    }
    return RaftMessageTile(
      key: ValueKey('message-$key'),
      rowContext: widget.thread
          ? RaftMessageRowContext.thread
          : RaftMessageRowContext.main,
      author: m.author,
      avatar: senderAvatar(m),
      selectionLeading: selectionLeading,
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
      hoverToolbar: IgnorePointer(
        ignoring: pending,
        child: ExcludeFocus(
          excluding: pending,
          child: messageToolbar(m, parent: parent),
        ),
      ),
      compactSemantics: true,
      semanticsContent:
          m.json['actionMetadata'] is Map &&
              const {
                'action-card',
                'forwarded-bundle',
              }.contains(m.json['actionMetadata']['kind'])
          ? ''
          : null,
      semanticsActions: messageSemanticsActions(
        m,
        parent: parent,
        pending: pending,
      ),
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
      onActions: () {
        if (!pending) actions(m, parentTile: parent);
      },
      onActionsAt: (anchor) {
        if (!pending) actions(m, anchor: anchor, parentTile: parent);
      },
      onThread: parent || widget.thread
          ? null
          : () {
              if (!pending) w.openThread(m);
            },
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
      attachmentBuilder: (metadata) => sendStateAttachment(
        pending,
        AttachmentView(
          key: ValueKey('attachment-${metadata['id']}'),
          controller: w,
          metadata: metadata,
          messageId: pending ? null : m.id,
        ),
      ),
      reactions: (m.json['reactions'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      reactedEmojis: withPendingReactions(
        projectedOwnReactions(
          principal: w.client.user?.id,
          reactions: m.json['reactions'] as List? ?? const [],
          completeViewer: w.reactionViewer.reacted(m.id),
        ),
        w.pendingReactionTargets(m.id),
      ),
      failedReactionEmojis: reactionFailures[m.id] == null
          ? const {}
          : {reactionFailures[m.id]!},
      onReaction: canReact
          ? (emoji) {
              if (!pending) react(m, emoji);
            }
          : null,
      onReactionAdd: canReact
          ? (anchor) {
              if (!pending) openReactionPicker(m, anchor);
            }
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
      'count': rows.length,
    }),
  );

  // id -> index over the displayed window, rebuilt when the window changes;
  // rows used to project and scan the whole channel on every build.
  List<chat.Message>? indexedWindow;
  int indexedRevision = -1;
  final windowIndex = <String, int>{};
  int? windowIndexOf(String id) {
    final list = adapter.messages;
    if (!identical(list, indexedWindow) || indexedRevision != windowRevision) {
      windowIndex
        ..clear()
        ..addAll({for (var i = 0; i < list.length; i++) list[i].id: i});
      indexedWindow = list;
      indexedRevision = windowRevision;
    }
    return windowIndex[id];
  }

  Widget datedTile(RaftMessage message, {bool captureFocus = true}) {
    final stamp = message.createdAt;
    final key = w.messageKey(message);
    final index = windowIndexOf(key);
    DateTime? previous;
    if (index != null) {
      previous = index > 0 ? adapter.messages[index - 1].createdAt : null;
    } else {
      final current = rows;
      final at = current.indexWhere((row) => w.messageKey(row) == key);
      previous = at > 0 ? current[at - 1].createdAt : null;
    }
    final showDay =
        stamp != null &&
        (previous == null ||
            timeFormatter.dayKey(previous) != timeFormatter.dayKey(stamp));
    return RaftRowExtentRecorder(
      scope: rowExtentScope(context),
      id: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDay &&
              const RaftTimelineCompositionRecipe().emitsDayDivider(
                widget.thread
                    ? RaftTimelineHost.threadPanel
                    : RaftTimelineHost.chatPanel,
              ))
            RaftConversationDateHeader(
              key: ValueKey('message-day-$key'),
              label: timeFormatter.dayLabel(stamp),
            ),
          Padding(
            key: ValueKey('message-wrapper-$key'),
            padding: const RaftTimelineCompositionRecipe().messageInset,
            child: tile(message, captureFocus: captureFocus),
          ),
        ],
      ),
    );
  }

  String rowExtentScope(BuildContext context) {
    final tokens = RaftTokens.of(context);
    return '${tokens.family.name}|${tokens.dark}|${widget.thread}';
  }

  /// Total-extent estimate for a row not laid out yet: its last measured
  /// height at this width, otherwise a content-based guess.
  double estimateRow(
    Map<String, (double, double)> measuredRows,
    List<chat.Message> list,
    int index,
  ) {
    final width = raftLastRowWidth;
    if (index < 0 || index >= list.length) return 96;
    final message = list[index];
    final measured = measuredRows[message.id];
    if (measured != null && (measured.$1 - width).abs() < 1) return measured.$2;
    return raftRowExtents.guess(message.id, message.metadata, width);
  }

  Widget tile(RaftMessage m, {bool parent = false, bool captureFocus = true}) {
    final selectable =
        selection.active && m.string('messageType') != 'system';
    final checked = selectable && selection.ids.contains(m.id);
    // Web MessageMultiSelectCheckbox: circle, size lg, primary variant, in the
    // row's flex line before the avatar (the row owns `mt-1.5` and the gap).
    final body = messageTile(
      m,
      parent: parent,
      selectionLeading: selectable
          ? RaftCheckbox(
              value: checked,
              size: RaftCheckboxRecipeSize.lg,
              primary: true,
              circle: true,
              flatWhenChecked: true,
              semanticLabel: raftFormat(context, 'Select message by {name}', {
                'name': m.author,
              }),
              onChanged: capturingSelection
                  ? null
                  : (_) => selection.toggle(m.id),
            )
          : null,
    );
    final child =
        captureFocus &&
            !parent &&
            (m.id == w.highlightedMessageId || m.id == scrolledHighlight)
        ? KeyedSubtree(
            key: focusAnchors.putIfAbsent(m.id, GlobalKey.new),
            child: body,
          )
        : body;
    if (!selectable) return child;
    return Semantics(
      selected: checked,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: capturingSelection ? null : () => selection.toggle(m.id),
        child: AbsorbPointer(child: child),
      ),
    );
  }

  Widget buildTimeline() {
    final timelineAdapter = adapter;
    final messages = timelineAdapter.messages;
    final measuredRows = raftRowExtents.scope(rowExtentScope(context));
    final loading = widget.thread ? w.threadLoading : w.channelLoading;
    final empty = rows.isEmpty;
    const recipe = RaftTimelineCompositionRecipe();
    final List<Widget> header;
    if (widget.thread) {
      header = [
        threadTopSliver(loading: loading),
        if (!loading && empty)
          RaftTimelineSparseFill(
            child: RaftEmptyState(
              title: raftText(context, 'No replies yet'),
              detail: raftText(context, 'Reply to start a thread.'),
            ),
          ),
      ];
    } else {
      // Fills the space above a short timeline so the history state stays at
      // the top while messages sit at the bottom (Source flex-grow spacer),
      // and is just its own height otherwise.
      header = [
        RaftTimelineSparseFill(
          child: Align(
            alignment: Alignment.topCenter,
            child: empty
                ? const SizedBox.shrink()
                : Padding(
                    padding: recipe.channelHeaderInset,
                    child: RaftThreadHistoryTopState(
                      hasMore: w.hasMore,
                      historyLimited: w.historyLimited,
                      loadingOlder: w.loadingOlder,
                      loadingOlderLabel: raftText(context, 'Loading...'),
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
      ];
    }
    return Chat(
      key: timelineKeys.putIfAbsent(listRevision, GlobalKey.new),
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
        chatAnimatedListBuilder: (context, _) => RaftMessageTimeline(
          key: ValueKey('chat-list-${widget.thread ? 'thread' : 'channel'}'),
          controller: viewport,
          messages: messages,
          centerIndex: centerIndex(),
          epoch: centerEpoch,
          indexOfId: windowIndexOf,
          rowBuilder: (context, index) => datedTile(source(messages[index])),
          estimateRow: (index) => estimateRow(measuredRows, messages, index),
          slivers: (history, forward) => recipe.centeredSlivers(
            header: header,
            history: history,
            forward: forward,
            footer: const RaftTimelineFooter(),
          ),
          hasOlder: widget.thread ? w.threadHasMore : w.hasMore,
          loadingOlder: w.loadingOlder,
          onLoadOlder: presentationActive
              ? () => w.older(thread: widget.thread)
              : null,
          empty: widget.thread
              ? null
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
        : buildTimeline();
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
      // The composer handed this text off on submit; only a rejected send
      // gives it back, even if the conversation changed meanwhile.
      return accepted;
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
                KeyedSubtree(
                  key: const ValueKey('current-timeline'),
                  child: currentTimeline,
                ),
                if (!widget.thread &&
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
              // Web MessageInput drag-and-drop, paste and keyboard images.
              frame: (_, composer, enabled) => ComposerFileDropTarget(
                controller: w,
                thread: widget.thread,
                active: () =>
                    enabled && presentationActive && currentComposer(),
                child: composer,
              ),
              onPasteAttachments: () => pasteComposerAttachments(
                context,
                w,
                thread: widget.thread,
                active: () => presentationActive && currentComposer(),
              ),
              onContentInserted: (content) => insertComposerContent(
                context,
                w,
                content,
                thread: widget.thread,
                active: () => presentationActive && currentComposer(),
              ),
              clearOnSubmit: true,
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
