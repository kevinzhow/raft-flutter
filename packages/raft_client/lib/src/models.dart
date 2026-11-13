import 'dart:collection';

import 'package:uuid/uuid.dart';

import 'wire_fields.dart';

/// Keeps the wire contract intact, including projections newer than this client.
class RaftRecord {
  RaftRecord(Map<String, dynamic> value)
    : json = UnmodifiableMapView(Map.of(value));
  final Map<String, dynamic> json;
  String string(String key, [String fallback = '']) =>
      json[key]?.toString() ?? fallback;
  String get id => string('id');

  /// First non-empty string among [keys] (Web's `a || b || c`). A null and an
  /// empty string both mean "missing"; `string(k, fallback)` only skips null.
  String firstNonEmpty(Iterable<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = json[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  /// Web shows `displayName || name`; a stored empty displayName must not blank the title.
  String get name => firstNonEmpty(const ['displayName', 'name']);
  bool flag(String key) => json[key] == true;
}

class RaftChannel extends RaftRecord {
  RaftChannel(super.value);
  String get type => string('type', 'channel');
  String get description => string('description');
  bool get archived => json['archivedAt'] != null;

  /// DM label as Web shows it: `peerDisplayName || peerName || name`.
  String get peerLabel => firstNonEmpty(const [
    'peerDisplayName',
    'peerName',
    'displayName',
    'name',
  ]);

  /// `bridge.provider` of a bridged channel (`slack`), else null.
  String? get bridgeProvider => switch (json['bridge']) {
    {'provider': final String provider} => provider,
    _ => null,
  };
  bool get joined =>
      json['joined'] == true ||
      json['isJoined'] == true ||
      json['membership'] != null ||
      type == 'dm';

  /// The member's explicit notification level here; null = the default
  /// (also from an older server).
  RaftNotificationLevel? get notificationLevel =>
      RaftNotificationLevel.parse(json['notificationLevel']);

  /// Signed-out visitors of the server's public page can read it. Older
  /// servers (and v1.24, for one release) send the `guestVisible` mirror.
  bool get visitorVisible =>
      json['visitorVisible'] == true ||
      !json.containsKey('visitorVisible') && json['guestVisible'] == true;

  /// The channel has a Guest or an open external invite. Sent only to its
  /// own server's non-guest members; null when the row did not say.
  bool? get hasExternalRelation => switch (json['hasExternalRelation']) {
    final bool value => value,
    _ => null,
  };

  /// Agent Lounge v0: the agent this channel is the Lounge of.
  String? get loungeAgentId => switch (json['loungeAgentId']) {
    final String id when id.isNotEmpty => id,
    _ => null,
  };

  /// Agent Lounge v0: false = may read, not post. Absent = may post.
  bool get canPost => json['canPost'] != false;

  /// Agent Lounge v0, on an agent DM row: that agent's Lounge, once it exists.
  ({String channelId, bool joined, int unreadCount, int mentionCount})?
  get lounge => switch (json['lounge']) {
    {'channelId': final String channelId} && final Map lounge
        when channelId.isNotEmpty =>
      (
        channelId: channelId,
        joined: lounge['joined'] == true,
        unreadCount: (lounge['unreadCount'] as num?)?.toInt() ?? 0,
        mentionCount: (lounge['mentionCount'] as num?)?.toInt() ?? 0,
      ),
    _ => null,
  };

  /// A bridged channel's binding (`bridge`), null when it is not bridged.
  RaftChannelBridge? get bridge => switch (json['bridge']) {
    {'provider': final String _} && final Map bridge => RaftChannelBridge(
      Map<String, dynamic>.from(bridge),
    ),
    _ => null,
  };
}

/// `Channel.bridge` (web store/channelStore.ts at v1.24.0): the Slack binding
/// and, while Raft messages for Slack are held, why.
extension type RaftChannelBridge(Map<String, dynamic> json) {
  String get provider => json['provider'] as String? ?? '';
  String get providerConversationId =>
      json['providerConversationId'] as String? ?? '';

  /// `active`, `paused` or `quarantined`.
  String get state => json['state'] as String? ?? 'active';

  /// Why sync stopped; present only while the binding is not active.
  String? get stateReason => json['stateReason'] as String?;

  /// `waiting` or `stalled` while Raft messages for Slack are held, else null.
  String? get outboundStatus => switch (json['outbound']) {
    {'status': final String status} => status,
    _ => null,
  };

  /// While waiting: `connection`, `credentials`, `configuration`,
  /// `invite_app`, `reauthorize`, `unarchive` or `check_channel`.
  String? get outboundReason => switch (json['outbound']) {
    {'reason': final String reason} => reason,
    _ => null,
  };

  /// Why Raft cannot yet confirm the held message reached Slack.
  String? get outboundDetail => switch (json['outbound']) {
    {'detail': final String detail} => detail,
    _ => null,
  };
  DateTime? get outboundSince => switch (json['outbound']) {
    {'since': final String since} => DateTime.tryParse(since),
    _ => null,
  };

  /// The installation's state, present only while it is not active.
  String? get installState => json['installState'] as String?;
}

class RaftMessage extends RaftRecord {
  RaftMessage(super.value);
  String get channelId => string('channelId');
  String get content => string('content');
  String get author => string(
    'senderDisplayName',
    string('senderName', string('senderType', 'System')),
  );
  String get senderId => string('senderId');
  String? get threadId => json['threadId'] as String?;
  BigInt get seq => BigInt.tryParse(string('seq')) ?? BigInt.zero;
  DateTime? get createdAt => DateTime.tryParse(string('createdAt'));

  /// Absent from older servers.
  DateTime? get updatedAt => DateTime.tryParse(string('updatedAt'));

  /// RFC 077: when the owner retracted this delegated message, else null.
  DateTime? get deletedAt => DateTime.tryParse(string('deletedAt'));
  bool get retracted => switch (json['deletedAt']) {
    final String at => at.isNotEmpty,
    _ => false,
  };
  List<Map<String, dynamic>> get attachments =>
      ((json['attachments'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
}

class Session {
  Session({
    required this.accessToken,
    required this.refreshToken,
    String? installationId,
    this.refreshAttemptId,
    this.cachedUser,
  }) : installationId =
           installationId ?? 'ari_${const Uuid().v4().replaceAll('-', '')}';
  final String accessToken;
  final String refreshToken;
  final String installationId;
  final String? refreshAttemptId;
  final Map<String, dynamic>? cachedUser;
  Session withAttempt(String attempt) => Session(
    accessToken: accessToken,
    refreshToken: refreshToken,
    installationId: installationId,
    refreshAttemptId: attempt,
    cachedUser: cachedUser,
  );

  /// A sign-in answer's session, or null when it carries no tokens (a
  /// two-step verification challenge, or a shape this client cannot read).
  static Session? tryFromJson(Map json) {
    final access = json['accessToken'], refresh = json['refreshToken'];
    if (access is! String || access.isEmpty) return null;
    if (refresh is! String || refresh.isEmpty) return null;
    return Session.fromJson(Map<String, dynamic>.from(json));
  }

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    installationId: json['installationId'] as String?,
    refreshAttemptId: json['refreshAttemptId'] as String?,
    cachedUser: json['user'] is Map
        ? Map<String, dynamic>.from(json['user'])
        : null,
  );
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'installationId': installationId,
    if (refreshAttemptId != null) 'refreshAttemptId': refreshAttemptId,
    if (cachedUser != null) 'user': cachedUser,
  };
  @override
  String toString() => 'Session(redacted)';
}
