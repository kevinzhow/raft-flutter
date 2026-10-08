/// Behavioral port of raft-source 26f77ef / packages/sync-core/src/core.ts.
/// Pure: transports execute the declarative request list outside this reducer.
library;

import 'dart:collection';

enum SyncDensity { contiguous, sparse }

class SyncDomain {
  const SyncDomain({
    required this.name,
    required this.density,
    required this.initialState,
    required this.fold,
    required this.fromSnapshot,
    this.eventFingerprint,
    this.acceptSameWatermarkSnapshot,
  });
  final String name;
  final SyncDensity density;
  final dynamic Function() initialState;
  final dynamic Function(
    dynamic state,
    dynamic event,
    String scopeId,
    BigInt seq,
  )
  fold;
  final dynamic Function(SyncSnapshot snapshot) fromSnapshot;
  final String Function(dynamic event)? eventFingerprint;
  final bool Function(dynamic current, SyncSnapshot snapshot)?
  acceptSameWatermarkSnapshot;
}

class SyncFrame {
  const SyncFrame({
    required this.scopeId,
    required this.seq,
    required this.event,
    this.epoch,
  });
  final String scopeId;
  final BigInt seq;
  final String? epoch;
  final dynamic event;
}

class SyncSnapshot {
  const SyncSnapshot({
    required this.scopeId,
    required this.watermark,
    required this.state,
    this.epoch,
  });
  final String scopeId;
  final BigInt watermark;
  final String? epoch;
  final dynamic state;
}

class SyncDifference {
  const SyncDifference({
    required this.scopeId,
    required this.fromSeq,
    required this.toSeq,
    required this.events,
    this.epoch,
    this.partial = false,
    this.snapshotRequired = false,
  });
  final String scopeId;
  final BigInt fromSeq, toSeq;
  final String? epoch;
  final List<SyncFrame> events;
  final bool partial, snapshotRequired;
}

class _Entry {
  _Entry(this.state);
  BigInt? appliedSeq;
  String? acceptedFingerprint, epoch;
  bool repairPending = false;
  dynamic state;
}

class SyncCore {
  SyncCore({required List<SyncDomain> domains, this.violationCapacity = 256})
    : _domains = {for (final d in domains) d.name: d} {
    if (violationCapacity <= 0) throw RangeError.value(violationCapacity);
  }
  final Map<String, SyncDomain> _domains;
  final Map<String, Map<String, _Entry>> _scopes = {};
  final _pending = LinkedHashMap<String, Map<String, dynamic>>();
  final List<Map<String, dynamic>> _violations = [];
  final int violationCapacity;
  int _nextViolation = 0;
  SyncDomain _domain(String name) =>
      _domains[name] ??
      (throw ArgumentError('Unregistered sync domain: $name'));
  _Entry _entry(SyncDomain d, String scope) => (_scopes[d.name] ??= {})
      .putIfAbsent(scope, () => _Entry(d.initialState()));
  Map<String, dynamic> _out(
    String kind,
    String scope, {
    BigInt? seq,
    BigInt? from,
    BigInt? to,
    String? violation,
  }) => {
    'kind': kind,
    'scopeId': scope,
    if (seq != null) 'seq': seq.toString(),
    if (from != null) 'fromSeq': from.toString(),
    if (to != null) 'toSeq': to.toString(),
    if (violation != null) 'violation': violation,
  };
  void _violation(
    String kind,
    String domain,
    String scope, {
    BigInt? seq,
    String? epoch,
    bool includeEpoch = true,
  }) {
    _violations.add({
      'index': _nextViolation++,
      'kind': kind,
      'domain': domain,
      'scopeId': scope,
      if (seq != null) 'seq': seq.toString(),
      if (includeEpoch) 'epoch': epoch,
    });
    if (_violations.length > violationCapacity) _violations.removeAt(0);
  }

  void _snapshot(String domain, String scope, String reason) =>
      _pending['snapshot:$domain:$scope'] = {
        'kind': 'snapshot',
        'domain': domain,
        'scopeId': scope,
        'reason': reason,
      };
  void _difference(String domain, String scope, BigInt seq, String? epoch) =>
      _pending['difference:$domain:$scope'] = {
        'kind': 'difference',
        'domain': domain,
        'scopeId': scope,
        'sinceSeq': seq.toString(),
        'epoch': epoch,
      };
  void _clear(String domain, String scope) {
    _pending.remove('snapshot:$domain:$scope');
    _pending.remove('difference:$domain:$scope');
  }

