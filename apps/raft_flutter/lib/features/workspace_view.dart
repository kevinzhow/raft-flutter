import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'announcement_host.dart';
import 'notification_activation_workspace.dart';
import '../data/user_error.dart';
import 'local_error_diagnostics.dart';
import '../data/workspace_controller.dart';
import '../platform/route_frame_diagnostics.dart';
import '../data/workspace_entity_directory.dart';
import '../data/source_activity_unread_store.dart';
import '../data/source_mobile_app_badge.dart';
import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/navigation_registry.dart';
import '../data/workspace_navigation.dart';
import '../data/source_server_unread.dart';
import 'workspace_menu_invite.dart';
import '../data/personal_presentation.dart';
import '../data/device_preferences.dart';
import '../data/mobile_tabbar_preferences.dart';
import '../data/rail_side_preference.dart';
import '../data/sidebar_disclosure.dart';
import 'message_reference_directory.dart';
import 'chat_agent_presentation.dart';
import 'live_agent_activity_bar.dart';
import 'chat_view.dart';
import 'mobile_route_gate.dart';
import 'rail_gesture_exclusion.dart';
import 'thread_actions.dart';
import 'profile_side_panel.dart';
import 'thread_agent_followers_view.dart';
import 'community_join.dart';
import 'conversation_panel.dart';
import 'message_selection.dart';

import 'package:flutter/scheduler.dart';

import 'resource_view.dart';
import 'workspace_task_host.dart';
import 'page_layout.dart';
import 'channel_settings.dart';
import 'channel_members.dart';
import 'create_channel_dialog.dart';
import 'create_joint_channel_dialog.dart' show CreateJointChannelDialog;
import 'workspace_settings.dart';
import 'mobile_resource_direct.dart';
import 'mobile_settings_owner.dart';
import 'server_views.dart';
import 'layout_hold.dart';
import 'mobile_workspace_navigation.dart';
import 'mobile_workspace_pages.dart';
import 'desktop_navigation_policy.dart';
import 'activity_destination.dart';
import 'desktop_master_detail.dart';
import 'desktop_directory_view.dart';
import 'desktop_activity_flag.dart';
import 'resource_search.dart';
import 'quick_switcher_host.dart';
import 'member_graph_view.dart';
import 'member_profile_view.dart';
import 'fleet_views.dart';
import 'private_route_guard.dart';
import 'server_setup_gate.dart';
import 'sidebar_projection.dart';
import 'sidebar_reorder.dart';
import 'sidebar_sort_menu.dart';
import 'agent_avatar_projection.dart';
import 'saved_sidebar_entry.dart';
import 'system_notification_center.dart';
import 'workspace_browser.dart';
import 'workspace_dm_header.dart';
import 'management_support.dart' show managementLaunch;
import 'sender_avatar_projection.dart';
import '../platform/app_services.dart';
import '../platform/app_update.dart';
import '../platform/native_sharing.dart';
import '../platform/native_notifications.dart';
import '../platform/system_bars.dart';
import '../platform/keyboard_inset_diagnostics.dart';
import '../data/feature_flag_client_facts.dart';
import 'public_avatar_url.dart';

