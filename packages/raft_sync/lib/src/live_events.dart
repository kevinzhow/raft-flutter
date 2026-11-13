// Socket events server v1.24 added (Web store/socketBridge.ts
// MAIN_LAYOUT_SOCKET_EVENT_NAMES at v1.24.0-source.1), parsed into typed
// values. Each reader takes the raw payload and returns null for a frame the
// Web reader would drop, so every consumer sees the same accepted frames.
// The surfaces that show them are their packages' (typing line, theme,
// Activity objects); this file only defines what a frame means.

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool _nullableString(Object? value) => value == null || value is String;

sealed class LiveEvent {
  const LiveEvent();

  /// Socket event names this file reads.
  static const names = {
    AgentTypingEvent.name,
    AgentActivityStateEvent.name,
    ActorUpdatedEvent.name,
    UserProfileUpdatedEvent.name,
    AppearanceUpdatedEvent.name,
    ActivityChangedEvent.name,
    SyncChangedEvent.name,
    ThreadReplyUpdatedEvent.name,
    ListChangedEvent.permissionUpdates,
    ListChangedEvent.jointInvites,
    ListChangedEvent.seatJoinBlocks,
    ServerFeaturesChangedEvent.name,
  };

  /// The typed value of one socket frame, or null (unknown event or a frame
  /// the Web drops).
  static LiveEvent? read(String event, Object? payload) => switch (event) {
    AgentTypingEvent.name => AgentTypingEvent.read(payload),
    AgentActivityStateEvent.name => AgentActivityStateEvent.read(payload),
    ActorUpdatedEvent.name => ActorUpdatedEvent.read(payload),
    UserProfileUpdatedEvent.name => UserProfileUpdatedEvent.read(payload),
    AppearanceUpdatedEvent.name => AppearanceUpdatedEvent.read(payload),
    ActivityChangedEvent.name => ActivityChangedEvent.read(payload),
    SyncChangedEvent.name => const SyncChangedEvent(),
    ThreadReplyUpdatedEvent.name => ThreadReplyUpdatedEvent.read(payload),
    ServerFeaturesChangedEvent.name => ServerFeaturesChangedEvent.read(payload),
    _ when ListChangedEvent.events.contains(event) => ListChangedEvent.read(
      event,
      payload,
    ),
    _ => null,
  };
}

/// `agent:typing` (Web agentTypingStore readAgentTypingEvent): an agent is
/// about to post into a channel (or one thread under it). `start` is renewed
/// until `expiresAt` (epoch ms); `end` clears that call.
class AgentTypingEvent extends LiveEvent {
  const AgentTypingEvent({
    required this.agentId,
    required this.serverId,
    required this.channelId,
    required this.parentMessageId,
    required this.callId,
    required this.started,
    required this.expiresAt,
  });
  static const name = 'agent:typing';
  final String agentId, serverId, channelId, callId;
  final String? parentMessageId;
  final bool started;
  final int expiresAt;

  static AgentTypingEvent? read(Object? payload) {
    if (payload is! Map) return null;
    final agentId = payload['agentId'], channelId = payload['channelId'];
    final callId = payload['callId'], serverId = payload['serverId'];
    final state = payload['state'];
    if (agentId is! String ||
        channelId is! String ||
        callId is! String ||
        serverId is! String ||
        (state != 'start' && state != 'end')) {
      return null;
    }
    final parent = payload['parentMessageId'];
    final expires = payload['expiresAt'];
    return AgentTypingEvent(
      agentId: agentId,
      serverId: serverId,
      channelId: channelId,
      parentMessageId: parent is String ? parent : null,
      callId: callId,
      started: state == 'start',
      expiresAt: expires is num && expires.isFinite ? expires.toInt() : 0,
    );
  }
}

/// `agent:activity_state` (shared agentActivitySubscriptions.ts): the coarse
/// state of an agent this socket gets no detailed `agent:activity` for.
class AgentActivityStateEvent extends LiveEvent {
  const AgentActivityStateEvent({
    required this.agentId,
    required this.activity,
    this.state,
    this.timestamp,
    this.serverSeq,
  });
  static const name = 'agent:activity_state';
  final String agentId, activity;

  /// offline / online / busy / error.
  final String? state;
  final int? timestamp, serverSeq;

