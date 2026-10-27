import 'dart:async';
import 'dart:convert';
import 'dart:io' show stderr;

import 'package:flutter/widgets.dart'
    show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import 'package:app_links/app_links.dart';
import 'package:raft_client/raft_client.dart';

import '../data/activity_attention.dart';
import '../data/workspace_controller.dart';
import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../features/invite_accept_view.dart';
import 'app_window.dart';
import 'live_session_recovery.dart';
import 'content_target.dart';
import 'content_links.dart';
import 'raft_app_links.dart';
import 'native_notifications.dart';
import 'background_inbox.dart';
import 'background_notifications.dart';
import 'desktop_inbox_notifications.dart';
import 'macos_dock_unread.dart';
import 'notification_reconciler.dart';
import 'native_sharing.dart';
import 'windows_tray.dart';

/// Binds platform links and notification clicks to the currently signed-in
/// principal. Every navigation rechecks server membership and visible context.
class NativeContentCoordinator with WidgetsBindingObserver {
  NativeContentCoordinator({
    NativeNotificationService? notifications,
    this.links,
    this.onIncomingShare,
    MacOSDockUnread? dockUnread,
    WindowsTray? tray,
    this.appLinks = RaftAppLinks.enabled,
  }) : _providedTray = tray,
       _providedDockUnread = dockUnread,
       notifications = notifications ?? NativeNotificationService();
  final NativeNotificationService notifications;

  /// Raft https links open the app (see [RaftAppLinks]); off until the domain
  /// serves the association files.
  final bool appLinks;
  final MacOSDockUnread? _providedDockUnread;
  final WindowsTray? _providedTray;
  late final tray =
      _providedTray ?? WindowsTray(platform: notifications.platform);
  late final dockUnread =
      _providedDockUnread ?? MacOSDockUnread(platform: notifications.platform);

  /// Keeps the shade equal to the Activity unread state (cancel on read,
  /// counts, Android backlog); see [NotificationReconciler].
  late final reconciler = NotificationReconciler(
    notifications: notifications,
    accountUnread: dockUnread.counts,
  );
  final Stream<Uri>? links;
  void Function()? onIncomingShare;
  final background = BackgroundNotificationScheduler();
  DesktopInboxNotifications? desktop;
  bool? _appForeground;

  bool get _isDesktop => const {
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  }.contains(notifications.platform);

  /// Whether the app is active.
  ///
  /// Unknown mobile state preserves foreground read receipts. Desktop startup
  /// resolves native activation, defaulting to background if unavailable.
  /// The root also checks workspace visibility, such as the server chooser.
  bool get appForeground => _appForeground ?? !_isDesktop;
  void Function()? onForegroundChanged;
  WorkspaceController? _workspace;
  LiveSessionRecovery? _liveRecovery;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<RaftEvent>? _events;
  String? _scope;
  int _epoch = 0, _navigation = 0;
  bool _closed = false;
  bool _workspaceBindingResolved = false;
  Uri? _pendingLink;

  /// The content link kept until the account is restored.
  @visibleForTesting
  Uri? get pendingLink => _pendingLink;
  String? _pendingTap;
  bool _pendingTapInitial = false;
  final Set<String> _delivered = {};
  final Set<String> _inFlight = {};

  Future<void> init({List<String> initialArguments = const []}) async {
    _appForeground = WidgetsBinding.instance.lifecycleState == null
        ? null
        : WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _liveRecovery = LiveSessionRecovery()..bind(_workspace);
    tray.onHidden = () => _setAppForeground(false);
    await tray.initialize(notifications.localize);
    if (_closed) return;
    dockUnread.bind(_workspace);
    reconciler.bind(_workspace);
    notifications.onTap = _tap;
    // Desktop startup waits for native activation; unknown mobile lifecycle
    // retains the workspace visibility fallback for incoming notifications.
    notifications.deliveryAllowed = () =>
        !_closed &&
        (!_isDesktop || _appForeground != null) &&
        !(_appForeground ?? _workspace?.foreground ?? true);
    notifications.addListener(_notificationSettingsChanged);
    if (_isDesktop) {
      desktop = DesktopInboxNotifications(notifications: notifications);
      desktop!.bind(_workspace);
    }
    unawaited(background.initialize().catchError((Object _) {}));
    _linkSubscription = (links ?? AppLinks().uriLinkStream).listen(
      receiveLink,
      onError: (_) {},
    );
    if (_appForeground == null && _isDesktop) {
      final active = await isAppWindowActive(platform: notifications.platform);
      if (_closed) return;
      // A lifecycle event received during the native read is newer evidence.
      if (_appForeground == null) _setAppForeground(active);
    }
    await notifications.initialize();
    for (final argument in initialArguments) {
      final uri = Uri.tryParse(argument);
      if (uri != null) receiveLink(uri);
    }
    if (notifications.platform == TargetPlatform.windows &&
        initialArguments.contains('--windows-notification-test')) {
      await notifications.test();
    }
    if (notifications.platform == TargetPlatform.linux &&
        initialArguments.contains('--linux-notification-test')) {
      _linuxProbe = true;
      stderr.writeln(
        'raft-probe lifecycle=${WidgetsBinding.instance.lifecycleState}',
      );
      await notifications.bind('linux-notification-test');
      await notifications.test();
      await _linuxProbeSend();
    }
  }

