// Channel members: the Web ChannelMembers "modal" presentation
// (packages/web/src/components/agent/ChannelMembers.tsx) — a header trigger
// (Users + participant count) opening a Modal Card `max-w-sm p-6` with the
// roster and the staged multi-select "Add Member" view (search, AGENTS /
// HUMANS candidates with CheckMarker + AvatarSlot compact-list, pinned
// "Create a New Agent" entry, "Add selected (N)").
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'channel_form_fields.dart';
import 'create_channel_dialog.dart';

/// Agent activity for the compact-list badge: the row's `activity` when the
/// payload carries one, else `agentStatusFallbackActivity(status)`.
RaftAvatarPresence? _presence(Map<String, dynamic> json) {
  final activity = json['activity'];
  final value = switch (activity) {
    'online' => RaftAvatarActivity.online,
    'thinking' => RaftAvatarActivity.thinking,
    'working' => RaftAvatarActivity.working,
    'error' => RaftAvatarActivity.error,
    'offline' => RaftAvatarActivity.offline,
    _ =>
      json['status'] == 'active'
          ? RaftAvatarActivity.online
          : RaftAvatarActivity.offline,
  };
  return RaftAvatarPresence(activity: value);
}

/// Header trigger: `Button size="sm" className="min-w-7 gap-1 px-1.5"` with
/// `Users size={14}` and the mono participant count.
class ChannelMembersButton extends StatefulWidget {
  const ChannelMembersButton({
    super.key,
    required this.controller,
    required this.channel,
  });
  final WorkspaceController controller;
  final RaftChannel channel;
  @override
  State<ChannelMembersButton> createState() => _ChannelMembersButtonState();
}

class _ChannelMembersButtonState extends State<ChannelMembersButton> {
  int? count;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final roster = await widget.controller.query(
        '/channels/${widget.channel.id}/members',
      );
      if (!mounted) return;
      setState(
        () => count =
            ((roster['humans'] as List?)?.length ?? 0) +
            ((roster['agents'] as List?)?.length ?? 0),
      );
    } catch (_) {
      if (mounted) setState(() => count = 0);
    }
  }

  @override
  Widget build(BuildContext context) => RaftMembersTrigger(
    key: const ValueKey('channel-members-open'),
    count: count,
    onPressed: () async {
      await ChannelMembers.show(
        context,
        controller: widget.controller,
        channel: widget.channel,
      );
      refresh();
    },
  );
}

class ChannelMembers extends StatefulWidget {
  const ChannelMembers({
    super.key,
    required this.controller,
    required this.channel,
  });
  final WorkspaceController controller;
  final RaftChannel channel;

  static Future<void> show(
    BuildContext context, {
    required WorkspaceController controller,
    required RaftChannel channel,
  }) => showRaftModal<void>(
    context,
    builder: (_) => ChannelMembers(controller: controller, channel: channel),
  );

  @override
  State<ChannelMembers> createState() => _ChannelMembersState();
}

