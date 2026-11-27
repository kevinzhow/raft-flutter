// Web features/channel/ChannelMembers.tsx roster and staged membership adapter.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'external_invite_channel_members.dart';
import '../data/cause_notice.dart';
import '../data/channel_roster_invalidations.dart';
import '../data/user_error.dart';

import '../data/workspace_controller.dart';
import '../data/raft_location.dart';
import '../data/workspace_entity_directory.dart';
import 'channel_form_fields.dart';
import 'channel_member_servers.dart';
import 'composer_directory.dart'
    show
        cachedChannelRoster,
        cachedChannelRosterExternals,
        rememberChannelRoster;
import 'create_channel_dialog.dart';
import 'fleet_views.dart';
import 'managed_agent_launcher.dart';
import 'member_profile_view.dart';
import 'agent_metadata_catalog.dart' show sourceAgentActivities;
import 'agent_metadata_projection.dart';
import 'resource_cards.dart' show resourceRelativeTime;

/// Web `ChannelMembers` participant count: agents + humans + Slack bridge
/// participants (`externalMembers`).
int channelRosterCount(dynamic roster) {
  int length(String key) =>
      roster is Map && roster[key] is List ? (roster[key] as List).length : 0;
  return length('humans') + length('agents') + length('externalMembers');
}

/// Web `isLocalMember`: a roster row belongs to this server unless it names
/// another `serverId` than the channel's.
bool isLocalChannelMember(Map<String, dynamic> member, RaftChannel channel) {
  final channelServer = channel.json['serverId'];
  final memberServer = member['serverId'];
  return channelServer is! String ||
      channelServer.isEmpty ||
      memberServer is! String ||
      memberServer.isEmpty ||
      memberServer == channelServer;
}

/// Web `useChannelMembers` + `useAgentDisplayState`: the roster snapshot with
/// the canonical directory row (live activity, `lastSeenAt`) laid over it,
/// resolved by [resolveAgentAmbientDisplay]. Without a live activity a
/// managed stopped agent reads "Stopped" and an external agent silent for more
/// than 120 s reads offline.
AgentAmbientDisplay channelMemberAgentDisplay(
  Map<String, dynamic> roster, {
  Map? directory,
  DateTime? now,
}) {
  final row = <String, dynamic>{
    ...roster,
    if (directory != null) ...Map<String, dynamic>.from(directory),
  };
  final activity = row['activityKind'] ?? row['activity'];
  final status = row['status'] is String ? row['status'] as String : 'offline';
  final external = row['external'] == true || row['runtime'] == 'external';
  // A snapshot `offline` of a stopped agent is the absence of activity.
  final live =
      sourceAgentActivities.contains(activity) &&
      !(status == 'stopped' && !external && activity == 'offline');
  return resolveAgentAmbientDisplay(
    identity: AgentPresentationIdentity(
      id: '${row['id']}',
      status: status,
      runtime: row['runtime'] as String?,
      external: external,
      deleted: row['deletedAt'] != null,
      lastSeenAt: row['lastSeenAt'] is String
          ? DateTime.tryParse(row['lastSeenAt'] as String)
          : null,
    ),
    now: now ?? DateTime.now(),
    current: live ? agentRowActivity(row) : null,
  );
}

RaftAvatarPresence channelMemberDisplayPresence(AgentAmbientDisplay display) =>
    RaftAvatarPresence(
      activity: switch (display.activity) {
        'thinking' => RaftAvatarActivity.thinking,
        'working' => RaftAvatarActivity.working,
        'error' => RaftAvatarActivity.error,
        'offline' => RaftAvatarActivity.offline,
        _ => RaftAvatarActivity.online,
      },
    );

