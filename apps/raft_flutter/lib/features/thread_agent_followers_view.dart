import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/thread_agent_followers.dart';
import '../data/workspace_controller.dart';
import 'channel_form_fields.dart';
import 'agent_metadata_projection.dart';
import 'resource_cards.dart' show resourceRelativeTime;
import 'create_channel_dialog.dart' show ChannelMemberCandidate;

/// Web `followerAgentStatus`: the follower endpoint's transport-ish statuses
/// ("online") map onto the shared agent status union.
String followerAgentStatus(String? status) =>
    status == 'active' || status == 'online'
    ? 'active'
    : status == 'stopped'
    ? 'stopped'
    : 'inactive';

/// Web ThreadAgentFollowers (header variant) in the thread header: the
/// "N Agents following" trigger and the follower popover (remove with undo).
class ThreadAgentFollowersView extends StatefulWidget {
  const ThreadAgentFollowersView({
    super.key,
    required this.controller,
    required this.threadChannelId,
    this.onOpenAgent,
  });
  final WorkspaceController controller;
  final String threadChannelId;

  /// Opens the agent's profile (Web `openProfile("agent", id)`).
  final void Function(String agentId)? onOpenAgent;

  @override
  State<ThreadAgentFollowersView> createState() =>
      _ThreadAgentFollowersViewState();
}

class _ThreadAgentFollowersViewState extends State<ThreadAgentFollowersView> {
  WorkspaceController get w => widget.controller;
  late ThreadAgentFollowers store;
  final toast = RaftToastController();
  StreamSubscription<RaftEvent>? events;
  String? removingId;
  late Object _authority;
  Object get authority => (
    w.client,
    w.client.generation,
    w.client.user?.id,
    w.client.serverId,
    w.server?.id,
    w.server?.string('role'),
  );

  @override
  void initState() {
    super.initState();
    bind();
  }

  void bind() {
    store = w.services.threadFollowers;
    _authority = authority;
    store.addListener(changed);
    w.addListener(authorityChanged);
    events = w.client.events.listen(onEvent);
    store.request(widget.threadChannelId);
  }

  void unbind(WorkspaceController owner) {
    store.removeListener(changed);
    owner.removeListener(authorityChanged);
    unawaited(events?.cancel());
  }

  void authorityChanged() {
    if (authority == _authority) return;
    _authority = authority;
    toast.clear();
    removingId = null;
    store.request(widget.threadChannelId);
    changed();
  }

