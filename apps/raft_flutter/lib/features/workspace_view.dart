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
import '../data/workspace_mode_store.dart';
import 'workspace_grid_view.dart';
import '../data/personal_presentation.dart';
import '../data/sidebar_disclosure.dart';
import 'message_reference_directory.dart';
import 'chat_agent_presentation.dart';
import 'live_agent_activity_bar.dart';
import 'chat_view.dart';
import 'thread_actions.dart';
import 'conversation_panel.dart';
import 'message_selection.dart';

import 'package:flutter/scheduler.dart';

import 'resource_view.dart';
import 'page_layout.dart';
import 'channel_settings.dart';
import 'create_channel_dialog.dart';
import 'workspace_settings.dart';
import 'server_views.dart';
import 'mobile_workspace_navigation.dart';
import 'desktop_navigation_policy.dart';
import 'desktop_master_detail.dart';
import 'desktop_directory_view.dart';
import 'desktop_activity_flag.dart';
import 'resource_search.dart';
import 'member_profile_view.dart';
import 'fleet_views.dart';
import 'integrations_views.dart';
import 'provider_views.dart';
import 'admin_views.dart';
import 'private_route_guard.dart';
import 'server_setup_gate.dart';
import 'sidebar_preferences_view.dart';
import 'sidebar_projection.dart';
import 'sidebar_sort_menu.dart';
import 'saved_sidebar_entry.dart';
import 'system_notification_center.dart';
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
    this.presentation,
  });
  final WorkspaceController controller;
  final NativeNotificationService? notifications;
  final NativeSharing? sharing;
  final PersonalPresentationStore? presentation;

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
  int searchEntryRevision = 0;
  String? channelSearchSeed, channelSearchAuthority;
  bool channelSearchRevoked = false;

  void syncChannelSearch() {
    if (channelSearchSeed == null) return;
    final channel = w.channels
        .where((c) => c.id == channelSearchSeed)
        .firstOrNull;
    if (channelSearchAuthority != workspaceAuthority(w) ||
        channel == null ||
        !w.can('viewChannel', resource: channel)) {
      channelSearchSeed = channelSearchAuthority = null;
      channelSearchRevoked = w.section == 'search';
    }
  }

  void searchThisChannel() {
    final channel = w.channel;
    if (channel == null || !w.can('viewChannel', resource: channel)) return;
    select('search', searchChannelId: channel.id);
  }

  final desktopNavigation = DesktopNavigationState();
  bool pendingDesktopSelection = false;
  String get desktopAuthority => '$mobileAuthority|$channelAuthorityRevision';
  int mobileSettingsRevision = 0;
  bool mobileSettingsDetail = false;
  String get mobileAuthority => jsonEncode([
    identityHashCode(w),
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ]);
  String? mobileRouteAuthority;
  bool mobileRouteInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasMobile = w.mobileNavigation;
    w.mobileNavigation = !wide;
    if (wasMobile && wide && w.section == 'home') {
      w.section = 'chat';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && wide && w.section == 'chat') {
          w.setForeground(w.foreground);
        }
      });
    }
    if (!mobileRouteInitialized) {
      mobileRouteInitialized = true;
      if (!wide && w.section == 'chat' && w.threadParent == null) {
        // The production controller starts Home before bootstrap. This also
        // normalizes manually supplied controllers without rendering Chat.
        w.section = 'home';
      }
    }
  }

  void selectMobileTab(String tab, String scope) {
    if (!mounted || scope != mobileAuthority || wide) {
      return;
    }
    if (tab == 'members' &&
        (w.server?.string('role') == 'guest' || !w.can('viewMembers'))) {
      return;
    }
    if (!['chat', 'tasks', 'members', 'settings'].contains(tab)) {
      return;
    }
    mainSelection.dismiss();
    threadSelection.dismiss();
    w.closeThread();
    setState(() {
      mobileSettingsDetail = false;
      mobileSettingsRevision++;
    });
    select(tab == 'chat' ? 'home' : tab);
  }

  late final ownedPresentation = PersonalPresentationStore(
    desktop:
        !kIsWeb &&
        [
          TargetPlatform.linux,
          TargetPlatform.macOS,
          TargetPlatform.windows,
        ].contains(defaultTargetPlatform),
  );
  PersonalPresentationStore get presentation =>
      widget.presentation ?? ownedPresentation;
  final sidebarDisclosure = SidebarDisclosureStore();
  final sortAnchors = <String, GlobalKey>{};
  final sortingGroups = <String>{};
  void syncSidebarDisclosure() {
    unawaited(
      sidebarDisclosure.bind(
        origin: w.client.origin,
        principal: w.client.user?.id,
        server: w.server?.id,
        scope: mobileAuthority,
      ),
    );
  }

  late DesktopActivityFlag activityFlag;
  void activityFlagChanged() {
    if (mounted) setState(() {});
  }

  late MessageReferenceDirectory activityDirectory;
  late ChatAgentPresentation liveActivities;
  void syncPresentation() {
    unawaited(
      presentation.bind(
        w.client.origin,
        w.client.user?.id,
        profileFont: w.client.user?.string('preferredMessageBodyFontSize'),
      ),
    );
  }

  Widget liveActivityBar() => NativeLiveAgentActivityBar(
    activities: liveActivities,
    presentation: presentation,
    origin: w.client.origin,
  );
  bool get wide =>
      MediaQuery.sizeOf(context).width >= RaftAdaptiveWorkspace.desktopMinWidth;
  double sidebarWidth = 240, threadWidth = 400;
  double masterWideWidth = 560, masterCompactWidth = 320;
  Timer? persistPanels;
  String? sidebarAgentScope;
  List<Map<String, dynamic>> sidebarAgents = [];
  int sidebarAgentRequest = 0;
  VoidCallback? removeShareReceiver;
  bool sharingReady = false,
      reviewingIncoming = false,
      bridgeEnabled = false,
      providerEnabled = false;
  String? shareReceiverScope, bridgeScope;
  int bridgeRequest = 0;
  String tr(String source) => raftText(context, source);

  @override
  void initState() {
    super.initState();
    workspaceMode = WorkspaceModeStore(w);
    activityFlag = DesktopActivityFlag(w)..addListener(activityFlagChanged);
    activityDirectory = MessageReferenceDirectory(w);
    liveActivities = ChatAgentPresentation(w, activityDirectory);
    w.addListener(syncChannelSearch);
    w.addListener(syncPresentation);
    syncPresentation();
    w.addListener(syncSidebarDisclosure);
    syncSidebarDisclosure();
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

  late WorkspaceModeStore workspaceMode;
  final gridKey = GlobalKey<WorkspaceGridViewState>();
  int classicEditorRevision = 0;
  bool lastGridActive = false;
  bool gridEntered = false;
  Size? retainedGridSize;
  String? classicDraftScope, classicDraftAtEntry;
  bool get gridActive => workspaceMode.active(MediaQuery.sizeOf(context).width);

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
      w.can('manageExternalAuth'),
    ]);
    if (bridgeScope == next) return;
    bridgeScope = next;
    bridgeEnabled = false;
    providerEnabled = false;
    final request = ++bridgeRequest;
    if (w.server == null ||
        (!w.can('manageIntegrations') && !w.can('manageExternalAuth'))) {
      return;
    }
    () async {
      try {
        final result = await w.client.post(
          '/feature-flags/evaluate',
          data: {
            'keys': ['slack_bridge_v0', 'provider_connections_v0'],
            'serverId': w.server!.id,
            'platform':
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS)
                ? 'mobile'
                : 'web',
          },
        );
        if (!mounted || request != bridgeRequest) return;
        final rows = result is Map
            ? result['evaluations'] as List? ?? []
            : const [];
        setState(() {
          providerEnabled = rows.whereType<Map>().any(
            (f) =>
                f['key'] == 'provider_connections_v0' && f['enabled'] == true,
          );
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
      mobileRouteInitialized = false;
      mobileRouteAuthority = null;
      w.mobileNavigation = !wide;
      oldWidget.controller.releaseConversationPresentation(this);
      oldWidget.controller.removeListener(syncChannelSearch);
      channelSearchSeed = channelSearchAuthority = null;
      channelSearchRevoked = false;
      w.addListener(syncChannelSearch);
      oldWidget.controller.removeListener(syncPresentation);
      oldWidget.controller.removeListener(syncSidebarDisclosure);
      liveActivities.dispose();
      activityDirectory.dispose();
      activityFlag.removeListener(activityFlagChanged);
      activityFlag.dispose();
      workspaceMode.dispose();
      workspaceMode = WorkspaceModeStore(w);
      activityFlag = DesktopActivityFlag(w)..addListener(activityFlagChanged);
      activityDirectory = MessageReferenceDirectory(w);
      liveActivities = ChatAgentPresentation(w, activityDirectory);
      w.addListener(syncPresentation);
      syncPresentation();
      w.addListener(syncSidebarDisclosure);
      syncSidebarDisclosure();
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
      masterWideWidth = prefs.getDouble('raft.layout.masterWideWidth') ?? 560;
      masterCompactWidth =
          prefs.getDouble('raft.layout.masterCompactWidth') ?? 320;
    });
  }

  void saveMasterPanel(double value, bool compact) {
    setState(() {
      if (compact) {
        masterCompactWidth = value;
      } else {
        masterWideWidth = value;
      }
    });
    savePanels(sidebarWidth, threadWidth);
  }

  void savePanels(double sidebar, double thread) {
    sidebarWidth = sidebar;
    threadWidth = thread;
    persistPanels?.cancel();
    persistPanels = Timer(const Duration(milliseconds: 250), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('raft.layout.sidebarWidth', sidebarWidth);
      await prefs.setDouble('raft.layout.threadWidth', threadWidth);
      await prefs.setDouble('raft.layout.masterWideWidth', masterWideWidth);
      await prefs.setDouble(
        'raft.layout.masterCompactWidth',
        masterCompactWidth,
      );
    });
  }

  @override
  void dispose() {
    workspaceMode.dispose();
    persistPanels?.cancel();
    w.releaseConversationPresentation(this);
    w.removeListener(syncChannelSearch);
    w.removeListener(syncPresentation);
    w.removeListener(syncSidebarDisclosure);
    sidebarDisclosure.dispose();
    liveActivities.dispose();
    activityDirectory.dispose();
    activityFlag.removeListener(activityFlagChanged);
    activityFlag.dispose();
    ownedPresentation.dispose();
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
    } else if (wide &&
        desktopNavigation.target?.kind == DesktopContentKind.thread) {
      closeDesktopDetail();
    } else if (w.threadParent != null && w.section == 'chat') {
      w.closeThread();
    } else if (wide && desktopNavigation.target != null) {
      closeDesktopDetail();
    } else if (!wide && w.section == 'settings' && mobileSettingsDetail) {
      setState(() {
        mobileSettingsDetail = false;
        mobileSettingsRevision++;
      });
    } else if (!wide && w.section != 'home') {
      select(mobileWorkspaceBackSection(w.section));
    } else if (w.section != 'chat' && w.section != 'home') {
      select('chat');
    }
  }

  void select(String section, {String? searchChannelId}) {
    if (!w.canVisitSection(section)) return;
    desktopNavigation.bind(desktopAuthority);
    desktopNavigation.selectRoute(section);
    pendingDesktopSelection = false;
    if (section == 'search') {
      setState(() {
        searchEntryRevision++;
        channelSearchSeed = searchChannelId;
        channelSearchAuthority = searchChannelId == null
            ? null
            : workspaceAuthority(w);
        channelSearchRevoked = false;
      });
    } else {
      channelSearchSeed = channelSearchAuthority = null;
      channelSearchRevoked = false;
    }
    if (w.section == 'administration' || section == 'settings') {
      bridgeScope = null;
      syncBridgeFlag();
    }
    w.setSection(section);
    scaffold.currentState?.closeDrawer();
  }

  Future<void> chooseChannel(RaftChannel c, {String? expectedScope}) async {
    if (!mounted || expectedScope != null && expectedScope != mobileAuthority) {
      return;
    }
    final fresh = [
      ...w.channels,
      ...w.dms,
    ].where((row) => row.id == c.id).firstOrNull;
    if (fresh == null && expectedScope != null) {
      return;
    }
    scaffold.currentState?.closeDrawer();
    if (gridActive && gridKey.currentState?.openChannel(c.id) == true) {
      w.setSection('chat');
      return;
    }
    desktopNavigation.clear();
    await w.selectChannel(fresh ?? c);
  }

  @override
  Widget build(BuildContext context) => PersonalPresentationScope(
    store: presentation,
    child: buildWorkspace(context),
  );
  Widget buildWorkspace(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      w,
      presentation,
      liveActivities,
      sidebarDisclosure,
      workspaceMode,
    ]),
    builder: (context, _) {
      if (!lastGridActive && gridActive) {
        classicDraftScope = w.draftScope();
        classicDraftAtEntry = w.drafts[classicDraftScope] ?? '';
      }
      if (lastGridActive && !gridActive) {
        gridKey.currentState?.flushDrafts();
        // Hydrate only an editor whose own text changed in the grid. A draft
        // in a different tab must not reset the retained classic cursor.
        if (classicDraftScope == w.draftScope() &&
            classicDraftAtEntry != (w.drafts[classicDraftScope] ?? '')) {
          classicEditorRevision++;
        }
      }
      lastGridActive = gridActive;
      if (gridActive) gridEntered = true;
      if (!workspaceMode.enabled || !workspaceMode.showCard) {
        gridEntered = false;
        retainedGridSize = null;
      }
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
      if (mobileRouteAuthority != mobileAuthority) {
        mobileRouteAuthority = mobileAuthority;
        mobileSettingsDetail = false;
        mobileSettingsRevision++;
      }
      desktopNavigation.bind(desktopAuthority);
      if (wide &&
          desktopNavigation.masterRoute == null &&
          ['search', 'activity'].contains(w.section)) {
        desktopNavigation.selectRoute(w.section);
      }
      final route = wide
          ? desktopNavigation.visibleRoute(w.section)
          : w.section;
      final t = RaftTokens.of(context);
      final thread =
          w.section == 'chat' &&
          w.threadParent != null &&
          !(wide &&
              desktopNavigation.target?.kind == DesktopContentKind.thread);
      final title = route == 'chat' || route == 'home'
          ? (w.channel?.name ?? tr('Workspace'))
          : tr(switch (route) {
              'workspace-settings' => 'Workspace settings',
              'activity' => 'Activity',
              'settings' => 'Settings',
              'providers' => 'Provider connections',
              'sidebar-settings' => 'Sidebar preferences',
              'im-bridges' => 'IM bridges',
              'joint-channels' => 'Joint channels',
              _ => route[0].toUpperCase() + route.substring(1),
            });
      // Mobile home keeps the sidebar mounted while the lists load and shows
      // SidebarRowsSkeleton rows (Sidebar.tsx channelsLoading), not a spinner.
      final homeSkeleton = route == 'home' && !wide && w.server != null;
      Widget content = w.loading && !homeSkeleton
          ? const Center(child: CircularProgressIndicator())
          : route == 'settings'
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
          : route == 'workspace-settings'
          ? ServerSettingsView(
              key: ValueKey('settings-${w.server!.id}'),
              controller: w,
            )
          : route == 'sidebar-settings'
          ? SidebarPreferencesView(
              key: ValueKey('sidebar-${w.server!.id}'),
              controller: w,
            )
          : route == 'members'
          ? wide
                ? DesktopDirectoryView(
                    key: ValueKey('directory-$desktopAuthority'),
                    controller: w,
                    selected: desktopNavigation.target,
                    onSelected: selectDesktopDirectoryTarget,
                  )
                : MembersView(
                    key: ValueKey('members-${w.server!.id}'),
                    controller: w,
                    mobileRoot: !wide,
                  )
          : route == 'providers'
          ? ProviderConnectionsView(
              key: ValueKey('providers-${w.server!.id}'),
              controller: w,
            )
          : route == 'administration'
          ? AdministrationView(
              key: ValueKey('administration-${w.server!.id}'),
              controller: w,
            )
          : route == 'billing'
          ? BillingView(key: ValueKey('billing-${w.server!.id}'), controller: w)
          : route == 'joint-channels'
          ? JointChannelsView(
              key: ValueKey('joint-channels-${w.server!.id}'),
              controller: w,
            )
          : route == 'im-bridges'
          ? IMBridgesView(
              key: ValueKey('bridges-${w.server!.id}'),
              controller: w,
            )
          : route == 'integrations'
          ? IntegrationsView(
              key: ValueKey('integrations-${w.server!.id}'),
              controller: w,
            )
          : route == 'agents' || route == 'computers'
          ? wide
                ? DesktopDirectoryView(
                    key: ValueKey('directory-$desktopAuthority-$route'),
                    controller: w,
                    computers: route == 'computers',
                    selected: desktopNavigation.target,
                    onSelected: selectDesktopDirectoryTarget,
                  )
                : FleetView(
                    key: ValueKey('fleet-${w.server!.id}:$route'),
                    controller: w,
                    computers: route == 'computers',
                  )
          : route == 'home' && !wide
          ? Material(
              key: const Key('workspace-mobile-home'),
              color: RaftSidebarRecipe(
                t,
                viewportWidth: MediaQuery.sizeOf(context).width,
                viewportHeight: MediaQuery.sizeOf(context).height,
                variant: RaftSidebarVariant.mountedProduct,
              ).bodyBackground,
              child: sidebar(mobileHome: true),
            )
          : route == 'chat' || route == 'home'
          ? ServerSetupGate(
              controller: w,
              child: ConversationPanel(
                controller: w,
                selectionHandle: mainSelection,
              ),
            )
          : route == 'search' && channelSearchRevoked
          ? Center(child: Text(tr('Channel is no longer available')))
          : ResourceView(
              key: ValueKey(
                '${w.server?.id}:$route:${route == 'search' ? '$searchEntryRevision:$channelSearchSeed:$channelSearchAuthority' : 0}',
              ),
              controller: w,
              section: route,
              restoreSearchState: searchEntryRevision == 0,
              initialSearchDeferUntilQuery:
                  route == 'search' && channelSearchSeed != null,
              initialSearchChannelId: route == 'search'
                  ? channelSearchSeed
                  : null,
              onBack: dismissPanel,
              onSearchEntity: wide ? openDesktopEntity : null,
              onActivityItem:
                  wide &&
                      activityFlag.masterDetail(
                        MediaQuery.sizeOf(context).width,
                      )
                  ? openDesktopActivity
                  : null,
              onMessage: (channelId, messageId) async {
                scaffold.currentState?.closeDrawer();
                if (wide &&
                    (route == 'search' ||
                        route == 'activity' &&
                            activityFlag.masterDetail(
                              MediaQuery.sizeOf(context).width,
                            ))) {
                  await openDesktopConversation(channelId, messageId);
                } else {
                  desktopNavigation.clear();
                  await w.jumpToMessage(channelId, messageId);
                }
              },
            );
      if (wide && ['members', 'agents', 'computers'].contains(route)) {
        content = DesktopMasterDetail(
          master: content,
          directoryWidth: sidebarWidth,
          onWidthChanged: (value, _) {
            setState(() => sidebarWidth = value);
            savePanels(value, threadWidth);
          },
          detail: desktopContentDetail() ?? const SizedBox.expand(),
        );
      }
      if (wide &&
          DesktopNavigationPolicy.forSection(route).contentMasterDetail) {
        content = DesktopMasterDetail(
          master: content,
          detail: desktopContentDetail(),
          compact: thread,
          wideWidth: masterWideWidth,
          compactWidth: masterCompactWidth,
          onWidthChanged: saveMasterPanel,
        );
      }
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
              (wide || w.section == 'home'),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) dismissPanel();
          },
          child: Scaffold(
            key: scaffold,
            drawer: wide ? null : Drawer(child: sidebar()),
            body: SafeArea(
              child: Column(
                children: [
                  if (!wide &&
                      (thread ||
                          ![
                            'home',
                            'tasks',
                            'saved',
                            'activity',
                            'search',
                            'members',
                            'settings',
                          ].contains(route)))
                    mobilePageHeader(title, thread),
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
                      onPresentationChanged: (main, thread) =>
                          w.setConversationPresentation(
                            this,
                            main: main && !gridActive,
                            thread: thread && !gridActive,
                          ),
                      sidebarWidth: sidebarWidth,
                      threadWidth: threadWidth,
                      onPanelWidthsChanged: savePanels,
                      sidebarResizeLabel: tr('Resize sidebar'),
                      threadResizeLabel: tr('Resize thread'),
                      sidebarVisible:
                          gridActive ||
                          DesktopNavigationPolicy.forSection(route)
                              .usesConversationSidebar,
                      sidebar: sidebar(),
                      rail: workspaceRail(),
                      mobileNavigationFloating: !t.brutal,
                      mobileNavigation:
                          mobileWorkspaceRootTab(
                                    w.section,
                                    threadOpen: thread,
                                    settingsDetail: mobileSettingsDetail,
                                  ) ==
                                  null ||
                              w.server == null
                          ? null
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [liveActivityBar(), mobileNavigation()],
                            ),
                      content: Stack(
                        fit: StackFit.expand,
                        children: [
                          Offstage(
                            offstage: gridActive,
                            child: ExcludeFocus(
                              excluding: gridActive,
                              child: TickerMode(
                                enabled: !gridActive,
                                child: Column(
                                  children: [
                                    if (wide &&
                                        ![
                                          'home',
                                          'tasks',
                                          'saved',
                                          'activity',
                                          'search',
                                          'members',
                                        ].contains(w.section))
                                      w.section == 'chat' &&
                                              w.channel != null &&
                                              [
                                                'channel',
                                                'private',
                                                'joint',
                                              ].contains(w.channel!.type)
                                          ? channelHeader()
                                          : RaftPageHeader(
                                              title: w.section == 'home'
                                                  ? (w.channel?.name ?? title)
                                                  : title,
                                              height: raftPageHeaderHeight(
                                                context,
                                              ),
                                              icon: RaftIcon(
                                                sectionGlyph(w.section),
                                              ),
                                              subtitle: w.section == 'chat'
                                                  ? w.channel?.string(
                                                      'description',
                                                    )
                                                  : null,
                                              actions: [
                                                Tooltip(
                                                  message: w.connected
                                                      ? tr('Connected')
                                                      : tr('Reconnecting'),
                                                  child: Icon(
                                                    Icons.circle,
                                                    size: 8,
                                                    color: w.connected
                                                        ? t.colors['success']
                                                        : t.muted,
                                                  ),
                                                ),
                                                if (w.section == 'chat' &&
                                                    w.channel != null)
                                                  RaftIconButton(
                                                    tooltip: 'Channel settings',
                                                    onPressed: () =>
                                                        channelSettings(),
                                                    glyph: RaftGlyph
                                                        .slidersHorizontal,
                                                  ),
                                                RaftIconButton(
                                                  tooltip: 'Refresh',
                                                  onPressed: () =>
                                                      w.channel == null
                                                      ? w.bootstrap()
                                                      : w.selectChannel(
                                                          w.channel!,
                                                        ),
                                                  glyph: RaftGlyph.refreshCw,
                                                ),
                                              ],
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
                                    Expanded(
                                      child: KeyedSubtree(
                                        key: ValueKey(
                                          'classic-editor-$classicEditorRevision',
                                        ),
                                        child: content,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (gridEntered)
                            Positioned.fill(
                              child: Offstage(
                                offstage: !gridActive,
                                child: ExcludeFocus(
                                  excluding: !gridActive,
                                  child: TickerMode(
                                    enabled: gridActive,
                                    child: LayoutBuilder(
                                      builder: (context, bounds) {
                                        if (gridActive) {
                                          retainedGridSize = bounds.biggest;
                                        }
                                        final capturedAuthority =
                                            workspaceMode.authority;
                                        final size =
                                            retainedGridSize ?? bounds.biggest;
                                        // Hidden grid editors retain their last admitted
                                        // layout; shrinking the classic mobile host must
                                        // not lay out two desktop tabsets at phone width.
                                        return OverflowBox(
                                          alignment: Alignment.topLeft,
                                          minWidth: size.width,
                                          maxWidth: size.width,
                                          minHeight: size.height,
                                          maxHeight: size.height,
                                          child: WorkspaceGridView(
                                            key: gridKey,
                                            controller: w,
                                            route: route,
                                            routeBody: content,
                                            active: gridActive,
                                            onRouteSelected: (next) {
                                              if (!mounted ||
                                                  !gridActive ||
                                                  capturedAuthority !=
                                                      workspaceMode.authority) {
                                                return;
                                              }
                                              select(next);
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      thread: thread && !gridActive
                          ? RaftConversationSurface(
                              role: RaftConversationSurfaceRole.threadTimeline,
                              child: Column(
                                children: [
                                  if (wide) sourceThreadHeader(),
                                  Expanded(
                                    child: ServerSetupGate(
                                      controller: w,
                                      child: RaftChatView(
                                        controller: w,
                                        thread: true,
                                        viewportHandle: threadViewport,
                                        selectionHandle: threadSelection,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
  final threadViewport = ChatViewportHandle();
  Widget sourceThreadHeader({bool mobile = false}) => RaftThreadHeader(
    key: Key(
      mobile ? 'workspace-mobile-detail-header' : 'workspace-thread-header',
    ),
    presentation: RaftThreadPresentation.side,
    threadLabel: tr('Thread'),
    jumpLabel: tr('Jump to beginning'),
    backLabel: threadSelection.active ? 'Exit selection' : 'Close thread',
    closeLabel: threadSelection.active ? 'Exit selection' : 'Close thread',
    backKey: mobile
        ? const Key('mobile-detail-back')
        : const Key('thread-back'),
    closeKey: const Key('thread-close'),
    parentLabel: w.channel == null
        ? null
        : '${w.channel!.type == 'dm' ? '@' : '#'}${w.channel!.name}',
    onBack: dismissPanel,
    onClose: dismissPanel,
    onJumpToStart: threadViewport.jumpToBeginning,
    actions: [
      if (w.threadParent != null)
        ThreadActions(
          key: ValueKey('thread-menu-${w.threadParent!.id}'),
          controller: w,
          parent: w.threadParent!,
          menuMode: true,
          onSearch: () => select('search'),
          onViewChannel: () {
            final parent = w.threadParent!;
            w.closeThread();
            w.jumpToMessage(parent.channelId, parent.id);
          },
        ),
    ],
  );

  void closeDesktopDetail() {
    final route = desktopNavigation.masterRoute;
    if (route == null) return;
    desktopNavigation.closeTarget();
    pendingDesktopSelection = false;
    w.closeThread();
    w.setSection(route);
  }

  Future<bool> openDesktopConversation(
    String channelId,
    String? messageId,
  ) async {
    final scope = desktopAuthority;
    desktopNavigation.bind(scope);
    if (!['search', 'activity'].contains(desktopNavigation.masterRoute)) {
      await w.jumpToMessage(channelId, messageId);
      return true;
    }
    var ticket = desktopNavigation.selectTarget(
      DesktopContentTarget(
        DesktopContentKind.channel,
        channelId,
        channelId: channelId,
        messageId: messageId,
      ),
    );
    pendingDesktopSelection = true;
    setState(() {});
    try {
      await w.jumpToMessage(channelId, messageId);
      if (!mounted ||
          !desktopNavigation.accepts(desktopAuthority, ticket) ||
          scope != desktopAuthority) {
        return false;
      }
      if (w.threadParent != null) {
        ticket = desktopNavigation.selectTarget(
          DesktopContentTarget(
            DesktopContentKind.thread,
            w.threadChannelId ?? w.threadParent!.id,
            channelId: channelId,
            messageId: messageId,
          ),
        );
      }
      return true;
    } finally {
      if (mounted &&
          desktopNavigation.accepts(desktopAuthority, ticket) &&
          scope == desktopAuthority &&
          desktopNavigation.target?.channelId == channelId) {
        pendingDesktopSelection = false;
        setState(() {});
      }
    }
  }

  Future<void> openDesktopActivity(Map<String, dynamic> row) async {
    final scope = desktopAuthority;
    if (row['kind'] != 'thread') {
      final id = row['parentChannelId'] ?? row['channelId'];
      final unread = (row['unreadCount'] as num? ?? 0) > 0;
      final message =
          row['firstMentionMessageId'] ??
          (unread ? row['firstUnreadMessageId'] : null) ??
          row['latestActivityMessageId'] ??
          row['lastMessageId'];
      if (id is String) {
        await openDesktopConversation(id, message is String ? message : null);
      }
      return;
    }
    final channelId = row['parentChannelId'], parentId = row['parentMessageId'];
    if (channelId is! String || parentId is! String) return;
    final opened = await openDesktopConversation(channelId, parentId);
    if (!opened) return;
    if (!mounted ||
        scope != desktopAuthority ||
        desktopNavigation.masterRoute != 'activity') {
      return;
    }
    final parent = w.messages.where((m) => m.id == parentId).firstOrNull;
    if (parent == null) return;
    final ticket = desktopNavigation.selectTarget(
      DesktopContentTarget(
        DesktopContentKind.thread,
        row['threadChannelId'] as String? ?? parentId,
        channelId: channelId,
      ),
    );
    final focused = (row['unreadCount'] as num? ?? 0) > 0
        ? row['firstUnreadMessageId'] ?? row['latestActivityMessageId']
        : row['latestActivityMessageId'];
    await w.openThread(
      parent,
      focusedMessageId: focused is String ? focused : null,
    );
    if (mounted && desktopNavigation.accepts(desktopAuthority, ticket)) {
      setState(() {});
    }
  }

  void selectDesktopDirectoryTarget(DesktopContentTarget target) {
    desktopNavigation.bind(desktopAuthority);
    if (desktopNavigation.masterRoute == null) {
      desktopNavigation.selectRoute(w.section);
    }
    desktopNavigation.selectTarget(target);
    pendingDesktopSelection = false;
    w.closeThread();
    w.setSection(desktopNavigation.masterRoute ?? 'members');
    setState(() {});
  }

  Future<void> openDesktopEntity(SearchEntity entity) async {
    final capability = entity.kind == 'computer'
        ? 'viewMachines'
        : entity.kind == 'agent'
        ? 'viewAgents'
        : 'viewMembers';
    if (!wide || !w.can(capability)) return;
    final scope = desktopAuthority;
    desktopNavigation.bind(scope);
    final selectionTicket = desktopNavigation.beginSelection();
    if (entity.kind != 'computer') {
      dynamic result;
      try {
        final existing = w.dms
            .where(
              (c) =>
                  c.json['peerId'] == entity.id &&
                  c.json['peerType'] ==
                      (entity.kind == 'agent' ? 'agent' : 'user'),
            )
            .firstOrNull;
        result = existing == null
            ? await w.client.post(
                '/channels/dm',
                data: {
                  entity.kind == 'agent' ? 'agentId' : 'userId': entity.id,
                },
              )
            : {'id': existing.id};
      } catch (_) {
        if (!mounted ||
            scope != desktopAuthority ||
            !desktopNavigation.accepts(scope, selectionTicket)) {
          return;
        }
      }
      if (!mounted ||
          scope != desktopAuthority ||
          !desktopNavigation.accepts(scope, selectionTicket)) {
        return;
      }
      if (result is Map && result['id'] is String) {
        await openDesktopConversation(result['id'], null);
        return;
      }
      // Profile fallback is source-authorized only after DM creation fails.
      if (entity.kind != 'agent') {
        desktopNavigation.selectRoute('members');
      }
    }
    desktopNavigation.selectTarget(
      DesktopContentTarget(
        entity.kind == 'computer'
            ? DesktopContentKind.computer
            : entity.kind == 'agent'
            ? DesktopContentKind.agent
            : DesktopContentKind.human,
        entity.id,
      ),
    );
    w.closeThread();
    w.setSection(desktopNavigation.masterRoute ?? 'search');
  }

  Future<void> messageDesktopProfile(DesktopContentTarget target) async {
    final scope = desktopAuthority;
    final value = await w.client.post(
      '/channels/dm',
      data: {
        target.kind == DesktopContentKind.agent ? 'agentId' : 'userId':
            target.id,
      },
    );
    if (!mounted ||
        scope != desktopAuthority ||
        !identical(desktopNavigation.target, target)) {
      return;
    }
    if (value is Map && value['id'] is String) {
      desktopNavigation.clear();
      await w.jumpToMessage(value['id'], null);
    }
  }

  Widget? desktopContentDetail() {
    final target = desktopNavigation.target;
    if (target == null) return null;
    final key = ValueKey(
      'desktop-detail-$mobileAuthority-${target.kind}-${target.id}',
    );
    if (target.kind == DesktopContentKind.human) {
      return MemberProfileView(
        key: key,
        controller: w,
        userId: target.id,
        onClose: closeDesktopDetail,
        onMessage: () => messageDesktopProfile(target),
      );
    }
    if (target.kind == DesktopContentKind.agent ||
        target.kind == DesktopContentKind.computer) {
      return FleetDetail(
        key: key,
        controller: w,
        computers: target.kind == DesktopContentKind.computer,
        initial: {'id': target.id},
        onClose: closeDesktopDetail,
      );
    }
    final thread = target.kind == DesktopContentKind.thread;
    final content = Column(
      key: key,
      children: [
        RaftPageHeader(
          title: thread ? tr('Thread') : w.channel?.name ?? '',
          height: raftPageHeaderHeight(context),
          actions: [
            RaftIconButton(
              glyph: RaftGlyph.x,
              tooltip: 'Close detail',
              onPressed: closeDesktopDetail,
            ),
          ],
        ),
        Expanded(
          child: pendingDesktopSelection && w.channel?.id != target.channelId
              ? Center(child: Text(tr('Loading...')))
              : ServerSetupGate(
                  controller: w,
                  child: RaftChatView(
                    controller: w,
                    thread: thread,
                    selectionHandle: thread ? threadSelection : mainSelection,
                  ),
                ),
        ),
      ],
    );
    return thread
        ? RaftConversationSurface(
            role: RaftConversationSurfaceRole.threadTimeline,
            child: content,
          )
        : content;
  }

  RaftGlyph sectionGlyph(String section) => switch (section) {
    'chat' => RaftGlyph.hash,
    'activity' => RaftGlyph.activity,
    'search' => RaftGlyph.search,
    'tasks' => RaftGlyph.checkSquare,
    'saved' => RaftGlyph.bookmark,
    'members' => RaftGlyph.users,
    'agents' => RaftGlyph.bot,
    'computers' => RaftGlyph.monitor,
    _ => RaftGlyph.settings,
  };

  Widget railIcon(RaftGlyph glyph) => RaftIcon(
    glyph,
    size: RaftRailRecipe(
      RaftTokens.of(context),
      viewportHeight: MediaQuery.sizeOf(context).height,
    ).glyphSize,
  );

  List<RaftRailDestination> get railDestinations => [
    RaftRailDestination(
      id: 'search',
      label: tr('Search'),
      glyph: RaftGlyph.search,
      iconWidget: railIcon(RaftGlyph.search),
    ),
    RaftRailDestination(
      id: 'chat',
      label: tr('Chat'),
      glyph: RaftGlyph.messageSquare,
      iconWidget: railIcon(RaftGlyph.messageSquare),
    ),
    RaftRailDestination(
      id: 'activity',
      label: tr('Activity'),
      glyph: RaftGlyph.activity,
      iconWidget: railIcon(RaftGlyph.activity),
      unread: w.unread.values.fold(0, (a, b) => a + b),
    ),
    RaftRailDestination(
      id: 'tasks',
      label: tr('Tasks'),
      glyph: RaftGlyph.checkSquare,
      iconWidget: railIcon(RaftGlyph.checkSquare),
    ),
    if (w.can('viewMembers'))
      RaftRailDestination(
        id: 'members',
        label: tr('Members'),
        glyph: RaftGlyph.users,
        iconWidget: railIcon(RaftGlyph.users),
      ),
    if (w.can('viewMachines'))
      RaftRailDestination(
        id: 'computers',
        label: tr('Computers'),
        glyph: RaftGlyph.monitor,
        iconWidget: railIcon(RaftGlyph.monitor),
      ),
  ];

  Widget workspaceRail() => RaftWorkspaceRail(
    destinations: railDestinations,
    selected: wide
        ? DesktopNavigationPolicy.forSection(
            desktopNavigation.visibleRoute(w.section),
          ).railMode
        : w.section,
    onSelected: select,
    workspaceName: w.server?.name ?? 'Raft',
    workspaceTooltip: tr('Switch workspace'),
    onWorkspace: () => showWorkspaceSwitcher(),
    footer: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SystemNotificationBell(
          controller: w,
          mobile: false,
          onBilling: () => select('billing'),
        ),
        RaftIconButton(
          key: const Key('rail-settings'),
          tooltip: 'Settings',
          onPressed: () => select('settings'),
          glyph: RaftGlyph.settings,
          visualSize: RaftMetrics.railItem,
        ),
      ],
    ),
  );

  Future<void> showWorkspaceSwitcher() async {
    final scope = mobileAuthority;
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
                    ? const RaftIcon(RaftGlyph.check, size: 14)
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
    if (choice == null || !mounted || scope != mobileAuthority) return;
    if (choice == 'create') {
      await WorkspaceActions.create(context, w);
    } else if (choice == 'join') {
      await WorkspaceActions.join(context, w);
    } else {
      final server = w.servers.where((s) => s.id == choice).firstOrNull;
      if (server != null) await w.selectServer(server);
    }
  }

  Widget mobileNavigation() {
    final scope = mobileAuthority;
    return WorkspaceMobileTabBar(
      controller: w,
      selectedId:
          mobileWorkspaceRootTab(
            w.section,
            threadOpen: w.threadParent != null,
            settingsDetail: mobileSettingsDetail,
          ) ??
          'chat',
      // The enclosing SafeArea consumed this inset exactly once.
      bottomInset: 0,
      onSelected: (tab) => selectMobileTab(tab, scope),
    );
  }

  Widget channelHeader({bool mobile = false}) => RaftChannelHeader(
    key: Key(
      mobile ? 'workspace-mobile-detail-header' : 'workspace-channel-header',
    ),
    name: w.channel!.name,
    description: w.channel!.description,
    kind: w.channel!.type,
    onBack: mobile ? dismissPanel : null,
    backKey: mobile ? const Key('mobile-detail-back') : null,
    backLabel: mainSelection.active ? tr('Exit selection') : tr('Back'),
    onSearch: searchThisChannel,
    onSettings: channelSettings,
    searchLabel: tr('Search this channel'),
    settingsLabel: tr('Channel settings'),
  );

  Widget mobilePageHeader(String title, bool thread) => thread
      ? sourceThreadHeader(mobile: true)
      : w.section == 'chat' &&
            w.channel != null &&
            ['channel', 'private', 'joint'].contains(w.channel!.type)
      ? channelHeader(mobile: true)
      : RaftPageHeader(
          key: const Key('workspace-mobile-detail-header'),
          title: thread ? tr('Thread') : title,
          height: raftPageHeaderHeight(context),
          mobile: true,
          leading: RaftBackButton(
            key: const Key('mobile-detail-back'),
            tooltip: thread
                ? (threadSelection.active ? 'Exit selection' : 'Close thread')
                : (mainSelection.active ? 'Exit selection' : 'Back'),
            onPressed: dismissPanel,
          ),
          actions: [
            if (w.section == 'chat' && w.channel != null && !thread)
              RaftIconButton(
                tooltip: 'Channel settings',
                onPressed: channelSettings,
                glyph: RaftGlyph.slidersHorizontal,
              ),
            RaftIconButton(
              tooltip: 'Search messages',
              onPressed: () => select('search'),
              glyph: RaftGlyph.search,
            ),
            RaftIconButton(
              tooltip: 'Settings',
              onPressed: () => select('settings'),
              glyph: RaftGlyph.settings,
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
      if (group.custom) ...[
        if (group.entries.isNotEmpty ||
            !presentation.value.hideEmptySections) ...[
          sectionLabel(group.label, group: group),
          if (sidebarDisclosure.collapsed[group.id] != true)
            ...group.entries.map(sidebarEntry),
        ],
      ] else
        RaftChatSidebarGroup(
          key: ValueKey('sidebar-group-${group.id}'),
          headerKey: ValueKey('sidebar-section-${group.id}'),
          disclosureKey: ValueKey('sidebar-disclosure-${group.id}'),
          kind: switch (group.id) {
            'system:pinned' => RaftChatSidebarGroupKind.pinned,
            'system:joint' => RaftChatSidebarGroupKind.joint,
            'system:dms' => RaftChatSidebarGroupKind.directMessages,
            _ => RaftChatSidebarGroupKind.channels,
          },
          label: tr(group.label),
          count: group.entries.length,
          expanded: sidebarDisclosure.collapsed[group.id] != true,
          hideEmpty: presentation.value.hideEmptySections,
          loading: w.loading,
          emptyLabel: switch (group.id) {
            'system:pinned' => tr('Drag channels or DMs here to pin'),
            'system:joint' => tr('No joint channels yet'),
            _ => '',
          },
          onExpandedChanged: (expanded) => sidebarDisclosure.setExpanded(
            mobileAuthority,
            group.id,
            expanded,
          ),
          actions: sidebarGroupActions(group),
          children: group.entries.map(sidebarEntry).toList(),
        ),
  ];

  Widget channelItem(RaftChannel c) {
    final scope = mobileAuthority;
    return RaftNavItem(
      key: ValueKey('sidebar-channel-${c.id}'),
      label: c.type == 'dm'
          ? c.string('peerDisplayName', c.string('peerName', c.name))
          : c.name,
      glyph: c.type == 'dm'
          ? RaftGlyph.user
          : c.type == 'private'
          ? RaftGlyph.lock
          : c.type == 'joint'
          ? RaftGlyph.gitBranch
          : RaftGlyph.hash,
      conversationKind: c.type == 'dm'
          ? RaftConversationNavKind.directMessage
          : RaftConversationNavKind.channel,
      selected: gridActive
          ? gridKey.currentState?.activeChannelId == c.id
          : w.section == 'chat' && w.channel?.id == c.id,
      unread: w.unread[c.id] ?? 0,
      onTap: () => chooseChannel(c, expectedScope: scope),
    );
  }

  Widget sidebar({bool mobileHome = false}) {
    final recipe = RaftSidebarRecipe(
      RaftTokens.of(context),
      viewportWidth: MediaQuery.sizeOf(context).width,
      viewportHeight: MediaQuery.sizeOf(context).height,
      variant: RaftSidebarVariant.mountedProduct,
    );
    final latest = liveActivities.latest;
    final liveActivityVisible =
        presentation.value.liveActivity &&
        latest != null &&
        liveActivities.agent(latest.agentId) != null;
    return ColoredBox(
      color: recipe.bodyBackground,
      child: SafeArea(
        child: Column(
          children: [
            if (mobileHome)
              WorkspaceMobileHomeHeader(
                controller: w,
                onServer: showWorkspaceSwitcher,
                onBilling: () => select('billing'),
              )
            else
              SizedBox(
                height: recipe.headerHeight,
                child: Padding(
                  padding: recipe.headerInset,
                  child: Row(
                    children: [
                      if (!mobileHome)
                        Text(
                          tr('Chat'),
                          style: RaftTypography.heading(
                            RaftTokens.of(context),
                            size: 18,
                            line: 28,
                          ),
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
                                    defaultTargetPlatform ==
                                            TargetPlatform.linux &&
                                        workspaceBrowserOrigin(
                                              w.client.origin,
                                            ) !=
                                            null
                                    ? (event) {
                                        if (event.buttons ==
                                            kMiddleMouseButton) {
                                          Navigator.of(context).pop();
                                          unawaited(
                                            openWorkspaceInBrowser(
                                              context,
                                              w,
                                              s,
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                child: Row(
                                  children: [
                                    Expanded(child: Text(s.name)),
                                    if (defaultTargetPlatform ==
                                            TargetPlatform.linux &&
                                        workspaceBrowserOrigin(
                                              w.client.origin,
                                            ) !=
                                            null)
                                      IconButton(
                                        key: ValueKey(
                                          'workspace-browser-${s.id}',
                                        ),
                                        tooltip: tr(
                                          'Open workspace in browser',
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          unawaited(
                                            openWorkspaceInBrowser(
                                              context,
                                              w,
                                              s,
                                            ),
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
                            const RaftIcon(RaftGlyph.chevronDown, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!mobileHome)
              Divider(
                height: RaftTokens.of(context).border,
                thickness: RaftTokens.of(context).border,
              ),
            Expanded(
              child: ListView(
                key: const Key('workspace-sidebar'),
                padding: recipe.contentInset(
                  headerInFlow: true,
                  liveActivity: mobileHome && liveActivityVisible,
                  bottomInset: 0,
                ),
                children: [
                  if (mobileHome)
                    RaftNavItem(
                      key: const Key('nav-search'),
                      role: RaftNavItemRole.search,
                      viewportHeight: MediaQuery.sizeOf(context).height,
                      label: tr('Search'),
                      glyph: RaftGlyph.search,
                      selected: w.section == 'search',
                      onTap: () => select('search'),
                    ),
                  if (mobileHome)
                    RaftNavItem(
                      key: const Key('nav-activity'),
                      role: RaftNavItemRole.activity,
                      viewportHeight: MediaQuery.sizeOf(context).height,
                      label: tr('Activity'),
                      glyph: RaftGlyph.activity,
                      selected: w.section == 'activity',
                      unread: w.unread.values.fold(0, (a, b) => a + b),
                      onTap: () => select('activity'),
                    ),
                  SavedSidebarEntry(
                    key: const Key('nav-saved'),
                    controller: w,
                    onTap: () => select('saved'),
                  ),
                  ...conversationSections(),
                ],
              ),
            ),
            if (!mobileHome) ...[
              liveActivityBar(),
              const Divider(height: 1),
              RaftNavItem(
                key: const Key('account-navigation'),
                label: w.client.user?.name ?? tr('Account'),
                icon: Icons.account_circle_outlined,
                glyph: RaftGlyph.circleUserRound,
                onTap: () => select('settings'),
                selected: w.section == 'settings',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> sortSidebarGroup(SidebarGroup group) async {
    final scope = mobileAuthority;
    if (sortingGroups.contains(group.id)) return;
    final prefs = Map<String, dynamic>.from(w.sidebarOrder);
    final key = switch (group.id) {
      'system:pinned' => 'pinnedSortMode',
      'system:joint' => 'jointChannelSortMode',
      'system:channels' => 'channelSortMode',
      'system:dms' => 'dmSortMode',
      _ => null,
    };
    if (key == null || w.server == null) return;
    final mode = await showSidebarSortMenu(
      context,
      w,
      sortAnchors[group.id]!,
      '${prefs[key] ?? 'manual'}',
    );
    if (!mounted || scope != mobileAuthority || mode == null) return;
    sortingGroups.add(group.id);
    setState(() {});
    try {
      await w.command(
        'PATCH',
        '/servers/${w.server!.id}/sidebar-order',
        data: {key: mode},
      );
      if (!mounted || scope != mobileAuthority) return;
      await w.loadSidebar();
    } catch (error) {
      if (mounted && scope == mobileAuthority) w.setError('$error');
    } finally {
      sortingGroups.remove(group.id);
      if (mounted && scope == mobileAuthority) setState(() {});
    }
  }

  Widget sectionLabel(
    String label, {
    SidebarGroup? group,
    VoidCallback? onAdd,
    String addLabel = 'Create channel',
  }) {
    final id = group?.id;
    return RaftSidebarSectionHeader(
      key: id == null ? null : ValueKey('sidebar-section-$id'),
      disclosureKey: id == null ? null : ValueKey('sidebar-disclosure-$id'),
      label: label,
      expanded: id == null || sidebarDisclosure.collapsed[id] != true,
      count: group?.entries.length,
      onExpandedChanged: id == null
          ? null
          : (expanded) =>
                sidebarDisclosure.setExpanded(mobileAuthority, id, expanded),
      actions: group == null ? const [] : sidebarGroupActions(group),
    );
  }

  List<RaftSidebarSectionAction> sidebarGroupActions(SidebarGroup group) {
    final scope = mobileAuthority, id = group.id;
    final sortable = !group.custom;
    final anchor = sortable ? sortAnchors.putIfAbsent(id, GlobalKey.new) : null;
    // Sidebar.tsx renderSectionAddButton: Plus 14 on Channels
    // (createChannels) and Joint channels (federateChannels) only; Pinned and
    // Direct messages carry just the sort menu.
    final VoidCallback? onAdd =
        id == 'system:channels' && w.can('createChannels')
        ? createChannel
        : id == 'system:joint' && w.can('federateChannels')
        ? () => select('joint-channels')
        : null;
    return [
      if (sortable)
        RaftSidebarSectionAction(
          key: anchor,
          label: tr('Sort'),
          glyph: RaftGlyph.arrowUpDown, // Sidebar.tsx ArrowUpDown 14
          onPressed: sortingGroups.contains(id)
              ? null
              : () => sortSidebarGroup(group),
        ),
      if (onAdd != null)
        RaftSidebarSectionAction(
          label: id == 'system:joint'
              ? tr('Create joint channel')
              : tr('Create channel'),
          glyph: RaftGlyph.plus,
          onPressed: () {
            if (scope == mobileAuthority) onAdd();
          },
        ),
    ];
  }

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

  Future<void> createChannel() => CreateChannelDialog.show(
    context,
    controller: w,
    onCreated: (channel) => chooseChannel(channel),
  );

  Widget? modeCard() {
    if (!workspaceMode.showCard) return null;
    final capturedAuthority = workspaceMode.authority;
    return RaftWorkspaceModeCard(
      enabled: workspaceMode.enabled,
      onChanged: (value) {
        if (!mounted || capturedAuthority != workspaceMode.authority) return;
        gridKey.currentState?.flushDrafts();
        workspaceMode.setEnabled(value, capturedAuthority: capturedAuthority);
      },
    );
  }

  Widget settings() {
    final scope = mobileAuthority;
    return KeyedSubtree(
      key: const Key('workspace-account-settings'),
      child: WorkspaceSettings(
        key: ValueKey(
          'workspace-account-settings-${w.client.generation}-${w.client.user?.id}-${w.server?.id}-${w.server?.string('role')}',
        ),
        controller: w,
        workspaceModeCard: modeCard(),
        appearance: widget.appearance,
        onAppearance: (appearance) => widget.onAppearance(appearance),
        presentation: presentation,
        notifications: widget.notifications,
        onLogout: widget.onLogout,
        mobileRoot: true,
        mobileResetRevision: mobileSettingsRevision,
        onMobileDetailChanged: (detail) {
          if (!mounted || scope != mobileAuthority) return;
          setState(() => mobileSettingsDetail = detail);
        },
        providerEnabled: providerEnabled,
        bridgeEnabled: bridgeEnabled,
      ),
    );
  }
}
