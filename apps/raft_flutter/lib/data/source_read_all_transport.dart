import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';

/// Local transport metadata: Source thread Done owns its awaited inbox refresh,
/// so its successful read-all must not publish another persisted-read refresh.
const sourceDoneOwnsReadRefresh = 'raftSourceDoneOwnsReadRefresh';

/// Human-self read-all identity. Activity profile overlays are presentation and
/// never become an agent receiver or add a guessed sequence to this write.
class SourceReadAllIdentity {
  SourceReadAllIdentity.capture(RaftClient client)
    : origin = client.origin,
      generation = client.generation,
      serverId = client.serverId,
      principalId = client.user?.id;
  final String origin;
  final int generation;
  final String? serverId, principalId;
  bool current(RaftClient client) =>
      serverId?.isNotEmpty == true &&
      principalId?.isNotEmpty == true &&
      origin == client.origin &&
      generation == client.generation &&
      serverId == client.serverId &&
      principalId == client.user?.id;
  String key(String channelId) => jsonEncode([
    origin,
    generation,
    serverId,
    principalId,
    'self',
    channelId,
  ]);
}

/// Source inboxTransport's same-identity/scope in-flight coalescing. The first
/// caller owns the raw promise; a detached handler retires it on either result.
/// The owner is per real client, shared by borrowed Activity page consumers.
class SourceReadAllTransport {
  SourceReadAllTransport._(this.client) {
    client.http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, next) {
          final flight = Zone.current[_writeZone];
          if (flight is _ReadAllFlight &&
              identical(_inFlight[flight.key], flight) &&
              request.method == 'POST' &&
              request.path == flight.path &&
              request.headers['X-Server-Id'] == flight.identity.serverId &&
              request.data == null) {
            if (flight.doneOwnsRefresh) {
              request.extra[sourceDoneOwnsReadRefresh] = true;
            }
          }
          next.next(request);
        },
      ),
    );
  }
  static final _owners = Expando<SourceReadAllTransport>();
  static final _writeZone = Object();
  static SourceReadAllTransport of(RaftClient client) =>
      _owners[client] ??= SourceReadAllTransport._(client);
  final RaftClient client;
  final _inFlight = <String, _ReadAllFlight>{};

  Future<dynamic> threadDone(
    String channelId, {
    required SourceReadAllIdentity identity,
  }) => _post(channelId, identity, doneOwnsRefresh: true);

  /// Source inboxStore.markRead: opening an Activity row persists a human-self
  /// read-all for its scope. Unlike thread Done, the persisted read publishes
  /// the normal read-write refresh to the Activity attention owner.
  Future<dynamic> readAll(
    String channelId, {
    required SourceReadAllIdentity identity,
  }) => _post(channelId, identity, doneOwnsRefresh: false);

  Future<dynamic> _post(
    String channelId,
    SourceReadAllIdentity identity, {
    required bool doneOwnsRefresh,
  }) {
    if (channelId.isEmpty || !identity.current(client)) {
      return Future.error(
        const RaftApiException('Read-all authority changed.'),
      );
    }
    final key = identity.key(channelId);
    final existing = _inFlight[key];
    if (existing != null) return existing.response;
    final flight = _ReadAllFlight(
      key,
      '/channels/$channelId/read-all',
      identity,
      doneOwnsRefresh,
    );
    _inFlight[key] = flight;
    // Zone ownership reaches Dio's asynchronous request interceptors without
    // an invented wire header/body or a second authenticated transport path.
    final response = flight.response = runZoned(
      () => client.request('POST', flight.path),
      zoneValues: {_writeZone: flight},
    );
    void retire() {
      if (identical(_inFlight[key], flight)) _inFlight.remove(key);
    }

    response.then(
      (_) => retire(),
      onError: (Object _, StackTrace _) => retire(),
    );
    return response;
  }
}

class _ReadAllFlight {
  _ReadAllFlight(this.key, this.path, this.identity, this.doneOwnsRefresh);
  final String key, path;
  final bool doneOwnsRefresh;
  final SourceReadAllIdentity identity;
  late Future<dynamic> response;
}
