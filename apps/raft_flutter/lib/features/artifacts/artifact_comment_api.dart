import 'dart:typed_data';

import 'package:raft_client/raft_client.dart';

import 'artifact_comment_models.dart';
import 'artifact_models.dart';

abstract interface class ArtifactMentionAudience {
  Future<List<ArtifactActor>> candidates(String query);
}

class ArtifactCommentApi implements ArtifactMentionAudience {
  ArtifactCommentApi(this.client, this.artifactId);

  final RaftClient client;
  final String artifactId;

  String get path => '/artifacts/${Uri.encodeComponent(artifactId)}';
  String commentPath(String id) => '$path/comments/${Uri.encodeComponent(id)}';

  String _query(String route, Map<String, String> values) => values.isEmpty
      ? route
      : Uri(path: route, queryParameters: values).toString();

  Future<
    ({
      List<ArtifactComment> comments,
      String? cursor,
      Map<String, Object?>? review,
    })
  >
  list({String? before, String? review}) async {
    final result = commentMap(
      await client.get(
        _query('$path/comments', {'before': ?before, 'review': ?review}),
      ),
    );
    return (
      comments: commentRows(result['comments'])
          .map(ArtifactComment.fromJson)
          .toList(),
      cursor: result['olderCursor'] as String?,
      review: result['review'] is Map ? commentMap(result['review']) : null,
    );
  }

  Future<ArtifactComment> post(ArtifactCommentInput input) async =>
      _comment(await client.post('$path/comments', data: input.toJson()));

  Future<ArtifactComment> edit(
    String id,
    List<ArtifactCommentPart> body,
  ) async => _comment(
    await client.patch(
      commentPath(id),
      data: {'body': body.map((part) => part.toJson()).toList()},
    ),
  );

  Future<void> delete(String id) => client.delete(commentPath(id));

  Future<ArtifactComment> resolve(String id, bool resolved) async => _comment(
    await client.post('${commentPath(id)}/${resolved ? 'resolve' : 'reopen'}'),
  );

  ArtifactComment _comment(Object? result) =>
      ArtifactComment.fromJson(commentMap(commentMap(result)['comment']));

  @override
  Future<List<ArtifactActor>> candidates(String query) async {
    final result = commentMap(
      await client.post(
        '/mentions/audience',
        data: {
          'audience': {
            'kind': 'object',
            'app': 'artifacts',
            'objectKind': 'artifact',
            'objectId': artifactId,
          },
          'q': query,
        },
      ),
    );
    return commentRows(result['candidates'])
        .map(ArtifactActor.fromJson)
        .where((actor) => actor.id != null)
        .toList();
  }

  Future<List<({ArtifactActor actor, String reason})>> willNotify({
    String? path,
    String? replyTo,
  }) async {
    final result = commentMap(
      await client.get(
        _query('${this.path}/will-notify', {
          'replyTo': ?replyTo,
          'path': ?path,
        }),
      ),
    );
    return [
      for (final row in commentRows(result['recipients']))
        (
          actor: ArtifactActor.fromJson(row['actor']),
          reason: row['reason'] as String? ?? '',
        ),
    ];
  }

  Future<String> upload(Uint8List bytes, String contentType) async {
    final result = commentMap(
      await client.request(
        'POST',
        '$path/comment-images',
        data: bytes,
        headers: {'Content-Type': contentType, 'Content-Length': bytes.length},
      ),
    );
    return result['fileId'] as String;
  }

  Future<Uint8List> image(String id) => client.getBytes(
    '/objects/artifact/${Uri.encodeComponent(artifactId)}/files/${Uri.encodeComponent(id)}',
  );
}
