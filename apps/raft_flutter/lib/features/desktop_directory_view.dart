import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'desktop_navigation_policy.dart';
import 'management_support.dart';
import 'fleet_views.dart' show showFleetRegistration;
import 'managed_agent_launcher.dart';
import 'sender_avatar_projection.dart';

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

class _DesktopDirectoryViewState extends ManagementState<DesktopDirectoryView> {
  @override
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> agents = [], humans = [], computers = [];
  StreamSubscription<RaftEvent>? events;
  final agentMenu = RaftMenuController();
  bool agentsExpanded = true, humansExpanded = true;
  final collapsedMachineGroups = <String, bool>{};
  @override
  String get authority =>
      '${super.authority}|${identityHashCode(w)}|${w.client.origin}|${widget.computers}|'
      '${w.can('viewAgents')}|${w.can('viewMembers')}|${w.can('viewMachines')}|'
      '${w.server?.json['hideHumansFromMembers']}';
  @override
  void initState() {
    super.initState();
    startManagement();
    bindEvents();
  }

  void bindEvents() {
    events?.cancel();
    events = w.client.events.listen((event) {
      if (event.name.startsWith('agent:') ||
          event.name.startsWith('machine:') ||
          event.name.startsWith('server:member')) {
        reload();
      }
    });
  }

  @override
  void didUpdateWidget(DesktopDirectoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != w) {
      rebindManagementController();
      bindEvents();
    } else if (oldWidget.computers != widget.computers) {
      refreshAuthority();
    }
  }

  @override
  void dispose() {
    events?.cancel();
    agentMenu.dispose();
    super.dispose();
  }

  @override
  void clearData() {
    agentMenu.close();
    agents = [];
    humans = [];
    computers = [];
    collapsedMachineGroups.clear();
  }

  @override
  Future<void> loadData(int request, int generation) async {
    if (w.server == null) {
      clearData();
      return;
    }
    final server = w.server!.id;
    Future<List<Map<String, dynamic>>> read(String path, String key) async {
      final value = await w.query(path);
      return managementRows(value is Map ? value[key] : value);
    }

    if (widget.computers) {
      final rows = w.can('viewMachines')
          ? await read('/servers/$server/machines', 'machines')
          : <Map<String, dynamic>>[];
      if (accepts(generation, request)) {
        computers = rows;
      }
      return;
    }
    final showHumans =
        w.can('viewMembers') &&
        !(w.server!.string('role') == 'member' &&
            w.server!.json['hideHumansFromMembers'] == true);
    Future<List<Map<String, dynamic>>> readGroupMachines() async {
      if (!w.can('viewMachines')) return const [];
      try {
        return await read('/servers/$server/machines', 'machines');
      } catch (_) {
        // Auxiliary names may be unavailable. Never discard accepted members
        // or infer machine access from an agent's machineId.
        return const [];
      }
    }

    final results = await Future.wait([
      w.can('viewAgents')
          ? read('/agents', 'agents')
          : Future.value(<Map<String, dynamic>>[]),
      showHumans
          ? read('/servers/$server/members', 'members')
          : Future.value(<Map<String, dynamic>>[]),
      readGroupMachines(),
    ]);
    if (accepts(generation, request)) {
      agents = results[0].where((row) => row['deletedAt'] == null).toList();
      humans = results[1];
      computers = results[2];
    }
  }

  Future<void> register(bool computer) async {
    final captured = authority;
    await showFleetRegistration(
      context,
      w,
      computers: computer,
      onCreated: reload,
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
          if (mounted && captured == authority) await reload();
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
      description:
          kind != DesktopContentKind.computer &&
              '${value['description'] ?? ''}'.isNotEmpty
          ? '${value['description']}'
          : null,
      leading: kind == DesktopContentKind.computer
          ? const RaftIcon(RaftGlyph.monitor, size: 18)
          : RaftAvatar(
              name: name,
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

  List<Widget> agentMachineGroups(List<Map<String, dynamic>> rows) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final value in rows) {
      final machine = value['machineId'];
      final id = machine is String ? machine : '__no_machine__';
      groups.putIfAbsent(id, () => []).add(value);
    }
    return [
      for (final entry in groups.entries)
        RaftSidebarMachineGroup(
          key: ValueKey('directory-machine-group-${entry.key}'),
          disclosureKey: ValueKey('directory-machine-disclosure-${entry.key}'),
          name:
              '${computers.where((m) => m['id'] == entry.key).firstOrNull?['name'] ?? raftText(context, 'No computer')}',
          count: entry.value.length,
          expanded: collapsedMachineGroups[entry.key] != true,
          onExpandedChanged: (expanded) =>
              setState(() => collapsedMachineGroups[entry.key] = !expanded),
          children: [
            for (final value in entry.value)
              row(value, DesktopContentKind.agent),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    Widget section(
      String label,
      List<Map<String, dynamic>> rows,
      DesktopContentKind kind,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSidebarSectionHeader(
          label: label,
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
              : const [],
        ),
        if (widget.computers ||
            (kind == DesktopContentKind.agent
                ? agentsExpanded
                : humansExpanded))
          if (kind == DesktopContentKind.agent)
            ...agentMachineGroups(rows)
          else
            for (final value in rows) row(value, kind),
      ],
    );
    final size = MediaQuery.sizeOf(context);
    final recipe = RaftSidebarRecipe(
      t,
      viewportWidth: size.width,
      viewportHeight: size.height,
      variant: RaftSidebarVariant.mountedProduct,
    );
    return RaftMountedSidebarFrame(
      header: widget.mobileRoot
          ? RaftMobileRootHeader(
              title: widget.computers ? 'Computers' : 'Members',
            )
          : RaftChatSidebarHeading(
              label: widget.computers ? 'Computers' : 'Members',
            ),
      body: loading && agents.isEmpty && humans.isEmpty && computers.isEmpty
          ? Center(
              child: Text(
                raftText(context, 'Loading...'),
                style: RaftTypography.mono(t, size: 14, line: 20),
              ),
            )
          : ListView(
              key: const Key('desktop-directory-list'),
              padding: recipe.contentInset(headerInFlow: true),
              children: [
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      raftText(context, 'Directory could not be loaded.'),
                    ),
                  ),
                if (widget.computers)
                  section('Computers', computers, DesktopContentKind.computer)
                else ...[
                  if (w.can('viewAgents'))
                    section('Agents', agents, DesktopContentKind.agent),
                  if (w.can('viewMembers') &&
                      !(w.server?.string('role') == 'member' &&
                          w.server?.json['hideHumansFromMembers'] == true))
                    section('Humans', humans, DesktopContentKind.human),
                ],
              ],
            ),
    );
  }
}
