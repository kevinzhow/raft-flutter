import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:app_links/app_links.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'content_target.dart';
import 'content_links.dart';
import 'native_notifications.dart';
import 'background_inbox.dart';
import 'background_notifications.dart';

/// Binds platform links and notification clicks to the currently signed-in
/// principal. Every navigation rechecks server membership and visible context.
class NativeContentCoordinator {
  NativeContentCoordinator({
    NativeNotificationService? notifications,
    this.links,
  }) : notifications = notifications ?? NativeNotificationService();
  final NativeNotificationService notifications;
  final Stream<Uri>? links;
  final background = BackgroundNotificationScheduler();
  WorkspaceController? _workspace;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<RaftEvent>? _events;
  String? _scope;
  int _epoch = 0, _navigation = 0;
  bool _closed = false;
  bool _workspaceBindingResolved = false;
  Uri? _pendingLink;
  String? _pendingTap;
  final Set<String> _delivered = {};
  final Set<String> _inFlight = {};

  Future<void> init({List<String> initialArguments = const []}) async {
    notifications.onTap = _tap;
    notifications.addListener(_notificationSettingsChanged);
    unawaited(background.initialize().catchError((Object _) {}));
    _linkSubscription = (links ?? AppLinks().uriLinkStream).listen(
      receiveLink,
      onError: (_) {},
    );
    for (final argument in initialArguments) {
      final uri = Uri.tryParse(argument);
      if (uri != null) receiveLink(uri);
    }
    await notifications.initialize();
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
    workspace?.addListener(_changed);
    _events = workspace?.client.events.listen(_event);
    _changed();
    final link = _pendingLink, tap = _pendingTap;
    _pendingLink = null;
    _pendingTap = null;
    if (workspace != null) {
      if (link != null) receiveLink(link);
      if (tap != null) _tap(tap);
    }
  }

  String? get currentScope {
    final c = _workspace?.client;
    if (c?.user == null || c?.serverId == null) return null;
    return '${c!.origin}\n${c.user!.id}\n${c.serverId}';
  }

  void _changed() {
    final scope = currentScope;
    if (_scope == scope) return;
    _scope = scope;
    _epoch++;
    _navigation++;
    _delivered.clear();
    _inFlight.clear();
    unawaited(background.bind(null, false).catchError((Object _) {}));
    unawaited(notifications.bind(scope));
  }

  void _notificationSettingsChanged() {
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
                'Background inbox checks could not be scheduled. Open Raft to retry.',
              );
            }
          }),
    );
  }

  Future<bool> pollBackground() async {
    final w = _workspace, scope = _scope, epoch = _epoch;
    if (w == null || scope == null || !notifications.enabled) return true;
    bool valid() =>
        !_closed && _workspace == w && _scope == scope && _epoch == epoch;
    return BackgroundInboxPoller(
      client: w.client,
      store: background.store,
      authorize: (target, _) async {
        final server = await authorize(w, target, valid);
        if (server.flag('serverPushMuted')) {
          throw const RaftApiException('Notifications are muted.');
        }
      },
      suppress: (target) =>
          w.foreground &&
          w.section == 'chat' &&
          (w.channel?.id == target.channelId ||
              w.threadChannelId == target.threadId),
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
    final w = _workspace;
    if (w == null || w.client.user == null) {
      // Only a bounded content URI can wait for normal account restoration.
      if (uri.scheme == 'raft' &&
          uri.host == 'v1' &&
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

  void _tap(String payload) {
    if (_closed) return;
    if (Platform.isLinux) {
      unawaited(
        const MethodChannel('app.raft/window')
            .invokeMethod<void>('present')
            .catchError((Object _) {}),
      );
    }
    if (payload == 'raft-notification-test') return;
    if (_workspace == null) {
      if (payload.length <= 4096) _pendingTap = payload;
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
        unawaited(navigate(target));
      }
    } catch (_) {
      /* Untrusted platform payloads cannot navigate. */
    }
  }

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
    if (w.foreground &&
        w.section == 'chat' &&
        (w.channel?.id == target.channelId ||
            w.threadChannelId == target.threadId)) {
      return;
    }
    final key = '${target.serverId}:${target.messageId}';
    if (_delivered.contains(key) || _inFlight.contains(key)) return;
    try {
      if (mobileBackgroundSupported &&
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
      // Socket room delivery is an eligibility decision, not lasting authority.
      final memberServer = await authorize(
        w,
        target,
        () => !_closed && _workspace == w && _scope == scope && epoch == _epoch,
      );
      if (_closed || _workspace != w || _scope != scope || epoch != _epoch) {
        return;
      }
      if (memberServer.flag('serverPushMuted') ||
          w.foreground &&
              w.section == 'chat' &&
              (w.channel?.id == target.channelId ||
                  w.threadChannelId == target.threadId)) {
        return;
      }
      _delivered.add(key);
      if (_delivered.length > 1000) _delivered.remove(_delivered.first);
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
      );
      if (mobileBackgroundSupported &&
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

  Future<void> navigate(ContentTarget target) async {
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
    try {
      final server = await authorize(w, target, valid);
      if (!valid()) return;
      // Content links never switch the signed-in account or coordinator origin.
      // Cross-server links require an explicit server selection in the app first.
      if (server.id != w.client.serverId) {
        w.setError('Select the linked workspace before opening this message.');
        return;
      }
      if (target.parentMessageId != null && target.messageId == null) {
        await w.jumpToMessage(target.channelId, target.parentMessageId);
        if (!valid()) return;
        final parent = w.messages
            .where((m) => m.id == target.parentMessageId)
            .firstOrNull;
        if (parent != null) await w.openThread(parent);
      } else {
        await w.jumpToMessage(target.channelId, target.messageId);
      }
    } catch (_) {
      if (valid()) {
        w.setError(
          'This link is unavailable for the current account or workspace.',
        );
      }
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
      throw const RaftApiException('Unavailable workspace.');
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
    return server;
  }

  Future<void> dispose() async {
    _closed = true;
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
