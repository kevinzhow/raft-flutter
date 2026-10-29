import 'dart:async';

import 'package:dbus/dbus.dart';

/// The `ActivationToken(id, token)` signal of org.freedesktop.Notifications
/// (spec 1.3). A desktop sends it just before `ActionInvoked` when a banner is
/// clicked; the token is what lets a Wayland compositor (and KWin's focus
/// stealing prevention) raise and focus the window that handles the click. The
/// notification plugin does not surface it, so it is read here.
class LinuxActivationTokens {
  LinuxActivationTokens({
    Stream<String>? tokens,
    DateTime Function()? clock,
    this.lifetime = const Duration(seconds: 10),
  }) : _clock = clock ?? DateTime.now,
       _injected = tokens;

  final Duration lifetime;
  final DateTime Function() _clock;
  final Stream<String>? _injected;
  DBusClient? _client;
  StreamSubscription<Object?>? _subscription;
  String? _token;
  DateTime? _at;

  /// Starts listening on the session bus; failures only mean no token.
  void start() {
    if (_subscription != null) return;
    try {
      if (_injected != null) {
        _subscription = _injected.listen(_remember);
        return;
      }
      final client = _client = DBusClient.session();
      _subscription =
          DBusSignalStream(
            client,
            sender: 'org.freedesktop.Notifications',
            interface: 'org.freedesktop.Notifications',
            name: 'ActivationToken',
            path: DBusObjectPath('/org/freedesktop/Notifications'),
          ).listen((signal) {
            if (signal.values.length >= 2 && signal.values[1] is DBusString) {
              _remember(signal.values[1].asString());
            }
          }, onError: (Object _) {});
    } catch (_) {
      // No session bus: clicks still work, only without a focus token.
    }
  }

  Completer<void>? _arrival;
  void _remember(String token) {
    if (token.isEmpty || token.length > 1024) return;
    _token = token;
    _at = _clock();
    _arrival?.complete();
  }

  /// The token of the click being handled, once: null when the desktop sent
  /// none or it is too old to belong to this click. The signal and the click
  /// travel on different connections, so a click can be seen first; [wait]
  /// covers that gap.
  Future<String?> take({
    Duration wait = const Duration(milliseconds: 150),
  }) async {
    if (_token == null && _subscription != null && wait > Duration.zero) {
      final arrival = _arrival = Completer<void>();
      await arrival.future.timeout(wait, onTimeout: () {});
      _arrival = null;
    }
    final token = _token, at = _at;
    _token = null;
    _at = null;
    if (token == null || at == null) return null;
    return _clock().difference(at) <= lifetime ? token : null;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    final client = _client;
    _client = null;
    if (client != null) {
      try {
        await client.close();
      } catch (_) {}
    }
  }
}
