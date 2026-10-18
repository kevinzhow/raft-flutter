// Add Computer flow for the Computers rail `+`: registration, connection
// watch and naming requests behind raft_ui RaftAddComputerDialog (the port of
// Web AddMachineDialog.tsx + ComputerCommandGuide.tsx).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'computer_connection_match.dart';
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
  List<Map<String, dynamic>> baseline = const [];
  bool requiresConfirmation = false, retired = false, canceled = false;
  RaftForegroundPeriodic? poll;
  late final Object openedAuthority;
  Object get authority => (
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.client.serverId,
    w.server?.id,
    w.server?.string('role'),
    w.can('registerMachines'),
  );
  bool get current =>
      mounted &&
      !retired &&
      !canceled &&
      w.can('registerMachines') &&
      openedAuthority == authority;

  @override
  void initState() {
    super.initState();
    openedAuthority = authority;
    w.addListener(_workspaceChanged);
    w.services.entityDirectory.addListener(_directoryChanged);
  }

  @override
  void dispose() {
    poll?.dispose();
    w.removeListener(_workspaceChanged);
    w.services.entityDirectory.removeListener(_directoryChanged);
    super.dispose();
  }

  void _workspaceChanged() {
    if (retired || openedAuthority == authority) return;
    retired = true;
    poll?.dispose();
    poll = null;
    final route = ModalRoute.of(context);
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
  }

  /// Watch the accepted directory, including an event accepted while the
  /// registration HTTP response was still pending.
  void _directoryChanged() {
    if (!current || connected != null || registeredId == null) return;
    final match = resolveComputerConnectionMatch(
      w.services.entityDirectory.rows(WorkspaceEntityKind.computers),
      registeredId!,
      baseline,
    );
    if (match == null) return;
    poll?.dispose();
    poll = null;
    setState(() {
      connected = Map<String, dynamic>.from(match.machine);
      requiresConfirmation = match.requiresConfirmation;
    });
  }

  void _recoverConnection() {
    if (!current || connected != null || registeredId == null) return;
    unawaited(
      w.services.entityDirectory.refresh(WorkspaceEntityKind.computers),
    );
  }

  Future<void> register() async {
    if (!current) return;
    // Freeze before the command can cause a socket update, not in a later
    // frame where the newly connected Computer might poison the baseline.
    baseline = [
      for (final row in w.services.entityDirectory.rows(
        WorkspaceEntityKind.computers,
      ))
        Map<String, dynamic>.from(row),
    ];
    final serverId = w.server!.id;
    try {
      final result = await w.command(
        'POST',
        '/servers/$serverId/machines',
        data: {'name': 'my-computer'},
      );
      final machine = result is Map ? result['machine'] : null;
      if (machine is! Map || machine['id'] is! String) {
        throw const RaftComputerActionError('Failed to register computer');
      }
      if (!current) {
        // A canceled HTTP attempt can still have created its private raw
        // placeholder. Only clean it while the original authority survives.
        if (!retired && openedAuthority == authority) {
          await _removePlaceholder(machine['id'] as String, serverId);
        }
        return;
      }
      registeredId = machine['id'] as String;
      _directoryChanged();
      if (connected == null) {
        poll = RaftForegroundPeriodic(
          const Duration(seconds: 3),
          _recoverConnection,
        );
        _recoverConnection();
      }
    } on RaftComputerActionError {
      rethrow;
    } catch (e) {
      // Web: `data.error || machine.add.registerFailed`.
      throw RaftComputerActionError(
        userErrorText(
          e,
          fallback: 'Failed to register computer',
          where: 'register computer',
        ),
      );
    }
  }

  Future<void> cancel() async {
    final id = registeredId;
    if (!current) return;
    canceled = true;
    poll?.dispose();
    poll = null;
    if (id != null && connected?['id'] != id) {
      await _removePlaceholder(id, w.server!.id);
    }
  }

  Future<void> _removePlaceholder(String id, String serverId) async {
    try {
      await w.command('DELETE', '/servers/$serverId/machines/$id');
    } catch (_) {
      // Best effort, like the Web dialog.
    }
  }

  Future<void> done(String name) async {
    if (!current) return;
    final id = connected?['id'] as String?;
    final serverId = w.server!.id;
    if (id != null && name.isNotEmpty && name != 'my-computer') {
      try {
        await w.command(
          'PATCH',
          '/servers/$serverId/machines/$id',
          data: {'name': name},
        );
      } catch (_) {}
    }
    if (!current) return;
    final placeholder = registeredId;
    if (placeholder != null && placeholder != id) {
      await _removePlaceholder(placeholder, serverId);
    }
    if (!current) return;
    unawaited(
      w.services.entityDirectory.refresh(
        WorkspaceEntityKind.computers,
        force: true,
      ),
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
    onViewPlans: () => w.setSection('billing'),
    cancel: cancel,
    done: done,
    connected: connected == null
        ? null
        : RaftAddComputerConnection(
            hostname: '${connected!['hostname'] ?? ''}',
            os: connected!['os'] as String?,
            requiresConfirmation: requiresConfirmation,
          ),
  );
}
