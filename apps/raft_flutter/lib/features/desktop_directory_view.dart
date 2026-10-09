import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'desktop_navigation_policy.dart';
import 'management_support.dart';
import 'page_layout.dart';
import 'fleet_views.dart' show showFleetRegistration;
import 'managed_agent_launcher.dart';
import 'public_avatar_url.dart';

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
    final results = await Future.wait([
      w.can('viewAgents')
          ? read('/agents', 'agents')
          : Future.value(<Map<String, dynamic>>[]),
      showHumans
          ? read('/servers/$server/members', 'members')
          : Future.value(<Map<String, dynamic>>[]),
    ]);
    if (accepts(generation, request)) {
      agents = results[0].where((row) => row['deletedAt'] == null).toList();
      humans = results[1];
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
    final name = '${value['displayName'] ?? value['name'] ?? ''}';
    final target = DesktopContentTarget(kind, id);
    final sourceAuthority = authority;
    final t = RaftTokens.of(context);
    final selected = widget.selected?.kind == kind && widget.selected?.id == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RaftControl(
        key: ValueKey('desktop-directory-${kind.name}-$id'),
        semanticLabel: name,
        selected: selected,
        visualHeight: 36,
        recipe: RaftMountedConversationControlRecipe(t, selected: selected),
        onPressed: () {
          if (sourceAuthority == authority && mounted) {
            widget.onSelected(target);
          }
        },
        child: Row(
          children: [
            if (kind == DesktopContentKind.computer)
              const RaftIcon(RaftGlyph.monitor, size: 18)
            else
              RaftAvatar(
                name: name,
                size: 24,
                kind: kind == DesktopContentKind.agent
                    ? RaftAvatarKind.agent
                    : RaftAvatarKind.human,
                imageUrl: raftPublicAvatarUrl(
                  w.client.origin,
                  value['avatarUrl'] as String?,
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RaftTypography.heading(
                  t,
                  size: 14,
                  line: 20,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          for (final value in rows) row(value, kind),
      ],
    );
    return Material(
      color: RaftSidebarRecipe(
        t,
        viewportWidth: MediaQuery.sizeOf(context).width,
        viewportHeight: MediaQuery.sizeOf(context).height,
        variant: RaftSidebarVariant.mountedProduct,
      ).bodyBackground,
      child: Column(
        children: [
          if (widget.mobileRoot)
            RaftMobileRootHeader(
              title: widget.computers ? 'Computers' : 'Members',
              actions: [
                RaftIconButton(
                  glyph: RaftGlyph.refreshCw,
                  tooltip: 'Refresh members',
                  onPressed: reload,
                ),
              ],
            )
          else
            RaftPageHeader(
              title: widget.computers ? 'Computers' : 'Members',
              height: raftPageHeaderHeight(context),
              actions: [
                RaftIconButton(
                  glyph: RaftGlyph.refreshCw,
                  tooltip: 'Refresh',
                  onPressed: reload,
                ),
              ],
            ),
          Expanded(
            child:
                loading && agents.isEmpty && humans.isEmpty && computers.isEmpty
                ? Center(
                    child: Text(
                      raftText(context, 'Loading...'),
                      style: RaftTypography.mono(t, size: 14, line: 20),
                    ),
                  )
                : ListView(
                    key: const Key('desktop-directory-list'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    children: [
                      if (error != null)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            raftText(context, 'Directory could not be loaded.'),
                          ),
                        ),
                      if (widget.computers)
                        section(
                          'Computers',
                          computers,
                          DesktopContentKind.computer,
                        )
                      else ...[
                        if (w.can('viewAgents'))
                          section('Agents', agents, DesktopContentKind.agent),
                        if (w.can('viewMembers'))
                          section('Humans', humans, DesktopContentKind.human),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
