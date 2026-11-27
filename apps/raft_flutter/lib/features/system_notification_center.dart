import 'page_layout.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart'
    show LiveEvent, ListChangedEvent, ServerFeaturesChangedEvent;
import 'package:raft_ui/raft_ui.dart';

import '../data/feature_flag_client_facts.dart';
import '../data/freshness.dart';
import '../data/raft_location.dart';
import '../data/second_factor_recovery_notice.dart';
import '../data/system_notification_projection.dart';
import '../data/system_notification_store.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import '../data/workspace_navigation.dart';
import 'account_security_recovery.dart';
import 'app_permission_updates.dart';
import 'joint_invite_errors.dart';
import 'source_feedback_view.dart';
import 'workspace_web_billing.dart' show openWebBillingOrToast;
import 'system_notification_copy.dart';
import 'settings_link.dart';

/// The mounted Web system-notification aggregator, separate from message Activity
/// and operating-system notifications. All data and overlay actions are scoped.
class SystemNotificationBell extends StatefulWidget {
  const SystemNotificationBell({
    super.key,
    required this.controller,
    required this.onBilling,
    this.onFeedback,
    this.mobile = true,
    this.topBar = false,
    this.store,
  });
  final WorkspaceController controller;
  final VoidCallback onBilling;

  /// Web `nav.toSettings("feedback")`: the workspace opens the Feedback tab of
  /// Settings. Without it the notice shows the feedback view in a pushed page.
  final VoidCallback? onFeedback;
  final bool mobile;
  final bool topBar;
  final SystemNotificationStore? store;
  @override
  State<SystemNotificationBell> createState() => _SystemNotificationBellState();
}

