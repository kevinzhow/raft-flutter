// Account connections of a cloud agent (Web `AgentConnections.tsx`, shared
// `AgentConnectionStatusView`; raft-agent-provider.v1 connections extension).
// The provider runs the OAuth flow and keeps the token: Raft only starts it,
// reads status, assigns a connector and disconnects. GitHub is the only
// provider. Nothing here reads the network.
import 'package:raft_client/raft_client.dart';

const agentConnectionProvider = 'github';

/// `AGENT_MISSING_AT_PROVIDER_CODE`.
const agentMissingAtProviderCode = 'agent_connection_agent_missing_at_provider';

/// `CONNECTOR_DISCONNECT_PARTIAL_CODE`.
const connectorDisconnectPartialCode =
    'agent_connection_connector_disconnect_partial';

/// `agentConnectionPath`.
String agentConnectionPath(String agentId, [String provider = 'github']) =>
    '/agents/${Uri.encodeComponent(agentId)}/connections/$provider';

/// `agentConnectorPath`: a tenant connector, addressed through an agent the
/// caller manages.
String agentConnectorPath(
  String agentId,
  String connectorId, [
  String provider = 'github',
]) =>
    '${agentConnectionPath(agentId, provider)}/connectors/${Uri.encodeComponent(connectorId)}';

/// `DISCONNECT_NOT_CLEARED_CODE`: removing this agent's connection did not
/// take (its mount still holds the credential); the same removal again
/// completes it.
const disconnectNotClearedCode = 'agent_connection_disconnect_not_cleared';

/// `PROVIDER_REFUSED_CODE`: the generic provider refusal (409).
const providerRefusedCode = 'agent_connection_provider_refused';

/// `CONNECTOR_NOT_FOUND_CODE`: the connection was disconnected meanwhile.
const connectorNotFoundCode = 'agent_connection_connector_not_found';

/// `CONNECTOR_FORBIDDEN_CODE`: only its creator or a server owner/admin may
/// change it.
const connectorForbiddenCode = 'agent_connection_connector_forbidden';

/// `OWNER_REQUIRED_CODE`.
const connectionOwnerRequiredCode = 'agent_connection_owner_required';

/// `GITHUB_AUTHORIZED_APPS_URL`: where a GitHub account's authorizations of
/// apps are revoked.
final githubAuthorizedAppsUrl = Uri.parse(
  'https://github.com/settings/applications',
);

/// The server `code` of a failed call, if any.
String? connectionErrorCode(Object? error) {
  if (error is! RaftApiException) return null;
  final code = error.details['code'];
  return code is String ? code : null;
}

/// The provider's own words about a refusal: under the refusal envelope's
/// `details`, or top level as a server from before it wrote them (its 502s
/// still do). Web `providerRefusalFields`.
Object? _refusalField(Object? error, String key) {
  if (error is! RaftApiException) return null;
  final nested = error.details['details'];
  if (nested is Map && nested[key] != null) return nested[key];
  return error.details[key];
}

/// `providerRefusalReason`: the provider's own reason for refusing (for
/// example "the agent needs exactly one GitHub plugin mount"), if any.
String? providerRefusalReason(Object? error) {
  final message = _refusalField(error, 'providerMessage');
  return message is String && message.trim().isNotEmpty ? message : null;
}

/// `providerRefusalSentence`: the generic refusal's `error` sentence when it
/// reads as one, else the provider's reason. Null for any other error.
String? providerRefusalSentence(Object? error) {
  if (connectionErrorCode(error) != providerRefusedCode) return null;
  final raftError = error as RaftApiException;
  final sentence = raftError.structured ? raftError.message.trim() : '';
  return sentence.isNotEmpty ? sentence : providerRefusalReason(error);
}

/// `refusalDetails`: "{status} {code}: {message}", for Copy details only
/// (never rendered).
String? refusalDetails(Object? error) {
  if (error is! RaftApiException) return null;
  final status = _refusalField(error, 'providerStatus');
  final code = _refusalField(error, 'providerCode');
  final head = [
    if (status is num) '${status.toInt()}',
    if (code is String && code.isNotEmpty) code,
  ].join(' ');
  final text = [
    if (head.isNotEmpty) head,
    ?providerRefusalReason(error),
  ].join(': ');
  return text.isEmpty ? null : text;
}

