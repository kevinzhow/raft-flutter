// Add Computer flow for the Computers rail `+`: registration, connection
// watch and naming requests behind raft_ui RaftAddComputerDialog (the port of
// Web AddMachineDialog.tsx + ComputerCommandGuide.tsx).
import 'dart:async';

import 'package:flutter/foundation.dart';
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
  ValueChanged<String>? onOpenComputer,
  String deployment = const String.fromEnvironment(
    'RAFT_DEPLOYMENT_ENV',
    defaultValue: 'production',
  ),
}) => RaftAddComputerDialog.show(
  context,
  (_) => AddComputerDialog(
    controller: w,
    deployment: deployment,
    onOpenComputer: onOpenComputer,
  ),
);

class AddComputerDialog extends StatefulWidget {
  const AddComputerDialog({
    super.key,
    required this.controller,
    this.deployment = 'production',
    this.onOpenComputer,
  });
  final ValueChanged<String>? onOpenComputer;
  final WorkspaceController controller;
  final String deployment;
  @override
  State<AddComputerDialog> createState() => _AddComputerDialogState();
}

class _AddComputerDialogState extends State<AddComputerDialog> {
  WorkspaceController get w => widget.controller;
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
    _freezeBaseline();
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
    if (!current) return;
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
    final match = resolveComputerConnectionMatch(rows, '', baseline);
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
    if (!_detailsPending) {
      poll?.dispose();
      poll = null;
    }
  }

  void _recoverConnection() {
    if (!current || (connected != null && !_detailsPending)) return;
    unawaited(
      w.services.entityDirectory.refresh(WorkspaceEntityKind.computers),
    );
  }

  /// Freeze the baseline when the dialog opens, before the command can cause
  /// a socket update: Web's `useComputerConnectionWatch` snapshots during the
  /// render that starts the attempt so the new row cannot poison it. Nothing
  /// is registered on the server until a computer actually connects.
  void _freezeBaseline() {
    baseline = [
      for (final row in w.services.entityDirectory.rows(
        WorkspaceEntityKind.computers,
      ))
        Map<String, dynamic>.from(row),
    ];
    // Dropped-event fallback: Web reloads machines every 3 s while waiting.
    poll = RaftForegroundPeriodic(
      const Duration(seconds: 3),
      _recoverConnection,
    );
  }

  Future<void> cancel() async {
    if (!mounted || retired || openedAuthority != authority) return;
    canceled = true;
    poll?.dispose();
    poll = null;
  }

  Future<void> done(String name) async {
    if (!current) return;
    final id = connected?['id'] as String?;
    final serverId = w.server!.id;
    if (id != null && name.isNotEmpty && name != connected?['name']) {
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
    unawaited(
      w.services.entityDirectory.refresh(
        WorkspaceEntityKind.computers,
        force: true,
      ),
    );
    // Web `nav.toMachine(machineId)` after Done.
    if (id != null) widget.onOpenComputer?.call(id);
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
