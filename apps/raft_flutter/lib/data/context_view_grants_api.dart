// View Context grants (Web v1.24.0 features/settings/administration/
// contextViewGrantsApi.ts, shared agentContextViewGrant.ts): the owner/admin
// list, grant and revoke. Every route is behind `agent_context_view_v0`.
import 'package:raft_client/raft_client.dart';

import 'workspace_controller.dart';

/// One active grant as the list shows it.
class ContextViewGrant {
  const ContextViewGrant({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.grantedAt,
    this.granterName,
  });
  final String id, agentId, agentName;

  /// Null for a former member (the server sends `granter: null`).
  final String? granterName;
  final String grantedAt;

  static ContextViewGrant? parse(Object? value) {
    if (value is! Map) return null;
    final agent = value['agent'], granter = value['granter'];
    final id = value['id'];
    if (id is! String || agent is! Map || agent['id'] is! String) return null;
    return ContextViewGrant(
      id: id,
      agentId: agent['id'] as String,
      agentName: '${agent['name'] ?? ''}',
      granterName: granter is Map && granter['name'] is String
          ? granter['name'] as String
          : null,
      grantedAt: '${value['grantedAt'] ?? ''}',
    );
  }
}

String _path(String serverId) => '/servers/$serverId/agent-context-view-grants';

Future<List<ContextViewGrant>> listContextViewGrants(
  WorkspaceController w,
  String serverId,
) async {
  final data = await w.query(_path(serverId));
  final grants = data is Map ? data['grants'] : null;
  if (grants is! List) throw StateError('Malformed grants list');
  return [for (final g in grants) ?ContextViewGrant.parse(g)];
}

/// POST {agentId}: the active grant (an agent that already had one gets the
/// same grant back).
Future<ContextViewGrant> grantContextView(
  WorkspaceController w,
  String serverId,
  String agentId,
) async {
  final data = await w.command(
    'POST',
    _path(serverId),
    data: {'agentId': agentId},
  );
  final grant = ContextViewGrant.parse(data is Map ? data['grant'] : null);
  if (grant == null) throw StateError('Malformed grant');
  return grant;
}

/// Revoke: `false` ("gone") when the server no longer has the grant (404
/// `context_view_grant_not_found`: already revoked by someone else, or one the
/// caller may not revoke, which reads the same) or says `revoked: false`. Any
/// other failure throws.
Future<bool> revokeContextViewGrant(
  WorkspaceController w,
  String serverId,
  String grantId,
) async {
  try {
    final data = await w.command('DELETE', '${_path(serverId)}/$grantId');
    return data is Map && data['revoked'] == true;
  } on RaftApiException catch (e) {
    if (e.status == 404 && e.code == 'context_view_grant_not_found') {
      return false;
    }
    rethrow;
  }
}
