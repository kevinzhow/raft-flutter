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

/// The server `code` of a failed call, if any.
String? connectionErrorCode(Object? error) {
  if (error is! RaftApiException) return null;
  final code = error.details['code'];
  return code is String ? code : null;
}

/// `providerRefusalReason`: the provider's own reason for refusing (for
/// example "the agent needs exactly one GitHub plugin mount"), if any.
String? providerRefusalReason(Object? error) {
  if (error is! RaftApiException) return null;
  final message = error.details['providerMessage'];
  return message is String && message.trim().isNotEmpty ? message : null;
}

/// One tenant-level (per server) connection; no token is ever part of it.
class AgentConnector {
  const AgentConnector({
    required this.id,
    required this.account,
    required this.current,
    required this.canManage,
    required this.creatorName,
  });

  final String id;
  final String? account;

  /// The agent currently uses this connector.
  final bool current;

  /// Its creator or a server owner/admin may assign it and disconnect it.
  final bool canManage;

  /// `creator.name ?? creator.displayName`; null when not a member here.
  final String? creatorName;

  static AgentConnector? parse(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    final creator = json['creator'];
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    return AgentConnector(
      id: json['id'] as String,
      account: text(json['account']),
      current: json['current'] == true,
      canManage: json['canManage'] == true,
      creatorName: creator is Map
          ? text(creator['name']) ?? text(creator['displayName'])
          : null,
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
  });

  final bool connected;
  final String? account, connectedAt, connectedByName, connectorId;
  final List<String> scopes;
  final List<AgentConnector> connectors;

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

  /// `null` for `supported: false` (the provider serves no connections) and
  /// for a shape this client does not know.
  static AgentConnectionStatus? parse(Object? json) {
    if (json is! Map || json['supported'] != true) return null;
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    final by = json['connectedBy'];
    return AgentConnectionStatus(
      connected: json['connected'] == true,
      account: text(json['account']),
      connectedAt: text(json['connectedAt']),
      connectedByName: by is Map ? text(by['name']) ?? text(by['id']) : null,
      scopes: [
        if (json['scopes'] is List)
          for (final s in json['scopes'] as List)
            if (s is String) s,
      ],
      connectorId: text(json['connectorId']),
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