part 'workspace_view_sidebar_menus.dart';
part 'mobile_workspace_route.dart';
part 'mobile_settings_route.dart';

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
    this.mobileTabbar,
    this.railSide,
    this.onChooseServer,
    this.onSwitchServer,
    this.mobileRoutePage = false,
    this.mobileHost,
  });
  final WorkspaceController controller;

  final bool mobileRoutePage;
  final Object? mobileHost;
  final NativeNotificationService? notifications;
  final NativeSharing? sharing;
  final PersonalPresentationStore? presentation;

  /// The device-local bottom-bar choice; the workspace owns one by default.
  final MobileTabbarStore? mobileTabbar;

  /// The device-local side of the phone layout's rail (left / right); the
  /// workspace owns one by default.
  final RailSideStore? railSide;

  /// App root owns the Source `/` server chooser outside a workspace URI.
  final VoidCallback? onChooseServer;

  /// App root publishes the accepted server URI before server hydration.
  final Future<void> Function(RaftRecord server, bool replaceWithHome)?
  onSwitchServer;

  final RaftAppearance appearance;
  final Future<void> Function(RaftAppearance) onAppearance;
  final Future<void> Function() onLogout;
  @override
  State<WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends State<WorkspaceView>
    with WidgetsBindingObserver, KeyboardInsetLogger<WorkspaceView> {
  AppUpdateService? get appUpdate => AppServicesScope.of(context).appUpdate;
  /// Sidebar.tsx `joinedChannelsOnly` display preference of the Channels
  /// section (per workspace session here; Web persists it per server).
  bool joinedChannelsOnly = false;

  // The most recently admitted Settings page survives a conversation visit.
  // Other destinations retire it; workspace authority retires both panes.
  Widget? retainedSettingsContent;

  /// Sidebar.tsx `menuOpen`: the row whose context menu is open (`c:<id>` /
  /// `a:<id>`) keeps its muted fill.
  String? menuOpenRow;
  void setMenuOpenRow(String? row) {
    if (mounted && menuOpenRow != row) setState(() => menuOpenRow = row);
  }

  /// Sidebar row-menu feedback (Source `toast.error` of the mute action).
  final rowToast = RaftToastController();

  void toggleJoinedChannelsOnly() =>
      setState(() => joinedChannelsOnly = !joinedChannelsOnly);
  final serverMenu = RaftMenuController();
  late SourceServerUnreadStore serverUnread;
  String? serverMenuScope;
  int serverOrderRequest = 0;
  Timer? serverUnreadTimer;
  bool serverUnreadBooted = false, serverUnreadLocal = false;
  String? serverUnreadScope;

  /// Sidebar.tsx / App boot: the cross-server summary loads once the member
  /// and servers are known and again when local unread flips 0 <-> nonzero
  /// (150 ms debounce), so the Activity count and the other-server dot are
  /// painted without opening the server menu.
  void syncServerUnreadLoad() {
    if (w.client.user == null || w.servers.isEmpty) return;
    final local = w.conversationReads.unread.values.any((count) => count > 0);
    final scope = serverUnread.scope;
    if (serverUnreadBooted &&
        local == serverUnreadLocal &&
        scope == serverUnreadScope) {
      return;
    }
    serverUnreadBooted = true;
    serverUnreadLocal = local;
    serverUnreadScope = scope;
    serverUnreadTimer?.cancel();
    serverUnreadTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) unawaited(serverUnread.refresh());
    });
  }

  void syncServerMenu() {
    if (skipCoveredPage) return;
    serverUnread.synchronize();
    syncServerUnreadLoad();
    if (serverMenuScope == mobileAuthority) return;
    serverMenuScope = mobileAuthority;
    serverMenu.close();
  }

  void serverUnreadChanged() {
    if (mounted) setState(() {});
  }

  /// Sidebar.tsx loads the summary again when the window regains focus: the
  /// same on return to the foreground (the host view only; the store is shared).
  void appResumed() {
    if (mounted) unawaited(serverUnread.refreshOnResume());
  }

  void serverMenuChanged() {
    if (serverMenu.isOpen) unawaited(serverUnread.refresh());
  }

  final scaffold = GlobalKey<ScaffoldState>();
  final mainSelection = ChatSelectionHandle(),
      threadSelection = ChatSelectionHandle();
  WorkspaceController get w => widget.controller;

  /// A covered phone route shares the workspace controller. Its listeners must
  /// not apply the page that is now on screen.
  bool get skipCoveredPage {
    if (!widget.mobileRoutePage || !mounted) return false;
    final pageRoute = context.findAncestorStateOfType<_MobileWorkspaceRouteState>();
    return pageRoute != null && !pageRoute.active;
  }

  PageStorageBucket mobilePageStorage = PageStorageBucket();
  String? mobileStorageAuthority;
  _MobileNavigationSelection? _mobileNavigationSelection;
  _MobileNavigationSelection get mobileNavigationSelection =>
      _mobileNavigationSelection ??= _MobileNavigationSelection(this);

  _WorkspaceViewState? get mobileHost => widget.mobileHost as _WorkspaceViewState?;
  TaskSurfaceSeed? taskSeed;
  void openTaskSurface(
    Map<String, dynamic> row,
    Future<void> Function() reload, {
    bool boardIntent = true,
  }) {
    final host = mobileHost;
    if (host != null) {
      host.openTaskSurface(row, reload, boardIntent: boardIntent);
      return;
    }
    final channelId = row['channelId'];
    final itemId = row['isLegacy'] == true ? row['id'] : row['messageId'];
    if (channelId is! String || itemId is! String || itemId.isEmpty) return;
    taskSeed = TaskSurfaceSeed(
      {...row},
      taskSurfaceAuthority(w, channelId),
      reload,
    );
    final legacy = row['isLegacy'] == true;
    final next = w.location.withQuery({
      if (boardIntent) 'profile': null,
      if (legacy || boardIntent)
        'legacyTask': legacy ? '$channelId:$itemId' : null,
      if (!legacy || boardIntent) 'task': legacy ? null : '$channelId:$itemId',
      if (legacy && boardIntent) 'thread': null,
    });
    if (!wide) {
      // Board arbitration clears a profile/legacy thread before the new page.
      // Back must return to that accepted list, not revive a discarded panel.
      if (w.location.task == null && w.location.legacyTask == null) {
        final base = next.withQuery({'task': null, 'legacyTask': null});
        if (base.uri.query != w.location.uri.query) {
          w.navigation.navigate(base, kind: RaftNavigationKind.replace);
        }
      }
      w.navigation.navigateTask(next);
    } else {
      w.navigation.navigateTask(
        next,
        kind: w.location.panelNavigationKindTo(next),
      );
    }
    if (legacy && boardIntent) w.closeThread(navigate: false);
    w.notifyListeners();
  }

  void openMessageTaskSurface(
    Map<String, dynamic> row,
    Future<void> Function() reload,
  ) => openTaskSurface(row, reload, boardIntent: false);

  String? lastAuthority, lastChannelId;
  Map<String, dynamic>? lastChannelAuthority;
  int channelAuthorityRevision = 0;
  int searchEntryRevision = 0;

  /// The Search page opened from the quick switcher restores the query and
  /// filters the switcher saved.
  int restoreSavedSearchRevision = -1;
  String? channelSearchSeed, channelSearchAuthority;
  bool channelSearchRevoked = false;

  void syncChannelSearch() {
    if (skipCoveredPage || channelSearchSeed == null) return;
    final channel = w.channels
        .where((c) => c.id == channelSearchSeed)
        .firstOrNull;
    if (channelSearchAuthority != channelSearchPageAuthority(w) ||
        channel == null ||
        !w.can('viewChannel', resource: channel)) {
      channelSearchSeed = channelSearchAuthority = null;
      channelSearchRevoked = w.section == 'search';
    }
  }

  void searchThisChannel() {
    final channel = w.channel;
    if (channel == null || !w.can('viewChannel', resource: channel)) return;
    if (wide && w.canVisitSection('search')) {
      quickSwitcher.open(
        context,
        entry: QuickSwitcherEntry.channel,
        channelId: channel.id,
      );
      return;
    }
    select('search', searchChannelId: channel.id);
  }

  DesktopNavigationState? _desktopNavigation;
  DesktopNavigationState get desktopNavigation =>
      _desktopNavigation ??= DesktopNavigationState(navigation: w.navigation);
  bool pendingDesktopSelection = false;
  String get desktopAuthority => '$mobileAuthority|$channelAuthorityRevision';
  int mobileSettingsRevision = 0;
  String get mobileAuthority => jsonEncode([
    identityHashCode(w.presentationSource ?? w),
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ]);
  String? mobileRouteAuthority;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    w.mobileNavigation = !wide;
    w.bindNavigation();
    ensureLayoutLocation();
  }

  bool? lastCompact, heldCompact;

  void layoutHoldChanged() {
    if (!mounted || LayoutHold.held) return;
    ensureLayoutLocation();
    setState(() {});
  }

  /// Width picks the projection of the one canonical location. Crossing the
  /// breakpoint (or arriving by link in the other layout) translates the few
  /// identities that only exist in one layout (`channelPage=` is phone-only,
  /// `activity|search ?open=` is wide master/detail). Pages pushed without a
  /// location (forward composer, fleet details, notification centre pages) and
  /// dialogs are the user's task, not the layout's: they stay open across the
  /// crossing. Silent: the build that follows reads the translated location;
  /// listeners catch up after it.
  void ensureLayoutLocation() {
    if (widget.mobileRoutePage || !mounted || LayoutHold.held) return;
    final compact = !wide;
    final crossed = lastCompact != null && lastCompact != compact;
    lastCompact = compact;
    if (w.presentationSource != null || w.server == null) return;
    if (crossed) {
      w.navigation.collapseRepeatedEntries();
    }
    // A content slot opened on a phone (Search thread hits) is a phone page
    // already; only a slot the wide layout made needs translating.
    final translation = compact && !crossed
        ? null
        : w.navigation.translateForLayout(compact: compact);
    if (crossed) {
      w.navigation.markLayoutCrossing(translated: translation != null && compact);
    }
    if (translation == null && !crossed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      w.notifyListeners();
      if (translation != null) hydrateTranslated(translation, compact);
    });
  }

  /// The translated location names a conversation the other layout had not
  /// loaded as its main channel (Activity detail was a content slot), and wide
  /// shows channel management as a dialog.
  void hydrateTranslated(LayoutTranslation translation, bool compact) {
    if (compact) {
      final to = translation.to;
      final id = to.entityId;
      if (id == null || !{RaftRoute.channel, RaftRoute.dm}.contains(to.route)) {
        return;
      }
      if (w.channel?.id == id && to.thread == null) return;
      if (to.thread != null) {
        unawaited(w.resolveConversationChannel(id, preserveThread: true));
      } else {
        unawaited(w.jumpToMessage(id, to.messageId, navigate: false));
      }
      return;
    }
    final page = translation.from.channelPage;
    if (page == null) return;
    final channel = [
      ...w.channels,
      ...w.dms,
    ].where((channel) => channel.id == page.channelId).firstOrNull;
    if (channel == null || !w.can('viewChannel', resource: channel)) return;
    if (page.kind == RaftChannelPage.settings) {
      unawaited(
        ChannelSettings.show(
          context,
          controller: w,
          channel: channel,
          dmName: channel.type == 'dm'
              ? dmPeer(channel, requestSize: 36).name
              : null,
        ),
      );
    } else {
      unawaited(
        ChannelMembers.show(
          context,
          controller: w,
          channel: channel,
          startInAdd: translation.from.query('channelPageAdd') == '1',
        ),
      );
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
    if (tab != 'settings' && !mobileTabIds.contains(tab)) return;
    if (![
      'chat',
      'tasks',
      'members',
      'computers',
      'activity',
      'settings',
    ].contains(tab)) {
      return;
    }
    mainSelection.dismiss();
    threadSelection.dismiss();
    w.closeThread(navigate: false);
    setState(() {
      mobileSettingsRevision++;
    });
    select(tab == 'chat' ? 'home' : tab);
  }

  /// A rail destination on the phone layout: the same phone navigation the
  /// bottom bar drives (Search is the Home list's own pushed page).
  void selectRailDestination(String id) {
    final scope = mobileAuthority;
    if (id == 'search') {
      if (mounted && scope == mobileAuthority) select('search');
      return;
    }
    selectMobileTab(id, scope);
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

  /// Read synchronously from the preloaded device preferences, so the first
  /// frame already has the configured bar.
  MobileTabbarStore? _ownedMobileTabbar;
  MobileTabbarStore get ownedMobileTabbar =>
      _ownedMobileTabbar ??= MobileTabbarStore();
  MobileTabbarStore get mobileTabbar =>
      widget.mobileTabbar ?? ownedMobileTabbar;

  RailSideStore? _ownedRailSide;
  RailSideStore get railSideStore =>
      widget.railSide ?? (_ownedRailSide ??= RailSideStore());

  /// Ids of the tabs the bar shows for this account (Settings not included).
  ///
  /// With the left rail the bottom-bar choice does not apply: every
  /// destination the desktop rail lists is a root tab (Home, Activity, Tasks,
  /// Members, Computers; Search and Settings are the rail's own entries).
  List<String> get mobileTabIds => railNavigation
      ? [
          MobileTabs.home,
          MobileTabs.activity,
          MobileTabs.tasks,
          if (w.can('viewMembers')) MobileTabs.members,
          if (w.can('viewMachines')) MobileTabs.computers,
        ]
      : mobileTabbar.settings.effective(
          guest: w.server?.string('role') == 'guest',
          can: w.can,
        );
  final sidebarDisclosure = SidebarDisclosureStore();

  /// Cmd/Ctrl+K quick switcher: visit history, shared search memory and the
  /// dialog route live across openings.
  late final QuickSwitcherHost quickSwitcher = QuickSwitcherHost(
    controller: w,
    actions: QuickSwitcherActions(
      openConversation: openQuickSwitcherConversation,
      openDirectory: openQuickSwitcherDirectory,
      openThread: openQuickSwitcherThread,
      openMessage: openQuickSwitcherMessage,
      searchAll: (query) => select('search', restoreSavedSearch: true),
    ),
  );
  final sortAnchors = <String, GlobalKey>{};
  final sortingGroups = <String>{};
  void syncSidebarDisclosure() {
    if (skipCoveredPage) return;
    unawaited(
      sidebarDisclosure.bind(
        origin: w.client.origin,
        principal: w.client.user?.id,
        server: w.server?.id,
        scope: mobileAuthority,
      ),
    );
  }

  /// Source loads the first Saved page when the connection is established, so
  /// earlier saves are known before the Saved page is visited.
  void syncSavedIds() {
    if (skipCoveredPage) return;
    SavedCountStore.of(w).sync();
  }

  late SourceMobileAppBadge mobileAppBadge;
  void syncMobileAppBadge() {
    if (skipCoveredPage) return;
    unawaited(mobileAppBadge.bind(w.client.origin, w.client.user?.id));
  }

  late SourceActivityUnreadStore activityUnread;
  String? presentedAttention;
  void activityUnreadChanged() {
    if (!mounted) return;
    // The workspace presents only the attention dot and the store authority
    // captured by the Activity page; accepted windows that change neither
    // do not rebuild the whole workspace.
    final next = jsonEncode([
      activityUnread.hasAttention,
      activityUnread.scope,
      activityUnread.authorityEpoch,
      // The sidebar's Activity count follows the accepted window.
      activityUnread.totalUnreadCount,
    ]);
    if (next == presentedAttention) return;
    presentedAttention = next;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  bool get hasActivityAttention => activityUnread.hasAttention;

  /// The Activity count of [serverId]: for the open server the accepted
  /// window's total (the number the app icon badge and the shade sum to, live
  /// with every message and read), for the others the server's summary.
  int? activityCountOf(String serverId) =>
      serverId == w.server?.id && activityUnread.totalUnreadCount != null
      ? activityUnread.totalUnreadCount
      : serverUnread[serverId]?.activityUnreadCount;
  bool get hasChatAttention => [
    ...w.channels.where((c) => c.type != 'channel' || c.joined),
    ...w.dms,
  ].any((c) => (w.conversationReads.unread[c.id] ?? 0) > 0);

  late DesktopActivityFlag activityFlag;
  void activityFlagChanged() {
    if (mounted) setState(() {});
  }

  late MessageReferenceDirectory activityDirectory;
  late ChatAgentPresentation liveActivities;

  /// The shell rebuilds only when the live activity bar appears or leaves
  /// (the mobile home inset); the bar itself follows every activity change.
  final liveActivityShown = ValueNotifier(false);
  void syncLiveActivityShown() {
    final latest = liveActivities.latest;
    liveActivityShown.value =
        latest != null && liveActivities.agent(latest.agentId) != null;
  }

  /// Sidebar agent rows and DM peers render identity fields only; agent
  /// presence patches never rebuild the shell.
  late WorkspaceEntitySelection shellIdentities;
  WorkspaceEntitySelection bindShellIdentities() =>
      WorkspaceEntitySelection(w.services.entityDirectory, (d) => d.authorRevision);
  void syncPresentation() {
    if (skipCoveredPage) return;
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
  bool get wide => !RaftAdaptiveWorkspace.compactOf(context);

  /// The phone layout shows the desktop left rail instead of the bottom tab
  /// bar (wide foldable, landscape phone, 600-767 dp; see [RaftWindowClass]).
  /// Held with the layout while a full-bleed overlay owns state in the tree.
  bool get railNavigation {
    final live = RaftAdaptiveWorkspace.phoneRailOf(
      context,
      side: railSideStore.side,
    );
    if (!LayoutHold.held) return heldRail = live;
    return heldRail ?? live;
  }

  bool? heldRail;

  /// The desktop layout's navigation column sits on the right: a touch device
  /// whose side choice is the end side, with no separating fold in the column
  /// (see [RaftWindowClass.desktopNavigationOnRight]). Always false below the
  /// desktop cut and on computers.
  bool get desktopNavigationOnRight =>
      wide &&
      RaftWindowClass.desktopNavigationOnRight(
        MediaQuery.sizeOf(context),
        followsSide: railSideFollowsChoice(),
        railSide: railSideStore.side,
        textDirection: Directionality.of(context),
        columnWidth: RaftWindowClass.railStripWidth + sidebarWidth,
        displayFeatures: () => MediaQuery.displayFeaturesOf(context),
      );

  /// The rail's scrolling destination list, measured for gesture exclusion.
  final railItemArea = GlobalKey(debugLabel: 'rail-item-area');

  /// Cmd/Ctrl+K while the Search page shows: a bump asks it to focus its field.
  final searchFocusRequests = ValueNotifier<int>(0);
  double sidebarWidth = 240, threadWidth = 400;
  double masterWideWidth = 560, masterCompactWidth = 320;
  Timer? persistPanels;
  bool joiningCommunityFromHelp = false;
  bool bridgeEnabled = false, providerEnabled = false, labsEnabled = false;
  String? bridgeScope;
  int bridgeRequest = 0;
  String tr(String source) => raftText(context, source);

  @override
  void initState() {
    super.initState();
    LayoutHold.count.addListener(layoutHoldChanged);
    adoptHostSearchEntry();
    mobileAppBadge = SourceMobileAppBadge()..addListener(chatSelectionChanged);
    // Starts recording visits to conversations from the first frame.
    quickSwitcher.changed();
    HardwareKeyboard.instance.addHandler(globalShortcut);
    w.addListener(syncMobileAppBadge);
    syncMobileAppBadge();
    activityUnread = w.services.activityUnread..addListener(activityUnreadChanged);
    serverUnread = mobileHost?.serverUnread ?? SourceServerUnreadStore(w);
    serverUnread.addListener(serverUnreadChanged);
    serverMenu.addListener(serverMenuChanged);
    if (mobileHost == null) w.resumes.addListener(appResumed);
    w.addListener(syncServerMenu);
    syncServerMenu();
    activityFlag = mobileHost?.activityFlag ?? DesktopActivityFlag(w);
    activityFlag.addListener(activityFlagChanged);
    activityDirectory =
        mobileHost?.activityDirectory ?? MessageReferenceDirectory(w);
    liveActivities =
        mobileHost?.liveActivities ??
        ChatAgentPresentation(w, activityDirectory);
    liveActivities.addListener(syncLiveActivityShown);
    syncLiveActivityShown();
    shellIdentities = bindShellIdentities();
    w.addListener(syncChannelSearch);
    w.addListener(syncPresentation);
    syncPresentation();
    w.addListener(syncSidebarDisclosure);
    syncSidebarDisclosure();
    w.addListener(syncSavedIds);
    syncSavedIds();
    mainSelection.addListener(chatSelectionChanged);
    threadSelection.addListener(chatSelectionChanged);
    restorePanels();
    w.addListener(syncSidebarAgents);
    w.addListener(syncBridgeFlag);
    w.addListener(syncWorkspaceError);
    syncWorkspaceError();
    syncSidebarAgents();
    if (mobileHost == null) {
      syncBridgeFlag();
    } else {
      bridgeEnabled = mobileHost!.bridgeEnabled;
      providerEnabled = mobileHost!.providerEnabled;
      labsEnabled = mobileHost!.labsEnabled;
    }
  }

  void syncBridgeFlag() {
    if (skipCoveredPage) return;
    final host = mobileHost;
    if (host != null) {
      bridgeEnabled = host.bridgeEnabled;
      providerEnabled = host.providerEnabled;
      labsEnabled = host.labsEnabled;
      return;
    }
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
    final request = ++bridgeRequest;
    // Settings rail gates (WorkspaceSettingsModal hiddenTabIds): IM Bridges
    // and Labs follow their flags alone; AI Providers also needs
    // manageExternalAuth (checked by WorkspaceSettings).
    if (w.server == null) {
      bridgeEnabled = false;
      providerEnabled = false;
      labsEnabled = false;
      return;
    }
    // Last evaluation under this identity: the first frame already has the
    // final navigation, and the fresh evaluation replaces it in place.
    final memory = [
      w.client.origin,
      w.client.user?.id,
      w.server?.id,
      w.server?.string('role'),
    ];
    bridgeEnabled = FeatureFlagMemory.read(memory, 'slack_bridge_v0') ?? false;
    providerEnabled =
        FeatureFlagMemory.read(memory, 'provider_connections_v0') ?? false;
    labsEnabled = FeatureFlagMemory.read(memory, 'server_labs_ui_v0') ?? false;
    () async {
      try {
        final result = await w.client.post(
          '/feature-flags/evaluate',
          data: featureFlagEvaluateBody(keys: ['slack_bridge_v0', 'provider_connections_v0', 'server_labs_ui_v0'], serverId: w.server!.id),
        );
        if (!mounted || request != bridgeRequest) return;
        final rows = result is Map
            ? result['evaluations'] as List? ?? []
            : const [];
        final provider = rows.whereType<Map>().any(
          (f) => f['key'] == 'provider_connections_v0' && f['enabled'] == true,
        );
        final bridge = rows.whereType<Map>().any(
          (f) => f['key'] == 'slack_bridge_v0' && f['enabled'] == true,
        );
        final labs = rows.whereType<Map>().any(
          (f) => f['key'] == 'server_labs_ui_v0' && f['enabled'] == true,
        );
        FeatureFlagMemory.write(memory, {
          'provider_connections_v0': provider,
          'slack_bridge_v0': bridge,
          'server_labs_ui_v0': labs,
        });
        if (provider == providerEnabled &&
            bridge == bridgeEnabled &&
            labs == labsEnabled) {
          return;
        }
        setState(() {
          providerEnabled = provider;
          bridgeEnabled = bridge;
          labsEnabled = labs;
        });
      } catch (_) {
        /* Unresolved flags keep bridge navigation unavailable. */
      }
    }();
  }

  @override
  void didUpdateWidget(covariant WorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    adoptHostSearchEntry();
    if (!identical(oldWidget.controller, w)) {
      _mobileNavigationSelection?.dispose();
      _mobileNavigationSelection = null;
      oldWidget.controller.removeListener(syncMobileAppBadge);
      w.addListener(syncMobileAppBadge);
      syncMobileAppBadge();
      activityUnread.removeListener(activityUnreadChanged);
      activityUnread = w.services.activityUnread..addListener(activityUnreadChanged);
      serverMenu.close();
      if (mobileHost == null) {
        oldWidget.controller.resumes.removeListener(appResumed);
        w.resumes.addListener(appResumed);
      }
      oldWidget.controller.removeListener(syncServerMenu);
      serverUnread.dispose();
      serverUnread = SourceServerUnreadStore(w)
        ..addListener(serverUnreadChanged);
      w.addListener(syncServerMenu);
      serverMenuScope = null;
      syncServerMenu();
      _desktopNavigation = null;
      mobileRouteAuthority = null;
      w.mobileNavigation = !wide;
      oldWidget.controller.releaseConversationPresentation(this);
      oldWidget.controller.removeListener(syncChannelSearch);
      channelSearchSeed = channelSearchAuthority = null;
      channelSearchRevoked = false;
      w.addListener(syncChannelSearch);
      oldWidget.controller.removeListener(syncPresentation);
      oldWidget.controller.removeListener(syncSidebarDisclosure);
      quickSwitcher.rebind(w);
      liveActivities.dispose();
      activityDirectory.dispose();
      activityFlag.removeListener(activityFlagChanged);
      activityFlag.dispose();
      activityFlag = DesktopActivityFlag(w)..addListener(activityFlagChanged);
      activityDirectory = MessageReferenceDirectory(w);
      liveActivities = ChatAgentPresentation(w, activityDirectory)
        ..addListener(syncLiveActivityShown);
      syncLiveActivityShown();
      shellIdentities.dispose();
      shellIdentities = bindShellIdentities();
      w.addListener(syncPresentation);
      syncPresentation();
      w.addListener(syncSidebarDisclosure);
      syncSidebarDisclosure();
      oldWidget.controller.removeListener(syncSavedIds);
      w.addListener(syncSavedIds);
      syncSavedIds();
      oldWidget.controller.removeListener(syncSidebarAgents);
      oldWidget.controller.removeListener(syncBridgeFlag);
      oldWidget.controller.removeListener(syncWorkspaceError);
      w.addListener(syncSidebarAgents);
      w.addListener(syncBridgeFlag);
      w.addListener(syncWorkspaceError);
      syncWorkspaceError();
      bridgeScope = null;
      syncBridgeFlag();
      syncSidebarAgents();
    }
  }

  bool workspaceErrorScheduled = false;

  /// A workspace-level failure (`w.error`) is Web's `toast.error`: it shows in
  /// the app-wide toast and is cleared so it is not shown twice. Runs after the
  /// frame because the controller can notify mid-build.
  void syncWorkspaceError() {
    if (skipCoveredPage || w.error == null || workspaceErrorScheduled) return;
    workspaceErrorScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      workspaceErrorScheduled = false;
      if (!mounted) return;
      final message = w.error;
      if (message == null) return;
      // ignore: raft_lints/avoid_imperative_notice_state -- Consumes the pending workspace error into a toast.
      w.setError(null);
      showLocalErrorToast(context, message);
    });
    // ignore: raft_lints/avoid_unreviewed_idle_work -- Single frame so the post-frame callback that shows and clears w.error (Web toast.error) runs even when nothing else rebuilds; the callback never re-requests.
    WidgetsBinding.instance.ensureVisualUpdate();
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

  void applyPanels(SharedPreferences prefs) {
    sidebarWidth = (prefs.getDouble('raft.layout.sidebarWidth') ?? 240).clamp(
      180,
      320,
    );
    threadWidth = prefs.getDouble('raft.layout.threadWidth') ?? 400;
    masterWideWidth = prefs.getDouble('raft.layout.masterWideWidth') ?? 560;
    masterCompactWidth =
        prefs.getDouble('raft.layout.masterCompactWidth') ?? 320;
  }

  /// Saved panel widths come from the preferences preloaded at app start, so
  /// the first frame already has them; only an unloaded store falls back to
  /// an asynchronous read.
  Future<void> restorePanels() async {
    final loaded = DevicePreferences.current;
    if (loaded != null) {
      applyPanels(loaded);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => applyPanels(prefs));
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
    clearWorkspaceSettingsCache(this);
    _mobileNavigationSelection?.dispose();
    w.removeListener(syncMobileAppBadge);
    mobileAppBadge.removeListener(chatSelectionChanged);
    mobileAppBadge.dispose();
    _ownedMobileTabbar?.dispose();
    _ownedRailSide?.dispose();
    activityUnread.removeListener(activityUnreadChanged);
    if (mobileHost == null) w.resumes.removeListener(appResumed);
    w.removeListener(syncServerMenu);
    serverMenu.removeListener(serverMenuChanged);
    serverMenu.dispose();
    rowToast.dispose();
    serverUnread.removeListener(serverUnreadChanged);
    if (mobileHost == null) {
      serverUnread.dispose();
    }
    serverUnreadTimer?.cancel();
    persistPanels?.cancel();
    w.releaseConversationPresentation(this);
    w.removeListener(syncChannelSearch);
    w.removeListener(syncPresentation);
    w.removeListener(syncSidebarDisclosure);
    w.removeListener(syncSavedIds);
    HardwareKeyboard.instance.removeHandler(globalShortcut);
    searchFocusRequests.dispose();
    quickSwitcher.dispose();
    sidebarDisclosure.dispose();
    liveActivities.removeListener(syncLiveActivityShown);
    if (mobileHost == null) liveActivities.dispose();
    liveActivityShown.dispose();
    shellIdentities.dispose();
    if (mobileHost == null) activityDirectory.dispose();
    activityFlag.removeListener(activityFlagChanged);
    if (mobileHost == null) activityFlag.dispose();
    ownedPresentation.dispose();
    mainSelection.dispose();
    threadSelection.dispose();
    w.removeListener(syncSidebarAgents);
    w.removeListener(syncBridgeFlag);
    w.removeListener(syncWorkspaceError);
    bridgeRequest++;
    LayoutHold.count.removeListener(layoutHoldChanged);
    super.dispose();
  }

  /// Escape for the content inside the shell's Scaffold. The Scaffold
  /// registers its own `DismissIntent` action (close the drawer), and the
  /// nearest registered action wins even while it is disabled, so a scope
  /// above the Scaffold never sees Escape once a control inside it has focus.
  Widget dismissInScaffold(VoidCallback? onEscape, Widget child) =>
      RaftDismissScope(onDismiss: onEscape ?? escapePanel, child: child);

  /// Escape: closes the topmost closable layer and nothing else (Web's
  /// document listeners do not navigate Back from a plain page).
  void escapePanel() {
    final layer =
        mobileHost != null ||
        w.location.profile != null ||
        w.location.task != null ||
        w.location.legacyTask != null ||
        w.location.channelPage != null ||
        w.location.thread != null ||
        wide && desktopNavigation.target != null ||
        threadSelection.active ||
        mainSelection.active ||
        scaffold.currentState?.isDrawerOpen == true ||
        w.messageDomain.state.threadParent != null && w.section == 'chat';
    if (layer) dismissPanel();
  }

  void dismissPanel() {
    final host = mobileHost;
    if (host != null) {
      if (threadSelection.dismiss() || mainSelection.dismiss()) return;
      host.dismissPanel();
      return;
    }
    if (w.location.task != null || w.location.legacyTask != null) {
      if (wide) {
        w.navigation.back();
      } else {
        backMobilePage(w.navigation);
      }
      w.notifyListeners();
      return;
    }
    if (threadSelection.dismiss() || mainSelection.dismiss()) return;
    if (scaffold.currentState?.isDrawerOpen == true) {
      scaffold.currentState?.closeDrawer();
      return;
    }
    if (wide && desktopNavigation.target != null) {
      // Column 4 (profile, then thread) closes before its column-3 detail.
      final panels = DesktopNavigationPolicy.sidePanels(
        route: w.section,
        wide: wide,
        location: w.location,
        target: desktopNavigation.target?.kind,
      );
      if (panels.profile) {
        w.closeProfile();
      } else if (panels.thread) {
        closeThreadPanel();
      } else {
        closeDesktopDetail();
      }
      return;
    }
    // A thread parent kept in the message domain without a thread in the
    // location is a visible panel only on a wide window. On a phone the pages
    // are the location: consuming Back here would leave the Navigator one
    // page short of the location (a blank page) and Back would do nothing.
    if (wide &&
        w.messageDomain.state.threadParent != null &&
        w.location.thread == null &&
        w.section == 'chat') {
      w.closeThread();
      return;
    }
    final previous = w.location;
    final next = wide ? w.navigation.back() : backMobilePage(w.navigation);
    pendingDesktopSelection = false;
    if (next.thread == null) w.closeThread(navigate: false);
    mobileSettingsRevision++;
    w.notifyListeners();
    if ({RaftRoute.channel, RaftRoute.dm}.contains(next.route) &&
        (w.channel?.id != next.entityId ||
            next.messageId != null && next.messageId != previous.messageId)) {
      unawaited(
        w.jumpToMessage(next.entityId!, next.messageId, navigate: false),
      );
    }
    setState(() {});
  }

  int adoptedHostSearchEntry = 0;

  /// A live mobile page is created after the host chose a section, so the
  /// entry intent the host recorded (fresh channel search, saved-search
  /// restore) is adopted once per entry rather than lost with the old page.
  void adoptHostSearchEntry() {
    final host = mobileHost;
    if (host == null || host.searchEntryRevision == adoptedHostSearchEntry) {
      return;
    }
    adoptedHostSearchEntry = searchEntryRevision = host.searchEntryRevision;
    restoreSavedSearchRevision = host.restoreSavedSearchRevision;
    channelSearchSeed = host.channelSearchSeed;
    channelSearchAuthority = host.channelSearchAuthority;
    channelSearchRevoked = host.channelSearchRevoked;
  }

  void select(
    String section, {
    String? searchChannelId,
    String? searchQuery,
    bool restoreSavedSearch = false,
  }) {
    if (!NavigationRegistry.knowsSection(section)) {
      NavigationRegistry.reportFallback(
        'section',
        section,
        NavigationRegistry.unsupportedSections[section],
      );
      return;
    }
    final host = mobileHost;
    if (host != null) {
      // The covered page's projected location is stale after a section change;
      // the accepted source's host decorates the new entry.
      host.select(
        section,
        searchChannelId: searchChannelId,
        searchQuery: searchQuery,
        restoreSavedSearch: restoreSavedSearch,
      );
      return;
    }
    if (!w.canVisitSection(section)) return;
    desktopNavigation.bind(desktopAuthority);
    pendingDesktopSelection = false;
    if (section == 'search') {
      setState(() {
        searchEntryRevision++;
        if (restoreSavedSearch) {
          restoreSavedSearchRevision = searchEntryRevision;
        }
        channelSearchSeed = searchChannelId;
        channelSearchAuthority = searchChannelId == null
            ? null
            : channelSearchPageAuthority(w);
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
    if (section == 'search' && searchChannelId != null) {
      w.navigation.navigate(
        w.location.withQuery({'channelId': searchChannelId, 'defer': '1'}),
        kind: RaftNavigationKind.replace,
      );
      w.notifyListeners();
    } else if (section == 'search' && searchQuery?.trim().isNotEmpty == true) {
      // The switcher's "Search for" row hands its query to the full page.
      w.navigation.navigate(
        w.location.withQuery({'q': searchQuery!.trim()}),
        kind: RaftNavigationKind.replace,
      );
      w.notifyListeners();
    }
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
    desktopNavigation.clear();
    await w.selectChannel(fresh ?? c);
  }

  void updateChannelAuthority() {
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
  }

  String bindPageAuthority() {
    final authority = jsonEncode([
      identityHashCode(w.presentationSource ?? w),
      w.client.origin,
      w.client.generation,
      w.client.user?.id,
      w.server?.id,
      w.server?.string('role'),
      mobileHost?.channelAuthorityRevision ?? channelAuthorityRevision,
    ]);
    if (lastAuthority != authority) {
      if (lastAuthority != null && w.location.channelPage != null) {
        w.navigation.navigate(
          w.location.withQuery({'channelPage': null}),
          kind: RaftNavigationKind.replace,
        );
      }
      retainedSettingsContent = null;
      conversationInstance = null;
      clearWorkspaceSettingsCache(this);
      lastAuthority = authority;
      final navigator = Navigator.of(context, rootNavigator: true);
      for (final observer
          in navigator.widget.observers.whereType<PrivateRouteGuard>()) {
        observer.scopeChanged(authority);
      }
    }
    return authority;
  }

  @override
  Widget build(BuildContext context) => NotificationActivationWorkspace(
    service: widget.notifications,
    mobileRoutePage: widget.mobileRoutePage,
    railSide: railSideStore,
    builder: buildHost,
  );

  Widget buildHost(BuildContext context) {
    final live = RaftAdaptiveWorkspace.compactOf(context);
    final compact = LayoutHold.held ? heldCompact ?? live : live;
    if (!LayoutHold.held) heldCompact = live;
    final Widget body;
    if (!widget.mobileRoutePage && compact) {
      body = ListenableBuilder(
        listenable: Listenable.merge([
          mobileNavigationSelection,
          mobileTabbar,
          railSideStore,
        ]),
        builder: (context, _) {
          ensureLayoutLocation();
          updateChannelAuthority();
          if (RouteFrameDiagnostics.enabled) {
            RouteFrameDiagnostics.location(
              w.location.thread == null
                  ? w.location.route.name
                  : '${w.location.route.name}/thread',
            );
          }
          bindPageAuthority();
          if (mobileStorageAuthority != desktopAuthority) {
            mobileStorageAuthority = desktopAuthority;
            mobilePageStorage = PageStorageBucket();
          }
          w.navigation.mobileTabs = mobileTabIds.toSet();
          return MobileWorkspacePages(
            storageBucket: mobilePageStorage,
            key: ValueKey('mobile-pages-$desktopAuthority'),
            navigation: w.navigation,
            onBack: dismissPanel,
            pageBuilder: (context, location) =>
                _MobileWorkspaceRoute(host: this, location: location),
          );
        },
      );
    } else {
      body = buildWorkspace(context);
    }
    return PersonalPresentationScope(
      store: presentation,
      // Account-level entry/resume work belongs to the workspace, not each
      // page in its retained mobile Navigator.
      child: widget.mobileRoutePage
          ? body
          : AnnouncementHost(controller: w, child: body),
    );
  }

  Widget buildWorkspace(BuildContext context) => QuietListenableBuilder(
    listenable: Listenable.merge([
      w,
      presentation,
      mobileTabbar,
      railSideStore,
      liveActivityShown,
      shellIdentities,
      sidebarDisclosure,
    ]),
    builder: (context, _) {
      final pageRoute = widget.mobileRoutePage
          ? context.findAncestorStateOfType<_MobileWorkspaceRouteState>()
          : null;
      if (pageRoute != null &&
          pageRoute.content != null &&
          (!pageRoute.active ||
              MobileRouteGate.staleChannel(pageRoute.widget.location, w))) {
        return pageRoute.content!;
      }
      if (pageRoute != null && !pageRoute.active) return const SizedBox.shrink();
      final buildStarted = RouteFrameDiagnostics.enabled
          ? RouteFrameDiagnostics.now()
          : 0;
      ensureLayoutLocation();
      // Computers and Activity are tab roots only while the bar has them.
      w.navigation.mobileTabs = mobileTabIds.toSet();
      final attentionOwner = activityUnread;
      final attentionScope = attentionOwner.scope;
      final attentionEpoch = attentionOwner.authorityEpoch;
      updateChannelAuthority();
      final authority = bindPageAuthority();
      if (mobileRouteAuthority != mobileAuthority) {
        mobileRouteAuthority = mobileAuthority;
        mobileSettingsRevision++;
      }
      desktopNavigation.bind(desktopAuthority);
      if (wide &&
          desktopNavigation.masterRoute == null &&
          ['search', 'activity'].contains(w.section)) {
        desktopNavigation.selectRoute(w.section);
      }
      final navigationScope = mobileAuthority;
      final location = w.location;
      final route = location.route == RaftRoute.settings
          ? 'settings'
          : w.section;
      final unresolvedChannelRoute =
          {RaftRoute.channel, RaftRoute.dm}.contains(location.route) &&
          w.channel?.id != location.entityId;
      if (route == 'search' &&
          channelSearchSeed == null &&
          !channelSearchRevoked &&
          location.query('channelId') != null) {
        channelSearchSeed = location.query('channelId');
        channelSearchAuthority = channelSearchPageAuthority(w);
      }
      final t = RaftTokens.of(context);
      final sidePanels = DesktopNavigationPolicy.sidePanels(
        route: route,
        wide: wide,
        location: location,
        target: desktopNavigation.target?.kind,
      );
      final thread = sidePanels.thread;
      final phoneChatDirect =
          widget.mobileRoutePage &&
          (location.route == RaftRoute.channel ||
              location.route == RaftRoute.dm);
      final rootTab = w.navigation.mobileRootTabOf(location);
      // The left rail stands in for the bottom bar on the same tab roots.
      final railShown = railNavigation && rootTab != null && w.server != null;
      final railOnRight = RaftRailSideScope.onRight(
        railSideStore.side,
        Directionality.of(context),
      );
      final navigationOnRight = desktopNavigationOnRight;
      final title = route == 'chat' || route == 'home'
          ? (w.channel?.name ?? tr('Workspace'))
          : tr(switch (route) {
              'activity' => 'Activity',
              'settings' => 'Settings',
              _ => route[0].toUpperCase() + route.substring(1),
            });
      Widget conversation() {
        final panel = ConversationPanel(
          controller: w,
          selectionHandle: mainSelection,
          onTask: openTaskSurface,
          onMessageTask: openMessageTaskSurface,
          onViewBilling: () => select('billing'),
          onOpenChannelSettings: channelSettings,
        );
        return ServerSetupGate(
          controller: w,
          onSwitchServer: showWorkspaceSwitcher,
          child: phoneChatDirect
              ? MobileChatDirectRead(
                  channel: true,
                  thread: false,
                  child: panel,
                )
              : panel,
        );
      }
      // Mobile home keeps the sidebar mounted while the lists load and shows
      // SidebarRowsSkeleton rows (Sidebar.tsx channelsLoading), not a spinner.
      Widget content = w.loading && w.server == null
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
          : route == 'members'
          ? DesktopDirectoryView(
              key: ValueKey('directory-$mobileAuthority'),
              controller: w,
              mobileRoot: !wide,
              selected: desktopNavigation.target,
              onSelected: selectDesktopDirectoryTarget,
            )
          : route == 'agents' || route == 'computers'
          ? wide
                ? DesktopDirectoryView(
                    key: ValueKey('directory-$mobileAuthority-$route'),
                    controller: w,
                    computers: route == 'computers',
                    selected: desktopNavigation.target,
                    onSelected: selectDesktopDirectoryTarget,
                  )
                : FleetView(
                    key: ValueKey('fleet-${w.server!.id}:$route'),
                    controller: w,
                    computers: route == 'computers',
                    attentionOnly:
                        route == 'computers' &&
                        location.query('filter') == 'attention',
                    onOpenDetail: (row) => openDirectoryLocation(
                      route == 'computers'
                          ? RaftRoute.computer
                          : RaftRoute.agent,
                      row['id'] as String,
                    ),
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
          : route == 'chat' && unresolvedChannelRoute
          ? w.missingConversationChannelId == location.entityId
                ? RaftChannelResolutionBody(
                    label: tr('Select a channel'),
                    backLabel: tr('Back'),
                    onBack: dismissPanel,
                  )
                : RaftChannelResolutionBody(label: tr('Loading channel'))
          : route == 'chat' || route == 'home'
          ? shownConversation(conversation)
          : route == 'search' && channelSearchRevoked
          ? Center(child: Text(tr('Channel is no longer available')))
          : mobileResourceBody(
              route: route,
              page: w,
              outer: mobileHost?.w,
              direct: widget.mobileRoutePage,
              active: () => pageRoute?.active ?? true,
              wide: wide,
              rootTab: rootTab,
              activityMasterDetail: activityFlag.masterDetail(
                MediaQuery.sizeOf(context).width,
              ),
              buildList: (owner) => ResourceView(
              key: ValueKey(
                '${owner.server?.id}:$route:${route == 'search' ? '$searchEntryRevision:$channelSearchSeed:$channelSearchAuthority' : (wide ? 'wide' : 'narrow')}',
              ),
              controller: owner,
              section: route,
              // Phone tasks open on the outer workspace. That controller is
              // the direct list's owner. Desktop has no outer host, so this
              // page's controller is the owner.
              onTask: (row, reload) {
                final host = mobileHost;
                if (host != null) {
                  host.openTaskSurface(row, reload);
                  return;
                }
                openTaskSurface(row, reload);
              },
              mobileRoot: !wide && rootTab == 'activity',
              activitySidebarEnabled:
                  route == 'activity' && activityFlag.enabled,
              compactActivitySidebar:
                  route == 'activity' &&
                  wide &&
                  activityFlag.masterDetail(MediaQuery.sizeOf(context).width),
              onActivityWindowAccepted: route == 'activity'
                  ? (window, {firstPage = false}) {
                      if (!identical(attentionOwner, activityUnread)) return;
                      if (window == null) {
                        attentionOwner.deny(
                          scope: attentionScope,
                          authorityEpoch: attentionEpoch,
                        );
                      } else {
                        attentionOwner.acceptWindow(
                          window,
                          scope: attentionScope,
                          authorityEpoch: attentionEpoch,
                          firstPage: firstPage,
                        );
                      }
                    }
                  : null,
              initialQuery:
                  route == 'search' &&
                      restoreSavedSearchRevision != searchEntryRevision
                  ? location.query('q')
                  : null,
              searchMemory: quickSwitcher.searchMemory,
              searchFocusRequests: route == 'search'
                  ? searchFocusRequests
                  : null,
              restoreSearchState:
                  searchEntryRevision == 0 ||
                  restoreSavedSearchRevision == searchEntryRevision,
              initialSearchDeferUntilQuery:
                  route == 'search' && channelSearchSeed != null,
              initialSearchChannelId: route == 'search'
                  ? channelSearchSeed
                  : null,
              onBack: dismissPanel,
              // Search and activity are not direct. [owner] is this page's
              // controller, and these openers use that same controller.
              onSearchEntity: wide ? openDesktopEntity : null,
              onSearchMessage: openSearchMessage,
              onSearchQueryCommitted: route == 'search'
                  ? (query) {
                      if (!mounted ||
                          navigationScope != mobileAuthority ||
                          !owner.canVisitSection('search')) {
                        return;
                      }
                      if (owner.navigation.replaceSearchQuery(query)) {
                        owner.notifyListeners();
                      }
                    }
                  : null,
              activitySelectedTarget:
                  route == 'activity' &&
                      wide &&
                      activityFlag.masterDetail(
                        MediaQuery.sizeOf(context).width,
                      )
                  ? desktopNavigation.target
                  : null,
              onActivityCanonical:
                  wide &&
                      activityFlag.masterDetail(
                        MediaQuery.sizeOf(context).width,
                      )
                  ? (row) => openCanonicalActivity(row)
                  : null,
              onActivityItem: (row) =>
                  wide &&
                      activityFlag.masterDetail(
                        MediaQuery.sizeOf(context).width,
                      )
                  ? openDesktopActivity(row)
                  : openCanonicalActivity(row, single: true),
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
                  await owner.jumpToMessage(channelId, messageId);
                }
              },
            ),
            );
      if (['members', 'agents', 'computers'].contains(route)) {
        final detail = desktopContentDetail();
        content = widget.mobileRoutePage && detail != null
            ? detail
            : DesktopMasterDetail(
                master: content,
                directoryWidth: sidebarWidth,
                onWidthChanged: (value, _) {
                  setState(() => sidebarWidth = value);
                  savePanels(value, threadWidth);
                },
                detail:
                    desktopContentDetail() ??
                    (wide ? const SizedBox.expand() : null),
              );
      }
      if (DesktopNavigationPolicy.forSection(route).contentMasterDetail) {
        content = DesktopMasterDetail(
          master: content,
          detail: desktopContentDetail(),
          compact: thread,
          masterEdge: route == 'search',
          wideWidth: masterWideWidth,
          compactWidth: masterCompactWidth,
          onWidthChanged: saveMasterPanel,
        );
      }
      final showingConversation =
          (route == 'chat' || route == 'home' && wide) &&
          !unresolvedChannelRoute;
      if (w.server != null) {
        final currentContent = content;
        if (!showingConversation) {
          retainedSettingsContent = route == 'settings' ? currentContent : null;
          if (route != 'settings') clearWorkspaceSettingsCache(this);
        }
        // Keep one admitted conversation, not an unbounded cache of routes.
        // The pager removes hidden content from layout, focus and semantics;
        // authority changes discard its retained elements together.
        content = RaftSectionPager<String>(
          key: ValueKey('workspace-content-$authority:$unresolvedChannelRoute'),
          sections: const ['conversation', 'other'],
          value: showingConversation ? 'conversation' : 'other',
          onChanged: null,
          swipeEnabled: false,
          builder: (context, id) => id == 'conversation'
              ? showingConversation
                    ? currentContent
                    : hiddenConversation(conversation)
              : showingConversation
              ? retainedSettingsContent ?? const SizedBox.expand()
              : currentContent,
        );
      }
      Widget workspace(
        double legacyDockWidth,
        VoidCallback? onLegacyEscape,
      ) => RaftDismissScope(
        // Web closes panels from a document-level Escape listener; here the
        // scope holds the shell's initial focus, so Escape reaches it even
        // before anything inside was focused.
        onDismiss: onLegacyEscape ?? escapePanel,
        child: PopScope(
          // Tasks/channel management own mobile MaterialPages. Their hidden
          // workspace must allow the platform page to pop; desktop panels and
          // active selection/drawer actions still consume Back locally.
          canPop:
              !wide &&
                  (w.location.task != null ||
                      w.location.legacyTask != null ||
                      w.location.channelPage != null) ||
              w.location.task == null &&
                  w.location.legacyTask == null &&
                  !mainSelection.active &&
                  !threadSelection.active &&
                  (!wide || !thread) &&
                  // Wide layouts show a profile / directory detail beside the
                  // list: Back closes it instead of leaving the route.
                  (!wide ||
                      w.location.profile == null &&
                          desktopNavigation.target == null) &&
                  scaffold.currentState?.isDrawerOpen != true,
          onPopInvokedWithResult: (didPop, _) {
            // A channel page may consume Back internally (e.g. Add Members).
            // Its hidden workspace must not also advance the business history.
            if (didPop || raftDismissTopPopup(context)) return;
            if (w.location.channelPage == null) dismissPanel();
          },
          child: Scaffold(
            key: scaffold,
            // Phones: the tab bar must not ride up with the keyboard, so the
            // adaptive workspace shrinks only its content region above it.
            resizeToAvoidBottomInset: wide,
            // No drawer: phones reach the sidebar through the Home tab (as Web
            // does). A drawer here would open from a left-edge swipe, racing
            // Android's back gesture, with nothing in the app opening it.
            body: dismissInScaffold(onLegacyEscape, RaftSystemBarSurface(
              statusBarFallback: t.canvas,
              child: SafeArea(
                bottom: false,
                // The rail paints under its own side's system inset.
                left: !railShown || railOnRight,
                right: !railShown || !railOnRight,
                child: Column(
                  children: [
                    if (!wide && rootTab == 'computers' && !thread)
                      // With the rail the header sits beside it, in the content.
                      ...[
                        if (!railShown) RaftMobileRootHeader(title: 'Computers'),
                      ]
                    else if (!wide &&
                        location.route != RaftRoute.computer &&
                        // A profile overlay brings its own header.
                        location.profile == null &&
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
                      if (thread || !unresolvedChannelRoute)
                        mobilePageHeader(title, thread),
                    RaftToastPortal(controller: rowToast),
                    Expanded(
                      child: ProfileOutsideTapDismiss(
                        controller: w,
                        panelKey: profilePanelKeyFor(w),
                        // Wide layouts only: a phone / folded profile is a page.
                        enabled: wide,
                        onDismiss: w.closeProfile,
                        child: RaftAdaptiveWorkspace(
                          key: ValueKey('adaptive-workspace-$authority'),
                          onPresentationChanged: (main, thread) =>
                              w.setConversationPresentation(
                                this,
                                main: main,
                                thread: thread,
                              ),
                          sidebarWidth: sidebarWidth,
                          trailingExtent: legacyDockWidth,
                          threadWidth: threadWidth,
                          onPanelWidthsChanged: savePanels,
                          sidebarResizeLabel: tr('Resize sidebar'),
                          threadResizeLabel: tr('Resize thread'),
                          sidebarVisible: DesktopNavigationPolicy.forSection(
                            route,
                          ).usesConversationSidebar,
                          // Phones mount neither; only desktop widths consume them.
                          sidebar: wide ? sidebar() : const SizedBox.shrink(),
                          navigationOnRight: navigationOnRight,
                          rail: wide
                              ? RailGestureExclusion(
                                  itemArea: railItemArea,
                                  // A rail on the right edge is kept clear of
                                  // the back swipe, as the phone rail is.
                                  enabled: navigationOnRight,
                                  child: workspaceRail(),
                                )
                              : const SizedBox.shrink(),
                          mobileNavigationFloating: !t.brutal,
                          mobileNavigationClearance: raftTabBarClearance(
                            liveActivity: liveActivityVisible,
                          ),
                          mobileRail: railShown
                              ? RailGestureExclusion(
                                  itemArea: railItemArea,
                                  // Back swipes start at both window edges;
                                  // a rail on the right is kept clear of them.
                                  enabled: railOnRight,
                                  child: workspaceRail(),
                                )
                              : null,
                          mobileNavigation: railNavigation
                              // Only the live activity strip docks in the
                              // content region next to the rail.
                              ? railShown && liveActivityVisible
                                    ? Padding(
                                        padding: EdgeInsets.only(
                                          bottom: raftSystemBottomInset(
                                            context,
                                          ),
                                        ),
                                        child: liveActivityBar(),
                                      )
                                    : null
                              : w.navigation.mobileRootTabOf(location) ==
                                        null ||
                                    w.server == null
                              ? null
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    liveActivityBar(),
                                    mobileNavigation(),
                                  ],
                                ),
                          content: Column(
                            children: [
                                        // The Computers root header sits in the
                                        // content region beside the rail.
                                        if (railShown &&
                                            rootTab == 'computers' &&
                                            !thread)
                                          RaftMobileRootHeader(
                                            title: 'Computers',
                                          ),
                                        // Settings composes its own sidebar and
                                        // content headers in the shared top row.
                                        if (wide &&
                                            !unresolvedChannelRoute &&
                                            ![
                                              'settings',
                                              'home',
                                              'tasks',
                                              'saved',
                                              'activity',
                                              'search',
                                              'members',
                                              'computers',
                                            ].contains(route))
                                          route == 'chat' &&
                                                  w.channel != null &&
                                                  [
                                                    'channel',
                                                    'private',
                                                    'joint',
                                                  ].contains(w.channel!.type)
                                              ? channelHeader()
                                              : route == 'chat' &&
                                                    w.channel?.type == 'dm'
                                              ? dmHeader()
                                              : RaftPageHeader(
                                                  title: route == 'home'
                                                      ? (w.channel?.name ??
                                                            title)
                                                      : title,
                                                  height: raftPageHeaderHeight(
                                                    context,
                                                  ),
                                                  icon: RaftIcon(
                                                    sectionGlyph(route),
                                                  ),
                                                  subtitle: route == 'chat'
                                                      ? w.channel?.string(
                                                          'description',
                                                        )
                                                      : null,
                                                  actions: [
                                                    RaftTooltip(
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
                                                    if (route == 'chat' &&
                                                        w.channel != null)
                                                      RaftIconButton(
                                                        tooltip:
                                                            'Channel settings',
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
                                                      glyph:
                                                          RaftGlyph.refreshCw,
                                                    ),
                                                  ],
                                                ),
                                        Expanded(
                                          child: KeyedSubtree(
                                            key: const ValueKey('classic-editor'),
                                            child: content,
                                          ),
                                        ),
                                      ],
                                    ),
                          thread: thread
                              ? RaftConversationSurface(
                                  role: RaftConversationSurfaceRole
                                      .threadTimeline,
                                  child: Column(
                                    children: [
                                      if (wide) sourceThreadHeader(),
                                      Expanded(
                                        child: ServerSetupGate(
                                          controller: w,
                                          onSwitchServer: showWorkspaceSwitcher,
                                          child: phoneChatDirect
                                              ? MobileChatDirectRead(
                                                  channel: false,
                                                  thread: true,
                                                  child: _phoneThreadChat(),
                                                )
                                              : _phoneThreadChat(),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                          profile: sidePanels.profile
                              ? profileSidePanel(location.profile!, page: !wide)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ),
        ),
      );
      final body = WorkspaceTaskHost(
        controller: w,
        onTask: openMessageTaskSurface,
        onViewBilling: () => select('billing'),
        seed: taskSeed ?? mobileHost?.taskSeed,
        // RightPanel handles content routes before its workspace guard.
        presented: true,
        leadingOnRight: navigationOnRight,
        leadingExtent: wide
            ? RaftLayoutMetrics.railWidth(
                    t,
                    MediaQuery.sizeOf(context).height,
                  ) +
                  (DesktopNavigationPolicy.forSection(
                        route,
                      ).usesConversationSidebar
                      ? sidebarWidth
                      : 0)
            : 0,
        childBuilder: (dockWidth, onEscape) => channelPageHost(
          widget.mobileRoutePage &&
                  (location.task != null || location.legacyTask != null)
              ? const RaftAdaptiveWorkspace(
                  content: SizedBox.expand(),
                  sidebar: SizedBox.shrink(),
                  rail: SizedBox.shrink(),
                )
              : widget.mobileRoutePage && location.channelPage != null
              ? const SizedBox.expand()
              : workspace(dockWidth, onEscape),
          location,
        ),
      );
      if (RouteFrameDiagnostics.enabled) {
        RouteFrameDiagnostics.scope('shellBuildUs', buildStarted);
      }
      if (pageRoute != null) pageRoute.content = body;
      return body;
    },
  );
  final threadViewport = ChatViewportHandle();

  /// A DM with the profiled member / agent (the panel's Message action).
  Future<void> messageProfile(RaftProfileKind kind, String id) async {
    final scope = desktopAuthority;
    final revision = w.navigationRevision;
    final value = await w.client.post(
      '/channels/dm',
      data: {kind == RaftProfileKind.agent ? 'agentId' : 'userId': id},
    );
    if (!mounted ||
        scope != desktopAuthority ||
        revision != w.navigationRevision) {
      return;
    }
    if (value is Map && value['id'] is String) {
      w.closeProfile();
      await w.jumpToMessage(value['id'], null);
    }
  }

  Widget _phoneThreadChat() => RaftChatView(
    controller: w,
    thread: true,
    viewportHandle: threadViewport,
    selectionHandle: threadSelection,
    onTask: openMessageTaskSurface,
    onViewBilling: () => select('billing'),
  );

  Widget profileSidePanel(RaftProfileLocation profile, {bool page = false}) =>
      ProfileSidePanel(
        key: profilePanelKeyFor(w),
        controller: w,
        profile: profile,
        agentTab: w.location.agentTab,
        onClose: w.closeProfile,
        onBack: page ? dismissPanel : null,
        onMessage: messageProfile,
      );

  Widget sourceThreadHeader({bool mobile = false, VoidCallback? onClose}) {
    final unresolved =
        w.threadChannelId == null &&
        (w.messageDomain.threadResolutionLoading || w.messageDomain.threadResolutionError != null);
    // The menu needs only the thread identity, never the loaded parent row,
    // so the header's actions are present at its first frame.
    final parentId = w.messageDomain.threadParentMessageId,
        parentChannelId = w.messageDomain.threadParentChannelId;
    final sourceChannel = w.messageDomain.threadSourceChannel;
    final threadId = w.threadChannelId;
    return ListenableBuilder(
      listenable: w.services.threadFollowers,
      builder: (context, _) => RetainWhileCovered(
        builder: (context) => RaftThreadHeader(
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
        parentLabel: unresolved || sourceChannel == null
            ? null
            : '${sourceChannel.type == 'dm' ? '@' : '#'}${sourceChannel.name}',
        interactiveTitle: !unresolved,
        onBack: onClose ?? (mobile ? dismissPanel : closeThreadPanel),
        onClose: onClose ?? (mobile ? dismissPanel : closeThreadPanel),
        onJumpToStart: unresolved ? null : threadViewport.jumpToBeginning,
        followers: threadId == null || unresolved
            ? null
            : ThreadAgentFollowersView(
                key: ValueKey('thread-followers-$threadId'),
                controller: w,
                threadChannelId: threadId,
                onOpenAgent: (id) => w.openProfile(RaftProfileKind.agent, id),
              ),
        followersVisible:
            threadId != null &&
            !unresolved &&
            w.services.threadFollowers.visible(threadId),
        actions: [
          if (!unresolved && parentId != null && parentChannelId != null)
            ThreadActions(
              key: ValueKey('thread-menu-$parentId'),
              controller: w,
              parentMessageId: parentId,
              menuMode: true,
              // Web ThreadPanel openThreadSearch: the in-thread search bar.
              onSearch: w.threadSearch.open,
              onViewChannel: () {
                w.closeThread(navigate: false);
                // Web openThreadParentMessageRoute: desktop pushes, phone
                // replaces the thread entry.
                w.jumpToMessage(parentChannelId, parentId, replaceEntry: !wide);
              },
            ),
        ],
      ),
      ),
    );
  }

  void closeThreadPanel() {
    if (threadSelection.dismiss()) return;
    // Source side-thread Close replaces its slot; it does not consume Back.
    // Activity/Search content slots supply their own explicit close callback.
    w.closeThread();
    pendingDesktopSelection = false;
    setState(() {});
  }

  void closeDesktopDetail() {
    final route = desktopNavigation.masterRoute;
    if (route == null) return;
    desktopNavigation.closeTarget();
    pendingDesktopSelection = false;
    w.closeThread(navigate: false);
    setState(() {});
  }

  Future<bool> openDesktopConversation(
    String channelId,
    String? messageId, {
    bool retireThread = false,
  }) async {
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
        dm: w.dms.any((channel) => channel.id == channelId),
      ),
    );
    if (retireThread) w.closeThread(navigate: false);
    pendingDesktopSelection = true;
    setState(() {});
    try {
      await w.jumpToMessage(channelId, messageId, navigate: false);
      if (!mounted ||
          !desktopNavigation.accepts(desktopAuthority, ticket) ||
          scope != desktopAuthority) {
        return false;
      }
      if (w.messageDomain.state.threadParent != null) {
        ticket = desktopNavigation.selectTarget(
          DesktopContentTarget(
            DesktopContentKind.thread,
            w.threadChannelId ?? w.messageDomain.state.threadParent!.id,
            channelId: channelId,
            messageId: messageId,
            parentMessageId: w.messageDomain.state.threadParent!.id,
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

  Future<void> openSearchMessage(Map<String, dynamic> row) async {
    final channelId = row['channelId'], messageId = row['id'];
    if (channelId is! String || messageId is! String) return;
    if (row['channelType'] != 'thread') {
      if (wide) {
        await openDesktopConversation(channelId, messageId);
      } else {
        // Keep the ordinary narrow message entry; typed thread hits below
        // use Source's Search content slot at every viewport width.
        scaffold.currentState?.closeDrawer();
        desktopNavigation.clear();
        await w.jumpToMessage(channelId, messageId);
      }
      return;
    }
    final parentChannelId = row['parentChannelId'],
        parentMessageId = row['parentMessageId'];
    if (parentChannelId is! String ||
        parentMessageId is! String ||
        channelId.isEmpty ||
        parentChannelId.isEmpty ||
        parentMessageId.isEmpty) {
      return;
    }
    final scope = desktopAuthority;
    desktopNavigation.bind(scope);
    if (desktopNavigation.masterRoute != 'search') return;
    // Source MessageSearchPage1281–1315 opens the typed hit directly. Its
    // channelId is the thread itself, never the selected main conversation.
    final ticket = desktopNavigation.selectTarget(
      DesktopContentTarget(
        DesktopContentKind.thread,
        channelId,
        channelId: parentChannelId,
        parentMessageId: parentMessageId,
        messageId: messageId,
      ),
      // Source first publishes the added thread anchor (PUSH), then mirrors
      // the Search slot into that same entry (REPLACE). Retargeting replaces.
      // MainLayout1453–1501/1594–1618; rightPanelUrlSync515–549.
      kind: w.location.panelNavigationKindTo(
        w.location.withQuery({'thread': '$parentChannelId:$parentMessageId'}),
      ),
    );
    pendingDesktopSelection = false;
    setState(() {});
    await w.openThreadIdentity(
      parentChannelId: parentChannelId,
      parentMessageId: parentMessageId,
      focusedMessageId: messageId,
      initialThreadChannelId: channelId,
      navigate: false,
    );
    if (mounted &&
        scope == desktopAuthority &&
        desktopNavigation.accepts(desktopAuthority, ticket)) {
      setState(() {});
    }
  }

  Future<void> openDesktopActivity(Map<String, dynamic> row) async {
    final scope = desktopAuthority;
    desktopNavigation.bind(scope);
    if (desktopNavigation.masterRoute != 'activity') return;
    final target = ActivityDestination.fromRow(row, canonical: false);
    if (target == null) return;
    if (!target.thread) {
      // Source ThreadsInbox1150–1184 drops the old thread when switching the
      // content slot. Retire its data without a second history transition.
      await openDesktopConversation(
        target.channelId,
        target.messageId,
        retireThread: row['kind'] != 'mention_action',
      );
      return;
    }
    // ThreadsInbox1111–1147 opens the accepted thread directly in col 3.
    // Parent metadata is independent: it never becomes the main channel's
    // window, nor a temporary channel content slot.
    final ticket = desktopNavigation.selectTarget(
      DesktopContentTarget(
        DesktopContentKind.thread,
        target.threadChannelId!,
        channelId: target.channelId,
        parentMessageId: target.parentMessageId,
        messageId: target.messageId,
      ),
    );
    pendingDesktopSelection = false;
    setState(() {});
    await w.openThreadIdentity(
      parentChannelId: target.channelId,
      parentMessageId: target.parentMessageId!,
      focusedMessageId: target.messageId,
      initialThreadChannelId: target.threadChannelId,
      navigate: false,
    );
    if (mounted &&
        scope == desktopAuthority &&
        desktopNavigation.accepts(desktopAuthority, ticket)) {
      setState(() {});
    }
  }

  Future<void> openCanonicalActivity(
    Map<String, dynamic> row, {
    bool single = false,
  }) async {
    final target = ActivityDestination.fromRow(
      row,
      canonical: !single,
      mobile: single,
    );
    if (target == null) return;
    // Upgrade the temporary preview, retaining Activity as the Back entry.
    // Both URI changes precede notification, so no empty intermediate frame
    // is painted and unrelated query slots remain owned by their consumers.
    if (!single &&
        w.location.route == RaftRoute.activity &&
        w.location.content != null) {
      w.navigation.navigate(
        w.location.withQuery({'open': null, 'msg': null, 'thread': null}),
        kind: RaftNavigationKind.replace,
      );
    }
    w.navigation.navigate(target.canonicalLocation(w.location.serverSlug));
    pendingDesktopSelection = false;
    w.closeThread(navigate: false);
    setState(() {});
    if (target.thread) {
      // ChannelById's real metadata/tail hydrate is independent of the URL's
      // thread identity. Never pass a reply ID into the parent's context GET.
      unawaited(
        w.resolveConversationChannel(target.channelId, preserveThread: true),
      );
      await w.openThreadIdentity(
        parentChannelId: target.channelId,
        parentMessageId: target.parentMessageId!,
        focusedMessageId: target.messageId,
        navigate: false,
      );
      return;
    }
    await w.jumpToMessage(target.channelId, target.messageId, navigate: false);
  }

  void openDirectoryLocation(
    RaftRoute route,
    String id, {
    String? expectedScope,
  }) {
    if (!mounted || expectedScope != null && expectedScope != mobileAuthority) {
      return;
    }
    // Human profiles are not gated on `viewMembers`: the server answers a guest
    // with the channel-scoped profile of a human they can see (routes/servers.ts
    // member profile) and Web opens it unconditionally (ProfilePanel.tsx).
    final capability = switch (route) {
      RaftRoute.agent => 'viewAgents',
      RaftRoute.computer => 'viewMachines',
      _ => null,
    };
    if (capability != null && !w.can(capability)) return;
    w.navigation.navigate(
      RaftLocation.at(
        serverSlug: w.location.serverSlug,
        route: route,
        entityId: id,
      ),
    );
    w.closeThread(navigate: false);
    w.notifyListeners();
  }

  void selectDesktopDirectoryTarget(DesktopContentTarget target) {
    desktopNavigation.bind(desktopAuthority);
    if (desktopNavigation.masterRoute == null) {
      desktopNavigation.selectRoute(w.section);
    }
    desktopNavigation.selectTarget(target);
    pendingDesktopSelection = false;
    w.closeThread(navigate: false);
    w.notifyListeners();
    setState(() {});
  }

  /// Cmd/Ctrl+K (search) and Cmd/Ctrl+, (settings) are global, like Source's
  /// document-level listener and native menu: they work wherever focus is
  /// (composer, a field, nothing focused) while this workspace is the visible
  /// route, and never under an open dialog.
  bool globalShortcut(KeyEvent event) {
    if (skipCoveredPage ||
        !widget.mobileRoutePage && RaftAdaptiveWorkspace.compactOf(context)) {
      return false;
    }
    final key = event.logicalKey;
    if (event is! KeyDownEvent ||
        key != LogicalKeyboardKey.keyK && key != LogicalKeyboardKey.comma ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    // Source isGlobalSearchShortcut: Cmd alone on macOS, Ctrl alone elsewhere.
    if (keyboard.isShiftPressed ||
        keyboard.isAltPressed ||
        !primaryShortcutModifierDown(keyboard)) {
      return false;
    }
    if (key == LogicalKeyboardKey.keyK) {
      openSearchShortcut();
    } else {
      select('settings');
    }
    return true;
  }

  /// Cmd/Ctrl+K. A desktop window floats the quick switcher over the current
  /// page (Source SearchOverlay); a narrow window keeps the full Search page.
  void openSearchShortcut() {
    if (!w.canVisitSection('search')) return;
    // Source routeGlobalSearchShortcut: the Search page is already showing, so
    // focus its field (and select the query) instead of opening another one.
    if (w.section == 'search') {
      searchFocusRequests.value++;
      return;
    }
    if (!wide) {
      select('search');
      return;
    }
    quickSwitcher.open(context);
  }

  /// The rail's Search button. A desktop window floats the same overlay as
  /// Cmd/Ctrl+K but starts fresh (Source `searchEntry: "rail"`); a narrow
  /// window keeps the full Search page.
  void openSearchFromRail() {
    if (!w.canVisitSection('search')) return;
    if (!wide) {
      select('search');
      return;
    }
    quickSwitcher.open(context, entry: QuickSwitcherEntry.rail);
  }

  Future<void> openQuickSwitcherConversation(RaftChannel channel) async {
    if (!mounted) return;
    await chooseChannel(channel);
  }

  void openQuickSwitcherDirectory(RaftRoute route, String id) {
    if (!mounted) return;
    desktopNavigation.clear();
    openDirectoryLocation(route, id);
  }

  Future<void> openQuickSwitcherMessage(
    String channelId,
    String? messageId,
  ) async {
    if (!mounted) return;
    scaffold.currentState?.closeDrawer();
    desktopNavigation.clear();
    await w.jumpToMessage(channelId, messageId);
  }

  Future<void> openQuickSwitcherThread({
    required String parentChannelId,
    required String parentMessageId,
    required String messageId,
    required String threadChannelId,
  }) async {
    if (!mounted) return;
    desktopNavigation.clear();
    await w.openThreadIdentity(
      parentChannelId: parentChannelId,
      parentMessageId: parentMessageId,
      focusedMessageId: messageId,
      initialThreadChannelId: threadChannelId,
    );
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
    w.closeThread(navigate: false);
    w.notifyListeners();
  }

  Future<void> messageDesktopProfile(DesktopContentTarget target) async {
    final scope = desktopAuthority;
    final revision = w.navigationRevision;
    final value = await w.client.post(
      '/channels/dm',
      data: {
        target.kind == DesktopContentKind.agent ? 'agentId' : 'userId':
            target.id,
      },
    );
    if (!mounted ||
        scope != desktopAuthority ||
        revision != w.navigationRevision) {
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
    if (target.kind == DesktopContentKind.graph) {
      return MemberGraphPage(
        key: key,
        controller: w,
        sectionLabel: raftText(context, 'Connections'),
        onBack: closeDesktopDetail,
      );
    }
    // Web `renderContentSlot` hands Search / Activity agent and human details
    // `onBack=closeSlot` with `backButtonVisibility="always"`: Back at every
    // width. A directory / route detail keeps Back below `md` only (the phone
    // page), and nothing beside the list on wide layouts.
    final slot = const {'search', 'activity'}.contains(
      desktopNavigation.masterRoute,
    );
    if (target.kind == DesktopContentKind.human) {
      return MemberProfileView(
        key: key,
        controller: w,
        userId: target.id,
        onClose: closeDesktopDetail,
        onBack: !wide
            ? dismissPanel
            : slot
            ? closeDesktopDetail
            : null,
        showClose: false,
        onMessage: () => messageDesktopProfile(target),
      );
    }
    if (target.kind == DesktopContentKind.agent ||
        target.kind == DesktopContentKind.computer) {
      return FleetDetail(
        key: key,
        controller: w,
        computers: target.kind == DesktopContentKind.computer,
        initial:
            (target.kind == DesktopContentKind.computer
                ? w.services.entityDirectory.computer(target.id)
                : w.services.entityDirectory.agent(target.id)) ??
            {'id': target.id},
        onClose: !wide && target.kind == DesktopContentKind.computer
            ? dismissPanel
            : closeDesktopDetail,
        backAlways: slot && target.kind == DesktopContentKind.agent,
        onOpenAgent: (id) => wide
            ? desktopNavigation.selectTarget(
                DesktopContentTarget(DesktopContentKind.agent, id),
              )
            : openDirectoryLocation(RaftRoute.agent, id),
      );
    }
    final thread = target.kind == DesktopContentKind.thread;
    // The destination is still being resolved: like Source ChannelById, hold a
    // neutral "Loading channel" body instead of the previous channel's name
    // above a bare "Loading...".
    final resolving =
        pendingDesktopSelection && w.channel?.id != target.channelId;
    final content = Column(
      key: key,
      children: [
        if (thread)
          sourceThreadHeader(onClose: closeDesktopDetail)
        else
          RaftPageHeader(
            title: resolving ? '' : w.channel?.name ?? '',
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
          child: resolving
              ? thread
                    ? Center(child: Text(tr('Loading...')))
                    : RaftChannelResolutionBody(label: tr('Loading channel'))
              : ServerSetupGate(
                  controller: w,
                  onSwitchServer: showWorkspaceSwitcher,
                  child: thread
                      ? RaftChatView(
                          controller: w,
                          thread: true,
                          selectionHandle: threadSelection,
                          viewportHandle: threadViewport,
                          onTask: openMessageTaskSurface,
                          onViewBilling: () => select('billing'),
                        )
                      : ConversationPanel(
                          controller: w,
                          selectionHandle: mainSelection,
                          onTask: openTaskSurface,
                          onMessageTask: openMessageTaskSurface,
                          onViewBilling: () => select('billing'),
                          onOpenChannelSettings: channelSettings,
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
      attention: hasChatAttention,
    ),
    RaftRailDestination(
      id: 'activity',
      label: tr('Activity'),
      glyph: RaftGlyph.activity,
      iconWidget: railIcon(RaftGlyph.activity),
      attention: hasActivityAttention,
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

  Widget workspaceRail() {
    final mobileAppScope = mobileAppBadge.key;
    return RaftWorkspaceRail(
      phone: !wide,
      itemAreaKey: railItemArea,
      thinDivider: w.location.route == RaftRoute.activity,
      destinations: railDestinations,
      selected: DesktopNavigationPolicy.forSection(
        w.location.route == RaftRoute.settings ? 'settings' : w.section,
      ).railMode,
      onSelected: (id) => wide
          ? (id == 'search' ? openSearchFromRail() : select(id))
          : selectRailDestination(id),
      workspaceName: w.server?.name ?? 'Raft',
      workspaceTooltip: tr('Switch workspace'),
      workspaceHeader: workspaceServerMenu(),
      onWorkspace: () => showWorkspaceSwitcher(),
      footer: RaftWorkspaceRailFooter(
        children: [
          SystemNotificationBell(
            controller: w,
            mobile: false,
            onBilling: () => select('billing'),
            onFeedback: () => openHelpSettings('feedback'),
          ),
          RaftWorkspaceHelpMenu(
            key: const Key('rail-help'),
            label: tr('Help'),
            heading: tr('Help & resources'),
            attention: mobileAppBadge.hasAttention,
            entries: [
              RaftMenuEntry(
                label: tr('Raft Documentation'),
                leading: const RaftIcon(RaftGlyph.bookOpenText, size: 14),
                trailing: const RaftIcon(RaftGlyph.arrowUpRight, size: 14),
                onPressed: () => unawaited(openDocumentationFromHelp()),
              ),
              RaftMenuEntry(
                label: tr('Mobile App'),
                glyph: RaftGlyph.smartphone,
                // Source LeftRail: the entry carries the same AttentionDot as
                // the Help button, so the announcement says what it points at.
                trailing: mobileAppBadge.hasAttention
                    ? const RaftAttentionDot(key: Key('help-mobile-app-badge'))
                    : null,
                // Source openMobileApp: consume the announcement, then always
                // open About (seen or not).
                onPressed: () {
                  mobileAppBadge.markSeen(mobileAppScope);
                  openHelpSettings('about');
                },
              ),
              RaftMenuEntry(
                label: tr('Feedback'),
                glyph: RaftGlyph.messageSquare,
                onPressed: () => openHelpSettings('feedback'),
              ),
              RaftMenuEntry(
                label: tr(
                  joiningCommunityFromHelp ? 'Joining...' : 'Join Community',
                ),
                glyph: RaftGlyph.usersRound,
                onPressed: joiningCommunityFromHelp
                    ? null
                    : () => unawaited(openCommunityFromHelp()),
              ),
            ],
          ),
          settingsRailAction(),
        ],
      ),
    );
  }

  Widget settingsRailAction() {
    Widget action() => RaftWorkspaceRailAction(
      key: const Key('rail-settings'),
      label: tr('Settings'),
      selected: w.location.route == RaftRoute.settings,
      onPressed: () =>
          wide ? select('settings') : selectRailDestination('settings'),
      glyph: RaftGlyph.settings,
      attention: appUpdate?.hasUnseen ?? false,
    );
    final update = appUpdate;
    return update == null
        ? action()
        : ListenableBuilder(
            listenable: update,
            builder: (context, _) => action(),
          );
  }

  Widget workspaceServerMenu({bool mobile = false}) {
    final scope = mobileAuthority;
    return RaftServerSwitcher(
      mobile: mobile,
      attention: w.servers.any(
        (s) => s.id != w.server?.id && (activityCountOf(s.id) ?? 0) > 0,
      ),
      headerActions: mobile
          ? [
              SystemNotificationBell(
                key: const Key('mobile-home-notifications'),
                controller: w,
                onBilling: () => select('billing'),
                onFeedback: () => openHelpSettings('feedback'),
              ),
            ]
          : const [],
      controller: serverMenu,
      workspaceName: w.server?.name ?? 'Raft',
      workspaceAvatarUrl: raftPublicAvatarUrl(
        w.client.origin,
        w.server?.json['avatarUrl'] as String?,
      ),
      label: tr('Switch workspace'),
      rows: [
        for (final server in w.servers)
          RaftServerMenuRow(
            id: server.id,
            name: server.name,
            slug: server.string('slug'),
            avatarUrl: raftPublicAvatarUrl(
              w.client.origin,
              server.json['avatarUrl'] as String?,
            ),
            current: server.id == w.server?.id,
            activityUnreadCount: activityCountOf(server.id),
            pushMuted: serverUnread[server.id]?.pushMuted ?? false,
            onSelected: () =>
                unawaited(selectMenuServer(server, scope, mobile: mobile)),
            onAuxiliary:
                defaultTargetPlatform == TargetPlatform.linux &&
                    workspaceBrowserOrigin(w.client.origin) != null
                ? () => unawaited(openWorkspaceInBrowser(context, w, server))
                : null,
          ),
      ],
      actions: [
        if (!w.servers.any((server) => server.string('slug') == 'community'))
          RaftMenuEntry(
            label: tr('Join Community'),
            glyph: RaftGlyph.plus,
            onPressed: joiningCommunityFromHelp
                ? null
                : () => unawaited(openCommunityFromHelp()),
          ),
        RaftMenuEntry(
          label: tr('Switch or Create Server'),
          glyph: RaftGlyph.plus,
          onPressed: widget.onChooseServer == null
              ? null
              : () {
                  if (mounted && scope == mobileAuthority) {
                    widget.onChooseServer!();
                  }
                },
        ),
        if (w.can('inviteMembers'))
          RaftServerMenuAction(
            tone: RaftServerMenuActionTone.invite,
            label: tr('Invite human'),
            glyph: RaftGlyph.userPlus,
            onPressed: () => unawaited(inviteFromServerMenu(scope)),
          ),
      ],
      onReorder: (from, to) => unawaited(reorderMenuServers(from, to, scope)),
    );
  }

  void openHelpSettings(String tab) {
    mainSelection.dismiss();
    threadSelection.dismiss();
    w.closeThread(navigate: false);
    w.navigation.navigate(
      RaftLocation.at(
        serverSlug: w.location.serverSlug,
        route: RaftRoute.settings,
        settingsPath: [tab],
      ),
    );
    w.notifyListeners();
    setState(() {});
  }

  Future<void> openDocumentationFromHelp() async {
    final scope = mobileAuthority;
    try {
      await managementLaunch(WorkspaceSettings.documentationUrl);
    } catch (e) {
      if (mounted && scope == mobileAuthority) {
        // ignore: raft_lints/avoid_imperative_notice_state -- Workspace error is a one-shot toast, consumed by syncWorkspaceError; set only while the mobile authority is unchanged.
        w.setError(userErrorText(e, where: 'open documentation'));
      }
    }
  }

  Future<void> openCommunityFromHelp() async {
    if (joiningCommunityFromHelp) return;
    setState(() => joiningCommunityFromHelp = true);
    final scope = mobileAuthority;
    try {
      var joined = w.servers
          .where((s) => s.string('slug') == 'community')
          .firstOrNull;
      if (joined == null) {
        // useJoinCommunityFlow: an agreement to accept opens the dialog.
        final accepted = await joinCommunity(
          () => context,
          w.client,
          communityServerSlug,
        );
        if (!accepted || !mounted || scope != mobileAuthority) return;
        await w.recoverMembership();
        if (!mounted || scope != mobileAuthority) return;
        joined = w.servers
            .where((s) => s.string('slug') == 'community')
            .firstOrNull;
        if (joined == null) {
          throw const RaftUserError(
            "Joined community server but it's missing from the list",
          );
        }
      }
      if (joined.id == w.server?.id) {
        w.setSection('home');
      } else {
        final selecting = w.selectServer(joined);
        final selectedScope = mobileAuthority;
        await selecting;
        if (mounted &&
            selectedScope == mobileAuthority &&
            w.server?.id == joined.id) {
          w.setSection('home');
        }
      }
    } catch (e) {
      if (mounted && scope == mobileAuthority) {
        // ignore: raft_lints/avoid_imperative_notice_state -- Workspace error is a one-shot toast, consumed by syncWorkspaceError; set only while the mobile authority is unchanged.
        w.setError(
          userErrorText(
            e,
            fallback: 'Failed to join community server',
            where: 'community from help',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => joiningCommunityFromHelp = false);
    }
  }

  Future<void> showWorkspaceSwitcher() async {
    if (wide) {
      serverMenu.isOpen ? serverMenu.close() : serverMenu.open();
      return;
    }
    final scope = mobileAuthority;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('Switch workspace')),
        children: [
          for (final server in w.servers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, server.id),
              child: Listener(
                onPointerDown:
                    defaultTargetPlatform == TargetPlatform.linux &&
                        workspaceBrowserOrigin(w.client.origin) != null
                    ? (event) {
                        if (event.buttons == kMiddleMouseButton) {
                          Navigator.pop(context);
                          unawaited(openWorkspaceInBrowser(context, w, server));
                        }
                      }
                    : null,
                child: Row(
                  children: [
                    Expanded(child: Text(server.name)),
                    if (defaultTargetPlatform == TargetPlatform.linux &&
                        workspaceBrowserOrigin(w.client.origin) != null)
                      RaftIconButton(
                        key: ValueKey('workspace-browser-${server.id}'),
                        tooltip: tr('Open workspace in browser'),
                        glyph: RaftGlyph.arrowUpRight,
                        onPressed: () {
                          Navigator.pop(context);
                          unawaited(openWorkspaceInBrowser(context, w, server));
                        },
                      ),
                    if (server.id == w.server?.id)
                      const RaftIcon(RaftGlyph.check, size: 14),
                  ],
                ),
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

  Future<void> selectMenuServer(
    RaftRecord target,
    String scope, {
    bool mobile = false,
  }) async {
    if (!mounted || scope != mobileAuthority) return;
    final accepted = w.servers.where((s) => s.id == target.id).firstOrNull;
    if (accepted == null || accepted.id == w.server?.id) return;
    if (widget.onSwitchServer != null) {
      await widget.onSwitchServer!(accepted, mobile);
    } else {
      await w.selectServer(accepted);
    }
  }

  Future<void> inviteFromServerMenu(String scope) async {
    if (!mounted || scope != mobileAuthority || !w.can('inviteMembers')) return;
    final sent = await showWorkspaceMenuInvite(context, w);
    if (sent && mounted && scope == mobileAuthority) select('administration');
  }

  Future<void> reorderMenuServers(int from, int to, String scope) async {
    if (!mounted ||
        scope != mobileAuthority ||
        from == to ||
        from < 0 ||
        to < 0 ||
        from >= w.servers.length ||
        to >= w.servers.length) {
      return;
    }
    final previous = List<RaftRecord>.of(w.servers),
        ticket = ++serverOrderRequest;
    final ordered = List<RaftRecord>.of(previous);
    ordered.insert(to, ordered.removeAt(from));
    w.servers = ordered;
    w.notifyListeners();
    try {
      final result = await w.client.patch(
        '/servers/order',
        data: {'serverOrder': ordered.map((s) => s.id).toList()},
      );
      if (!mounted ||
          scope != mobileAuthority ||
          ticket != serverOrderRequest) {
        return;
      }
      final saved = result is Map ? result['serverOrder'] : null;
      if (saved is List) {
        final byId = {for (final server in w.servers) server.id: server};
        final seen = <String>{};
        w.servers = [
          for (final id in saved)
            if (id is String && byId.containsKey(id) && seen.add(id)) byId[id]!,
          for (final server in w.servers)
            if (seen.add(server.id)) server,
        ];
        w.notifyListeners();
      }
    } catch (_) {
      if (mounted && scope == mobileAuthority && ticket == serverOrderRequest) {
        // Source restores the previous order on error. Membership must still
        // be accepted; an old drag must never resurrect a removed server.
        final ids = w.servers.map((s) => s.id).toSet();
        w.servers = [
          for (final server in previous)
            if (ids.contains(server.id)) server,
        ];
        w.notifyListeners();
      }
    }
  }

  Widget mobileNavigation() {
    final scope = mobileAuthority;
    return WorkspaceMobileTabBar(
      controller: w,
      selectedId: w.navigation.mobileRootTabOf(w.location) ?? 'chat',
      tabs: mobileTabIds,
      activityUnread: activityUnread,
      appUpdate: appUpdate,
      // Native tab bars consume the system inset once, outside the nav recipe.
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
    settingsLabel: tr('Channel details and settings'),
    archivedLabel: w.channel!.archived ? tr('Archived') : null,
  );

  /// ChatPanel's DM header: identity from the DM record (first frame), the
  /// agent's status from the server-scoped agent directory.
  Widget dmHeader({bool mobile = false}) {
    final c = w.channel!;
    final peer = dmPeer(c, requestSize: 36);
    return WorkspaceDmHeader(
      headerKey: Key(
        mobile ? 'workspace-mobile-detail-header' : 'workspace-channel-header',
      ),
      controller: w,
      channel: c,
      agent: peer.agent,
      name: peer.name,
      profile: peer.profile,
      avatar: mountedPeerAvatar(
        peer.name,
        peer.agent,
        peer.avatar,
        avatarContext: RaftMountedAvatarContext.panelHeader,
      ),
      selectionActive: () => mainSelection.active,
      onBack: mobile ? dismissPanel : null,
      backKey: mobile ? const Key('mobile-detail-back') : null,
      onSearch: searchThisChannel,
      onSettings: channelSettings,
    );
  }

  Widget mobilePageHeader(String title, bool thread) => thread
      ? sourceThreadHeader(mobile: true)
      : w.section == 'chat' &&
            w.channel != null &&
            ['channel', 'private', 'joint'].contains(w.channel!.type)
      ? channelHeader(mobile: true)
      : w.section == 'chat' && w.channel?.type == 'dm'
      ? dmHeader(mobile: true)
      : RaftPageHeader(
          key: const Key('workspace-mobile-detail-header'),
          title: thread ? tr('Thread') : title,
          height: raftPageHeaderHeight(context),
          mobile: true,
          backKey: const Key('mobile-detail-back'),
          backLabel: thread
              ? (threadSelection.active ? 'Exit selection' : 'Close thread')
              : (mainSelection.active ? 'Exit selection' : 'Back'),
          onBack: dismissPanel,
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

  /// Pinned/placed agent rows come from the shared, server-scoped entity
  /// directory: they are present at the first frame after a channel switch or
  /// a pin change and are cleared only by a server-level identity change.
  void syncSidebarAgents() {
    if (skipCoveredPage || !w.can('viewAgents') || w.server == null) return;
    final pinnedAgent = [
      ...(w.sidebarOrder['pinned'] as List? ?? []),
      ...(w.sidebarOrder['sectionPlacements'] as List? ?? []),
    ].any((r) => r is Map && r['kind'] == 'agent');
    if (pinnedAgent) w.services.entityDirectory.ensureAuthors();
  }

  List<Map<String, dynamic>>? sidebarAgentSource;
  List<Map<String, dynamic>> sidebarAgentRows = const [];
  List<Map<String, dynamic>> get sidebarAgents {
    final source = w.services.entityDirectory.authorAgents;
    if (!identical(source, sidebarAgentSource)) {
      sidebarAgentSource = source;
      sidebarAgentRows = [
        for (final row in source)
          if (row['deletedAt'] == null) row,
      ];
    }
    return sidebarAgentRows;
  }

  // The conversation page stays mounted (hidden) while another section is in
  // front. Handing the framework the very widget it last built for that page
  // lets it skip the hidden subtree, instead of rebuilding every cached row on
  // each navigation frame; the page's own listeners keep it current, and the
  // next visit builds a fresh widget. Authority changes drop the cache.
  Widget? conversationInstance;
  Widget shownConversation(Widget Function() build) =>
      conversationInstance = build();

  Widget hiddenConversation(Widget Function() build) =>
      conversationInstance ??= build();

  List<SidebarGroup> get sidebarGroups {
    final activity = <String, DateTime>{};
    for (final c in [...w.channels, ...w.dms]) {
      final stamp = w.messageDomain.ledger.latestCreatedAt(c.id);
      if (stamp != null) activity[c.id] = stamp;
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
      if (mounted && authority == workspaceAuthority(w)) {
        // ignore: raft_lints/avoid_imperative_notice_state -- Workspace error is a one-shot toast, consumed by syncWorkspaceError; set only while the workspace authority is unchanged.
        w.setError(userErrorText(e, where: 'open agent conversation'));
      }
    }
  }

  Widget mountedPeerAvatar(
    String name,
    bool agent,
    SenderAvatarProjection source, {
    RaftMountedAvatarContext avatarContext =
        RaftMountedAvatarContext.sidebarList,
    RaftAvatarPresence? presence,
  }) => RaftAvatar(
    name: name,
    kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
    mountedContext: avatarContext,
    presence: presence,
    content: RaftAvatarContent(
      name: name,
      kind: agent ? RaftAvatarContentKind.agent : RaftAvatarContentKind.human,
      uploadedUrl: source.uploadedUrl,
      gravatarUrl: source.gravatarUrl,
      pixelKey: source.pixelKey,
      fallback: RaftMountedAvatarFallback(
        avatarContext: avatarContext,
        identity: agent
            ? RaftMountedAvatarIdentity.agent
            : RaftMountedAvatarIdentity.human,
        gravatar: source.gravatarUrl != null,
      ),
    ),
  );

  /// [pinned] / [custom]: the Sidebar.tsx row options of those sections -
  /// Pinned rows wrap (`allowWrap`) and hide an agent's description, custom
  /// sections hide every DM description.
  RaftNavItem sidebarEntry(
    SidebarEntry entry, {
    bool pinned = false,
    bool custom = false,
    bool reorderable = false,
  }) {
    final agent = entry.agent;
    if (agent == null) {
      return channelItem(entry.channel!, pinned, custom, reorderable);
    }
    final source = projectSenderAvatar(
      origin: w.client.origin,
      senderId: '${agent['id']}',
      senderType: 'agent',
      agents: [agent],
      members: const [],
      requestSize: 16,
    );
    final description = '${agent['description'] ?? ''}';
    return RaftNavItem(
      key: ValueKey('sidebar-${entry.key}'),
      label: entry.label,
      conversationKind: RaftConversationNavKind.directMessage,
      leading: mountedPeerAvatar(
        entry.label,
        true,
        source,
        presence: agentRowPresence(agent),
      ),
      wrap: pinned,
      menuOpen: menuOpenRow == 'a:${agent['id']}',
      onContextMenu: (at) => openAgentMenu(at, agent, entry.channel),
      contextMenuOnLongPress: !reorderable,
      description: pinned || custom || description.isEmpty ? null : description,
      selected:
          w.section == 'chat' &&
          entry.channel != null &&
          w.channel?.id == entry.channel!.id,
      unread: w.conversationReads.unread[entry.channel?.id] ?? 0,
      hasDraft: (w.drafts[entry.channel?.id] ?? '').isNotEmpty,
      onTap: () => chooseSidebarAgent(entry),
    );
  }

  List<SidebarEntry> _shownEntries(SidebarGroup group) =>
      joinedChannelsOnly && group.id == 'system:channels'
      ? [
          for (final e in group.entries)
            if (e.channel?.joined ?? true) e,
        ]
      : group.entries;

  List<Widget> conversationSlivers() => [
    for (final group in sidebarGroups)
      if (group.custom) ...[
        if (group.entries.isNotEmpty || !presentation.value.hideEmptySections)
          SliverMainAxisGroup(
            key: ValueKey('sidebar-group-${group.id}'),
            slivers: [
              SliverToBoxAdapter(
                child: sectionLabel(group.label, group: group),
              ),
              if (sidebarDisclosure.collapsed[group.id] != true)
                sidebarCustomRows(group, w, (e, reorderable) =>
                    sidebarEntry(e, custom: true, reorderable: reorderable)),
              if (sidebarDisclosure.collapsed[group.id] != true &&
                  group.entries.isEmpty)
                SliverToBoxAdapter(
                  child: RaftSidebarSectionEmptyHint(tr('No conversations')),
                ),
            ],
          ),
      ] else
        sidebarGroupSliver(group),
  ];

  /// Source `hasUnmutedUnread`: a collapsed section header shows an attention
  /// dot when one of its rows has unread messages and is not Activity-muted.
  bool groupHasUnread(Iterable<SidebarEntry> entries) => entries.any((e) {
    final c = e.channel;
    return c != null && !c.flag('activityMuted') && (w.conversationReads.unread[c.id] ?? 0) > 0;
  });

  Widget? groupAttention(SidebarGroup group, Iterable<SidebarEntry> entries) =>
      sidebarDisclosure.collapsed[group.id] == true && groupHasUnread(entries)
      ? const RaftAttentionDot(key: ValueKey('sidebar-section-unread-dot'))
      : null;

  Widget sidebarGroupSliver(SidebarGroup group) {
    final entries = _shownEntries(group);
    return sidebarSystemGroupSliver(
      group: group,
      entries: entries,
      w: w,
      label: tr(group.label),
      kind: switch (group.id) {
        'system:pinned' => RaftChatSidebarGroupKind.pinned,
        'system:joint' => RaftChatSidebarGroupKind.joint,
        'system:dms' => RaftChatSidebarGroupKind.directMessages,
        _ => RaftChatSidebarGroupKind.channels,
      },
      expanded: sidebarDisclosure.collapsed[group.id] != true,
      hideEmpty: presentation.value.hideEmptySections,
      loading: w.loading,
      emptyLabel: switch (group.id) {
        'system:pinned' => tr('Drag channels or DMs here to pin'),
        'system:joint' => tr('No joint channels yet'),
        _ => '',
      },
      onExpandedChanged: (expanded) =>
          sidebarDisclosure.setExpanded(mobileAuthority, group.id, expanded),
      attention: groupAttention(group, entries),
      actions: sidebarGroupActions(group),
      onOpenMenu: (at) => openSectionMenu(at, group),
      row: (entry, reorderable) => sidebarEntry(
        entry,
        pinned: group.id == 'system:pinned',
        reorderable: reorderable,
      ),
    );
  }

  /// A DM's peer as the sidebar row and the DM header show it: the accepted
  /// agent directory row when present, else the DM record's own peer fields
  /// (present at the first frame).
  ({
    bool agent,
    String name,
    String description,
    Map<String, dynamic>? profile,
    SenderAvatarProjection avatar,
  })
  dmPeer(RaftChannel c, {double requestSize = 16}) {
    final agent = c.type == 'dm' && c.string('peerType') == 'agent';
    final profile = agent
        ? w.services.entityDirectory.agent(c.string('peerId')) ??
              sidebarAgents
                  .where((a) => a['id'] == c.string('peerId'))
                  .firstOrNull
        : null;
    final displayName = profile == null
        ? c.string('peerDisplayName')
        : '${profile['displayName'] ?? ''}';
    final peerName = profile == null
        ? c.string('peerName')
        : '${profile['name'] ?? ''}';
    final name = displayName.isNotEmpty
        ? displayName
        : peerName.isNotEmpty
        ? peerName
        : c.name;
    final description = profile == null
        ? c.string('peerDescription')
        : '${profile['description'] ?? ''}';
    final avatar = projectSenderAvatar(
      origin: w.client.origin,
      senderId: c.string('peerId'),
      senderType: agent ? 'agent' : 'user',
      agents: [
        if (agent)
          {
            ...?profile,
            'id': c.string('peerId'),
            'avatarUrl': profile?['avatarUrl'] ?? c.json['peerAvatarUrl'],
          },
      ],
      members: [
        if (!agent)
          {
            'userId': c.string('peerId'),
            'avatarUrl': c.json['peerAvatarUrl'],
            'gravatarHash': c.json['peerGravatarHash'],
          },
      ],
      requestSize: requestSize,
    );
    return (
      agent: agent,
      name: name,
      description: description,
      profile: profile,
      avatar: avatar,
    );
  }

  RaftNavItem channelItem(
    RaftChannel c, [
    bool pinned = false,
    bool custom = false,
    bool reorderable = false,
  ]) {
    final scope = mobileAuthority;
    final peer = dmPeer(c);
    final agent = peer.agent, name = peer.name;
    final description = custom || (pinned && agent) ? '' : peer.description;
    final source = peer.avatar;
    return RaftNavItem(
      key: ValueKey('sidebar-channel-${c.id}'),
      leading: c.type == 'dm'
          ? mountedPeerAvatar(
              name,
              agent,
              source,
              presence: agent && peer.profile != null
                  ? agentRowPresence(peer.profile!)
                  : null,
            )
          : null,
      wrap: pinned,
      menuOpen: menuOpenRow == 'c:${c.id}',
      onContextMenu: (at) => openChannelMenu(at, c),
      contextMenuOnLongPress: !reorderable,
      description: c.type == 'dm' && description.isNotEmpty
          ? description
          : null,
      label: c.type == 'dm' ? name : c.name,
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
      selected: w.section == 'chat' && w.channel?.id == c.id,
      unread: w.conversationReads.unread[c.id] ?? 0,
      joined: c.joined,
      activityMuted: c.flag('activityMuted'),
      hasDraft: (w.drafts[c.id] ?? '').isNotEmpty,
      mention:
          c.type != 'dm' &&
          w.conversationReads.mentions.contains(c.id) &&
          (w.conversationReads.unread[c.id] ?? 0) > 0,
      onTap: () => chooseChannel(c, expectedScope: scope),
    );
  }

  /// The live-activity strip above the mobile tab bar (Web 116 px clearance).
  bool get liveActivityVisible {
    final latest = liveActivities.latest;
    return presentation.value.liveActivity &&
        latest != null &&
        liveActivities.agent(latest.agentId) != null;
  }

  Widget sidebar({bool mobileHome = false}) {
    final edgeToEdgeHome =
        mobileHome &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final recipe = RaftSidebarRecipe(
      RaftTokens.of(context),
      viewportWidth: MediaQuery.sizeOf(context).width,
      viewportHeight: MediaQuery.sizeOf(context).height,
      variant: RaftSidebarVariant.mountedProduct,
    );
    return ColoredBox(
      key: PageStorageKey(
        mobileHome ? 'mobile-home-list' : 'channel-sidebar-list',
      ),
      color: recipe.bodyBackground,
      child: SafeArea(
        // The list paints behind the floating bar through the gesture area.
        // Reserve that space in scroll padding, rather than clipping its viewport.
        bottom: !edgeToEdgeHome,
        child: Column(
          children: [
            if (mobileHome)
              WorkspaceMobileHomeHeader(
                controller: w,
                onServer: showWorkspaceSwitcher,
                onBilling: () => select('billing'),
                serverSwitcher: workspaceServerMenu(mobile: true),
              )
            else
              RaftChatSidebarHeading(
                label: tr('Chat'),
              ),
            Expanded(
              child: GestureDetector(
                // Sidebar.tsx `sidebar-scroll-surface onContextMenu`: rows,
                // sections and the Saved entry claim their own gestures first.
                behavior: HitTestBehavior.translucent,
                // Web `contextmenu`: right click (also in a phone viewport) and
                // the touch browsers' long press.
                onSecondaryTapDown: (d) => openSurfaceMenu(d.globalPosition),
                onLongPressStart: (d) => openSurfaceMenu(d.globalPosition),
                child: RaftPullToRefresh(
                  enabled: mobileHome || RaftInteraction.of(context).touch,
                  onRefresh: () => Future.wait([
                    w.refreshChannels(),
                    w.refreshUnread(),
                    w.loadSidebar(),
                  ]),
                  child: CustomScrollView(
                    key: const Key('workspace-sidebar'),
                    physics: mobileHome
                        ? const AlwaysScrollableScrollPhysics()
                        : null,
                    slivers: [
                      SliverPadding(
                        padding: recipe.contentInset(
                          headerInFlow: true,
                          liveActivity: mobileHome && liveActivityVisible,
                          bottomBar: !railNavigation,
                          bottomInset: edgeToEdgeHome
                              ? raftSystemBottomInset(context)
                              : 0,
                        ),
                        sliver: SliverMainAxisGroup(
                          slivers: [
                            if (mobileHome)
                              SliverToBoxAdapter(
                                child: RaftNavItem(
                                  key: const Key('nav-search'),
                                  role: RaftNavItemRole.search,
                                  viewportHeight: MediaQuery.sizeOf(
                                    context,
                                  ).height,
                                  label: tr('Search'),
                                  glyph: RaftGlyph.search,
                                  selected: w.section == 'search',
                                  onTap: () => select('search'),
                                ),
                              ),
                            // Activity is a bottom-bar tab: no second entry here.
                            if (mobileHome &&
                                !mobileTabIds.contains(MobileTabs.activity))
                              SliverToBoxAdapter(
                                child: RaftNavItem(
                                  key: const Key('nav-activity'),
                                  role: RaftNavItemRole.activity,
                                  viewportHeight: MediaQuery.sizeOf(
                                    context,
                                  ).height,
                                  label: tr('Activity'),
                                  glyph: RaftGlyph.activity,
                                  selected: w.section == 'activity',
                                  // Sidebar.tsx: the server's own activityUnreadCount;
                                  // an absent value is unknown, never the
                                  // broader per-conversation sum. The open
                                  // server follows its accepted Activity
                                  // window (activityCountOf).
                                  unread:
                                      activityCountOf(w.server?.id ?? '') ?? 0,
                                  onTap: () => select('activity'),
                                ),
                              ),
                            SliverToBoxAdapter(
                              child: SavedSidebarEntry(
                                key: const Key('nav-saved'),
                                controller: w,
                                onTap: () => select('saved'),
                              ),
                            ),
                            ...conversationSlivers(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!mobileHome) liveActivityBar(),
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
      await w.updateSidebarOrder({key: mode});
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
    final header = RaftSidebarSectionHeader(
      key: id == null ? null : ValueKey('sidebar-section-$id'),
      disclosureKey: id == null ? null : ValueKey('sidebar-disclosure-$id'),
      label: label,
      expanded: id == null || sidebarDisclosure.collapsed[id] != true,
      count: group?.entries.length,
      attention: group == null || !group.custom
          ? null
          : groupAttention(group, group.entries),
      onExpandedChanged: id == null
          ? null
          : (expanded) =>
                sidebarDisclosure.setExpanded(mobileAuthority, id, expanded),
      actions: group == null ? const [] : sidebarGroupActions(group),
      onContextMenu: group == null ? null : (at) => openSectionMenu(at, group),
      contextMenuOnLongPress: group == null,
    );
    return sidebarDragSectionHeader(
      group: group,
      w: w,
      label: label,
      header: header,
      onOpenMenu: openSectionMenu,
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
        ? createJointChannel
        : null;
    return [
      if (sortable)
        RaftSidebarSectionAction(
          key: anchor,
          testKey: ValueKey('sidebar-sort-$id'),
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

  Future<void> channelSettings() async {
    // The route can rebuild after archive/delete refresh clears the current
    // selection. Its identity belongs to the channel that opened the sheet.
    final channel = w.channel;
    if (channel == null) return;
    if (!wide) {
      openChannelPage(RaftChannelPage.settings, channel);
      return;
    }
    await ChannelSettings.show(
      context,
      controller: w,
      channel: channel,
      dmName: channel.type == 'dm'
          ? dmPeer(channel, requestSize: 36).name
          : null,
    );
  }

  void openChannelPage(RaftChannelPage kind, RaftChannel channel) {
    if (!w.can('viewChannel', resource: channel)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    w.navigation.navigate(
      w.location.withQuery({'channelPage': '${kind.name}:${channel.id}'}),
    );
    w.notifyListeners();
  }

  Widget channelPageHost(Widget child, RaftLocation location) {
    final page = location.channelPage;
    final channel = page == null
        ? null
        : [
            ...w.channels,
            ...w.dms,
          ].where((channel) => channel.id == page.channelId).firstOrNull;
    final available =
        channel != null && w.can('viewChannel', resource: channel);
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: page != null,
          child: ExcludeFocus(
            excluding: page != null,
            child: TickerMode(enabled: page == null, child: child),
          ),
        ),
        if (page != null)
          // ds-allow: Native page Scaffold owns keyboard insets; raft_ui owns its content/header.
          Scaffold(
            body: RaftSystemBarSurface(
              statusBarFallback: RaftTokens.of(context).panel,
              child: SafeArea(
                bottom: false,
                child: !available
                    ? Column(
                        children: [
                          RaftPanelHeaderBar(
                            title: tr('Channel is no longer available'),
                            onBack: dismissPanel,
                            backTooltip: tr('Back'),
                          ),
                        ],
                      )
                    : page.kind == RaftChannelPage.settings
                    ? ChannelSettings(
                        key: ValueKey('channel-settings-${page.channelId}'),
                        controller: w,
                        channel: channel,
                        isPanel: true,
                        page: true,
                        dmName: channel.type == 'dm'
                            ? dmPeer(channel, requestSize: 36).name
                            : null,
                        onClose: dismissPanel,
                        onMembers: () =>
                            openChannelPage(RaftChannelPage.members, channel),
                      )
                    // Web mounts the members page `bare` in the phone's
                    // full-width OverflowSheet (drawer border-l-2 included).
                    : RaftOverflowBareSheet(
                        page: true,
                        child: ChannelMembers(
                          key: ValueKey('channel-members-${page.channelId}'),
                          controller: w,
                          channel: channel,
                          page: true,
                          startInAdd: location.query('channelPageAdd') == '1',
                          onClose: dismissPanel,
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> createChannel() => CreateChannelDialog.show(
    context,
    controller: w,
    onCreated: (channel) => chooseChannel(channel),
  );

  Future<void> createJointChannel() => CreateJointChannelDialog.show(
    context,
    controller: w,
    onCreated: (channel) => chooseChannel(channel),
  );

  Widget settings() {
    final host = mobileHost;
    if (host != null) {
      final pageRoute = context
          .findAncestorStateOfType<_MobileWorkspaceRouteState>();
      return MobileSettingsDirectPage(
        controller: host.w,
        presentation: host.presentation,
        buildPage: host.settings,
        active: () => pageRoute?.active ?? true,
      );
    }
    final scope = mobileAuthority;
    return workspaceSettingsSurface(
      cacheKey: this,
      controller: w,
      authority: lastAuthority,
      scope: scope,
      revision: mobileSettingsRevision,
      hostRevision: mobileHost?.mobileSettingsRevision ?? 0,
      appearance: widget.appearance,
      onAppearance: widget.onAppearance,
      notifications: widget.notifications,
      onLogout: widget.onLogout,
      presentation: presentation,
      mobileTabbar: mobileTabbar,
      railSide: railSideStore,
      providerEnabled: providerEnabled,
      bridgeEnabled: bridgeEnabled,
      labsEnabled: labsEnabled,
      wide: wide,
      allowed: () => mounted && scope == mobileAuthority,
      dismiss: dismissPanel,
    );
  }
}
