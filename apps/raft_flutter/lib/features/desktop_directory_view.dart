import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'desktop_navigation_policy.dart';
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

class _DesktopDirectoryViewState extends State<DesktopDirectoryView> {
  WorkspaceController get w => widget.controller;
  WorkspaceEntityDirectory? _directory;
  final agentMenu = RaftMenuController();
  bool agentsExpanded = true, humansExpanded = true;
  final collapsedMachineGroups = <String, bool>{};
  WorkspaceController? _listened;
  late String _authority;

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

  /// Kinds whose failure is reported; group names are auxiliary.
  List<WorkspaceEntityKind> get errorKinds => widget.computers
      ? [WorkspaceEntityKind.computers]
      : [
          if (w.can('viewAgents')) WorkspaceEntityKind.agents,
          if (showHumans) WorkspaceEntityKind.members,
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
    _directory = w.entityDirectory..addListener(directoryChanged);
    w.entityDirectory.ensure(waitKinds, retryFailed: true);
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
    w.entityDirectory.ensure(waitKinds);
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
    agentMenu.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> rows(WorkspaceEntityKind kind) =>
      w.server == null ? const [] : w.entityDirectory.rows(kind);

  /// After the user's own creation the affected list is re-read in place.
  Future<void> reload(WorkspaceEntityKind kind) =>
      w.entityDirectory.refresh(kind, force: true);

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

  List<Widget> agentMachineGroups(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> computers,
  ) {
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
    final directory = w.entityDirectory;
    final loading = waitKinds.any((kind) => !directory.settled(kind));
    final error = errorKinds.any((kind) => directory.state(kind).error != null);
    final computers = w.can('viewMachines')
        ? rows(WorkspaceEntityKind.computers)
        : const <Map<String, dynamic>>[];
    final agents = !widget.computers && w.can('viewAgents')
        ? rows(WorkspaceEntityKind.agents)
        : const <Map<String, dynamic>>[];
    final humans = !widget.computers && showHumans
        ? rows(WorkspaceEntityKind.members)
        : const <Map<String, dynamic>>[];
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
            ...agentMachineGroups(rows, computers)
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
      body: loading
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
                if (error)
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
                  if (showHumans)
                    section('Humans', humans, DesktopContentKind.human),
                ],
              ],
            ),
    );
  }
}
