// Web MessageInput.tsx pending-mention handling: after a send whose receipt
// carries `pendingMentionActions`, the composer shows
// PendingMentionActionStrip; Add / Notify call
// `POST /messages/mention-actions/execute`, a success marks the row
// (Added / Queued), fades it at 450ms and removes it at 750ms; Ignore removes
// it immediately.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'composer_attachments_view.dart';
import 'public_avatar_url.dart';
import 'recoverable_uploads_banner.dart';

/// Web `formatMentionActionStatusNotice`: why a mention action did not apply.
String mentionActionStatusNotice(BuildContext context, Map? result) {
  final status = result?['status'], reason = result?['reason'];
  final text = switch (status) {
    _ when result == null => 'This mention action is no longer available.',
    'dropped' =>
      reason == 'delivery_unavailable'
          ? 'Notification was not delivered because delivery is temporarily unavailable. Try again.'
          : 'That target was not notified right now. Try again.',
    'no_permission' => switch (reason) {
      'sender_lacks_channel_access' => 'You no longer have access to that channel, so this mention action was not applied.',
      'target_lacks_read_access' =>
        'That person cannot read this conversation, so they were not notified.',
      'add_not_allowed_for_surface' => 'That person cannot be added from this mention action. Use the channel member controls instead.',
      'add_requires_human_member_authority' => 'Agents cannot add channel members from mention actions. Ask a human member to add them.',
      'add_requires_member_management_authority' =>
        'Only channel admins can add members from this mention action.',
      _ =>
        'This mention action is not available for the current channel state.',
    },
    'stale' => switch (reason) {
      'target_already_member' =>
        'That target is already in the channel, so no action is needed.',
      'target_unavailable' => 'That target is no longer available.',
      _ => 'This mention action is no longer pending.',
    },
    'expired' => 'This mention action has expired.',
    'not_found' => 'This mention action is no longer available.',
    'ambiguous' => 'This mention action matched more than one target. Refresh and try again.',
    _ => 'This mention action could not be applied.',
  };
  return raftText(context, text);
}

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
  // Why the last action did not apply. Bound to the composer scope that
  // raised it and to the failed row (Web clears it on a new send, a channel
  // change and when a row is dismissed): a notice about a row that is gone, or
  // about another channel's composer, must not stay.
  late final CauseNotice notice = CauseNotice(
    scope: () => w.draftScope(thread: widget.thread),
  );

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
    // ignore: raft_lints/avoid_imperative_notice_state -- Clears the composer banner at the start of a mention action (mark) and when a row is dismissed (Web removePendingMentionAction).
    w.setComposerError(null, thread: widget.thread);
    setState(() {
      notice.clear();
      for (final id in ids) {
        executing[id] = outcome;
      }
    });
    final single = ids.length == 1;
    try {
      final action = outcome == RaftPendingMentionState.added
          ? 'add'
          : 'notify';
      final results = await w.executeMentionActionResults(action, ids);
      if (!mounted) return;
      final ok = [
        for (final id in ids)
          if (WorkspaceController.mentionActionSucceeded(action, results[id]))
            id,
      ];
      for (final id in ok) {
        scheduleRemoval(id, outcome);
      }
      if (ok.length < ids.length) {
        final failed = ids.firstWhere((id) => !ok.contains(id));
        final reason = mentionActionStatusNotice(context, results[failed]);
        // Web: a single row shows the reason alone; a batch add leads with
        // how many were added.
        final text = single
            ? reason
            : ok.isNotEmpty
            ? '${raftFormat(context, 'Added {succeeded} of {total}. ', {'succeeded': ok.length, 'total': ids.length})}$reason'
            : '${raftText(context, 'No people were added. ')}$reason';
        setState(
          () => notice.raise(
            text,
            whileTrue: () => w
                .pendingMentionsFor(thread: widget.thread)
                .any((row) => row['resolutionId'] == failed),
          ),
        );
      }
    } catch (e) {
      // Web: the server's text, else `failedMentionAction` / `mentionAddFailed`.
      if (mounted) {
        // ignore: raft_lints/avoid_imperative_notice_state -- Raises the server's text when the action request throws; the composer notice store ends it with the composer visit and the next mark/dismiss clears it.
        w.setComposerError(
          userErrorText(
            e,
            fallback: single
                ? 'Failed to execute mention action'
                : 'Failed to add mentioned people',
            where: 'mention action',
          ),
          thread: widget.thread,
        );
      }
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
        notice: notice.message,
        strip: RaftPendingMentionActionStrip(
          actions: actions,
          channelName: w.channel?.name ?? '',
          state: state,
          executing: executing,
          removing: removing,
          onMark: (id, outcome) => mark([id], outcome),
          onAddAll: (ids) => mark(ids, RaftPendingMentionState.added),
          onDismiss: (id) => setState(() {
            // Web removePendingMentionAction: dismissing clears the feedback.
            notice.clear();
            // ignore: raft_lints/avoid_imperative_notice_state -- Clears the composer banner at the start of a mention action (mark) and when a row is dismissed (Web removePendingMentionAction).
            w.setComposerError(null, thread: widget.thread);
            remove(id);
          }),
        ),
      );
    },
  );
}

