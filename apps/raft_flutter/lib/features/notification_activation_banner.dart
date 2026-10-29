import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/raft_location.dart';
import '../platform/native_notifications.dart';
import 'channel_footer_states.dart';

/// One app-session dismissal lives in the notification service, so changing
/// channels, layouts or accounts cannot bring the reminder straight back.
class NotificationActivationHost extends StatefulWidget {
  const NotificationActivationHost({
    super.key,
    this.service,
    required this.child,
  });
  final NativeNotificationService? service;
  final Widget child;
  @override
  State<NotificationActivationHost> createState() => _ActivationHostState();
}

class _ActivationHostState extends State<NotificationActivationHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.state == ViewFocusState.focused) _refresh();
  }

  void _refresh() => unawaited(widget.service?.refreshPermission());

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ActivationScope(service: widget.service, child: widget.child);
}

class _ActivationScope extends InheritedWidget {
  const _ActivationScope({required this.service, required super.child});
  final NativeNotificationService? service;
  @override
  bool updateShouldNotify(_ActivationScope oldWidget) =>
      service != oldWidget.service;
}

/// Placed only beside the actual composer, after the footer/selection decision.
class NotificationActivationComposer extends StatelessWidget {
  const NotificationActivationComposer({
    super.key,
    required this.controller,
    required this.thread,
    required this.child,
  });
  final WorkspaceController controller;
  final bool thread;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final service = context
        .dependOnInheritedWidgetOfExactType<_ActivationScope>()
        ?.service;
    final w = controller, c = w.channel;
    final eligible =
        !thread &&
        c != null &&
        c.type != 'thread' &&
        channelFooterKind(w, DateTime.now()) == ChannelFooterKind.composer &&
        c.json['readOnlyReason'] == null &&
        !w.conversationPaused &&
        !w.sharedBlocked(thread: false) &&
        w.can('viewChannel', resource: c);
    if (service == null || !eligible) return child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NotificationActivationBanner(
          service: service,
          onSettings: () {
            w.closeThread(navigate: false);
            w.navigation.navigate(
              RaftLocation.at(
                serverSlug: w.location.serverSlug,
                route: RaftRoute.settings,
                settingsPath: const ['notifications'],
              ),
            );
            w.notifyListeners();
          },
        ),
        child,
      ],
    );
  }
}

/// Web v1.21.12 NotificationActivationBanner: explicit opt-in, a session-only
/// dismissal with a three-second confirmation, and OS settings reconciliation.
class NotificationActivationBanner extends StatefulWidget {
  const NotificationActivationBanner({
    super.key,
    required this.service,
    required this.onSettings,
  });
  final NativeNotificationService service;
  final VoidCallback onSettings;
  @override
  State<NotificationActivationBanner> createState() => _ActivationBannerState();
}

class _ActivationBannerState extends State<NotificationActivationBanner> {
  bool busy = false, confirming = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Activation failure belongs to the current opt-in attempt; next attempt/dismiss clears it and a permission grant removes the banner.
  String? error;
  Timer? confirmation;
  @override
  void dispose() {
    confirmation?.cancel();
    super.dispose();
  }

  Future<void> enable() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    await widget.service.requestEnable(true);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (!widget.service.activationAsked && !widget.service.permitted) {
        error = "Couldn't enable notifications. Try again.";
      }
    });
  }

  void dismiss() {
    widget.service.dismissActivation();
    setState(() {
      confirming = true;
      error = null;
    });
    // Functional, finite dismissal clock; no polling or recurring idle frames.
    confirmation = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => confirming = false);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      if (widget.service.permitted ||
          widget.service.activationAsked ||
          (!widget.service.showActivation && !confirming)) {
        return const SizedBox.shrink();
      }
      final mobile = RaftDensityScope.of(context) == RaftDensity.touch;
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RaftSpace.x3,
          vertical: RaftSpace.x2,
        ),
        child: confirming
            ? RaftBanner(
                key: const ValueKey('notification-activation-dismiss-confirm'),
                status: RaftBannerRecipeStatus.info,
                size: RaftBannerRecipeSize.sm,
                glyph: RaftGlyph.check,
                description: 'Hidden for now — turn on anytime in',
                descriptionTail: (
                  label: 'Settings › Notifications',
                  onPressed: widget.onSettings,
                ),
              )
            : RaftBanner(
                key: const ValueKey('notification-activation-banner'),
                centerAction: true,
                status: RaftBannerRecipeStatus.info,
                size: RaftBannerRecipeSize.sm,
                glyph: RaftGlyph.bell,
                title: mobile
                    ? 'Agents keep working after you leave.'
                    : 'Your agents keep working after you leave.',
                description: mobile
                    ? 'Get notified when they finish or need you.'
                    : "Turn on notifications so you don't miss when they finish or need you.",
                action: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: RaftSpace.x2,
                  children: [
                    RaftButton(
                      size: RaftButtonRecipeSize.sm,
                      tone: RaftButtonRecipeVariant.accent,
                      label: busy ? 'Enabling…' : 'Enable Notifications',
                      onPressed: busy ? null : enable,
                    ),
                    RaftCloseButton(
                      tooltip: 'Hide Notification Reminder for This Session',
                      onPressed: dismiss,
                    ),
                  ],
                ),
                footer: error == null ? null : Text(raftText(context, error!)),
              ),
      );
    },
  );
}
