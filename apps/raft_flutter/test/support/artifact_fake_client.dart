import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:raft_client/raft_client.dart';

/// A signed-in client on the official deployment (so the app knows its
/// content domain) whose Artifact routes a test answers. Every request is
/// recorded as `METHOD path`.
class ArtifactFakeClient extends RaftClient {
  ArtifactFakeClient({this.enabled = true})
    : super(
        origin: 'https://api.raft.build',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'u1', 'name': 'dev', 'displayName': 'Developer'});
    selectServer('s1');
  }

  bool enabled;
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  final requests = <String>[];
  final bodies = <String, Object?>{};

  /// Answers by `METHOD path` (exact), then by path prefix; a value that is a
  /// [RaftApiException] is thrown.
  final answers = <String, Object? Function(Object? data)>{};

  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  bool get signedIn => true;

  @override
  Future<RaftClientConfig> clientConfig() async =>
      const RaftClientConfig(appHosts: ['app.raft.build']);

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    final key = '$method $path';
    requests.add(key);
    bodies[key] = data;
    if (path == '/feature-flags/evaluate') {
      return {
        'evaluations': [
          {'key': 'workspace_artifacts_v0', 'enabled': enabled},
        ],
      };
    }
    final answer = answers[key];
    if (answer == null) {
      throw RaftApiException.response(
        'Not found',
        status: 404,
        body: {'error': 'Not found', 'code': 'NOT_FOUND'},
      );
    }
    final value = answer(data);
    if (value is RaftApiException) throw value;
    if (value is Future) return await value;
    return value;
  }

  @override
  Future<Uint8List> getBytes(String path) async {
    final value = await request('GET', path);
    if (value is Uint8List) return value;
    if (value is String) return Uint8List.fromList(utf8.encode(value));
    throw const RaftApiException('The server did not return a file.');
  }

  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }
}

const artifactUuid = 'db491d86-6156-4fe1-a742-01890ddbfffe';
const artifactId = 'pt_$artifactUuid';
const artifactShort = 'U5YUUwNcK8gqGo5mEh76Ms';

Map<String, Object?> artifactActor([String name = 'Developer']) => {
  'type': 'user',
  'id': 'u1',
  'name': name.toLowerCase(),
  'displayName': name,
  'avatarUrl': null,
};

Map<String, Object?> artifactCardJson({
  String id = artifactId,
  String title = 'probe',
  String kind = 'html',
  int version = 1,
  int latest = 1,
  bool pinned = false,
  int comments = 0,
  Map<String, Object?>? unseen,
  Map<String, Object?>? preview,
  Map<String, Object?>? facts,
}) => {
  'id': id,
  'url': 'https://app.raft.build/artifacts/$artifactShort',
  'title': title,
  'description': null,
  'kind': kind,
  'facts': facts ?? {'sizeBytes': 3780, 'fileCount': 1},
  'preview': preview ?? {'kind': 'none'},
  'version': version,
  'pinned': pinned,
  'latestVersion': latest,
  'author': artifactActor(),
  'createdAt': '2026-11-13T14:01:48.016Z',
  'updatedAt': '2026-11-13T14:01:48.016Z',
  'commentCount': comments,
  'home': {
    'kind': 'conversation',
    'conversation': {'id': 'c1', 'name': 'general', 'type': 'channel'},
  },
  'unseen': ?unseen,
};

Map<String, Object?> artifactFrameJson([String ticket = 'v']) {
  const origin = 'https://w-$artifactUuid.w.raftusercontent.com';
  return {
    'url': '$origin/__porthole/f/x/?ticket=$ticket',
    'origin': origin,
    'door': {'url': '$origin/__porthole/door?ticket=$ticket'},
  };
}

Map<String, Object?> artifactViewerJson({
  Map<String, Object?>? card,
  List<Map<String, Object?>>? files,
  List<int> versions = const [1],
  bool following = false,
  bool frame = true,
}) => {
  'card': card ?? artifactCardJson(),
  'files':
      files ??
      [
        {
          'path': 'probe.html',
          'kind': 'html',
          'sizeBytes': 3780,
          'entry': true,
        },
      ],
  'versions': [
    for (final n in versions.reversed)
      {
        'number': n,
        'publisher': artifactActor(),
        'createdAt': '2026-11-13T14:01:48.016Z',
        'note': null,
        'changedPaths': ['probe.html'],
      },
  ],
  'capabilities': {
    'publish': true,
    'comment': true,
    'changeHome': true,
    'unpublish': false,
    'narrowHome': false,
    'delete': true,
  },
  'viewer': artifactActor(),
  'following': following,
  'savedFrom': null,
  'origin': null,
  if (frame) 'frame': artifactFrameJson(),
};