  bool _mismatch(_Entry e, String? epoch) =>
      e.epoch != null && epoch != null && e.epoch != epoch;
  Map<String, dynamic> ingestFrame(String name, SyncFrame frame) {
    final d = _domain(name),
        e = _entry(_domain(name), frame.scopeId),
        scope = frame.scopeId;
    if (_mismatch(e, frame.epoch)) {
      _violation(
        'cross_epoch_arrival',
        name,
        scope,
        seq: frame.seq,
        epoch: frame.epoch,
      );
      _snapshot(name, scope, 'epoch_mismatch');
      e.repairPending = true;
      return _out('epoch_rebaseline_requested', scope);
    }
    if (e.appliedSeq == null) {
      if (d.density == SyncDensity.contiguous) {
        _snapshot(name, scope, 'initial');
        e.repairPending = true;
        return _out(
          'gap_repair_requested',
          scope,
          from: BigInt.zero,
          to: frame.seq,
        );
      }
      e.state = d.fold(e.state, frame.event, scope, frame.seq);
      e.appliedSeq = frame.seq;
      e.acceptedFingerprint = d.eventFingerprint?.call(frame.event);
      e.epoch ??= frame.epoch;
      return _out('max_advanced', scope, seq: frame.seq);
    }
    if (frame.seq < e.appliedSeq!) {
      if (d.eventFingerprint != null)
        _violation(
          'version_regression',
          name,
          scope,
          seq: frame.seq,
          epoch: frame.epoch,
        );
      return _out('duplicate_dropped', scope, seq: frame.seq);
    }
    if (frame.seq == e.appliedSeq!) {
      if (d.eventFingerprint == null ||
          e.acceptedFingerprint == d.eventFingerprint!(frame.event))
        return _out('duplicate_dropped', scope, seq: frame.seq);
      _violation(
        'producer_version_conflict',
        name,
        scope,
        seq: frame.seq,
        epoch: frame.epoch,
      );
      _snapshot(
        name,
        scope,
        d.density == SyncDensity.sparse ? 'sparse_repull' : 'snapshot_required',
      );
      e.repairPending = true;
      return _out('violation', scope, violation: 'producer_version_conflict');
    }
    if (d.density == SyncDensity.sparse ||
        frame.seq == e.appliedSeq! + BigInt.one) {
      e.state = d.fold(e.state, frame.event, scope, frame.seq);
      e.appliedSeq = frame.seq;
      e.acceptedFingerprint = d.eventFingerprint?.call(frame.event);
      return _out(
        d.density == SyncDensity.sparse ? 'max_advanced' : 'applied',
        scope,
        seq: frame.seq,
      );
    }
    _difference(name, scope, e.appliedSeq!, e.epoch);
    e.repairPending = true;
    return _out(
      'gap_repair_requested',
      scope,
      from: e.appliedSeq! + BigInt.one,
      to: frame.seq - BigInt.one,
    );
  }

  Map<String, dynamic> ingestSnapshot(String name, SyncSnapshot snapshot) {
    final d = _domain(name),
        e = _entry(_domain(name), snapshot.scopeId),
        scope = snapshot.scopeId;
    final sameEpoch =
        e.epoch == null || snapshot.epoch == null || e.epoch == snapshot.epoch;
    final sameWatermark =
        e.appliedSeq != null && e.appliedSeq == snapshot.watermark;
    final allowSame =
        sameWatermark &&
        d.acceptSameWatermarkSnapshot?.call(e.state, snapshot) == true;
    if (sameEpoch &&
        e.appliedSeq != null &&
        (snapshot.watermark < e.appliedSeq! || (sameWatermark && !allowSame))) {
      _violation(
        'version_regression',
        name,
        scope,
        seq: snapshot.watermark,
        epoch: snapshot.epoch,
      );
      return _out('duplicate_dropped', scope, seq: snapshot.watermark);
    }
    e.state = d.fromSnapshot(snapshot);
    e.appliedSeq = snapshot.watermark;
    e.acceptedFingerprint = null;
    e.epoch = snapshot.epoch;
    e.repairPending = false;
    _clear(name, scope);
    return _out('applied', scope, seq: snapshot.watermark);
  }

  Map<String, dynamic> ingestDifference(String name, SyncDifference response) {
    final d = _domain(name),
        e = _entry(_domain(name), response.scopeId),
        scope = response.scopeId;
    if (_mismatch(e, response.epoch)) {
      _violation('cross_epoch_arrival', name, scope, epoch: response.epoch);
      _snapshot(name, scope, 'epoch_mismatch');
      return _out('epoch_rebaseline_requested', scope);
    }
    if (response.snapshotRequired) {
      _clear(name, scope);
      _snapshot(name, scope, 'snapshot_required');
      e.repairPending = true;
      return _out('epoch_rebaseline_requested', scope);
    }
    final ordered = List<SyncFrame>.of(response.events)
      ..sort((a, b) => a.seq.compareTo(b.seq));
    for (final item in ordered) {
      if (e.appliedSeq != null && item.seq <= e.appliedSeq!) continue;
      e.state = d.fold(e.state, item.event, scope, item.seq);
      e.appliedSeq = item.seq;
      e.acceptedFingerprint = d.eventFingerprint?.call(item.event);
    }
    if (e.appliedSeq == null || response.toSeq > e.appliedSeq!) {
      e.appliedSeq = response.toSeq;
      e.acceptedFingerprint = null;
    }
    _clear(name, scope);
    if (response.partial) {
      _difference(name, scope, e.appliedSeq!, e.epoch);
      return _out(
        'gap_repair_requested',
        scope,
        from: e.appliedSeq! + BigInt.one,
        to: response.toSeq,
      );
    }
    e.repairPending = false;
    return _out('applied', scope, seq: e.appliedSeq);
  }

  List<Map<String, dynamic>> pendingRequests() => _pending.values
      .map((e) => Map<String, dynamic>.unmodifiable(e))
      .toList(growable: false);
  dynamic state(String domain, String scope) => _scopes[domain]?[scope]?.state;
  Map<String, dynamic>? scopeSyncState(String domain, String scope) {
    final e = _scopes[domain]?[scope];
    return e == null
        ? null
        : {
            'appliedSeq': (e.appliedSeq ?? BigInt.zero).toString(),
            'epoch': e.epoch,
            'repairPending': e.repairPending,
          };
  }

  Map<String, dynamic> violations([int? since]) {
    final oldest = _nextViolation - _violations.length;
    final requested = since ?? oldest;
    if (requested < 0) throw RangeError.value(requested);
    return {
      'records': _violations
          .where((e) => (e['index'] as int) >= requested)
          .map(Map<String, dynamic>.of)
          .toList(),
      'droppedCount': requested < oldest ? oldest - requested : 0,
      'nextIndex': _nextViolation,
    };
  }

  void revokeScope(String domain, String scope) {
    _scopes[domain]?.remove(scope);
    _clear(domain, scope);
  }
}
