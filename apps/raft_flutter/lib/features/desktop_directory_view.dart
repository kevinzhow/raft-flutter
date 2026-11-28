import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart' show RaftProfileKind;
import '../data/machine_order.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'desktop_navigation_policy.dart';
import 'add_computer_dialog.dart';
import 'agent_avatar_projection.dart';
import 'agent_metadata_projection.dart' show agentRowAmbientDisplay;
import 'agent_runtime_labels.dart' show runtimeLabelWithStatus;
import 'agent_runtime_models.dart' show runtimeModelLabel;
import 'chat_agent_presentation.dart';
import 'computer_detail_view.dart'
    show computerAvailableVersion, computerDiskLow, computerRowStatus;
import 'create_external_agent_dialog.dart';
import 'managed_agent_launcher.dart';
import 'member_row_menu.dart';
import 'member_profile_rules.dart';
import 'members_page.dart';
import 'members_page_entries.dart';
import 'pushed_server_page.dart';
import 'sender_avatar_projection.dart';
import 'workspace_menu_invite.dart';

/// The classic Sidebar's Members/Computers column. This is a current-authority
/// directory, separate from settings' member-role management and fleet routes.
class DesktopDirectoryView extends StatefulWidget {
  const DesktopDirectoryView({
    super.key,
    required this.controller,
    required this.onSelected,
    this.onOpenDm,
    this.activities,
    this.computers = false,
    this.mobileRoot = false,
    this.selected,
  });
  final WorkspaceController controller;

  /// What each working agent is doing, shown in place of its description.
  final ChatAgentPresentation? activities;
  final bool computers, mobileRoot;
  final DesktopContentTarget? selected;
  final ValueChanged<DesktopContentTarget> onSelected;

  /// Source `MemberHumanRow` / `MemberAgentRow` `onDoubleClick`: a mouse
  /// double-click opens the DM with that person or agent.
  final Future<void> Function(DesktopContentTarget)? onOpenDm;
  @override
  State<DesktopDirectoryView> createState() => _DesktopDirectoryViewState();
}

class _DesktopDirectoryViewState extends State<DesktopDirectoryView> {
  WorkspaceController get w => widget.controller;
  WorkspaceEntityDirectory? _directory;
  List<Map<String, dynamic>> _people = const [],
      _agents = const [],
      _computers = const [];