/// MessageInput slots above the composer card, in Web order: the error
/// `Banner`, then the PendingMentionActionStrip.
Widget? raftComposerAccessory(
  BuildContext context,
  WorkspaceController w, {
  bool thread = false,
}) {
  final error = w.composerErrorFor(thread: thread);
  // Shared content added before its destination was re-checked: the check
  // refused it. The draft and files stay; Send is off (chat_view `canSend`).
  final shared = w.shareNoticeFor(thread: thread);
  // Web `billingUploadQuotaError`: the quota failure keeps its chip and
  // leaves the message in its own banner.
  final quota = w
      .uploads(thread: thread)
      .where((d) => isBillingUploadQuotaError(d.error))
      .map((d) => d.error!)
      .firstOrNull;
  final mentions = w.pendingMentionsFor(thread: thread).isNotEmpty;
  final recoverable = recoverableUploadsFor(context, w, thread: thread);
  // Web order: error, quota, delivery warning (DM), unresolved mentions
  // (channel), then the strip. Both warnings carry a dismiss X.
  final warnings = w.sendWarningsFor(thread: thread);
  final dm = !thread && w.channel?.type == 'dm';
  final stopped = dm && warnings.agentStopped;
  final unresolved = !dm && warnings.unresolved.isNotEmpty;
  if (error == null &&
      shared == null &&
      quota == null &&
      !stopped &&
      !unresolved &&
      !mentions &&
      recoverable == null) {
    return null;
  }
  final banners = <Widget>[
    if (shared != null)
      RaftComposerNotice(
        key: const Key('shared-destination-notice'),
        message: raftText(context, shared),
      ),
    if (error != null) RaftComposerNotice(message: error),
    if (quota != null) RaftComposerNotice(message: quota),
    if (stopped)
      RaftComposerNotice(
        message: raftText(
          context,
          'Message sent, but this agent is stopped and was not notified.',
        ),
        dismissLabel: raftText(context, 'Dismiss delivery warning'),
        onDismiss: () => w.dismissSendWarnings(thread: thread),
      ),
    if (unresolved)
      RaftComposerNotice(
        message: raftFormat(
          context,
          'Not notified: {handles}. Select a person or agent from the mention picker and try again if needed.',
          {'handles': warnings.unresolved.join(', ')},
        ),
        dismissLabel: raftText(context, 'Dismiss unnotified mention warning'),
        onDismiss: () => w.dismissSendWarnings(thread: thread),
      ),
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < banners.length; i++) ...[
        if (i > 0) const RaftComposerGap(),
        banners[i],
      ],
      if (banners.isNotEmpty && mentions) const RaftComposerGap(),
      if (mentions) PendingMentionActions(controller: w, thread: thread),
      if (recoverable != null) ...[
        if (banners.isNotEmpty || mentions) const RaftComposerGap(),
        recoverable,
      ],
    ],
  );
}