  /// Manual check on a notification server (docs/linux-desktop.md): with
  /// `--linux-notification-test` the app posts a test alert at start, then
  /// tries the same message alerts on every focus change. They go through
  /// the production delivery gate, so only an unfocused window shows them.
  bool _linuxProbe = false;
  Future<void> _linuxProbeSend() async {
    await notifications.bind('linux-notification-test');
    const base = 'raft://v1/servers/s1';
    for (final (title, body, uri) in const [
      (
        '#general',
        'Ada: first <b>message</b> & more',
        '$base/channels/c1/messages/m1',
      ),
      ('#general', 'Ada: second message', '$base/channels/c1/messages/m2'),
      ('#random', 'Bo: other channel', '$base/channels/c2/messages/m3'),
      ('Cy', 'direct message', '$base/dms/d1/messages/m4'),
    ]) {
      await notifications.show(
        title: title,
        body: body,
        payload: jsonEncode({
          'origin': 'https://example.test',
          'principal': 'u1',
          'serverId': 's1',
          'uri': uri,
        }),
      );
    }
  }

  void bindAccount(RaftClient? client) {
    final previous = dockUnread.counts.notificationAccount;
    dockUnread.bindAccount(client);
    if (previous != null && previous != dockUnread.counts.notificationAccount) {
      unawaited(notifications.bindAuthenticatedWorkspace(null));
    }
  }

  void retireAccount() {
    bindWorkspace(null);
    bindAccount(null);
    unawaited(notifications.bindAuthenticatedWorkspace(null));
  }

  void bindWorkspace(WorkspaceController? workspace) {
    _workspaceBindingResolved = true;
    if (identical(workspace, _workspace)) {
      _changed();
      return;
    }
    _workspace?.removeListener(_changed);
    _events?.cancel();
    _workspace = workspace;
    _liveRecovery?.bind(workspace);
    if (!appForeground) workspace?.setForeground(false);
    desktop?.bind(workspace);
    dockUnread.bind(workspace);
    reconciler.bind(workspace);
    workspace?.addListener(_changed);
    _events = workspace?.client.events.listen(_event);
    _changed();
    final link = _pendingLink, tap = _pendingTap;
    final replaceInitial = _pendingTapInitial;
    _pendingLink = null;
    _pendingTap = null;
    _pendingTapInitial = false;
    if (workspace != null) {
      if (link != null) receiveLink(link);
      if (tap != null) _tap(tap, replaceInitial: replaceInitial);
    }
  }

  String? get currentScope {
    final c = _workspace?.client;
    if (c?.user == null || c?.serverId == null) return null;
    return '${c!.origin}\n${c.user!.id}\n${c.serverId}';
  }

  void _changed() {
    unawaited(tray.configure(notifications.localize));
    final scope = currentScope;
    if (_scope == scope) return;
    _scope = scope;
    _epoch++;
    _navigation++;
    _delivered.clear();
    _inFlight.clear();
    unawaited(background.bind(null, false).catchError((Object _) {}));
    unawaited(
      scope == null
          ? notifications.detachWorkspace(dockUnread.counts.notificationAccount)
          : notifications.bindAuthenticatedWorkspace(scope),
    );
  }

