// The rich parts of a public message (Web PublicServerPage.tsx `PublicMention`,
// `PublicReaction`, `PublicThreadReply`): what the server projects for a visitor
// without exposing a principal id.
import 'package:flutter/foundation.dart';

/// `name` is the `@token` as written in the content; no principal id.
@immutable
class PublicMention {
  const PublicMention({
    required this.type,
    required this.name,
    required this.displayName,
  });
  static PublicMention? tryParse(Object? value) {
    if (value is! Map ||
        !const {'user', 'agent', 'external'}.contains(value['type']) ||
        value['name'] is! String) {
      return null;
    }
    return PublicMention(
      type: value['type'] as String,
      name: value['name'] as String,
      displayName: '${value['displayName'] ?? value['name']}',
    );
  }

  final String type, name, displayName;

  /// A display-local key like Web's `public:<type>:<name>`: it lets the
  /// renderer mark `@token`, and never reaches an API.
  String get key => 'public:$type:$name';
}

/// Emoji and count only; reactor identities are never projected.
@immutable
class PublicReaction {
  const PublicReaction({required this.emoji, required this.count});
  static PublicReaction? tryParse(Object? value) {
    if (value is! Map || value['emoji'] is! String || value['count'] is! num) {
      return null;
    }
    return PublicReaction(
      emoji: value['emoji'] as String,
      count: (value['count'] as num).toInt(),
    );
  }

  final String emoji;
  final int count;

  /// The reaction row of the shared message tile: counts render, reactors
  /// cannot (Web `{ ...reaction, previewK: [] }`).
  Map<String, dynamic> toRow() => {
    'emoji': emoji,
    'count': count,
    'previewK': const <Object?>[],
  };
}

/// A reply in a message's inline thread preview: the public projection of
/// `ThreadReplyPreview` (no sender id).
@immutable
class PublicThreadReply {
  const PublicThreadReply({
    required this.messageId,
    required this.preview,
    required this.senderType,
    required this.senderName,
    this.senderAvatarUrl,
    this.createdAt,
  });
  static PublicThreadReply? tryParse(Object? value) {
    if (value is! Map ||
        value['messageId'] is! String ||
        value['preview'] is! String ||
        !const {
          'user',
          'agent',
          'system',
          'external_projection',
        }.contains(value['senderType'])) {
      return null;
    }
    return PublicThreadReply(
      messageId: value['messageId'] as String,
      preview: value['preview'] as String,
      senderType: value['senderType'] as String,
      senderName: '${value['senderName'] ?? ''}',
      senderAvatarUrl: value['senderAvatarUrl'] as String?,
      createdAt: DateTime.tryParse('${value['createdAt']}'),
    );
  }

  final String messageId, preview, senderType, senderName;
  final String? senderAvatarUrl;
  final DateTime? createdAt;
}
