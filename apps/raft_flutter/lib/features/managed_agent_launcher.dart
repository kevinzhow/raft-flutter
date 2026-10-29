import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'private_route_guard.dart';
import 'create_agent_dialog.dart';

/// Web CreateAgentDialog: computer, name, description, runtime and the
/// runtime's protocol-v2 fields in one dialog (zero computers shows the
/// "Connect a computer first" branch). A required computer never silently
/// falls back to a different computer.
Future<Map<String, dynamic>?> showManagedAgentForm(
  BuildContext context,
  WorkspaceController w, {
  String? initialName,
  String? initialDescription,
  String? suggestedComputer,
  String? requiredComputer,
  String? initialHosting,
  String? initialHostedModel,
  String? actionCardMessageId,
  int? actionCardConfirmationVersion,
  VoidCallback? onConnectComputer,
  String? autoJoinChannelName,
  String? prefilledNameNote,
  math.Random? random,
  bool onboarding = false,
}) async {
  final authority = workspaceAuthority(w);
  bool current() =>
      context.mounted &&
      authority == workspaceAuthority(w) &&
      w.can('createAgents');
  if (!context.mounted || !current()) return null;
  // The dialog opens at once. The computer list comes from the workspace
  // directory's copy (revalidated in place); only a directory that cannot
  // provide it is fetched, behind the already-open dialog.
  Map<String, dynamic>? created;
  await showRaftForm<bool>(
    context,
    builder: (_) => _ManagedAgentFormHost(
      controller: w,
      requiredComputer: requiredComputer,
      current: current,
      dialog: (machines) => CreateAgentDialog(
        controller: w,
        machines: machines,
        initialMachineId: suggestedComputer,
        requiredMachineId: requiredComputer,
        initialHosting: initialHosting,
        initialHostedModel: initialHostedModel,
        initialName: initialName,
        initialDescription: initialDescription,
        actionCardMessageId: actionCardMessageId,
        actionCardConfirmationVersion: actionCardConfirmationVersion,
        onCreated: (value) => created = value,
        onConnectComputer: onConnectComputer,
        autoJoinChannelName: autoJoinChannelName,
        prefilledNameNote: prefilledNameNote,
        random: random,
        onboarding: onboarding,
        onboardingModal: onboarding,
      ),
    ),
  );
  return current() ? created : null;
}

/// Supplies [CreateAgentDialog] with the account's computers: the directory
/// copy at the first frame (a stable-size loading card only when nothing is
/// local yet), then in-place updates from the directory (status, runtimes).
class _ManagedAgentFormHost extends StatefulWidget {
  const _ManagedAgentFormHost({
    required this.controller,
    required this.requiredComputer,
    required this.current,
    required this.dialog,
  });
  final WorkspaceController controller;
  final String? requiredComputer;
  final bool Function() current;
  final Widget Function(List<Map<String, dynamic>> machines) dialog;
  @override
  State<_ManagedAgentFormHost> createState() => _ManagedAgentFormHostState();
}

class _ManagedAgentFormHostState extends State<_ManagedAgentFormHost> {
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>>? machines;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when Retry starts a new load or when the computers list arrives (it only shows while no list is known).
  String? failure;
  int ticket = 0;

  bool get directoryLoaded =>
      w.services.entityDirectory.state(WorkspaceEntityKind.computers).loaded;

  @override
  void initState() {
    super.initState();
    w.services.entityDirectory.addListener(adopt);
    if (directoryLoaded) {
      machines = filtered(
        w.services.entityDirectory.rows(WorkspaceEntityKind.computers),
      );
    }
    load();
  }

  @override
  void dispose() {
    w.services.entityDirectory.removeListener(adopt);
    super.dispose();
  }

  List<Map<String, dynamic>> filtered(Iterable<dynamic> rows) => [
    for (final m in rows.whereType<Map>())
      if (widget.requiredComputer == null || m['id'] == widget.requiredComputer)
        Map<String, dynamic>.from(m),
  ];

  void adopt() {
    if (!mounted || !directoryLoaded) return;
    final next = filtered(
      w.services.entityDirectory.rows(WorkspaceEntityKind.computers),
    );
    setState(() {
      machines = next;
      failure = null;
    });
  }

  Future<void> load() async {
    final mine = ++ticket;
    if (mounted && failure != null) setState(() => failure = null);
    // Quiet revalidation of the copy shown (or the first read).
    await w.services.entityDirectory.refresh(WorkspaceEntityKind.computers);
    if (!mounted || mine != ticket || machines != null) return;
    try {
      final result = await w.query('/servers/${w.server!.id}/machines');
      if (!mounted || mine != ticket || machines != null) return;
      if (!widget.current()) {
        Navigator.of(context).maybePop();
        return;
      }
      // The endpoint answers `{machines: [...]}` or a bare array (Web accepts both).
      final rows = result is Map ? result['machines'] : result;
      setState(() => machines = filtered(rows is List ? rows : const []));
    } catch (e) {
      if (mounted && mine == ticket && machines == null) {
        setState(
          () => failure = userErrorText(
            e,
            fallback: raftGenericErrorText,
            where: 'managed agent launcher',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = machines;
    if (list != null) return widget.dialog(list);
    return RaftDialog.agent(
      title: 'Create Agent',
      onClose: () => Navigator.of(context).maybePop(),
      children: [
        if (failure != null)
          RaftAgentBanner(
            status: RaftAgentBannerStatus.warning,
            description: failure!,
            action: 'Retry',
            onAction: load,
          )
        else
          const Center(child: RaftSpinner()),
      ],
    );
  }
}
