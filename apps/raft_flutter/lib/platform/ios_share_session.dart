import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';

/// Projects only the selected account's access credential to its own signed
/// extensions. Refresh credentials remain exclusively with NativeSessionOwner.
class IOSShareSession {
  IOSShareSession({MethodChannel? channel, bool? supported})
    : channel = channel ?? const MethodChannel('app.raft/sharing'),
      supported = supported ?? Platform.isIOS;
  final MethodChannel channel;
  final bool supported;
  RaftClient? _client;
  StreamSubscription<RaftEvent>? _events;
  Future<void> _tail = Future.value();
  int _revision = 0;
  bool _closed = false;
  Object? _published;
  String? _principal;
  Future<void> get settled => _tail;

  void bind(RaftClient? client) {
    if (!supported || _closed) return;
    if (identical(client, _client)) return;
    _detach();
    _client = client;
    _principal = client?.user?.id;
    _published = null;
    _enqueue(null);
    if (client == null) return;
    _events = client.events.listen((event) {
      if (event.name == 'session:ended') bind(null);
      if (event.name == 'session:credentials-updated' ||
          event.name == 'session:recovered') {
        unawaited(publish());
      }
    });
    unawaited(publish());
  }

  Future<void> publish() async {
    final client = _client;
    if (_closed || !supported || client == null) return;
    final principal = client.user?.id;
    if (_principal != principal) {
      _principal = principal;
      _published = null;
      _enqueue(null);
    }
    final revision = _revision;
    bool current() =>
        !_closed &&
        identical(client, _client) &&
        client.signedIn &&
        principal == client.user?.id &&
        revision == _revision;
    if (principal == null || !client.signedIn) {
      _enqueue(null);
      return;
    }
    try {
      await client.sessionValidated;
      if (!current()) return;
      if (client.restoredOffline) {
        _enqueue(null);
        return;
      }
      final session = await client.sessionStore.read(client.origin);
      if (!current()) return;
      if (session?.cachedUser?['id'] != principal) {
        _enqueue(null);
        return;
      }
      final token = session!.accessToken;
      final origin = Uri.tryParse(client.origin);
      if (origin == null ||
          origin.scheme != 'https' ||
          origin.host.isEmpty ||
          origin.userInfo.isNotEmpty ||
          origin.hasQuery ||
          origin.hasFragment ||
          (origin.path.isNotEmpty && origin.path != '/')) {
        _enqueue(null);
        return;
      }
      final signature = (client.origin, principal, token, client.serverId);
      if (_published == signature) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      var expiry = now + const Duration(hours: 24).inMilliseconds;
      try {
        final claims = jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(token.split('.')[1])),
          ),
        );
        final exp = claims is Map ? claims['exp'] : null;
        if (exp is num && exp.isFinite) {
          expiry = (exp * 1000).toInt().clamp(now, expiry);
        }
      } catch (_) {
        expiry = now + const Duration(hours: 1).inMilliseconds;
      }
      if (!current()) return;
      if (expiry <= now) {
        _enqueue(null);
        return;
      }
      _enqueue({
        'origin': client.origin,
        'principal': principal,
        'name': client.user?.name ?? '',
        'accessToken': token,
        'expiresAt': expiry,
        if (client.serverId != null) 'preferredServerId': client.serverId!,
      }, signature: signature);
    } catch (_) {
      // Native sharing is optional; it must not interrupt auth or requests.
    }
  }

  void _enqueue(Map<String, Object>? record, {Object? signature}) {
    final ticket = ++_revision;
    _tail = _tail.catchError((Object _) {}).then((_) async {
      if (ticket != _revision) return;
      try {
        await channel.invokeMethod<void>('updateShareSession', record);
        if (ticket == _revision) _published = signature;
      } catch (_) {}
    });
  }

  void _detach() {
    unawaited(_events?.cancel());
    _events = null;
    _client = null;
  }

  Future<void> dispose() async {
    if (_closed) return;
    _detach();
    if (supported) _enqueue(null);
    _closed = true;
    await _tail;
  }
}
