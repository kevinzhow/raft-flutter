// Actors no roster carries: senders of another server in a joint channel
// (Web store/localTables/actorResolve.ts and useActorFallback.ts at
// v1.24.0-source.1). Surfaces that show a sender (message rows, Activity
// rows, task assignees) ask [ActorDirectory.request] for one they could not
// resolve from the member / agent / channel rosters and read [row]; this
// directory batches the refs into `POST /actors/resolve` (50 ms debounce,
// chunks of 200) and asks each ref once per scope. A ref the server leaves
// out is not asked again until the scope changes; a 403 (guest) or 404 (a
// server without the endpoint) turns it off for the scope; any other failure
// only marks the refs as asked, so nothing retries in a loop.
//
// `actor:updated` (an agent of another server changed its display identity)
// refreshes the row of the current scope.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart' show ActorUpdatedEvent;

/// One resolved actor (shared resolvedActorSchema without `gravatarHash`).
typedef ActorRow = ({
  String kind,
  String id,
  String homeServerId,
  String name,
  String? displayName,
  String? avatarUrl,
});

class ActorDirectory extends ChangeNotifier {
  ActorDirectory._(this.client);
  final RaftClient client;

  static final _of = Expando<ActorDirectory>('actor directory');

  static ActorDirectory of(RaftClient client) =>
      _of[client] ??= ActorDirectory._(client);

  static const debounce = Duration(milliseconds: 50);
  static const maxActors = 200;
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Live rosters can drop refs they learned while a batch waited.
  final localLookups = <bool Function(String kind, String id)>{};

  String? _scope;
  final _rows = <String, ActorRow>{};
  final _asked = <String>{};
  final _pending = <String, (String, String)>{};
  Timer? _timer;
  bool _disabled = false;

  static String _key(String kind, String id) => '$kind:$id';

  String? get _current {
    final user = client.user?.id, server = client.serverId;
    return user == null || server == null
        ? null
        : '${client.origin}|${client.generation}|$user|$server';
  }

  /// The scope changed (sign-out, account or server switch): forget it all.
  bool _synchronize() {
    final scope = _current;
    if (scope == _scope) return scope != null;
    _scope = scope;
    _rows.clear();
    _asked.clear();
    _pending.clear();
    _timer?.cancel();
    _timer = null;
    _disabled = false;
    return scope != null;
  }

  ActorRow? row(String kind, String id) =>
      _synchronize() ? _rows[_key(kind, id)] : null;

  /// Ask the server for actors this scope has no row for. Cheap to call from
  /// build: refs with a row, already asked or queued are skipped.
  void request(Iterable<({String kind, String id})> refs) {
    if (!_synchronize() || _disabled) return;
    for (final ref in refs) {
      if ((ref.kind != 'human' && ref.kind != 'agent') ||
          !_uuid.hasMatch(ref.id)) {
        continue;
      }
      final key = _key(ref.kind, ref.id);
      if (_asked.contains(key) ||
          _pending.containsKey(key) ||
          _rows.containsKey(key)) {
        continue;
      }
      _pending[key] = (ref.kind, ref.id);
    }
    if (_pending.isEmpty || _timer != null) return;
    _timer = Timer(debounce, _flush);
  }

  void _flush() {
    _timer = null;
    final scope = _scope;
    if (scope == null || scope != _current) return;
    final refs = <Map<String, String>>[];
    for (final MapEntry(key: key, value: (kind, id)) in _pending.entries) {
      if (_rows.containsKey(key) || localLookups.any((l) => l(kind, id))) {
        continue;
      }
      _asked.add(key);
      refs.add({'kind': kind, 'id': id});
    }
    _pending.clear();
    for (var start = 0; start < refs.length; start += maxActors) {
      final end = start + maxActors < refs.length
          ? start + maxActors
          : refs.length;
      unawaited(_resolve(scope, refs.sublist(start, end)));
    }
  }

  Future<void> _resolve(String scope, List<Map<String, String>> refs) async {
    final server = client.serverId;
    if (_disabled || server == null) return;
    try {
      final data = await client.postForServer(
        server,
        '/actors/resolve',
        data: {'actors': refs},
      );
      if (_scope != scope || scope != _current) return;
      final actors = data is Map ? data['actors'] : null;
      if (actors is! List) return;
      var changed = false;
      for (final actor in actors) {
        final row = parse(actor);
        if (row == null) continue;
        _rows[_key(row.kind, row.id)] = row;
        changed = true;
      }
      if (changed) notifyListeners();
    } on RaftApiException catch (e) {
      // 404: a server without the endpoint. 403: a guest may not look up.
      if (_scope == scope && (e.status == 404 || e.status == 403)) {
        _disabled = true;
      }
    } catch (_) {
      // Marked as asked: not retried.
    }
  }

  /// One entry of the answer, field by field; anything malformed is dropped
  /// (not strict: a field a newer server adds must not drop the row).
  static ActorRow? parse(Object? value) {
    if (value is! Map) return null;
    final kind = value['kind'], id = value['id'];
    final home = value['homeServerId'], name = value['name'];
    final display = value['displayName'], avatar = value['avatarUrl'];
    if ((kind != 'human' && kind != 'agent') ||
        id is! String ||
        id.isEmpty ||
        home is! String ||
        (kind == 'agent' && home.isEmpty) ||
        name is! String ||
        (display != null && display is! String) ||
        (avatar != null && avatar is! String)) {
      return null;
    }
    return (
      kind: kind as String,
      id: id,
      homeServerId: home,
      name: name,
      displayName: display as String?,
      avatarUrl: avatar as String?,
    );
  }

  /// `actor:updated`: refresh the current scope's row of that agent.
  void applyUpdated(ActorUpdatedEvent event) {
    if (!_synchronize()) return;
    final row = (
      kind: event.kind,
      id: event.id,
      homeServerId: event.homeServerId,
      name: event.actorName,
      displayName: event.displayName,
      avatarUrl: event.avatarUrl,
    );
    final key = _key(event.kind, event.id);
    if (_rows[key] == row) return;
    _rows[key] = row;
    notifyListeners();
  }
}
