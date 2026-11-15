// A rack row's next step and … menu (Web v1.24 features/computer/
// RackRowAction.tsx, RackRowMenu.tsx, components/machine/
// ComputerActionConfirms.tsx, useComputerUpgradeCard.ts): only for whoever may
// manage the computer.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/computer_restart_progress.dart';
import '../../data/user_error.dart';
import '../../data/workspace_controller.dart';
import '../../data/workspace_entity_directory.dart';
import '../computer_delete_dialog.dart';
import '../computer_detail_view.dart' show isComputerSemver;
import '../computer_restart_request.dart';
import '../computer_setup_commands.dart';
import '../computer_upgrade_hint.dart';
import '../managed_agent_launcher.dart';
import 'computers_rack_glyphs.dart';
import 'rack_upgrade_popovers.dart';

/// utils/canManageMachine.ts (the Computer page's own rule).
bool canManageComputer(WorkspaceController w, Map m) {
  final me = w.client.user?.id;
  final creator = m['creator'];
  return m['computerAttachedByCurrentUser'] == true ||
      (me != null && creator is Map && creator['id'] == me) ||
      const [
        'editMachines',
        'controlComputers',
        'removeMachines',
        'rotateMachineKeys',
        'createAgents',
        'migrateAgents',
      ].any(w.can);
}

/// The rack row's next step, from useComputerUpgradeCard's states it uses.
sealed class RackNextStep {
  const RackNextStep();
}

/// Offline: the recovery restart command.
class RackRecover extends RackNextStep {
  const RackRecover(this.command);
  final String command;
}

/// Online, an upgrade in flight (waiting on [waitingAgents] agents first).
class RackUpgrading extends RackNextStep {
  const RackUpgrading(this.waitingAgents);
  final int waitingAgents;
}

/// Online, one click upgrades to [version].
class RackOneClick extends RackNextStep {
  const RackOneClick(this.version, {this.hint, this.installLines = const []});
  final String version;

  /// Beside Upgrade, why the web upgrade may fail (a warning icon).
  final RackUpgradeHint? hint;
  final List<RaftComputerInstallLine> installLines;
}

/// Online, newer [version] but the web can't upgrade it: the install command
/// on that machine, in the row's popover.
class RackManualUpgrade extends RackNextStep {
  const RackManualUpgrade(this.version, this.installLines);
  final String version;
  final List<RaftComputerInstallLine> installLines;
}

RackNextStep? rackNextStep(
  WorkspaceController w,
  Map<String, dynamic> m, {
  required bool canManage,
  required String? availableVersion,
  String deployment = const String.fromEnvironment(
    'RAFT_DEPLOYMENT_ENV',
    defaultValue: 'production',
  ),
}) {
  if (!canManage || m['isComputer'] != true) return null;
  final directory = w.services.entityDirectory;
  final windows = '${m['os'] ?? ''}'.toLowerCase().startsWith('win');
  if (m['status'] != 'online') {
    if (directory.upgradeReconnect(m).reconnecting) return null;
    final commands = ComputerCommands.build(
      slug: w.server?.string('slug') ?? '',
      serverUrl: w.client.origin,
      deployment: deployment,
      windows: windows,
    );
    return commands == null ? null : RackRecover(commands.restart);
  }
  final id = '${m['id']}';
  final inFlight = directory.upgradeReconnect(m).inFlight;
  if (inFlight != null || directory.upgradeSubmitting(id) != null) {
    final draining = inFlight?['phase'] == 'draining';
    final ids = inFlight?['drainingAgentIds'];
    return RackUpgrading(draining && ids is List ? ids.length : 0);
  }
  if (availableVersion == null) return null;
  final policy = m['computerBroadcastPolicy'];
  if (policy is Map && policy['reasonCode'] == 'managed_by_desktop') {
    return null;
  }
  final supported =
      (m['remoteUpgradeSupported'] ??
          isComputerSemver('${m['computerVersion'] ?? ''}')) ==
      true;
  List<RaftComputerInstallLine> lines() => computerInstallLines(
    slug: w.server?.string('slug') ?? '',
    serverUrl: w.client.origin,
    deployment: deployment,
    windows: windows,
  );
  if (!supported) return RackManualUpgrade(availableVersion, lines());
  final target = policy is Map ? policy['targetVersion'] : null;
  final gated =
      policy is Map &&
      (policy['reasonCode'] == 'broadcast_disabled' ||
          policy['reasonCode'] == 'broadcast_gate_unavailable');
  if (!gated &&
      m['computerUpgradeAvailable'] == true &&
      policy is Map &&
      policy['eligibility'] == 'eligible' &&
      target is String) {
    // One set of steps: the failure's when both apply (they include running
    // the install command, which is also the repair).
    final failure = computerUpgradeFailureHint(m);
    return RackOneClick(
      target,
      hint: failure != null
          ? RackUpgradeHint.failure(failure)
          : computerRecommendRepair(m)
          ? const RackUpgradeHint.repair()
          : null,
      installLines: lines(),
    );
  }
  return null;
}

