import 'package:flutter/widgets.dart';

/// A suggestion is supplied by the application after current server/channel
/// authority checks. The pure composer does not fetch directories.
class RaftComposerSuggestion {
  const RaftComposerSuggestion({
    required this.type,
    required this.id,
    required this.name,
    this.title,
    this.detail,
    this.inChannel = true,
    this.threadRank,
    this.archived = false,
    this.referenceText,
    this.avatar,
    this.mutedAvatar,
  });
  final String type, id, name;
  final String? title, detail, referenceText;

  /// Web MentionCandidateAvatar (`AvatarSlot context="compact-list"`),
  /// supplied by the authority-checked adapter; [mutedAvatar] is the
  /// not-in-channel treatment (`!border-black/40 opacity-60`).
  final Widget? avatar, mutedAvatar;
  final bool inChannel;

  /// Thread composers only (Web `buildRecentParticipantRanks`): 0 is the most
  /// recent speaker of the thread; null never spoke. Ranked before the match
  /// order inside each group.
  final int? threadRank;

  /// An archived channel option (Web `ch.archivedAt`): the `archived` Badge.
  final bool archived;
  bool get isMention => type == 'user' || type == 'agent' || type == 'external';
  String get insertion =>
      referenceText ?? '${type == 'channel' ? '#' : '@'}$name';
  Map<String, dynamic> get mention => {'type': type, 'id': id, 'name': name};
}

/// Selected identities remain bound to exact visible handles, including a
/// handle inserted next to Chinese text. Code and resource labels do not send
/// notifications, matching the source structured-mention contract.
bool raftStructuredMentionAppears(String text, String name) {
  if (!RegExp(r'^[\p{L}\p{N}_-]+$', unicode: true).hasMatch(name)) return false;
  final prose = text.replaceAll(
    RegExp(
      r'```[\s\S]*?(?:```|$)|~~~[\s\S]*?(?:~~~|$)|`[^`]*(?:`|$)|\\<@[\p{L}\p{N}_-]+>|\[(?:\\.|[^\]\\])*\]\(<(?:raft-ref://(?:computer|app)|computer:|app:)[^<>\n]*>\)',
      unicode: true,
    ),
    '',
  );
  return RegExp(
    '@${RegExp.escape(name)}(?![\\p{L}\\p{N}_-])',
    unicode: true,
  ).hasMatch(prose);
}

class RaftComposerTrigger {
  const RaftComposerTrigger(this.prefix, this.query, this.start, this.end);
  final String prefix, query;
  final int start, end;
}

RaftComposerTrigger? raftComposerTrigger(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final before = text.substring(0, cursor);
  // Preserve IME/editor code surfaces: completions never rewrite a code span.
  if (RegExp(r'```|~~~').allMatches(before).length.isOdd) return null;
  if ('`'.allMatches(before.replaceAll('```', '')).length.isOdd) return null;
  final match = RegExp(
    r'([@#])([\p{L}\p{N}_-]*)$',
    unicode: true,
  ).firstMatch(before);
  return match == null
      ? null
      : RaftComposerTrigger(match[1]!, match[2]!, match.start, cursor);
}
