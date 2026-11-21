part of 'client.dart';

enum _ReadFamily {
  channelIndex,
  channel,
  roster,
  files,
  agents,
  members,
  messageWindow,
  messageContext,
  reactions,
  search,
  saved,
  unread,
  activity,
  taskIndex,
  taskDetail,
  taskHistory,
  artifactIndex,
  artifact,
  apps,
}

typedef _ReadPolicy = ({
  _ReadFamily family,
  Duration age,
  String? channel,
  String? id,
});

_ReadPolicy _readPolicy(
  _ReadFamily family,
  int seconds, {
  String? channel,
  String? id,
}) =>
    (family: family, age: Duration(seconds: seconds), channel: channel, id: id);

_ReadPolicy? _getPolicy(Uri url) {
  if (url.pathSegments case ['api', ...final path]) {
    final channelId = url.queryParameters['channelId'];
    return switch (path) {
      ['channels'] => _readPolicy(_ReadFamily.channelIndex, 15),
      ['channels', 'dm'] => _readPolicy(_ReadFamily.channelIndex, 10),
      ['channels', 'unread'] => _readPolicy(_ReadFamily.unread, 2),
      ['channels', 'inbox'] => _readPolicy(_ReadFamily.activity, 4),
      ['channels', 'inbox', 'done' || 'unfollowed'] => _readPolicy(
        _ReadFamily.activity,
        5,
      ),
      ['channels', 'saved'] => _readPolicy(_ReadFamily.saved, 8),
      ['channels', 'threads', 'followed'] => _readPolicy(
        _ReadFamily.activity,
        4,
      ),
      ['channels', final id]
          when !const {
            'joint-connections',
            'external-availability',
            'external-connect-servers',
            'joint-invites',
          }.contains(id) =>
        _readPolicy(_ReadFamily.channel, 12, channel: id),
      ['channels', final id, 'members' || 'agents'] => _readPolicy(
        _ReadFamily.roster,
        20,
        channel: id,
      ),
      ['channels', final id, 'files'] => _readPolicy(
        _ReadFamily.files,
        10,
        channel: id,
      ),
      ['channels', final id, 'threads', final message] => _readPolicy(
        _ReadFamily.messageContext,
        8,
        channel: id,
        id: message,
      ),
      ['messages', 'channel', final id] => _readPolicy(
        _ReadFamily.messageWindow,
        6,
        channel: id,
      ),
      ['messages', 'context', final id] => _readPolicy(
        _ReadFamily.messageContext,
        8,
        channel: channelId,
        id: id,
      ),
      ['messages', final id, 'reactions', 'viewer'] => _readPolicy(
        _ReadFamily.reactions,
        12,
        id: id,
      ),
      ['messages', 'search'] => _readPolicy(
        _ReadFamily.search,
        8,
        channel: channelId,
      ),
      ['servers', 'unread-summary'] => _readPolicy(_ReadFamily.unread, 3),
      ['servers', _, 'members'] => _readPolicy(_ReadFamily.members, 15),
      ['servers', _, 'members', final id, 'profile'] => _readPolicy(
        _ReadFamily.members,
        30,
        id: id,
      ),
      ['agents'] => _readPolicy(_ReadFamily.agents, 12),
      ['tasks', 'server'] => _readPolicy(_ReadFamily.taskIndex, 5),
      ['tasks', 'server', 'counts'] => _readPolicy(_ReadFamily.taskIndex, 4),
      ['tasks', 'channel', final id] => _readPolicy(
        _ReadFamily.taskIndex,
        8,
        channel: id,
      ),
      ['tasks', 'channel', final id, 'number', final number] => _readPolicy(
        _ReadFamily.taskDetail,
        10,
        channel: id,
        id: number,
      ),
      ['tasks', final id, 'history'] => _readPolicy(
        _ReadFamily.taskHistory,
        8,
        id: id,
      ),
      ['artifacts', 'conversations', final id] => _readPolicy(
        _ReadFamily.artifactIndex,
        10,
        channel: id,
      ),
      ['artifacts', final id, 'details'] => _readPolicy(
        _ReadFamily.artifact,
        12,
        id: id,
      ),
      ['integrations', 'marketplace'] => _readPolicy(_ReadFamily.apps, 30),
      ['integrations', 'overview'] => _readPolicy(_ReadFamily.apps, 12),
      _ => null,
    };
  }
  return null;
}