/// ComputerActionConfirms' Upgrade: "{name} restarts into v{version}, which
/// disconnects it and its # agents until it reconnects." Then the POST.
Future<void> confirmComputerUpgrade(
  BuildContext context,
  WorkspaceController w,
  Map<String, dynamic> m, {
  required String version,
  required int agentCount,
}) => showRaftDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialog) => RaftConfirmDialog(
    surfaceKey: const ValueKey('computer-upgrade-confirm'),
    title: raftFormat(dialog, 'Upgrade to v{version}', {'version': version}),
    message: raftFormat(
      dialog,
      agentCount == 0
          ? '{name} restarts into v{version}, which disconnects it until it reconnects.'
          : agentCount == 1
          ? '{name} restarts into v{version}, which disconnects it and its {count} agent until it reconnects.'
          : '{name} restarts into v{version}, which disconnects it and its {count} agents until it reconnects.',
      {'name': m['name'], 'version': version, 'count': agentCount},
    ),
    confirmLabel: raftText(dialog, 'Upgrade'),
    confirmVariant: RaftButtonRecipeVariant.warning,
    confirmGlyph: RaftGlyph.alertTriangle,
    onConfirm: () => startComputerUpgrade(w, m, version),
  ),
);

/// POST …/computer/upgrade; the accepted request says "upgrading" until a
/// refresh carries the server's row.
Future<void> startComputerUpgrade(
  WorkspaceController w,
  Map<String, dynamic> m,
  String target,
) async {
  final directory = w.services.entityDirectory;
  final id = '${m['id']}';
  if (directory.upgradeSubmitting(id) != null) return;
  directory.setUpgradeSubmitting(id, target);
  try {
    final data = await w.command(
      'POST',
      '/servers/${w.server?.id}/machines/$id/computer/upgrade',
      data: {'targetVersion': target},
    );
    final request = data is Map ? data['upgradeRequest'] : null;
    if (request is Map) {
      directory.acceptComputerUpgrade(id, Map<String, dynamic>.from(request));
    }
  } catch (e) {
    throw RaftApiException(
      userErrorText(
        e,
        fallback: "Can't upgrade right now. Try again later.",
        where: 'computer upgrade',
      ),
    );
  } finally {
    directory.setUpgradeSubmitting(id, null);
    unawaited(
      directory
          .refresh(WorkspaceEntityKind.computers, force: true)
          .then((_) {}, onError: (_) {}),
    );
  }
}

/// ComputerActionConfirms' Restart, then POST …/computer/restart.
Future<void> confirmComputerRestart(
  BuildContext context,
  WorkspaceController w,
  Map<String, dynamic> m, {
  required int agentCount,
}) => showRaftDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialog) => RaftConfirmDialog(
    surfaceKey: const ValueKey('computer-restart-confirm'),
    title: raftText(dialog, 'Restart computer'),
    message: raftFormat(
      dialog,
      agentCount == 0
          ? 'Restarting {name} disconnects it until it comes back online.'
          : agentCount == 1
          ? 'Restarting {name} disconnects it and its {count} agent until it comes back online.'
          : 'Restarting {name} disconnects it and its {count} agents until it comes back online.',
      {'name': m['name'], 'count': agentCount},
    ),
    confirmLabel: raftText(dialog, 'Restart'),
    confirmVariant: RaftButtonRecipeVariant.warning,
    confirmGlyph: RaftGlyph.alertTriangle,
    // Web closes the question at once; the progress shows in the row / page.
    onConfirm: () async => unawaited(requestComputerRestart(w, '${m['id']}')),
  ),
);