class _ChannelMembersState extends State<ChannelMembers> {
  WorkspaceController get w => widget.controller;
  RaftChannel get channel => widget.channel;
  List<Map<String, dynamic>> humans = [], agents = [];
  List<ChannelMemberCandidate> candidates = [];
  final Map<String, Map<String, dynamic>> agentRows = {};
  bool loading = true, adding = false, addView = false;
  String? error;
  final selected = <String>{};
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final roster = await w.query('/channels/${channel.id}/members');
      final pool = await loadChannelMemberCandidates(w);
      final rawAgents = await w.query('/agents');
      if (!mounted) return;
      setState(() {
        humans = [
          for (final h in (roster['humans'] as List? ?? []).whereType<Map>())
            Map<String, dynamic>.from(h),
        ];
        agents = [
          for (final a in (roster['agents'] as List? ?? []).whereType<Map>())
            Map<String, dynamic>.from(a),
        ];
        for (final a in (rawAgents as List? ?? const []).whereType<Map>()) {
          agentRows['${a['id']}'] = Map<String, dynamic>.from(a);
        }
        final inChannel = {
          for (final h in humans) 'human:${h['userId'] ?? h['id']}',
          for (final a in agents) 'agent:${a['id']}',
        };
        // The add view also lists the signed-in user's server peers only.
        candidates = [
          for (final c in pool)
            if (!inChannel.contains('${c.kind}:${c.id}')) c,
        ];
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  bool get canAdd =>
      w.can('addChannelMembers', resource: channel) && !channel.archived;

  Future<void> confirmAdd() async {
    if (adding || selected.isEmpty) return;
    setState(() {
      adding = true;
      error = null;
    });
    try {
      await w.command(
        'POST',
        '/channels/${channel.id}/members/batch',
        data: {
          'userIds': [
            for (final k in selected)
              if (k.startsWith('human:')) k.substring(6),
          ],
          'agentIds': [
            for (final k in selected)
              if (k.startsWith('agent:')) k.substring(6),
          ],
        },
      );
      selected.clear();
      addView = false;
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = raftText(
            context,
            'Some selected members could not be added. They remain selected — press Add again to retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  Future<void> remove(String kind, String id) async {
    try {
      await w.command(
        'DELETE',
        '/channels/${channel.id}/members/${kind == 'agent' ? 'agent' : 'user'}/$id',
      );
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final origin = w.client.origin;
    final canRemove =
        w.can('removeChannelMembers', resource: channel) && !channel.archived;
    RaftMemberRowData row(String kind, Map<String, dynamic> m) {
      final id = '${kind == 'agent' ? m['id'] : (m['userId'] ?? m['id'])}';
      final candidate = ChannelMemberCandidate(
        kind: kind,
        id: id,
        name: '${m['name'] ?? ''}',
        displayName: m['displayName'] as String?,
        avatarUrl: m['avatarUrl'] as String?,
      );
      return RaftMemberRowData(
        label: candidate.label,
        avatar: ChannelCandidateAvatar(
          candidate: candidate,
          avatarContext: RaftMountedAvatarContext.compactList,
          origin: origin,
        ),
        onRemove: canRemove ? () => remove(kind, id) : null,
      );
    }

    RaftPickerItem item(ChannelMemberCandidate c) => RaftPickerItem(
      key: '${c.kind}:${c.id}',
      label: c.label,
      description: c.description,
      avatar: ChannelCandidateAvatar(
        candidate: c,
        avatarContext: RaftMountedAvatarContext.compactList,
        origin: origin,
        presence: c.kind == 'agent' && agentRows[c.id] != null
            ? _presence(agentRows[c.id]!)
            : null,
      ),
    );
    final query = search.text;
    return RaftChannelMembersModal(
      onClose: close,
      search: search,
      channelName: channel.name,
      addView: addView,
      loading: loading,
      adding: adding,
      error: error,
      humans: [for (final h in humans) row('human', h)],
      agents: [for (final a in agents) row('agent', a)],
      onAdd: canAdd ? () => setState(() => addView = true) : null,
      onBack: () => setState(() {
        addView = false;
        selected.clear();
        search.clear();
      }),
      hasCandidates: candidates.isNotEmpty,
      candidateAgents: [
        for (final c in candidates)
          if (c.kind == 'agent' && c.matches(query)) item(c),
      ],
      candidateHumans: [
        for (final c in candidates)
          if (c.kind == 'human' && c.matches(query)) item(c),
      ],
      chips: [
        for (final key in selected)
          (
            key,
            candidates
                    .where((c) => '${c.kind}:${c.id}' == key)
                    .firstOrNull
                    ?.label ??
                key,
          ),
      ],
      isChecked: selected.contains,
      onToggle: (key) => setState(() {
        if (!selected.remove(key)) selected.add(key);
      }),
      canCreateAgent: w.can('createAgents'),
      onConfirm: confirmAdd,
    );
  }
}
