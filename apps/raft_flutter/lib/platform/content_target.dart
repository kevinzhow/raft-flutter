/// Content navigation only. OAuth callback URLs never enter this parser.
class ContentTarget {
  const ContentTarget({
    required this.channelId,
    this.serverId,
    this.serverSlug,
    this.messageId,
    this.parentMessageId,
    this.threadId,
    this.kind = 'channel',
  });
  final String channelId, kind;
  final String? serverId, serverSlug, messageId, parentMessageId, threadId;

  static bool validId(String value) =>
      RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(value);
  static ContentTarget? parse(Uri uri, {required Uri origin}) {
    if (uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.toString().length > 2048) {
      return null;
    }
    final p = uri.pathSegments;
    String? single(String key) {
      final values = uri.queryParametersAll[key];
      return values?.length == 1 ? values!.single : null;
    }

    bool queries(Set<String> keys) =>
        uri.queryParametersAll.keys.every(keys.contains) &&
        uri.queryParametersAll.values.every((values) => values.length == 1);
    if (uri.scheme == 'raft' &&
        uri.host == 'v1' &&
        !uri.hasPort &&
        p.length >= 4 &&
        p[0] == 'servers' &&
        validId(p[1]) &&
        ['channels', 'dms'].contains(p[2]) &&
        validId(p[3])) {
      if (p.length == 4 && uri.query.isEmpty) {
        return ContentTarget(
          serverId: p[1],
          channelId: p[3],
          kind: p[2] == 'dms' ? 'dm' : 'channel',
        );
      }
      if (p.length == 6 &&
          p[4] == 'messages' &&
          validId(p[5]) &&
          uri.query.isEmpty) {
        return ContentTarget(
          serverId: p[1],
          channelId: p[3],
          messageId: p[5],
          kind: p[2] == 'dms' ? 'dm' : 'channel',
        );
      }
      final parent = single('parentMessageId'), message = single('messageId');
      if (p.length == 6 &&
          p[2] == 'channels' &&
          p[4] == 'threads' &&
          validId(p[5]) &&
          parent != null &&
          validId(parent) &&
          message != null &&
          validId(message) &&
          queries({'parentMessageId', 'messageId'})) {
        return ContentTarget(
          serverId: p[1],
          channelId: p[3],
          messageId: message,
          parentMessageId: parent,
          threadId: p[5],
          kind: 'thread',
        );
      }
      return null;
    }
    if (!['http', 'https'].contains(uri.scheme) ||
        uri.origin != origin.origin ||
        p.length != 4 ||
        p[0] != 's' ||
        !validId(p[1]) ||
        !['channel', 'dm'].contains(p[2]) ||
        !validId(p[3]) ||
        !queries({'msg', 'thread'})) {
      return null;
    }
    final message = single('msg'), thread = single('thread');
    if (message != null && !validId(message)) return null;
    String? parent;
    if (thread != null) {
      final parts = thread.split(':');
      if (parts.length != 2 || parts[0] != p[3] || !validId(parts[1])) {
        return null;
      }
      parent = parts[1];
    }
    return ContentTarget(
      serverSlug: p[1],
      channelId: p[3],
      messageId: message,
      parentMessageId: parent,
      kind: parent != null ? 'thread' : p[2],
    );
  }

  Uri nativeUri(String boundServerId) {
    if (parentMessageId != null && threadId != null && messageId != null) {
      return Uri(
        scheme: 'raft',
        host: 'v1',
        path: '/servers/$boundServerId/channels/$channelId/threads/$threadId',
        queryParameters: {
          'parentMessageId': parentMessageId!,
          'messageId': messageId!,
        },
      );
    }
    return Uri(
      scheme: 'raft',
      host: 'v1',
      path:
          '/servers/$boundServerId/${kind == 'dm' ? 'dms' : 'channels'}/$channelId${messageId == null ? '' : '/messages/$messageId'}',
    );
  }

  /// The mounted server's already-filtered mobile notification projection.
  static ContentTarget? fromNotification(Map payload) {
    final server = payload['serverId'],
        channel = payload['channelId'],
        message = payload['messageId'],
        kind = payload['kind'];
    if (server is! String ||
        channel is! String ||
        message is! String ||
        ![server, channel, message].every(validId) ||
        !['channel', 'dm', 'thread'].contains(kind)) {
      return null;
    }
    if (kind == 'thread') {
      final parent = payload['parentMessageId'],
          parentChannel = payload['parentChannelId'],
          thread = payload['threadId'];
      if (parent is! String ||
          parentChannel is! String ||
          thread is! String ||
          ![parent, parentChannel, thread].every(validId) ||
          thread != channel) {
        return null;
      }
      return ContentTarget(
        serverId: server,
        channelId: parentChannel,
        messageId: message,
        parentMessageId: parent,
        threadId: thread,
        kind: 'thread',
      );
    }
    return ContentTarget(
      serverId: server,
      channelId: channel,
      messageId: message,
      kind: kind,
    );
  }
}
