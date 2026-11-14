// Source: packages/web/src/notifications/presenceReport.ts at
// v1.24.0-source.1 (1d689caf); the mobile flavour follows botiverse/mobile
// SocketIoRealtimeClient.emitPresenceActivity (foreground = active,
// idleSeconds 0).
//
// `presence:activity` (docs/contracts/notifications.md §1.3, §5) tells the
// server whether the user is using THIS device, so a phone stays quiet while
// they are at a computer ("Phone alerts"):
//   - desktop: input in the Raft window (pointer, key, wheel) within the
//     last 3 minutes. A Flutter desktop cannot see the rest of the system, so
//     a person working in another app counts as away 3 minutes after their
//     last input here (Web's documented approximation for a browser tab; it
//     only ever lets a phone alert through). `locked` is always false;
//     `ackAlerts` while the server notification consumer runs here.
//   - mobile: the app in the foreground.
// Cadence (Web `createPresenceReporter`): a change of active is sent at once,
// including the moment the last input turns 3 minutes old; input that moved
// on by 30 s since the last report too; while connected the state is re-sent
// every 60 s; on every (re)connect it is sent again. Nothing is queued while
// disconnected.
import 'dart:async';

import 'package:raft_client/raft_client.dart';

const presenceActivityEvent = 'presence:activity';
const activeInputWindow = Duration(minutes: 3);
const presenceHeartbeat = Duration(seconds: 60);
const presenceInputReportStep = Duration(seconds: 30);

abstract interface class PresenceTimers {
  Object start(Duration after, void Function() callback);
  void cancel(Object handle);
}

class _RealTimers implements PresenceTimers {
  const _RealTimers();
  @override
  Object start(Duration after, void Function() callback) =>
      Timer(after.isNegative ? Duration.zero : after, callback);
  @override
  void cancel(Object handle) => (handle as Timer).cancel();
}

class PresenceReporter {
  PresenceReporter({
    required this.mobile,
    PresenceTimers? timers,
    DateTime Function()? now,
  }) : timers = timers ?? const _RealTimers(),
       now = now ?? DateTime.now;

  /// Mobile: foreground is active; no input tracking.
  final bool mobile;
  final PresenceTimers timers;
  final DateTime Function() now;

  RaftClient? _client;
  StreamSubscription<RaftEvent>? _events;
  bool _attended = false, _ackAlerts = false, _disposed = false;
  DateTime? _lastInputAt;
  String? _reported;
  DateTime? _reportedInputAt, _sentAt;
  Object? _heartbeat, _crossing;

  /// The last payload sent (tests and diagnostics).
  Map<String, Object?>? lastSent;

  void bind(RaftClient? client) {
    if (identical(client, _client)) return;
    unawaited(_events?.cancel());
    _stopHeartbeat();
    _reported = null;
    _sentAt = null;
    _client = client;
    _events = client?.events.listen((event) {
      if (event.name == 'connected' || event.name == 'disconnected') {
        _reported = null;
        _evaluate();
      }
    });
    if (client?.connected == true) _evaluate();
  }

  /// The window / app is in front of the user. On a desktop, coming to the
  /// front is itself an interaction.
  void setAttended(bool attended) {
    if (attended && !_attended && !mobile) _lastInputAt = now();
    _attended = attended;
    _evaluate();
  }

  /// A press, a key, a wheel turn in the window (desktop).
  void input() {
    if (mobile) return;
    _lastInputAt = now();
    _evaluate();
  }

  /// The server notification consumer runs here (desktop).
  void setAckAlerts(bool value) {
    if (value == _ackAlerts) return;
    _ackAlerts = value;
    _evaluate();
  }

  Duration? get _idle {
    final last = _lastInputAt;
    if (mobile) return _attended ? Duration.zero : null;
    if (last == null) return null;
    final idle = now().difference(last);
    return idle.isNegative ? Duration.zero : idle;
  }

  bool get active {
    if (mobile) return _attended;
    final idle = _idle;
    return idle != null && idle < activeInputWindow;
  }

  String get _stateKey => '$active:$_ackAlerts';

  void _stopHeartbeat() {
    final h = _heartbeat;
    if (h != null) timers.cancel(h);
    _heartbeat = null;
  }

  void _stopCrossing() {
    final c = _crossing;
    if (c != null) timers.cancel(c);
    _crossing = null;
  }

  void _send() {
    _stopHeartbeat();
    final client = _client;
    if (_disposed || client == null) return;
    final idle = _idle;
    final payload = mobile
        ? <String, Object?>{'active': active, 'idleSeconds': active ? 0 : null}
        : <String, Object?>{
            'active': active,
            // Rounded up: never claim input more recent than it was.
            'idleSeconds': idle == null
                ? null
                : (idle.inMilliseconds / 1000).ceil(),
            'locked': false,
            'attended': _attended,
            if (_ackAlerts) 'ackAlerts': true,
          };
    if (!client.emitSocketEvent(presenceActivityEvent, payload)) {
      // Never queued; the next connect re-reports.
      _reported = null;
      _sentAt = null;
      return;
    }
    lastSent = payload;
    _reported = _stateKey;
    _reportedInputAt = _lastInputAt;
    _sentAt = now();
    // A phone in the background has nothing to keep fresh (botiverse/mobile).
    if (mobile && !active) return;
    _heartbeat = timers.start(presenceHeartbeat, () {
      _heartbeat = null;
      _send();
    });
  }

  void _evaluate() {
    if (_disposed) return;
    // Nothing is measured for a socket that is not there: the next connect
    // evaluates again (and arms the timers).
    if (_client?.connected != true) {
      _stopCrossing();
      _stopHeartbeat();
      _reported = null;
      _sentAt = null;
      return;
    }
    final isActive = active;
    final last = _lastInputAt;
    if (!isActive || mobile) {
      _stopCrossing();
    } else if (_crossing == null && last != null) {
      // Fires as the last input turns 3 minutes old.
      _crossing = timers.start(
        last.add(activeInputWindow).difference(now()),
        () {
          _crossing = null;
          _evaluate();
        },
      );
    }
    final reportedInput = _reportedInputAt, sentAt = _sentAt;
    if (_reported != _stateKey) {
      _send();
    } else if (!mobile &&
        last != null &&
        reportedInput != null &&
        last.difference(reportedInput) >= presenceInputReportStep) {
      _send();
    } else if (sentAt != null &&
        now().difference(sentAt) >= presenceHeartbeat) {
      _send();
    }
  }

  void dispose() {
    _disposed = true;
    _stopHeartbeat();
    _stopCrossing();
    unawaited(_events?.cancel());
    _client = null;
  }
}
