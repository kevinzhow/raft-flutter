import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/system_notification_projection.dart';
import '../data/system_notification_store.dart';
import '../data/workspace_controller.dart';
import 'fleet_views.dart';
import 'source_feedback_view.dart';
import 'system_notification_copy.dart';

/// The mounted Web system-notification aggregator, separate from message Activity
/// and operating-system notifications. All data and overlay actions are scoped.
class SystemNotificationBell extends StatefulWidget {
  const SystemNotificationBell({
    super.key,
    required this.controller,
    required this.onBilling,
    this.mobile = true,
    this.store,
  });
  final WorkspaceController controller;
  final VoidCallback onBilling;
  final bool mobile;
  final SystemNotificationStore? store;
  @override
  State<SystemNotificationBell> createState() => _SystemNotificationBellState();
}

class _SystemNotificationBellState extends State<SystemNotificationBell>
    with WidgetsBindingObserver {
  WorkspaceController get w => widget.controller;
  late SystemNotificationStore store;
  StreamSubscription<RaftEvent>? events;
  Timer? poll, coalesce, closeDelay;
  OverlayEntry? popup;
  bool popupKeyboard = false;
  bool keyboardInput = false;
  FocusNode? previousFocus;
  final anchor = GlobalKey();
  final focus = FocusNode();
  bool disposed = false;
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
    for (final c in w.channels)
      [c.id, c.joined, c.archived, c.json['channelCapabilities']],
  ]);
  bool current(String scope) =>
      !disposed && mounted && authority == scope && w.client.user != null;

  @override
  void initState() {
    super.initState();
    attach();
  }

  void attach() {
    store = widget.store ?? SystemNotificationStore(get: w.query);
    unawaited(bind());
    store.addListener(updated);
    w.addListener(changed);
    events = w.client.events.listen((e) {
      changed();
      if (e.name.startsWith('machine:') ||
          e.name.startsWith('agent:') ||
          e.name.startsWith('server:member')) {
        coalesce?.cancel();
        coalesce = Timer(const Duration(milliseconds: 150), store.refresh);
      }
    });
    poll = Timer.periodic(const Duration(seconds: 60), (_) => store.refresh());
    WidgetsBinding.instance.addObserver(this);
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
    ),
  );

  void changed() {
    final old = store.context?.scope;
    final next = authority;
    if (old != next) close(remove: true);
    unawaited(bind());
  }

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
    }
  }

  void detach(SystemNotificationBell owner) {
    owner.controller.removeListener(changed);
    store.removeListener(updated);
    events?.cancel();
    poll?.cancel();
    coalesce?.cancel();
    closeDelay?.cancel();
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
      unawaited(store.refresh());
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
    final anchorRect = box.localToGlobal(Offset.zero) & box.size;
    final size = MediaQuery.sizeOf(context);
    final width = math.min(320.0, math.max(0.0, size.width - 16));
    final height = math.min(288.0, math.max(0.0, size.height - 16));
    final left = widget.mobile
        ? (anchorRect.right - width).clamp(
            8.0,
            math.max(8.0, size.width - width - 8),
          )
        : (anchorRect.right + 8).clamp(
            8.0,
            math.max(8.0, size.width - width - 8),
          );
    final top = widget.mobile
        ? (anchorRect.bottom + 8).clamp(
            8.0,
            math.max(8.0, size.height - height - 8),
          )
        : (anchorRect.bottom - height).clamp(
            8.0,
            math.max(8.0, size.height - height - 8),
          );
    final overlay = Overlay.of(context, rootOverlay: true);
    final themes = InheritedTheme.capture(from: context, to: overlay.context);
    final entry = OverlayEntry(
      builder: (_) => themes.wrap(
        Stack(
          children: [
            Positioned(
              left: left.toDouble(),
              top: top.toDouble(),
              width: width,
              height: height,
              child: TapRegion(
                groupId: this,
                onTapOutside: (_) => close(),
                child: MouseRegion(
                  onEnter: (_) => closeDelay?.cancel(),
                  onExit: (_) {
                    if (!widget.mobile) {
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
    );
    popup = entry;
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
    final copy = systemNotificationCopy(context, n);
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
        _ => RaftGlyph.triangleAlert,
      },
      actions: [
        if (n.destination != SystemNoticeDestination.billing ||
            w.can('viewBilling'))
          RaftNotificationAction(
            label: raftText(
              context,
              n.destination == SystemNoticeDestination.billing
                  ? 'Upgrade'
                  : n.destination == SystemNoticeDestination.feedback
                  ? 'View feedback'
                  : 'View',
            ),
            primary: true,
            onPressed: () => navigate(n, scope),
          ),
        if (n.fingerprint != null)
          RaftNotificationAction(
            label: raftText(context, 'Dismiss'),
            onPressed: () {
              if (live(n, scope)) store.dismiss(scope, n.fingerprint!);
            },
          ),
      ],
    );
  }

  Future<void> navigate(SystemNotice n, String captured) async {
    if (!live(n, captured)) return;
    if (n.destination == SystemNoticeDestination.billing) {
      if (!w.can('viewBilling')) return;
      close();
      if (current(captured)) widget.onBilling();
      return;
    }
    if (n.destination != SystemNoticeDestination.feedback &&
        !w.can('viewMachines')) {
      return;
    }
    Map<String, dynamic>? row;
    if (n.destination == SystemNoticeDestination.computer) {
      for (final machine in store.machines) {
        if (machine['id'] == n.targetId) row = machine;
      }
      if (row == null) return;
    }
    close();
    if (!current(captured)) return;
    final route = MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            raftText(
              context,
              n.destination == SystemNoticeDestination.feedback
                  ? 'Feedback'
                  : 'Computers',
            ),
          ),
        ),
        body: n.destination == SystemNoticeDestination.feedback
            ? SourceFeedbackView(
                controller: w,
                onUnreadChanged: (count) {
                  if (current(captured)) {
                    store.reconcileFeedback(captured, count);
                  }
                },
              )
            : row != null
            ? FleetDetail(controller: w, computers: true, initial: row)
            : FleetView(controller: w, computers: true, attentionOnly: true),
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

  double attentionInset(BuildContext context) {
    final visualSize = widget.mobile ? 32.0 : 40.0;
    final glyphSize = widget.mobile ? 16.0 : 18.0;
    // Source positions the dot relative to the glyph inside the visual box.
    // RaftInteractive extends touch semantics without inflating that box.
    return (visualSize - glyphSize) / 2 - 4;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: popup == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && popup != null) close();
    },
    child: Listener(
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
        child: MouseRegion(
          onEnter: (_) {
            if (!widget.mobile) unawaited(show());
          },
          onExit: (_) {
            if (!widget.mobile) {
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
                  semanticLabel: store.entries.isEmpty
                      ? raftText(context, 'Notification center')
                      : raftFormat(
                          context,
                          'Notification center ({count} active)',
                          {'count': store.entries.length},
                        ),
                  visualSize: widget.mobile ? 32 : 40,
                  glyphSize: widget.mobile ? 16 : 18,
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
                if (store.entries.isNotEmpty)
                  Positioned(
                    right: attentionInset(context),
                    top: attentionInset(context),
                    child: IgnorePointer(
                      child: RaftNotificationAttention(
                        count: store.entries.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