  void _notificationSettingsChanged() {
    unawaited(dockUnread.resync());
    reconciler.notificationsChanged();
    if (!_workspaceBindingResolved || _closed) return;
    unawaited(
      background
          .bind(currentScope, notifications.enabled)
          .then((_) {
            if (!_closed) notifications.setBackgroundError(null);
          })
          .catchError((Object _) {
            if (!_closed) {
              notifications.setBackgroundError(
                'Background Activity checks could not be scheduled. Open Raft to retry.',
              );
            }
          }),
    );
  }

  Future<bool> pollBackground() async {
    final w = _workspace, scope = _scope, epoch = _epoch;
    if (w == null ||
        scope == null ||
        !notifications.enabled ||
        w.foreground ||
        notifications.deliveryAllowed?.call() == false) {
      return true;
    }
    bool valid() =>
        !_closed &&
        _workspace == w &&
        _scope == scope &&
        _epoch == epoch &&
        !w.foreground;
    return BackgroundInboxPoller(
      client: w.client,
      store: background.store,
      authorize: (target, _) async {
        final server = await authorize(w, target, valid);
        if (server.flag('serverPushMuted')) {
          throw const RaftApiException('Notifications are muted.');
        }
      },
      suppress: (_) => w.foreground,
      deliver: (alert, selected) async {
        if (!valid() || selected != scope || !notifications.enabled) {
          return false;
        }
        await notifications.show(
          title: alert.title,
          body: alert.body,
          payload: notificationPayload(w.client, alert.target),
        );
        return valid() && notifications.enabled && notifications.error == null;
      },
    ).run();
  }

  void receiveLink(Uri uri) {
    if (_closed || uri.scheme == 'raft' && uri.host == 'oauth') return;
    if (NativeSharing.isIncomingShareLink(uri)) {
      onIncomingShare?.call();
      return;
    }
    if (notifications.receiveWindowsActivation(uri)) return;
    // raft://v1/join/<token>: an invite opens the invite page, signed in or not.
    final appLink = RaftAppLinks.accepts(uri, on: appLinks);
    if (uri.scheme == 'raft' && uri.host == 'v1' || appLink) {
      final invite = InviteLink.fromLocation(uri);
      if (invite != null && uri.toString().length <= 2048) {
        InviteRequests.instance.open(invite);
        return;
      }
    }
    final w = _workspace;
    if (w == null || w.client.user == null) {
      // Only a bounded content URI can wait for normal account restoration.
      if ((uri.scheme == 'raft' && uri.host == 'v1' || appLink) &&
          uri.toString().length <= 2048) {
        _pendingLink = uri;
      }
      return;
    }
    final target = ContentTarget.parse(
      uri,
      origin: ContentLinks.originFor(w.client.origin),
    );
    if (target != null) unawaited(navigate(target));
  }

  /// Raises the window with the focus token the desktop sent for the click,
  /// which Wayland compositors and KWin need before they let it take focus.
  Future<void> _presentLinuxWindow() async {
    try {
      final token = await notifications.takeActivationToken();
      if (_linuxProbe) stderr.writeln('raft-probe present token=$token');
      await const MethodChannel(
        'app.raft/window',
      ).invokeMethod<void>('present', token == null ? null : {'token': token});
    } catch (_) {
      // A window that cannot be raised still opens the conversation.
    }
  }

  void _tap(String payload, {bool replaceInitial = false}) {
    if (_closed) return;
    if (_linuxProbe) stderr.writeln('raft-probe tap payload=$payload');
    unawaited(notifications.presentWindow().catchError((Object _) {}));
    if (notifications.platform == TargetPlatform.linux) {
      unawaited(_presentLinuxWindow());
    }
    if (payload == 'raft-notification-test' ||
        payload == NotificationReconciler.moreNotificationPayload) {
      return;
    }
    if (_workspace == null) {
      if (payload.length <= 4096) {
        _pendingTap = payload;
        // The first restored surface is startup state, not a visited Back entry.
        _pendingTapInitial = !_workspaceBindingResolved;
      }
      return;
    }
    try {
      final data = jsonDecode(payload);
      final c = _workspace!.client;
      if (data is! Map ||
          data['origin'] != c.origin ||
          data['principal'] != c.user?.id ||
          data['serverId'] != c.serverId ||
          data['uri'] is! String) {
        return;
      }
      final target = ContentTarget.parse(
        Uri.parse(data['uri']),
        origin: ContentLinks.originFor(c.origin),
      );
      if (target != null && target.serverId == c.serverId) {
        unawaited(navigate(target, replaceEntry: replaceInitial));
      }
    } catch (_) {
      /* Untrusted platform payloads cannot navigate. */
    }
  }

