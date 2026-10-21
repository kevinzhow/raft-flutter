// Web components/agentMigration/AgentMigrationSection.tsx: the "Agent
// migration" section of the agent detail panel: the action, the live progress
// of the agent's migration, and the dialogs the action leads to (start,
// upgrade to Pro, cancel).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/agent_migration_status.dart';
import '../platform/content_links.dart';
import '../data/migration_error.dart';
import '../data/user_error.dart' show logUserError;
import '../data/workspace_controller.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'agent_migration_panel.dart';
import 'agent_migration_presentation.dart';
import 'agent_migration_start_dialog.dart';
import 'billing_view.dart' show RaftBillingPlans;
import 'management_support.dart';

/// Mounted by the agent detail only where the viewer can manage a non-external
/// agent that has a computer (Web: `canManageAgent && !isExternalAgent`, the
/// `agent_migration_v0` flag and `agent.machineId`).
class AgentMigrationSection extends StatefulWidget {
  const AgentMigrationSection({
    super.key,
    required this.controller,
    required this.agent,
    required this.machines,
    this.now,
    this.openExternal,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> agent;

  /// Every computer of the server (empty while the list is in flight).
  final List<Map<String, dynamic>> machines;

  /// Clock for the free-trial Pro gate and the notice (tests freeze it).
  final DateTime Function()? now;

  /// Opens a Web page in the browser; the platform launcher when null.
  final Future<bool> Function(Uri uri)? openExternal;
  @override
  State<AgentMigrationSection> createState() => _AgentMigrationSectionState();
}

class _AgentMigrationSectionState
    extends ManagementState<AgentMigrationSection> {
  @override
  WorkspaceController get w => widget.controller;

  String get _agentId => '${widget.agent['id']}';

  /// The agent's migration: read, pushed, and polled while it runs.
  late AgentMigrationStatus _status;

  /// Web `useServerStore().billing`: GET /billing/subscription. Null until a
  /// read lands; a failed read leaves it as it was.
  Map<String, dynamic>? billing;
  bool loadingBilling = false;

  /// Web `billingChecking`: Migrate waits for the first billing answer.
  bool get billingChecking => billing == null && loadingBilling;
  bool get requiresUpgrade => agentMigrationRequiresUpgrade(
    billing?['plan'],
    trialActive: RaftBillingPlans.trialActive(
      (widget.now ?? DateTime.now)().toUtc(),
    ),
  );

  /// The migration the cancel dialog shows and whether it can still be
  /// cancelled: they follow every read while the dialog is open.
  final _live = ValueNotifier<Map<String, dynamic>>({});
  final _cancellable = ValueNotifier<bool>(true);
  int _planRevision = 0;

  /// Web `watchedActiveRef`: the run this section saw active.
  String? _watchedRef;

  @override
  void initState() {
    super.initState();
    _bindStatus();
    _planRevision = w.planRevision;
    w.addListener(_planChanged);
    startManagement();
  }

  void _bindStatus() {
    _status = AgentMigrationStatus(w, _agentId)..addListener(_statusChanged);
    _observe();
  }

  @override
  void didUpdateWidget(AgentMigrationSection old) {
    super.didUpdateWidget(old);
    if (old.agent['id'] != widget.agent['id']) {
      _status
        ..removeListener(_statusChanged)
        ..dispose();
      _watchedRef = null;
      _bindStatus();
    }
  }

  @override
  void dispose() {
    w.removeListener(_planChanged);
    _status
      ..removeListener(_statusChanged)
      ..dispose();
    _live.dispose();
    _cancellable.dispose();
    super.dispose();
  }

  void _statusChanged() {
    _observe();
    if (mounted) setState(() {});
  }

  /// Web `watchedActiveRef`: completion broadcasts no agent update, so when
  /// this section watched a run finish it re-reads the agent directory (the
  /// Computer row, the computer's agent list and the fleet grouping follow).
  /// A canceled or failed end is covered too: a post-flip cancel leaves the
  /// agent on the target computer.
  void _observe() {
    final migration = _status.migration;
    _live.value = migration;
    _cancellable.value = canCancelMigration(migration);
    final phase = migrationPhase(migration['state'] as String?);
    final ref = migration['migrationRef'];
    if (phase == 'active') {
      _watchedRef = ref is String ? ref : null;
    } else if (ref is String && ref == _watchedRef && phase != null) {
      _watchedRef = null;
      w.services.entityDirectory.reloadAgents();
    }
  }

  /// Web `server:plan-updated` reloads billing.
  void _planChanged() {
    if (_planRevision == w.planRevision) return;
    _planRevision = w.planRevision;
    unawaited(loadBilling());
  }

  /// Web `loadBilling`: a failed read just leaves the gate undecided.
  Future<void> loadBilling() async {
    if (w.server == null) return;
    final generation = w.client.generation;
    loadingBilling = true;
    try {
      final value = await w.query('/billing/subscription');
      if (accepts(generation) && value is Map) {
        setState(() => billing = Map<String, dynamic>.from(value));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => loadingBilling = false);
    }
  }

  @override
  Future<void> loadData(int request, int generation) => loadBilling();

  @override
  void clearData() {
    billing = null;
  }

  bool get active => _status.active;

  MigrationComputers _computers(Object? targetId) {
    String? name(Object? id) =>
        widget.machines.where((m) => m['id'] == id).firstOrNull?['name']
            as String?;
    return MigrationComputers(
      sourceName: name(widget.agent['machineId']),
      targetName: name(targetId),
      sourceId: widget.agent['machineId'] as String?,
      targetId: targetId as String?,
    );
  }

  /// Web AgentMigrationDialog "Open computer settings" / "Open Computers":
  /// recovery happens on the Computers page, opened in the browser so the
  /// dialog (and the chosen target) stays put for the retry.
  Future<void> _openComputers(String? computerId) async {
    final slug = w.server?.string('slug') ?? '';
    if (slug.isEmpty) return;
    final uri = ContentLinks.originFor(w.client.origin).replace(
      path:
          '/s/$slug/${computerId == null ? 'computers' : 'computer/$computerId'}',
    );
    await (widget.openExternal?.call(uri) ??
        launchUrl(uri, mode: LaunchMode.externalApplication));
  }

  /// Web AgentMigrationUpgradeDialog: "Upgrade" opens Plan & Billing.
  Future<void> _showUpgrade() async {
    final viewPlans = await scopedDialog<bool>(
      (_) => RaftConfirmDialog(
        title: 'Upgrade to Pro to migrate agents',
        message: 'After upgrading, you can migrate an agent and its workspace to another computer.',
        confirmLabel: 'Upgrade',
        confirmVariant: RaftButtonRecipeVariant.accent,
        maxWidth: 448,
      ),
    );
    if (viewPlans != true || !mounted) return;
    w.setSection('billing');
  }

  /// Web `openMigration`: a known non-Pro plan gets the upgrade prompt.
  Future<void> migrate() async {
    if (requiresUpgrade) {
      await _showUpgrade();
      return;
    }
    // Web AgentMigrationDialog: every other computer; an offline one is
    // listed and the server answers TARGET_COMPUTER_OFFLINE.
    final targets = widget.machines
        .where(
          (m) =>
              m['isComputer'] == true && m['id'] != widget.agent['machineId'],
        )
        .toList();
    var proRequired = false;
    final generation = w.client.generation, sourceAuthority = authority;
    await scopedDialog<bool>(
      form: true,
      (dialogContext) => AgentMigrationStartDialog(
        targets: targets,
        openComputers: (id) => unawaited(_openComputers(id)),
        start: (target) async {
          if (!accepts(generation) || sourceAuthority != authority) {
            throw StateError('The active workspace changed. Reopen this form.');
          }
          try {
            await w.command(
              'POST',
              '/agents/$_agentId/migrate',
              data: {'targetComputer': target},
            );
          } catch (e) {
            if (accepts(generation) &&
                sourceAuthority == authority &&
                invalidateDeniedMutation(e) &&
                dialogContext.mounted) {
              Navigator.of(dialogContext).pop(false);
            }
            // Web handleProRequired: the server is the authority on the
            // plan. Closing the form without an error hands over to the
            // upgrade prompt below.
            if (isMigrationProPlanRequiredError(e)) {
              proRequired = true;
              return;
            }
            if (e is RaftApiException && const [401, 403].contains(e.status)) {
              rethrow;
            }
            logUserError(e, where: 'agent migration start');
            throw AgentMigrationStartFailure(
              migrationStartErrorPresentation(e, _computers(target)),
            );
          }
        },
      ),
    );
    if (proRequired) {
      unawaited(loadBilling());
      await _showUpgrade();
      return;
    }
    await _status.reload();
  }

  /// Web AgentMigrationCancelDialog `MAX_CANCEL_ATTEMPTS`: a running migration
  /// bumps its revision at every step, so the revision the dialog opened with
  /// is often stale by the time it is confirmed.
  static const maxCancelAttempts = 3;

  /// Submits the cancellation for the migration shown in the dialog. A stale
  /// rejection re-reads the status and retries for the same migration while it
  /// is still cancellable; anything else refreshes and is surfaced.
  Future<void> _submitCancel(int generation, String sourceAuthority) async {
    if (!accepts(generation) || sourceAuthority != authority) {
      throw StateError('The active workspace changed. Reopen this form.');
    }
    final opened = _live.value;
    if (!canCancelMigration(opened)) return;
    final ref = opened['migrationRef'];
    var revision = opened['revision'];
    for (var attempt = 1; ; attempt++) {
      try {
        await w.command(
          'POST',
          '/agents/$_agentId/migration/cancel',
          data: {'migrationRef': ref, 'expectedRevision': revision},
        );
        await _status.reload();
        return;
      } catch (e) {
        if (accepts(generation) &&
            sourceAuthority == authority &&
            invalidateDeniedMutation(e)) {
          rethrow;
        }
        final code = e is RaftApiException ? e.details['code'] : null;
        if (code == 'MIGRATION_REVISION_STALE' && attempt < maxCancelAttempts) {
          Map<String, dynamic>? latest;
          try {
            latest = managementMap(
              managementMap(
                await w.query('/agents/$_agentId/migration'),
              )['migration'],
            );
          } catch (_) {}
          if (latest != null &&
              latest['migrationRef'] == ref &&
              canCancelMigration(latest)) {
            revision = latest['revision'];
            continue;
          }
        }
        await _status.reload();
        throw migrationCancelUserError(e);
      }
    }
  }

  Future<void> cancel() async {
    if (!canCancelMigration(_status.migration)) return;
    final generation = w.client.generation, sourceAuthority = authority;
    _live.value = _status.migration;
    _cancellable.value = true;
    await scopedDialog<bool>(
      (_) => ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: _live,
        builder: (context, current, _) {
          final source = MigrationText('{name}', {
            'name': migrationComputerLabel(
              widget.machines,
              current['sourceMachineId'],
            ),
          }).text(context);
          final target = MigrationText('{name}', {
            'name': migrationComputerLabel(
              widget.machines,
              current['targetMachineId'],
            ),
          }).text(context);
          final t = RaftTokens.of(context);
          return RaftConfirmDialog(
            title: 'Cancel migration?',
            confirmLabel: 'Stop',
            cancelLabel: 'Continue',
            loadingLabel: 'Canceling…',
            confirmVariant: RaftButtonRecipeVariant.warning,
            confirmEnabled: _cancellable,
            maxWidth: 448,
            onConfirm: () => _submitCancel(generation, sourceAuthority),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  raftText(context, 'Canceling is safe'),
                  style: RaftTypography.body(
                    t,
                    size: 14,
                    line: 14 * 1.625,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  raftFormat(
                    context,
                    'Raft will stop the migration from {source} to {target} and clean up on both computers. Your agent and its workspace stay on whichever computer has them now.',
                    {'source': source, 'target': target},
                  ),
                  style: RaftTypography.body(
                    t,
                    size: 14,
                    line: 14 * 1.625,
                    color: t.strong,
                  ),
                ),
                const SizedBox(height: RaftSpace.x3),
                MigrationReference(migrationRef: '${current['migrationRef']}'),
                const SizedBox(height: RaftSpace.x3),
                Text(
                  raftText(
                    context,
                    'Canceling finishes only after both computers confirm. Keep both computers online until then.',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    await _status.reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final migration = _status.migration;
    final phase = migrationPhase(migration['state'] as String?);
    final shown = migration.isNotEmpty;
    final canRetry = migrationPhase(migration['state'] as String?) == 'failed';
    final statusError = _status.error;
    return RaftPanelSection(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Row(
                children: [
                  RaftSectionEyebrow(raftText(context, 'Agent migration')),
                  const SizedBox(width: RaftSpace.x2),
                  // Migration is a Pro feature; on other plans Migrate opens
                  // the upgrade prompt.
                  RaftRecipeBadge(
                    raftText(context, 'Pro'),
                    key: const ValueKey('agent-migration-pro-badge'),
                    variant: RaftBadgeRecipeVariant.accent,
                  ),
                ],
              ),
            ),
            // What migration does matters before one exists; once a
            // migration is shown, its block says it.
            if (!shown || phase == 'completed' || phase == 'canceled') ...[
              const SizedBox(height: RaftSpace.x1),
              Text(
                raftText(
                  context,
                  'Move this agent and its workspace to another computer. The agent stops while it migrates, then starts again there.',
                ),
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 16,
                  color: t.muted,
                ),
              ),
            ],
          ],
        ),
        if (shown)
          MigrationProgressPanel(
            migration: migration,
            machines: widget.machines,
            now: (widget.now ?? DateTime.now)().toUtc(),
            formatTimestamp: agentTimeFormatter(context, w).shortDateTime,
            onCancel: () => run(cancel, refresh: false),
          ),
        if (statusError != null)
          RaftBanner(
            status: RaftBannerRecipeStatus.warning,
            size: RaftBannerRecipeSize.sm,
            title: raftText(context, "Can't load migration status"),
            descriptionBuilder: (style) => MigrationErrorContent(
              presentation: migrationErrorPresentation(
                code: statusError is RaftApiException
                    ? statusError.details['code'] as String?
                    : null,
                rawMessage: statusError is RaftApiException
                    ? statusError.message
                    : null,
                context: MigrationErrorContext.status,
              ),
              style: style,
            ),
          ),
        if (error != null) RaftErrorBanner(error!, small: true),
        // While a migration runs, the progress block owns the only action
        // (Cancel).
        if (!active)
          Align(
            alignment: Alignment.centerRight,
            child: RaftButton(
              label: raftText(
                context,
                canRetry ? 'Try migration again' : 'Migrate',
              ),
              tone: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.sm,
              onPressed: busy || billingChecking
                  ? null
                  : () => run(migrate, refresh: false),
            ),
          ),
      ],
    );
  }
}