class _SystemNotificationBellState extends State<SystemNotificationBell>
    with WidgetsBindingObserver {
  WorkspaceController get w => widget.controller;
  late SystemNotificationStore store;
  late AppPermissionUpdates appPermissionUpdates;
  VoidCallback? releaseAppPermissionUpdates;
  StreamSubscription<RaftEvent>? events;

  /// Machines and agents the notices project from. Agent presence patches
  /// (activity, last seen) do not change them.
  WorkspaceEntitySelection? entities;
  Timer? coalesce, closeDelay, jointInvitesPing, seatJoinPing;
  RaftForegroundPeriodic? poll, seatPoll;
  final resumeRefresh = Freshness(const Duration(seconds: 20));
  OverlayEntry? popup;
  bool popupKeyboard = false;
  bool keyboardInput = false;
  FocusNode? previousFocus;
  final anchor = GlobalKey();
  final focus = FocusNode();
  bool disposed = false;

  /// Server-level identity only (Source NotificationCenter is server-scoped):
  /// joining/creating channels or capability refreshes keep the machines,
  /// agents, feedback count and dismissals. Channels re-project in place.
  String get authority => jsonEncode([
    identityHashCode(w),
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.client.serverId,
    w.server?.id,
    w.server?.string('role'),
    w.can('viewMachines'),
    w.can('viewAgents'),
    w.can('viewBilling'),
    w.can('manageIntegrations'),
  ]);
  bool current(String scope) =>
      !disposed && mounted && authority == scope && w.client.user != null;

  @override
  void initState() {
    super.initState();
    attach();
  }

  void attach() {
    store =
        widget.store ??
        SystemNotificationStore(
          get: w.query,
          entities: directoryEntities,
          post: (path) => w.command('POST', path),
          seatAddEnabled: seatAddEnabled,
        );
    unawaited(bind());
    appPermissionUpdates = AppPermissionUpdates.of(w);
    releaseAppPermissionUpdates = widget.store == null
        ? appPermissionUpdates.retain()
        : null;
    appPermissionUpdates.addListener(appPermissionsChanged);
    appPermissionsChanged();
    store.addListener(updated);
    w.addListener(changed);
    entities = WorkspaceEntitySelection(
      w.services.entityDirectory,
      (d) => (
        d.authorRevision,
        d.computerRevision,
        d.state(WorkspaceEntityKind.computers).loaded,
        d.state(WorkspaceEntityKind.agents).loaded,
      ),
    )..addListener(changed);
    events = w.client.events.listen((e) {
      // Accepted workspace/directory facts above own projection updates.
      // Raw chat events carry no notification-center fact and must not rebind
      // the bell a second time after the workspace already accepted them.
      // agent:*/machine:* revalidate the shared directory in place; only a
      // directory-less store reads them itself.
      if ((store.entities == null &&
              (e.name.startsWith('machine:') || e.name.startsWith('agent:'))) ||
          e.name.startsWith('server:member')) {
        coalesce?.cancel();
        coalesce = Timer(const Duration(milliseconds: 150), store.refresh);
      }
      // Web v1.24 listChangedSocket: `joint-invites:changed` re-reads the
      // pending joint invites (pings within 100 ms read once). Pings lost
      // while away are covered by the resume read and the 60 s poll above.
      final payload = e.payload;
      final ping = LiveEvent.read(e.name, payload);
      if (ping is ListChangedEvent &&
          ping.event == ListChangedEvent.jointInvites &&
          ping.serverId == w.client.serverId) {
        jointInvitesPing?.cancel();
        jointInvitesPing = Timer(
          const Duration(milliseconds: 100),
          () => unawaited(store.refreshJointInvites()),
        );
      }
      // Web useSeatJoinBlocks: the seat-join-blocks:changed ping, a change of
      // the pro_seat_add flag (which also asks the flag again) and a
      // reconnect read the list again.
      final flagChanged =
          ping is ServerFeaturesChangedEvent &&
          ping.serverId == w.client.serverId &&
          ping.keys.contains(RaftFeatureFlags.proSeatAdd);
      if ((ping is ListChangedEvent &&
              ping.event == ListChangedEvent.seatJoinBlocks &&
              ping.serverId == w.client.serverId) ||
          flagChanged ||
          e.name == 'connected') {
        seatJoinPing?.cancel();
        seatJoinPing = Timer(
          const Duration(milliseconds: 100),
          () => unawaited(
            store.refreshSeatJoinBlocks(
              reevaluate: flagChanged || e.name == 'connected',
            ),
          ),
        );
      }
    });
    // Stops while hidden/paused; resume refreshes (didChangeAppLifecycleState).
    poll = RaftForegroundPeriodic(const Duration(seconds: 60), () {
      unawaited(store.refresh());
      unawaited(store.refreshUsageLimit());
      unawaited(store.refreshJointInvites());
    });
    // The 5-minute safety poll of the seat-join list (an agent taking or
    // freeing a seat); stops while hidden.
    seatPoll = RaftForegroundPeriodic(const Duration(minutes: 5), () {
      unawaited(store.refreshSeatJoinBlocks());
    });
    WidgetsBinding.instance.addObserver(this);
  }

  /// `pro_seat_add` of [serverId] (`POST /feature-flags/evaluate`); null when
  /// the answer could not be read, so the last one stays.
  Future<bool?> seatAddEnabled(String serverId) async {
    try {
      final value = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: const [RaftFeatureFlags.proSeatAdd],
          serverId: serverId,
        ),
      );
      final rows = value is Map ? value['evaluations'] : null;
      if (rows is! List) return null;
      for (final row in rows) {
        if (row is Map && row['key'] == RaftFeatureFlags.proSeatAdd) {
          final enabled = row['enabled'];
          return enabled is bool ? enabled : null;
        }
      }
    } on RaftApiException catch (error) {
      // Unknown is not permission: only a denial turns the flag off.
      if (error.status == 401 || error.status == 403) return false;
    } catch (_) {}
    return null;
  }

  Future<void> bind() => store.bind(
    SystemNotificationContext(
      scope: authority,
      origin: w.client.origin,
      principal: w.client.user?.id ?? '',
      server: w.client.user == null ? null : w.server?.json,
      channels: [for (final c in w.channels) Map.of(c.json)],
      canViewMachines: w.can('viewMachines'),
      canViewAgents: w.can('viewAgents'),
      mobile: widget.mobile,
      managesMachines: const [
        'editMachines',
        'controlComputers',
        'removeMachines',
        'rotateMachineKeys',
        'createAgents',
        'migrateAgents',
      ].any(w.can),
    ),
  );

  /// Machines and agents from the workspace's shared entity directory, which
  /// is itself fenced by server-level identity.
  SystemNotificationEntities directoryEntities() {
    final directory = w.services.entityDirectory;
    final machinesAllowed = w.can('viewMachines'),
        agentsAllowed = machinesAllowed && w.can('viewAgents');
    for (final (kind, allowed) in [
      (WorkspaceEntityKind.computers, machinesAllowed),
      (WorkspaceEntityKind.agents, agentsAllowed),
    ]) {
      final state = directory.state(kind);
      if (allowed && !state.loaded && !state.loading && state.error == null) {
        // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot deferral out of a build or notification; the callback does not schedule another microtask itself.
        scheduleMicrotask(() {
          if (!disposed) unawaited(directory.refresh(kind));
        });
      }
    }
    return SystemNotificationEntities(
      machines: machinesAllowed
          ? directory.rows(WorkspaceEntityKind.computers)
          : const [],
      agents: agentsAllowed ? directory.authorAgents : const [],
      ready:
          (!machinesAllowed ||
              directory.state(WorkspaceEntityKind.computers).loaded) &&
          (!agentsAllowed ||
              directory.state(WorkspaceEntityKind.agents).loaded),
    );
  }

  void changed() {
    final old = store.context?.scope;
    final next = authority;
    if (old != next) close(remove: true);
    unawaited(bind());
    if (old != next) {
      appPermissionsChanged();
    }
  }

  void appPermissionsChanged() =>
      store.setAppPermissionUpdates(appPermissionUpdates.summary.count);

  void updated() {
    if (!disposed && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(SystemNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.store != widget.store) {
      close(remove: true);
      detach(oldWidget);
      attach();
    } else if (oldWidget.mobile != widget.mobile) {
      close(remove: true);
      unawaited(bind());
      unawaited(store.refresh());
      unawaited(store.refreshUsageLimit());
    }
  }

  void detach(SystemNotificationBell owner) {
    owner.controller.removeListener(changed);
    entities?.dispose();
    entities = null;
    store.removeListener(updated);
    appPermissionUpdates.removeListener(appPermissionsChanged);
    releaseAppPermissionUpdates?.call();
    events?.cancel();
    poll?.dispose();
    seatPoll?.dispose();
    coalesce?.cancel();
    closeDelay?.cancel();
    jointInvitesPing?.cancel();
    seatJoinPing?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (owner.store == null) store.dispose();
  }

  @override
  void didChangeMetrics() {
    // The old anchor rectangle cannot be used after an OS rotation/IME resize.
    close(remove: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      changed();
      // Alt-tab many times a minute reads the machines and agents once.
      // Web also refreshes the pending joint invites on window focus; here they
      // share the same once-per-window budget, so alt-tabbing does not repeat
      // the read (the 60 s poll still picks up new invites).
      if (resumeRefresh.due()) {
        unawaited(store.refresh());
        unawaited(store.refreshUsageLimit());
        unawaited(store.refreshSeatJoinBlocks());
        unawaited(store.refreshJointInvites());
        unawaited(store.refreshSecondFactorRecovery());
      }
    }
  }

  void close({bool remove = false}) {
    final entry = popup;
    if (entry == null) return;
    popup = null;
    closeDelay?.cancel();
    HardwareKeyboard.instance.removeHandler(popupKey);
    entry.remove();
    entry.dispose();
    if (!disposed && mounted) {
      setState(() {});
      if (popupKeyboard && !remove) {
        final previous = previousFocus;
        if (previous?.context != null) {
          previous!.requestFocus();
        } else {
          focus.requestFocus();
        }
      }
    }
    popupKeyboard = false;
    previousFocus = null;
  }

  bool popupKey(KeyEvent event) {
    if (popup != null &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      close();
      return true;
    }
    return false;
  }

  Future<void> show({bool keyboard = false}) async {
    closeDelay?.cancel();
    if (popup != null || w.server == null || w.client.user == null) return;
    final captured = authority;
    final box = anchor.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) return;
    final anchorRect =
        box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
    // The trigger can live below SafeArea/Scaffold, which consume insets.
    // This popup paints in the root overlay and needs that window's metrics.
    final metrics = MediaQuery.of(overlay.context);
    final size = overlayBox.size;
    final safe = metrics.padding;
    final bottom = math.max(safe.bottom, metrics.viewInsets.bottom);
    final width = RaftNotificationCenter.popupWidth(
      size.width - safe.horizontal,
      mobile: widget.mobile,
    );
    final height = math.min(
      288.0,
      math.max(0.0, size.height - safe.top - bottom - 16),
    );
    final minLeft = safe.left + 8;
    final maxLeft = math.max(minLeft, size.width - safe.right - width - 8);
    final minTop = safe.top + 8;
    final maxTop = math.max(minTop, size.height - bottom - height - 8);
    // A rail on the window's right opens toward the content (to its left).
    final railOnRight = !widget.mobile && RaftRailEdgeScope.onRightOf(context);
    final left = widget.mobile || widget.topBar
        ? (anchorRect.right - width).clamp(minLeft, maxLeft)
        : railOnRight
        ? (anchorRect.left - 8 - width).clamp(minLeft, maxLeft)
        : (anchorRect.right + 8).clamp(minLeft, maxLeft);
    final top = widget.mobile || widget.topBar
        ? (anchorRect.bottom + 8).clamp(minTop, maxTop)
        : (anchorRect.bottom - height).clamp(minTop, maxTop);
    final themes = InheritedTheme.capture(from: context, to: overlay.context);
    final entry = OverlayEntry(
      builder: (_) => themes.wrap(
        RaftBackDismiss(
          // OverlayEntry is above the routes. Register with the opener's
          // route so the workspace consumes Back before its business history.
          routeContext: context,
          onDismiss: close,
          child: Stack(
            children: [
              Positioned(
                left: left.toDouble(),
                top: top.toDouble(),
                width: width,
                height: height,
                child: TapRegion(
                  groupId: this,
                  onTapOutside: (_) => close(),
                  child: RaftHoverRegion(
                    onEnter: (_) => closeDelay?.cancel(),
                    onExit: (_) {
                      if (!widget.mobile && !widget.topBar) {
                        closeDelay = Timer(
                          const Duration(milliseconds: 120),
                          close,
                        );
                      }
                    },
                    child: ListenableBuilder(
                      listenable: store,
                      builder: (context, _) => !current(captured)
                          ? const SizedBox.shrink()
                          : RaftNotificationCenter(
                              key: const Key('system-notification-center'),
                              width: width,
                              height: height,
                              autofocus: keyboard,
                              countLabel: store.entries.isEmpty
                                  ? raftText(context, 'all clear')
                                  : raftFormat(
                                      context,
                                      store.entries.length == 1
                                          ? '{count} item'
                                          : '{count} items',
                                      {'count': store.entries.length},
                                    ),
                              entries: [
                                for (final entry in store.entries)
                                  display(entry, captured),
                              ],
                              onDismiss: close,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    popup = entry;
    // Opening the center is what marks server-backed entries seen.
    unawaited(store.markUsageLimitsSeen(captured));
    HardwareKeyboard.instance.addHandler(popupKey);
    popupKeyboard = keyboard;
    previousFocus = keyboard ? FocusManager.instance.primaryFocus : null;
    overlay.insert(entry);
    setState(() {});
  }

  bool live(SystemNotice notice, String scope) =>
      current(scope) &&
      store.entries.any(
        (n) => n.id == notice.id && n.fingerprint == notice.fingerprint,
      );

  RaftNotificationEntry display(SystemNotice n, String scope) {
    if (n.id == secondFactorRecoveryNoticeId) {
      return secondFactorRecoveryEntry(context, w.client, n, store, scope);
    }
    final copy = systemNotificationCopy(context, n);
    final managesBilling = w.can('manageBilling');
    return RaftNotificationEntry(
      id: n.id,
      kind: switch (n.kind) {
        SystemNoticeKind.error => RaftNotificationKind.error,
        SystemNoticeKind.warning => RaftNotificationKind.warning,
        SystemNoticeKind.info => RaftNotificationKind.info,
      },
      iconForeground: n.id == 'feedback-replies'
          ? null
          : RaftTokens.of(context).colors['foreground-strong'],
      title: copy.title,
      body: copy.bodyContent == null ? copy.body : null,
      bodyContent: copy.bodyContent,
      glyph: switch (n.id) {
        'computer-attention' => RaftGlyph.monitor,
        'machine-offline' => RaftGlyph.wifiOff,
        'machine-disk-low' => RaftGlyph.hardDrive,
        'feedback-replies' => RaftGlyph.messageSquare,
        _ when n.destination == SystemNoticeDestination.jointInvite =>
          RaftGlyph.gitBranch,
        _ => RaftGlyph.triangleAlert,
      },
      actions: [
        if (n.destination == SystemNoticeDestination.seatJoin)
          RaftNotificationAction(
            // Web: an owner adds the seat, anyone else asks an owner for it.
            // Both happen on the Web's Plan & Billing page.
            label: raftText(
              context,
              managesBilling ? 'Add seats' : 'Ask an owner',
            ),
            onPressed: () {
              if (!live(n, scope)) return;
              final host = context;
              close();
              unawaited(openWebBillingOrToast(host, w));
            },
          )
        else if (n.destination == SystemNoticeDestination.jointInvite)
          RaftNotificationAction(
            label: raftText(context, 'Accept'),
            enabled: acceptingJointInvite == null,
            onPressed: () => unawaited(acceptJointInvite(n, scope)),
          )
        else if (n.destination != SystemNoticeDestination.billing ||
            w.can('viewBilling'))
          RaftNotificationAction(
            label: raftText(
              context,
              n.destination == SystemNoticeDestination.billing
                  ? 'Upgrade'
                  : n.destination == SystemNoticeDestination.feedback
                  ? 'View Feedback'
                  : n.destination ==
                        SystemNoticeDestination.appPermissionUpdates
                  ? 'View updates'
                  : 'View',
            ),
            onPressed: () => navigate(n, scope),
          ),
        if (n.fingerprint != null)
          RaftNotificationAction(
            label: raftText(context, 'Dismiss'),
            onPressed: () {
              if (live(n, scope)) store.dismiss(scope, n.fingerprint!);
            },
          )
        else if (n.incidentId != null)
          RaftNotificationAction(
            label: raftText(context, 'Dismiss'),
            onPressed: () {
              if (live(n, scope)) {
                unawaited(store.dismissUsageLimit(scope, n.incidentId!));
              }
            },
          ),
      ],
    );
  }

  /// The invite being accepted: one at a time (Web `acceptingJointInviteId`).
  String? acceptingJointInvite;

  /// Same endpoint as the email link, so accept authority and the server's
  /// limit checks are identical on both paths. Success opens the channel; a
  /// failure is a toast with the limit codes' own copy.
  Future<void> acceptJointInvite(SystemNotice n, String captured) async {
    final id = n.targetId;
    if (id == null || acceptingJointInvite != null || !live(n, captured)) {
      return;
    }
    setState(() => acceptingJointInvite = id);
    try {
      final reply = await w.command(
        'POST',
        '/channels/joint-invites/${Uri.encodeComponent(id)}/accept',
      );
      if (current(captured) && reply is Map && reply['id'] is String) {
        close();
        await w.refreshChannels();
        if (current(captured)) {
          await w.selectChannel(RaftChannel(Map<String, dynamic>.from(reply)));
        }
      }
    } catch (e) {
      if (mounted) {
        showRaftToast(
          context,
          jointInviteAcceptErrorText(
            e,
            (source, values) => raftFormat(context, source, values),
          ),
          tone: RaftToastRecipeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => acceptingJointInvite = null);
      if (!disposed) unawaited(store.refreshJointInvites());
    }
  }

  Future<void> navigate(SystemNotice n, String captured) async {
    if (!live(n, captured)) return;
    if (n.destination == SystemNoticeDestination.appPermissionUpdates) {
      if (!w.can('manageIntegrations')) return;
      close();
      settingsLocationOpener(w, allowed: current(captured))(
        WorkspaceNavigation.locationForSection(
          w.location.serverSlug,
          'apps',
        ).withQuery({'permission_updates': '1'}),
      );
      return;
    }
    if (n.destination == SystemNoticeDestination.billing) {
      if (!w.can('viewBilling')) return;
      close();
      if (current(captured)) widget.onBilling();
      return;
    }
    if (n.destination == SystemNoticeDestination.feedback &&
        widget.onFeedback != null) {
      close();
      if (current(captured)) widget.onFeedback!();
      return;
    }
    if (n.destination != SystemNoticeDestination.feedback) {
      if (!w.can('viewMachines')) return;
      final computer = n.destination == SystemNoticeDestination.computer;
      final id = computer && store.machines.any((m) => m['id'] == n.targetId)
          ? n.targetId
          : null;
      // Server-backed entries name a Computer the directory may not hold yet
      // (or no longer): they open the list instead of doing nothing.
      if (computer && id == null && n.incidentId == null) return;
      close();
      if (!current(captured)) return;
      // Web nav.toComputer / nav.toComputers move the main area: the
      // Computer beside the rack on a wide window, its own page on a phone.
      w.navigation.navigate(
        RaftLocation.at(
          serverSlug: w.location.serverSlug,
          route: id != null ? RaftRoute.computer : RaftRoute.computers,
          entityId: id,
          query: {
            if (id == null && n.incidentId == null) 'filter': 'attention',
          },
        ),
      );
      w.closeThread(navigate: false);
      // perf-allow: the location is the workspace's own state; opening or closing a slot re-lays out the shell
      w.notifyListeners();
      return;
    }
    close();
    if (!current(captured)) return;
    // ignore: raft_lints/avoid_window_cover_route -- web-page: components/layout/useSystemNotifications.tsx:683 (Settings > Feedback; only a host without onFeedback, the phone bell)
    final route = MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: raftPageAppBar(context, title: raftText(context, 'Feedback')),
        body: SourceFeedbackView(
          controller: w,
          onUnreadChanged: (count) {
            if (current(captured)) store.reconcileFeedback(captured, count);
          },
        ),
      ),
    );
    void revoked() {
      if (!current(captured) && route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }

    w.addListener(revoked);
    try {
      await Navigator.of(context, rootNavigator: true).push(route);
    } finally {
      w.removeListener(revoked);
    }
    if (current(captured)) unawaited(store.refresh());
  }

  @override
  void dispose() {
    disposed = true;
    close(remove: true);
    detach(widget);
    focus.dispose();
    super.dispose();
  }

  double get statusEdge {
    final tokens = RaftTokens.of(context);
    if (widget.mobile) return (44 - 22) / 2;
    if (widget.topBar) {
      final frame = tokens.desktop
          ? RaftLayoutMetrics.desktopControl
          : tokens.size('css.frame-item-height', fallback: 36);
      return (frame - 20) / 2;
    }
    final rail = RaftRailRecipe(
      tokens,
      viewportHeight: MediaQuery.sizeOf(context).height,
    );
    return (40 - rail.glyphSize) / 2;
  }

  bool get securityAlert =>
      store.entries.any((n) => n.id == secondFactorRecoveryNoticeId);

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => keyboardInput = false,
    child: Focus(
      focusNode: focus,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          keyboardInput = true;
        }
        return KeyEventResult.ignored;
      },
      child: RaftHoverRegion(
        onEnter: (_) {
          if (!widget.mobile && !widget.topBar) unawaited(show());
        },
        onExit: (_) {
          if (!widget.mobile && !widget.topBar) {
            closeDelay = Timer(const Duration(milliseconds: 120), close);
          }
        },
        child: TapRegion(
          groupId: this,
          child: Stack(
            key: anchor,
            clipBehavior: Clip.none,
            children: [
              RaftMobileNotificationButton(
                open: popup != null,
                semanticLabel: securityAlert
                    ? raftFormat(
                        context,
                        'Notification center ({count} active), security alert',
                        {'count': store.unreadCount},
                      )
                    : store.unreadCount == 0
                    ? raftText(context, 'Notification Center')
                    : raftFormat(
                        context,
                        'Notification Center ({count} active)',
                        {'count': store.unreadCount},
                      ),
                visualSize: widget.mobile ? 32 : 40,
                glyphSize: 16,
                // NotificationTrigger: the rail bell is a rail icon with the
                // shared attention composite. The mobile header chooses its
                // frame treatment through theme data; SDK defaults stay 32/16.
                rail: !widget.mobile && !widget.topBar,
                onFrame: widget.topBar,
                mobileHeader: widget.mobile,
                attention:
                    !widget.mobile &&
                    !widget.topBar &&
                    !securityAlert &&
                    store.unreadCount > 0,
                onPressed: () => popup == null
                    ? show(
                        keyboard:
                            keyboardInput ||
                            HardwareKeyboard.instance.logicalKeysPressed
                                .contains(LogicalKeyboardKey.enter) ||
                            HardwareKeyboard.instance.logicalKeysPressed
                                .contains(LogicalKeyboardKey.space),
                      )
                    : close(),
              ),
              // Web NotificationTrigger: a security entry (the two-step
              // reset) wears a shield on a warning IconTile at the Bell's
              // corner instead of the unread dot.
              if (securityAlert)
                Positioned(
                  key: const ValueKey('notification-security-alert'),
                  right: statusEdge - 8,
                  top: statusEdge - 8,
                  child: const IgnorePointer(
                    child: RaftIconTile(
                      glyph: RaftGlyph.shieldAlert,
                      size: RaftIconTileSize.xs,
                      variant: RaftIconTileVariant.warning,
                    ),
                  ),
                )
              else if ((widget.mobile || widget.topBar) &&
                  store.unreadCount > 0)
                Positioned(
                  right: statusEdge - 4,
                  top: statusEdge - 4,
                  child: IgnorePointer(
                    child: RaftNotificationAttention(count: store.unreadCount),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
