/// Web `ParsedRaftPermalink` (packages/shared raftPermalinks.ts).
class RaftPermalink {
  const RaftPermalink({
    required this.routeKind,
    required this.serverSlug,
    required this.channelId,
    required this.messageId,
    this.threadParentMessageId,
  });

  /// `channel` or `dm`.
  final String routeKind, serverSlug, channelId, messageId;
  final String? threadParentMessageId;
  bool get isDm => routeKind == 'dm';

  @override
  bool operator ==(Object other) =>
      other is RaftPermalink &&
      other.routeKind == routeKind &&
      other.serverSlug == serverSlug &&
      other.channelId == channelId &&
      other.messageId == messageId &&
      other.threadParentMessageId == threadParentMessageId;
  @override
  int get hashCode => Object.hash(
    routeKind,
    serverSlug,
    channelId,
    messageId,
    threadParentMessageId,
  );
}

const defaultRaftPermalinkHostnames = [
  'app.slock.ai',
  'staging.slock.ai',
  'app.raft.build',
];

final _permalinkPath = RegExp(
  r'^/s/([^/]+)/(channel|dm)/([0-9a-f-]+)$',
  caseSensitive: false,
);
final _threadParam = RegExp(
  r'^([0-9a-f-]+):(.+)$',
  caseSensitive: false,
  dotAll: true,
);

/// Web `LEADING_MESSAGE_ID`: a link typed straight into CJK prose has no space
/// before the next word, so keep only the leading full or 8-hex short id.
final _leadingMessageId = RegExp(
  r'^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9a-f]{8})(?![0-9a-f-])',
  caseSensitive: false,
);
String? _leadingId(String value) => _leadingMessageId.firstMatch(value)?[1];

/// Web `parseRaftPermalink`: a message link of this app (the current frontend
/// host or one of the known Raft hosts), or null.
RaftPermalink? parseRaftPermalink(
  String href, {
  Iterable<String?> hostnames = const [],
}) {
  final Uri url;
  try {
    url = Uri.parse(href);
  } catch (_) {
    return null;
  }
  if (!url.hasScheme || url.host.isEmpty) return null;
  final allowed = {
    for (final h in [...hostnames, ...defaultRaftPermalinkHostnames])
      if (h != null && h.isNotEmpty) h,
  };
  if (!allowed.contains(url.host)) return null;
  final match = _permalinkPath.firstMatch(url.path);
  if (match == null) return null;
  final thread = url.queryParameters['thread'];
  String? parent;
  if (thread != null && thread.isNotEmpty) {
    final m = _threadParam.firstMatch(thread);
    if (m == null || m[1] != match[3]) return null;
    parent = _leadingId(m[2]!);
    if (parent == null) return null;
  }
  // `msg=` pinpoints a message; a thread-only URL targets the thread parent.
  final explicitParam = url.queryParameters['msg'];
  final explicit = explicitParam == null ? null : _leadingId(explicitParam);
  if (explicitParam != null && explicit == null) return null;
  final messageId = explicit ?? parent;
  if (messageId == null) return null;
  String slug;
  try {
    slug = Uri.decodeComponent(match[1]!);
  } catch (_) {
    return null;
  }
  return RaftPermalink(
    routeKind: match[2]!.toLowerCase(),
    serverSlug: slug,
    channelId: match[3]!,
    messageId: messageId,
    threadParentMessageId: parent,
  );
}

const _cjkBoundary = '，。、；：！？）》」』】》〉”’（《「『【〈“‘';
final _urlPattern = RegExp('https?://[^\\s<>"\'$_cjkBoundary]+');
final _trailingPunctuation = RegExp(r'[),.!?;:，。！？；：]+$');
final _fencedCode = RegExp(r'```[\s\S]*?```');
final _inlineCode = RegExp(r'``[^`]+``|`[^`]+`');

/// Web `extractFirstQuotedMessagePermalink`: the first permalink of this
/// server in [content] outside code and outside markdown `(…)` links.
({String rawUrl, RaftPermalink parsed})? extractFirstQuotedPermalink(
  String content, {
  String? hostname,
  String? serverSlug,
}) {
  if (!content.contains('http') || serverSlug == null) return null;
  // Protect code with same-length placeholders so offsets stay valid.
  final text = content
      .replaceAllMapped(_fencedCode, (m) => '\u0000' * m[0]!.length)
      .replaceAllMapped(_inlineCode, (m) => '\u0000' * m[0]!.length);
  for (final match in _urlPattern.allMatches(text)) {
    final raw = match[0]!;
    if (match.start > 0 && text[match.start - 1] == '(') continue;
    final trailing = _trailingPunctuation.firstMatch(raw)?[0] ?? '';
    final candidate = trailing.isEmpty
        ? raw
        : raw.substring(0, raw.length - trailing.length);
    final parsed = parseRaftPermalink(candidate, hostnames: [hostname]);
    if (parsed == null || parsed.serverSlug != serverSlug) continue;
    return (rawUrl: candidate, parsed: parsed);
  }
  return null;
}

/// Web `buildQuotedMessageAttachmentLabel` keys: `(source, count)`; the caller
/// localizes. Null when there are no attachments.
({String key, int? count})? quotedAttachmentLabel(List attachments) {
  if (attachments.isEmpty) return null;
  final images = attachments
      .whereType<Map>()
      .where((a) => '${a['mimeType'] ?? ''}'.startsWith('image/'))
      .length;
  if (attachments.length == 1) {
    return images == 1
        ? (key: '1 image', count: null)
        : (key: '1 file', count: null);
  }
  return images == attachments.length
      ? (key: '{count} images', count: images)
      : (key: '{count} attachments', count: attachments.length);
}
