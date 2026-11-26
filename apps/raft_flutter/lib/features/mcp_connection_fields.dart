import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/managed_mcp_apps.dart';
import '../data/workspace_controller.dart';

class McpConnectionFields extends StatefulWidget {
  const McpConnectionFields({
    super.key,
    required this.app,
    required this.headerNames,
    required this.workspace,
    required this.connection,
    required this.rename,
    required this.busy,
    required this.onCancel,
    required this.onSubmit,
  });

  final ManagedMcpApp app;

  /// The headers every Connection must supply: the App's, or for an App older
  /// than recorded names, its default Connection's.
  final List<String> headerNames;
  final WorkspaceController workspace;
  final McpConnection? connection;
  final bool rename, busy;
  final VoidCallback onCancel;
  final Future<void> Function(McpJson) onSubmit;

  @override
  State<McpConnectionFields> createState() => _McpConnectionFieldsState();
}

class _McpConnectionFieldsState extends State<McpConnectionFields> {
  late bool makeDefault = !widget.app.connections.any((item) => item.isDefault);
  late final name = TextEditingController(text: widget.connection?.name);
  late final headers = {
    if (!widget.rename && widget.app.auth == McpAuthKind.headers)
      for (final header in widget.headerNames) header: TextEditingController(),
  };
  bool get isNew => widget.connection == null;

  @override
  void dispose() {
    name.dispose();
    for (final field in headers.values) {
      field.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit =>
      !widget.busy &&
      (!isNew && !widget.rename || name.text.trim().isNotEmpty) &&
      headers.values.every((field) => field.text.trim().isNotEmpty);

  Future<void> _submit() => widget.onSubmit({
    if (isNew || widget.rename) 'name': name.text.trim(),
    if (isNew) 'makeDefault': makeDefault,
    if (headers.isNotEmpty)
      'headers': {
        for (final entry in headers.entries) entry.key: entry.value.text,
      },
  });

  @override
  Widget build(BuildContext context) => RaftAppEditorBox.connection(
    child: RaftAppEditorStack(
      gap: RaftSpace.x3,
      children: [
        if (isNew || widget.rename)
          _input(
            'Connection name',
            name,
            key: 'mcp-connection-name',
            hint: 'Team workspace',
          ),
        if (headers.isNotEmpty) ...[
          const RaftAppEditorFootnote(
            'Values are stored encrypted and never shown again. Agents never see them.',
          ),
          for (final entry in headers.entries)
            _input(
              entry.key,
              entry.value,
              key: 'mcp-connection-header-${entry.key}',
              hint: 'Paste the value',
              secret: true,
            ),
        ],
        if (isNew)
          RaftCheckboxRow.caption(
            title: raftText(context, 'Make this the server default'),
            description: raftText(
              context,
              'Agents without a specific connection use the server default.',
            ),
            value: makeDefault,
            onChanged: widget.busy
                ? null
                : (value) => setState(() => makeDefault = value == true),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: RaftSpace.x2,
          children: [
            RaftButton(
              label: 'Cancel',
              uiVariant: RaftButtonVariant.standard,
              onPressed: widget.busy ? null : widget.onCancel,
            ),
            RaftButton(
              key: const ValueKey('mcp-connection-submit'),
              label: isNew ? 'Add' : 'Save',
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _input(
    String label,
    TextEditingController controller, {
    String? key,
    String? hint,
    bool secret = false,
  }) => RaftAppEditorField(
    label: label,
    required: !widget.rename,
    compact: true,
    child: RaftRecipeInput(
      fieldKey: key == null ? null : ValueKey(key),
      controller: controller,
      placeholder: hint == null ? null : raftText(context, hint),
      obscure: secret,
      mono: secret,
      enabled: !widget.busy,
      onChanged: (_) => setState(() {}),
    ),
  );
}
