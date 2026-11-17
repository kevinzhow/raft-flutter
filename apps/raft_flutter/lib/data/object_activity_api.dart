// Source: packages/shared/src/activityObjectsContract.ts `objectActivityWebPaths`
// and packages/web/src/store/inboxStore.ts `postObjectActivity` at v1.24.0.
import 'package:raft_client/raft_client.dart';

/// The routes that act on an object (Artifact) Activity row for the signed-in
/// person in the client's active server (the client adds `/api` and the
/// `X-Server-Id` header). Refusals: 400 INVALID_REQUEST / UNKNOWN_OBJECT_KIND,
/// 403 APP_NOT_ENABLED, 404 NOT_FOUND, 409 DONE_FRONTIER_BEYOND_LATEST
/// (done and read only).
abstract final class ObjectActivityPaths {
  static const done = '/objects/activity/done';
  static const undone = '/objects/activity/undone';
  static const read = '/objects/activity/read';
}

class ObjectActivityApi {
  const ObjectActivityApi(this.client);
  final RaftClient client;

  /// Web's body: Done and read go through the row's newest event
  /// (`doneFrontierSeq`, what the row showed); undo Done names only the object.
  static Map<String, dynamic> body(Map row, {bool throughSeq = true}) => {
    'kind': row['objectKind'],
    'objectId': row['objectId'],
    if (throughSeq && row['doneFrontierSeq'] is String)
      'throughSeq': row['doneFrontierSeq'],
  };

  Future<void> done(Map row, {String? serverId}) =>
      _post(ObjectActivityPaths.done, body(row), serverId);

  Future<void> undone(Map row, {String? serverId}) =>
      _post(ObjectActivityPaths.undone, body(row, throughSeq: false), serverId);

  Future<void> read(Map row, {String? serverId}) =>
      _post(ObjectActivityPaths.read, body(row), serverId);

  Future<void> _post(String path, Map<String, dynamic> data, String? server) =>
      server == null
      ? client.post(path, data: data)
      : client.postForServer(server, path, data: data);
}