  /// The longest an alert waits for the Activity window to list its message.
  static const freshCap = Duration(milliseconds: 1500);

  Future<void> _event(RaftEvent event) async {
    if (event.name != 'notification:push' ||
        !notifications.receivesMessages ||
        !notifications.enabled ||
        event.payload is! Map) {
      return;
    }
    final w = _workspace, scope = _scope, epoch = _epoch;
    if (w == null || scope == null) return;
    final p = event.payload as Map;
    final target = ContentTarget.fromNotification(p);
    if (target == null ||
        target.serverId != w.client.serverId ||
        p['title'] is! String ||
        p['body'] is! String) {
      return;
    }
    if (w.foreground || notifications.deliveryAllowed?.call() == false) return;
    final key = '${target.serverId}:${target.messageId}';
    if (_delivered.contains(key) || _inFlight.contains(key)) return;
    try {
      if (backgroundRefreshSupported &&
          await background.store.seen(scope, target.messageId!)) {
        return;
      }
    } catch (_) {
      return;
    }
    if (_closed || _workspace != w || _scope != scope || epoch != _epoch) {
      return;
    }
    _inFlight.add(key);
    try {
      // The server lists a new message in the inbox about a second after it
      // announces it. Read the Activity window now (in parallel with the
      // checks below) so that opening the app from this alert finds the
      // conversation current; the alert itself never waits past the cap.
      final fresh = w.services.activityUnreadIfBound?.reach(
        // A thread reply's row is the thread's own channel.
        channelId: p['channelId'] as String,
        messageId: p['messageId'] as String,
        timeout: freshCap,
      );
      // Socket room delivery is an eligibility decision, not lasting authority.
      final memberServer = await authorize(
        w,
        target,
        () => !_closed && _workspace == w && _scope == scope && epoch == _epoch,
      );
      if (_closed || _workspace != w || _scope != scope || epoch != _epoch) {
        return;
      }
      if (fresh != null) {
        await fresh;
        if (_closed || _workspace != w || _scope != scope || epoch != _epoch) {
          return;
        }
      }
      if (memberServer.flag('serverPushMuted') ||
          w.foreground ||
          notifications.deliveryAllowed?.call() == false) {
        return;
      }
      _delivered.add(key);
      if (_delivered.length > 1000) _delivered.remove(_delivered.first);
      // The conversation's Activity count after the window reached this
      // message: the number the in-app badge and the launcher badge show.
      final unread = activityRowUnread(
        w.services.activityUnreadIfBound?.acceptedRows ?? const [],
        p['channelId'] as String,
      );
      await notifications.show(
        title: (p['title'] as String).substring(
          0,
          (p['title'] as String).length.clamp(0, 160),
        ),
        body: (p['body'] as String).substring(
          0,
          (p['body'] as String).length.clamp(0, 512),
        ),
        payload: jsonEncode({
          'origin': w.client.origin,
          'principal': w.client.user!.id,
          'serverId': target.serverId,
          'uri': target.nativeUri(target.serverId!).toString(),
        }),
        unread: unread,
      );
      if (backgroundRefreshSupported &&
          !_closed &&
          _workspace == w &&
          _scope == scope &&
          epoch == _epoch &&
          notifications.enabled &&
          notifications.error == null) {
        await background.store.mark(scope, target.messageId!);
      }
    } catch (_) {
      /* Revocation, stale requests or offline context suppress alerts. */
    } finally {
      if (epoch == _epoch) _inFlight.remove(key);
    }
  }

