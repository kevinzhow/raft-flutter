import 'package:raft_client/raft_client.dart';

import 'artifact_models.dart';

class ArtifactHomeTarget {
  const ArtifactHomeTarget.server() : kind = 'server', conversationId = null;
  const ArtifactHomeTarget.public() : kind = 'public', conversationId = null;
  const ArtifactHomeTarget.conversation(String this.conversationId)
    : kind = 'conversation';

  final String kind;
  final String? conversationId;

  Map<String, String> get fields => {
    'to': kind,
    if (conversationId case final id?) 'conversationId': id,
  };
}

typedef ArtifactHomeLoss = ({
  int people,
  int agents,
  bool capped,
  bool leavesPublic,
});

typedef ArtifactShareAudience = ({
  int cannotSee,
  int guests,
  bool capped,
  List<String> widenTo,
});

class ArtifactSharingApi {
  ArtifactSharingApi(this.client);

  final RaftClient client;

  String _path(String id, String route, [Map<String, String>? query]) =>
      '/artifacts/${Uri.encodeComponent(id)}/$route'
      '${query == null ? '' : '?${Uri(queryParameters: query).query}'}';

  Future<ArtifactViewerData> _viewer(Future<Object?> response) async =>
      ArtifactViewerData.fromJson(await response) ??
      (throw const FormatException('Invalid Artifact response.'));

  Future<ArtifactViewerData> rename(String id, String title) => _viewer(
    client.request('PATCH', _path(id, 'title'), data: {'title': title}),
  );

  Future<ArtifactViewerData> unpublish(String id) =>
      _viewer(client.post(_path(id, 'unpublish')));

  Future<ArtifactViewerData> move(
    String id,
    ArtifactHomeTarget target, {
    ArtifactHomeLoss? loss,
  }) => _viewer(
    client.post(
      _path(id, 'home'),
      data: {
        ...target.fields,
        if (loss != null) 'expectedLost': loss.people + loss.agents,
      },
    ),
  );

  Future<ArtifactHomeLoss> preview(String id, ArtifactHomeTarget target) async {
    final body = await client.get(_path(id, 'home-change', target.fields));
    if (body is! Map ||
        body['peopleLosingAccess'] is! int ||
        body['agentsLosingAccess'] is! int) {
      throw const FormatException('Invalid Artifact home preview.');
    }
    return (
      people: body['peopleLosingAccess'] as int,
      agents: body['agentsLosingAccess'] as int,
      capped: body['capped'] == true,
      leavesPublic: body['leavesPublic'] == true,
    );
  }

  Future<ArtifactShareAudience> audience(String id, String conversation) async {
    final body = await client.get(
      _path(id, 'share-audience', {'conversationId': conversation}),
    );
    if (body is! Map || body['cannotSee'] is! int) {
      throw const FormatException('Invalid Artifact share audience.');
    }
    final targets = body['widenTo'];
    return (
      cannotSee: body['cannotSee'] as int,
      guests: (body['guestsCannotSee'] as int?) ?? 0,
      capped: body['capped'] == true,
      widenTo: [
        if (targets is List)
          for (final target in targets.whereType<String>())
            if (target == 'server' || target == 'public') target,
      ],
    );
  }

  Future<({String messageId, ArtifactHome? home})> share(
    String id, {
    required String conversation,
    required String? note,
    required String? widenTo,
    required String clientKey,
  }) async {
    final body = await client.post(
      _path(id, 'share'),
      data: {
        'conversationId': conversation,
        'threadRootId': null,
        'note': note,
        'widenTo': widenTo,
        'clientKey': clientKey,
      },
    );
    if (body is! Map || body['messageId'] is! String) {
      throw const FormatException('Invalid Artifact share receipt.');
    }
    return (
      messageId: body['messageId'] as String,
      home: body['home'] == null ? null : ArtifactHome.fromJson(body['home']),
    );
  }
}
