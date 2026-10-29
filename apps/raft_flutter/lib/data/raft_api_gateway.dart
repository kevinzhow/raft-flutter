import 'dart:async';
import 'dart:convert';

import 'package:raft_client/raft_client.dart';

typedef RaftGatewayRead = Future<dynamic> Function(
  String path, {
  Map<String, dynamic>? query,
});

/// Workspace request execution shared by its borrowed presentations.
///
/// Each calling facade retains its own coalescing lane and supplies its read
/// override. Borrowed ordinary reads still reach the source facade, whose lane
/// joins them. Neither that dispatch nor the client's request policy changes.
/// UI revision and unread updates are callbacks owned by the source workspace.
/// The app owns [client]; this gateway never closes it or cancels pending work.
class RaftApiGateway {
  RaftApiGateway(
    this.client, {
    required this._savedChanged,
    required this._refreshUnread,
  });

  final RaftClient client;
  final void Function() _savedChanged;
  final Future<void> Function() _refreshUnread;
  final _sharedReads = Map<Object, Map<String, Future<dynamic>>>.identity();

  Future<dynamic> query(String path, {Map<String, dynamic>? query}) =>
      client.get(path, query: query);

  /// Join only identical pending reads of the same caller and client scope.
  /// Every consumer receives a separate decoded response, including the first.
  Future<dynamic> sharedQuery(
    String path, {
    Map<String, dynamic>? query,
    required Object readerKey,
    required RaftClient scopeClient,
    required RaftGatewayRead read,
  }) {
    final params = query == null
        ? null
        : (query.keys.toList()..sort()).map((k) => [k, query[k]]).toList();
    final key = jsonEncode([
      scopeClient.origin,
      scopeClient.generation,
      scopeClient.user?.id,
      scopeClient.serverId,
      path,
      params,
    ]);
    var pending = _sharedReads[readerKey]?[key];
    if (pending == null) {
      // Invoke before retaining the lane: an override may throw synchronously.
      final started = pending = read(path, query: query);
      final reads = _sharedReads.putIfAbsent(readerKey, () => {});
      reads[key] = started;
      unawaited(
        started
            .then<void>((_) {}, onError: (Object _, StackTrace _) {})
            .whenComplete(() {
              if (identical(reads[key], started)) reads.remove(key);
              if (reads.isEmpty && identical(_sharedReads[readerKey], reads)) {
                _sharedReads.remove(readerKey);
              }
            }),
      );
    }
    return pending.then(copyDecoded);
  }

  /// Copy decoded containers while preserving opaque leaf values.
  static dynamic copyDecoded(dynamic value) => switch (value) {
    Map() => <String, dynamic>{
      for (final MapEntry(:key, :value) in value.entries)
        '$key': copyDecoded(value),
    },
    List() => [for (final item in value) copyDecoded(item)],
    _ => value,
  };

  Future<dynamic> command(String method, String path, {dynamic data}) async {
    final generation = client.generation,
        principal = client.user?.id,
        serverId = client.serverId;
    final value = await client.request(method, path, data: data);
    if (generation == client.generation &&
        principal == client.user?.id &&
        serverId == client.serverId &&
        ((method == 'POST' && path == '/channels/saved') ||
            (method == 'DELETE' && path.startsWith('/channels/saved/')))) {
      _savedChanged();
    }
    if (_reconcilesUnread(path)) await _refreshUnread();
    return value;
  }

  /// Commands whose unread effect must be reconciled with the server.
  static bool _reconcilesUnread(String path) {
    final segments = Uri.parse(path).pathSegments;
    return segments.isNotEmpty &&
        const {
          'read',
          'read-all',
          'unread',
          'join',
          'leave',
          'notification-settings',
        }.contains(segments.last);
  }
}
