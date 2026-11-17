// What an Artifact's Activity row says (Web v1.24 `apps/artifacts/
// artifactActivityRow.ts`, `ObjectInboxRow.tsx`), over the shared contract's
// row fields (`activityObjectsContract.ts`): `summary`, `latestEvent`,
// `preview`, `target`, `unreadParts`, `unreadCount`, `home`.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'artifacts/artifact_models.dart' show ArtifactKind;
import 'artifacts/artifact_text.dart' show artifactKindGlyph;
import 'icu_message.dart';

bool _count(Object? v) => v is int && v >= 0;
Map? _map(Object? v) => v is Map ? v : null;
String _str(Object? v) => v is String ? v : '';

/// `{ part, count }` of what an unread row adds after its line.
typedef ObjectNews = ({String part, int count});

/// The review the newest event posted (`target.review`), or null.
({String id, int comments})? artifactActivityReview(Map row) {
  final event = _map(row['latestEvent']);
  if (event?['eventKind'] != 'review') return null;
  final review = _map(_map(row['target'])?['review']);
  final id = review?['id'], comments = review?['comments'];
  if (id is! String || id.isEmpty || comments is! int || comments < 1) {
    return null;
  }
  return (id: id, comments: comments);
}

/// `unreadParts` while the row is unread and the server split it.
({int versions, int comments})? artifactActivityUnread(Map row) {
  if (((row['unreadCount'] as num?) ?? 0) <= 0) return null;
  final parts = _map(row['unreadParts']);
  final versions = parts?['versions'], comments = parts?['comments'];
  if (!_count(versions) || !_count(comments)) return null;
  return (versions as int) + (comments as int) > 0
      ? (versions: versions, comments: comments)
      : null;
}

/// The comment text shown in place of the sentence (`artifactActivityExcerpt`),
/// as the preview map, or null to keep the sentence.
Map? artifactActivityExcerpt(Map row) {
  final preview = _map(row['preview']);
  if (preview == null) return null;
  final images = preview['images'];
  if (_str(preview['text']).trim().isEmpty && !(_count(images) && images > 0)) {
    return null;
  }
  final kind = _str(_map(row['latestEvent'])?['eventKind']);
  // A new version on top of new comments: the comment leads.
  if (kind == 'version') {
    return (artifactActivityUnread(row)?.comments ?? 0) > 0 ? preview : null;
  }
  if (kind != 'comment' && kind != 'review') return null;
  return artifactActivityReview(row) != null ? null : preview;
}

/// "Image" / "3 images" for a comment of images alone, else null.
String? artifactActivityImagesOnly(BuildContext context, Map excerpt) {
  final images = excerpt['images'];
  if (_str(excerpt['text']).trim().isNotEmpty ||
      !_count(images) ||
      images == 0) {
    return null;
  }
  return icuText(context, '{count, plural, =1 {Image} other {# images}}', {
    'count': images,
  });
}

/// What an unread row adds after its line, comments first.
List<ObjectNews> artifactActivityNews(Map row) {
  final unread = artifactActivityUnread(row);
  if (unread == null) return const [];
  final excerpt = artifactActivityExcerpt(row) != null;
  final review = artifactActivityReview(row);
  final kind = _str(_map(row['latestEvent'])?['eventKind']);
  final lineIsComment =
      excerpt || kind == 'comment' || (kind == 'review' && review == null);
  final lineIsVersion = !excerpt && kind == 'version';
  final commentsSaid = review != null
      ? unread.comments <= review.comments
      : lineIsComment && unread.comments == 1;
  return [
    if (unread.comments > 0 && !commentsSaid)
      (part: 'comments', count: unread.comments),
    if (unread.versions > 0 && !lineIsVersion)
      (part: 'versions', count: unread.versions),
  ];
}

/// The parts of an Artifact row: its tile glyph, title, sentence and news.
class ObjectRowParts {
  const ObjectRowParts({
    required this.glyph,
    required this.title,
    required this.event,
    required this.news,
  });
  final RaftGlyph glyph;
  final String title;

  /// "Alice commented", "Alice published v3": the sentence in place of an
  /// excerpt.
  final String event;
  final List<String> news;
}

ObjectRowParts objectRowParts(
  BuildContext context,
  Map row,
  String? actorName,
) {
  final name = actorName ?? raftText(context, 'Someone');
  final summary = _map(row['summary']), target = _map(row['target']);
  final event = _map(row['latestEvent']);
  final kind = _str(event?['eventKind']), reason = _str(event?['reason']);
  final version = target?['version'] ?? summary?['latestVersion'];
  final review = artifactActivityReview(row);
  String say(String key, [Map<String, Object?> extra = const {}]) =>
      icuText(context, key, {'name': name, ...extra});
  final sentence = () {
    if (review != null) {
      return reason == 'mentioned'
          ? say(
              '{name} mentioned you in a review ({count, plural, one {# comment} other {# comments}})',
              {'count': review.comments},
            )
          : say(
              '{name} reviewed it ({count, plural, one {# comment} other {# comments}})',
              {'count': review.comments},
            );
    }
    if (reason == 'mentioned' && kind != 'version') {
      return say('{name} mentioned you');
    }
    if (kind == 'comment' || kind == 'review') return say('{name} commented');
    if (kind == 'comment_edited') return say('{name} edited a comment');
    if (kind == 'version') {
      return version == null
          ? say('{name} published a new version')
          : say('{name} published v{version}', {'version': version});
    }
    return say('{name} updated it');
  }();
  final title = _str(summary?['title']).trim();
  return ObjectRowParts(
    glyph: artifactKindGlyph(ArtifactKind.parse(summary?['kind'])),
    title: title.isEmpty ? raftText(context, 'Untitled Artifact') : title,
    event: sentence,
    news: [
      for (final n in artifactActivityNews(row))
        raftFormat(context, '· {news}', {
          'news': icuText(
            context,
            n.part == 'comments'
                ? '{count, plural, one {# new comment} other {# new comments}}'
                : '{count, plural, one {# new version} other {# new versions}}',
            {'count': n.count},
          ),
        }),
    ],
  );
}

/// Where an object lives, as its row names it: `#channel`, `@peer`; nothing
/// for the server, public or a deleted conversation.
String? objectRowHome(Map row) {
  final home = _map(row['home']);
  final label = _str(home?['label']);
  if (label.isEmpty) return null;
  final kind = _str(home?['kind']);
  if (kind == 'channel') return '#$label';
  if (kind == 'dm') {
    final peer = _str(home?['peerDisplayName']);
    return '@${peer.isEmpty ? label : peer}';
  }
  return null;
}
