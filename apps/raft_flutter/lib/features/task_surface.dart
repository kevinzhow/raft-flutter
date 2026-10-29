import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/source_time_formatter.dart';
import '../data/workspace_entity_directory.dart';
import 'chat_view.dart';
import 'task_surface_controller.dart';

/// App adapter: the shared task surface receives facts and callbacks, never
/// session or API ownership. The borrowed discussion has its own identity.
class SourceTaskSurface extends StatefulWidget {
  const SourceTaskSurface({
    super.key,
    required this.owner,
    required this.onClose,
    required this.onTask,
    required this.onViewBilling,
    this.onCleanupDelete,
    this.onBack,
    this.onViewInThread,
    this.legacyPresentation = RaftLegacyTaskPresentation.modal,
    this.page = false,
  });
  final TaskSurfaceController owner;
  final VoidCallback onClose;

  /// Opens another task from an in-body `#N` reference of the discussion (Web
  /// swaps the modal's task); null when the host has no task slot.
  final ChatTaskOpener? onTask;

  /// The discussion's plan banner "View Billing" link; null hides it.
  final VoidCallback? onViewBilling;
  final VoidCallback? onCleanupDelete;
  final VoidCallback? onBack;

  /// "View in thread" of the task bar; null when the task has no thread.
  final VoidCallback? onViewInThread;
  final RaftLegacyTaskPresentation legacyPresentation;
  final bool page;
  @override
  State<SourceTaskSurface> createState() => _SourceTaskSurfaceState();
}

class _SourceTaskSurfaceState extends State<SourceTaskSurface> {
  TaskSurfaceController get o => widget.owner;
  @override
  void initState() {
    super.initState();
    o.parent.foregroundChanges.addListener(presentationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => presentationChanged());
  }

  void presentationChanged() {
    if (!mounted || !o.current) return;
    final c = o.discussion;
    c?.setConversationPresentation(
      o.presentationOwner,
      main: false,
      thread: true,
    );
    c?.setForeground(o.parent.foreground);
  }

  @override
  void dispose() {
    o.parent.foregroundChanges.removeListener(presentationChanged);
    // Route removal may complete the owner's Future before widget disposal.
    // The owner has already retired/disposed its borrowed controller then.
    if (o.current) {
      final c = o.discussion;
      c?.setForeground(false);
      c?.setConversationPresentation(
        o.presentationOwner,
        main: false,
        thread: false,
      );
    }
    super.dispose();
  }

  /// Web TaskProperties resolves creator/assignee display names from the
  /// channel members; the workspace directory carries the same names.
  String? displayName(String type, String id) {
    final directory = o.parent.services.entityDirectory;
    final row = type == 'agent'
        ? directory
              .rows(WorkspaceEntityKind.agents)
              .where((r) => r['id'] == id)
              .firstOrNull
        : directory.member(id);
    final name = row?['displayName'] ?? row?['name'];
    return name is String && name.isNotEmpty ? name : null;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: o,
    builder: (context, _) {
      if (o.parentReady &&
          o.hydrated &&
          o.error is RaftApiException &&
          (o.error as RaftApiException).status == 404) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && o.current) widget.onClose();
        });
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => presentationChanged(),
      );
      final user = o.parent.client.user;
      final formatter = SourceTimeFormatter(
        locale: Localizations.localeOf(context).toLanguageTag(),
        preferredTimezone:
            user?.string('preferredTimezone') ?? user?.string('timezone'),
        preferredTimeFormat: sourceTimeFormatPreference(
          user?.string('preferredTimeFormat') ?? user?.string('timeFormat'),
        ),
        systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
            ? SourceTimeFormat.twentyFourHour
            : null,
      );
      return RaftTaskSurface(
        page: widget.page,
        task: o.task,
        history: o.history,
        assignees: o.assignees,
        legacy: o.legacy,
        legacyPresentation: widget.legacyPresentation,
        displayNameFor: displayName,
        loading: o.loading,
        historyLoading: o.historyLoading,
        busy: o.busy,
        canStatus: o.canStatus,
        canAssign: o.canAssign,
        canCleanupDelete: o.canCleanupDelete,
        statusOptions: o.statusOptions,
        error: o.error,
        historyError: o.historyError,
        onClose: widget.onClose,
        onBack: widget.onBack,
        onViewInThread: widget.onViewInThread,
        onRetry: o.parentReady ? o.refresh : o.start,
        onLoadAssignees: o.loadAssignees,
        onUpdate: o.update,
        onCleanupDelete: widget.onCleanupDelete,
        formatTime: (value) => value == null
            ? raftText(context, 'Unknown')
            : formatter.shortDateTime(value),
        unresolvedBody: o.parentReady && o.hydrated || o.legacy
            ? null
            : o.discussion == null
            ? RaftThreadResolutionBody(
                loadingLabel: raftText(context, 'Loading thread…'),
                errorTitle: o.parentError == null && o.error == null
                    ? null
                    : raftText(context, "Couldn't load this thread"),
                errorBody: raftText(
                  context,
                  "The thread couldn't be opened. If this channel recently became public, try again.",
                ),
                retryLabel: raftText(context, 'Retry'),
                onRetry: o.parentRemoved ? null : o.start,
              )
            : RaftChatView(
                controller: o.discussion!,
                thread: true,
                onTask: widget.onTask,
                onViewBilling: widget.onViewBilling,
              ),
        discussionBuilder: o.discussion == null
            ? null
            : (head) => RaftChatView(
                controller: o.discussion!,
                thread: true,
                hideThreadParent: true,
                threadParentSlot: head,
                onTask: widget.onTask,
                onViewBilling: widget.onViewBilling,
              ),
      );
    },
  );
}