  /// Opens [target] without waiting for the network. The destination is
  /// published from what the device already knows (the selected workspace's
  /// cached channel list, or just its URL, which the workspace view renders as
  /// a loading channel), and membership, channel and message authority are
  /// verified concurrently. A denial reverts the optimistic entry and reports
  /// the failure; nothing is sent or written on the strength of the cache.
  Future<void> navigate(
    ContentTarget target, {
    bool replaceEntry = false,
  }) async {
    final w = _workspace,
        scope = _scope,
        epoch = _epoch,
        navigation = ++_navigation;
    if (w == null || scope == null) return;
    bool valid() =>
        !_closed &&
        _workspace == w &&
        _scope == scope &&
        _epoch == epoch &&
        _navigation == navigation;
    final slug = w.location.serverSlug;
    final ownWorkspace = target.serverId != null
        ? target.serverId == w.client.serverId
        : target.serverSlug == slug;
    final known = !ownWorkspace
        ? null
        : [...w.channels, ...w.dms]
              .where(
                (c) =>
                    c.id == target.channelId &&
                    w.can('viewChannel', resource: c),
              )
              .firstOrNull;
    final previous = w.location;
    final previousIndex = w.navigation.index;
    var published = false, replacedEntry = replaceEntry;
    // Verification starts first so it overlaps the page opening below.
    final authorization = _authorizeContent(w.client, target, valid);
    unawaited(authorization.then<void>((_) {}, onError: (Object _) {}));
    try {
      Future<void>? opening;
      if (known != null) {
        published = true;
        opening = _open(w, target, known, replaceEntry: replaceEntry);
        // Its failure is reported once, below, after verification settles.
        unawaited(opening.then<void>((_) {}, onError: (Object _) {}));
      } else if (ownWorkspace) {
        // Unknown to the device: show the destination's loading shell now.
        published = true;
        w.navigation.navigate(
          _destination(w, target, target.kind == 'dm'),
          kind: replaceEntry
              ? RaftNavigationKind.replace
              : RaftNavigationKind.push,
        );
        replacedEntry = true;
        w.notifyListeners();
      }
      final (server, channel) = await authorization;
      if (!valid()) return;
      // Content links never switch the signed-in account or coordinator origin.
      // Cross-server links require an explicit server selection in the app first.
      if (server.id != w.client.serverId) {
        throw const RaftApiException('Unavailable server.');
      }
      if (target.parentMessageId != null &&
          !w.can('viewChannel', resource: channel)) {
        throw const RaftApiException('Unavailable channel.');
      }
      opening ??= _open(w, target, channel, replaceEntry: replacedEntry);
      await opening;
    } catch (_) {
      if (valid()) {
        if (published) _revert(w, previous, previousIndex, replaceEntry);
        // ignore: raft_lints/avoid_imperative_notice_state -- Workspace-level w.error is shown once as a toast by workspace_view.syncWorkspaceError and cleared there (self-dismissing).
        w.setError(
          'This link is unavailable for the current account or server.',
        );
      }
    }
  }

  RaftLocation _destination(
    WorkspaceController w,
    ContentTarget target,
    bool dm,
  ) {
    final base = RaftLocation.at(
      serverSlug: w.location.serverSlug,
      route: dm ? RaftRoute.dm : RaftRoute.channel,
      entityId: target.channelId,
    );
    return target.parentMessageId != null
        ? base.withQuery({
            'thread': '${target.channelId}:${target.parentMessageId}',
            'msg': target.messageId,
          })
        : target.messageId != null
        ? base.withQuery({'msg': target.messageId})
        : base;
  }

  /// Publishes [channel]'s destination and loads it. Everything before the
  /// first await runs synchronously, so the page opens on the next frame.
  Future<void> _open(
    WorkspaceController w,
    ContentTarget target,
    RaftChannel channel, {
    required bool replaceEntry,
  }) async {
    if (target.parentMessageId != null) {
      if (!w.can('viewChannel', resource: channel)) {
        throw const RaftApiException('Unavailable channel.');
      }
      // Publish the complete destination once. The parent channel tail and
      // reply window then load independently, without an intermediate page.
      w.navigation.navigate(
        _destination(w, target, channel.type == 'dm'),
        kind: replaceEntry
            ? RaftNavigationKind.replace
            : RaftNavigationKind.push,
      );
      w.channel = channel;
      final opening = w.openThreadIdentity(
        parentChannelId: channel.id,
        parentMessageId: target.parentMessageId!,
        focusedMessageId: target.messageId,
        initialThreadChannelId: target.threadId,
        navigate: false,
      );
      await Future.wait([
        opening,
        w.selectChannel(channel, navigate: false, preserveThread: true),
      ]);
    } else {
      await w.jumpToMessage(
        target.channelId,
        target.messageId,
        replaceEntry: replaceEntry,
      );
    }
  }