/// Agent activity for the compact-list badge: the live directory row over the
/// roster snapshot, else `agentStatusFallbackActivity(status)`.
RaftAvatarPresence? channelMemberPresence(
  Map<String, dynamic> json, {
  Map? directory,
  DateTime? now,
}) => channelMemberDisplayPresence(
  channelMemberAgentDisplay(json, directory: directory, now: now),
);

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
  int _requestVersion = 0;
  @override
  void initState() {
    super.initState();
    // The roster the composer read when the channel opened is shown at once.
    final roster = cachedChannelRoster(widget.controller, widget.channel.id);
    if (roster != null) {
      count =
          roster.humans.length +
          roster.agents.length +
          cachedChannelRosterExternals(
            widget.controller,
            widget.channel.id,
          ).length;
    }
    ChannelRosterInvalidations.of(widget.controller.client)
        .addListener(_rosterInvalidated);
    refresh();
  }

  @override
  void didUpdateWidget(covariant ChannelMembersButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      ChannelRosterInvalidations.of(oldWidget.controller.client)
          .removeListener(_rosterInvalidated);
      ChannelRosterInvalidations.of(widget.controller.client)
          .addListener(_rosterInvalidated);
    }
    if (oldWidget.channel.id != widget.channel.id ||
        oldWidget.controller != widget.controller) {
      final roster = cachedChannelRoster(widget.controller, widget.channel.id);
      count = roster == null
          ? null
          : roster.humans.length +
                roster.agents.length +
                cachedChannelRosterExternals(
                  widget.controller,
                  widget.channel.id,
                ).length;
      unawaited(refresh());
    }
  }

  void _rosterInvalidated() {
    if (ChannelRosterInvalidations.of(widget.controller.client).value.$2 ==
        widget.channel.id) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    ChannelRosterInvalidations.of(widget.controller.client)
        .removeListener(_rosterInvalidated);
    super.dispose();
  }

  Future<void> refresh() async {
    final version = ++_requestVersion;
    try {
      final roster = await widget.controller.query(
        '/channels/${widget.channel.id}/members',
      );
      if (!mounted || version != _requestVersion) return;
      setState(() => count = channelRosterCount(roster));
    } catch (_) {
      if (mounted && version == _requestVersion) setState(() => count = 0);
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
    this.page = false,
    this.embedded = false,
    this.onClose,
    this.startInAdd = false,
    this.createAgentForm = showManagedAgentForm,
  });
  final WorkspaceController controller;
  final RaftChannel channel;
  final bool page;

  /// Opens the create-agent dialog (the existing one); returns the created
  /// agent row, or null when the dialog was dismissed.
  final Future<Map<String, dynamic>?> Function(
    BuildContext context,
    WorkspaceController w, {
    String? initialName,
  })
  createAgentForm;

  /// The page is mounted inside the desktop settings drawer (Web `OverflowSheet
  /// bare`), so back from the roster returns to the drawer root.
  final bool embedded;
  final VoidCallback? onClose;

  /// The settings drawer's dashed add tile lands directly in the add view.
  final bool startInAdd;

  static Future<void> show(
    BuildContext context, {
    required WorkspaceController controller,
    required RaftChannel channel,
    bool startInAdd = false,
  }) async {
    if (controller.mobileNavigation) {
      if (!controller.can('viewChannel', resource: channel)) return;
      FocusManager.instance.primaryFocus?.unfocus();
      controller.navigation.navigate(
        controller.location.withQuery({
          'channelPage': '${RaftChannelPage.members.name}:${channel.id}',
          // The drawer's dashed + tile lands straight in the add view.
          if (startInAdd) 'channelPageAdd': '1',
        }),
      );
      controller.notifyListeners();
      return;
    }
    await showRaftDialog<void>(
      context: context,
      modal: true,
      builder: (_) => ChannelMembers(
        controller: controller,
        channel: channel,
        startInAdd: startInAdd,
      ),
    );
  }

  @override
  State<ChannelMembers> createState() => _ChannelMembersState();
}

class _ChannelMembersState extends State<ChannelMembers> {
  WorkspaceController get w => widget.controller;
  RaftChannel get channel =>
      [
        ...w.channels,
        ...w.dms,
      ].where((channel) => channel.id == widget.channel.id).firstOrNull ??
      widget.channel;
  List<Map<String, dynamic>> humans = [], agents = [], externalMembers = [];
  late ChannelCandidateFeed _feed = ChannelCandidateFeed(w, includeSelf: true);
  late ChannelExternalInvites _invites;
  List<ChannelMemberCandidate> get candidates => [
    for (final c in _feed.value)
      if (!_inChannel.contains('${c.kind}:${c.id}')) c,
  ];