/// RackRowAction: the row's one next step.
class RackRowAction extends StatelessWidget {
  const RackRowAction({
    super.key,
    required this.step,
    required this.desktop,
    required this.machineId,
    required this.onUpgrade,
    required this.onOpenComputer,
    this.restart,
  });

  /// The shared restart progress; while it runs it replaces the next step
  /// (RackRowAction `if (progress)`, after the offline recovery).
  final ComputerRestartProgress? restart;
  final RackNextStep? step;
  final bool desktop;
  final String machineId;
  final VoidCallback onUpgrade, onOpenComputer;

  @override
  Widget build(BuildContext context) {
    final progress = restart;
    if (progress != null && step is! RackRecover) {
      return RaftRackRestartProgress(
        key: ValueKey('rack-restart-progress-$machineId'),
        text: progress.done ? (progress.error ?? 'Restarted.') : 'Restarting…',
        error: progress.error != null,
      );
    }
    return switch (step) {
      null => const SizedBox.shrink(),
      RackRecover(:final command) => RaftRackRecovery(
        key: ValueKey('rack-offline-recovery-$machineId'),
        label: desktop
            ? raftText(context, 'Bring this computer back online')
            : null,
        command: RaftCopyableCode(
          command,
          copyLabel: raftText(context, 'Copy command'),
          codeKey: ValueKey('rack-restart-command-$machineId'),
        ),
      ),
      RackUpgrading(:final waitingAgents) => RaftButton(
        key: ValueKey('rack-upgrading-$machineId'),
        label: waitingAgents > 0
            ? raftFormat(
                context,
                waitingAgents == 1
                    ? 'Waiting for {count} agent on this server…'
                    : 'Waiting for {count} agents on this server…',
                {'count': waitingAgents},
              )
            : raftText(context, 'Updating…'),
        secondary: true,
        busy: true,
        onPressed: null,
      ),
      RackOneClick(:final version, :final hint, :final installLines) => () {
        final upgrade = RaftButton(
          key: ValueKey('rack-upgrade-$machineId'),
          label: raftFormat(context, 'Upgrade to v{version}', {
            'version': version,
          }),
          glyph: rackGlyphCircleArrowUp,
          secondary: true,
          onPressed: onUpgrade,
        );
        if (hint == null) return upgrade;
        return RaftRackActionPair(
          leading: RackUpgradeHintButton(
            machineId: machineId,
            version: version,
            hint: hint,
            lines: installLines,
          ),
          action: upgrade,
        );
      }(),
      RackManualUpgrade(:final version, :final installLines) =>
        RackManualUpgradeButton(
          machineId: machineId,
          version: version,
          lines: installLines,
        ),
    };
  }
}

