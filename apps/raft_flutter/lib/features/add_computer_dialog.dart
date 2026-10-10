// Add Computer flow for the Computers rail `+`: registration, connection
// watch and naming requests behind raft_ui RaftAddComputerDialog (the port of
// Web AddMachineDialog.tsx + ComputerCommandGuide.tsx).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'computer_setup_commands.dart';

/// Opens the Add Computer flow the Web mounts from the Computers rail `+`.
Future<void> showAddComputerDialog(
  BuildContext context,
  WorkspaceController w, {
  String deployment = const String.fromEnvironment(
    'RAFT_DEPLOYMENT_ENV',
    defaultValue: 'production',
  ),
}) => RaftAddComputerDialog.show(
  context,
  (_) => AddComputerDialog(controller: w, deployment: deployment),
);

class AddComputerDialog extends StatefulWidget {
  const AddComputerDialog({
    super.key,
    required this.controller,
    this.deployment = 'production',
  });
  final WorkspaceController controller;
  final String deployment;
  @override
  State<AddComputerDialog> createState() => _AddComputerDialogState();
}

class _AddComputerDialogState extends State<AddComputerDialog> {
  WorkspaceController get w => widget.controller;
  String? registeredId;
  Map<String, dynamic>? connected;

  @override
  void initState() {
    super.initState();
    w.entityDirectory.addListener(_directoryChanged);
  }

  @override
  void dispose() {
    w.entityDirectory.removeListener(_directoryChanged);
    super.dispose();
  }

  /// useComputerConnectionWatch: the registered row coming online.
  void _directoryChanged() {
    if (!mounted || connected != null || registeredId == null) return;
    final row = w.entityDirectory.computer(registeredId!);
    if (row != null && row['status'] == 'online') {
      setState(() => connected = row);
    }
  }

  Future<void> register() async {
    try {
      final result = await w.command(
        'POST',
        '/servers/${w.server!.id}/machines',
        data: {'name': 'my-computer'},
      );
      final machine = result is Map ? result['machine'] : null;
      if (machine is! Map || machine['id'] is! String) {
        throw const RaftComputerActionError('Failed to register computer');
      }
      registeredId = machine['id'] as String;
    } on RaftApiException catch (e) {
      throw RaftComputerActionError(
        e.message.isNotEmpty ? e.message : 'Failed to register computer',
      );
    }
  }

  Future<void> cancel() async {
    final id = registeredId;
    if (id == null || connected != null) return;
    try {
      await w.command('DELETE', '/servers/${w.server!.id}/machines/$id');
    } catch (_) {
      // Best effort, like the Web dialog.
    }
  }

  Future<void> done(String name) async {
    final id = registeredId;
    if (id != null && name.isNotEmpty && name != 'my-computer') {
      try {
        await w.command(
          'PATCH',
          '/servers/${w.server!.id}/machines/$id',
          data: {'name': name},
        );
      } catch (_) {}
    }
    unawaited(
      w.entityDirectory.refresh(WorkspaceEntityKind.computers, force: true),
    );
  }

  @override
  Widget build(BuildContext context) => RaftAddComputerDialog(
    commandsFor: (windows) {
      final c = ComputerCommands.build(
        slug: w.server?.string('slug') ?? '',
        serverUrl: w.client.origin,
        deployment: widget.deployment,
        windows: windows,
      );
      return c == null ? null : (c.install, c.setup);
    },
    register: register,
    cancel: cancel,
    done: done,
    connected: connected == null
        ? null
        : RaftAddComputerConnection(
            hostname: '${connected!['hostname'] ?? ''}',
            os: connected!['os'] as String?,
          ),
  );
}
