import 'dart:collection';

import 'package:uuid/uuid.dart';

/// Keeps the wire contract intact, including projections newer than this client.
class RaftRecord {
  RaftRecord(Map<String, dynamic> value)
    : json = UnmodifiableMapView(Map.of(value));
  final Map<String, dynamic> json;
  String string(String key, [String fallback = '']) =>
      json[key]?.toString() ?? fallback;
  String get id => string('id');
  String get name => string('displayName', string('name'));
  bool flag(String key) => json[key] == true;
}

class RaftChannel extends RaftRecord {
  RaftChannel(super.value);
  String get type => string('type', 'channel');
  String get description => string('description');
  bool get archived => json['archivedAt'] != null;
  bool get joined =>
      json['joined'] == true ||
      json['isJoined'] == true ||
      json['membership'] != null ||
      type == 'dm';
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
