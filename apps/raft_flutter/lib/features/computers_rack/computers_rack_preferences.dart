// What the Computers overview keeps (Web v1.24 store/computersRack
// {Filter,Sort,View}Preference.ts, features/computer/computersRackRemembered.ts):
// the grouping, the sort and the list / cards choice are how people like to
// see the list, kept on this device; the search and the Status / Runtime
// filters are what they look for now, kept for the session on one server
// (another server's computers start from none). Desktop and phone share them.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/device_preferences.dart';
import 'computers_rack_model.dart';

enum RackView { list, cards }

const computersRackGroupStorageKey = 'raft_computers_rack_group';
const computersRackSortStorageKey = 'raft_computers_rack_sort';
const computersRackViewStorageKey = 'raft_computers_rack_view';

/// The rack's choices; one per app (the Web stores are module-level).
class ComputersRackPreferences implements Listenable {
  ComputersRackPreferences._();
  static final instance = ComputersRackPreferences._();

  // An app-lifetime singleton (never disposed), so a plain listener list
  // rather than a ChangeNotifier.
  final _listeners = <VoidCallback>[];
  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final l in List.of(_listeners)) {
      if (_listeners.contains(l)) l();
    }
  }

  String _query = '';
  RackStatusFilter _status = RackStatusFilter.all;
  List<String> _runtimes = const [];
  String? _filteredServer;

  // The kept choices, read once from the preloaded preferences.
  RackGroupBy? _groupBy;
  RackView? _view;
  RackSort? _sort;
  bool _sortRead = false;

  String get query => _query;
  RackStatusFilter get status => _status;
  List<String> get runtimes => _runtimes;

  RackGroupBy get groupBy => _groupBy ??= RackGroupBy.values.firstWhere(
    (g) =>
        g.name ==
        DevicePreferences.current?.getString(computersRackGroupStorageKey),
    orElse: () => RackGroupBy.none,
  );

  /// Cards by default (stdrc, 2026-11-05).
  RackView get view => _view ??= RackView.values.firstWhere(
    (v) =>
        v.name ==
        DevicePreferences.current?.getString(computersRackViewStorageKey),
    orElse: () => RackView.cards,
  );

  /// Null (nothing kept, or a value this build can't read): no sort, the
  /// list's own order, the viewer's computers first.
  RackSort? get sort {
    if (!_sortRead) {
      _sortRead = true;
      _sort = parseRackSort(
        DevicePreferences.current?.getString(computersRackSortStorageKey),
      );
    }
    return _sort;
  }

  /// Another server: none of this server's search or filters.
  void adoptServer(String? serverId) {
    if (serverId == _filteredServer) return;
    _filteredServer = serverId;
    if (_query.isEmpty &&
        _status == RackStatusFilter.all &&
        _runtimes.isEmpty) {
      return;
    }
    _query = '';
    _status = RackStatusFilter.all;
    _runtimes = const [];
    notifyListeners();
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void setStatus(RackStatusFilter value) {
    if (value == _status) return;
    _status = value;
    notifyListeners();
  }

  void setRuntimes(List<String> value) {
    _runtimes = List.unmodifiable(value);
    notifyListeners();
  }

  void toggleRuntime(String runtime) => setRuntimes(
    _runtimes.contains(runtime)
        ? [
            for (final r in _runtimes)
              if (r != runtime) r,
          ]
        : [..._runtimes, runtime],
  );

  /// Clear all: the search, Status and Runtime; grouping, sort and view stay.
  void clearFilters() {
    _query = '';
    _status = RackStatusFilter.all;
    _runtimes = const [];
    notifyListeners();
  }

  void setGroupBy(RackGroupBy value) {
    _groupBy = value;
    DevicePreferences.current?.setString(
      computersRackGroupStorageKey,
      value.name,
    );
    notifyListeners();
  }

  void setView(RackView value) {
    _view = value;
    DevicePreferences.current?.setString(
      computersRackViewStorageKey,
      value.name,
    );
    notifyListeners();
  }

  /// Keeps [value]; null goes back to the default, forgetting the choice.
  void setSort(RackSort? value) {
    _sortRead = true;
    _sort = value;
    final prefs = DevicePreferences.current;
    if (value == null) {
      prefs?.remove(computersRackSortStorageKey);
    } else {
      prefs?.setString(
        computersRackSortStorageKey,
        jsonEncode({'key': value.key, 'direction': value.direction.name}),
      );
    }
    notifyListeners();
  }

  /// Tests and visual cases: the defaults, nothing kept in memory.
  @visibleForTesting
  void resetForTests() {
    _query = '';
    _status = RackStatusFilter.all;
    _runtimes = const [];
    _filteredServer = null;
    _groupBy = null;
    _view = null;
    _sort = null;
    _sortRead = false;
  }
}

/// computersRackSortPreference.ts parse: an old or hand-edited value reads
/// as no sort.
RackSort? parseRackSort(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final value = jsonDecode(raw);
    if (value is! Map) return null;
    final key = value['key'], direction = value['direction'];
    if (key is! String || !isRackSortKey(key)) return null;
    final dir = RackSortDirection.values
        .where((d) => d.name == direction)
        .firstOrNull;
    return dir == null ? null : RackSort(key, dir);
  } catch (_) {
    return null;
  }
}

/// computersRackRemembered.ts: how many rows (and attention summary lines)
/// the list drew last time on this server, so the next load's placeholders
/// take the same room. Clamped to 0..12.
class ComputersRackRemembered {
  static const max = 12, fallbackRows = 4;
  static String _key(String userId, String serverId, String part) =>
      'slock:computersRack:${Uri.encodeComponent(userId)}:'
      '${Uri.encodeComponent(serverId)}:$part';

  static int? read(String? userId, String? serverId, String part) {
    if (userId == null || serverId == null) return null;
    final stored = DevicePreferences.current?.getString(
      _key(userId, serverId, part),
    );
    final count = stored == null ? null : int.tryParse(stored);
    return count?.clamp(0, max);
  }

  static void write(String? userId, String? serverId, String part, int count) {
    if (userId == null || serverId == null) return;
    final prefs = DevicePreferences.current;
    final key = _key(userId, serverId, part);
    final value = '${count.clamp(0, max)}';
    if (prefs != null && prefs.getString(key) != value) {
      prefs.setString(key, value);
    }
  }
}
