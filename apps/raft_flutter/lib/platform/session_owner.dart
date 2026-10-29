import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:raft_client/raft_client.dart';

const sessionOwnerName = 'raft.native.session-owner.v1';

/// How long a foreground refresh waits for a guest to confirm that it has
/// stopped. Only credential rotation ever waits; rendering and cached reads
/// never do. A guest in a dead isolate never answers, so this also bounds the
/// cost of reclaiming a stale registration.
const guestSettleTimeout = Duration(seconds: 1);

/// How long a guest waits for an existing registration to answer a probe
/// before it is treated as stale and reclaimed.
const ownerProbeTimeout = Duration(milliseconds: 1500);

/// What a guest found when it looked for the session owner.
enum OwnerProbe { none, delegated, busy }

/// Process-wide ownership of the rotating session credentials across Flutter
/// engines. See docs/session-ownership.md.
///
/// The foreground (UI engine) is the owner: [claim] is synchronous, never
/// fails and never waits, and replaces whatever registration exists. Background
/// workers are guests (iOS only: Android runs no background worker, so there
/// is never a second engine to own the session there): they register only when
/// nobody else is registered,
/// delegate to a live foreground, are told to [onPreempt] the instant a
/// foreground claims the session, and must not write credentials after that.
class NativeSessionOwner {
  NativeSessionOwner({this.poll, this.onPreempt, bool? supported})
    : supported = supported ?? Platform.isIOS;
  final bool supported;

  /// Foreground: poll the inbox with the UI's own client for a worker.
  final Future<bool> Function()? poll;

  /// Guest: stop now. Close transports, fence credential writes and complete
  /// once no credential write of this guest can still land.
  final Future<void> Function()? onPreempt;
  ReceivePort? _port;
  bool _foreground = false;
  Future<void> _guestSettled = Future<void>.value();
  Future<bool>? _polling;
  Future<void>? _preempting;

  bool get claimed => _port != null && _foreground;

  /// Completes when every guest registered at [claim] time confirmed that it
  /// stopped (or did not answer within [guestSettleTimeout]). Never throws.
  /// Await it only before rotating credentials or writing a stored session.
  Future<void> get guestSettled => _guestSettled;