/// RackRowMenu: Create agent (online), Restart (online, no upgrade or restart
/// running) and Delete Computer; an empty box for whoever may do none.
class RackRowMenu extends StatelessWidget {
  const RackRowMenu({
    super.key,
    required this.controller,
    required this.machine,
    required this.agents,
    required this.canManage,
    required this.upgrading,
    this.restarting = false,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> machine;
  final List<Map<String, dynamic>> agents;
  final bool canManage, upgrading, restarting;

  @override
  Widget build(BuildContext context) {
    if (!canManage) return const RaftRackMenuSpace();
    final w = controller, m = machine;
    final id = '${m['id']}';
    final online = m['status'] == 'online';
    final canRestart =
        m['isComputer'] == true && online && !upgrading && !restarting;
    final label = raftText(context, 'More actions');
    return RaftDropdownMenu(
      key: ValueKey('rack-row-menu-$id'),
      label: label,
      tooltip: label,
      glyph: RaftGlyph.ellipsisVertical,
      triggerStyle: RaftDropdownTriggerStyle.button,
      align: RaftDropdownAlign.end,
      triggerBuilder: (context, focusNode, onPressed) => RaftButton(
        glyph: RaftGlyph.ellipsisVertical,
        tooltip: label,
        semanticLabel: label,
        tone: RaftButtonRecipeVariant.ghost,
        size: RaftButtonRecipeSize.iconMd,
        focusNode: focusNode,
        onPressed: onPressed,
      ),
      entries: [
        if (online)
          RaftMenuEntry(
            label: raftText(context, 'Create agent'),
            glyph: RaftGlyph.plus,
            onPressed: () =>
                showManagedAgentForm(context, w, suggestedComputer: id),
          ),
        if (canRestart)
          RaftMenuEntry(
            label: raftText(context, 'Restart'),
            glyph: RaftGlyph.rotateCcw,
            onPressed: () => confirmComputerRestart(
              context,
              w,
              m,
              agentCount: agents.length,
            ),
          ),
        RaftMenuEntry(
          label: raftText(context, 'Delete computer'),
          glyph: RaftGlyph.trash2,
          onPressed: () async {
            final deleted = await showDeleteComputerDialog(
              context,
              w,
              machine: m,
              agents: agents,
            );
            if (deleted) {
              unawaited(
                w.services.entityDirectory
                    .refresh(WorkspaceEntityKind.computers, force: true)
                    .then((_) {}, onError: (_) {}),
              );
            }
          },
        ),
      ],
    );
  }
}

/// ComputerActionConfirms' Upgrade / Restart as a question only (the Computer
/// page runs its own request and progress after the answer). True = confirmed.
Future<bool> askComputerUpgrade(
  BuildContext context,
  Map<String, dynamic> m, {
  required String version,
  required int agentCount,
}) async =>
    await showRaftDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => RaftConfirmDialog(
        surfaceKey: const ValueKey('computer-upgrade-confirm'),
        title: raftFormat(dialog, 'Upgrade to v{version}', {
          'version': version,
        }),
        message: _upgradeMessage(dialog, m, version, agentCount),
        confirmLabel: raftText(dialog, 'Upgrade'),
        confirmVariant: RaftButtonRecipeVariant.warning,
        confirmGlyph: RaftGlyph.alertTriangle,
        onConfirm: () async {},
      ),
    ) ??
    false;

Future<bool> askComputerRestart(
  BuildContext context,
  Map<String, dynamic> m, {
  required int agentCount,
}) async =>
    await showRaftDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => RaftConfirmDialog(
        surfaceKey: const ValueKey('computer-restart-confirm'),
        title: raftText(dialog, 'Restart computer'),
        message: _restartMessage(dialog, m, agentCount),
        confirmLabel: raftText(dialog, 'Restart'),
        confirmVariant: RaftButtonRecipeVariant.warning,
        confirmGlyph: RaftGlyph.alertTriangle,
        onConfirm: () async {},
      ),
    ) ??
    false;

String _upgradeMessage(
  BuildContext context,
  Map<String, dynamic> m,
  String version,
  int agentCount,
) => raftFormat(
  context,
  agentCount == 0
      ? '{name} restarts into v{version}, which disconnects it until it reconnects.'
      : agentCount == 1
      ? '{name} restarts into v{version}, which disconnects it and its {count} agent until it reconnects.'
      : '{name} restarts into v{version}, which disconnects it and its {count} agents until it reconnects.',
  {'name': m['name'], 'version': version, 'count': agentCount},
);

String _restartMessage(
  BuildContext context,
  Map<String, dynamic> m,
  int agentCount,
) => raftFormat(
  context,
  agentCount == 0
      ? 'Restarting {name} disconnects it until it comes back online.'
      : agentCount == 1
      ? 'Restarting {name} disconnects it and its {count} agent until it comes back online.'
      : 'Restarting {name} disconnects it and its {count} agents until it comes back online.',
  {'name': m['name'], 'count': agentCount},
);