/// `saysRevokeOnGithub`: the server's word (a removal's 200 body, or the
/// partial disconnect's 502) that a copy of the credential is out of reach and
/// only revoking on GitHub takes it back.
bool saysRevokeOnGithub(Object? body) {
  if (body is RaftApiException) return body.details['revokeOnGithub'] == true;
  return body is Map && body['revokeOnGithub'] == true;
}

/// What a GitHub connection can do, from the OAuth scopes the provider
/// recorded (Web `describeGithubAccess`). [access] is `private` (`repo`),
/// `public` (`public_repo` only) or null (not recorded, `[]` or no repository
/// scope); [short] is what was requested and not granted; [granted] is the raw
/// list, for a tooltip only.
class GithubAccess {
  const GithubAccess({this.access, this.short = const [], this.granted});
  final String? access;
  final List<String> short;
  final List<String>? granted;
}

bool _covers(List<String> granted, String scope) {
  if (granted.contains(scope)) return true;
  if ((scope == 'public_repo' || scope.startsWith('repo:')) &&
      granted.contains('repo')) {
    return true;
  }
  final read = RegExp(r'^read:(.+)$').firstMatch(scope);
  return read != null &&
      (granted.contains('write:${read[1]}') ||
          granted.contains('admin:${read[1]}'));
}

GithubAccess describeGithubAccess(
  List<String>? scopes,
  List<String>? requestedScopes,
) {
  if (scopes == null) return const GithubAccess();
  // `[]` says nothing either way: a GitHub App user token has no OAuth scopes
  // and still works.
  if (scopes.isEmpty) return GithubAccess(granted: scopes);
  final access = scopes.contains('repo')
      ? 'private'
      : scopes.contains('public_repo')
      ? 'public'
      : null;
  return GithubAccess(
    access: access,
    short: [
      if (requestedScopes != null)
        for (final s in requestedScopes)
          if (!_covers(scopes, s)) s,
    ],
    granted: scopes,
  );
}

List<String>? _scopeList(Object? v) => v is List
    ? [
        for (final s in v)
          if (s is String) s,
      ]
    : null;

String? _text(Object? v) => v is String && v.isNotEmpty ? v : null;

/// One tenant-level (per server) connection; no token is ever part of it.
class AgentConnector {
  const AgentConnector({
    required this.id,
    required this.account,
    required this.current,
    required this.canManage,
    required this.creatorName,
    this.oauthStatus,
    this.lastCheckError,
    this.lastCheckedAt,
    this.scopes,
    this.requestedScopes,
    this.assignable,
    this.createdAt,
  });

  final String id;
  final String? account;

  /// The agent currently uses this connector.
  final bool current;

  /// Its creator or a server owner/admin may assign it and disconnect it.
  final bool canManage;

  /// `creator.displayName ?? creator.name` (Web `creatorLabel`); null when not
  /// a member here.
  final String? creatorName;

  /// The provider's own word on the OAuth token: `error` means it needs
  /// reconnecting.
  final String? oauthStatus;
  final String? lastCheckError, lastCheckedAt, createdAt;

  /// Granted and requested scopes; null when the provider did not report them.
  final List<String>? scopes, requestedScopes;

  /// False when the viewer may not point an agent at it (Web only blocks the
  /// explicit `false`).
  final bool? assignable;

  bool get canAssign => canManage && assignable != false;

  /// The connect flow asked for private repositories last time (or GitHub
  /// granted them): Reconnect asks again (Web `wantsPrivate`).
  bool get wantsPrivate =>
      (requestedScopes?.contains('repo') ?? false) ||
      (scopes?.contains('repo') ?? false);

