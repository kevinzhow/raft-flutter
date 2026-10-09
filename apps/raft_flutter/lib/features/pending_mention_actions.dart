// Web MessageInput.tsx pending-mention handling: after a send whose receipt
// carries `pendingMentionActions`, the composer shows
// PendingMentionActionStrip; Add / Notify call
// `POST /messages/mention-actions/execute`, a success marks the row
// (Added / Queued), fades it at 450ms and removes it at 750ms; Ignore removes
// it immediately.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'public_avatar_url.dart';

class PendingMentionActions extends StatefulWidget {
  const PendingMentionActions({
    super.key,
    required this.controller,
    this.thread = false,
  });
  final WorkspaceController controller;
  final bool thread;
  @override
  State<PendingMentionActions> createState() => _PendingMentionActionsState();
}

class _PendingMentionActionsState extends State<PendingMentionActions> {
  WorkspaceController get w => widget.controller;
  final state = <String, RaftPendingMentionState>{};
  final executing = <String, RaftPendingMentionState>{};
  final removing = <String>{};
  final timers = <String, List<Timer>>{};
  String? notice;

  @override
  void dispose() {
    for (final list in timers.values) {
      for (final timer in list) {
        timer.cancel();
      }
    }
    super.dispose();
  }

  void clearLocal(String id) {
    for (final timer in timers.remove(id) ?? const <Timer>[]) {
      timer.cancel();
    }
    state.remove(id);
    executing.remove(id);
    removing.remove(id);
  }

  void remove(String id) {
    clearLocal(id);
    w.dismissPendingMention(id, thread: widget.thread);
  }

  void scheduleRemoval(String id, RaftPendingMentionState outcome) {
    for (final timer in timers.remove(id) ?? const <Timer>[]) {
      timer.cancel();
    }
    setState(() => state[id] = outcome);
    timers[id] = [
      Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => removing.add(id));
      }),
      Timer(const Duration(milliseconds: 750), () {
        if (mounted) remove(id);
      }),
    ];
  }

  Future<void> mark(List<String> ids, RaftPendingMentionState outcome) async {
    setState(() {
      notice = null;
      for (final id in ids) {
        executing[id] = outcome;
      }
    });
    try {
      final ok = await w.executeMentionActions(
        outcome == RaftPendingMentionState.added ? 'add' : 'notify',
        ids,
      );
      if (!mounted) return;
      for (final id in ids.where(ok.contains)) {
        scheduleRemoval(id, outcome);
      }
      if (ok.length < ids.length) {
        setState(
          () => notice = raftText(context, 'Mention action failed. Try again.'),
        );
      }
    } catch (e) {
      if (mounted) setState(() => notice = '$e');
    } finally {
      if (mounted) {
        setState(() {
          for (final id in ids) {
            executing.remove(id);
          }
        });
      }
    }
  }

  Widget? avatar(Map<String, dynamic> row) {
    final url = row['targetAvatarUrl'];
    final type = row['targetType'];
    if ((type != 'agent' && type != 'user') || url is! String || url.isEmpty) {
      return null;
    }
    final pixel = url.startsWith('pixel:') ? url.substring(6) : null;
    final agent = type == 'agent';
    return RaftAvatar(
      name: '${row['targetHandle']}',
      size: 20,
      kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
      mountedContext: RaftMountedAvatarContext.compactList,
      content: RaftAvatarContent(
        name: '${row['targetHandle']}',
        kind: agent ? RaftAvatarContentKind.agent : RaftAvatarContentKind.human,
        pixelKey: pixel,
        uploadedUrl: pixel == null
            ? raftPublicAvatarUrl(w.client.origin, url)
            : null,
        fallback: RaftMountedAvatarFallback(
          avatarContext: RaftMountedAvatarContext.compactList,
          identity: agent
              ? RaftMountedAvatarIdentity.agent
              : RaftMountedAvatarIdentity.human,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: w,
    builder: (context, _) {
      final rows = w.pendingMentionsFor(thread: widget.thread);
      if (rows.isEmpty) return const SizedBox.shrink();
      final actions = [
        for (final row in rows)
          RaftPendingMention(
            resolutionId: row['resolutionId'] as String,
            targetType: row['targetType'] as String,
            targetHandle: '${row['targetHandle'] ?? ''}',
            availableActions: [
              for (final a in row['availableActions'] as List) '$a',
            ],
            avatar: avatar(row),
          ),
      ];
      return RaftPendingMentionSlot(
        notice: notice,
        strip: RaftPendingMentionActionStrip(
          actions: actions,
          channelName: w.channel?.name ?? '',
          state: state,
          executing: executing,
          removing: removing,
          onMark: (id, outcome) => mark([id], outcome),
          onAddAll: (ids) => mark(ids, RaftPendingMentionState.added),
          onDismiss: (id) => setState(() => remove(id)),
        ),
      );
    },
  );
}

/// MessageInput slots above the composer card, in Web order: the error
/// `Banner`, then the PendingMentionActionStrip.
Widget? raftComposerAccessory(WorkspaceController w, {bool thread = false}) {
  final error = w.composerErrorFor(thread: thread);
  final mentions = w.pendingMentionsFor(thread: thread).isNotEmpty;
  if (error == null && !mentions) return null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (error != null) RaftComposerNotice(message: error),
      if (error != null && mentions) const RaftComposerGap(),
      if (mentions) PendingMentionActions(controller: w, thread: thread),
    ],
  );
}
