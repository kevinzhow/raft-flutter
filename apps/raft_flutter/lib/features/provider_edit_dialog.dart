// Edit-provider-connection dialog: the Web EditProviderConnectionModal
// (packages/web/src/components/settings/EditProviderConnectionModal.tsx).
// Snapshots the selected row when it opens; a blank API key keeps the stored
// credential; gateway connections also edit the Base URL and image input.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

class EditProviderConnectionDialog extends StatefulWidget {
  const EditProviderConnectionDialog({
    super.key,
    required this.controller,
    required this.connection,
    required this.gateway,
    required this.onCompleted,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> connection;

  /// `providerOptions[connection.providerId].providerKind == 'gateway'`.
  final bool gateway;
  final Future<void> Function() onCompleted;

  @override
  State<EditProviderConnectionDialog> createState() =>
      _EditProviderConnectionDialogState();
}

class _EditProviderConnectionDialogState
    extends State<EditProviderConnectionDialog> {
  late final name = TextEditingController(
    text: '${widget.connection['name'] ?? ''}',
  );
  late final endpoint = TextEditingController(
    text: '${widget.connection['endpointUrl'] ?? ''}',
  );
  final apiKey = TextEditingController();
  late bool supportsImageInput = widget.connection['supportsImageInput'] == true;
  bool submitting = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next submit starts; the dialog state is dropped when it closes.
  String? error;

  @override
  void initState() {
    super.initState();
    for (final c in [name, endpoint]) {
      c.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    name.dispose();
    endpoint.dispose();
    apiKey.dispose();
    super.dispose();
  }

  bool get canSubmit =>
      name.text.trim().isNotEmpty &&
      (!widget.gateway || endpoint.text.trim().isNotEmpty);

  Future<void> submit() async {
    if (submitting || !canSubmit) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.controller.client.patch(
        '/provider-connections/${widget.connection['id']}',
        data: {
          'name': name.text.trim(),
          if (widget.gateway) ...{
            'endpointUrl': endpoint.text.trim(),
            'supportsImageInput': supportsImageInput,
          },
          if (apiKey.text.trim().isNotEmpty) 'apiKey': apiKey.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      await widget.onCompleted();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'The provider connection could not be updated.');
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => RaftEditProviderDialogView(
    connectionName: '${widget.connection['name'] ?? ''}',
    gateway: widget.gateway,
    name: name,
    endpoint: endpoint,
    apiKey: apiKey,
    supportsImageInput: supportsImageInput,
    onSupportsImageInput: (v) => setState(() => supportsImageInput = v),
    canSubmit: canSubmit,
    submitting: submitting,
    error: error,
    onClose: () => Navigator.of(context).maybePop(),
    onSubmit: submit,
  );
}
