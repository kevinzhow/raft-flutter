import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

// Web 1.24 externalIdentityPresentation.ts `externalSenderPresentation` and
// MessageItem's sender name: the synthetic Slack bot label ("Slack bot ·
// 1a2b", shared slackBotFallbackLabel) gives way to the bot's verified
// profile once the server returned one; a profile that could not be
// recovered reads "Slack user {id}".

/// Shared `slackBotFallbackLabel`.
String slackBotFallbackLabel(String providerBotId) =>
    'Slack bot · ${providerBotId.length > 4 ? providerBotId.substring(providerBotId.length - 4) : providerBotId}';

bool _replacesFallback(Map<dynamic, dynamic> author) =>
    author['provider'] == 'slack' &&
    author['actorKind'] == 'bot' &&
    author['displayName'] is String &&
    author['externalActorId'] is String &&
    author['displayName'] ==
        slackBotFallbackLabel(author['externalActorId'] as String);

/// The external author's shown name and picture (null: keep the row's own).
({String? name, String? avatarUrl}) externalSenderPresentation(
  Map<dynamic, dynamic>? author,
) {
  if (author == null) return (name: null, avatarUrl: null);
  final fields = RaftExternalAuthorFields(Map<String, dynamic>.from(author));
  final fallback = _replacesFallback(author);
  final name =
      (fallback ? fields.profileDisplayName : null) ??
      (author['displayName'] is String &&
              (author['displayName'] as String).isNotEmpty
          ? author['displayName'] as String
          : null);
  return (
    name: name,
    avatarUrl:
        (fallback ? fields.profileAvatarUrl : null) ??
        (author['avatarUrl'] is String ? author['avatarUrl'] as String : null),
  );
}

/// The name a message row shows for its sender.
String messageSenderName(BuildContext context, RaftMessage message) {
  final author = message.json['externalAuthor'];
  if (message.string('senderType') != 'external_projection' || author is! Map) {
    return message.author;
  }
  if (RaftExternalAuthorFields(Map<String, dynamic>.from(author))
      .profileUnresolved) {
    return raftFormat(context, 'Slack user {id}', {
      'id': '${author['externalActorId'] ?? ''}',
    });
  }
  return externalSenderPresentation(author).name ?? message.author;
}
