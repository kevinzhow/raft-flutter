import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/battery_optimization.dart';
import '../platform/native_notifications.dart';
import 'management_support.dart';
import 'windows_tray_settings.dart';

/// Mounted NotificationsSection. Desktop (macOS / Linux / Windows) mirrors
/// Web's DesktopNativeNotificationsCard: the system owns the switch. macOS
/// and phones show the checked permission and link to system settings; Windows
/// and Linux retain their system-managed guidance. Phones add the member-owned server
/// mute form. Neither describes a browser permission or web-push subscription.
class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({
    super.key,
    required this.service,
    this.controller,
    this.battery,
  });
  final NativeNotificationService service;

  /// Android battery optimisation; the default reads the real device.
  final BatteryOptimization? battery;
  final WorkspaceController? controller;
  @override
  State<NotificationSettingsView> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettingsView>
    with WidgetsBindingObserver {
  Object? scope;
  int ticket = 0, version = -1;
  bool loading = false, busy = false, muted = false, savedMuted = false;
  bool verified = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Both clear on the next save/native action, on a mute edit, on a pushed prefs update, on retry success and on server/account/service change (clear()).
  String? error, message;
  bool testPosted = false, nativeBusy = false;
  WorkspaceController? get w => widget.controller;
  late BatteryOptimization battery = widget.battery ?? BatteryOptimization();

  /// Android only: null until known, false while the app is battery optimised.
  bool? batteryExempt;
  int batteryTicket = 0;

  /// Without push, a background notification needs the app exempt from
  /// battery optimisation; the notice shows only once the system says it is not.
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

  /// Phones own the member mute form; desktop authorization belongs to the OS.
  bool get phone =>
      widget.service.platform == TargetPlatform.android ||
      widget.service.platform == TargetPlatform.iOS;

  /// Server-level identity only: switching channels or opening a thread keeps
  /// the accepted settings (Source useServerStore notification prefs).
  Object get authority => (
    w,
    w?.client.origin,
    w?.client.generation,
    w?.client.user?.id,
    w?.client.serverId,
    w?.server?.id,
    w?.server?.string('role'),
  );
  bool get hasServer =>
      w?.client.user != null &&
      w?.server != null &&
      w!.server!.id == w!.client.serverId;
  bool current(int request, Object original) =>
      mounted && ticket == request && original == authority;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refreshBattery());
    widget.service.addListener(serviceChanged);
    w?.addListener(workspaceChanged);
    scope = authority;
    seed();
    unawaited(load());
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
      clear();
      batteryExempt = null;
      unawaited(refreshBattery());
    }
    if (old.controller != w) {
      old.controller?.removeListener(workspaceChanged);
      w?.addListener(workspaceChanged);
    }
    if (old.service != widget.service && old.controller == w) {
      unawaited(load());
    }
    workspaceChanged();
  }

  @override
  void dispose() {
    ++ticket;
    ++batteryTicket;
    WidgetsBinding.instance.removeObserver(this);
    widget.service.removeListener(serviceChanged);
    w?.removeListener(workspaceChanged);
    super.dispose();
  }

  void serviceChanged() {
    if (mounted) setState(() {});
  }

  void clear() {
    ++ticket;
    version = -1;
    verified = false;
    muted = savedMuted = false;
    busy = loading = false;
    error = message = null;
    testPosted = nativeBusy = false;
  }

  /// First frame from the server projection when it carries the prefs; the
  /// GET then revalidates in place without a loading state.
  void seed() {
    final row = hasServer && phone ? w?.server?.json : null;
    final incoming = row?['notificationPrefsVersion'];
    if (incoming is int && row?['serverPushMuted'] is bool) {
      version = incoming;
      muted = savedMuted = row!['serverPushMuted'] as bool;
      verified = true;
      return;
    }
    // Else the settings this page last accepted for the server.
    final c = w;
    final seen = hasServer && phone && c != null
        ? readPageSnapshot(c, _snapshotKey)
        : null;
    if (seen != null && seen['muted'] is bool && seen['version'] is int) {
      version = seen['version'] as int;
      muted = savedMuted = seen['muted'] as bool;
      verified = true;
    }
  }

  static const _snapshotKey = 'notification-settings';

  void workspaceChanged() {
    if (!mounted) return;
    if (scope != authority) {
      scope = authority;
      clear();
      seed();
      setState(() {});
      unawaited(load());
      return;
    }
    if (!phone) return;
    final row = w?.server?.json;
    final incoming = row?['notificationPrefsVersion'];
    if (incoming is int &&
        incoming > version &&
        row?['serverPushMuted'] is bool) {
      setState(() {
        version = incoming;
        muted = savedMuted = row!['serverPushMuted'] as bool;
        verified = true;
        message = error = null;
      });
    }
  }

  bool accept(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Invalid notification settings');
    }
    final incoming = response['prefsVersion'];
    final projected = w?.server?.json['notificationPrefsVersion'];
    final floor = projected is int && projected > version ? projected : version;
    if (incoming is int && incoming < floor) return false;
    if (incoming is int && incoming >= 0) version = incoming;
    // Source Web uses !!notificationSettings.serverPushMuted, and permits
    // older envelopes without prefsVersion; current API returns both fields.
    muted = savedMuted = response['serverPushMuted'] == true;
    verified = true;
    final controller = w;
    if (controller != null) {
      writePageSnapshot(controller, _snapshotKey, pageIdentity(controller), {
        'muted': savedMuted,
        'version': version,
      });
    }
    final server = controller?.server;
    if (controller != null && server != null) {
      final patch = RaftRecord({
        ...server.json,
        'serverPushMuted': savedMuted,
        if (version >= 0) 'notificationPrefsVersion': version,
      });
      controller.server = patch;
      controller.servers = [
        for (final s in controller.servers)
          if (s.id == patch.id) patch else s,
      ];
      controller.notifyListeners();
    }
    return true;
  }

  Future<void> load() async {
    if (!hasServer || !phone) return;
    final request = ++ticket, original = authority, controller = w!;
    // A seeded/accepted value revalidates silently and stays editable.
    final background = verified;
    if (!background) setState(() => loading = true);
    try {
      final response = await controller.client.get(
        '/servers/${controller.server!.id}/notification-settings',
      );
      if (!current(request, original)) return;
      setState(() {
        final edit = muted != savedMuted ? muted : null;
        accept(response);
        if (edit != null && edit != savedMuted) muted = edit;
        loading = false;
        error = null;
      });
    } catch (failure) {
      if (!current(request, original)) return;
      setState(() {
        loading = false;
        if (background &&
            !(failure is RaftApiException &&
                [401, 403, 404].contains(failure.status))) {
          return;
        }
        verified = false;
        muted = savedMuted = false;
        error = 'Notification settings could not be loaded.';
      });
    }
  }

  Future<void> save() async {
    if (!hasServer || !verified || loading || busy || muted == savedMuted) {
      return;
    }
    final request = ++ticket, original = authority, controller = w!;
    final id = controller.server!.id, wanted = muted;
    setState(() {
      busy = true;
      error = message = null;
      testPosted = false;
    });
    try {
      final response = await controller.client.request(
        'PATCH',
        '/servers/$id/notification-settings',
        data: {'serverPushMuted': wanted},
      );
      if (!current(request, original)) return;
      setState(() {
        if (accept(response)) {
          message = savedMuted
              ? 'Notifications from {serverName} are muted.'
              : 'Notifications from {serverName} are unmuted.';
        }
      });
    } catch (failure) {
      if (current(request, original)) {
        setState(() {
          if (failure is RaftApiException &&
              [401, 403, 404].contains(failure.status)) {
            verified = false;
            muted = savedMuted = false;
          }
          error = 'Failed to update server notification setting.';
        });
      }
    } finally {
      if (current(request, original)) setState(() => busy = false);
    }
  }

  /// A system-notification action (permission request, settings, test). The
  /// button stays labelled; it is only disabled while the action runs.
  Future<void> nativeAction(Future<void> Function() action) async {
    if (busy) return;
    final request = ticket, original = authority;
    setState(() {
      busy = nativeBusy = true;
      error = message = null;
      testPosted = false;
    });
    try {
      await action();
    } catch (_) {
      if (current(request, original)) {
        setState(
          () => error = 'System notifications are unavailable on this device.',
        );
      }
    } finally {
      if (current(request, original)) {
        setState(() => busy = nativeBusy = false);
      }
    }
  }

  /// Ask for the permission; once the system stops asking (permanently
  /// denied), take the person to the system notification settings instead.
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

  Future<void> sendTest(String title, String body) async {
    final posted = await widget.service.test(title: title, body: body);
    if (!mounted) return;
    setState(() {
      testPosted = posted;
      error = posted ? null : 'Could not post a test notification.';
    });
  }

  static const _app = 'Raft';

  /// Web's `systemHint` with the OS settings path of the running platform.
  String desktopHint(BuildContext context, TargetPlatform platform) {
    final path = switch (platform) {
      TargetPlatform.macOS => raftFormat(
        context,
        'macOS → System Settings → Notifications → {app}',
        {'app': _app},
      ),
      TargetPlatform.windows => raftText(
        context,
        'Windows → Settings → System → Notifications',
      ),
      _ => raftText(
        context,
        "Linux → your desktop environment's notification settings",
      ),
    };
    return raftFormat(
      context,
      platform == TargetPlatform.windows
          ? 'Manage notifications for Raft in {path}. Do Not Disturb may send notifications directly to the notification center without showing a banner.'
          : platform == TargetPlatform.macOS
          ? 'Whether these notifications appear is decided by the system, not by Raft: {path}. A Focus mode or Do Not Disturb may delay or silence banners.'
          : 'Whether these notifications appear is decided by the system, not by Raft: {path}. The system may ask for permission the first time a notification is posted. A Focus mode or Do Not Disturb may delay or silence banners.',
      {'path': path},
    );
  }

  String testSentMessage(BuildContext context, TargetPlatform platform) {
    if (phone) {
      return raftText(
        context,
        "Test notification sent. If no banner appeared, check Raft's notification settings in the system settings, then try again.",
      );
    }
    final path = raftText(context, switch (platform) {
      TargetPlatform.macOS => 'System Settings → Notifications',
      TargetPlatform.windows => 'Settings → System → Notifications',
      _ => "your desktop environment's notification settings",
    });
    return raftFormat(
      context,
      'Test notification posted to the system. If no banner appeared, allow notifications for {app} in {path}, then try again.',
      {'app': _app, 'path': path},
    );
  }

  String phoneHint(BuildContext context, TargetPlatform platform) => raftText(
    context,
    platform == TargetPlatform.iOS
        ? 'Whether notifications appear is decided by the system: on iOS, Settings → Notifications → Raft. With Do Not Disturb or a Focus mode on, the system may delay or silence notifications.'
        : 'Whether notifications appear is decided by the system: on Android, Settings → Apps → Raft → Notifications. With Do Not Disturb or a Focus mode on, the system may delay or silence notifications.',
  );

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final platform = service.platform;
    final blocked = loading || busy;
    // Availability is decided synchronously, like Web: until the service has
    // initialised it is assumed available, so the card never shows a transient
    // status.
    final unavailable = service.initialized && !service.available;
    if (!phone) {
      final card = RaftNotificationSettingsCard(
        key: const ValueKey('notification-settings-card'),
        title: 'Desktop notifications',
        description: 'Raft Desktop shows system notifications for new DMs, direct mentions, and followed thread replies while the window is in the background. Web push is not used on desktop.',
        status: unavailable
            ? 'Unavailable'
            : platform == TargetPlatform.macOS && service.initialized
            ? service.permitted
                  ? 'Enabled'
                  : 'Off in system settings'
            : 'Managed by the system',
        hint: unavailable
            ? 'This desktop build cannot show system notifications.'
            : desktopHint(context, platform),
        error: error ?? (service.canOpenSettings ? service.error : null),
        message: testPosted ? testSentMessage(context, platform) : null,
        actionLabel: 'Send a test notification',
        actionTone: RaftButtonRecipeVariant.success,
        onAction: blocked || unavailable
            ? null
            : () => nativeAction(
                () => sendTest(
                  raftText(context, 'Test notification'),
                  raftText(
                    context,
                    'Test notification — desktop notifications are working.',
                  ),
                ),
              ),
        muted: false,
      );
      if (!service.canOpenSettings) return card;
      return RaftGapColumn(
        gap: RaftSpace.x3,
        children: [
          card,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RaftButton(
              label: 'Open Notification Settings',
              tone: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.sm,
              onPressed: blocked
                  ? null
                  : () => nativeAction(service.openSettings),
            ),
          ),
          if (platform == TargetPlatform.windows) const WindowsTraySettings(),
        ],
      );
    }
    final chinese = Localizations.maybeLocaleOf(context)?.languageCode == 'zh';
    final card = RaftNotificationSettingsCard(
      key: const ValueKey('notification-settings-card'),
      title: 'Phone notifications',
      description: platform == TargetPlatform.android
          ? 'While Raft is connected, new DMs, direct mentions and replies in followed threads show a system notification.'
          : 'While Raft is connected, new DMs, direct mentions and replies in followed threads show a system notification. In the background Raft checks for new messages periodically, so some may arrive later.',
      status: unavailable
          ? 'Unavailable'
          : service.enabled
          ? (chinese ? '已开启' : 'Enabled')
          : service.initialized && !service.permitted
          ? 'Off in system settings'
          : 'Not enabled',
      hint: unavailable
          ? 'System notifications are unavailable on this device.'
          : phoneHint(context, platform),
      notice: showBatteryNotice
          ? 'To receive notifications in the background, turn off battery optimization for Raft.'
          : null,
      noticeActionLabel: 'Open Battery Settings',
      onNoticeAction: () => unawaited(battery.openSettings()),
      error: error ?? service.backgroundError ?? service.error,
      message: testPosted
          ? testSentMessage(context, platform)
          : message == null
          ? null
          : raftFormat(context, message!, {
              'serverName': w?.server?.name ?? '',
            }),
      onRetry: !verified && !loading && !busy && hasServer
          ? () => unawaited(load())
          : null,
      actionLabel: service.enabled
          ? 'Send Test Notification'
          : 'Enable Notifications',
      actionTone: service.enabled
          ? RaftButtonRecipeVariant.success
          : RaftButtonRecipeVariant.accent,
      onAction: blocked || unavailable
          ? null
          : service.enabled
          ? () => nativeAction(
              () => sendTest(
                raftText(context, 'Test notification'),
                raftText(
                  context,
                  'System notifications are enabled. Tap to return to Raft.',
                ),
              ),
            )
          : () => nativeAction(enable),
      muted: muted,
      muteDescription: hasServer
          ? raftFormat(
              context,
              'Stops notifications from {serverName} for your account. Other servers are unchanged.',
              {'serverName': w!.server!.name},
            )
          : null,
      onMutedChanged: blocked || !verified
          ? null
          : (value) => setState(() {
              muted = value;
              error = message = null;
              testPosted = false;
            }),
      saveLabel: busy && !nativeBusy ? 'Saving…' : 'Save',
      onSave: blocked || !verified || muted == savedMuted ? null : save,
    );
    if (!service.initialized || service.permitted) return card;
    return RaftGapColumn(
      gap: RaftSpace.x3,
      children: [
        card,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: RaftButton(
            label: 'Open Notification Settings',
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            onPressed: blocked || unavailable
                ? null
                : () => nativeAction(service.openSettings),
          ),
        ),
      ],
    );
  }
}
