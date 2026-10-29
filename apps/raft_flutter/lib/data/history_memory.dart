import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart' show RaftIdleTimer;

import 'message_history.dart';

/// Size is serialized UTF-8 across distinct retained row versions, not RSS.
typedef HistoryBodyProof = ({String id, int bytes, bool durable});
typedef HistoryMemoryProof = Future<List<HistoryBodyProof>> Function(
  MessageHistoryScope scope,
  Map<String, List<Map<String, dynamic>>> versions,
);

class HistoryMemoryWindow {
  HistoryMemoryWindow({
    required this.scope,
    required this.versions,
    required this.active,
    required this.current,
    required this.release,
    this.paused = false,
    this.anchor,
    this.protectedIds = const {},
  });
  final MessageHistoryScope scope;
  final Map<String, List<Map<String, dynamic>>> versions;
  final bool active, paused;
  final String? anchor;
  final Set<String> protectedIds;
  final bool Function() current;
  final Set<String> Function(Set<String> ids) release;
}

class HistoryMemoryPort {
  HistoryMemoryPort({
    required this.changes,
    required this.stamp,
    required this.capture,
    this.selected,
  });
  final Listenable changes;
  final Object Function() stamp;
  final Future<Iterable<HistoryMemoryWindow>> Function() capture;
  final Iterable<String> Function()? selected;
}

/// One budget for every receiver sharing a device cache. The durable store
/// proves current body versions before this policy asks an owner to release.
class HistoryMemoryPool {
  HistoryMemoryPool(
    this.prove, {
    Zone? backgroundZone,
    this.hold,
    this.releaseHold,
    this.activeLimit = 500,
    this.idleLimit = 20,
    this.idleRows = 50,
    this.byteLimit = 32 << 20,
  }) : _zone = backgroundZone ?? Zone.current;
  final HistoryMemoryProof prove;
  final void Function(Iterable<HistoryMemoryWindow>)? hold;
  final VoidCallback? releaseHold;
  final int activeLimit, idleLimit, idleRows, byteLimit;
  final _ports = <Object, HistoryMemoryPort>{};
  final _listeners = <Object, VoidCallback>{};
  final _stamps = <Object, Object>{};
  final _visits = <(Object, String), int>{};
  final _older = <(Object, String), bool>{};
  final _active = <(Object, String)>{};
  final _samples = <Object, RaftIdleTimer>{};
  final Zone _zone;
  final _timer = RaftIdleTimer(yieldToAnimation: false);
  int _clock = 0;
  bool _running = false, _closed = false, _dirty = false;
  Future<void>? _maintenance;
  int retainedBytes = 0, retainedRows = 0, protectedBytes = 0;

  void register(Object owner, HistoryMemoryPort port) {
    unregister(owner);
    _ports[owner] = port;
    void listener() {
      final next = port.stamp();
      if (_stamps[owner] == next) return;
      _stamps[owner] = next;
      if (port.selected case final selected?) {
        final current = selected().map((id) => (owner, id)).toSet();
        for (final key in current) {
          if (!_active.contains(key)) _visits[key] = ++_clock;
        }
        _active.removeWhere((key) => identical(key.$1, owner));
        _active.addAll(current);
      }
      changed();
    }

    _listeners[owner] = listener;
    port.changes.addListener(listener);
    listener();
  }

  void unregister(Object owner) {
    final port = _ports.remove(owner), listener = _listeners.remove(owner);
    if (port != null && listener != null) port.changes.removeListener(listener);
    _stamps.remove(owner);
    _visits.removeWhere((key, _) => identical(key.$1, owner));
    _older.removeWhere((key, _) => identical(key.$1, owner));
    _active.removeWhere((key) => identical(key.$1, owner));
    if (_ports.isEmpty) _timer.cancel();
  }

  void direction(Object owner, String channel, {required bool older}) {
    if (_older[(owner, channel)] == older) return;
    _older[(owner, channel)] = older;
    changed();
  }

  /// Samples geometry at most five times a second during scrolling. No idle
  /// polling or repeated work remains after the requested sample completes.
  void samplePosition(Object owner, VoidCallback sample) {
    if (_closed || _samples.containsKey(owner)) return;
    final timer = _samples[owner] = RaftIdleTimer(yieldToAnimation: false);
    _zone.run(
      () => timer.start(const Duration(milliseconds: 200), () {
        _samples.remove(owner);
        sample();
        // Position alone changes no retained body or byte budget. Data changes
        // and direction changes already request maintenance when it is needed.
        // An in-flight proof may have captured the previous anchor. Retry that
        // existing work once rather than leaving an over-budget window stale.
        if (_running) _dirty = true;
      }),
    );
  }

  void cancelSample(Object owner) => _samples.remove(owner)?.cancel();

  void changed() {
    if (_closed || _ports.isEmpty) return;
    _dirty = true;
    if (!_running && !_timer.isActive) {
      _zone.run(
        () => _timer.start(const Duration(milliseconds: 500), () {
          unawaited(maintain().catchError((Object _) {}));
        }),
      );
    }
  }

  Future<void> maintain() {
    final running = _maintenance;
    if (running != null) {
      // A caller that joins an older proof also waits for changes that made
      // that capture stale. Returning the old future can leave every new body
      // retained until the next timer despite the caller awaiting cleanup.
      return running.then((_) async {
        if (_dirty && !_closed) await maintain();
      });
    }
    _timer.cancel();
    return _maintenance = _maintain().whenComplete(() => _maintenance = null);
  }