  /// Foreground: take the session now. Synchronous; a registered guest is
  /// preempted, a stale registration is replaced. Idempotent.
  Future<void> claim() {
    if (!supported || _port != null) return _guestSettled;
    final previous = <SendPort>[];
    ReceivePort? port;
    for (var attempt = 0; attempt < 4 && _port == null; attempt++) {
      final existing = IsolateNameServer.lookupPortByName(sessionOwnerName);
      if (existing != null) {
        previous.add(existing);
        IsolateNameServer.removePortNameMapping(sessionOwnerName);
      }
      port = ReceivePort();
      if (IsolateNameServer.registerPortWithName(
        port.sendPort,
        sessionOwnerName,
      )) {
        _port = port;
      } else {
        port.close();
        port = null;
      }
    }
    final mine = _port;
    if (mine == null) return _guestSettled;
    _foreground = true;
    mine.listen(_onForegroundMessage);
    final settled = <Future<void>>[];
    for (final target in previous) {
      final reply = ReceivePort();
      target.send(['preempt', reply.sendPort]);
      settled.add(
        reply.first
            .timeout(guestSettleTimeout, onTimeout: () => null)
            .whenComplete(reply.close)
            .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }
    return _guestSettled = settled.isEmpty
        ? Future<void>.value()
        : Future.wait(settled).then<void>((_) {});
  }

  void _onForegroundMessage(dynamic message) {
    if (message is! List || message.length != 2 || message[1] is! SendPort) {
      return;
    }
    final reply = message[1] as SendPort;
    switch (message[0]) {
      case 'ping':
        reply.send('foreground');
      case 'preempt':
        // A newer foreground took over; this one holds no guest writes.
        reply.send('settled');
      case 'poll':
        reply.send('accepted');
        if (poll == null) {
          reply.send(false);
          return;
        }
        unawaited(() async {
          try {
            reply.send(
              await (_polling ??= poll!().whenComplete(() => _polling = null)),
            );
          } catch (_) {
            reply.send(false);
          }
        }());
    }
  }

  /// Guest: ask the registered owner to poll for us. [OwnerProbe.none] means
  /// nobody (live) is registered, and any dead registration has been removed.
  /// A guest never waits for a foreground, and never takes the session from one.
  static Future<(OwnerProbe, bool)> probe({
    Duration timeout = ownerProbeTimeout,
    Duration pollTimeout = const Duration(seconds: 25),
  }) async {
    final existing = IsolateNameServer.lookupPortByName(sessionOwnerName);
    if (existing == null) return (OwnerProbe.none, false);
    final reply = ReceivePort();
    final messages = StreamIterator<dynamic>(reply);
    try {
      existing.send(['poll', reply.sendPort]);
      Object? first;
      if (await messages.moveNext().timeout(
        timeout,
        onTimeout: () => false,
      )) {
        first = messages.current;
      }
      if (first == null) {
        // Nobody answered: the registering isolate is gone (an OS-stopped
        // worker destroys its engine without running any cleanup).
        if (IsolateNameServer.lookupPortByName(sessionOwnerName) == existing) {
          IsolateNameServer.removePortNameMapping(sessionOwnerName);
        }
        return (OwnerProbe.none, false);
      }
      if (first == 'busy') return (OwnerProbe.busy, false);
      final more = await messages.moveNext().timeout(
        pollTimeout,
        onTimeout: () => false,
      );
      return (OwnerProbe.delegated, more && messages.current == true);
    } catch (_) {
      return (OwnerProbe.delegated, false);
    } finally {
      unawaited(messages.cancel());
      reply.close();
    }
  }

  /// Guest: register only if nobody is. Synchronous; false means someone else
  /// registered first (probe again).
  bool registerGuest() {
    if (!supported || _port != null) return _port != null && !_foreground;
    final port = ReceivePort();
    if (!IsolateNameServer.registerPortWithName(
      port.sendPort,
      sessionOwnerName,
    )) {
      port.close();
      return false;
    }
    _port = port;
    _foreground = false;
    port.listen((message) {
      if (message is! List || message.length != 2 || message[1] is! SendPort) {
        return;
      }
      final reply = message[1] as SendPort;
      switch (message[0]) {
        case 'ping':
          reply.send('guest');
        case 'poll':
          reply.send('busy');
        case 'preempt':
          unawaited(() async {
            try {
              await (_preempting ??= onPreempt?.call() ?? Future<void>.value());
            } catch (_) {}
            // The registration now belongs to the new owner; keep it.
            reply.send('settled');
          }());
      }
    });
    return true;
  }

  /// Drops this isolate's registration (only if it is still the registered
  /// one) and closes the port. Never waits.
  void release() {
    final port = _port;
    if (port == null) return;
    if (IsolateNameServer.lookupPortByName(sessionOwnerName) ==
        port.sendPort) {
      IsolateNameServer.removePortNameMapping(sessionOwnerName);
    }
    port.close();
    _port = null;
    _foreground = false;
  }
}

/// A guest's credential store. Once the guest is preempted, or when the stored
/// session is no longer the one the guest last read or wrote, a write is
/// dropped: a guest can never overwrite credentials the foreground has since
/// rotated, replaced or cleared.
class GuestSessionStore implements SessionStore {
  GuestSessionStore(this.delegate);
  final SessionStore delegate;
  bool _preempted = false;
  Session? _known;
  bool _haveKnown = false;
  final _writes = <Future<void>>{};
  bool get preempted => _preempted;

  /// Fence further writes; completes when in-flight writes have finished.
  Future<void> preempt() {
    _preempted = true;
    return Future.wait(_writes.toList()).then<void>((_) {}, onError: (Object _) {});
  }

  @override
  Future<Session?> read(String origin) async {
    final session = await delegate.read(origin);
    _known = session;
    _haveKnown = true;
    return session;
  }

  @override
  Future<void> write(String origin, Session? session) {
    if (_preempted) return Future<void>.value();
    final write = () async {
      if (_haveKnown) {
        final stored = await delegate.read(origin);
        if (_preempted || !_sameCredentials(stored, _known)) return;
      }
      await delegate.write(origin, session);
      _known = session;
    }();
    _writes.add(write);
    return write.whenComplete(() => _writes.remove(write));
  }

  static bool _sameCredentials(Session? a, Session? b) =>
      a == null || b == null
      ? a == b
      : a.refreshToken == b.refreshToken && a.accessToken == b.accessToken;
}
