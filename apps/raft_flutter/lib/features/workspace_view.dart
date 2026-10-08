import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'chat_view.dart';
import 'message_selection.dart';

import 'package:flutter/scheduler.dart';

import 'resource_view.dart';
import 'channel_settings.dart';
import 'server_views.dart';
import 'account_settings.dart';
import 'fleet_views.dart';
import 'integrations_views.dart';
import 'provider_views.dart';
import 'admin_views.dart';
import 'private_route_guard.dart';
import 'server_setup_gate.dart';
import 'notification_settings_view.dart';
import 'sidebar_preferences_view.dart';
import 'sidebar_projection.dart';
import 'incoming_share_review.dart';
import 'im_bridges_view.dart';
import 'joint_channel_views.dart';
import 'workspace_browser.dart';
import '../platform/native_sharing.dart';
import '../platform/native_notifications.dart';

class WorkspaceView extends StatefulWidget {
  const WorkspaceView({
    super.key,
    required this.controller,
    required this.appearance,
    required this.onAppearance,
    required this.onLogout,
    this.notifications,
    this.sharing,
  });
  final WorkspaceController controller;
  final NativeNotificationService? notifications;
  final NativeSharing? sharing;

  final RaftAppearance appearance;
  final Future<void> Function(RaftAppearance) onAppearance;
  final Future<void> Function() onLogout;
  @override
  State<WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends State<WorkspaceView> {
  final scaffold = GlobalKey<ScaffoldState>();
  final mainSelection = ChatSelectionHandle(),
      threadSelection = ChatSelectionHandle();
  WorkspaceController get w => widget.controller;
  String? lastAuthority, lastChannelId;
  Map<String, dynamic>? lastChannelAuthority;
  int channelAuthorityRevision = 0;
  bool get wide =>
      MediaQuery.sizeOf(context).width >= RaftAdaptiveWorkspace.desktopMinWidth;
  double sidebarWidth = 240, threadWidth = 400;
  Timer? persistPanels;
  String? sidebarAgentScope;
  List<Map<String, dynamic>> sidebarAgents = [];
  int sidebarAgentRequest = 0;
  VoidCallback? removeShareReceiver;
  bool sharingReady = false, reviewingIncoming = false, bridgeEnabled = false;
  String? shareReceiverScope, bridgeScope;
  int bridgeRequest = 0;
  String tr(String source) => raftText(context, source);

  @override
  void initState() {
    super.initState();
    mainSelection.addListener(chatSelectionChanged);
    threadSelection.addListener(chatSelectionChanged);
    restorePanels();
    w.addListener(syncSidebarAgents);
    w.addListener(syncSharing);
    w.addListener(syncBridgeFlag);
    syncSidebarAgents();
    syncBridgeFlag();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        sharingReady = true;
        syncSharing();
      }
    });
  }

  void syncSharing() {
    if (!sharingReady || !mounted) return;
    final ready =
        w.channel?.joined == true && w.server != null && w.client.user != null;
    final next = ready
        ? jsonEncode([
            w.client.generation,
            w.client.user!.id,
            w.server!.id,
            w.channel!.id,
          ])
        : null;
    if (shareReceiverScope == next) return;
    removeShareReceiver?.call();
    removeShareReceiver = null;
    shareReceiverScope = next;
    if (next == null) return;
    removeShareReceiver = widget.sharing?.registerReceiver((share) {
      if (!mounted || shareReceiverScope != next) return;
      if (reviewingIncoming) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Finish reviewing the current share first.')),
          ),
        );
        return;
      }
      reviewingIncoming = true;
      unawaited(
        reviewIncomingShare(context, w, share, widget.sharing!).whenComplete(
          () {
            reviewingIncoming = false;
          },
        ),
      );
    });
  }

  void syncBridgeFlag() {
    final next = jsonEncode([
      w.client.generation,
      w.client.user?.id,
      w.server?.id,
      w.server?.string('role'),
      w.can('manageIntegrations'),
    ]);
    if (bridgeScope == next) return;
    bridgeScope = next;
    bridgeEnabled = false;
    final request = ++bridgeRequest;
    if (w.server == null || !w.can('manageIntegrations')) return;
    () async {
      try {
        final result = await w.client.post(
          '/feature-flags/evaluate',
          data: {
            'keys': ['slack_bridge_v0'],
            'serverId': w.server!.id,
            'platform': defaultTargetPlatform == TargetPlatform.android
                ? 'mobile'
                : 'web',
          },
        );
        if (!mounted || request != bridgeRequest) return;
        final rows = result is Map
            ? result['evaluations'] as List? ?? []
            : const [];
        setState(() {
          bridgeEnabled = rows.whereType<Map>().any(
            (f) => f['key'] == 'slack_bridge_v0' && f['enabled'] == true,
          );
        });
      } catch (_) {
        /* Unresolved flags keep bridge navigation unavailable. */
      }
    }();
  }

  @override
  void didUpdateWidget(covariant WorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, w)) {
      oldWidget.controller.removeListener(syncSidebarAgents);
      oldWidget.controller.removeListener(syncSharing);
      oldWidget.controller.removeListener(syncBridgeFlag);
      w.addListener(syncSidebarAgents);
      w.addListener(syncSharing);
      w.addListener(syncBridgeFlag);
      bridgeScope = null;
      syncBridgeFlag();
      sidebarAgentScope = null;
      syncSidebarAgents();
    }
    if (!identical(oldWidget.controller, w) ||
        !identical(oldWidget.sharing, widget.sharing)) {
      removeShareReceiver?.call();
      shareReceiverScope = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) syncSharing();
      });
    }
  }

  void chatSelectionChanged() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  Future<void> restorePanels() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      sidebarWidth = (prefs.getDouble('raft.layout.sidebarWidth') ?? 240).clamp(
        180,
        320,
      );
      threadWidth = prefs.getDouble('raft.layout.threadWidth') ?? 400;
    });
  }

  void savePanels(double sidebar, double thread) {
    sidebarWidth = sidebar;
    threadWidth = thread;
    persistPanels?.cancel();
    persistPanels = Timer(const Duration(milliseconds: 250), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('raft.layout.sidebarWidth', sidebarWidth);
      await prefs.setDouble('raft.layout.threadWidth', threadWidth);
    });
  }

  @override
  void dispose() {
    persistPanels?.cancel();
    mainSelection.dispose();
    threadSelection.dispose();
    w.removeListener(syncSidebarAgents);
    w.removeListener(syncSharing);
    w.removeListener(syncBridgeFlag);
    bridgeRequest++;
    removeShareReceiver?.call();
    sidebarAgentRequest++;
    super.dispose();
  }

  void dismissPanel() {
    if (threadSelection.dismiss() || mainSelection.dismiss()) return;
    if (scaffold.currentState?.isDrawerOpen == true) {
      scaffold.currentState?.closeDrawer();
    } else if (w.threadParent != null && w.section == 'chat') {
      w.closeThread();
    } else if (w.section != 'chat') {
      select('chat');
    }
  }

  void select(String section) {
    if (w.section == 'administration' || section == 'settings') {
      bridgeScope = null;
      syncBridgeFlag();
    }
    w.setSection(section);
    scaffold.currentState?.closeDrawer();
  }

  Future<void> chooseChannel(RaftChannel c) async {
    scaffold.currentState?.closeDrawer();
    await w.selectChannel(c);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: w,
    builder: (context, _) {
      final currentChannelAuthority = w.channel == null
          ? null
          : {
              'joined': w.channel!.joined,
              'channelCapabilities': w.channel!.json['channelCapabilities'],
            };
      if (lastChannelId == w.channel?.id) {
        if (channelAuthorityReduced(
          lastChannelAuthority,
          currentChannelAuthority,
        )) {
          channelAuthorityRevision++;
        }
      } else if (lastChannelId != null) {
        final prior = [
          ...w.channels,
          ...w.dms,
        ].where((c) => c.id == lastChannelId).firstOrNull;
        if (channelAuthorityReduced(
          lastChannelAuthority,
          prior == null
              ? null
              : {
                  'joined': prior.joined,
                  'channelCapabilities': prior.json['channelCapabilities'],
                },
        )) {
          channelAuthorityRevision++;
        }
      }
      lastChannelId = w.channel?.id;
      lastChannelAuthority = currentChannelAuthority;
      final authority = jsonEncode([
        w.client.generation,
        w.client.user?.id,
        w.server?.id,
        w.server?.string('role'),
        channelAuthorityRevision,
      ]);
      if (lastAuthority != authority) {
        lastAuthority = authority;
        final navigator = Navigator.of(context);
        for (final observer
            in navigator.widget.observers.whereType<PrivateRouteGuard>()) {
          observer.scopeChanged(authority);
        }
      }
      final t = RaftTokens.of(context);
      final thread = w.section == 'chat' && w.threadParent != null;
      final title = w.section == 'chat'
          ? (w.channel?.name ?? tr('Workspace'))
          : tr(switch (w.section) {
              'workspace-settings' => 'Workspace settings',
              'activity' => 'Activity',
              'settings' => 'Settings',
              'providers' => 'Provider connections',
              'sidebar-settings' => 'Sidebar preferences',
              'im-bridges' => 'IM bridges',
              'joint-channels' => 'Joint channels',
              _ => w.section[0].toUpperCase() + w.section.substring(1),
            });
      Widget content = w.loading
          ? const Center(child: CircularProgressIndicator())
          : w.section == 'settings'
          ? settings()
          : w.server == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RaftEmptyState(
                      title: tr('Welcome to Raft'),
                      detail: tr(
                        'Create a workspace or join with an invitation.',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        RaftButton(
                          label: tr('Create workspace'),
                          onPressed: () => WorkspaceActions.create(context, w),
                        ),
                        RaftButton(
                          label: tr('Join workspace'),
                          secondary: true,
                          onPressed: () => WorkspaceActions.join(context, w),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : w.section == 'workspace-settings'
          ? ServerSettingsView(
              key: ValueKey('settings-${w.server!.id}'),
              controller: w,
            )
          : w.section == 'sidebar-settings'
          ? SidebarPreferencesView(
              key: ValueKey('sidebar-${w.server!.id}'),
              controller: w,
            )
          : w.section == 'members'
          ? MembersView(key: ValueKey('members-${w.server!.id}'), controller: w)
          : w.section == 'providers'
          ? ProviderConnectionsView(
              key: ValueKey('providers-${w.server!.id}'),
              controller: w,
            )
          : w.section == 'administration'
          ? AdministrationView(
              key: ValueKey('administration-${w.server!.id}'),
              controller: w,
            )
          : w.section == 'billing'
          ? BillingView(key: ValueKey('billing-${w.server!.id}'), controller: w)
          : w.section == 'joint-channels'
          ? JointChannelsView(
              key: ValueKey('joint-channels-${w.server!.id}'),
              controller: w,
            )
          : w.section == 'im-bridges'
          ? IMBridgesView(
              key: ValueKey('bridges-${w.server!.id}'),
              controller: w,
            )
          : w.section == 'integrations'
          ? IntegrationsView(
              key: ValueKey('integrations-${w.server!.id}'),
              controller: w,
            )
          : w.section == 'agents' || w.section == 'computers'
          ? FleetView(
              key: ValueKey('fleet-${w.server!.id}:${w.section}'),
              controller: w,
              computers: w.section == 'computers',
            )
          : w.section == 'chat'
          ? ServerSetupGate(
              controller: w,
              child: RaftChatView(
                controller: w,
                selectionHandle: mainSelection,
              ),
            )
          : ResourceView(
              key: ValueKey('${w.server?.id}:${w.section}'),
              controller: w,
              section: w.section,
              onMessage: (channelId, messageId) async {
                scaffold.currentState?.closeDrawer();
                await w.jumpToMessage(channelId, messageId);
              },
            );
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              select('search'),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              select('search'),
          const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
              select('settings'),
          const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
              select('settings'),
          const SingleActivator(LogicalKeyboardKey.escape): dismissPanel,
        },
        child: PopScope(
          canPop:
              !mainSelection.active &&
              !threadSelection.active &&
              !thread &&
              (wide || w.section == 'chat'),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) dismissPanel();
          },
          child: Scaffold(
            key: scaffold,
            drawer: wide ? null : Drawer(child: sidebar()),
            appBar: wide
                ? null
                : AppBar(
                    title: Text(thread ? tr('Thread') : title),
                    leading: thread
                        ? IconButton(
                            tooltip: tr(
                              threadSelection.active
                                  ? 'Exit selection'
                                  : 'Close thread',
                            ),
                            onPressed: dismissPanel,
                            icon: const Icon(Icons.arrow_back),
                          )
                        : null,
                    actions: [
                      if (w.section == 'chat' && w.channel != null && !thread)
                        IconButton(
                          tooltip: tr('Channel settings'),
                          onPressed: () => channelSettings(),
                          icon: const Icon(Icons.tune),
                        ),
                      IconButton(
                        tooltip: tr('Search messages'),
                        onPressed: () => select('search'),
                        icon: const Icon(Icons.search),
                      ),
                      IconButton(
                        tooltip: tr('Settings'),
                        onPressed: () => select('settings'),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
            body: SafeArea(
              child: Column(
                children: [
                  if (w.error != null)
                    MaterialBanner(
                      content: Text(w.error!),
                      actions: [
                        TextButton(
                          onPressed: () {
                            w.setError(null);
                          },
                          child: Text(tr('Dismiss')),
                        ),
                      ],
                    ),
                  Expanded(
                    child: RaftAdaptiveWorkspace(
                      sidebarWidth: sidebarWidth,
                      threadWidth: threadWidth,
                      onPanelWidthsChanged: savePanels,
                      sidebarResizeLabel: tr('Resize sidebar'),
                      threadResizeLabel: tr('Resize thread'),
                      sidebar: sidebar(),
                      rail: workspaceRail(),
                      mobileNavigation: thread ? null : mobileNavigation(),
                      content: Column(
                        children: [
                          if (wide)
                            Container(
                              height: 58,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: t.line),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (w.section == 'chat')
                                    const Icon(Icons.tag, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Tooltip(
                                    message: w.connected
                                        ? tr('Connected')
                                        : tr('Reconnecting'),
                                    child: Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: w.connected
                                          ? Colors.green
                                          : t.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (w.section == 'chat' && w.channel != null)
                                    IconButton(
                                      tooltip: tr('Channel settings'),
                                      onPressed: () => channelSettings(),
                                      icon: const Icon(Icons.tune, size: 19),
                                    ),
                                  IconButton(
                                    tooltip: tr('Refresh'),
                                    onPressed: () => w.channel == null
                                        ? w.bootstrap()
                                        : w.selectChannel(w.channel!),
                                    icon: const Icon(Icons.refresh, size: 19),
                                  ),
                                ],
                              ),
                            ),
                          if (w.section == 'chat' &&
                              w.channel != null &&
                              !w.channel!.joined &&
                              !w.channel!.archived)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: RaftButton(
                                label: tr('Join channel'),
                                onPressed: () => joinChannel(),
                              ),
                            ),
                          if (w.section == 'chat' &&
                              w.channel?.archived == true)
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                tr(
                                  'This channel is archived. History is available.',
                                ),
                              ),
                            ),
                          Expanded(child: content),
                        ],
                      ),
                      thread: thread
                          ? Column(
                              children: [
                                if (wide)
                                  SizedBox(
                                    height: 58,
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            tr('Thread'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: tr('Close thread'),
                                          onPressed: w.closeThread,
                                          icon: const Icon(Icons.close),
                                        ),
                                      ],
                                    ),
                                  ),
                                Expanded(
                                  child: ServerSetupGate(
                                    controller: w,
                                    child: RaftChatView(
                                      controller: w,
                                      thread: true,
                                      selectionHandle: threadSelection,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  List<RaftRailDestination> get railDestinations => [
    RaftRailDestination(
      id: 'chat',
      label: tr('Chat'),
      icon: Icons.chat_bubble_outline,
    ),
    RaftRailDestination(
      id: 'activity',
      label: tr('Activity'),
      icon: Icons.inbox_outlined,
      unread: w.unread.values.fold(0, (a, b) => a + b),
    ),
    RaftRailDestination(id: 'search', label: tr('Search'), icon: Icons.search),
    RaftRailDestination(
      id: 'tasks',
      label: tr('Tasks'),
      icon: Icons.check_box_outlined,
    ),
    RaftRailDestination(
      id: 'saved',
      label: tr('Saved'),
      icon: Icons.bookmark_border,
    ),
    if (w.can('viewAgents'))
      RaftRailDestination(
        id: 'agents',
        label: tr('Agents'),
        icon: Icons.smart_toy_outlined,
      ),
    if (w.can('viewMachines'))
      RaftRailDestination(
        id: 'computers',
        label: tr('Computers'),
        icon: Icons.computer_outlined,
      ),
    if (w.can('viewMembers'))
      RaftRailDestination(
        id: 'members',
        label: tr('Members'),
        icon: Icons.people_outline,
      ),
  ];

  Widget workspaceRail() => RaftWorkspaceRail(
    destinations: railDestinations,
    selected: w.section,
    onSelected: select,
    workspaceName: w.server?.name ?? 'Raft',
    workspaceTooltip: tr('Switch workspace'),
    onWorkspace: () => showWorkspaceSwitcher(),
    footer: IconButton(
      key: const Key('rail-settings'),
      tooltip: tr('Settings'),
      onPressed: () => select('settings'),
      icon: const Icon(Icons.settings_outlined),
    ),
  );

  Future<void> showWorkspaceSwitcher() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('Switch workspace')),
        children: [
          for (final server in w.servers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, server.id),
              child: ListTile(
                title: Text(server.name),
                trailing: server.id == w.server?.id
                    ? const Icon(Icons.check)
                    : null,
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'create'),
            child: Text(tr('Create workspace')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'join'),
            child: Text(tr('Join workspace')),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'create') {
      await WorkspaceActions.create(context, w);
    } else if (choice == 'join') {
      await WorkspaceActions.join(context, w);
    } else {
      final server = w.servers.where((s) => s.id == choice).firstOrNull;
      if (server != null) await w.selectServer(server);
    }
  }

  Widget mobileNavigation() => NavigationBar(
    key: const Key('workspace-mobile-navigation'),
    selectedIndex: switch (w.section) {
      'activity' => 1,
      'tasks' => 2,
      _ => 0,
    },
    onDestinationSelected: (index) =>
        select(['chat', 'activity', 'tasks'][index]),
    destinations: [
      NavigationDestination(
        icon: const Icon(Icons.chat_bubble_outline),
        label: tr('Chat'),
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: w.unread.values.any((n) => n > 0),
          child: const Icon(Icons.inbox_outlined),
        ),
        label: tr('Activity'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.check_box_outlined),
        label: tr('Tasks'),
      ),
    ],
  );

  void syncSidebarAgents() {
    final ids = [
      for (final r in [
        ...(w.sidebarOrder['pinned'] as List? ?? []),
        ...(w.sidebarOrder['sectionPlacements'] as List? ?? []),
      ])
        if (r is Map && r['kind'] == 'agent') '${r['id']}',
    ]..sort();
    final scope = jsonEncode([
      w.client.generation,
      w.client.user?.id,
      w.server?.id,
      w.server?.string('role'),
      w.can('viewAgents'),
      ids,
    ]);
    if (sidebarAgentScope == scope) return;
    sidebarAgentScope = scope;
    sidebarAgents = [];
    final ticket = ++sidebarAgentRequest;
    if (ids.isEmpty || w.server == null || !w.can('viewAgents')) return;
    () async {
      try {
        final result = await w.query('/agents');
        if (!mounted || ticket != sidebarAgentRequest) return;
        final rows = result is List
            ? result
            : result is Map
            ? result['agents']
            : null;
        setState(() {
          sidebarAgents = (rows as List? ?? [])
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
        });
      } catch (_) {
        // A missing directory does not manufacture an identity. Existing DMs
        // remain usable; refreshing the workspace retries a changed authority.
      }
    }();
  }

  List<SidebarGroup> get sidebarGroups {
    final activity = <String, DateTime>{};
    for (final c in [...w.channels, ...w.dms]) {
      for (final m in w.ledger.messages(c.id)) {
        final stamp = DateTime.tryParse('${m['createdAt'] ?? ''}');
        if (stamp != null &&
            (activity[c.id] == null || stamp.isAfter(activity[c.id]!))) {
          activity[c.id] = stamp;
        }
      }
    }
    return projectSidebar(
      channels: w.channels,
      dms: w.dms,
      preferences: w.sidebarOrder,
      agents: sidebarAgents,
      activity: activity,
    );
  }

  Future<void> chooseSidebarAgent(SidebarEntry entry) async {
    if (entry.channel != null) {
      await chooseChannel(entry.channel!);
      return;
    }
    final authority = workspaceAuthority(w);
    try {
      final result = await w.command(
        'POST',
        '/channels/dm',
        data: {'agentId': entry.agent!['id']},
      );
      if (!mounted || authority != workspaceAuthority(w)) return;
      await w.refreshChannels();
      if (!mounted || authority != workspaceAuthority(w)) return;
      await chooseChannel(RaftChannel(Map<String, dynamic>.from(result)));
    } catch (e) {
      if (mounted && authority == workspaceAuthority(w)) w.setError('$e');
    }
  }

  Widget sidebarEntry(SidebarEntry entry) => entry.agent == null
      ? channelItem(entry.channel!)
      : RaftNavItem(
          key: ValueKey('sidebar-${entry.key}'),
          label: entry.label,
          icon: Icons.smart_toy_outlined,
          selected:
              w.section == 'chat' &&
              entry.channel != null &&
              w.channel?.id == entry.channel!.id,
          unread: w.unread[entry.channel?.id] ?? 0,
          onTap: () => chooseSidebarAgent(entry),
        );

  List<Widget> conversationSections() => [
    for (final group in sidebarGroups)
      if (group.entries.isNotEmpty ||
          group.custom ||
          group.id == 'system:channels' ||
          group.id == 'system:dms') ...[
        sectionLabel(
          group.custom ? group.label : tr(group.label),
          onAdd: group.id == 'system:channels' && w.can('createChannels')
              ? () => createChannel()
              : group.id == 'system:dms'
              ? () => newConversation()
              : null,
          addLabel: group.id == 'system:dms'
              ? tr('New direct message')
              : tr('Create channel'),
        ),
        ...group.entries.map(sidebarEntry),
        const SizedBox(height: 18),
      ],
  ];
  Widget channelItem(RaftChannel c) => RaftNavItem(
    key: ValueKey('sidebar-channel-${c.id}'),
    label: c.type == 'dm'
        ? c.string('peerDisplayName', c.string('peerName', c.name))
        : c.name,
    icon: c.type == 'dm'
        ? Icons.person_outline
        : c.archived
        ? Icons.archive_outlined
        : c.type == 'private'
        ? Icons.lock_outline
        : c.type == 'joint'
        ? Icons.link
        : Icons.tag,
    selected: w.section == 'chat' && w.channel?.id == c.id,
    unread: w.unread[c.id] ?? 0,
    onTap: () => chooseChannel(c),
  );
  Widget sidebar() => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Row(
            children: [
              const Text(
                'Raft',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: tr('Switch workspace'),
                onSelected: (value) async {
                  scaffold.currentState?.closeDrawer();
                  if (value == 'create') {
                    await WorkspaceActions.create(context, w);
                  } else if (value == 'join') {
                    await WorkspaceActions.join(context, w);
                  } else if (value == 'settings') {
                    select('workspace-settings');
                  } else {
                    await w.selectServer(
                      w.servers.firstWhere((s) => s.id == value),
                    );
                  }
                },
                itemBuilder: (_) => [
                  for (final s in w.servers)
                    PopupMenuItem(
                      value: s.id,
                      child: Listener(
                        onPointerDown:
                            defaultTargetPlatform == TargetPlatform.linux &&
                                workspaceBrowserOrigin(w.client.origin) != null
                            ? (event) {
                                if (event.buttons == kMiddleMouseButton) {
                                  Navigator.of(context).pop();
                                  unawaited(
                                    openWorkspaceInBrowser(context, w, s),
                                  );
                                }
                              }
                            : null,
                        child: Row(
                          children: [
                            Expanded(child: Text(s.name)),
                            if (defaultTargetPlatform == TargetPlatform.linux &&
                                workspaceBrowserOrigin(w.client.origin) != null)
                              IconButton(
                                key: ValueKey('workspace-browser-${s.id}'),
                                tooltip: tr('Open workspace in browser'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  unawaited(
                                    openWorkspaceInBrowser(context, w, s),
                                  );
                                },
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: const Icon(Icons.open_in_new),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const PopupMenuDivider(),
                  if (w.server != null)
                    PopupMenuItem(
                      value: 'settings',
                      child: Text(tr('Workspace settings')),
                    ),
                  PopupMenuItem(
                    value: 'create',
                    child: Text(tr('Create workspace')),
                  ),
                  PopupMenuItem(
                    value: 'join',
                    child: Text(tr('Join workspace')),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 115),
                      child: Text(
                        w.server?.name ?? tr('Workspace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            key: const Key('workspace-sidebar'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            children: [
              RaftNavItem(
                key: const Key('nav-activity'),
                label: tr('Activity'),
                icon: Icons.inbox_outlined,
                selected: w.section == 'activity',
                unread: w.unread.values.fold(0, (a, b) => a + b),
                onTap: () => select('activity'),
              ),
              RaftNavItem(
                key: const Key('nav-search'),
                label: tr('Search'),
                icon: Icons.search,
                selected: w.section == 'search',
                onTap: () => select('search'),
              ),
              RaftNavItem(
                key: const Key('nav-saved'),
                label: tr('Saved'),
                icon: Icons.bookmark_border,
                selected: w.section == 'saved',
                onTap: () => select('saved'),
              ),
              RaftNavItem(
                key: const Key('nav-tasks'),
                label: tr('Tasks'),
                icon: Icons.check_box_outlined,
                selected: w.section == 'tasks',
                onTap: () => select('tasks'),
              ),
              const SizedBox(height: 18),
              ...conversationSections(),
              sectionLabel(tr('WORKSPACE')),
              if (w.can('viewAgents'))
                RaftNavItem(
                  key: const Key('nav-agents'),
                  label: tr('Agents'),
                  icon: Icons.smart_toy_outlined,
                  onTap: () => select('agents'),
                  selected: w.section == 'agents',
                ),
              if (w.can('viewMachines'))
                RaftNavItem(
                  key: const Key('nav-computers'),
                  label: tr('Computers'),
                  icon: Icons.computer_outlined,
                  onTap: () => select('computers'),
                  selected: w.section == 'computers',
                ),
              if (w.can('viewMembers'))
                RaftNavItem(
                  key: const Key('nav-members'),
                  label: tr('Members'),
                  icon: Icons.people_outline,
                  onTap: () => select('members'),
                  selected: w.section == 'members',
                ),
              if (w.can('manageIntegrations'))
                RaftNavItem(
                  key: const Key('nav-integrations'),
                  label: tr('Integrations'),
                  icon: Icons.extension_outlined,
                  onTap: () => select('integrations'),
                  selected: w.section == 'integrations',
                ),
              if (w.can('federateChannels'))
                RaftNavItem(
                  key: const Key('nav-joint-channels'),
                  label: tr('Joint channels'),
                  icon: Icons.link,
                  onTap: () => select('joint-channels'),
                  selected: w.section == 'joint-channels',
                ),
              if (bridgeEnabled && w.can('manageIntegrations'))
                RaftNavItem(
                  key: const Key('nav-im-bridges'),
                  label: tr('IM bridges'),
                  icon: Icons.hub_outlined,
                  onTap: () => select('im-bridges'),
                  selected: w.section == 'im-bridges',
                ),
              if (w.can('manageExternalAuth'))
                RaftNavItem(
                  key: const Key('nav-providers'),
                  label: tr('Provider connections'),
                  icon: Icons.vpn_key_outlined,
                  onTap: () => select('providers'),
                  selected: w.section == 'providers',
                ),
              if (w.can('viewServerSettings'))
                RaftNavItem(
                  key: const Key('nav-administration'),
                  label: tr('Administration'),
                  icon: Icons.admin_panel_settings_outlined,
                  onTap: () => select('administration'),
                  selected: w.section == 'administration',
                ),
              if (w.can('viewBilling'))
                RaftNavItem(
                  key: const Key('nav-billing'),
                  label: tr('Billing'),
                  icon: Icons.receipt_long_outlined,
                  onTap: () => select('billing'),
                  selected: w.section == 'billing',
                ),
              if (w.server != null)
                RaftNavItem(
                  key: const Key('nav-sidebar-settings'),
                  label: tr('Sidebar preferences'),
                  icon: Icons.view_sidebar_outlined,
                  onTap: () => select('sidebar-settings'),
                  selected: w.section == 'sidebar-settings',
                ),
              if (w.server != null)
                RaftNavItem(
                  key: const Key('nav-workspace-settings'),
                  label: tr('Workspace settings'),
                  icon: Icons.settings_outlined,
                  onTap: () => select('workspace-settings'),
                  selected: w.section == 'workspace-settings',
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        RaftNavItem(
          key: const Key('account-navigation'),
          label: w.client.user?.name ?? tr('Account'),
          icon: Icons.account_circle_outlined,
          onTap: () => select('settings'),
          selected: w.section == 'settings',
        ),
      ],
    ),
  );
  Widget sectionLabel(
    String label, {
    VoidCallback? onAdd,
    String addLabel = 'Create channel',
  }) => Padding(
    padding: const EdgeInsets.only(left: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: RaftTokens.of(context).muted,
              letterSpacing: 1,
            ),
          ),
        ),
        if (onAdd != null)
          IconButton(
            tooltip: addLabel,
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
          )
        else
          const SizedBox(height: 32),
      ],
    ),
  );
  Future<void> joinChannel() async {
    try {
      final c = w.channel!;
      await w.command('POST', '/channels/${c.id}/join');
      await w.refreshChannels();
      await w.selectChannel(w.channels.firstWhere((next) => next.id == c.id));
    } catch (e) {
      w.setError('$e');
    }
  }

  Future<void> channelSettings() async {
    if (w.channel == null) return;
    await showDialog(
      context: context,
      builder: (_) => ChannelSettings(controller: w, channel: w.channel!),
    );
  }

  Future<void> newConversation() async {
    try {
      final lists = await Future.wait([
        w.query('/servers/${w.server!.id}/members'),
        w.query('/agents'),
      ]);
      if (!mounted) return;
      final people = [
        for (final p in lists[0] as List)
          {
            ...Map<String, dynamic>.from(p),
            'target': 'userId',
            'targetId': p['userId'] ?? p['id'],
          },
        for (final p in lists[1] as List)
          {
            ...Map<String, dynamic>.from(p),
            'target': 'agentId',
            'targetId': p['id'],
          },
      ];
      final person = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(tr('New direct message')),
          children: [
            for (final person in people.where(
              (p) => p['targetId'] != w.client.user!.id,
            ))
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, person),
                child: ListTile(
                  leading: RaftAvatar(
                    name: '${person['displayName'] ?? person['name']}',
                  ),
                  title: Text('${person['displayName'] ?? person['name']}'),
                  subtitle: Text(
                    person['target'] == 'agentId' ? 'Agent' : 'Member',
                  ),
                ),
              ),
          ],
        ),
      );
      if (person != null) {
        final result = await w.command(
          'POST',
          '/channels/dm',
          data: {person['target']: person['targetId']},
        );
        await w.refreshChannels();
        await chooseChannel(RaftChannel(Map<String, dynamic>.from(result)));
      }
    } catch (e) {
      w.setError('$e');
    }
  }

  Future<void> createChannel() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => RaftFormDialog(
        title: tr('Create channel'),
        submitLabel: tr('Create'),
        fields: [
          RaftFormField('name', 'Channel name', required: true),
          RaftFormField('description', 'Description', multiline: true),
          RaftFormField(
            'visibility',
            'Visibility',
            initial: 'public',
            choices: {'public': 'Public channel', 'private': 'Private channel'},
          ),
        ],
        onSubmit: (values) async {
          final result = await w.command(
            'POST',
            '/channels',
            data: {
              'name': values['name'],
              'description': values['description'],
              'visibility': values['visibility'],
              'type': 'channel',
            },
          );
          await w.refreshChannels();
          await chooseChannel(RaftChannel(Map<String, dynamic>.from(result)));
        },
      ),
    );
  }

  Widget settings() => ListView(
    key: const Key('workspace-account-settings'),
    padding: const EdgeInsets.all(24),
    children: [
      Text(tr('Appearance'), style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      Text(tr('Mode')),
      const SizedBox(height: 10),
      SegmentedButton<ThemeMode>(
        segments: [
          ButtonSegment(
            value: ThemeMode.light,
            label: Text(tr('Light')),
            icon: Icon(Icons.light_mode_outlined),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text(tr('Dark')),
            icon: Icon(Icons.dark_mode_outlined),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            label: Text(tr('System')),
            icon: Icon(Icons.brightness_auto),
          ),
        ],
        selected: {widget.appearance.mode},
        onSelectionChanged: (s) =>
            widget.onAppearance(widget.appearance.copyWith(mode: s.first)),
      ),
      const SizedBox(height: 24),
      Text(tr('Day theme')),
      const SizedBox(height: 10),
      SegmentedButton<RaftFamily>(
        segments: [
          ButtonSegment(value: RaftFamily.brutal, label: Text(tr('Brutal'))),
          ButtonSegment(value: RaftFamily.elegant, label: Text(tr('Elegant'))),
        ],
        selected: {widget.appearance.light},
        onSelectionChanged: (s) =>
            widget.onAppearance(widget.appearance.copyWith(light: s.first)),
      ),
      const SizedBox(height: 16),
      Text(tr('Night theme: Elegant')),
      const SizedBox(height: 32),
      AccountSettings(controller: w),
      if (widget.notifications != null) ...[
        const SizedBox(height: 24),
        RaftPanel(
          child: NotificationSettingsView(service: widget.notifications!),
        ),
      ],
      const SizedBox(height: 24),
      Align(
        alignment: Alignment.centerLeft,
        child: RaftButton(
          label: tr('Sign out'),
          secondary: true,
          icon: Icons.logout,
          onPressed: widget.onLogout,
        ),
      ),
    ],
  );
}
