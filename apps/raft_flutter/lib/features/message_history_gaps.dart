import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/history_gap_recovery.dart';
import '../data/workspace_controller.dart';

/// Owns automatic checks only while this chat presentation is mounted.
class MessageHistoryGapMonitor extends StatefulWidget {
  const MessageHistoryGapMonitor({
    super.key,
    required this.controller,
    this.thread = false,
  });
  final WorkspaceController controller;
  final bool thread;
  @override
  State<MessageHistoryGapMonitor> createState() =>
      _MessageHistoryGapMonitorState();
}

class _MessageHistoryGapMonitorState extends State<MessageHistoryGapMonitor> {
  late HistoryGapRecovery recovery;
  void attach() {
    recovery = HistoryGapRecovery.of(widget.controller, widget.thread);
    recovery.start(this);
  }

  @override
  void initState() {
    super.initState();
    attach();
  }

  @override
  void didUpdateWidget(MessageHistoryGapMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.thread != widget.thread) {
      recovery.stop(this);
      attach();
    }
  }

  @override
  void dispose() {
    recovery.stop(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Anchors status at the missing interval, immediately before its newer row.
class HistoryGapPlaceholder extends StatelessWidget {
  const HistoryGapPlaceholder({
    super.key,
    required this.controller,
    required this.newerId,
    required this.child,
    this.thread = false,
  });
  final WorkspaceController controller;
  final String newerId;
  final Widget child;
  final bool thread;
  @override
  Widget build(BuildContext context) {
    final recovery = HistoryGapRecovery.of(controller, thread);
    return ListenableBuilder(
      listenable: recovery,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recovery.contains(newerId))
            HistoryGapNotice(
              key: ValueKey('history-gap-placeholder-$newerId'),
              failed: recovery.failed(newerId),
              offline: !controller.connected,
              error: recovery.error(newerId),
              onRetry: () => recovery.retry(newerId),
            ),
          child,
        ],
      ),
    );
  }
}

/// Quiet loading at the missing interval; only actionable errors have copy.
class HistoryGapNotice extends StatelessWidget {
  const HistoryGapNotice({
    super.key,
    this.failed = false,
    this.offline = false,
    this.error,
    this.onRetry,
  });
  final bool failed, offline;
  final String? error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    if (offline) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: RaftSpace.x4),
      );
    }
    if (!failed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: RaftSpace.x2),
        child: Center(child: RaftSpinner(size: 16)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x4,
        vertical: RaftSpace.x2,
      ),
      child: Semantics(
        liveRegion: true,
        child: Wrap(
          spacing: RaftSpace.x2,
          runSpacing: RaftSpace.x2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              raftText(context, error ?? 'Unable to load messages.'),
              style: RaftSettingsText(RaftTokens.of(context)).description,
            ),
            RaftRecipeButton(
              onPressed: onRetry,
              child: Text(raftText(context, 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
