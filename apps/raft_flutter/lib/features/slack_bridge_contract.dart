/// Versioned Slack bridge projection. Invalid or newer contracts fail closed.
class SlackBridgeProjection {
  SlackBridgeProjection._(this.snapshot, this.oauthAuthority);
  final Map<String, dynamic> snapshot;
  final Map<String, dynamic>? oauthAuthority;
  String get stage => snapshot['stage'] as String;
  List<Map<String, dynamic>> rows(String key) =>
      (snapshot[key] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic> get health =>
      snapshot['rawHealth'] as Map<String, dynamic>? ?? const {};
  List<Map<String, dynamic>> healthRows(String key) =>
      health.containsKey(key) ? _list(health[key], max: 5000) : const [];
  bool get preflightPassed {
    final preflight = snapshot['preflight'] as Map<String, dynamic>?;
    if (preflight == null || preflight['state'] != 'passed') return false;
    final checks = (preflight['checks'] as List).cast<Map<String, dynamic>>();
    return checks.length == 4 &&
        checks.every((c) => c['state'] == 'passed') &&
        checks.map((c) => c['id']).toSet().containsAll(_checks);
  }

  int? get connectionEpoch {
    final install = health['install'] as Map<String, dynamic>?;
    final raw = install?['epochs']['connection'];
    final value = raw is String ? num.tryParse(raw) : null;
    return value != null &&
            value > 0 &&
            value <= _maxInteger &&
            value == value.roundToDouble()
        ? value.toInt()
        : null;
  }

  /// The `agentMentionSync` hint: Raft members Slack's @ menu could not list.
  /// Mention sync is an enhancement, never a delivery problem (a typed unique
  /// @name still reaches the member), so the hint shows only when an admin can
  /// act on it. A free Slack plan and transient failures (no Slack error; the
  /// next tick retries) show nothing.
  ({String source, int count, String code})? get mentionSyncHint {
    final sync = health['agentMentionSync'] as Map<String, dynamic>?;
    if (sync == null || sync['state'] != 'degraded') return null;
    final error = sync['slackError'] as String?;
    if (error == null || _silentMentionErrors.contains(error)) return null;
    final count = [
      1,
      (sync['expected'] as int) - (sync['actual'] as int),
    ].reduce((a, b) => a > b ? a : b);
    return (
      source: switch (error) {
        'restricted_action' || 'permission_denied' => _mentionRestricted,
        'missing_scope' => _mentionMissingScope,
        'name_taken' => count == 1 ? _mentionNameTakenOne : _mentionNameTaken,
        _ => _mentionGeneric,
      },
      count: count,
      code: error,
    );
  }

  /// Exact precedence from the enabled Web health projection.
  String get healthReason {
    final install = health['install'] as Map<String, dynamic>?;
    if (install == null) return 'install_missing';
    switch (install['state']) {
      case 'pending':
        return 'oauth_pending';
      case 'reauth_required':
        return 'reauth_required';
      case 'disconnected':
      case 'revoked':
        return 'disconnected';
      case 'quarantined':
        return 'quarantined';
    }
    final credential = health['credential'] as Map<String, dynamic>?;
    if (credential == null) return 'credential_missing';
    if (credential['state'] == 'revoked') return 'credential_revoked';
    if (credential['state'] == 'persist_unknown') {
      return 'credential_unverified';
    }
    final bindings = (health['bindings'] as List).cast<Map<String, dynamic>>();
    if (bindings.isEmpty) return 'binding_required';
    for (final state in ['quarantined', 'revoked', 'paused']) {
      if (bindings.any((b) => b['state'] == state)) return 'binding_$state';
    }
    final audiences = (health['audiences'] as List)
        .cast<Map<String, dynamic>>();
    if (audiences.any((a) => a['status'] == 'mismatch')) {
      return 'audience_mismatch';
    }
    if (bindings.any(
      (b) => !audiences.any(
        (a) => a['bindingId'] == b['id'] && a['status'] == 'matched',
      ),
    )) {
      return 'audience_unverified';
    }
    if (healthRows('outboundDeliveries').isNotEmpty ||
        health['failingSurface'] == 'delivery') {
      return 'delivery_blocked';
    }
    if (health['failingSurface'] != null) {
      return '${health['failingSurface']}_unverified';
    }
    if (health['lastVerifiedAt'] == null) return 'verification_required';
    return 'healthy';
  }

  static SlackBridgeProjection parse(dynamic value) {
    final response = _object(value, {
      'protocolVersion',
      'snapshot',
      'oauthAuthority',
    });
    _require(response['protocolVersion'] == 1);
    final s = _object(
      response['snapshot'],
      {
        'stage',
        'workspaceName',
        'raftChannels',
        'slackChannels',
        'channelPairs',
        'preflight',
        'rawHealth',
      },
      optional: {'needsSlackReauthorization'},
    );
    if (s.containsKey('needsSlackReauthorization')) {
      _require(s['needsSlackReauthorization'] is bool);
    }
    _enum(s['stage'], {
      'connect',
      'oauth',
      'channels',
      'preflight',
      'enable',
      'health',
    });
    _text(s['workspaceName'], 200, nullable: true);
    final raft = _list(s['raftChannels']);
    final slack = _list(s['slackChannels']);
    for (final c in raft) {
      _object(c, {'id', 'name'});
      _text(c['id'], 256);
      _text(c['name'], 200);
    }
    for (final c in slack) {
      _object(c, {'id', 'name'}, optional: {'privacyClass', 'isMember'});
      _text(c['id'], 256);
      _text(c['name'], 200);
      if (c.containsKey('privacyClass')) {
        _enum(c['privacyClass'], {'public', 'private'});
      }
      if (c.containsKey('isMember')) _require(c['isMember'] is bool);
    }
    _unique(raft, 'id');
    _unique(slack, 'id');
    final pairs = _list(s['channelPairs']);
    for (final p in pairs) {
      _object(
        p,
        {'raftChannelId', 'slackChannelId'},
        optional: {'bindingEpoch', 'invalidReason'},
      );
      _require(
        raft.any((c) => c['id'] == p['raftChannelId']) &&
            slack.any((c) => c['id'] == p['slackChannelId']),
      );
      if (p.containsKey('bindingEpoch')) _integer(p['bindingEpoch']);
      if (p.containsKey('invalidReason')) {
        _enum(p['invalidReason'], {
          'privacy_mismatch',
          'not_member',
          'channel_unavailable',
          'provider_unavailable',
        });
      }
    }
    _unique(pairs, 'raftChannelId');
    _unique(pairs, 'slackChannelId');
    if (s['preflight'] != null) {
      final p = _object(s['preflight'], {'state', 'checks'});
      _enum(p['state'], {'pending', 'passed', 'failed'});
      final checks = _list(p['checks'], max: 4);
      for (final c in checks) {
        _object(c, {'id', 'state'});
        _enum(c['id'], _checks);
        _enum(c['state'], {'passed', 'failed', 'unverified'});
      }
      _unique(checks, 'id');
      if (p['state'] == 'passed') {
        _require(
          checks.length == 4 && checks.every((c) => c['state'] == 'passed'),
        );
      }
    }
    if (s['rawHealth'] != null) _validateHealth(s['rawHealth']);
    Map<String, dynamic>? authority;
    if (response['oauthAuthority'] != null) {
      authority = _object(response['oauthAuthority'], {
        'registrationId',
        'serverGrantId',
        'grantEpoch',
      });
      final uuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      _require(
        uuid.hasMatch('${authority['registrationId']}') &&
            uuid.hasMatch('${authority['serverGrantId']}'),
      );
      _integer(authority['grantEpoch']);
    }
    return SlackBridgeProjection._(s, authority);
  }

  static void _validateHealth(dynamic value) {
    final h = _object(
      value,
      {
        'install',
        'credential',
        'bindings',
        'audiences',
        'lastVerifiedAt',
        'failingSurface',
      },
      optional: {
        'agentMentionSync',
        'attachmentSourceIssues',
        'outboundDeliveries',
        'outboundPairBlocks',
        'cardEditNotices',
        'inboundIsolated',
        'inboundIsolatedSummary',
        'inboundIsolatedGroups',
      },
    );
    if (h['agentMentionSync'] != null) {
      final m = _object(h['agentMentionSync'], {
        'state',
        'slackError',
        'expected',
        'actual',
        'observedAt',
      });
      _enum(m['state'], {'synced', 'degraded'});
      _text(m['slackError'], 160, nullable: true);
      _require(
        m['expected'] is int &&
            m['expected'] >= 0 &&
            m['actual'] is int &&
            m['actual'] >= 0,
      );
      _date(m['observedAt']);
    }
    if (h['install'] != null) {
      final i = _object(h['install'], {'state', 'epochs'});
      _enum(i['state'], {
        'pending',
        'active',
        'reauth_required',
        'disconnected',
        'revoked',
        'quarantined',
      });
      final epochs = _object(i['epochs'], {
        'grant',
        'connection',
        'scope',
        'credential',
      });
      for (final e in epochs.values) {
        _require(e is String);
      }
    }
    if (h['credential'] != null) {
      _enum(_object(h['credential'], {'state'})['state'], {
        'active',
        'persist_unknown',
        'revoked',
      });
    }
    final bindings = _list(h['bindings']);
    for (final b in bindings) {
      _object(b, {
        'id',
        'state',
        'bindingEpoch',
        'stateReason',
        'recoveryAction',
      });
      _text(b['id'], 256);
      _integer(b['bindingEpoch']);
      _text(b['stateReason'], 160, nullable: true);
      _enum(b['state'], {'active', 'paused', 'revoked', 'quarantined'});
      _enum(b['recoveryAction'], {
        'none',
        'unarchive_slack_channel',
        'select_replacement_slack_channel',
        'reinstall_slack_app',
        'reauthorize_slack_app',
        'migrate_slack_channel_audience',
        'review_and_resume_binding',
      });
    }
    _unique(bindings, 'id');
    final audiences = _list(h['audiences']);
    for (final a in audiences) {
      _object(a, {'bindingId', 'status'});
      _enum(a['status'], {'matched', 'mismatch', 'unavailable'});
      _require(bindings.any((b) => b['id'] == a['bindingId']));
    }
    _unique(audiences, 'bindingId');
    _date(h['lastVerifiedAt'], nullable: true);
    if (h['failingSurface'] != null) {
      _enum(h['failingSurface'], {
        'install',
        'credential',
        'binding',
        'audience',
        'connection',
        'scope',
        'delivery',
      });
    }
    _validateRecovery(h, bindings);
  }

  static String oauthUrl(dynamic value) {
    final v = _object(value, {'authorizationUrl', 'expiresAt'});
    final uri = v['authorizationUrl'] is String
        ? Uri.tryParse(v['authorizationUrl'])
        : null;
    _require(
      uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty,
    );
    _date(v['expiresAt']);
    return v['authorizationUrl'] as String;
  }
}

void _validateRecovery(
  Map<String, dynamic> health,
  List<Map<String, dynamic>> bindings,
) {
  List<Map<String, dynamic>> rows(String key, {int max = 500}) =>
      health.containsKey(key) ? _list(health[key], max: max) : const [];
  for (final issue in rows('attachmentSourceIssues')) {
    _object(issue, {'raftChannelId', 'reason'});
    _text(issue['raftChannelId'], 256);
    _enum(issue['reason'], {'unavailable', 'size_mismatch'});
  }
  for (final delivery in rows('outboundDeliveries')) {
    _object(delivery, {
      'raftChannelId',
      'bindingId',
      'bindingEpoch',
      'deliveryId',
      'providerAttempts',
      'state',
      'retryRequested',
    });
    _text(delivery['raftChannelId'], 256);
    _text(delivery['bindingId'], 256);
    _text(delivery['deliveryId'], 256);
    _integer(delivery['bindingEpoch']);
    _integer(delivery['providerAttempts']);
    _enum(delivery['state'], {'dead', 'outcome_unknown', 'retry_wait'});
    _require(delivery['retryRequested'] is bool);
  }
  const reasons = {
    'connection',
    'credentials',
    'configuration',
    'invite_app',
    'reauthorize',
    'unarchive',
    'check_channel',
  };
  for (final block in rows('outboundPairBlocks')) {
    _object(
      block,
      {'raftChannelId', 'bindingId', 'since', 'nextRetryAt', 'reason'},
      optional: {'action', 'detail'},
    );
    _text(block['raftChannelId'], 256);
    _text(block['bindingId'], 256);
    _date(block['since']);
    _date(block['nextRetryAt'], nullable: true);
    _enum(block['reason'], reasons);
    if (block.containsKey('action')) {
      _require(block['action'] == 'workspace_admin');
    }
    if (block.containsKey('detail')) {
      _enum(block['detail'], {
        'history_limited',
        'metadata_missing',
        'marker_unconfirmed',
      });
    }
  }
  for (final card in rows('cardEditNotices', max: 2000)) {
    _object(
      card,
      {'raftChannelId', 'bindingId', 'kind', 'since'},
      optional: {'reason'},
    );
    _text(card['raftChannelId'], 256);
    _text(card['bindingId'], 256);
    _date(card['since']);
    _enum(card['kind'], {
      'not_confirmed',
      'latest_update_not_shown',
      'updates_cannot_be_shown',
      'edit_waiting',
    });
    if (card.containsKey('reason')) _enum(card['reason'], reasons);
  }
  if (health.containsKey('inboundIsolatedSummary')) {
    final summary = _object(health['inboundIsolatedSummary'], {
      'count',
      'oldestFirstFailureAt',
      'undisplayed',
    });
    for (final count in [summary['count'], summary['undisplayed']]) {
      _require(count is int && count >= 0 && count <= _maxInteger);
    }
    _date(summary['oldestFirstFailureAt'], nullable: true);
  }
  final events = rows('inboundIsolated');
  final groups = rows('inboundIsolatedGroups', max: 5000);
  const scope = {'raftChannelId', 'bindingId', 'bindingEpoch', 'reason'};
  for (final event in events) {
    _object(event, {...scope, 'eventId', 'firstFailureAt', 'heldAt'});
    _text(event['eventId'], 256);
    _date(event['firstFailureAt'], nullable: true);
    _date(event['heldAt'], nullable: true);
  }
  _unique(events, 'eventId');
  for (final group in groups) {
    _object(group, {...scope, 'count'});
    _integer(group['count']);
  }
  final reason = RegExp(r'^[a-z][a-z0-9_]{0,159}$');
  for (final row in [...events, ...groups]) {
    _text(row['raftChannelId'], 256);
    _require(row['reason'] is String && reason.hasMatch(row['reason']));
    _require(
      bindings.any(
        (binding) =>
            binding['id'] == row['bindingId'] &&
            binding['bindingEpoch'] == row['bindingEpoch'],
      ),
    );
  }
}

const _checks = {'oauth', 'endpoint', 'scope', 'audience'};
const _silentMentionErrors = {'paid_only', 'paid_teams_only'};
const _mentionLead =
    "Messages sync normally, and typing a Raft member's @name in Slack still reaches them when no one else in the channel has that name.";
const _mentionRestricted =
    "$_mentionLead To also list them in Slack's @ menu, a Slack admin needs to let members create user groups: Workspace settings \u2192 Permissions \u2192 User groups.";
const _mentionMissingScope =
    "$_mentionLead To also list them in Slack's @ menu, Raft needs one more Slack permission: use \u201cUpdate Slack authorization\u201d below.";
const _mentionNameTakenOne =
    "$_mentionLead {count} member couldn't get an entry in Slack's @ menu because every name Raft tried is already used in Slack. Renaming them in Raft, or freeing the name in Slack, fixes it.";
const _mentionNameTaken =
    "$_mentionLead {count} members couldn't get an entry in Slack's @ menu because every name Raft tried is already used in Slack. Renaming them in Raft, or freeing the name in Slack, fixes it.";
const _mentionGeneric =
    "$_mentionLead Slack refused to list some of them in its @ menu ({code}); Raft keeps retrying.";
const _maxInteger = 9007199254740991;
Never _invalid() => throw const FormatException(
  'The Slack bridge response is unsupported or incomplete. Refresh or contact your administrator.',
);
void _require(bool condition) {
  if (!condition) _invalid();
}

Map<String, dynamic> _object(
  dynamic value,
  Set<String> required, {
  Set<String> optional = const {},
}) {
  _require(value is Map<String, dynamic>);
  final map = value as Map<String, dynamic>;
  _require(
    map.keys.toSet().containsAll(required) &&
        map.keys.every((k) => required.contains(k) || optional.contains(k)),
  );
  return map;
}

List<Map<String, dynamic>> _list(dynamic value, {int max = 500}) {
  _require(
    value is List &&
        value.length <= max &&
        value.every((v) => v is Map<String, dynamic>),
  );
  return (value as List).cast<Map<String, dynamic>>();
}

void _unique(List<Map<String, dynamic>> values, String key) =>
    _require(values.map((v) => v[key]).toSet().length == values.length);
void _enum(dynamic value, Set<String> values) =>
    _require(values.contains(value));
void _integer(dynamic value) =>
    _require(value is int && value > 0 && value <= _maxInteger);
void _text(dynamic value, int max, {bool nullable = false}) => _require(
  (nullable && value == null) ||
      (value is String && value.trim().isNotEmpty && value.length <= max),
);
void _date(dynamic value, {bool nullable = false}) => _require(
  (nullable && value == null) ||
      (value is String &&
          RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value) &&
          DateTime.tryParse(value) != null),
);
