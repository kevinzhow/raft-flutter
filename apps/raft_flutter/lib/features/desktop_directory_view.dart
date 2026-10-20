import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'desktop_navigation_policy.dart';
import 'add_computer_dialog.dart';
import 'agent_avatar_projection.dart';
import 'agent_metadata_catalog.dart' show sourceAgentActivities;
import 'computer_detail_view.dart'
    show computerAvailableVersion, computerDiskLow, computerRowStatus;
import 'fleet_views.dart' show showFleetRegistration;
import 'managed_agent_launcher.dart';
import 'sender_avatar_projection.dart';
import 'workspace_menu_invite.dart';

/// The classic Sidebar's Members/Computers column. This is a current-authority
/// directory, separate from settings' member-role management and fleet routes.
class DesktopDirectoryView extends StatefulWidget {
  const DesktopDirectoryView({
    super.key,
    required this.controller,
    required this.onSelected,
    this.computers = false,
    this.mobileRoot = false,
    this.selected,
  });
  final WorkspaceController controller;
  final bool computers, mobileRoot;
  final DesktopContentTarget? selected;
  final ValueChanged<DesktopContentTarget> onSelected;
  @override
  State<DesktopDirectoryView> createState() => _DesktopDirectoryViewState();
}

class _DesktopDirectoryViewState extends State<DesktopDirectoryView> {
  WorkspaceController get w => widget.controller;
  WorkspaceEntityDirectory? _directory;
  final agentMenu = RaftMenuController();
  bool agentsExpanded = true, humansExpanded = true;
  final collapsedMachineGroups = <String, bool>{};
  WorkspaceController? _listened;
  late String _authority;

  /// Live `agent:activity` per agent (Web agentStore.agentActivities): the
  /// avatar badge follows it before the next directory read.
  final liveActivity = <String, String>{};
  final _liveSeq = <String, BigInt>{};
  StreamSubscription<RaftEvent>? _events;

  /// Account, workspace, role and the visibility rules of this column. Rows
  /// themselves are a projection of the server-scoped entity directory, which
  /// fences its own data, so a channel change never touches this column.
  String get authority =>
      '${w.client.generation}|${w.client.user?.id}|${w.server?.id}|'
      '${w.server?.string('role')}|${identityHashCode(w)}|${w.client.origin}|'
      '${widget.computers}|${w.can('viewAgents')}|${w.can('viewMembers')}|'
      '${w.can('viewMachines')}|${w.server?.json['hideHumansFromMembers']}';

  bool get showHumans =>
      w.can('viewMembers') &&
      !(w.server?.string('role') == 'member' &&
          w.server?.json['hideHumansFromMembers'] == true);

  /// Kinds whose first read decides the column's first frame. Computer names
  /// label the agent groups, so the Members column waits for them too.
  List<WorkspaceEntityKind> get waitKinds => [
    if (w.server != null) ...[
      if (!widget.computers && w.can('viewAgents')) WorkspaceEntityKind.agents,
      if (!widget.computers && showHumans) WorkspaceEntityKind.members,
      if (w.can('viewMachines')) WorkspaceEntityKind.computers,
    ],
  ];

  @override
  void initState() {
    super.initState();
    _authority = authority;
    bind();
  }

  void bind() {
    _listened?.removeListener(workspaceChanged);
    _directory?.removeListener(directoryChanged);
    _listened = w..addListener(workspaceChanged);
    _directory = w.services.entityDirectory..addListener(directoryChanged);
    _events?.cancel();
    liveActivity.clear();
    _liveSeq.clear();
    _events = w.client.events.listen((e) {
      final p = e.payload;
      if (e.name == 'connected') _liveSeq.clear();
      if (e.name != 'agent:activity' || p is! Map || !mounted) return;
      final id = p['agentId'], activity = p['activityKind'] ?? p['activity'];
      if (id is! String || !sourceAgentActivities.contains(activity)) return;
      // Web applySocketActivity: a serverSeq at or below the held one is stale.
      final seq = BigInt.tryParse('${p['serverSeq'] ?? ''}');
      final last = _liveSeq[id];
      if (seq != null && last != null && seq <= last) return;
      if (seq != null) _liveSeq[id] = seq;
      setState(() => liveActivity[id] = activity as String);
    });
    w.services.entityDirectory.ensure(waitKinds, retryFailed: true);
  }