  /// The row whose context menu is open (it keeps its pressed fill).
  DesktopContentTarget? _menuTarget;
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
    _readDirectory();
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
    _menuTarget = null;
    _readDirectory();
    w.services.entityDirectory.ensure(waitKinds);
  }

  void directoryChanged() {
    if (mounted) setState(_readDirectory);
  }

  void _readDirectory() {
    _people = !widget.computers && showHumans
        ? rows(WorkspaceEntityKind.members)
        : const [];
    _agents = !widget.computers && w.can('viewAgents')
        ? rows(WorkspaceEntityKind.agents)
        : const [];
    _computers = w.can('viewMachines')
        ? rows(WorkspaceEntityKind.computers)
        : const [];
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
    super.dispose();
  }

  List<Map<String, dynamic>> rows(WorkspaceEntityKind kind) =>
      w.server == null ? const [] : w.services.entityDirectory.rows(kind);

  /// After the user's own creation the affected list is re-read in place.
  Future<void> reload(WorkspaceEntityKind kind) =>
      w.services.entityDirectory.refresh(kind, force: true);

  Future<void> refreshDirectory() =>
      Future.wait([for (final kind in waitKinds) reload(kind)]);

  /// Create external agent (Web CreateExternalAgentDialog): Done opens the
  /// agent's page in the directory.
  Future<void> createExternalAgent() async {
    final captured = authority;
    await showCreateExternalAgentDialog(
      context,
      w,
      onCreated: () => reload(WorkspaceEntityKind.agents),
      onOpenAgent: (id) {
        if (mounted && captured == authority) {
          widget.onSelected(DesktopContentTarget(DesktopContentKind.agent, id));
        }
      },
      authorized: () => mounted && captured == authority,
    );
  }

  Future<void> invite() async {
    await showWorkspaceMenuInvite(context, w);
  }

  Future<void> createAgent() async {
    final captured = authority;
    await showManagedAgentForm(context, w);
    if (mounted && captured == authority) {
      await reload(WorkspaceEntityKind.agents);
    }
  }

  /// Sidebar.tsx member-human / member-agent context menu (right click or
  /// long press): Message, and for a managed agent Start / Stop and
  /// Restart / Reset.
  Future<void> openMenu(
    Offset at,
    DesktopContentTarget target,
    Map<String, dynamic> value,
  ) {
    final captured = authority;
    setState(() => _menuTarget = target);
    return openMemberRowMenu(
      context,
      at: at,
      w: w,
      target: target,
      value: value,
      onClosed: () {
        if (mounted && identical(_menuTarget, target)) {
          setState(() => _menuTarget = null);
        }
      },
      onMessage: (target) async {
        if (captured == authority && mounted) {
          await widget.onOpenDm?.call(target);
        }
      },
    );
  }

  Widget row(
    MemberPageEntry entry,
    MembersEntryLayout layout,
    String? computer, {
    bool showComputer = true,
  }) {
    final target = entry.target;
    final kind = target.kind, id = target.id;
    final value = entry.record;
    final name = entry.name;
    final agent = kind == DesktopContentKind.agent;
    final avatar = projectSenderAvatar(
      origin: w.client.origin,
      senderId: id,
      senderType: agent ? 'agent' : 'user',
      agents: agent ? [value] : const [],
      members: agent ? const [] : [value],
      currentUser: w.client.user?.json,
    );
    final sourceAuthority = authority;
    final selected = widget.selected?.kind == kind && widget.selected?.id == id;
    final mayMessage =
        agent ||
        canMessageHuman(
          membershipStatus: value['membershipStatus'] ?? 'active',
          remoteJoint: false,
          actorRole: w.server?.string('role'),
          targetRole: value['role'] as String?,
        );
    final runtime = value['runtime'] as String?;
    final model = value['model'] as String?;
    final display = agent ? agentRowAmbientDisplay(value) : null;
    final machine = value['machineId'] is String
        ? w.entityDirectory.computer(value['machineId'] as String)
        : null;
    final computerOffline = machine?['status'] == 'offline';
    final tone = switch (display?.activity) {
      _ when computerOffline => RaftActivityTone.offline,
      'working' => RaftActivityTone.working,
      'thinking' => RaftActivityTone.thinking,
      'error' => RaftActivityTone.error,
      'offline' => RaftActivityTone.offline,
      _ => RaftActivityTone.online,
    };
    return MemberDirectoryEntry(
      key: ValueKey('desktop-directory-${kind.name}-$id'),
      layout: layout,
      entry: entry,
      self: !agent && id == w.client.user?.id,
      selected: selected,
      menuOpen: _menuTarget?.kind == kind && _menuTarget?.id == id,
      onMenu: mayMessage ? (at) => openMenu(at, target, value) : null,
      activity: agent ? widget.activities?.rowText(id) : null,
      statusDot: agent ? RaftStatusDot(activity: tone) : null,
      computerDot: machine == null
          ? null
          : RaftStatusDot(
              activity: computerOffline
                  ? RaftActivityTone.offline
                  : RaftActivityTone.online,
            ),
      facts: [
        if (agent) ...[
          raftText(
            context,
            (computerOffline ? 'Computer offline' : display!.heldText) ??
                switch (display?.activity) {
                  'offline' => 'Offline',
                  'working' => 'Working…',
                  'thinking' => 'Thinking…',
                  'error' => 'Error',
                  _ => 'Online',
                },
          ),
          runtime == null ? '—' : runtimeLabelWithStatus(context, runtime),
          model == null ? '—' : runtimeModelLabel(runtime ?? '', model),
          if (showComputer) computer ?? '—',
        ],
      ],
      avatar: RaftAvatar(
        name: name,
        size: 35,
        presence: agent ? agentRowPresence(value) : null,
        mountedContext: layout == MembersEntryLayout.list
            ? RaftMountedAvatarContext.sidebarList
            : null,
        kind: kind == DesktopContentKind.agent
            ? RaftAvatarKind.agent
            : RaftAvatarKind.human,
        content: RaftAvatarContent(
          name: name,
          kind: agent
              ? RaftAvatarContentKind.agent
              : RaftAvatarContentKind.human,
          uploadedUrl: avatar.uploadedUrl,
          pixelKey: avatar.pixelKey,
          fallback: agent
              ? null
              : layout == MembersEntryLayout.list
              ? const RaftMountedAvatarFallback(
                  avatarContext: RaftMountedAvatarContext.sidebarList,
                )
              : Center(
                  child: RaftIcon(
                    RaftGlyph.user,
                    size: 16,
                    color: RaftTokens.of(context).ui.stickerInk,
                  ),
                ),
        ),
      ),
      onOpen: () {
        if (sourceAuthority == authority && mounted) {
          widget.onSelected(target);
        }
      },
      onMessage: !mayMessage
          ? null
          : () {
              if (sourceAuthority == authority && mounted) {
                unawaited(
                  widget.onOpenDm?.call(target).catchError((_) {}) ??
                      Future.value(),
                );
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
    final loading = !w.services.entityDirectory.settled(
      WorkspaceEntityKind.computers,
    );
    final error =
        w.services.entityDirectory.state(WorkspaceEntityKind.computers).error !=
        null;
    final ordered = orderMachinesLikeSidebar(rows, userId: w.client.user?.id);
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

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final directory = w.services.entityDirectory;
    final loading = waitKinds.any((kind) => !directory.settled(kind));
    if (widget.computers) {
      return KeyedSubtree(
        key: const PageStorageKey('directory-computers'),
        child: RaftMountedSidebarFrame(
          header: widget.mobileRoot
              ? RaftMobileRootHeader(
                  title: 'Computers',
                  onBack: pushedServerPageBack(context, w),
                  backKey: pushedServerPageBackKey,
                )
              : const RaftChatSidebarHeading(label: 'Computers'),
          body: computersList(t, _computers),
        ),
      );
    }
    final create = w.can('createAgents');
    return MembersPage(
      key: ValueKey(authority),
      workspace: w,
      humans: _people,
      agents: _agents,
      computers: _computers,
      showHumans: showHumans,
      loading: loading,
      failed:
          showHumans &&
          directory.state(WorkspaceEntityKind.members).error != null,
      mobile: widget.mobileRoot,
      onRefresh: refreshDirectory,
      onBack: widget.mobileRoot ? pushedServerPageBack(context, w) : null,
      onInvite: w.can('inviteMembers') ? invite : null,
      onCreate: create ? createAgent : null,
      onConnect: create ? createExternalAgent : null,
      buildEntry: row,
      onOpenAgent: (id) =>
          w.openProfile(RaftProfileKind.agent, id, agentTab: 'usage'),
    );
  }
}
