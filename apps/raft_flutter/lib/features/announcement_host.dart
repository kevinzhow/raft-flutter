import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/announcement_store.dart';
import '../data/workspace_controller.dart';
import 'announcement_cta.dart';

/// Mounts the Web `AnnouncementModal` (v1.21.12: raft-ui's AnnouncementDialog)
/// over the workspace (MainLayout: `<AnnouncementModal suppressed={…onboarding
/// gate…} />`).
///
/// * Entry: the queue is read when the workspace mounts (Web
///   `bootstrapMainLayoutRealtimeBridge`) and on every return to the
///   foreground (Web `recoverLiveSession` on visibility / focus). Publishing
///   never pushes a read.
/// * The oldest unread row is shown when the current server's onboarding
///   gate is ready and onboarding was not seen this session.
/// * The dialog is a layer above the workspace and any dialog open at that
///   moment (Web `layer={1}`). It shows the first page only; every way out
///   (✕, Escape, the scrim, "Got it", the CTA, Enter) dismisses the row.
/// * The CTA dismisses, then opens its href: an internal path or query in the
///   app ([openAnnouncementInternalLink]), an https URL in the browser.
/// * A failed read-complete write raises an error notice once per row.
class AnnouncementHost extends StatefulWidget {
  const AnnouncementHost({
    super.key,
    required this.controller,
    required this.child,
    this.deployment = const String.fromEnvironment(
      'RAFT_DEPLOYMENT_ENV',
      defaultValue: 'production',
    ),
    this.openLink,
  });

  final WorkspaceController controller;
  final Widget child;

  /// VITE_DEPLOYMENT_ENV: `slockdev` shows the popup for one frame, then
  /// confirms it like OK (Web `shouldAutoDismissSlockdevAnnouncement`).
  final String deployment;

  /// Opens a Markdown link (Web `target="_blank"`); defaults to the system
  /// browser.
  final void Function(String href)? openLink;

  @override
  State<AnnouncementHost> createState() => _AnnouncementHostState();
}

class _AnnouncementHostState extends State<AnnouncementHost>
    with WidgetsBindingObserver {
  WorkspaceController get w => widget.controller;
  late WorkspaceController _bound;
  String? _serverId;
  Route<void>? _route;
  String? _routeId;
  bool _scheduled = false;
  final _notified = <String>{};
  final _setupReads = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bind(w);
  }

  void _bind(WorkspaceController controller) {
    _bound = controller;
    controller.addListener(_changed);
    controller.services.announcements.addListener(_changed);
    controller.services.announcementGate.addListener(_changed);
    _serverId = null;
    unawaited(controller.services.announcements.load());
    _changed();
  }

  void _unbind(WorkspaceController controller, {bool disposing = false}) {
    controller.removeListener(_changed);
    controller.services.announcements.removeListener(_changed);
    controller.services.announcementGate.removeListener(_changed);
    _removeRoute(deferred: disposing);
    _notified.clear();
    _setupReads.clear();
  }

  @override
  void didUpdateWidget(AnnouncementHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _unbind(oldWidget.controller);
      _bind(widget.controller);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(w.services.announcements.load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unbind(_bound, disposing: true);
    super.dispose();
  }

  /// Store and gate notifications can arrive mid-build (a gate detaching);
  /// the route is reconciled after the frame.
  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _sync();
    });
    // ignore: raft_lints/avoid_unreviewed_idle_work -- Single request after a state change; nothing re-requests from the callback.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _sync() {
    final gate = w.services.announcementGate, store = w.services.announcements;
    final serverId = w.server?.id;
    if (serverId != _serverId) {
      // Web: the previous server's gate unmounts (its live reading goes).
      final previous = _serverId;
      _serverId = serverId;
      if (previous != null) gate.clearForServer(previous);
    }
    if (serverId != null &&
        gate.stateFor(serverId) == AnnouncementGateState.pending &&
        !gate.hasGate(serverId)) {
      unawaited(_readSetup(serverId));
    }
    for (final id in store.writeFailedIds) {
      if (_notified.add(id)) {
        // AnnouncementModal: `toast.error(common.announcement.saveFailed)`.
        showRaftToast(
          context,
          "Couldn't save that you've read this announcement. It'll show again next time.",
        );
      }
    }
    final current = store.current;
    final visible =
        current != null &&
            current.pages.isNotEmpty &&
            !gate.suppressed(serverId)
        ? current
        : null;
    if (visible?.id == _routeId) return;
    _removeRoute();
    if (visible != null) _present(visible);
  }

  /// No setup gate is mounted for this server (a page without conversation
  /// content): read the projection the Web gate would have read.
  Future<void> _readSetup(String serverId) async {
    if (!_setupReads.add(serverId)) return;
    final controller = w, gate = w.services.announcementGate;
    Map<String, dynamic>? projection;
    try {
      final result = await controller.client.get(
        '/servers/$serverId/setup-projection',
      );
      if (result is Map) projection = Map<String, dynamic>.from(result);
    } catch (_) {
      projection = null;
    } finally {
      _setupReads.remove(serverId);
    }
    if (!mounted || !identical(controller, w)) return;
    if (controller.server?.id != serverId ||
        gate.stateFor(serverId) != AnnouncementGateState.pending) {
      return;
    }
    gate.report(serverId, projection);
  }

  void _present(Announcement a) {
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    if (navigator == null) return;
    final store = w.services.announcements;
    final cta = a.cta, image = a.image;
    // AnnouncementModal `activate`: once per presentation.
    var activated = false;
    void activate() {
      if (activated) return;
      activated = true;
      // Open synchronously in the user gesture; a failed write still raises
      // the store's save-failed notice.
      unawaited(store.dismiss(a.id));
      if (cta != null) _openCta(cta);
    }

    final route = RaftDialogRoute<void>(
      settings: RouteSettings(name: 'announcement:${a.id}'),
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      builder: (context) => RaftAnnouncementModal(
        key: ValueKey('announcement:${a.id}'),
        title: a.title,
        body: a.pages.first.body,
        label: a.label,
        image: image == null
            ? null
            : RaftAnnouncementImage(
                url: announcementImageUrl(w.client.origin, image.assetId),
                alt: image.alt,
              ),
        ctaLabel: cta?.label,
        onCta: activate,
        onDismiss: () => unawaited(store.dismiss(a.id)),
        onLink: widget.openLink ?? _openLink,
      ),
    );
    _route = route;
    _routeId = a.id;
    navigator.push(route).then((_) {
      // Popped from outside (Escape, the scrim, Android back): the dialog's
      // `onOpenChange(false)`, a dismissal like ✕.
      if (!identical(_route, route)) return;
      _route = null;
      _routeId = null;
      unawaited(store.dismiss(a.id));
    });
    if (widget.deployment == 'slockdev') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(_route, route)) unawaited(store.dismiss(a.id));
      });
    }
  }

  void _openCta(AnnouncementCta cta) {
    if (!cta.internal) {
      (widget.openLink ?? _openLink)(cta.href);
      return;
    }
    openAnnouncementInternalLink(
      context,
      w,
      cta.href,
      openExternal: widget.openLink ?? _openLink,
    );
  }

  void _removeRoute({bool deferred = false}) {
    final route = _route;
    _route = null;
    _routeId = null;
    if (route == null) return;
    void remove() {
      if (route.isActive) route.navigator?.removeRoute(route);
    }

    // The navigator cannot change while the tree is being torn down.
    deferred
        ? WidgetsBinding.instance.addPostFrameCallback((_) => remove())
        : remove();
  }

  static void _openLink(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null || !['http', 'https', 'mailto'].contains(uri.scheme)) {
      return;
    }
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
