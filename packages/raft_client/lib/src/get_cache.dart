part of 'client.dart';

typedef _GetKey = ({
  String principal,
  String? server,
  String method,
  Uri url,
  String? language,
  bool workspaceScoped,
  _ReadPolicy policy,
});

class _GetEntry {
  const _GetEntry(this.data, this.received, this.size);

  final Object data;
  final DateTime received;
  final int size;
}

class _GetObservation {
  _GetObservation(this.key);

  final _GetKey key;
  bool invalidated = false;
}

class _GetCache {
  static const _maxEntries = 128;
  static const _maxPayloadSize = 384 * 1024;
  static const _maxTotalSize = 4 * 1024 * 1024;
  static const _staleFor = Duration(minutes: 2);

  final _entries = <_GetKey, _GetEntry>{};
  final _flights = <_GetKey, ({Future<dynamic> future, DateTime started})>{};
  final _observations = <_GetObservation>{};
  final _writes = <bool Function(_GetKey)>{};
  int _size = 0;

  void Function() beginWrite(bool Function(_GetKey) affects) {
    _writes.add(affects);
    _flights.removeWhere((key, _) => affects(key));
    return () => _writes.remove(affects);
  }

  _GetObservation? observe(_GetKey? key) {
    if (key == null) return null;
    final observation = _GetObservation(key);
    _observations.add(observation);
    return observation;
  }

  void unobserve(_GetObservation? observation) =>
      _observations.remove(observation);

  _GetEntry? peek(
    _GetKey key,
    Duration maxAge,
    DateTime now, {
    bool stale = false,
  }) {
    final entry = _entries[key];
    if (entry == null) return null;
    final age = now.difference(entry.received);
    if (age.isNegative || age >= maxAge + _staleFor) {
      _remove(key);
      return null;
    }
    if (!stale && (age >= maxAge || _writes.any((affects) => affects(key)))) {
      return null;
    }
    _entries
      ..remove(key)
      ..[key] = entry;
    return entry;
  }

  Future<dynamic> fetch(
    _GetKey key,
    DateTime Function() now,
    Duration joinWindow,
    Future<dynamic> Function(void Function(Response<dynamic>)) send,
    void Function() joined,
  ) {
    final pending = _flights[key];
    final started = now();
    if (pending != null && started.difference(pending.started) < joinWindow) {
      joined();
      return pending.future.then(RaftClient._cloneJson);
    }
    if (pending == null && _flights.length >= _maxEntries * 2) {
      return send((_) {});
    }
    bool retain = false;
    late final Future<dynamic> flight;
    flight = send((response) => retain = _eligibleResponse(response))
        .then((body) {
          if (identical(_flights[key]?.future, flight)) {
            if (retain) {
              _store(key, body, now());
            } else {
              _remove(key);
            }
          }
          return body;
        })
        .whenComplete(() {
          if (identical(_flights[key]?.future, flight)) _flights.remove(key);
        });
    _flights[key] = (future: flight, started: started);
    return flight.then(RaftClient._cloneJson);
  }

  void invalidate(bool Function(_GetKey) affects) {
    _flights.removeWhere((key, _) => affects(key));
    _observations.removeWhere((observation) {
      if (!affects(observation.key)) return false;
      observation.invalidated = true;
      return true;
    });
    _entries.removeWhere((key, entry) {
      if (!affects(key)) return false;
      _size -= entry.size;
      return true;
    });
  }

  void clear() {
    for (final observation in _observations) {
      observation.invalidated = true;
    }
    _observations.clear();
    _writes.clear();
    _flights.clear();
    _entries.clear();
    _size = 0;
  }

  void _store(_GetKey key, Object? body, DateTime received) {
    _remove(key);
    if (body is! Map && body is! List) return;
    if (key.policy.family == _ReadFamily.agents &&
        body is List &&
        body.any((item) => item is Map && item['runtimeConfig'] != null)) {
      return;
    }
    final size = _jsonSize(body, _maxPayloadSize);
    if (size > _maxPayloadSize) return;
    while (_entries.length >= _maxEntries || _size + size > _maxTotalSize) {
      _remove(_entries.keys.first);
    }
    _entries[key] = _GetEntry(RaftClient._cloneJson(body), received, size);
    _size += size;
  }

  void _remove(_GetKey key) => _size -= _entries.remove(key)?.size ?? 0;
}

bool _eligibleResponse(Response<dynamic> response) {
  if (response.statusCode != 200 || response.headers['set-cookie'] != null) {
    return false;
  }
  final directives = response.headers['cache-control'] ?? const <String>[];
  if (directives.any((line) {
    final parts = line.toLowerCase().split(',').map((part) => part.trim());
    return parts.any(
      (part) =>
          part == 'no-store' ||
          part.startsWith('no-cache') ||
          part == 'max-age=0',
    );
  })) {
    return false;
  }
  final vary = response.headers['vary'] ?? const <String>[];
  return vary.every(
    (line) => line
        .toLowerCase()
        .split(',')
        .every(
          (name) => const {
            'accept-encoding',
            'accept-language',
            'authorization',
            'x-server-id',
            'origin',
          }.contains(name.trim()),
        ),
  );
}

int _jsonSize(Object? value, int limit) {
  if (value is String) return 32 + 2 * value.length;
  if (value == null || value is num || value is bool) return 16;
  if (value is Uint8List) return limit + 1;
  var size = 64;
  if (value is List) {
    for (final item in value) {
      size += 8 + _jsonSize(item, limit - size);
      if (size > limit) break;
    }
    return size;
  }
  if (value is Map) {
    for (final MapEntry(:key, :value) in value.entries) {
      if (key is! String ||
          value != null &&
              const {
                'envvars',
                'accesstoken',
                'refreshtoken',
                'idtoken',
                'clientsecret',
                'apikey',
                'password',
                'signingkey',
                'credentials',
                'recoverycodes',
                'setuptoken',
                'ticket',
              }.contains(key.toLowerCase())) {
        return limit + 1;
      }
      size += 40 + _jsonSize(key, limit - size);
      size += _jsonSize(value, limit - size);
      if (size > limit) break;
    }
    return size;
  }
  return limit + 1;
}

bool _equalReadJson(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is List && right is List && left.length == right.length) {
    for (var index = 0; index < left.length; index++) {
      if (!_equalReadJson(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map && right is Map && left.length == right.length) {
    return left.entries.every(
      (entry) =>
          right.containsKey(entry.key) &&
          _equalReadJson(entry.value, right[entry.key]),
    );
  }
  return left == right;
}
