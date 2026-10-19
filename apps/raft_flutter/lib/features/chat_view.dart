import 'dart:convert';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mobile_route_gate.dart';
export 'mobile_route_gate.dart' show MobileChatDirectRead;
import 'message_timeline.dart';
import 'history_reading_anchor.dart';
import 'message_history_gaps.dart';
import '../data/message_history_memory.dart';
import '../data/message_history_positions.dart';
import 'row_extents.dart';

import '../data/plan_history.dart';
import '../data/raft_location.dart';
import '../data/raft_permalink.dart';
import '../data/thread_search.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_messages.dart';
import '../data/message_translation_store.dart';
import '../data/source_time_formatter.dart';
import '../platform/content_links.dart';
import '../data/personal_presentation.dart';
import '../platform/file_selection.dart';
import 'attachment_preview_dialog.dart' show attachmentPreviewKind;
import 'attachment_view.dart';
import 'media_items.dart';
import 'attachment_shape.dart';
import 'message_presentation.dart';
import 'message_preparation.dart';
import 'pending_mention_actions.dart';
import 'message_reference_directory.dart';
import 'share_message_link.dart';
import 'private_route_guard.dart';
import 'message_selection.dart';
import 'system_message_grouping.dart';
import 'copy_selection_links.dart';
import 'message_image_export.dart';
import 'forward_messages_dialog.dart';
import 'channel_footer_states.dart';
import 'composer_directory.dart';
import 'composer_attachment_input.dart';
import 'composer_attachments_view.dart';
import 'sender_avatar_projection.dart';
import 'message_reaction_projection.dart';
import 'message_agent_presentation.dart';
import 'agent_message_collapse.dart';
import 'agent_metadata_projection.dart';
import 'agent_avatar_projection.dart';
import 'profile_preview.dart';
import 'quoted_message_preview.dart';
import 'message_task_projection.dart';
import 'saved_sidebar_entry.dart';
import 'composer_slot.dart';

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

/// Opens a task from a message (footer chip, in-body `#N` reference) in the
/// host's task slot; [refresh] re-reads the message's task facts afterwards.
typedef ChatTaskOpener = void Function(
  Map<String, dynamic> task,
  Future<void> Function() refresh,
);

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
    this.onViewBilling,
    this.onOpenChannelSettings,
  });
  final WorkspaceController controller;

  /// ChatPanel's archived banner "Unarchive" link (Web `setOverflowOpen(true)`):
  /// opens the channel settings the header gear opens.
  final VoidCallback? onOpenChannelSettings;

  /// HistoryLimitBanner's "View Billing" link (Web `nav.toSettings("billing")`).
  final VoidCallback? onViewBilling;
  final bool thread;

  /// Source TaskModalHead is an independent task subject above the replies.
  final Widget? threadParentSlot;
  final bool hideThreadParent;
  final ChatSelectionHandle? selectionHandle;
  final ChatViewportHandle? viewportHandle;
  final ChatTaskOpener? onTask;
  @override
  State<RaftChatView> createState() => _RaftChatViewState();
}

class _RaftChatViewState extends PhonePageState<RaftChatView> {
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
  // ignore: raft_lints/avoid_imperative_notice_state -- Selection toolbar error: cleared when the selection ends (selectionChanged), on rebind and when a preview capture starts.
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
  ModalRoute<dynamic>? preparationRoute;
  late final bodyPreparation = MessagePreparation(
    isIdle: () =>
        mounted &&
        presentationActive &&
        w.presentationActive &&
        messagePreparationRouteIsIdle(preparationRoute) &&
        RaftFontWarmUp.isIdle,
  );
  Object? bodyPreparationInputs;

