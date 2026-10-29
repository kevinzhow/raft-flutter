import 'package:flutter/material.dart';
import 'package:raft_ui/previews.dart';

import 'mcp_server_editor.dart';

@RaftPreviews('MCP server editor', size: Size(720, 1000))
@RaftPreviews('MCP server editor phone', size: Size(390, 1000))
Widget mcpServerEditorPreview() => _editor();

@RaftPreviews('MCP stored headers', size: Size(720, 1000))
@RaftPreviews('MCP stored headers phone', size: Size(390, 1000))
Widget mcpStoredHeadersPreview() => _editor({
  'id': 'preview-only',
  'name': 'Example tools',
  'provider': 'custom',
  'authMode': 'headers',
  'endpointUrl': 'https://example.invalid/mcp',
  'credentialHeaderNames': ['Authorization', 'X-Workspace'],
});

/// Synthetic callbacks only. Preview never sends a request or reveals a secret.
Widget _editor([Map<String, dynamic>? server]) => SingleChildScrollView(
  child: McpServerEditor(
    server: server,
    onSave: (_) async {},
    onTest: (_) async => 2,
  ),
);