  static AgentActivityStateEvent? read(Object? payload) {
    if (payload is! Map) return null;
    final agentId = payload['agentId'], activity = payload['activity'];
    if (agentId is! String || activity is! String) return null;
    final state = payload['state'], ts = payload['timestamp'];
    final seq = payload['serverSeq'];
    return AgentActivityStateEvent(
      agentId: agentId,
      activity: activity,
      state: state is String ? state : null,
      timestamp: ts is num ? ts.toInt() : null,
      serverSeq: seq is num ? seq.toInt() : null,
    );
  }
}

/// `actor:updated` (Web localTables/actorResolve applyActorUpdatedEvent): an
/// agent of another server, seen here through a joint channel, changed its
/// display identity. Humans and malformed frames are dropped.
class ActorUpdatedEvent extends LiveEvent {
  const ActorUpdatedEvent({
    required this.kind,
    required this.id,
    required this.homeServerId,
    required this.displayName,
    required this.avatarUrl,
    required this.actorName,
  });
  static const name = 'actor:updated';
  final String kind, id, homeServerId, actorName;
  final String? displayName, avatarUrl;

  static ActorUpdatedEvent? read(Object? payload) {
    if (payload is! Map || payload['kind'] != 'agent') return null;
    final id = payload['id'], home = payload['homeServerId'];
    final actorName = payload['name'];
    if (id is! String ||
        !_uuid.hasMatch(id) ||
        home is! String ||
        !_uuid.hasMatch(home) ||
        actorName is! String ||
        !_nullableString(payload['displayName']) ||
        !_nullableString(payload['avatarUrl'])) {
      return null;
    }
    return ActorUpdatedEvent(
      kind: 'agent',
      id: id,
      homeServerId: home,
      actorName: actorName,
      displayName: payload['displayName'] as String?,
      avatarUrl: payload['avatarUrl'] as String?,
    );
  }
}

/// `user:profile-updated` (Web userProfileUpdated.ts): a person changed their
/// name or avatar; patch that member in place. `gravatarHash` is ignored.
class UserProfileUpdatedEvent extends LiveEvent {
  const UserProfileUpdatedEvent({
    required this.serverId,
    required this.userId,
    required this.userName,
    required this.displayName,
    required this.avatarUrl,
  });
  static const name = 'user:profile-updated';
  final String serverId, userId, userName;
  final String? displayName, avatarUrl;

  /// The fields a member row and the signed-in user take from it.
  Map<String, dynamic> get profile => {
    'name': userName,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
  };

  static UserProfileUpdatedEvent? read(Object? payload) {
    if (payload is! Map) return null;
    final serverId = payload['serverId'], userId = payload['userId'];
    final userName = payload['name'];
    if (serverId is! String ||
        !_uuid.hasMatch(serverId) ||
        userId is! String ||
        !_uuid.hasMatch(userId) ||
        userName is! String ||
        !_nullableString(payload['displayName']) ||
        !_nullableString(payload['avatarUrl'])) {
      return null;
    }
    return UserProfileUpdatedEvent(
      serverId: serverId,
      userId: userId,
      userName: userName,
      displayName: payload['displayName'] as String?,
      avatarUrl: payload['avatarUrl'] as String?,
    );
  }
}

/// `appearance:updated`: the member changed their theme for [serverId] on
/// another tab or device. `theme` null = the default theme.
class AppearanceUpdatedEvent extends LiveEvent {
  const AppearanceUpdatedEvent({
    required this.serverId,
    required this.theme,
    this.themeDecor,
  });
  static const name = 'appearance:updated';
  final String serverId;
  final String? theme;
  final bool? themeDecor;

  /// The server row patch (Web applyServerPatch).
  Map<String, dynamic> get patch => {'theme': theme, 'themeDecor': ?themeDecor};

  /// Web shared raftThemes.ts RAFT_THEME_IDS at v1.24.0-source.1.
  static const themeIds = {
    'raft',
    'boring',
    'bots',
    'critters',
    'space',
    'desk',
    'food',
    'quest',
    'weather',
    'plants',
    'spooky',
  };

