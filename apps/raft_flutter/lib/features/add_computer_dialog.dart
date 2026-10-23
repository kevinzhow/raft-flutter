// Add Computer flow for the Computers rail `+`: registration, connection
// watch and naming requests behind raft_ui RaftAddComputerDialog (the port of
// Web AddMachineDialog.tsx + ComputerCommandGuide.tsx).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
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
    if (!current || registeredId == null) return;
    final rows = w.services.entityDirectory.rows(WorkspaceEntityKind.computers);
    if (connected case final selected?) {
      // Latch identity, not a snapshot of a partially hydrated online row.
      final latest = rows
          .where((row) => row['id'] == selected['id'])
          .firstOrNull;
      if (latest != null && !mapEquals(latest, selected)) {
        setState(() => connected = Map<String, dynamic>.from(latest));
      }
      _watchDetails();
      return;
    }
    final match = resolveComputerConnectionMatch(rows, registeredId!, baseline);
    if (match == null) return;
    setState(() {
      connected = Map<String, dynamic>.from(match.machine);
      requiresConfirmation = match.requiresConfirmation;
    });
    _watchDetails();
  }

  bool get _detailsPending =>
      connected == null ||
      '${connected!['hostname'] ?? ''}'.trim().isEmpty ||
      '${connected!['os'] ?? ''}'.trim().isEmpty;

  void _watchDetails() {
    if (_detailsPending) {
      poll ??= RaftForegroundPeriodic(
        const Duration(seconds: 3),
        _recoverConnection,
      );
    } else {
      poll?.dispose();
      poll = null;
    }
  }

  void _recoverConnection() {
    if (!current || !_detailsPending || registeredId == null) return;
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
      if (_detailsPending) {
        _watchDetails();
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
    // A failed cleanup can be retried, but a canceled attempt cannot adopt
    // a later connection or issue commands under a different authority.
    if (!mounted || retired || openedAuthority != authority) return;
    canceled = true;
    poll?.dispose();
    poll = null;
    if (id != null && connected?['id'] != id) {
      await _removePlaceholder(id, w.server!.id, bestEffort: false);
    }
  }

  Future<void> _removePlaceholder(
    String id,
    String serverId, {
    bool bestEffort = true,
  }) async {
    try {
      await w.command('DELETE', '/servers/$serverId/machines/$id');
    } catch (error) {
      // A successful previous DELETE may have lost its response.
      if (error is RaftApiException && error.status == 404) return;
      if (!bestEffort) {
        throw RaftComputerActionError(
          userErrorText(error, fallback: 'Could not finish computer setup.'),
        );
      }
      // Only a late registration response after disposal is best effort.
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
      } catch (error) {
        throw RaftComputerActionError(
          userErrorText(error, fallback: 'Could not save computer name.'),
        );
      }
    }
    if (!current) return;
    final placeholder = registeredId;
    if (placeholder != null && placeholder != id) {
      await _removePlaceholder(placeholder, serverId, bestEffort: false);
    }
    if (!current) return;
    unawaited(
      w.services.entityDirectory.refresh(
        WorkspaceEntityKind.computers,
        force: true,
      ),
    );
  }

  ComputerCommands? _commands(bool windows) => ComputerCommands.build(
    slug: w.server?.string('slug') ?? '',
    serverUrl: w.client.origin,
    deployment: widget.deployment,
    windows: windows,
  );

  @override
  Widget build(BuildContext context) => RaftAddComputerDialog(
    commandsFor: (windows) {
      final c = _commands(windows);
      return c == null ? null : (c.install, c.setup);
    },
    installAndSetupFor: (windows) => _commands(windows)?.installAndSetup,
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
