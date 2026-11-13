// Source: packages/web/src/features/settings/notifications/NotificationsTabContent.tsx,
// components/settings/notifications/NotificationSettingsSection.tsx,
// ThisDeviceCard.tsx, TestNotificationButton.tsx and
// features/settings/notifications/ServerNotificationsLink.tsx at
// v1.24.0-source.1 (1d689caf).
//
// Settings › Notifications (design §4.3): this device, pause and schedule,
// the content every device shows, and every server's level, then a link to
// this server's own (Settings › On {server} › Notifications). Raft Desktop
// (macOS / Linux / Windows) mirrors Web's desktop card: the system owns the
// switch, the test goes through the real server path. Phones keep the native
// permission card (no Web counterpart: Web describes a browser's Web Push).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/notification_settings_api.dart';
import '../data/notification_settings_store.dart';
import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import '../platform/battery_optimization.dart';
import '../platform/desktop_server_notifications.dart';
import '../platform/native_notifications.dart';
import 'notification_settings_cards.dart';
import 'windows_tray_settings.dart';

class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({
    super.key,
    required this.service,
    this.controller,
    this.battery,
    this.now = DateTime.now,
    this.timeZone,
    this.runDesktopTest,
  });
  final NativeNotificationService service;

  /// Android battery optimisation; the default reads the real device.
  final BatteryOptimization? battery;
  final WorkspaceController? controller;
  final DateTime Function() now;
  final Future<String?> Function()? timeZone;

  /// The desktop test notification (default: POST /notifications/test to this
  /// socket, then wait for this device's ack).
  final Future<TestNotificationOutcome> Function()? runDesktopTest;

  @override
  State<NotificationSettingsView> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettingsView>
    with WidgetsBindingObserver {
  WorkspaceController? get w => widget.controller;
  late BatteryOptimization battery = widget.battery ?? BatteryOptimization();
  NotificationSettingsStore? store;

  /// Android only: null until known, false while the app is battery optimised.
  bool? batteryExempt;
  int batteryTicket = 0;
  bool nativeBusy = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared by the next native action and on a service change.
  String? error;
  bool phoneTestPosted = false;
  bool testRunning = false;
  TestNotificationOutcome? testOutcome;

  bool get phone =>
      widget.service.platform == TargetPlatform.android ||
      widget.service.platform == TargetPlatform.iOS;

  bool get showBatteryNotice =>
      widget.service.platform == TargetPlatform.android &&
      batteryExempt == false;

  Future<void> refreshBattery() async {
    if (widget.service.platform != TargetPlatform.android) return;
    final request = ++batteryTicket;
    final exempt = await battery.exempt();
    if (mounted && request == batteryTicket && exempt != batteryExempt) {
      setState(() => batteryExempt = exempt);
    }
  }

  /// The person returns from the system screen: read the status again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refreshBattery());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refreshBattery());
    widget.service.addListener(serviceChanged);
    bindStore();
  }

  /// Fresh account settings each time the page opens (another device may
  /// have changed them).
  void bindStore() {
    final client = w?.client;
    final next = client == null || client.user == null
        ? null
        : NotificationSettingsStore.of(client);
    if (identical(next, store)) return;
    store = next;
    if (next != null) unawaited(next.loadAccount());
  }

  @override
  void didUpdateWidget(NotificationSettingsView old) {
    super.didUpdateWidget(old);
    if (old.battery != widget.battery) {
      battery = widget.battery ?? BatteryOptimization();
    }
    if (old.service != widget.service) {
      old.service.removeListener(serviceChanged);
      widget.service.addListener(serviceChanged);
      error = null;
      phoneTestPosted = false;
      batteryExempt = null;
      unawaited(refreshBattery());
    }
    bindStore();
  }

  @override
  void dispose() {
    ++batteryTicket;
    WidgetsBinding.instance.removeObserver(this);
    widget.service.removeListener(serviceChanged);
    super.dispose();
  }

  void serviceChanged() {
    if (mounted) setState(() {});
  }

  /// A system-notification action (permission request, settings, local
  /// test); the button is disabled while it runs.
  Future<void> nativeAction(Future<void> Function() action) async {
    if (nativeBusy) return;
    setState(() {
      nativeBusy = true;
      error = null;
      phoneTestPosted = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'System notifications are unavailable on this device.',
        );
      }
    } finally {
      if (mounted) setState(() => nativeBusy = false);
    }
  }

  /// Ask for the permission; once the system stops asking, take the person
  /// to the system notification settings instead.
  Future<void> enable() async {
    final service = widget.service;
    await service.requestEnable(true);
    if (!service.enabled &&
        !service.permitted &&
        service.permissionPromptSkipped &&
        service.canOpenSettings) {
      await service.openSettings();
    }
  }

  Future<void> sendPhoneTest() async {
    final posted = await widget.service.test(
      title: raftText(context, 'Raft test notification'),
      body: raftText(
        context,
        'If you can read this, notifications reach this device.',
      ),
    );
    if (!mounted) return;
    setState(() {
      phoneTestPosted = posted;
      error = posted ? null : 'Could not post a test notification.';
    });
  }

  Future<void> sendDesktopTest() async {
    setState(() {
      testRunning = true;
      testOutcome = null;
    });
    TestNotificationOutcome outcome;
    try {
      final run = widget.runDesktopTest;
      final client = w?.client;
      outcome = run != null
          ? await run()
          : client == null
          ? (state: TestNotificationState.failed, reason: 'no_socket')
          : await NotificationSettingsApi(client).runDesktopTest(
              isUnconfirmed: DesktopServerNotifications.isUnconfirmedTest,
            );
    } catch (_) {
      outcome = (state: TestNotificationState.failed, reason: 'error');
    }
    if (!mounted) return;
    setState(() {
      testRunning = false;
      testOutcome = outcome;
    });
  }

  String phoneHint(TargetPlatform platform) => platform == TargetPlatform.iOS
      ? 'Whether notifications appear is decided by the system: on iOS, Settings → Notifications → Raft. With Do Not Disturb or a Focus mode on, the system may delay or silence notifications.'
      : 'Whether notifications appear is decided by the system: on Android, Settings → Apps → Raft → Notifications. With Do Not Disturb or a Focus mode on, the system may delay or silence notifications.';

  String desktopHint(BuildContext context, TargetPlatform platform) {
    if (platform != TargetPlatform.macOS) {
      return 'Whether these notifications appear is decided by the system: Settings → System → Notifications on Windows, or your desktop’s notification settings on Linux. Do Not Disturb may hold banners back.';
    }
    return raftFormat(
      context,
      'Whether these notifications appear is decided by the system, not by Raft: {path}. A Focus mode or Do Not Disturb may delay or silence banners.',
      {
        'path': raftFormat(
          context,
          'macOS → System Settings → Notifications → {app}',
          {'app': 'Raft'},
        ),
      },
    );
  }

  Widget testBanner(BuildContext context) {
    final outcome = testOutcome!;
    final (result, message) = switch (outcome.state) {
      TestNotificationState.shown => (
        RaftTestNotificationResult.shown,
        raftText(context, 'Test notification shown on this device.'),
      ),
      TestNotificationState.notShown => (
        RaftTestNotificationResult.notShown,
        raftText(
          context,
          'The test was sent, but the system didn’t show it. Allow notifications for Raft in the system’s notification settings, and check that Do Not Disturb or Focus is off.',
        ),
      ),
      TestNotificationState.unconfirmed => (
        RaftTestNotificationResult.unconfirmed,
        raftText(
          context,
          'Sent. This version of Raft Desktop couldn’t confirm it appeared.',
        ),
      ),
      TestNotificationState.failed => (
        RaftTestNotificationResult.failed,
        raftFormat(context, 'Couldn’t send the test notification ({reason}).', {
          'reason': outcome.reason ?? 'error',
        }),
      ),
    };
    return RaftTestNotificationBanner(result: result, message: message);
  }

  Widget desktopCard(BuildContext context) {
    final service = widget.service;
    final platform = service.platform;
    final available = !service.initialized || service.available;
    return RaftSettingsRowGroup(
      key: const ValueKey('desktop-notifications-card'),
      rows: [
        RaftSettingsRowSpec(
          title: 'Desktop notifications',
          titleTrailing: RaftBadge(
            label: raftText(
              context,
              available ? 'Managed by the system' : 'Unavailable',
            ),
            appearance: RaftBadgeRecipeAppearance.soft,
            variant: available
                ? RaftBadgeRecipeVariant.default_
                : RaftBadgeRecipeVariant.muted,
          ),
          body: [
            RaftListRowDescription(
              key: const ValueKey('desktop-notifications-system-hint'),
              available
                  ? desktopHint(context, platform)
                  : 'This desktop build cannot show system notifications.',
              wrap: true,
            ),
            if (error != null)
              RaftBanner(
                status: RaftBannerRecipeStatus.warning,
                size: RaftBannerRecipeSize.sm,
                description: error!,
              ),
            if (service.canOpenSettings)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: RaftButton(
                  key: const ValueKey(
                    'desktop-open-system-notification-settings',
                  ),
                  label: 'Open System Settings',
                  tone: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.md,
                  onPressed: nativeBusy
                      ? null
                      : () => nativeAction(service.openSettings),
                ),
              ),
            if (testOutcome != null) testBanner(context),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: RaftButton(
                key: const ValueKey('send-test-notification'),
                label: testRunning
                    ? 'Waiting for this device…'
                    : 'Send test notification',
                tone: RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.md,
                onPressed: !available || testRunning
                    ? null
                    : () => unawaited(sendDesktopTest()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget phoneCard(BuildContext context) {
    final service = widget.service;
    final platform = service.platform;
    final unavailable = service.initialized && !service.available;
    final status = unavailable
        ? 'Unavailable'
        : service.enabled
        ? 'Enabled'
        : service.initialized && !service.permitted
        ? 'Off in system settings'
        : 'Not enabled';
    final problem = error ?? service.backgroundError ?? service.error;
    return RaftSettingsRowGroup(
      key: const ValueKey('phone-notifications-card'),
      rows: [
        RaftSettingsRowSpec(
          title: 'Phone notifications',
          titleTrailing: RaftBadge(
            key: const ValueKey('phone-notifications-status'),
            // The phone card's own zh wording for "Enabled" (已开启).
            label: status == 'Enabled'
                ? raftTextZh(context, status, '已开启')
                : raftText(context, status),
            appearance: RaftBadgeRecipeAppearance.soft,
            variant: service.enabled
                ? RaftBadgeRecipeVariant.success
                : status == 'Off in system settings'
                ? RaftBadgeRecipeVariant.warning
                : RaftBadgeRecipeVariant.muted,
          ),
          body: [
            RaftListRowDescription(
              unavailable
                  ? 'System notifications are unavailable on this device.'
                  : phoneHint(platform),
              wrap: true,
            ),
            if (showBatteryNotice)
              RaftBanner(
                key: const ValueKey('battery-optimization-notice'),
                status: RaftBannerRecipeStatus.warning,
                size: RaftBannerRecipeSize.sm,
                description: 'To receive notifications in the background, turn off battery optimization for Raft.',
                actions: [
                  RaftButton(
                    label: 'Open Battery Settings',
                    tone: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: () => unawaited(battery.openSettings()),
                  ),
                ],
              ),
            if (problem != null)
              RaftBanner(
                status: RaftBannerRecipeStatus.warning,
                size: RaftBannerRecipeSize.sm,
                description: problem,
              ),
            if (phoneTestPosted)
              RaftBanner(
                key: const ValueKey('test-notification-posted'),
                status: RaftBannerRecipeStatus.info,
                size: RaftBannerRecipeSize.sm,
                description: "Test notification sent. If no banner appeared, check Raft's notification settings in the system settings, then try again.",
              ),
            Wrap(
              spacing: RaftSpace.x2,
              runSpacing: RaftSpace.x2,
              children: [
                if (service.enabled)
                  RaftButton(
                    key: const ValueKey('send-test-notification'),
                    label: 'Send test notification',
                    tone: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.md,
                    onPressed: nativeBusy || unavailable
                        ? null
                        : () => nativeAction(sendPhoneTest),
                  )
                else
                  RaftButton(
                    key: const ValueKey('phone-notifications-enable'),
                    label: 'Enable Notifications',
                    tone: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.md,
                    onPressed: nativeBusy || unavailable
                        ? null
                        : () => nativeAction(enable),
                  ),
                if (service.initialized && !service.permitted)
                  RaftButton(
                    key: const ValueKey('phone-notifications-open-settings'),
                    label: 'Open Notification Settings',
                    tone: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.md,
                    onPressed: nativeBusy || unavailable
                        ? null
                        : () => nativeAction(service.openSettings),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = this.store;
    final controller = w;
    return RaftGapColumn(
      key: const ValueKey('notification-settings-section'),
      gap: RaftSpace.x6,
      children: [
        Column(
          key: const ValueKey('push-notifications'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RaftSettingsSectionHeader(
              label: 'This device',
              glyph: RaftGlyph.bell,
            ),
            phone ? phoneCard(context) : desktopCard(context),
          ],
        ),
        if (!phone && widget.service.platform == TargetPlatform.windows)
          const WindowsTraySettings(),
        if (store != null && controller != null) ...[
          PauseScheduleCard(
            store: store,
            now: widget.now,
            timeZone: widget.timeZone,
          ),
          NotificationContentCard(store: store),
          NotificationServersCard(controller: controller, store: store),
          if (controller.server != null)
            ServerNotificationsLink(controller: controller, store: store),
        ],
      ],
    );
  }
}

/// The personal Notifications page's way to this server's own.
class ServerNotificationsLink extends StatelessWidget {
  const ServerNotificationsLink({
    super.key,
    required this.controller,
    required this.store,
  });
  final WorkspaceController controller;
  final NotificationSettingsStore store;

  void open() {
    controller.navigation.navigate(
      RaftLocation.at(
        serverSlug: controller.location.serverSlug,
        route: RaftRoute.settings,
        settingsPath: ['server-notifications'],
      ),
    );
    controller.notifyListeners();
  }

  @override
  Widget build(BuildContext context) => NotificationStoreBuilder(
    store: store,
    builder: (context) {
      final server = controller.server!;
      final level = store.serverLevel(server.id, row: server);
      return RaftListRowGroup(
        children: [
          RaftListRow(
            key: const ValueKey('settings-server-notifications-link'),
            variant: RaftListRowVariant.plain,
            onPressed: open,
            children: [
              RaftListRowBody(
                children: [
                  RaftListRowTitle(
                    raftFormat(context, 'Notifications on {serverName}', {
                      'serverName': server.name,
                    }),
                  ),
                ],
              ),
              RaftListRowValue(raftText(context, level.label)),
              const RaftListRowChevron(),
            ],
          ),
        ],
      );
    },
  );
}

/// Settings › On {server} › Notifications: this server's level and its
/// customized channels (Web `CurrentServerNotificationsCard`).
class ServerNotificationSettingsView extends StatefulWidget {
  const ServerNotificationSettingsView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<ServerNotificationSettingsView> createState() =>
      _ServerNotificationSettingsViewState();
}

class _ServerNotificationSettingsViewState
    extends State<ServerNotificationSettingsView> {
  @override
  void initState() {
    super.initState();
    final id = widget.controller.server?.id;
    if (id != null) {
      unawaited(
        NotificationSettingsStore.of(widget.controller.client)
            .loadServerLevels(id),
      );
    }
  }

  @override
  Widget build(BuildContext context) => NotificationServersCard(
    controller: widget.controller,
    store: NotificationSettingsStore.of(widget.controller.client),
    only: true,
  );
}
