import 'artifact_models.dart';

Map<String, Object?> commentMap(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const {};

Iterable<Map<String, Object?>> commentRows(Object? value) =>
    value is List ? value.whereType<Map>().map(commentMap) : const [];

final class ArtifactCommentPlace {
  const ArtifactCommentPlace([this.path, this.anchor]);

  factory ArtifactCommentPlace.fromJson(Object? value) {
    final map = commentMap(value);
    return ArtifactCommentPlace(
      map['path'] as String?,
      map['anchor'] is Map ? commentMap(map['anchor']) : null,
    );
  }

  final String? path;
  final Map<String, Object?>? anchor;

  Map<String, Object?> toJson() => path == null
      ? const {'scope': 'artifact'}
      : {'scope': 'file', 'path': path, 'anchor': anchor};
}

final class ArtifactCommentPart {
  const ArtifactCommentPart.text(this.text) : actor = null;
  const ArtifactCommentPart.mention(ArtifactActor this.actor) : text = '';

  factory ArtifactCommentPart.fromJson(Map<String, Object?> row) =>
      row['type'] == 'mention'
      ? ArtifactCommentPart.mention(ArtifactActor.fromJson(row['actor']))
      : ArtifactCommentPart.text(row['text'] as String? ?? '');

  final String text;
  final ArtifactActor? actor;

  String get display => actor == null ? text : '@${actor!.name}';

  Map<String, Object?> toJson() => actor == null
      ? {'type': 'text', 'text': text}
      : {
          'type': 'mention',
          'actor': {'type': actor!.type, 'id': actor!.id},
        };
}

List<ArtifactCommentPart> readCommentBody(Object? value) =>
    commentRows(value).map(ArtifactCommentPart.fromJson).toList();

final class ArtifactComment {
  ArtifactComment.fromJson(Map<String, Object?> row)
    : id = row['id'] as String,
      author = ArtifactActor.fromJson(row['author']),
      body = readCommentBody(row['body']),
      place = ArtifactCommentPlace.fromJson(row['target']),
      version = row['version'] as int,
      replyTo = row['replyTo'] as String?,
      reviewId = row['reviewId'] as String?,
      createdAt = row['createdAt'] as String? ?? '',
      edited = row['editedAt'] != null,
      deleted = row['deletedAt'] != null,
      resolvedAt = row['resolvedAt'] as String?,
      resolvedBy = row['resolvedBy'] == null
          ? null
          : ArtifactActor.fromJson(row['resolvedBy']),
      images = commentRows(row['images'])
          .map((image) => image['fileId'])
          .whereType<String>()
          .toList();

  final String id, createdAt;
  final int version;
  final String? replyTo, reviewId, resolvedAt;
  final bool deleted, edited;
  final ArtifactActor author;
  final ArtifactActor? resolvedBy;
  final ArtifactCommentPlace place;
  final List<ArtifactCommentPart> body;
  final List<String> images;
}

final class ArtifactCommentThread {
  const ArtifactCommentThread(this.id, this.root, this.replies);

  final String id;
  final ArtifactComment? root;
  final List<ArtifactComment> replies;

  ArtifactComment get first => root ?? replies.first;
  bool get resolved => root?.resolvedAt != null;
}

List<ArtifactCommentThread> artifactCommentThreads(
  Iterable<ArtifactComment> comments,
) {
  final byId = {for (final comment in comments) comment.id: comment};
  final groups = <String, List<ArtifactComment>>{};
  for (final comment in comments) {
    var root = comment;
    final visited = {comment.id};
    while (root.replyTo != null) {
      final parent = root.replyTo!;
      final previous = byId[parent];
      if (previous == null || !visited.add(parent)) break;
      root = previous;
    }
    (groups[root.replyTo ?? root.id] ??= []).add(comment);
  }
  return [
    for (final MapEntry(key: id, value: members) in groups.entries)
      ArtifactCommentThread(
        id,
        members.where((item) => item.id == id).firstOrNull,
        members.where((item) => item.id != id).toList(),
      ),
  ]..sort((a, b) => a.first.createdAt.compareTo(b.first.createdAt));
}

final class ArtifactCommentInput {
  const ArtifactCommentInput({
    required this.version,
    required this.place,
    required this.body,
    this.replyTo,
    this.images = const [],
  });

  final int version;
  final ArtifactCommentPlace place;
  final List<ArtifactCommentPart> body;
  final String? replyTo;
  final List<String> images;

  Map<String, Object?> toJson() => {
    'version': version,
    'target': (replyTo == null ? place : const ArtifactCommentPlace()).toJson(),
    'replyTo': replyTo,
    'body': body.map((item) => item.toJson()).toList(),
    if (images.isNotEmpty) 'images': images,
  };
}