  void workspaceChanged() {
    if (!mounted || _authority == authority) return;
    authorityChanged();
  }

  void authorityChanged() => setState(resetAuthority);

  /// A new account, workspace, role or visibility retires the open menu and
  /// remembered folds; the rows follow the directory's own fencing.
  void resetAuthority() {
    _authority = authority;
    agentMenu.close();
    collapsedMachineGroups.clear();
    w.services.entityDirectory.ensure(waitKinds);
  }

  void directoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(DesktopDirectoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, w)) {
      bind();
      resetAuthority();
    } else if (oldWidget.computers != widget.computers) {
      resetAuthority();
    }
  }

  @override
  void dispose() {
    _listened?.removeListener(workspaceChanged);
    _directory?.removeListener(directoryChanged);
    _events?.cancel();
    agentMenu.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> rows(WorkspaceEntityKind kind) =>
      w.server == null ? const [] : w.services.entityDirectory.rows(kind);

  /// After the user's own creation the affected list is re-read in place.
  Future<void> reload(WorkspaceEntityKind kind) =>
      w.services.entityDirectory.refresh(kind, force: true);

  Future<void> refreshDirectory() =>
      Future.wait([for (final kind in waitKinds) reload(kind)]);

  Future<void> register(bool computer) async {
    final captured = authority;
    await showFleetRegistration(
      context,
      w,
      computers: computer,
      onCreated: () => reload(
        computer ? WorkspaceEntityKind.computers : WorkspaceEntityKind.agents,
      ),
      authorized: () => mounted && captured == authority,
    );
  }

  Widget addAgentMenu() => RaftDropdownMenu(
    controller: agentMenu,
    label: 'Add agent',
    tooltip: 'Add agent',
    width: 190,
    align: RaftDropdownAlign.end,
    sideOffset: 8,
    entries: [
      RaftMenuEntry(
        label: raftText(context, 'Create agent'),
        glyph: RaftGlyph.bot,
        onPressed: () async {
          final captured = authority;
          await showManagedAgentForm(context, w);
          if (mounted && captured == authority) {
            await reload(WorkspaceEntityKind.agents);
          }
        },
      ),
      RaftMenuEntry(
        label: raftText(context, 'Create external agent'),
        glyph: RaftGlyph.link2,
        onPressed: () => register(false),
      ),
    ],
    triggerBuilder: (context, focus, open) => RaftControl(
      key: const ValueKey('desktop-directory-add-agent'),
      semanticLabel: raftText(context, 'Add agent'),
      tooltip: raftText(context, 'Add agent'),
      focusNode: focus,
      visualHeight: 24,
      visualWidth: 24,
      minimumTargetSize: 24,
      recipe: RaftSidebarSectionActionRecipe(RaftTokens.of(context)),
      onPressed: open,
      child: const RaftIcon(RaftGlyph.plus, size: 14),
    ),
  );

  Widget row(Map<String, dynamic> value, DesktopContentKind kind) {
    final id = kind == DesktopContentKind.human
        ? value['userId'] ?? value['id']
        : value['id'];
    if (id is! String) {
      return const SizedBox.shrink();
    }
    final displayName = '${value['displayName'] ?? ''}';
    final name = displayName.isNotEmpty
        ? displayName
        : '${value['name'] ?? ''}';
    final agent = kind == DesktopContentKind.agent;
    final avatar = projectSenderAvatar(
      origin: w.client.origin,
      senderId: id,
      senderType: agent ? 'agent' : 'user',
      agents: agent ? [value] : const [],
      members: agent ? const [] : [value],
      currentUser: w.client.user?.json,
      requestSize: 16,
    );
    final target = DesktopContentTarget(kind, id);
    final sourceAuthority = authority;
    final selected = widget.selected?.kind == kind && widget.selected?.id == id;
    // Sidebar.tsx member rows use the same SidebarItem recipe as conversations.
    return RaftNavItem(
      key: ValueKey('desktop-directory-${kind.name}-$id'),
      label: name,
      labelSuffix: kind == DesktopContentKind.human && id == w.client.user?.id
          ? raftText(context, '(you)')
          : null,
      conversationKind: RaftConversationNavKind.directory,
      selected: selected,
      tag: kind == DesktopContentKind.human && value['role'] == 'guest'
          ? RaftSidebarTag(raftText(context, 'Guest'))
          : null,
      description:
          kind != DesktopContentKind.computer &&
              '${value['description'] ?? ''}'.isNotEmpty
          ? '${value['description']}'
          : null,
      leading: kind == DesktopContentKind.computer
          ? const RaftIcon(RaftGlyph.monitor, size: 18)
          : RaftAvatar(
              name: name,
              presence: agent
                  ? agentRowPresence(value, live: liveActivity[id])
                  : null,
              mountedContext: RaftMountedAvatarContext.sidebarList,
              kind: kind == DesktopContentKind.agent
                  ? RaftAvatarKind.agent
                  : RaftAvatarKind.human,
              content: RaftAvatarContent(
                name: name,
                kind: agent
                    ? RaftAvatarContentKind.agent
                    : RaftAvatarContentKind.human,
                uploadedUrl: avatar.uploadedUrl,
                gravatarUrl: avatar.gravatarUrl,
                pixelKey: avatar.pixelKey,
                fallback: RaftMountedAvatarFallback(
                  avatarContext: RaftMountedAvatarContext.sidebarList,
                  identity: agent
                      ? RaftMountedAvatarIdentity.agent
                      : RaftMountedAvatarIdentity.human,
                  gravatar: avatar.gravatarUrl != null,
                ),
              ),
            ),
      onTap: () {
        if (sourceAuthority == authority && mounted) {
          widget.onSelected(target);
        }
      },
    );
  }

  /// Sidebar.tsx `ComputerRow` for one machine (status dot, run label,
  /// `→ vX`, Low disk), selected when it is the open detail.
  Widget computerRow(Map<String, dynamic> m) {
    final id = m['id'];
    if (id is! String) return const SizedBox.shrink();
    final latest = w.services.entityDirectory.latestComputerVersion;
    final available = computerAvailableVersion(m, latest);
    final status = computerRowStatus(
      m,
      available,
      w.services.entityDirectory.upgradeReconnect(m),
    );
    final target = DesktopContentTarget(DesktopContentKind.computer, id);
    final sourceAuthority = authority;
    return RaftComputerRow(
      key: ValueKey('desktop-directory-computer-$id'),
      name: '${m['name'] ?? ''}',
      description: '${m['description'] ?? ''}',
      runLabel: status.label,
      offline: status.offline,
      availableVersion: available,
      diskLow: computerDiskLow(m) != null,
      dot: status.dot,
      selected:
          widget.selected?.kind == DesktopContentKind.computer &&
          widget.selected?.id == id,
      onTap: () {
        if (sourceAuthority == authority && mounted) widget.onSelected(target);
      },
    );
  }

  /// Sidebar.tsx computers mode: heading (`COMPUTERS n` + Add computer),
  /// rows (attached-by-me first, like sidebarMachineOrder.ts), and the
  /// skeleton / "No computers yet" states.
  Widget computersList(RaftTokens t, List<Map<String, dynamic>> rows) {
    final loading = !w.services.entityDirectory.settled(WorkspaceEntityKind.computers);
    final error =
        w.services.entityDirectory.state(WorkspaceEntityKind.computers).error != null;
    final ordered = [
      ...rows.where((m) => m['computerAttachedByCurrentUser'] == true),
      ...rows.where((m) => m['computerAttachedByCurrentUser'] != true),
    ];
    return RaftComputerSidebarList(
      listKey: const Key('desktop-directory-list'),
      label: raftText(context, 'Computers'),
      count: rows.length,
      loading: loading,
      errorText: error
          ? raftText(context, 'Directory could not be loaded.')
          : null,
      emptyText: raftText(context, 'No computers yet'),
      addKey: const ValueKey('desktop-directory-add-computer'),
      addLabel: raftText(context, 'Add computer'),
      onAdd: w.can('registerMachines')
          ? () => showAddComputerDialog(context, w)
          : null,
      rows: [for (final m in ordered) computerRow(m)],
    );
  }

  /// Builds machine headers and agent rows in first-seen order.
  List<({String id, WidgetBuilder build})> agentMachineRows(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> computers,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final value in rows) {
      final machine = value['machineId'];
      final id = machine is String ? machine : '__no_machine__';
      groups.putIfAbsent(id, () => []).add(value);
    }
    final names = {
      for (final computer in computers) computer['id']: computer['name'],
    };
    return [
      for (final (index, entry) in groups.entries.indexed) ...[
        (
          id: 'directory-machine-group-${entry.key}',
          build: (_) => RaftSidebarMachineGroup(
            key: ValueKey('directory-machine-group-${entry.key}'),
            topPadding: index == 0
                ? 2
                : 6 - (RaftTokens.of(context).brutal ? 4 : 2),
            disclosureKey: ValueKey(
              'directory-machine-disclosure-${entry.key}',
            ),
            name: '${names[entry.key] ?? raftText(context, 'No computer')}',
            count: entry.value.length,
            expanded: collapsedMachineGroups[entry.key] != true,
            onExpandedChanged: (expanded) =>
                setState(() => collapsedMachineGroups[entry.key] = !expanded),
            children: const [],
          ),
        ),
        if (collapsedMachineGroups[entry.key] != true)
          for (final value in entry.value)
            (
              id: 'desktop-directory-agent-${value['id']}',
              build: (_) => row(value, DesktopContentKind.agent),
            ),
      ],
    ];
  }

  /// Mobile elegant root: the floating tab bar's clearance (68 / 116 + inset)
  /// arrives as MediaQuery padding from the adaptive workspace, so the recipe's
  /// own 68 is dropped to avoid counting it twice.
  EdgeInsets directoryPadding(RaftSidebarRecipe recipe) {
    final inset = recipe
        .contentInset(headerInFlow: true)
        .resolve(Directionality.of(context));
    final floatingBar = widget.mobileRoot && !RaftTokens.of(context).brutal;
    return raftScrollPadding(
      context,
      floatingBar ? inset.copyWith(bottom: 0) : inset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final directory = w.services.entityDirectory;
    final loading = waitKinds.any((kind) => !directory.settled(kind));
    final computers = w.can('viewMachines')
        ? rows(WorkspaceEntityKind.computers)
        : const <Map<String, dynamic>>[];
    final agents = !widget.computers && w.can('viewAgents')
        ? rows(WorkspaceEntityKind.agents)
        : const <Map<String, dynamic>>[];
    final humans = !widget.computers && showHumans
        ? rows(WorkspaceEntityKind.members)
        : const <Map<String, dynamic>>[];
    List<({String id, WidgetBuilder build})> section(
      String label,
      List<Map<String, dynamic>> rows,
      DesktopContentKind kind, {
      double? topInset,
      bool loading = false,
      bool hideRows = false,
      bool failed = false,
    }) => [
      (
        id: 'directory-section-${kind.name}',
        build: (_) => RaftSidebarSectionHeader(
          key: ValueKey('directory-section-${kind.name}'),
          label: label,
          disclosureKey: ValueKey('desktop-directory-toggle-${kind.name}'),
          topInset: topInset,
          expanded: kind == DesktopContentKind.agent
              ? agentsExpanded
              : humansExpanded,
          onExpandedChanged: widget.computers
              ? null
              : (expanded) => setState(() {
                  if (kind == DesktopContentKind.agent) {
                    agentsExpanded = expanded;
                  } else {
                    humansExpanded = expanded;
                  }
                }),
          count: rows.length,
          trailing: kind == DesktopContentKind.agent && w.can('createAgents')
              ? addAgentMenu()
              : null,
          actions:
              kind == DesktopContentKind.computer && w.can('registerMachines')
              ? [
                  RaftSidebarSectionAction(
                    label: raftText(context, 'Add computer'),
                    key: const ValueKey('desktop-directory-add-computer'),
                    glyph: RaftGlyph.plus,
                    onPressed: () => register(true),
                  ),
                ]
              : kind == DesktopContentKind.human && w.can('inviteMembers')
              ? [
                  RaftSidebarSectionAction(
                    label: raftText(context, 'Invite human'),
                    key: const ValueKey('desktop-directory-invite-human'),
                    glyph: RaftGlyph.plus,
                    onPressed: () => showWorkspaceMenuInvite(context, w),
                  ),
                ]
              : const [],
        ),
      ),
      if (widget.computers ||
          (kind == DesktopContentKind.agent ? agentsExpanded : humansExpanded))
        if (failed && rows.isEmpty)
          (
            id: 'directory-${kind.name}-error',
            build: (_) => RaftSidebarSectionDescription(
              raftText(context, 'Humans failed to load'),
              error: raftSidebarErrorInk,
            ),
          )
        else if (hideRows || rows.isEmpty)
          (
            id: 'directory-${kind.name}-hint',
            build: (_) => loading
                ? const RaftSidebarRowsSkeleton()
                : RaftSidebarSectionDescription(
                    raftText(
                      context,
                      kind == DesktopContentKind.agent
                          ? 'No agents yet'
                          : 'No humans',
                    ),
                  ),
          )
        else if (kind == DesktopContentKind.agent)
          ...agentMachineRows(rows, computers)
        else
          for (final value in rows)
            (
              id: 'desktop-directory-${kind.name}-${value['id']}',
              build: (_) => row(value, kind),
            ),
    ];
    final items = <({String id, WidgetBuilder build})>[
      // Sidebar.tsx people tab: the accent `Graph` item (GitBranch 14) above
      // Agents, shown while the workspace grid is off.
      if (!widget.computers)
        (
          id: 'directory-graph',
          build: (_) => RaftNavItem(
            key: const ValueKey('desktop-directory-graph'),
            label: raftText(context, 'Graph'),
            glyph: RaftGlyph.gitBranch,
            glyphSize: 14,
            selected: widget.selected?.kind == DesktopContentKind.graph,
            onTap: () {
              if (mounted) {
                widget.onSelected(
                  const DesktopContentTarget(DesktopContentKind.graph, 'graph'),
                );
              }
            },
          ),
        ),
      if (w.can('viewAgents'))
        ...section(
          'Agents',
          agents,
          DesktopContentKind.agent,
          loading: loading,
          hideRows: loading,
        ),
      if (showHumans)
        ...section(
          'Humans',
          humans,
          DesktopContentKind.human,
          topInset: !w.can('viewAgents')
              ? null
              : !agentsExpanded
              ? 8
              : agents.isEmpty || loading
              ? 12
              : 12 - (t.brutal ? 4 : 2),
          failed: directory.state(WorkspaceEntityKind.members).error != null,
        ),
    ];
    final indices = {for (var i = 0; i < items.length; i++) items[i].id: i};
    final size = MediaQuery.sizeOf(context);
    final recipe = RaftSidebarRecipe(
      t,
      viewportWidth: size.width,
      viewportHeight: size.height,
      variant: RaftSidebarVariant.mountedProduct,
    );
    // SidebarRoot: `border-r border-line-muted theme-brutal:border-r-2
    // theme-brutal:border-black` inside the 240px column (desktop only).
    final frame = RaftMountedSidebarFrame(
      // The edge is drawn by the frame so the column's colour and divider both
      // continue under the status bar.
      trailingEdge: !widget.mobileRoot,
      header: widget.mobileRoot
          ? RaftMobileRootHeader(
              title: widget.computers ? 'Computers' : 'Members',
            )
          : RaftChatSidebarHeading(
              label: widget.computers ? 'Computers' : 'Members',
            ),
      body: widget.computers
          ? computersList(t, computers)
          : RaftPullToRefresh(
              enabled: widget.mobileRoot || RaftInteraction.of(context).touch,
              onRefresh: refreshDirectory,
              child: ListView.builder(
                key: const Key('desktop-directory-list'),
                physics:
                    widget.mobileRoot || RaftInteraction.of(context).touch
                    ? const AlwaysScrollableScrollPhysics()
                    : null,
                padding: directoryPadding(recipe),
                itemCount: items.length,
                findChildIndexCallback: (key) =>
                    key is ValueKey<String> ? indices[key.value] : null,
                itemBuilder: (context, index) => items[index].build(context),
              ),
            ),
    );
    return KeyedSubtree(
      key: PageStorageKey(
        'directory-${widget.computers ? 'computers' : 'members'}',
      ),
      child: frame,
    );
  }
}