  /// A denied optimistic entry leaves as Back would: the history entry it
  /// added is dropped (or, for a replaced start page, restored) and the
  /// workspace follows the location again.
  void _revert(
    WorkspaceController w,
    RaftLocation previous,
    int previousIndex,
    bool replaced,
  ) {
    if (replaced) {
      w.navigation.navigate(previous, kind: RaftNavigationKind.replace);
    } else if (w.navigation.index > previousIndex && previousIndex >= 0) {
      w.navigation.back();
    } else {
      return;
    }
    final next = w.location;
    if (next.thread == null) w.closeThread(navigate: false);
    w.notifyListeners();
    if ({RaftRoute.channel, RaftRoute.dm}.contains(next.route) &&
        w.channel?.id != next.entityId) {
      unawaited(
        w.jumpToMessage(next.entityId!, next.messageId, navigate: false),
      );
    }
  }

  static Future<RaftRecord> authorize(
    WorkspaceController w,
    ContentTarget target,
    bool Function() valid,
  ) => authorizeClient(w.client, target, valid);

  static Future<RaftRecord> authorizeClient(
    RaftClient client,
    ContentTarget target,
    bool Function() valid,
  ) async => (await _authorizeContent(client, target, valid)).$1;

  static Future<(RaftRecord, RaftChannel)> _authorizeContent(
    RaftClient client,
    ContentTarget target,
    bool Function() valid,
  ) async {
    final rows = await client.servers();
    if (!valid()) throw const RaftApiException('Stale content link.');
    final server = rows
        .where(
          (s) => target.serverId != null
              ? s.id == target.serverId
              : s.string('slug') == target.serverSlug,
        )
        .firstOrNull;
    if (server == null || server.id != client.serverId) {
      throw const RaftApiException('Unavailable server.');
    }
    final channel = await client.get('/channels/${target.channelId}');
    if (!valid() ||
        channel is! Map ||
        channel['id'] != target.channelId ||
        channel['serverId'] != server.id) {
      throw const RaftApiException('Unavailable channel.');
    }
    if (target.messageId != null) {
      final context = await client.get(
        '/messages/context/${target.messageId}',
        query: {'channelId': target.channelId},
      );
      if (!valid() || context is! Map || context['messages'] is! List) {
        throw const RaftApiException('Unavailable message.');
      }
      final canonicalMessage = context['canonicalTarget'];
      final rows = context['messages'] as List;
      if (!rows.whereType<Map>().any((row) => row['id'] == target.messageId) &&
          (canonicalMessage is! Map ||
              canonicalMessage['kind'] != 'thread' ||
              canonicalMessage['messageId'] != target.messageId)) {
        throw const RaftApiException('Unavailable message.');
      }
      final canonical = context['canonicalTarget'];
      if (target.parentMessageId != null &&
          (canonical is! Map ||
              canonical['kind'] != 'thread' ||
              canonical['threadParentMessageId'] != target.parentMessageId ||
              target.threadId != null &&
                  canonical['threadChannelId'] != target.threadId)) {
        throw const RaftApiException('Unavailable thread.');
      }
    }
    return (server, RaftChannel(Map<String, dynamic>.from(channel)));
  }

  void _setAppForeground(bool active) {
    final resumed = active && _appForeground != true;
    _appForeground = active;
    if (resumed) {
      unawaited(dockUnread.resync());
      unawaited(dockUnread.refresh());
    }
    if (!active) _workspace?.setForeground(false);
    onForegroundChanged?.call();
    desktop?.sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setAppForeground(state == AppLifecycleState.resumed);
    if (_linuxProbe) {
      stderr.writeln('raft-probe lifecycle=$state');
      unawaited(_linuxProbeSend());
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _liveRecovery?.dispose();
    onForegroundChanged = null;
    WidgetsBinding.instance.removeObserver(this);
    desktop?.dispose();
    reconciler.dispose();
    await dockUnread.dispose();
    await tray.dispose();
    _epoch++;
    _navigation++;
    _workspace?.removeListener(_changed);
    await _events?.cancel();
    await _linkSubscription?.cancel();
    notifications.removeListener(_notificationSettingsChanged);
    await background.bind(null, false);
    notifications.onTap = null;
    await notifications.bind(null);
  }
}