  @override
  void didUpdateWidget(covariant ThreadAgentFollowersView old) {
    super.didUpdateWidget(old);
    if (old.controller != w) {
      unbind(old.controller);
      bind();
    }
    if (old.controller != w || old.threadChannelId != widget.threadChannelId) {
      removingId = null;
      final scope = authority, thread = widget.threadChannelId;
      // The toast overlay is outside this subtree; retire it after this build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && current(scope, thread)) toast.clear();
      });
      store.request(widget.threadChannelId);
    }
  }

  @override
  void dispose() {
    unbind(w);
    toast.dispose();
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  void onEvent(RaftEvent event) {
    final payload = event.payload;
    // Web: `message:new` in this thread refreshes the roster.
    if (event.name == 'message:new' &&
        payload is Map &&
        payload['channelId'] == widget.threadChannelId) {
      store.request(widget.threadChannelId, force: true);
    }
  }

  Future<void> remove(ThreadAgentFollower agent) async {
    final id = widget.threadChannelId;
    final scope = authority;
    setState(() => removingId = agent.id);
    try {
      final token = await store.remove(id, agent.id);
      if (token == null || !mounted || !current(scope, id)) return;
      toast.show(
        raftFormat(context, "Removed {agent} from this thread's followers.", {
          'agent': agent.label,
        }),
        actionLabel: raftText(context, 'Undo'),
        onAction: () => unawaited(restore(id, agent, token, scope)),
      );
    } catch (_) {
      if (mounted && current(scope, id)) {
        toast.show(
          raftText(context, "Couldn't remove this follower."),
          tone: RaftToastRecipeTone.error,
        );
      }
    } finally {
      if (mounted && current(scope, id)) setState(() => removingId = null);
    }
  }

  bool current(Object scope, String thread) =>
      scope == authority && thread == widget.threadChannelId;

  Future<void> restore(
    String thread,
    ThreadAgentFollower agent,
    String token,
    Object scope,
  ) async {
    if (!mounted || !current(scope, thread)) return;
    final restored = await store.restore(thread, agent.id, token);
    if (restored && mounted && current(scope, thread)) {
      toast.show(
        raftFormat(context, 'Restored {agent} as a follower.', {
          'agent': agent.label,
        }),
      );
    }
  }

  Widget avatar(
    ThreadAgentFollower agent,
    RaftMountedAvatarContext context, {
    RaftAvatarPresence? presence,
  }) => ChannelCandidateAvatar(
    candidate: ChannelMemberCandidate(
      kind: 'agent',
      id: agent.id,
      name: agent.name,
      displayName: agent.displayName,
      avatarUrl: agent.avatarUrl,
    ),
    avatarContext: context,
    origin: w.client.origin,
    presence: presence,
  );

  /// Web `AgentActivityInfo`: `formatAgentDisplayStateText` of the agent's
  /// display state (live directory row, else the follower's status).
  (RaftAvatarPresence, String) activity(ThreadAgentFollower agent) {
    final live = w.services.entityDirectory.agent(agent.id);
    final status = followerAgentStatus(agent.status);
    final display = live != null
        ? agentRowAmbientDisplay(live)
        : resolveAgentAmbientDisplay(
            identity: AgentPresentationIdentity(id: agent.id, status: status),
            now: DateTime.now(),
          );
    final presence = RaftAvatarPresence(
      activity: switch (display.activity) {
        'thinking' => RaftAvatarActivity.thinking,
        'working' => RaftAvatarActivity.working,
        'error' => RaftAvatarActivity.error,
        'offline' => RaftAvatarActivity.offline,
        _ => RaftAvatarActivity.online,
      },
    );
    final text = agentDisplayText(
      display,
      lastSeenAt: live?['lastSeenAt'] is String
          ? DateTime.tryParse(live!['lastSeenAt'] as String)
          : null,
      relativeTime: (seen) => resourceRelativeTime(
        seen.toIso8601String(),
        chinese: Localizations.localeOf(context).languageCode == 'zh',
      ),
      translate: (source, values) => raftFormat(context, source, values),
    );
    return (presence, text);
  }

  @override
  Widget build(BuildContext context) {
    final roster = store.roster(widget.threadChannelId);
    // No zero-count affordance and nothing actionable while the count is
    // unknown; a failed load keeps an error-only trigger with Retry.
    final visible = roster != null && store.visible(widget.threadChannelId);
    final agents = roster?.agents ?? const <ThreadAgentFollower>[];
    final label = roster?.error == true
        ? raftText(context, "Followers couldn't be loaded.")
        : raftFormat(
            context,
            agents.length == 1
                ? '{count} Agent following'
                : '{count} Agents following',
            {'count': agents.length},
          );
    final body = roster != null && roster.loading && !roster.loaded
        ? RaftFollowersBody.loading
        : roster?.error == true
        ? RaftFollowersBody.error
        : agents.isEmpty
        ? RaftFollowersBody.empty
        : RaftFollowersBody.list;
    return RaftToastPortal(
      controller: toast,
      child: RaftThreadFollowers(
        triggerLabel: label,
        count: agents.length,
        error: roster?.error == true,
        visible: visible,
        body: body,
        avatars: [
          for (final agent in agents.take(3))
            avatar(agent, RaftMountedAvatarContext.sidebarList),
        ],
        onRetry: () =>
            unawaited(store.load([widget.threadChannelId], force: true)),
        rows: [
          for (final agent in agents)
            () {
              final (presence, text) = activity(agent);
              final canRemove = roster?.canManage == true && agent.canRemove;
              final server = agent.serverLabel;
              return RaftFollowerRow(
                id: agent.id,
                label: agent.label,
                avatar: avatar(
                  agent,
                  RaftMountedAvatarContext.membersRow,
                  presence: presence,
                ),
                secondary: text,
                peerLabel: !agent.isCurrentServer && server != null
                    ? server
                    : null,
                onOpen: widget.onOpenAgent == null
                    ? null
                    : () => widget.onOpenAgent!(agent.id),
                removeLabel: roster?.canManage != true
                    ? null
                    : canRemove
                    ? raftFormat(context, 'Remove {agent} from followers', {
                        'agent': agent.label,
                      })
                    : raftFormat(
                        context,
                        '{agent} follows from {server}. Switch to that server to remove them.',
                        {
                          'agent': agent.label,
                          'server':
                              server ?? raftText(context, 'another server'),
                        },
                      ),
                canRemove: canRemove,
                removing: removingId == agent.id,
                onRemove: () => unawaited(remove(agent)),
              );
            }(),
        ],
      ),
    );
  }
}
