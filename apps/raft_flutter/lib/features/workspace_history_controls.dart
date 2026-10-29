import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';

/// Visits an observed entry without appending another history entry. Only the
/// bound workspace owns these entries; late popup actions cannot cross epochs.
Future<void> visitWorkspaceHistory(
  WorkspaceController w,
  int index, {
  required String authority,
  required Uri expectedUri,
}) async {
  final history = w.navigation;
  if (w.navigationAuthority != authority ||
      index < 0 ||
      index >= history.entries.length ||
      history.entries[index].uri != expectedUri) {
    return;
  }
  final previous = w.location;
  while (history.index > index) {
    history.back();
  }
  while (history.index < index) {
    if (!history.forward()) return;
  }
  final next = w.location;
  if (next.thread == null) w.closeThread(navigate: false);
  w.notifyListeners();
  if ({RaftRoute.channel, RaftRoute.dm}.contains(next.route)) {
    if (w.channel?.id != next.entityId ||
        next.messageId != previous.messageId) {
      // A thread permalink's msg belongs to the reply window. Restore the
      // channel's accepted window, then hydrate the independent thread below.
      await w.jumpToMessage(
        next.entityId!,
        next.thread == null ? next.messageId : null,
        navigate: false,
      );
    }
    if (w.navigationAuthority != authority || w.location.uri != next.uri) {
      return;
    }
    final thread = next.thread;
    if (thread != null) {
      await w.openThreadIdentity(
        parentChannelId: thread.channelId,
        parentMessageId: thread.itemId,
        focusedMessageId: next.threadFocusedMessageId,
        navigate: false,
      );
    }
  }
}

String _historyLabel(
  BuildContext context,
  WorkspaceController w,
  RaftLocation entry,
) {
  final channel = w.channels.where((c) => c.id == entry.entityId).firstOrNull;
  final name = channel?.name;
  if ((entry.route == RaftRoute.channel || entry.route == RaftRoute.dm) &&
      name != null) {
    return entry.route == RaftRoute.channel ? '#$name' : name;
  }
  final label = switch (entry.route) {
    RaftRoute.home => 'Home',
    RaftRoute.channel || RaftRoute.dm => 'Chat',
    RaftRoute.agent => 'Agent',
    RaftRoute.human => 'Member',
    RaftRoute.computer => 'Computer',
    RaftRoute.members => 'Members',
    RaftRoute.memberGraph => 'Member Graph',
    RaftRoute.computers => 'Computers',
    RaftRoute.search => 'Search',
    RaftRoute.settings => 'Settings',
    RaftRoute.activity => 'Activity',
    RaftRoute.tasks => 'Tasks',
    RaftRoute.saved => 'Saved',
    RaftRoute.releaseNotes => 'Release Notes',
    RaftRoute.unknown => 'Home',
  };
  return raftText(context, label);
}

/// Desktop history shares the same accepted locations as phone Back and deep
/// links. Narrow desktop rows put Back/Forward in the history menu.
class WorkspaceHistoryControls extends StatelessWidget {
  const WorkspaceHistoryControls({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final w = controller, history = w.navigation;
    final entries = history.entries;
    final authority = w.navigationAuthority;
    final compact = MediaQuery.sizeOf(context).width < 1000;
    VoidCallback? visit(int index) => index < 0 || index >= entries.length
        ? null
        : () => unawaited(
            visitWorkspaceHistory(
              w,
              index,
              authority: authority,
              expectedUri: entries[index].uri,
            ),
          );
    final back = visit(history.index - 1), forward = visit(history.index + 1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) ...[
          RaftIconButton(
            key: const Key('topbar-back'),
            uiVariant: RaftButtonVariant.onFrame,
            glyph: RaftGlyph.arrowLeft,
            tooltip: 'Go back',
            semanticLabel: raftText(context, 'Go back'),
            onPressed: back,
          ),
          RaftIconButton(
            key: const Key('topbar-forward'),
            uiVariant: RaftButtonVariant.onFrame,
            glyph: RaftGlyph.arrowRight,
            tooltip: 'Go forward',
            semanticLabel: raftText(context, 'Go forward'),
            onPressed: forward,
          ),
        ],
        RaftDropdownMenu(
          key: ValueKey('topbar-history-$authority'),
          label: raftText(context, 'History'),
          tooltip: 'History',
          width: 280,
          triggerBuilder: (context, focus, open) => Focus(
            focusNode: focus,
            child: RaftIconButton(
              key: const Key('topbar-history'),
              uiVariant: RaftButtonVariant.onFrame,
              glyph: RaftGlyph.clock,
              tooltip: 'History',
              semanticLabel: raftText(context, 'History'),
              onPressed: open,
            ),
          ),
          entries: [
            if (compact) ...[
              RaftMenuEntry(
                label: raftText(context, 'Go back'),
                glyph: RaftGlyph.arrowLeft,
                onPressed: back,
              ),
              RaftMenuEntry(
                label: raftText(context, 'Go forward'),
                glyph: RaftGlyph.arrowRight,
                onPressed: forward,
              ),
              const RaftMenuEntry.separator(),
            ],
            for (
              var i = entries.length - 1;
              i >= (entries.length - 30).clamp(0, entries.length);
              i--
            )
              RaftMenuEntry(
                label: _historyLabel(context, w, entries[i]),
                glyph: i == history.index ? RaftGlyph.check : null,
                onPressed: i == history.index ? null : visit(i),
              ),
          ],
        ),
      ],
    );
  }
}