  Future<void> _maintain() async {
    if (_running || _closed) return;
    _running = true;
    _dirty = false;
    try {
      final windows = <(Object, HistoryMemoryWindow)>[];
      for (final entry in _ports.entries.toList()) {
        for (final window in await entry.value.capture()) {
          final key = (entry.key, window.scope.channel);
          if (window.active && entry.value.selected == null) {
            if (!_active.contains(key)) _visits[key] = ++_clock;
            _active.add(key);
          }
          windows.add((entry.key, window));
        }
      }
      hold?.call(windows.map((entry) => entry.$2));
      final idle = windows.where((entry) => !entry.$2.active).toList()
        ..sort(
          (a, b) => (_visits[(b.$1, b.$2.scope.channel)] ?? 0).compareTo(
            _visits[(a.$1, a.$2.scope.channel)] ?? 0,
          ),
        );
      final keptIdle = idle.take(idleLimit).map((e) => e.$2).toSet();
      final candidates = <_MemoryCandidate>[];
      retainedBytes = 0;
      retainedRows = 0;
      protectedBytes = 0;
      for (final (owner, window) in windows) {
        if (_closed || !_ports.containsKey(owner) || !window.current()) {
          continue;
        }
        final rows = window.versions.entries.toList()
          ..sort((a, b) {
            final x = BigInt.tryParse('${a.value.first['seq']}') ?? BigInt.zero;
            final y = BigInt.tryParse('${b.value.first['seq']}') ?? BigInt.zero;
            final order = x.compareTo(y);
            return order != 0 ? order : a.key.compareTo(b.key);
          });
        final limit = window.active
            ? activeLimit
            : keptIdle.contains(window)
            ? idleRows
            : 0;
        final anchor = rows.indexWhere((e) => e.key == window.anchor);
        final start = anchor >= 0
            ? (anchor - limit ~/ 2).clamp(
                0,
                (rows.length - limit).clamp(0, rows.length),
              )
            : _older[(owner, window.scope.channel)] == true
            ? 0
            : (rows.length - limit).clamp(0, rows.length);
        final preferred = rows
            .skip(start)
            .take(limit)
            .map((e) => e.key)
            .toSet();
        for (var offset = 0; offset < rows.length; offset += 200) {
          if (_closed || !_ports.containsKey(owner) || !window.current()) break;
          final batch = Map.fromEntries(rows.skip(offset).take(200));
          final proof = await prove(window.scope, batch);
          if (_closed || !_ports.containsKey(owner) || !window.current()) break;
          for (final item in proof) {
            retainedBytes += item.bytes;
            retainedRows++;
            final protected =
                window.paused ||
                window.protectedIds.contains(item.id) ||
                item.id == window.anchor ||
                !item.durable ||
                window.active &&
                    item.id ==
                        (anchor >= 0
                            ? rows[anchor].key
                            : _older[(owner, window.scope.channel)] == true
                            ? rows.first.key
                            : rows.last.key);
            if (protected) protectedBytes += item.bytes;
            candidates.add(
              _MemoryCandidate(
                owner,
                window,
                item,
                protected,
                preferred.contains(item.id),
                anchor < 0 ? rows.length - offset : (offset - anchor).abs(),
              ),
            );
          }
          // No ordered database operation or worker is held across this yield.
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      }
      // First honor conversation/row limits, then release distant idle bodies
      // before active ones to meet the shared serialized-byte target.
      candidates.sort((a, b) {
        final preferred = (a.preferred ? 1 : 0).compareTo(b.preferred ? 1 : 0);
        if (preferred != 0) return preferred;
        final active = (a.window.active ? 1 : 0).compareTo(
          b.window.active ? 1 : 0,
        );
        return active != 0 ? active : b.distance.compareTo(a.distance);
      });
      final release = <HistoryMemoryWindow, Set<String>>{};
      final sizes = <(HistoryMemoryWindow, String), int>{};
      var plannedBytes = retainedBytes;
      for (final item in candidates) {
        if (item.protected || item.preferred && plannedBytes <= byteLimit) {
          continue;
        }
        if (!_ports.containsKey(item.owner) || !item.window.current()) continue;
        release.putIfAbsent(item.window, () => {}).add(item.proof.id);
        sizes[(item.window, item.proof.id)] = item.proof.bytes;
        plannedBytes -= item.proof.bytes;
      }
      for (final entry in release.entries) {
        if (!entry.key.current()) continue;
        for (final id in entry.key.release(entry.value)) {
          retainedBytes -= sizes[(entry.key, id)] ?? 0;
          retainedRows--;
        }
      }
    } finally {
      releaseHold?.call();
      _running = false;
      if (_dirty && !_closed) changed();
    }
  }

  void close() {
    _closed = true;
    _timer.cancel();
    for (final timer in _samples.values) {
      timer.cancel();
    }
    _samples.clear();
    for (final owner in _ports.keys.toList()) {
      unregister(owner);
    }
  }
}

class _MemoryCandidate {
  _MemoryCandidate(
    this.owner,
    this.window,
    this.proof,
    this.protected,
    this.preferred,
    this.distance,
  );
  final Object owner;
  final HistoryMemoryWindow window;
  final HistoryBodyProof proof;
  final bool protected, preferred;
  final int distance;
}
