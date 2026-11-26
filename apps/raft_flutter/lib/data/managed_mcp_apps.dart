import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart' show RaftUserError;

typedef McpJson = Map<String, dynamic>;

McpJson mcpObject(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

List<McpJson> mcpRows(Object? value) => value is List
    ? [for (final row in value.whereType<Map>()) mcpObject(row)]
    : [];

enum McpAuthKind {
  none,
  headers,
  oauth;

  static McpAuthKind parse(Object? value) => switch (value) {
    'headers' => headers,
    'oauth' => oauth,
    _ => none,
  };

  String get label => switch (this) {
    none => 'No sign-in',
    headers => 'API key',
    oauth => 'OAuth sign-in',
  };
}

class ManagedMcpApp {
  ManagedMcpApp(McpJson json)
    : id = json['id'] as String,
      profile = mcpObject(json['profile']),
      server = mcpObject(json['server']),
      source = mcpObject(json['source']),
      agents = mcpObject(json['agentsSummary']),
      connections = mcpRows(json['connections'])
          .map(McpConnection.new)
          .toList(),
      canManage = mcpObject(json['viewer'])['canManage'] == true;

  final String id;
  final McpJson profile, server, source, agents;
  final List<McpConnection> connections;
  final bool canManage;

  String get name => profile['name'] as String? ?? '';
  String get endpoint => server['endpointUrl'] as String? ?? '';
  McpAuthKind get auth => McpAuthKind.parse(server['authKind']);
  bool get maintained => source['maintainedByRaft'] == true;
  List<String> get headerNames =>
      (server['requiredHeaderNames'] as List? ?? const [])
          .whereType<String>()
          .toList();
}

class McpConnection {
  McpConnection(McpJson json)
    : id = json['id'] as String,
      name = json['name'] as String?,
      account = json['accountLabel'] as String?,
      lastError = json['lastError'] as String?,
      isDefault = json['isServerDefault'] == true,
      hasClient = json['hasConfiguredOAuthClient'] == true,
      auth = McpAuthKind.parse(json['authKind']),
      headerNames = (json['headerNames'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      status = json['status'] as String? ?? '';

  final String id, status;

  /// An App older than recorded header names keeps them on its default
  /// Connection (McpAppConnectionsSection.tsx:51-54).
  final List<String> headerNames;
  final String? name, account, lastError;
  final bool isDefault, hasClient;
  final McpAuthKind auth;

  String get statusLabel => switch (status) {
    'ready' => 'Ready',
    'pending' => 'Signing in',
    'needs_auth' => 'Needs sign-in',
    'expired' => 'Authorization expired',
    _ => 'Error',
  };
}

class ManagedMcpAgentApp {
  ManagedMcpAgentApp(McpJson json)
    : id = json['id'] as String,
      name = json['name'] as String? ?? '',
      logo = json['logoUrl'] as String?,
      homepage = json['homepageUrl'] as String?,
      toolCount = mcpRows(json['toolCatalog']).length,
      auth = McpAuthKind.parse(json['authMode']),
      connection = mcpObject(json['agentConnection']),
      assignment = mcpObject(json['assignment']);

  final String id, name;
  final String? logo, homepage;
  final int toolCount;
  final McpAuthKind auth;
  final McpJson connection, assignment;

  String get grant =>
      connection['grant'] as String? ??
      (connection['mode'] == 'off' || assignment['enabled'] == false
          ? 'revoked'
          : 'automatic');
  bool get granted => grant == 'automatic' || grant == 'person';
}

class ManagedMcpAppsApi {
  const ManagedMcpAppsApi(this.client);

  final RaftClient client;

  static String app(String id) => '/mcp/apps/${Uri.encodeComponent(id)}';

  Future<McpJson> request(
    String method,
    String path, {
    Object? data,
    McpJson? query,
    bool authorized = true,
  }) async {
    try {
      return mcpObject(
        await client.request(
          method,
          path,
          data: data,
          query: query,
          authorized: authorized,
        ),
      );
    } on RaftApiException catch (error) {
      if (error.status == 401 || error.status == 403) rethrow;
      throw RaftUserError(mcpAppError(error));
    }
  }
}

String mcpAppError(Object error) => switch (error) {
  RaftUserError(:final message) => message,
  RaftApiException(
    :final details,
    :final status,
    :final structured,
    :final message,
  ) =>
    _mcpAppErrors[details['code']] ??
        (status == 429
            ? 'Too many attempts. Wait a minute and try again.'
            : null) ??
        (structured && message.trim().isNotEmpty ? message : null) ??
        (status == 403 ? "You don't have permission to do this." : _generic),
  _ => _generic,
};

const _generic = 'Something went wrong. Try again.';
const _mcpAppErrors = {
  'managed_mcp_probe_rate_limited':
      'Too many attempts. Wait a minute and try again.',
  'managed_mcp_unreachable': 'The MCP server could not be reached. Check that it is online and try again.',
  'managed_mcp_endpoint_blocked': "The server's network security check blocked this address. Check the server's network or proxy settings.",
  'managed_mcp_template_field_locked': "Raft maintains this App's server URL and sign-in; they cannot be changed.",
  'managed_mcp_template_not_found':
      'This recommended app is no longer available.',
  'managed_mcp_app_name_taken': 'An MCP App with this name already exists.',
  'managed_mcp_endpoint_invalid':
      'Enter the https URL of a public MCP server, without a query string.',
  'managed_mcp_endpoint_auth_rejected':
      'The MCP server refused these credentials.',
  'managed_mcp_headers_incomplete':
      'Fill in every required header, and only those.',
  'managed_mcp_header_names_unset': 'This App has no recorded header names. Set them in MCP Server, then add the connection.',
  'managed_mcp_connection_limit_reached':
      "This App can't take another connection right now.",
  'managed_mcp_oauth_busy': 'Another sign-in for this connection is in progress. Try again in a moment.',
  'managed_mcp_oauth_client_registration_unsupported': "This service doesn't support automatic registration. Register an OAuth client with the provider, choose “Use a registered client” and enter it, and allow the redirect URI shown there.",
  'managed_mcp_config_stale':
      'The App changed while this was running. Try again.',
  'managed_mcp_server_not_found': 'This MCP App no longer exists.',
  'managed_mcp_connection_not_found': 'This connection no longer exists.',
  'managed_mcp_connection_not_usable': "This Connection belongs to someone else. An agent can use the App's default Connection or one its owner created.",
  'managed_mcp_forbidden': "You don't have permission to do this.",
};
