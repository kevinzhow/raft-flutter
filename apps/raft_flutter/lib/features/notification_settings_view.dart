import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/native_notifications.dart';

/// Mounted NotificationsSection: source card and member-owned server mute form.
/// The delivery actions describe the actual native service, never a fabricated
/// browser permission or web-push subscription.
class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({
    super.key,
    required this.service,
    this.controller,
  });
  final NativeNotificationService service;
  final WorkspaceController? controller;
  @override
  State<NotificationSettingsView> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettingsView> {
  Object? scope;
  int ticket = 0, version = -1;
  bool loading = false, busy = false, muted = false, savedMuted = false;
  bool verified = false;
  String? error, message, nativeBusyLabel;
  WorkspaceController? get w => widget.controller;
  Object get authority => (
    w,
    w?.client.origin,
    w?.client.generation,
    w?.client.user?.id,
    w?.client.serverId,
    w?.server?.id,
    w?.server?.string('role'),
    w?.channelGeneration,
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
    widget.service.addListener(serviceChanged);
    w?.addListener(workspaceChanged);
    scope = authority;
    unawaited(load());
  }

  @override
  void didUpdateWidget(NotificationSettingsView old) {
    super.didUpdateWidget(old);
    if (old.service != widget.service) {
      old.service.removeListener(serviceChanged);
      widget.service.addListener(serviceChanged);
      clear();
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
    error = message = nativeBusyLabel = null;
  }

  void workspaceChanged() {
    if (!mounted) return;
    if (scope != authority) {
      scope = authority;
      clear();
      setState(() {});
      unawaited(load());
      return;
    }
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
    if (!hasServer) return;
    final request = ++ticket, original = authority, controller = w!;
    setState(() => loading = true);
    try {
      final response = await controller.client.get(
        '/servers/${controller.server!.id}/notification-settings',
      );
      if (!current(request, original)) return;
      setState(() {
        accept(response);
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!current(request, original)) return;
      setState(() {
        loading = false;
        verified = false;
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

  Future<void> nativeAction(
    Future<void> Function() action,
    String label,
  ) async {
    if (busy) return;
    final request = ticket, original = authority;
    setState(() {
      busy = true;
      error = message = null;
      nativeBusyLabel = label;
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
        setState(() {
          busy = false;
          nativeBusyLabel = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final blocked = loading || busy;
    return RaftNotificationSettingsCard(
      title: service.receivesMessages
          ? 'DMs, direct mentions, and followed thread replies'
          : 'System notifications',
      description: service.receivesMessages
          ? 'Messages arrive while connected. Background inbox checks provide a fallback when the system allows them; delivery may be delayed.'
          : 'This server does not send desktop message notifications. You can test system delivery.',
      status: loading
          ? 'Checking…'
          : !service.available
          ? 'Unavailable'
          : service.enabled
          ? 'Enabled'
          : 'Disabled',
      availabilityHint: service.available
          ? null
          : 'System notifications are unavailable on this device.',
      error: error ?? service.backgroundError ?? service.error,
      message: message == null
          ? null
          : raftFormat(context, message!, {
              'serverName': w?.server?.name ?? '',
            }),
      onRetry: !verified && !loading && !busy && hasServer
          ? () => unawaited(load())
          : null,
      enableLabel:
          nativeBusyLabel == 'Enabling…' || nativeBusyLabel == 'Disabling…'
          ? nativeBusyLabel!
          : service.enabled
          ? 'Disable Push Notifications'
          : 'Enable Push Notifications',
      onEnable: blocked || !service.available
          ? null
          : () => nativeAction(
              () => service.requestEnable(!service.enabled),
              service.enabled ? 'Disabling…' : 'Enabling…',
            ),
      showTest: service.enabled,
      testLabel: nativeBusyLabel == 'Sending…'
          ? 'Sending…'
          : 'Send test notification',
      onTest: blocked ? null : () => nativeAction(service.test, 'Sending…'),
      showSettings: service.canOpenSettings && service.available,
      onOpenSettings: blocked
          ? null
          : () => nativeAction(service.openSettings, 'Opening…'),
      muted: muted,
      muteDescription: hasServer
          ? raftFormat(
              context,
              'Stops web push notifications from {serverName} for your account. Other servers are unchanged.',
              {'serverName': w!.server!.name},
            )
          : null,
      onMutedChanged: blocked || !verified
          ? null
          : (value) => setState(() {
              muted = value;
              error = message = null;
            }),
      saveLabel: busy && nativeBusyLabel == null ? 'Saving…' : 'Save',
      onSave: blocked || !verified || muted == savedMuted ? null : save,
    );
  }
}