  /// Agent rows (presence, profile seed) from the workspace directory.
  Map<String, Map<String, dynamic>> get agentRows => {
    for (final a in w.services.entityDirectory.rows(WorkspaceEntityKind.agents))
      '${a['id']}': a,
  };
  Set<String> get _inChannel => {
    for (final h in humans)
      if (isLocalChannelMember(h, channel)) 'human:${h['userId'] ?? h['id']}',
    for (final a in agents) 'agent:${a['id']}',
  };

  /// The channel roster is the only per-channel read: it shows from the
  /// composer's prefetched copy at the first frame (loading only on a true
  /// cold open). Candidates and agent rows come from the workspace directory
  /// and never hold the roster back.
  bool rosterKnown = false, adding = false;
  int rosterEpoch = 0;
  bool get loading => !rosterKnown || (addView && !_feed.ready);
  late bool addView = widget.startInAdd;

  /// A failed add / role change (cleared by the next attempt, by a change to
  /// the selection and by leaving the add view).
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next add or role change starts, the add selection changes or the add view is left.
  String? error;

  /// A failed roster read: it ends with the next roster that loads.
  final loadError = CauseNotice();
  final selected = <String>{};
  final failedChoices = <String>{};
  final search = TextEditingController();

  String? roleChanging;

  /// The members page's profile stack top (`kind:id`): a row opens its member's
  /// profile as the page's second level (`ProfilePanel presentation="embedded"`).
  ({String kind, String id})? profile;

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    final roster = cachedChannelRoster(w, widget.channel.id);
    if (roster != null) {
      humans = roster.humans;
      agents = roster.agents;
      externalMembers = cachedChannelRosterExternals(w, widget.channel.id);
      rosterKnown = true;
    }
    _feed.addListener(_directoryChanged);
    _invites = ChannelExternalInvites(w, widget.channel)
      ..addListener(_directoryChanged);
    w.services.entityDirectory.addListener(_directoryChanged);
    // Source useChannelMembers: a member change in this channel re-reads the
    // roster in place, so a newly joined agent appears while the view is open.
    _events = w.client.events.listen(_event);
    ChannelRosterInvalidations.of(w.client).addListener(_rosterInvalidated);
    load();
  }

  @override
  void didUpdateWidget(covariant ChannelMembers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _feed.removeListener(_directoryChanged);
      _feed.dispose();
      oldWidget.controller.services.entityDirectory.removeListener(
        _directoryChanged,
      );
      ChannelRosterInvalidations.of(oldWidget.controller.client)
          .removeListener(_rosterInvalidated);
      unawaited(_events?.cancel());
      _feed = ChannelCandidateFeed(w, includeSelf: true)
        ..addListener(_directoryChanged);
      w.services.entityDirectory.addListener(_directoryChanged);
      ChannelRosterInvalidations.of(w.client).addListener(_rosterInvalidated);
      _events = w.client.events.listen(_event);
    }
    if (oldWidget.channel.id != widget.channel.id ||
        oldWidget.controller != widget.controller) {
      _reload?.cancel();
      _invites.dispose();
      _invites = ChannelExternalInvites(w, widget.channel)
        ..addListener(_directoryChanged);
      rosterEpoch++;
      adding = false;
      profile = null;
      pendingJoin = null;
      selected.clear();
      failedChoices.clear();
      search.clear();
      addView = widget.startInAdd;
      error = null;
      loadError.clear();
      final roster = cachedChannelRoster(w, widget.channel.id);
      humans = roster?.humans ?? [];
      agents = roster?.agents ?? [];
      externalMembers = cachedChannelRosterExternals(w, widget.channel.id);
      rosterKnown = roster != null;
      unawaited(load());
    }
  }

  void _rosterInvalidated() {
    if (ChannelRosterInvalidations.of(w.client).value.$2 == channel.id) {
      unawaited(load());
    }
  }

  void _directoryChanged() {
    if (mounted) setState(() {});
  }

  StreamSubscription<RaftEvent>? _events;
  Timer? _reload;

  void _event(RaftEvent event) {
    if (event.name != 'channel:members-updated') return;
    final payload = event.payload;
    final id = payload is Map ? payload['channelId'] : null;
    if (id is String && id != widget.channel.id) return;
    _reload?.cancel();
    _reload = Timer(const Duration(milliseconds: 150), () {
      if (mounted) unawaited(load());
    });
  }

  @override
  void dispose() {
    ChannelRosterInvalidations.of(w.client).removeListener(_rosterInvalidated);
    unawaited(_events?.cancel());
    _reload?.cancel();
    _feed.removeListener(_directoryChanged);
    _feed.dispose();
    _invites.dispose();
    w.services.entityDirectory.removeListener(_directoryChanged);
    search.dispose();
    super.dispose();
  }

  int _loadVersion = 0;

  Future<void> load() async {
    final version = ++_loadVersion;
    // The authority the roster is read under (a later reduction drops it).
    final readUnder = channel;
    try {
      final roster = await w.query('/channels/${readUnder.id}/members');
      if (!mounted || version != _loadVersion) return;
      setState(() {
        humans = [
          for (final h in (roster['humans'] as List? ?? []).whereType<Map>())
            Map<String, dynamic>.from(h),
        ];
        agents = [
          for (final a in (roster['agents'] as List? ?? []).whereType<Map>())
            Map<String, dynamic>.from(a),
        ];
        externalMembers = [
          for (final e
              in (roster['externalMembers'] as List? ?? []).whereType<Map>())
            Map<String, dynamic>.from(e),
        ];
        rosterKnown = true;
        loadError.clear();
      });
      rememberChannelRoster(
        w,
        readUnder,
        humans: humans,
        agents: agents,
        externalMembers: externalMembers,
      );
    } catch (e) {
      if (mounted && version == _loadVersion) {
        // Only the server's own words: Web shows nothing for a read that got
        // no answer (useChannelMembers logs it), so neither does this page.
        final shown = userErrorText(e, fallback: '', where: 'channel members');
        setState(() {
          rosterKnown = true;
          if (shown.isNotEmpty) loadError.raise(raftText(context, shown));
        });
      }
    }
  }

  bool get canAdd =>
      w.can('addChannelMembers', resource: channel) && !channel.archived;

  /// The created agent that could not join this channel (Web
  /// `pendingJoinAgent`): the banner stays until the roster holds it.
  ({String id, String name})? pendingJoin;
  bool retryingJoin = false;

  /// The search text doubles as the new agent's suggested name; the leading
  /// "@" is display notation, so it is dropped (Web `createAgentPrefillName`).
  String get createAgentName =>
      search.text.trim().replaceFirst(RegExp(r'^@'), '');

  /// The name carries over only from the promoted (no-hit) entry: a generic
  /// "Create Agent" row never smuggles the search text into the dialog.
  bool get createPromoted =>
      createAgentName.isNotEmpty &&
      !candidates.any((c) => c.matches(search.text));

  /// "Create Agent": the existing create-agent dialog, then the new agent
  /// joins this channel.
  Future<void> createAgent() async {
    if (adding || !w.can('createAgents') || !canAdd) return;
    final created = await widget.createAgentForm(
      context,
      w,
      initialName: createPromoted ? createAgentName : null,
    );
    final id = created?['id'];
    if (created == null || id is! String || !mounted) return;
    await joinCreatedAgent(
      id,
      '${created['name'] ?? created['displayName'] ?? id}',
    );
  }

  /// The same atomic batch as "Add selected" for every way a created agent
  /// reaches this channel. A failure stages it in the selection too, so the
  /// banner's retry and "Add selected" both finish the join.
  Future<void> joinCreatedAgent(String id, String name) async {
    setState(() => retryingJoin = true);
    try {
      await w.command(
        'POST',
        '/channels/${channel.id}/members/batch',
        data: {
          'userIds': <String>[],
          'agentIds': [id],
        },
      );
      if (!mounted) return;
      setState(() {
        pendingJoin = null;
        selected.remove('agent:$id');
        failedChoices.remove('agent:$id');
        search.clear();
      });
      await load();
    } catch (_) {
      if (mounted) {
        setState(() {
          pendingJoin = (id: id, name: name);
          selected.add('agent:$id');
        });
      }
    } finally {
      if (mounted) setState(() => retryingJoin = false);
    }
  }

  Future<void> confirmAdd() async {
    if (adding || selected.isEmpty || !canAdd) return;
    final epoch = rosterEpoch;
    final id = channel.id;
    final choices = Set<String>.of(selected);
    bool current() => mounted && rosterEpoch == epoch;
    setState(() {
      adding = true;
      error = null;
    });
    try {
      await w.command(
        'POST',
        '/channels/$id/members/batch',
        data: {
          'userIds': [
            for (final k in choices)
              if (k.startsWith('human:')) k.substring(6),
          ],
          'agentIds': [
            for (final k in choices)
              if (k.startsWith('agent:')) k.substring(6),
          ],
        },
      );
      if (!current()) return;
      resetAdd();
      await load();
    } catch (_) {
      if (current() && addView) {
        setState(() {
          // The batch is atomic. Keep each unresolved choice available.
          failedChoices
            ..clear()
            ..addAll(choices);
          final pending = pendingJoin;
          if (pending == null ||
              choices.length != 1 ||
              !choices.contains('agent:${pending.id}')) {
            error = raftText(
              context,
              'None of the selected members could be added.',
            );
          }
        });
      }
    } finally {
      if (current()) setState(() => adding = false);
    }
  }

  void resetAdd() {
    setState(() {
      addView = false;
      error = null;
      selected.clear();
      failedChoices.clear();
    });
    search.clear();
  }

  /// `useChannelMemberRemoval`: stage the target, then the destructive
  /// ConfirmDialog runs the same DELETE.
  Future<void> requestRemove(String kind, String id, String name) async {
    if (channel.archived || isAllChannel) {
      return;
    }
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('channel-member-remove-dialog'),
        title: raftText(context, 'Remove member'),
        message: raftFormat(
          context,
          '{name} will stop receiving ordinary delivery from #{channel} and cannot send messages until they rejoin. Existing followed threads are not automatically unfollowed; followed public threads can still notify them until they unfollow or manage those threads. Private content remains gated by current access.',
          {'name': name, 'channel': channel.name},
        ),
        confirmLabel: raftText(context, 'Remove member'),
        cancelLabel: raftText(context, 'Keep Member'),
        loadingLabel: raftText(context, 'Removing…'),
        actionSize: RaftButtonRecipeSize.xs,
        onConfirm: () => removeNow(kind, id),
      ),
      // Web opens it from the members Modal: its scrim stacks on that one's.
      overModal: true,
    );
  }

  Future<void> removeNow(String kind, String id) async {
    await w.command(
      'DELETE',
      '/channels/${channel.id}/members/${kind == 'agent' ? 'agent' : 'user'}/$id',
    );
    await load();
  }

  /// `changeMemberRole`: PATCH the member's channel role, then reload.
  Future<void> changeRole(String kind, String id, String role) async {
    final key = '$kind:$id';
    setState(() {
      error = null;
      roleChanging = key;
    });
    try {
      await w.command(
        'PATCH',
        '/channels/${channel.id}/members/${kind == 'agent' ? 'agent' : 'user'}/$id/role',
        data: {'role': role},
      );
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = raftText(
            context,
            "Could not update this member's channel role. Try again.",
          ),
        );
      }
    } finally {
      if (mounted) setState(() => roleChanging = null);
    }
  }

  bool get isAllChannel => channel.name == 'all' && channel.type == 'channel';

  /// `renderMemberActions` role action: shown behind the flag for a member
  /// whose channel role the viewer may change (`canChangeChannelRole`), or to
  /// explain why a server owner/admin cannot be demoted.
  ({String nextRole, bool protectedDemote})? _roleAction(
    String kind,
    String id,
    Map<String, dynamic> m,
    String effectiveRole,
    String serverRole,
  ) {
    final effective =
        m['effectiveChannelRole'] ??
        (serverRole == 'owner' ||
                serverRole == 'admin' ||
                m['channelRole'] == 'admin'
            ? 'admin'
            : 'member');
    final protectedServerAdmin = serverRole == 'owner' || serverRole == 'admin';
    final self = id == w.client.user?.id;
    final canExplain =
        !channel.archived &&
        !isAllChannel &&
        channel.json['channelCapabilities'] is Map &&
        (channel.json['channelCapabilities']
                as Map)['changeChannelMemberRoles'] ==
            true &&
        !self &&
        protectedServerAdmin &&
        effective != 'member';
    final canChange =
        !channel.archived && !isAllChannel && m['canChangeChannelRole'] == true;
    // Web 1.24 MemberRoleActions.tsx:48 (`channel_manager_role_actions_v0`
    // is retired; the channel's own capability decides the explanation).
    if (!(canChange || canExplain)) return null;
    return (
      nextRole: effective == 'member' ? 'admin' : 'member',
      protectedDemote: canExplain,
    );
  }

  Future<void> protectedDemote(String name) => RaftConfirmDialog.show(
    context,
    RaftConfirmDialog(
      title: raftText(context, "Can't demote server admins"),
      message: raftFormat(
        context,
        '{name} is a server owner or admin, so they remain a Channel Admin in every channel. Change their server role in Server Administration first.',
        {'name': name},
      ),
      confirmLabel: raftText(context, 'Got It'),
      confirmVariant: RaftButtonRecipeVariant.outline,
      showCancel: false,
    ),
  );

  void close() => widget.onClose != null
      ? widget.onClose!()
      : Navigator.of(context).maybePop();

  void back() {
    if (profile != null) {
      setState(() => profile = null);
    } else if (addView) {
      resetAdd();
    } else {
      close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final origin = w.client.origin;
    final canRemove =
        w.can('removeChannelMembers', resource: channel) && !channel.archived;
    // Web `renderExternalRow`: a Slack bridge participant is read-only (no
    // profile, no actions) with the provider tag and `@handle`.
    RaftMemberRowData externalRow(Map<String, dynamic> m) {
      final id = '${m['id']}';
      final candidate = ChannelMemberCandidate(
        kind: 'human',
        id: id,
        name: '${m['displayName'] ?? ''}',
        avatarUrl: m['avatarUrl'] as String?,
      );
      final handles = m['handles'];
      final handle = handles is List && handles.isNotEmpty
          ? '${handles.first}'
          : '';
      return RaftMemberRowData(
        testId: 'member-page-row-external-$id',
        human: true,
        secondaryMono: true,
        secondary: handle.isEmpty ? null : '@$handle',
        roleLabel: raftText(context, 'Slack'),
        label: '${m['displayName'] ?? ''}',
        searchText:
            '${m['displayName'] ?? ''} ${handles is List ? handles.join(' ') : ''}',
        avatar: ChannelCandidateAvatar(
          candidate: candidate,
          avatarContext: widget.page
              ? RaftMountedAvatarContext.membersRow
              : RaftMountedAvatarContext.compactList,
          origin: origin,
          extent: 35,
        ),
      );
    }

    RaftMemberRowData row(String kind, Map<String, dynamic> m) {
      final id = '${kind == 'agent' ? m['id'] : (m['userId'] ?? m['id'])}';
      if (kind == 'agent') {
        m = {...m, ...?w.services.entityDirectory.agent(id)};
      }
      final candidate = ChannelMemberCandidate(
        kind: kind,
        id: id,
        name: '${m['name'] ?? ''}',
        displayName: m['displayName'] as String?,
        managedByAppInstallId: m['managedByAppInstallId'] as String?,
        managedByAppName: m['managedByApp'] is Map
            ? (m['managedByApp'] as Map)['name'] as String?
            : null,
        avatarUrl: kind == 'agent'
            ? agentAvatarWithDirectory(
                w.services.entityDirectory.agent(id),
                m['avatarUrl'] as String?,
              )
            : m['avatarUrl'] as String?,
      );
      final display = kind == 'agent'
          ? channelMemberAgentDisplay(
              m,
              directory: w.services.entityDirectory.agent(id),
            )
          : null;
      final presence = display == null
          ? null
          : channelMemberDisplayPresence(display);
      // Web: a joint partner's member can't be removed from this server.
      final local = isLocalChannelMember(m, channel);
      // `effectiveChannelRole ?? serverRole`: owner / admin inheritance and an
      // explicit channel grant share the one user-facing Channel Admin label
      // (MemberRoleTag); a plain member shows nothing.
      final serverRole = '${m['serverRole'] ?? m['role'] ?? 'member'}';
      final role =
          '${m['effectiveChannelRole'] ?? (kind == 'agent' ? serverRole : m['role'] ?? 'member')}';
      final description = '${m['description'] ?? ''}'.trim();
      final roleAction = _roleAction(kind, id, m, role, serverRole);
      final profileKind = kind == 'agent'
          ? RaftProfileKind.agent
          : RaftProfileKind.human;
      void openProfile() {
        if (widget.page && profileKind == RaftProfileKind.human) {
          primeHumanProfileServers(
            w,
            channel.json['serverId'] as String?,
            id,
            m['servers'],
          );
        }
        if (widget.page) {
          setState(() => profile = (kind: kind, id: id));
        } else {
          close();
          w.openProfile(
            profileKind,
            id,
            channelId:
                profileKind == RaftProfileKind.human && channel.type == 'joint'
                ? channel.id
                : null,
          );
        }
      }

      final avatar = ChannelCandidateAvatar(
        candidate: candidate,
        avatarContext: widget.page
            ? RaftMountedAvatarContext.membersRow
            : RaftMountedAvatarContext.compactList,
        origin: origin,
        presence: candidate.managedByAppInstallId == null ? presence : null,
        extent: 35,
      );
      return RaftMemberRowData(
        testId: 'member-page-row-$kind-$id',
        human: kind != 'agent',
        badge: channelCandidateAppBadge(context, candidate),
        secondary: display != null
            ? agentDisplayText(
                display,
                lastSeenAt:
                    w.services.entityDirectory.agent(id)?['lastSeenAt']
                        is String
                    ? DateTime.tryParse(
                        w.services.entityDirectory.agent(id)!['lastSeenAt']
                            as String,
                      )
                    : m['lastSeenAt'] is String
                    ? DateTime.tryParse(m['lastSeenAt'] as String)
                    : null,
                relativeTime: (seen) => resourceRelativeTime(
                  seen.toIso8601String(),
                  locale: Localizations.localeOf(context).toLanguageTag(),
                ),
                translate: (source, values) =>
                    raftFormat(context, source, values),
              )
            : (description.isEmpty ? null : description),
        secondaryMono: false,
        roleLabel: switch (role) {
          'guest' => raftText(context, 'Guest'),
          'member' => null,
          _ => raftText(context, 'Channel admin'),
        },
        guest: role == 'guest',
        label: candidate.label,
        searchText: '${candidate.name} ${candidate.displayName ?? ''}',
        avatar: widget.page
            ? avatar
            : RaftAvatarButton(
                semanticLabel: candidate.label,
                onPressed: openProfile,
                child: avatar,
              ),
        serverBadges: channelMemberServerLabels(m, channel),
        onTap: widget.page ? openProfile : null,
        onRemove:
            !channel.archived &&
                !isAllChannel &&
                (m['canRemoveFromChannel'] as bool? ?? (canRemove && local))
            ? () => requestRemove(
                kind,
                id,
                '${m['displayName'] ?? m['name'] ?? ''}',
              )
            : null,
        roleActionLabel: roleAction == null
            ? null
            : raftText(
                context,
                roleAction.nextRole == 'admin' ? 'Make Admin' : 'Demote',
              ),
        roleActionSemantics: roleAction == null
            ? null
            : raftFormat(
                context,
                roleAction.nextRole == 'admin'
                    ? 'Make {name} a Channel Admin'
                    : 'Remove Channel Admin from {name}',
                {'name': '${m['name'] ?? ''}'},
              ),
        roleActionDisabled: roleChanging == '$kind:$id',
        onRoleAction: roleAction == null
            ? null
            : () => roleAction.protectedDemote
                  ? protectedDemote('${m['displayName'] ?? m['name'] ?? ''}')
                  : changeRole(kind, id, roleAction.nextRole),
      );
    }

    RaftPickerItem item(ChannelMemberCandidate c) => RaftPickerItem(
      key: '${c.kind}:${c.id}',
      label: c.label,
      description: c.description,
      badge: channelCandidateAppBadge(context, c),
      avatar: ChannelCandidateAvatar(
        candidate: c,
        avatarContext: RaftMountedAvatarContext.compactList,
        origin: origin,
        presence:
            c.kind == 'agent' &&
                c.managedByAppInstallId == null &&
                agentRows[c.id] != null
            ? channelMemberPresence(
                // ignore: raft_lints/avoid_render_index_assertion -- Guarded by `agentRows[c.id] != null` on the line above.
                agentRows[c.id]!,
                directory: w.services.entityDirectory.agent(c.id),
              )
            : null,
      ),
    );
    final matching = searchChannelMemberCandidates(search.text, candidates);
    final roster = RaftChannelMembersModal(
      page: widget.page,
      onClose: close,
      search: search,
      channelName: channel.name,
      invited: _invites.rows(context),
      retryInvites: _invites.retry,
      inviteOutside: _invites.inviteOutside(context),
      addView: addView,
      loading: loading,
      adding: adding,
      error: error ?? loadError.message,
      humans: [
        for (final h in humans) row('human', h),
        for (final e in externalMembers) externalRow(e),
      ],
      agents: [for (final a in agents) row('agent', a)],
      onAdd: canAdd ? () => setState(() => addView = true) : null,
      onBack: resetAdd,
      hasCandidates: candidates.isNotEmpty,
      matchedCandidateKeys: [for (final c in matching) '${c.kind}:${c.id}'],
      candidateAgents: [
        for (final c in candidates)
          if (c.kind == 'agent') item(c),
      ],
      candidateHumans: [
        for (final c in candidates)
          if (c.kind == 'human') item(c),
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
      failedChoices: failedChoices,
      isChecked: selected.contains,
      onToggle: (key) => setState(() {
        if (!selected.remove(key)) selected.add(key);
        failedChoices.remove(key);
        // Web toggleCandidate: the add failure described the old selection.
        error = null;
      }),
      canCreateAgent: w.can('createAgents'),
      onCreateAgent: createAgent,
      createAgentName: createPromoted ? createAgentName : null,
      joinFailedAgent:
          pendingJoin != null && !agents.any((a) => a['id'] == pendingJoin!.id)
          ? pendingJoin!.name
          : null,
      onRetryJoin: pendingJoin == null
          ? null
          : () =>
                unawaited(joinCreatedAgent(pendingJoin!.id, pendingJoin!.name)),
      retryingJoin: retryingJoin,
      onConfirm: confirmAdd,
    );
    final open = profile;
    if (!widget.page) return roster;
    final content = open == null
        ? roster
        : open.kind == 'human'
        ? MemberProfileView(
            key: ValueKey('member-page-profile-${open.id}'),
            controller: w,
            userId: open.id,
            onClose: back,
            onBack: back,
            onOpenAgent: (id) =>
                setState(() => profile = (kind: 'agent', id: id)),
          )
        : FleetDetail(
            key: ValueKey('member-page-profile-${open.id}'),
            controller: w,
            computers: false,
            initial: agentRows[open.id] ?? {'id': open.id},
            onClose: back,
          );
    final canPop = open == null && !addView && !widget.embedded;
    return RaftDismissScope(
      takeFocus: widget.embedded,
      onDismiss: back,
      child: PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !canPop && !raftDismissTopPopup(context)) back();
        },
        child: content,
      ),
    );
  }
}