  void scheduleBodyPreparation(BuildContext context) {
    if (kDebugMode || !presentationActive) return;
    final tokens = RaftTokens.of(context);
    final fontSize = PersonalPresentationScope.bodyFontSize(
      context,
      w.client.user?.string('preferredMessageBodyFontSize'),
    );
    final inputs = (
      workspaceAuthority(w),
      bindingRevision,
      listRevision,
      referenceDirectory.references,
      taskProjection.byMessage,
      tokens,
      fontSize,
    );
    if (bodyPreparationInputs == inputs) return;
    bodyPreparationInputs = inputs;
    final window = rows;
    final nearest = widget.thread ? window : window.reversed;
    bodyPreparation.replace(
      nearest
          .take(64)
          .map(
            (message) => () {
              if (bodyPreparationInputs != inputs ||
                  workspaceAuthority(w) != inputs.$1 ||
                  bindingRevision != inputs.$2 ||
                  listRevision != inputs.$3) {
                return;
              }
              final translation = w.services.translations.present(message);
              if (translation.skeleton) return;
              MessagePresentation(
                controller: w,
                message: message,
                content: translation.translatedContent,
                taskByNumber: taskProjection.taskByNumber,
                directoryReferences: referenceDirectory.references,
                fontSize: fontSize,
                onExternalLink: link,
              ).prepareCache(tokens);
            },
          ),
    );
  }

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
    // The end is pinned again during the next layout (a tall new row, a fresh
    // center), which does not notify; re-read the reader's state afterwards so
    // the "N new messages" button cannot outlive the jump.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) timelineScrolled();
    });
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
          final context = focusAnchors[target]?.currentContext;
          if (context == null) return null;
          try {
            final box = context.findRenderObject();
            return box is RenderBox && box.attached ? box : null;
          } on FlutterError {
            // The row's element went inactive while the timeline rebuilt.
            return null;
          }
        },
        leading: leading,
      );

  /// Aligns a built row found by its wrapper key (no highlight anchor).
  RaftTimelineAlignment alignOnRow(String key, {double? leading}) =>
      RaftTimelineAlignment.row(
        find: () {
          RenderBox? found;
          void visit(Element element) {
            if (found != null) return;
            if (element.widget.key == ValueKey('message-wrapper-$key')) {
              final box = element.renderObject;
              if (box is RenderBox && box.attached) found = box;
              return;
            }
            element.visitChildren(visit);
          }

          try {
            (context as Element).visitChildren(visit);
          } on FlutterError {
            return null;
          }
          return found;
        },
        leading: leading,
      );

  double distanceFromLatest(ScrollPosition p) => p.maxScrollExtent - p.pixels;
  int newMessageCount = 0;
  Timer? highlightTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    preparationRoute = ModalRoute.of(context);
    final active =
        Visibility.of(context) && TickerMode.valuesOf(context).enabled;
    if (active != presentationActive) {
      presentationActive = active;
      ++presentationRevision;
      if (!active) {
        closeReactionPicker();
        bodyPreparation.cancel();
        bodyPreparationInputs = null;
      }
      if (active) sync();
    }
    if (!_directLatched && _directTimeline && presentationActive) {
      _directLatched = true;
      sync();
    }
  }

  // Web ThreadPanel in-thread search (thread view only): the bar's field and
  // focus, bound to the controller's [ThreadSearch].
  final searchInput = TextEditingController();
  final searchFocus = FocusNode();
  ThreadSearch? boundSearch;
  String? searchActive;
  int seenSearchFocus = 0;

  void bindThreadSearch() {
    boundSearch?.removeListener(threadSearchChanged);
    boundSearch = widget.thread ? w.threadSearch : null;
    boundSearch?.addListener(threadSearchChanged);
    searchActive = boundSearch?.activeMessageId;
    seenSearchFocus = boundSearch?.focusRequest ?? 0;
  }

  void threadSearchChanged() {
    final search = boundSearch;
    if (!mounted || search == null) return;
    if (searchInput.text != search.query) {
      searchInput.value = TextEditingValue(
        text: search.query,
        selection: TextSelection.collapsed(offset: search.query.length),
      );
    }
    if (search.focusRequest != seenSearchFocus) {
      seenSearchFocus = search.focusRequest;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !search.isOpen) return;
        searchFocus.requestFocus();
        searchInput.selection = TextSelection(
          baseOffset: 0,
          extentOffset: searchInput.text.length,
        );
      });
    }
    final active = search.activeMessageId;
    final changed = active != searchActive;
    searchActive = active;
    if (presentationActive) setState(() {});
    if (changed && active != null) revealSearchMatch(active);
  }

  /// Web `ensureThreadSearchMatchVisible` then `scrollToMessage(center)`: a
  /// match outside the loaded window reloads the thread around it (the
  /// timeline's focus reveal centers it); a loaded one is centered here.
  Future<void> revealSearchMatch(String id) async {
    final search = boundSearch;
    if (search == null) return;
    final loaded = await search.ensureVisible(id);
    if (!loaded || !mounted || searchActive != id || !presentationActive) {
      return;
    }
    if (w.presentedThreadParent?.id == id) {
      jumpToBeginning();
      return;
    }
    final target = adapter.messages
        .where((m) => m.metadata?['id'] == id)
        .firstOrNull;
    if (target == null) return;
    // Mount the row's anchor, then center it.
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || searchActive != id) return;
      recenter(first: target.id, alignment: alignOn(id));
    });
  }

  final focusAnchors = <String, GlobalKey>{};
  Future<void> updates = Future.value();
  WorkspaceController get w => widget.controller;
  WorkspaceMessages get _messages => w.messageDomain;

  /// Latched once the phone direct scope is visible, so the first dependencies
  /// pass reads the shared window before paint. Later dependency changes do
  /// not sync again.
  bool _directLatched = false;

  MobileChatDirectRead? get _directScope {
    if (!mounted) return null;
    try {
      return MobileChatDirectRead.maybeOf(context);
    } on FlutterError {
      return null;
    }
  }

  bool get _directTimeline {
    final scope = _directScope;
    if (scope == null) return false;
    return widget.thread ? scope.thread : scope.channel;
  }

  List<RaftMessage> get rows {
    // Covered and non-phone timelines keep the controller projection. The
    // foreground phone page reads the shared window, which already includes
    // pending sends. A missing window falls back so the first frame is not
    // emptied.
    if (MobileRouteGate.sharedWindow(
      context,
      w,
      direct: _directTimeline,
      visible: presentationActive,
    )) {
      final window = widget.thread
          ? _messages.threadWindow
          : _messages.messageWindow;
      if (window != null && !window.retired) return window.timeline;
    }
    return _messages.timeline(thread: widget.thread);
  }

  @override
  void initState() {
    super.initState();
    // Close the anchored reaction picker on window metric changes without a
    // MediaQuery size dependency: that dependency rebuilt the whole timeline
    // on every frame of a window resize.
    WidgetsBinding.instance.addObserver(this);
    viewport.addListener(timelineScrolled);
    if (!widget.thread &&
        _messages.state.channelLoading &&
        _messages.pendingMessageContextChannelId == w.channel?.id &&
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
      thread: widget.thread,
    )..addListener(referencesChanged);
    taskProjection = MessageTaskProjection(w)..addListener(referencesChanged);
    selection = MessageSelection(w, thread: widget.thread)
      ..addListener(selectionChanged);
    w.services.translations.addListener(referencesChanged);
    bindThreadSearch();
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
        oldWidget.controller.services.translations.removeListener(
          referencesChanged,
        );
        w.services.translations.addListener(referencesChanged);
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
          thread: widget.thread,
        )..addListener(referencesChanged);
        taskProjection = MessageTaskProjection(w)
          ..addListener(referencesChanged);
        w.addListener(sync);
      }
      if (!controllerChanged) {
        // The thread/channel scope picks the roster the composer suggests
        // from; the mobile shell reuses this State across the two.
        composerDirectory.dispose();
        composerDirectory = ComposerDirectory(
          w,
          agentPresentation: agentPresentation,
          thread: widget.thread,
        )..addListener(referencesChanged);
      }
      selection = MessageSelection(w, thread: widget.thread)
        ..addListener(selectionChanged);
      bindThreadSearch();
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
      // The failure belonged to the selection that just ended; entering
      // selection mode again must not show it.
      selectionError = null;
    }
    widget.selectionHandle?.update(selection.active, selection.exit);
    // A hidden retained page repaints nothing; it rebuilds when shown again.
    if (mounted &&
        presentationActive &&
        !RouteTransitionGate.defer(preparationRoute, selectionChanged)) {
      setState(() {});
    }
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
        selectionToast.show(raftText(context, 'Copied'), dismissible: false);
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
        selectionToast.show(
          raftText(context, 'Copied Markdown'),
          dismissible: false,
        );
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

  bool ordinary(RaftMessage m) => messageForwardable(m);
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
        setState(
          () => selectionError = raftText(
            context,
            userErrorText(
              e,
              fallback: "One or more selected items can't be forwarded. Select regular messages instead.",
              where: 'forward selection',
            ),
          ),
        );
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
        setState(
          () => selectionError = raftText(
            context,
            userErrorText(
              e,
              fallback: 'The message image could not be rendered.',
              where: 'message image preview',
            ),
          ),
        );
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

  /// Tells the controller whether this timeline sits at the latest end (the
  /// phone reads a live append only there). Edge-only: callers gate on a change.
  String? reportedBottomId;
  void reportBottom(bool bottom) {
    final id = widget.thread ? w.threadChannelId : w.channel?.id;
    if (id == null) return;
    reportedBottomId = bottom ? null : id;
    w.setTimelineAtBottom(id, bottom);
  }

  void timelineScrolled() {
    closePickerOnScroll();
    if (!mounted || viewport.positions.length != 1) return;
    final position = viewport.position;
    if (!position.hasContentDimensions) return;
    final sampledId = widget.thread ? w.threadChannelId : w.channel?.id;
    MessageHistoryMemory.sample(w, this, () {
      if (mounted && sampledId == scope) saveReadingAnchor();
    });
    // MessageTimeline.tsx AT_BOTTOM_THRESHOLD.
    final next = distanceFromLatest(position) <= 100;
    if (next != atBottom || (next && newMessageCount != 0)) {
      final arrived = next && !atBottom;
      if (next != atBottom) reportBottom(next);
      setState(() {
        atBottom = next;
        if (next) newMessageCount = 0;
      });
      // Source setNearBottom(true) -> markCurrentChannelRead: scrolling back
      // to the latest end reads what arrived while the reader was above it.
      if (arrived && presentationActive) {
        // A covered direct page shares the session receipt. It must not send
        // one. Other pages keep the existing receipt rule.
        if (_directTimeline && MobileRouteGate.paused(context, w)) return;
        final id = widget.thread ? w.threadChannelId : w.channel?.id;
        if (id != null && (w.unread[id] ?? 0) != 0) {
          unawaited(w.markRead(id));
        }
      }
    }
  }

  Future<void> returnToBottom() async {
    newMessageCount = 0;
    returningLatest = widget.thread
        ? _messages.threadWindow?.hasNewer == true
        : _messages.state.hasNewer;
    await _messages.returnToLatest(
      thread: widget.thread,
      navigate: w.section == 'chat',
    );
    if (!mounted || returningLatest) return;
    showLatest();
    timelineScrolled();
  }

  // Projections of the presented rows, reused while a row is unchanged (the
  // controller returns the same RaftMessage for an unchanged ledger row).
  final projections = Expando<chat.Message>('chat projections');
  final sources = Expando<RaftMessage>('projected rows');
  chat.Message project(RaftMessage m) {
    final key = _messages.messageKey(m);
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
    if (mounted &&
        presentationActive &&
        !RouteTransitionGate.defer(preparationRoute, referencesChanged)) {
      setState(() {});
    }
  }

  @override
  void didChangeMetrics() {
    if (reactionPicker != null) closeReactionPicker();
    saveReadingAnchor();
  }

  /// A fold/unfold rebuilds the timeline in the other layout: remember the
  /// topmost visible row (by id, not pixels, which reflow) so the new one
  /// resumes there. Only readers above the latest end need it.
  void saveReadingAnchor() {
    final id = widget.thread ? w.threadChannelId : w.channel?.id;
    if (!mounted ||
        id == null ||
        scope != id ||
        adapterWindow !=
            (widget.thread
                ? _messages.threadGeneration
                : _messages.channelGeneration) ||
        !viewport.hasClients ||
        viewport.positions.length != 1) {
      return;
    }
    // A short restored context can end inside the viewport while newer rows
    // remain on disk. Only the conversation's latest end clears its anchor.
    if (atBottom &&
        !(widget.thread
            ? _messages.threadWindow?.hasNewer == true
            : _messages.state.hasNewer)) {
      w.messageWindows.clearReadingAnchor(id);
      MessageHistoryPositions.save(w, id, null);
    } else if (captureTimelineReadingAnchor(context) case final anchor?) {
      _messages.saveReadingAnchor(id, anchor);
    }
  }

  @override
  void dispose() {
    saveReadingAnchor();
    MessageHistoryMemory.cancelSample(w, this);
    releaseAgentCollapse(this);
    if (reportedBottomId case final id?) w.setTimelineAtBottom(id, true);
    WidgetsBinding.instance.removeObserver(this);
    widget.viewportHandle?.release(this);
    boundSearch?.removeListener(threadSearchChanged);
    searchInput.dispose();
    searchFocus.dispose();
    copiedSelectionTimer?.cancel();
    bodyPreparation.dispose();
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
    w.services.translations.removeListener(referencesChanged);
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
    ReadingAnchor? resume,
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
    final resumed = target != null || resume == null
        ? null
        : messages.where((m) => m.id == resume.messageKey).firstOrNull;
    centerFirst = (target ?? resumed)?.id;
    centerAfter = target == null && resumed == null
        ? messages.lastOrNull?.id
        : null;
    lastCenterIndex = target == null && resumed == null ? messages.length : 0;
    centerEpoch++;
    viewport = RaftTimelineScrollController(
      bottomAnchored: bottomAnchored,
      initial: target != null
          ? alignOn(focus!, leading: focusTop)
          : resumed != null
          ? alignOnRow(resumed.id, leading: resume!.top)
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
    // The window owns ordering, including an optimistic row's confirmed
    // server sequence. Keep row identity and reading anchors, not stale order.
    final next = projected;
    var same = current.length == next.length;
    for (var i = 0; same && i < next.length; i++) {
      final a = current[i], b = next[i];
      same =
          identical(a, b) ||
          (a.id == b.id && identical(a.metadata, b.metadata));
    }
    if (same) return false;
    final previousLast = current.lastOrNull?.id;
    if (!atBottom &&
            insertsBetweenRetainedRows(
              current.map((m) => m.id),
              next.map((m) => m.id),
            ) ||
        centerFirst != null && !wanted.contains(centerFirst) ||
        centerAfter != null && !wanted.contains(centerAfter)) {
      saveReadingAnchor();
      final resume = w.messageWindows.readingAnchor(scope ?? '');
      if (resume != null && wanted.contains(resume.messageKey)) {
        replaceContext(next, resume: resume);
        return true;
      }
    }
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

  int windowRevision = 0;
  bool revealPending = false, preservingFocus = false;
  int revealTicket = 0;
  String? revealing;
  int? revealingWindow;

  void sync() {
    if (!mounted ||
        MobileRouteGate.paused(context, w) ||
        RouteTransitionGate.defer(preparationRoute, sync)) {
      return;
    }
    if (reactionPicker != null && pickerAuthority != workspaceAuthority(w)) {
      closeReactionPicker();
    }
    // Web useTranslationBatch: the panel loads the server's translation
    // settings once per server.
    w.services.translations.ensureSettings();
    // Upload drafts and composer authority are independent of the chat
    // adapter's message diff. Rebuild them on this view's own listener even
    // when an adaptive/setup parent retains the same child instance. A hidden
    // retained page (another section or route in front) is not painted, and
    // becoming active again calls sync() once more, so it does not rebuild its
    // composer and chrome on every notification while a transition plays.
    if (mounted && presentationActive) setState(() {});
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
      final window = widget.thread
          ? _messages.threadGeneration
          : _messages.channelGeneration;
      final loading = widget.thread
          ? _messages.state.threadLoading
          : _messages.state.channelLoading;
      final target = _messages.state.highlightedMessageId;
      // A newly mounted preview can own a still-accepted same-channel window
      // while its permalink GET waits. Publish that accepted window at its
      // actual end; the pending target is not part of it. Cross-channel rows
      // are already excluded by the controller's projection.
      final pendingAcceptedMount =
          !widget.thread &&
          loading &&
          scope != id &&
          _messages.pendingMessageContextChannelId == id &&
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
        final enteringScope = scope != id;
        if (enteringScope) {
          alsoCreateTask = false;
          selectionToast.clear();
        }
        scope = id;
        // A context replacement has different scroll bounds and its own
        // center; ordinary diffs and history prepends never enter here.
        replaceContext(
          projected,
          focus: pendingAcceptedMount ? null : target,
          resume:
              (enteringScope ||
                      adapter.messages.isEmpty ||
                      adapterWindow != window) &&
                  target == null &&
                  !pendingAcceptedMount &&
                  id != null
              ? _messages.takeReadingAnchor(id) ??
                    w.messageWindows.readingAnchor(id)
              : null,
        );
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
        window ==
            (widget.thread
                ? _messages.threadGeneration
                : _messages.channelGeneration);
    var attempts = 0;
    void check(Duration _) {
      if (!current()) {
        if (mounted && ticket == revealTicket) revealing = null;
        return;
      }
      if (target != null && !focusReceiptVisible(target) && attempts++ < 8) {
        // ignore: raft_lints/avoid_unreviewed_idle_work -- reveal(): ensures one frame for the first check and re-requests only while the target row is not visible, capped at 8 attempts.
        WidgetsBinding.instance.addPostFrameCallback(check);
        // ignore: raft_lints/avoid_unreviewed_idle_work -- reveal(): ensures one frame for the first check and re-requests only while the target row is not visible, capped at 8 attempts.
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
        final bottom =
            position == null ||
            !position.hasContentDimensions ||
            distanceFromLatest(position) <= 100;
        if (bottom != atBottom) reportBottom(bottom);
        atBottom = bottom;
      });
      if (preserving) return;
      highlightTimer?.cancel();
      if (target != null && _messages.state.highlightedMessageId == target) {
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
                      ? _messages.threadGeneration
                      : _messages.channelGeneration)) {
            _messages.clearHighlightedMessage(
              target,
              expectedNavigationRevision: navigationWindow,
            );
          }
        });
      }
    }

    // ignore: raft_lints/avoid_unreviewed_idle_work -- reveal(): ensures one frame for the first check and re-requests only while the target row is not visible, capped at 8 attempts.
    WidgetsBinding.instance.addPostFrameCallback(check);
    // ignore: raft_lints/avoid_unreviewed_idle_work -- reveal(): ensures one frame for the first check and re-requests only while the target row is not visible, capped at 8 attempts.
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
      raftComposerAccessory(context, w, thread: widget.thread);

  /// Web `openDraftImagePreview`: the local picture of a ready image in the
  /// lightbox.
  Future<void> previewDraftImage(UploadDraft draft) async {
    final zoom = TransformationController();
    late final DialogRoute<void> route;
    final imageKey = GlobalKey();
    void close() {
      if (route.isActive) route.navigator?.removeRoute(route);
    }

    route = RaftFullBleedDialogRoute<void>(
      context: context,
      builder: (_) => RaftAttachmentLightbox(
        title: draft.filename,
        titleBold: true,
        onResetZoom: () => zoom.value = Matrix4.identity(),
        onClose: close,
        child: RaftLightboxStageTap(
          imageKey: imageKey,
          onClose: close,
          child: InteractiveViewer(
            transformationController: zoom,
            child: Center(
              child: RaftSizedImage.memory(
                draft.bytes,
                key: imageKey,
                fit: BoxFit.contain,
                zoom: raftZoomableImageScale,
                evictOnDispose: true,
              ),
            ),
          ),
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    zoom.dispose();
  }

  Future<void> attach({bool mediaOnly = false}) async {
    final scope = w.draftScope(thread: widget.thread),
        generation = _messages.ledger.generation;
    try {
      final files = await selectUploads(mediaOnly: mediaOnly);
      if (files.isEmpty || !mounted) return;
      if (generation != _messages.ledger.generation ||
          scope != w.draftScope(thread: widget.thread)) {
        return;
      }
      final picked = <({String name, Uint8List bytes})>[];
      for (final file in files) {
        picked.add((name: file.name, bytes: await file.readAsBytes()));
        if (!mounted ||
            generation != _messages.ledger.generation ||
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
      // Web MessageInput `setError`: the composer's error banner.
      if (mounted) {
        // ignore: raft_lints/avoid_imperative_notice_state -- Attach-selection failure: the composer notice store ends it with the composer visit (channel/thread change), the next accepted send, or the next selection's decision.
        w.setComposerError(
          userErrorText(e, fallback: 'Upload failed', where: 'attach files'),
          thread: widget.thread,
        );
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
    final summary = _messages.threadSummaries[message.id];
    // `hideThreadActions`: thread panel rows (parent and replies).
    final hideThreadActions = widget.thread || parentTile;
    final threadReply = widget.thread && !parentTile;
    final hasThreadConversation =
        (summary is Map &&
            (summary['threadChannelId'] != null ||
                (int.tryParse('${summary['replyCount']}') ?? 0) > 0)) ||
        message.json['threadChannelId'] != null;
    // Source MessageItem reads the server-scoped followed list synchronously.
    final followedThreads = w.services.followedThreads;
    if (!hideThreadActions && hasThreadConversation) followedThreads.ensure();
    final followed = followedThreads.isFollowing(message.id);
    final task = taskProjection.taskFor(message);
    final guest = w.server?.string('role') == 'guest';
    // Web MessageItem: an external_projection has no convert, reopen, or done.
    final supportsTasks =
        w.channel?.type != 'thread' &&
        message.string('senderType') != 'external_projection';
    final saved = SavedCountStore.of(w).isSaved(message.id);
    final translation = w.services.translations.present(message);
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
              // Web: manual mode offers Translate (Translating… while the
              // request is pending) after Copy Markdown.
              if (translation.manualAction)
                RaftMessageContextMenuItem(
                  key: const ValueKey('message-menu-translate'),
                  label: raftText(
                    menuContext,
                    translation.manualPending ? 'Translating…' : 'Translate',
                  ),
                  icon: raftMessageMenuIcon(RaftGlyph.languages),
                  onPressed: translation.manualPending
                      ? null
                      : () => pick(menuContext, 'translate'),
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
      if (choice == 'translate') {
        unawaited(w.services.translations.translate(message));
      }
      if (choice == 'select') selection.enter(message.id);
      if (choice == 'thread') await _messages.threads.openThread(message);
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
        showRaftToast(context, userErrorText(e, where: 'message action'));
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
    final summary = _messages.threadSummaries[m.id];
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
      onPressed: () => _messages.threads.openThread(m),
    );
  }

  Widget? inlineThreadReplies(RaftMessage parent, {required bool parentTile}) {
    if (parentTile ||
        widget.thread ||
        w.channel == null ||
        !w.can('viewChannel', resource: w.channel)) {
      return null;
    }
    final summary = _messages.threadSummaries[parent.id];
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
          !_messages.presentsMessage(parent.id) ||
          !w.can('viewChannel', resource: w.channel)) {
        return;
      }
      // All previews are one parent-thread action. Focus an authoritative unread
      // target only; clicking a preview does not create a different route.
      final live = _messages.threadSummaries[parent.id];
      final unread = live is Map && live['firstUnreadMessageId'] is String
          ? live['firstUnreadMessageId'] as String
          : null;
      _messages.threads.openThread(parent, focusedMessageId: unread);
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

  /// The media browser's context of [message]: sender, send time and text,
  /// read when the browser opens.
  MediaMessageInfo Function() mediaMessage(RaftMessage message) =>
      () => MediaMessageInfo(
        sender: message.author,
        time: message.createdAt == null
            ? null
            : timeFormatter.mediumDateTime(message.createdAt),
        text: message.content,
      );

  Widget? attachmentGallery(RaftMessage message) {
    final all = message.attachments;
    bool raster(Map<String, dynamic> metadata) =>
        attachmentIsInlineImage(metadata);

    final images = all.where(raster).toList();
    // The media browser's pages in message order: the images, and the videos
    // when the browser pages through those too.
    final media = [
      for (final a in all)
        if (raster(a) || attachmentPreviewKind(a) == 'video') a,
    ];
    // Web MessageItem: images, then videos, then audio (each `space-y-2`),
    // then every other attachment as a card.
    final videos = [
      for (final a in all)
        if (!raster(a) && attachmentPreviewKind(a) == 'video') a,
    ];
    final audios = [
      for (final a in all)
        if (!raster(a) && attachmentPreviewKind(a) == 'audio') a,
    ];
    final others = [
      for (final a in all)
        if (!raster(a) && !videos.contains(a) && !audios.contains(a)) a,
    ];
    if (images.isEmpty && videos.isEmpty && audios.isEmpty) return null;
    final pending = WorkspaceController.isPendingSend(message);
    final messageId = pending ? null : message.id;
    Widget view(Map<String, dynamic> a) => sendStateAttachment(
      pending,
      AttachmentView(
        key: ValueKey('attachment-${a['id']}'),
        controller: w,
        metadata: a,
        messageId: messageId,
        mediaMessage: mediaMessage(message),
        galleryItems: pending ? null : media,
      ),
    );
    return RaftAttachmentStack(
      gallery: images.isEmpty
          ? null
          : ShapedImageGallery(
              sessions: w.attachmentMedia.playerSessions,
              images: images,
              builder: (dimensions) => RaftAttachmentGallery(
                dimensions: dimensions,
                itemBuilder: (index, extent, fit) => sendStateAttachment(
                  pending,
                  AttachmentView(
                    key: ValueKey('attachment-${images[index]['id']}'),
                    controller: w,
                    metadata: images[index],
                    messageId: messageId,
                    mediaMessage: mediaMessage(message),
                    imageExtent: extent,
                    imageFit: fit,
                    // Web lightboxImages: the message's images, no optimistic.
                    galleryItems: pending ? null : media,
                  ),
                ),
              ),
            ),
      videos: [for (final a in videos) view(a)],
      audios: [for (final a in audios) view(a)],
      others: [for (final a in others) view(a)],
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
    if (message.string('senderType') == 'external_projection') {
      return externalSenderSubtitle(message);
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
        child: RaftBackDismiss(
          routeContext: this.context,
          onDismiss: closeReactionPicker,
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
            onPressed: presentationActive
                ? () => _messages.threads.openThread(message)
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
          (_) => _messages.threads.openThread(message),
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
      ...translationSemanticsActions(message),
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
        showRaftToast(context, userErrorText(e, where: 'save message'));
      }
    }
  }

  Widget senderAvatar(RaftMessage message, {bool compact = false}) {
    final local =
        message.json['sourceServerId'] == null ||
        message.json['sourceServerId'] == w.server?.id;
    // Joint peers are not in the server directory; the channel roster read
    // when the channel opened lists them (rows rebuild when it arrives, the
    // composer directory notifies this view).
    final roster = w.channel == null
        ? null
        : cachedChannelRoster(w, w.channel!.id);
    final source = projectSenderAvatar(
      origin: w.client.origin,
      senderId: message.string('senderId'),
      senderType: message.string('senderType'),
      channelAgents: roster?.agents ?? const [],
      channelMembers: roster?.humans ?? const [],
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
        initials: message.author,
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
          'message-avatar-${_messages.messageKey(message)}-${source.identity}',
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

    final Widget sender = message.string('senderType') != 'agent'
        ? avatar()
        : QuietListenableBuilder(
            listenable: presentation.presenceOf(message.senderId),
            builder: (context, _) => avatar(),
          );
    // Web SenderAvatar `<button>` + PreviewCard (profile / external identity
    // on hover): a click opens the profile side panel.
    return compact
        ? sender
        : senderProfileHoverCard(
            controller: w,
            message: message,
            content: avatarContent,
            child: RaftAvatarButton(
              key: ValueKey('sender-avatar-${_messages.messageKey(message)}'),
              semanticLabel: message.author,
              onPressed: senderProfileTarget(message) == null
                  ? null
                  : () => openSenderProfile(message),
              child: sender,
            ),
            onOpenActivity: senderIsAgent(message)
                ? (id) => w.openProfile(
                    RaftProfileKind.agent,
                    id,
                    agentTab: 'activity',
                  )
                : null,
          );
  }

  bool senderIsAgent(RaftMessage m) => m.string('senderType') == 'agent';

  /// Web MessageItem `handleNavigateAgent` / `Human` / `External`: the kind a
  /// sender avatar opens, or null (system rows, another server's sender).
  RaftProfileKind? senderProfileTarget(RaftMessage m) {
    if (m.json['sourceServerId'] != null &&
        m.json['sourceServerId'] != w.server?.id) {
      return null;
    }
    if (m.string('senderType') == 'external_projection' ||
        m.json['externalAuthor'] is Map) {
      return m.json['externalAuthor'] is Map ? RaftProfileKind.external : null;
    }
    if (m.string('senderId').isEmpty) return null;
    return switch (m.string('senderType')) {
      'agent' => RaftProfileKind.agent,
      'user' => RaftProfileKind.human,
      _ => null,
    };
  }

  void openSenderProfile(RaftMessage m) {
    if (selection.active) return;
    switch (senderProfileTarget(m)) {
      case RaftProfileKind.external:
        w.openProfile(
          RaftProfileKind.external,
          m.id,
          channelId: m.channelId,
          externalAuthor: Map<String, dynamic>.from(
            m.json['externalAuthor'] as Map,
          ),
        );
      case final kind?:
        w.openProfile(kind, m.string('senderId'));
      case null:
        break;
    }
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
      // Inactive sections are gated by the pager. Keep the painted control
      // enabled so dragging the retained Chat back into view cannot dim its
      // task labels; recheck activity at invocation for stale callbacks.
      // A host without a task slot (onTask null) paints the chip disabled
      // instead of opening something Web does not open.
      onOpen: widget.onTask == null
          ? null
          : () {
              if (!presentationActive) return;
              // Open the accepted task current at tap time; a chip built from
              // the message's own fields waits for the channel's task rows.
              final current = taskProjection.taskFor(message);
              if (authority == workspaceAuthority(w) &&
                  current != null &&
                  current['id'] == task['id']) {
                // Source MessageItem3685–3700: the footer task chip opens the
                // independent task slot; the replies action keeps side intent.
                widget.onTask!(current, () async {
                  if (mounted && authority == workspaceAuthority(w)) {
                    taskProjection.refresh();
                  }
                });
              }
            },
    );
  }

  /// Web `onOpenTaskRef`: an in-body `#N` reference opens the task slot like
  /// the footer chip. Null when the host has no task slot (the reference then
  /// falls back to its read-only summary dialog).
  ValueChanged<Map<String, dynamic>>? get openTaskRef {
    final open = widget.onTask;
    if (open == null) return null;
    final authority = workspaceAuthority(w);
    return (task) => open(task, () async {
      if (mounted && authority == workspaceAuthority(w)) {
        taskProjection.refresh();
      }
    });
  }

  /// Web AttachmentChip `isOptimistic`: dimmed and inert until the message
  /// exists. One wrapper shape for every row keeps the attachment state when
  /// the server copy replaces the optimistic row.
  Widget sendStateAttachment(bool pending, Widget child) => IgnorePointer(
    ignoring: pending,
    child: Opacity(opacity: pending ? .7 : 1, child: child),
  );

  /// Web MessageItem body: the pending skeleton (auto mode), the
  /// translation or the original, and the bilingual view's original below.
  Widget translatedBody(
    RaftMessage m,
    MessageTranslationPresentation translation,
    double fontSize,
  ) {
    if (translation.skeleton) {
      return RaftMessageTranslationSkeleton(
        key: ValueKey('message-translation-placeholder-${m.id}'),
        fontSize: fontSize,
      );
    }
    final quoted = quotedPermalink(m);
    final body = MessagePresentation(
      controller: w,
      message: m,
      unavailablePermalink: quoted == null ? null : unavailableQuoted[m.id],
      content: translation.translatedContent,
      taskByNumber: taskProjection.taskByNumber,
      onExternalLink: link,
      onOpenTask: openTaskRef,
      directoryReferences: referenceDirectory.references,
      fontSize: fontSize,
      searchHighlight: searchActive == m.id ? boundSearch?.query : null,
    );
    if (!translation.bilingual) return withQuotedPreview(m, quoted, body);
    return withQuotedPreview(
      m,
      quoted,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          RaftMessageTranslationOriginal(
            key: ValueKey('message-translation-bilingual-original-${m.id}'),
            label: raftText(context, 'Original'),
            child: MessagePresentation(
              controller: w,
              message: m,
              taskByNumber: taskProjection.taskByNumber,
              onExternalLink: link,
              onOpenTask: openTaskRef,
              directoryReferences: referenceDirectory.references,
              fontSize: fontSize,
              foregroundColor: RaftMessageTranslationOriginal.foreground(
                context,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Web MessageItem: the first Raft permalink of this server in the text.
  ({String rawUrl, RaftPermalink parsed})? quotedPermalink(RaftMessage m) {
    if (m.json['sourceServerId'] != null &&
        m.json['sourceServerId'] != w.server?.id) {
      return null;
    }
    return extractFirstQuotedPermalink(
      m.content,
      hostname: ContentLinks.originFor(w.client.origin).host,
      serverSlug: w.server?.string('slug'),
    );
  }

  /// Raw URL of a row's permalink whose preview could not be read.
  final Map<String, String> unavailableQuoted = {};

  Widget withQuotedPreview(
    RaftMessage m,
    ({String rawUrl, RaftPermalink parsed})? quoted,
    Widget body,
  ) {
    if (quoted == null || unavailableQuoted[m.id] == quoted.rawUrl) return body;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        RaftQuotedMessageSlot(
          child: QuotedMessagePermalinkPreview(
            key: ValueKey('quoted-${m.id}-${quoted.rawUrl}'),
            controller: w,
            permalink: quoted.parsed,
            avatar: (target) => senderAvatar(target, compact: true),
            subtitle: senderSubtitle,
            formatTimestamp: quotedTimestamp(),
            onOpen: (link) => unawaited(openRaftPermalink(w, link)),
            onUnavailable: () {
              // Web: the chip reads "Unavailable linked message" and the card
              // is dropped; the row repaints after the current frame.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && unavailableQuoted[m.id] != quoted.rawUrl) {
                  setState(() => unavailableQuoted[m.id] = quoted.rawUrl);
                }
              });
            },
          ),
        ),
      ],
    );
  }

  /// Web `formatShortDateTime` in the account's zone and hour cycle.
  String Function(DateTime) quotedTimestamp() {
    final user = w.client.user;
    return SourceTimeFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      preferredTimezone:
          user?.string('preferredTimezone') ?? user?.string('timezone'),
      preferredTimeFormat: sourceTimeFormatPreference(
        user?.string('preferredTimeFormat') ?? user?.string('timeFormat'),
      ),
      systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
          ? SourceTimeFormat.twentyFourHour
          : null,
    ).shortDateTime;
  }

  /// Web MessageItem `TranslationIndicator`.
  Widget? translationStatus(
    RaftMessage m,
    MessageTranslationPresentation translation,
  ) {
    final entry = translation.entry;
    if (entry == null || !entry.indicated) return null;
    final RaftMessageTranslationStatus status;
    if (entry.hasContent) {
      final original = translation.showingOriginal;
      status = RaftMessageTranslationStatus(
        tone: RaftMessageTranslationTone.normal,
        actionLabel: raftText(
          context,
          original ? 'Show translation' : 'Show original',
        ),
        tooltip: raftText(
          context,
          original
              ? 'Original shown. Show translation'
              : 'Translated. Show original',
        ),
        onAction: () =>
            w.services.translations.setShowOriginal(m.id, !original),
      );
    } else if (entry.status == MessageTranslationStatus.pending) {
      status = RaftMessageTranslationStatus(
        tone: RaftMessageTranslationTone.pending,
        message: raftText(context, 'Translating…'),
        tooltip: raftText(context, 'Translating'),
      );
    } else {
      final unavailable = raftText(context, 'Translation unavailable');
      status = RaftMessageTranslationStatus(
        tone: RaftMessageTranslationTone.failed,
        message: unavailable,
        actionLabel: raftText(context, 'Retry'),
        tooltip: unavailable,
        onAction: () => unawaited(w.services.translations.translate(m)),
      );
    }
    return KeyedSubtree(
      key: ValueKey('message-translation-indicator-${m.id}'),
      child: status,
    );
  }

  List<RaftMessageSemanticsAction> translationSemanticsActions(RaftMessage m) {
    final translation = w.services.translations.present(m);
    final entry = translation.entry;
    return [
      if (translation.manualAction && !translation.manualPending)
        RaftMessageSemanticsAction(
          raftText(context, 'Translate'),
          (_) => unawaited(w.services.translations.translate(m)),
        ),
      if (entry != null && entry.hasContent)
        RaftMessageSemanticsAction(
          raftText(
            context,
            translation.showingOriginal ? 'Show translation' : 'Show original',
          ),
          (_) => w.services.translations.setShowOriginal(
            m.id,
            !translation.showingOriginal,
          ),
        )
      else if (entry?.status == MessageTranslationStatus.failed)
        RaftMessageSemanticsAction(
          raftText(context, 'Retry'),
          (_) => unawaited(w.services.translations.translate(m)),
        ),
    ];
  }

  Widget messageTile(
    RaftMessage m, {
    bool parent = false,
    Widget? selectionLeading,
    bool continuation = false,
    bool nextContinuation = false,
  }) {
    // Optimistic rows share the final row's key and widget shape; only the
    // actions that need a server message id stay inert until it arrives.
    final key = _messages.messageKey(m);
    final pending = WorkspaceController.isPendingSend(m);
    if (m.string('messageType') == 'system') {
      return RaftSystemMessage(
        key: ValueKey('message-$key'),
        content: m.content,
        timestamp: m.createdAt == null ? '' : clock(m.createdAt!),
      );
    }
    final times = timeFormatter;
    final fontSize = PersonalPresentationScope.bodyFontSize(
      context,
      w.client.user?.string('preferredMessageBodyFontSize'),
    );
    final translation = w.services.translations.present(m);
    // Web useTranslationBatch: auto mode asks for the rows in the built
    // window; the store batches them and skips cached / in-flight rows.
    if (translation.needsRequest && presentationActive) {
      w.services.translations.want(m);
    }
    final session = agentCollapseOf(this);
    final choice = agentMessageOpens(
      session,
      parent,
      senderIsAgent(m),
      m,
      w,
      scope,
    );
    return RaftMessageTile(
      key: ValueKey('message-$key'),
      rowContext: widget.thread
          ? RaftMessageRowContext.thread
          : RaftMessageRowContext.main,
      continuation: continuation,
      nextContinuation: nextContinuation,
      author: m.author,
      avatar: senderAvatar(m),
      selectionLeading: selectionLeading,
      content: translation.translatedContent ?? m.content,
      body: translatedBody(m, translation, fontSize),
      bodyFontSize: fontSize,
      translation: translationStatus(m, translation),
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
      highlighted:
          _messages.state.highlightedMessageId == m.id || searchActive == m.id,
      collapseLongMessages: choice.collapse,
      initiallyExpanded: choice.open,
      onMessageExpanded: (open) => session.choose(m.id, open),
      timestamp: times.messageTime(m.createdAt),
      continuationTimestamp: continuation ? times.clock(m.createdAt) : null,
      timestampTooltip: continuation ? times.mediumDateTime(m.createdAt) : null,
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
              if (!pending) _messages.threads.openThread(m);
            },
      threadPreview: inlineThreadReplies(m, parentTile: parent),
      taskReference: taskReference(m),
      threadRepliesBadge: threadRepliesBadge(m, parentTile: parent),
      threadLabel: _messages.threadSummaries[m.id] is Map
          ? raftFormat(context, '{count} replies', {
              'count': _messages.threadSummaries[m.id]['replyCount'] ?? 0,
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
          mediaMessage: mediaMessage(m),
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
          // ignore: raft_lints/avoid_render_index_assertion -- Guarded by `reactionFailures[m.id] == null ? const {} : ...` on the line above.
          : {reactionFailures[m.id]!},
      reactionViewerId: w.client.user?.id,
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

  /// Web ChatPanel footer chain (channel_footer_states.dart): the replacement
  /// for the composer (null = show the composer) and the joint over-limit grace
  /// banner above it.
  (Widget?, Widget?) channelFooterWidgets() {
    final channel = w.channel;
    if (channel == null) return (null, null);
    final now = sourceTimeNow();
    Widget? grace;
    final ends = channel.archived
        ? null
        : jointChannelGraceEndsAt(channel.json, now);
    if (ends != null) {
      grace = RaftChannelGraceBanner(
        message: raftFormat(
          context,
          "This Joint Channel has more than 2 free servers and becomes read-only on {deadline}. To keep it writable, one server's admin needs to upgrade, or a free server needs to leave.",
          {
            'deadline': timeFormatter.mediumDateTime(
              ends,
              followPreference: false,
            ),
          },
        ),
      );
    }
    final guest = w.server?.string('role') == 'guest';
    final footer = switch (channelFooterKind(w, now)) {
      null || ChannelFooterKind.composer => null,
      ChannelFooterKind.archived => RaftChannelArchivedFooter(
        message: 'This channel is archived.',
        linkLabel:
            w.can('archiveChannels') && widget.onOpenChannelSettings != null
            ? 'Unarchive'
            : null,
        onLink: widget.onOpenChannelSettings,
      ),
      ChannelFooterKind.jointLocked => RaftChannelBannerFooter(
        message: "This Joint Channel is read-only because it has more than 2 free servers. It becomes writable again when one server's admin upgrades or a free server leaves.",
        linkLabel: widget.onViewBilling == null ? null : 'View Billing',
        onLink: widget.onViewBilling,
      ),
      ChannelFooterKind.guestReadOnly => const RaftChannelBannerFooter(
        message: 'Guest access is read-only. You can read and follow updates, but you cannot post or react.',
      ),
      ChannelFooterKind.join => RaftChannelJoinFooter(
        channelName: channel.name,
        onJoin: _messages.joinOpenChannel,
        explanation: guest
            ? 'Joining adds this channel to your sidebar and follows its updates. It does not enable posting or reactions.'
            : null,
      ),
    };
    return (footer, grace);
  }

  /// Web ThreadPanel footer chain: guest read-only / joint locked banners and
  /// the "Join channel to reply" CTA replace the composer (null = composer).
  Widget? threadFooterWidget() {
    final parent = _messages.threadSourceChannel;
    if (parent == null) return null;
    final guest = w.server?.string('role') == 'guest';
    final joined = parent.joined;
    final guestJoinable = parent.json['guestJoinable'] == true;
    if (guest && (joined || !guestJoinable)) {
      return const RaftChannelBannerFooter(
        message: 'Guest access is read-only. You can read and follow this thread, but you cannot reply or react.',
      );
    }
    if (selection.active) return null;
    if (jointChannelReadOnly(parent.json, sourceTimeNow())) {
      return RaftChannelBannerFooter(
        message: "This Joint Channel is read-only because it has more than 2 free servers. It becomes writable again when one server's admin upgrades or a free server leaves.",
        linkLabel: widget.onViewBilling == null ? null : 'View Billing',
        onLink: widget.onViewBilling,
      );
    }
    if (joined) return null;
    return RaftChannelJoinFooter(
      channelName: parent.name,
      label: guest ? 'Join channel' : 'Join channel to reply',
      onJoin: _messages.joinThreadParentChannel,
      explanation: guest
          ? 'Joining follows the parent channel. Guest access remains read-only.'
          : null,
    );
  }

  /// ChatPanel `contextLoadError` banner above the history state: the jump
  /// target is missing ("Message not found") or hidden by the plan cutoff.
  Widget? contextLoadBanner() {
    final error = _messages.contextLoadError;
    if (error == null) return null;
    if (error == MessageContextLoadError.beyondHistory) {
      final limit = planHistoryLimit(w.server?.string('plan'));
      return RaftHistoryLimitBanner(
        message: raftFormat(
          context,
          'This message is older than the {days}-day history available on the {plan} plan. Upgrade to view it.',
          {'days': limit.days, 'plan': limit.plan},
        ),
        linkLabel: widget.onViewBilling == null
            ? null
            : raftText(context, 'View Billing'),
        onLink: widget.onViewBilling,
      );
    }
    return RaftHistoryLimitBanner(
      message: raftText(context, 'Message not found'),
    );
  }

  /// Web HistoryLimitBanner: the plan message-history cutoff notice with a
  /// billing link, shared by the channel list and the thread panel.
  Widget historyLimitBanner({bool inset = false}) {
    final limit = planHistoryLimit(w.server?.string('plan'));
    return RaftHistoryLimitBanner(
      inset: inset,
      message: raftFormat(
        context,
        'Message history is limited to {days} days on the {plan} plan.',
        {'days': limit.days, 'plan': limit.plan},
      ),
      linkLabel: widget.onViewBilling == null
          ? null
          : raftText(context, 'View Billing'),
      onLink: widget.onViewBilling,
    );
  }

  Widget threadTopSliver({bool loading = false, bool showSummary = true}) =>
      RaftThreadTimelineTopSliver(
        showSummary: showSummary,
        parentSlot: widget.threadParentSlot,
        parent: widget.hideThreadParent || w.presentedThreadParent == null
            ? null
            : tile(w.presentedThreadParent!, parent: true),
        hasMore: loading || w.threadHasMore,
        historyLimited: _messages.state.threadHistoryLimited,
        loadingOlder: loading || _messages.state.loadingOlder,
        loadingOlderLabel: raftText(context, 'Loading older replies...'),
        historyLimitedLabel: raftText(
          context,
          'Older replies are limited by the current plan',
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

  // Web `expandedSystemMessageGroups` + `systemMessageRenderStates`: render-only
  // grouping of adjacent system messages over the displayed window.
  final expandedSystemGroups = <String>{};
  List<SystemGroupState?>? systemStates;
  List<chat.Message>? systemStatesWindow;
  int systemStatesRevision = -1;
  String? systemStatesLocale;
  SystemGroupState? systemStateAt(int index) {
    final list = adapter.messages;
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (systemStates == null ||
        !identical(list, systemStatesWindow) ||
        systemStatesRevision != windowRevision ||
        systemStatesLocale != locale) {
      systemStates = buildSystemGroupStates([
        for (final m in list) source(m),
      ], (text, values) => raftFormat(context, text, values));
      systemStatesWindow = list;
      systemStatesRevision = windowRevision;
      systemStatesLocale = locale;
    }
    return index < systemStates!.length ? systemStates![index] : null;
  }

  Widget datedTile(RaftMessage message, {bool captureFocus = true}) {
    final stamp = message.createdAt;
    final key = _messages.messageKey(message);
    final index = windowIndexOf(key);
    final systemState = index == null ? null : systemStateAt(index);
    if (systemState is SystemGroupHide) {
      return RaftRowExtentRecorder(
        scope: rowExtentScope(context),
        id: key,
        child: SizedBox.shrink(key: ValueKey('message-wrapper-$key')),
      );
    }
    if (systemState is SystemGroupSummary) {
      final expanded = expandedSystemGroups.contains(systemState.groupId);
      return RaftRowExtentRecorder(
        scope: rowExtentScope(context),
        id: key,
        child: Padding(
          key: ValueKey('message-wrapper-$key'),
          padding: const RaftTimelineCompositionRecipe().messageInsetFor(
            MediaQuery.sizeOf(context).width,
          ),
          child: RaftSystemMessageGroup(
            toggleKey: const ValueKey('system-message-group-toggle'),
            summary: systemState.summary,
            expanded: expanded,
            onToggle: () => setState(() {
              if (!expandedSystemGroups.remove(systemState.groupId)) {
                expandedSystemGroups.add(systemState.groupId);
              }
            }),
            children: [
              for (final at in systemState.messageIndexes)
                tile(source(adapter.messages[at])),
            ],
          ),
        ),
      );
    }
    DateTime? previous;
    if (index != null) {
      previous = index > 0 ? adapter.messages[index - 1].createdAt : null;
    } else {
      final current = rows;
      final at = current.indexWhere((row) => _messages.messageKey(row) == key);
      previous = at > 0 ? current[at - 1].createdAt : null;
    }
    final showDay =
        stamp != null &&
        (previous == null ||
            timeFormatter.dayKey(previous) != timeFormatter.dayKey(stamp));
    final neighbours = displayedNeighbours(key, index);
    final continuation = continuesGroup(neighbours.$1, message);
    final following = neighbours.$2;
    final nextContinuation =
        following != null && continuesGroup(message, following);
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
            padding: const RaftTimelineCompositionRecipe().messageInsetFor(
              MediaQuery.sizeOf(context).width,
            ),
            child: tile(
              message,
              captureFocus: captureFocus,
              continuation: continuation,
              nextContinuation: nextContinuation,
            ),
          ),
        ],
      ),
    );
  }

  /// The displayed rows before and after [key] (over the window when it is
  /// indexed, else over [rows]).
  (RaftMessage?, RaftMessage?) displayedNeighbours(String key, int? index) {
    if (index != null) {
      final list = adapter.messages;
      return (
        index > 0 ? source(list[index - 1]) : null,
        index + 1 < list.length ? source(list[index + 1]) : null,
      );
    }
    final current = rows;
    final at = current.indexWhere((row) => _messages.messageKey(row) == key);
    return (
      at > 0 ? current[at - 1] : null,
      at >= 0 && at + 1 < current.length ? current[at + 1] : null,
    );
  }

  /// Source `messageGrouping.ts` computeMessageGrouping: [message] continues
  /// [previous]'s sender group when both are chat rows from the same sender on
  /// the same calendar day and neither carries a thread reply or a task (those
  /// render standalone with their own header).
  bool continuesGroup(RaftMessage? previous, RaftMessage message) {
    if (previous == null) return false;
    if (previous.string('messageType') == 'system' ||
        message.string('messageType') == 'system') {
      return false;
    }
    final before = previous.createdAt, now = message.createdAt;
    if (before == null ||
        now == null ||
        timeFormatter.dayKey(before) != timeFormatter.dayKey(now)) {
      return false;
    }
    bool standalone(RaftMessage m) =>
        _messages.threadSummaries[m.id] != null ||
        taskProjection.presentFor(m) != null;
    if (standalone(previous) || standalone(message)) return false;
    return previous.string('senderType') == message.string('senderType') &&
        previous.string('senderId') == message.string('senderId');
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
    double width,
  ) {
    if (index < 0 || index >= list.length) return 96;
    final message = list[index];
    final measured = measuredRows[message.id];
    if (measured != null && (measured.$1 - width).abs() < 1) return measured.$2;
    // Projected model getters create a fresh Map view on each access. Reuse
    // the canonical row metadata for width-independent extent preparation.
    final metadata = sources[message]?.json ?? message.metadata;
    return raftRowExtents.guess(message.id, metadata, width);
  }

  Widget tile(
    RaftMessage m, {
    bool parent = false,
    bool captureFocus = true,
    bool continuation = false,
    bool nextContinuation = false,
  }) {
    final selectable = selection.active && m.string('messageType') != 'system';
    final checked = selectable && selection.ids.contains(m.id);
    // Web MessageMultiSelectCheckbox: circle, size lg, primary variant, in the
    // row's flex line before the avatar (the row owns `mt-1.5` and the gap).
    final body = messageTile(
      m,
      parent: parent,
      continuation: continuation,
      nextContinuation: nextContinuation,
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
            (m.id == _messages.state.highlightedMessageId ||
                m.id == scrolledHighlight ||
                m.id == searchActive)
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
    final loading = widget.thread
        ? _messages.state.threadLoading
        : _messages.state.channelLoading;
    final empty = rows.isEmpty;
    const recipe = RaftTimelineCompositionRecipe();
    final List<Widget> header;
    if (widget.thread) {
      header = [
        threadTopSliver(loading: loading, showSummary: loading || !empty),
        if (!loading && empty)
          RaftTimelineSparseFill(
            // Every reply sits behind the plan cutoff: the thread is hidden,
            // not empty (Web shows the banner instead of "No replies yet").
            child: _messages.state.threadHistoryLimited
                ? Center(child: historyLimitBanner(inset: true))
                : RaftProductEmptyState(
                    title: raftText(context, 'No replies yet'),
                    icon: (context, size, color) =>
                        RaftThreadIcon(size: size, color: color),
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
            child: empty && _messages.contextLoadError == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: recipe.channelHeaderInset,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ?contextLoadBanner(),
                        if (!empty)
                          !_messages.state.hasMore &&
                                  _messages.state.historyLimited
                              ? historyLimitBanner()
                              : RaftThreadHistoryTopState(
                                  hasMore: _messages.state.hasMore,
                                  historyLimited:
                                      _messages.state.historyLimited,
                                  loadingOlder: _messages.state.loadingOlder,
                                  loadingOlderLabel: raftText(
                                    context,
                                    'Loading older messages...',
                                  ),
                                  historyLimitedLabel: raftText(
                                    context,
                                    'Older messages are limited by the current plan',
                                  ),
                                  beginningLabel: raftText(
                                    context,
                                    'Beginning of messages',
                                  ),
                                ),
                      ],
                    ),
                  ),
          ),
        ),
      ];
    }
    // The list depends on the pane's width only. The keyboard animation, the
    // composer growing and a banner appearing change its height on every
    // frame, and `LayoutBuilder` re-runs for any constraint change: handing
    // back the same widget lets the framework skip the rebuild of the whole
    // timeline and its visible rows (new widgets would re-create the sliver
    // delegates). The cache lives for this call's captured state only.
    Widget? timelineWidget;
    double? timelineWidth;
    Widget timelineFor(double width, Widget Function() create) {
      if (timelineWidget != null && timelineWidth == width) {
        return timelineWidget!;
      }
      timelineWidth = width;
      return timelineWidget = create();
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
        chatAnimatedListBuilder: (context, _) => LayoutBuilder(
          builder: (context, constraints) => timelineFor(
            constraints.maxWidth,
            () => RaftMessageTimeline(
              key: ValueKey(
                'chat-list-${widget.thread ? 'thread' : 'channel'}',
              ),
              controller: viewport,
              canPrepareNearbyRows:
                  kDebugMode || defaultTargetPlatform != TargetPlatform.macOS
                  ? null
                  : () => presentationActive && RaftFontWarmUp.isIdle,
              messages: messages,
              centerIndex: centerIndex(),
              epoch: centerEpoch,
              indexOfId: windowIndexOf,
              rowBuilder: (context, index) => HistoryGapPlaceholder(
                controller: w,
                thread: widget.thread,
                newerId: source(messages[index]).id,
                child: datedTile(source(messages[index])),
              ),
              estimateRow: (index) => estimateRow(
                measuredRows,
                messages,
                index,
                constraints.maxWidth,
              ),
              slivers: (history, forward) => recipe.centeredSlivers(
                header: header,
                history: history,
                forward: forward,
                footer: const RaftTimelineFooter(),
              ),
              hasOlder: widget.thread
                  ? w.threadHasMore
                  : _messages.state.hasMore,
              loadingOlder: _messages.state.loadingOlder,
              onLoadOlder: presentationActive
                  ? () => _messages.older(thread: widget.thread)
                  : null,
              hasNewer: widget.thread
                  ? _messages.threadWindow?.hasNewer == true
                  : _messages.state.hasNewer,
              onLoadNewer: presentationActive
                  ? () => _messages.newer(thread: widget.thread)
                  : null,
              onRecenter: (index, alignment) =>
                  recenter(first: messages[index].id, alignment: alignment),
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
                      detail: raftText(
                        context,
                        'Send a message to this channel.',
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// A long expanded task history stays scrollable while replies resolve;
  /// the fixed task bar and composer stay outside this viewport.
  Widget taskLoadingBody(Widget body) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: widget.threadParentSlot),
      SliverFillRemaining(hasScrollBody: false, child: body),
    ],
  );

  @override
  Widget buildLive(BuildContext context) {
    bindAgentCollapse(this, w, scope);
    final search = boundSearch;
    if (!widget.thread || search == null) return buildView(context);
    final apple =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return CallbackShortcuts(
      // Web ThreadPanel: Cmd/Ctrl+F opens the thread search while the thread
      // surface has focus.
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyF, control: !apple, meta: apple):
            search.open,
      },
      child: buildView(context),
    );
  }

  Widget buildView(BuildContext context) {
    scheduleBodyPreparation(context);
    if (widget.thread &&
        w.threadChannelId == null &&
        (_messages.threadResolutionLoading ||
            _messages.threadResolutionError != null)) {
      final body = RaftThreadResolutionBody(
        loadingLabel: raftText(context, 'Loading...'),
        errorTitle: _messages.threadResolutionError == null
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
    final currentTimeline = widget.thread && _messages.state.threadLoading
        ? widget.threadParentSlot == null
              ? loadingBody
              : taskLoadingBody(loadingBody)
        : buildTimeline();
    final historyWindow = widget.thread
        ? _messages.threadWindow?.hasNewer == true
        : _messages.state.hasNewer;
    final bottomCount = historyWindow
        ? (w.unread[w.channel?.id] ?? 0)
        : newMessageCount;
    final thread = widget.thread;
    final composeScope = w.draftScope(thread: thread),
        composeAuthority = workspaceAuthority(w);
    var composeWindow = thread
        ? _messages.threadGeneration
        : _messages.channelGeneration;
    bool currentComposer() =>
        mounted &&
        composeScope == w.draftScope(thread: thread) &&
        composeAuthority == workspaceAuthority(w) &&
        composeWindow ==
            (thread ? _messages.threadGeneration : _messages.channelGeneration);
    final onlyOne = raftFormat(context, '[{count} attachment]', {'count': 1});
    final manyBody = raftText(context, '[{count} attachments]');
    String attachmentsOnlyBody(int count) =>
        count == 1 ? onlyOne : manyBody.replaceAll('{count}', '$count');
    Future<bool> sendCurrent(
      String text,
      List<Map<String, dynamic>> mentions, {
      bool forceTask = false,
    }) async {
      if (!presentationActive || !currentComposer()) return false;
      final submittedTask = !thread && (alsoCreateTask || forceTask);
      final submittedTaskRevision = taskChoiceRevision;
      final accepted = await w.send(
        text,
        thread: thread,
        mentions: mentions,
        asTask: submittedTask,
        attachmentsOnlyBody: attachmentsOnlyBody,
        onWindowRefreshed: (window) {
          if (mounted &&
              composeScope == w.draftScope(thread: thread) &&
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
      return accepted;
    }

    if (!thread && w.channel == null) {
      return RaftEmptyState(
        title: raftText(context, 'Welcome to Raft'),
        detail: raftText(
          context,
          'Choose a channel or direct message to start.',
        ),
      );
    }
    final (channelFooter, channelGraceBanner) = thread
        ? (threadFooterWidget(), null)
        : channelFooterWidgets();
    // Rows read breakpoint bands, not the raw window width, so a resize
    // within a band does not rebuild every mounted message.
    final search = boundSearch;
    return RaftViewportBreakpointScope(
      child: Column(
        children: [
          RaftToastPortal(controller: selectionToast),
          if (thread && search != null && search.isOpen)
            RaftThreadSearchBar(
              controller: searchInput,
              focusNode: searchFocus,
              countLabel: search.countLabel(raftText(context, 'Loading')),
              canStep: search.matches.isNotEmpty,
              onChanged: search.setQuery,
              onStep: search.step,
              onClose: search.close,
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                KeyedSubtree(
                  key: const ValueKey('current-timeline'),
                  child: currentTimeline,
                ),
                MessageHistoryGapMonitor(controller: w, thread: widget.thread),
                if (historyWindow || !atBottom || newMessageCount > 0)
                  RaftTimelineBottomButton(
                    label: bottomCount > 0
                        ? raftFormat(
                            context,
                            // ThreadPanel.tsx:2619 uses its own shorter copy.
                            thread ? '{count} new' : '{count} new messages',
                            {'count': bottomCount},
                          )
                        : raftText(context, 'Back to bottom'),
                    onPressed: returnToBottom,
                  ),
              ],
            ),
          ),
          ?channelGraceBanner,
          if (selection.active)
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape):
                    selection.exit,
              },
              child: Focus(autofocus: true, child: selectionToolbar()),
            )
          else if (channelFooter != null)
            channelFooter
          else
            ComposerSlot(
              controller: w,
              thread: thread,
              builder: (context) => RaftComposer(
                // Web MessageInput drag-and-drop, paste and keyboard images.
                frame: (_, composer, enabled) => ComposerFileDropTarget(
                  controller: w,
                  thread: thread,
                  active: () =>
                      enabled && presentationActive && currentComposer(),
                  child: composer,
                ),
                onPasteAttachments: () => pasteComposerAttachments(
                  context,
                  w,
                  thread: thread,
                  active: () => presentationActive && currentComposer(),
                ),
                onContentInserted: (content) => insertComposerContent(
                  context,
                  w,
                  content,
                  thread: thread,
                  active: () => presentationActive && currentComposer(),
                ),
                clearOnSubmit: true,
                accessoryRow: composerAccessory(),
                autofocus:
                    thread &&
                    RaftDensityScope.of(context) == RaftDensity.desktop,
                canAutofocus: () =>
                    presentationActive &&
                    currentComposer() &&
                    w.client.user != null &&
                    w.can('viewChannel', resource: w.channel),
                handle: composerHandle,
                initialDraft: w.drafts[w.draftScope(thread: thread)] ?? '',
                draftRevision: w.draftRevision(thread: thread),
                onDraftChanged: (text) {
                  if (currentComposer()) w.saveDraft(text, thread: thread);
                },
                key: ValueKey(
                  'compose-${thread ? _messages.threadParentMessageId : w.channel?.id}',
                ),
                taskAction: !thread && w.channel?.type != 'thread'
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
                    attach(mediaOnly: true);
                  }
                },
                hasAttachments: w.uploads(thread: thread).isNotEmpty,
                attachments: composerAttachmentsFor(
                  context,
                  w,
                  thread: thread,
                  onPreview: previewDraftImage,
                ),
                submitSpinner: w
                    .uploads(thread: thread)
                    .any(
                      (d) =>
                          d.checking ||
                          (d.error == null && d.id == null && !d.queued),
                    ),
                // Web MessageInput `conversionBlocked`: the composer stays and
                // Send is disabled with the conversion notice as its title.
                submitTooltip: w.conversationPaused
                    ? raftText(context, 'Channel conversion in progress')
                    : composerSendBlockTitle(
                        context,
                        w.uploads(thread: thread),
                      ),
                onSendBlocked: w.conversationPaused
                    ? null
                    : () => raiseComposerSendBlockNotice(
                        context,
                        w,
                        thread: thread,
                      ),
                hint: thread
                    ? raftText(context, 'Message thread')
                    : w.channel?.type == 'dm'
                    // Web ChatPanel: a DM composer reads `Message @<peer>`.
                    ? raftFormat(context, 'Message @{name}', {
                        'name': w.channel!.string(
                          'peerDisplayName',
                          w.channel!.string('peerName', w.channel!.name),
                        ),
                      })
                    : raftFormat(context, 'Message #{name}', {
                        'name': w.channel?.name ?? '',
                      }),
                enabled:
                    presentationActive &&
                    (thread
                        ? _messages.threadParentMessageId != null &&
                              _messages.threadSourceChannel?.archived != true &&
                              _messages.threadSourceChannel?.joined == true
                        : w.channel?.archived != true),
                canSend:
                    !w.conversationPaused &&
                    !w.sharedBlocked(thread: thread) &&
                    w.uploadsReady(thread: thread),
                suggestions: composerDirectory.suggestions,
                onSuggestionsRequested: (prefix) {
                  if (presentationActive && currentComposer()) {
                    composerDirectory.request(prefix);
                  }
                },
                onForceTaskSendWithMentions: !thread
                    ? (text, mentions) =>
                          sendCurrent(text, mentions, forceTask: true)
                    : null,
                onSendWithMentions: sendCurrent,
                onSend: (text) => sendCurrent(text, const []),
              ),
            ),
        ],
      ),
    );
  }
}