typedef _ReadEffect = bool Function(_ReadPolicy);

bool _allReads(_ReadPolicy policy) => true;
bool _noReads(_ReadPolicy policy) => false;
bool _possibly(String? cached, String? changed) =>
    cached == null || changed == null || cached == changed;

bool _matchesMessage(_ReadPolicy policy, String? channel, String? message) =>
    _possibly(policy.channel, channel) ||
    message != null && policy.id == message;

bool _messageEffect(
  _ReadPolicy policy,
  String? channel,
  String? message, {
  bool attachments = true,
}) => switch (policy.family) {
  _ReadFamily.unread || _ReadFamily.activity || _ReadFamily.saved => true,
  _ReadFamily.files => attachments && _possibly(policy.channel, channel),
  _ReadFamily.messageWindow ||
  _ReadFamily.search ||
  _ReadFamily.channel => _possibly(policy.channel, channel),
  _ReadFamily.messageContext => _matchesMessage(policy, channel, message),
  _ReadFamily.reactions => _possibly(policy.id, message),
  _ => false,
};

bool _taskEffect(
  _ReadPolicy policy,
  String? channel,
  String? task,
  String? number,
  String? conversation,
) => switch (policy.family) {
  _ReadFamily.taskIndex => _possibly(policy.channel, channel),
  _ReadFamily.taskDetail =>
    _possibly(policy.channel, channel) && _possibly(policy.id, number),
  _ReadFamily.taskHistory => _possibly(policy.id, task),
  _ReadFamily.channel =>
    _possibly(policy.channel, channel) ||
        conversation != null && _possibly(policy.channel, conversation),
  _ReadFamily.messageWindow || _ReadFamily.messageContext =>
    conversation == null ||
        _possibly(policy.channel, channel) ||
        _possibly(policy.channel, conversation),
  _ReadFamily.unread ||
  _ReadFamily.activity ||
  _ReadFamily.saved ||
  _ReadFamily.search => true,
  _ => false,
};

bool _agentEffect(_ReadPolicy policy) => const {
  _ReadFamily.agents,
  _ReadFamily.roster,
  _ReadFamily.members,
  _ReadFamily.apps,
}.contains(policy.family);

bool _readStateEffect(_ReadPolicy policy, String? channel) =>
    policy.family == _ReadFamily.unread ||
    policy.family == _ReadFamily.activity ||
    policy.family == _ReadFamily.channel &&
        _possibly(policy.channel, channel) ||
    policy.family == _ReadFamily.channelIndex;

bool _artifactEffect(_ReadPolicy policy, String? id) => switch (policy.family) {
  _ReadFamily.artifact => _possibly(policy.id, id),
  _ReadFamily.artifactIndex ||
  _ReadFamily.files ||
  _ReadFamily.activity => true,
  _ => false,
};

String? _readId(Object? payload, String key) =>
    payload is Map && payload[key] != null ? '${payload[key]}' : null;

_ReadEffect _writeEffect(Uri uri, Object? body) {
  final channel = _readId(body, 'channelId');
  final segments = uri.pathSegments;
  return switch (segments.firstOrNull == 'api'
      ? segments.skip(1).toList()
      : segments) {
    ['feature-flags', 'evaluate'] ||
    ['attachments', 'urls'] ||
    ['objects', 'summaries'] ||
    ['messages', _, 'link-cards', 'read'] ||
    ['auth', 'me', 'timezone-observation'] => _noReads,
    ['channels', 'saved', ...] => (
      policy,
    ) => policy.family == _ReadFamily.saved,
    ['channels', final id, 'read' || 'unread'] => (policy) => _readStateEffect(
      policy,
      id,
    ),
    ['channels', 'read-all'] => (policy) => _readStateEffect(policy, null),
    ['tasks', final id, ...] => (policy) => _taskEffect(
      policy,
      channel,
      id,
      null,
      null,
    ),
    ['tasks'] => (policy) => _taskEffect(policy, channel, null, null, null),
    ['v2', 'messages', final id, ...] || ['messages', final id, ...] => (
      policy,
    ) => _messageEffect(policy, channel, id),
    ['v2', 'messages'] ||
    ['messages'] => (policy) => _messageEffect(policy, channel, null),
    ['agents', ...] => _agentEffect,
    ['artifacts', 'save-attachment'] => (policy) => _artifactEffect(
      policy,
      null,
    ),
    ['artifacts', final id, ...] => (policy) => _artifactEffect(policy, id),
    ['integrations', ...] || ['mcp', ...] => (
      policy,
    ) => _agentEffect(policy) || policy.family == _ReadFamily.apps,
    _ => _allReads,
  };
}