  static AgentConnector? parse(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    final creator = json['creator'];
    return AgentConnector(
      id: json['id'] as String,
      account: _text(json['account']),
      current: json['current'] == true,
      canManage: json['canManage'] == true,
      creatorName: creator is Map
          ? _text(creator['displayName']) ?? _text(creator['name'])
          : null,
      oauthStatus: _text(json['oauthStatus']),
      lastCheckError: _text(json['lastCheckError']),
      lastCheckedAt: _text(json['lastCheckedAt']),
      scopes: _scopeList(json['scopes']),
      requestedScopes: _scopeList(json['requestedScopes']),
      assignable: json['assignable'] is bool
          ? json['assignable'] as bool
          : null,
      createdAt: _text(json['createdAt']),
    );
  }
}

/// The `supported: true` arm of `AgentConnectionStatusView`
/// (`GET /agents/:id/connections/github`).
class AgentConnectionStatus {
  const AgentConnectionStatus({
    required this.connected,
    required this.account,
    required this.connectedAt,
    required this.connectedByName,
    required this.scopes,
    required this.connectorId,
    required this.connectors,
    this.requestedScopes,
    this.oauthStatus,
    this.lastCheckError,
    this.lastCheckedAt,
    this.canConnectNew = true,
  });

  final bool connected;
  final String? account, connectedAt, connectedByName, connectorId;
  final List<String> scopes;
  final List<AgentConnector> connectors;

  /// What the connect flow asked for, when reported (an older provider has no
  /// connector list; the status itself says).
  final List<String>? requestedScopes;
  final String? oauthStatus, lastCheckError, lastCheckedAt;

  /// Only the agent's owner may connect a new account (`canConnectNew !==
  /// false`, so an older server that does not send it allows it).
  final bool canConnectNew;

  /// The connector this agent uses, when connected.
  AgentConnector? get current {
    if (!connected) return null;
    for (final c in connectors) {
      if (c.id == connectorId) return c;
    }
    for (final c in connectors) {
      if (c.current) return c;
    }
    return null;
  }

  /// The connection this agent points at, also while it needs reconnecting
  /// (`connected` is false then).
  AgentConnector? get attached {
    final c = current;
    if (c != null) return c;
    for (final c in connectors) {
      if (c.current) return c;
    }
    return null;
  }

  /// "Needs reconnecting" is the provider's `oauthStatus`, never a refusal.
  bool get needsReconnect =>
      oauthStatus == 'error' || attached?.oauthStatus == 'error';

  /// `null` for `supported: false` (the provider serves no connections) and
  /// for a shape this client does not know.
  static AgentConnectionStatus? parse(Object? json) {
    if (json is! Map || json['supported'] != true) return null;
    final by = json['connectedBy'];
    return AgentConnectionStatus(
      connected: json['connected'] == true,
      account: _text(json['account']),
      connectedAt: _text(json['connectedAt']),
      connectedByName: by is Map ? _text(by['name']) ?? _text(by['id']) : null,
      scopes: _scopeList(json['scopes']) ?? const [],
      requestedScopes: _scopeList(json['requestedScopes']),
      oauthStatus: _text(json['oauthStatus']),
      lastCheckError: _text(json['lastCheckError']),
      lastCheckedAt: _text(json['lastCheckedAt']),
      canConnectNew: json['canConnectNew'] != false,
      connectorId: _text(json['connectorId']),
      connectors: [
        if (json['connectors'] is List)
          for (final c in json['connectors'] as List) ?AgentConnector.parse(c),
      ],
    );
  }
}

/// `AgentConnectionStartView`: the one-time provider URL the browser opens.
class AgentConnectionStart {
  const AgentConnectionStart({required this.url, required this.scopes});
  final Uri url;
  final List<String> scopes;

  /// Only an `https` or `http` address is opened; anything else is no start.
  static AgentConnectionStart? parse(Object? json) {
    if (json is! Map || json['url'] is! String) return null;
    final url = Uri.tryParse(json['url'] as String);
    if (url == null || !const {'https', 'http'}.contains(url.scheme)) {
      return null;
    }
    return AgentConnectionStart(
      url: url,
      scopes: [
        if (json['scopes'] is List)
          for (final s in json['scopes'] as List)
            if (s is String) s,
      ],
    );
  }
}