  /// An unknown theme drops the frame (Web isRaftThemeId; [validTheme]
  /// overrides [themeIds]).
  static AppearanceUpdatedEvent? read(
    Object? payload, {
    bool Function(String id)? validTheme,
  }) {
    if (payload is! Map || payload['serverId'] is! String) return null;
    final theme = payload['theme'];
    if (theme != null &&
        (theme is! String || !(validTheme ?? themeIds.contains)(theme))) {
      return null;
    }
    final decor = payload['themeDecor'];
    return AppearanceUpdatedEvent(
      serverId: payload['serverId'] as String,
      theme: theme as String?,
      themeDecor: decor is bool ? decor : null,
    );
  }
}

/// `activity:changed` (shared activityObjectsContract.ts): this person's
/// Activity of [serverId] changed (object rows); read it again.
class ActivityChangedEvent extends LiveEvent {
  const ActivityChangedEvent(this.serverId, {this.source});
  static const name = 'activity:changed';
  final String serverId;
  final String? source;

  static ActivityChangedEvent? read(Object? payload) {
    if (payload is! Map || payload['serverId'] is! String) return null;
    final source = payload['source'];
    return ActivityChangedEvent(
      payload['serverId'] as String,
      source: source is String ? source : null,
    );
  }
}

/// `sync:changed` (spec §4.1a): the person's own read / Done / follow changed
/// elsewhere. Only a reminder to pull GET /sync/changes.
class SyncChangedEvent extends LiveEvent {
  const SyncChangedEvent();
  static const name = 'sync:changed';
}

/// `thread:reply_updated` (Web messageUpdatedApply applyThreadReplyUpdate): a
/// thread reply's content changed in place. Merge-only: it never inserts a
/// reply or changes counts.
class ThreadReplyUpdatedEvent extends LiveEvent {
  const ThreadReplyUpdatedEvent(this.message);
  static const name = 'thread:reply_updated';
  final Map<String, dynamic> message;

  String get channelId => message['channelId'] as String;
  String get id => message['id'] as String;

  static ThreadReplyUpdatedEvent? read(Object? payload) {
    if (payload is! Map ||
        payload['id'] is! String ||
        payload['channelId'] is! String) {
      return null;
    }
    return ThreadReplyUpdatedEvent(Map<String, dynamic>.from(payload));
  }
}

/// List-changed pings (shared listChangedEvents.ts): `{serverId}` only; the
/// list of that server changed, read it again if you read it at all.
class ListChangedEvent extends LiveEvent {
  const ListChangedEvent(this.event, this.serverId);
  static const permissionUpdates = 'permission-updates:changed';
  static const jointInvites = 'joint-invites:changed';
  static const seatJoinBlocks = 'seat-join-blocks:changed';
  static const events = [permissionUpdates, jointInvites, seatJoinBlocks];
  final String event, serverId;

  static ListChangedEvent? read(String event, Object? payload) {
    final serverId = payload is Map ? payload['serverId'] : null;
    if (serverId is! String || serverId.isEmpty) return null;
    return ListChangedEvent(event, serverId);
  }
}

/// `server:features-changed`: a feature flag of [serverId] changed; [keys]
/// is a hint of which ones.
class ServerFeaturesChangedEvent extends LiveEvent {
  const ServerFeaturesChangedEvent(this.serverId, this.keys);
  static const name = 'server:features-changed';
  final String serverId;
  final List<String> keys;

  /// Flags whose value changes what a list's server read returns (Web
  /// listChangedSocket LIST_GATING_FLAGS).
  static const listGatingFlags = {
    'pro_seat_add': ListChangedEvent.seatJoinBlocks,
    'app_prompt_text_consent': ListChangedEvent.permissionUpdates,
  };

  /// The list-changed pings this flag change stands for.
  Iterable<ListChangedEvent> get listPings => [
    for (final MapEntry(key: flag, value: event) in listGatingFlags.entries)
      if (keys.contains(flag)) ListChangedEvent(event, serverId),
  ];

  static ServerFeaturesChangedEvent? read(Object? payload) {
    final serverId = payload is Map ? payload['serverId'] : null;
    if (serverId is! String || serverId.isEmpty) return null;
    final keys = (payload as Map)['keys'];
    return ServerFeaturesChangedEvent(serverId, [
      if (keys is List) ...keys.whereType<String>(),
    ]);
  }
}
