import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/source_time_formatter.dart';
import 'chat_view.dart';
import 'task_surface_controller.dart';

/// App adapter: the shared task surface receives facts and callbacks, never
/// session or API ownership. The borrowed discussion has its own identity.
class SourceTaskSurface extends StatefulWidget {
  const SourceTaskSurface({
    super.key,
    required this.owner,
    required this.onClose,
    this.onCleanupDelete,
    this.onBack,
  });
  final TaskSurfaceController owner;
  final VoidCallback onClose;
  final VoidCallback? onCleanupDelete;
  final VoidCallback? onBack;
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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: o,
    builder: (context, _) {
      if (o.hydrated &&
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
        task: o.task,
        history: o.history,
        assignees: o.assignees,
        legacy: o.legacy,
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
        onRetry: o.refresh,
        onLoadAssignees: o.loadAssignees,
        onUpdate: o.update,
        onCleanupDelete: widget.onCleanupDelete,
        formatTime: (value) => value == null
            ? raftText(context, 'Unknown')
            : formatter.shortDateTime(value),
        unresolvedBody: o.hydrated || o.legacy
            ? null
            : o.discussion == null
            ? RaftThreadResolutionBody(
                loadingLabel: raftText(context, 'Loading...'),
                errorTitle: o.error == null ? null : '${o.error}',
                retryLabel: raftText(context, 'Retry'),
                onRetry: o.start,
              )
            : RaftChatView(controller: o.discussion!, thread: true),
        discussionBuilder: o.discussion == null
            ? null
            : (head) => RaftChatView(
                controller: o.discussion!,
                thread: true,
                hideThreadParent: true,
                threadParentSlot: head,
              ),
      );
    },
  );
}