_ReadEffect _realtimeEffect(RaftEvent event) {
  final payload = event.payload;
  final channel = _readId(payload, 'channelId');
  final namespace = event.name.split(':').first;
  switch (namespace) {
    case 'message':
      if (event.name == 'message:read') {
        return (policy) => _readStateEffect(policy, channel);
      }
      final message = _readId(payload, 'messageId') ?? _readId(payload, 'id');
      return (policy) => _messageEffect(
        policy,
        channel,
        message,
        attachments: event.name != 'message:reactions',
      );
    case 'task':
      final task = payload is Map ? payload['task'] : null;
      final id = _readId(task, 'id') ?? _readId(payload, 'taskId');
      final scope = channel ?? _readId(task, 'channelId');
      final number =
          _readId(task, 'taskNumber') ?? _readId(payload, 'taskNumber');
      final conversation =
          _readId(task, 'conversationChannelId') ??
          _readId(payload, 'conversationChannelId');
      return (policy) => _taskEffect(policy, scope, id, number, conversation);
    case 'thread':
      final thread = _readId(payload, 'threadChannelId');
      final parent = _readId(payload, 'parentMessageId');
      if (event.name == 'thread:updated' && thread != null && parent != null) {
        final parentChannel = switch (payload) {
          {
            'latestReply': {
              'conversationContext': {'parentChannelId': String id},
            },
          } =>
            id,
          {
            'syncCoreReplyWindow': {
              'discussion': {'parentScopeKey': {'scopeId': String id}},
            },
          } =>
            id,
          _ => null,
        };
        return (policy) => switch (policy.family) {
          _ReadFamily.messageWindow =>
            _possibly(policy.channel, parentChannel) ||
                _possibly(policy.channel, thread),
          _ReadFamily.messageContext =>
            policy.id == parent || _possibly(policy.channel, thread),
          _ => _messageEffect(policy, thread, null, attachments: false),
        };
      }
      return _allReads;
    case 'agent':
      return const {
            'agent:activity',
            'agent:created',
            'agent:deleted',
            'agent:seen',
            'agent:updated',
          }.contains(event.name)
          ? _agentEffect
          : _allReads;
    case 'artifact':
      final id = _readId(payload, 'artifactId') ?? _readId(payload, 'id');
      return (policy) => _artifactEffect(policy, id);
    case 'read':
    case 'unread':
      return (policy) => _readStateEffect(policy, channel);
    case 'saved':
      return (policy) => policy.family == _ReadFamily.saved;
    case 'presence':
    case 'typing':
    case 'notification':
      return (policy) =>
          policy.family == _ReadFamily.activity ||
          policy.family == _ReadFamily.unread;
    case 'channel':
      final row = payload is Map ? payload['channel'] : null;
      final changed = channel ?? _readId(row, 'id');
      final authorityChanged = row is Map
          ? row['joined'] == false ||
                row.containsKey('channelCapabilities') ||
                row.containsKey('type')
          : false;
      if (event.name == 'channel:updated' &&
          changed != null &&
          !authorityChanged) {
        return (policy) =>
            policy.family == _ReadFamily.channelIndex ||
            policy.family == _ReadFamily.channel &&
                _possibly(policy.channel, changed);
      }
      return _allReads;
    default:
      return _allReads;
  }
}
