// Computer detail data and requests for raft_ui RaftComputerDetailView (the
// port of Web MachineDetailPanel.tsx). Product rules (version fact, upgrade
// card state, command bundle, runtime availability) live here; the view
// owns only presentation and UI state.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'agent_detail_view.dart' show sourceRuntimeDisplayNames;
import 'agent_metadata_catalog.dart';
import 'agent_metadata_projection.dart';
import 'computer_setup_commands.dart';
import 'runtime_usage_chip.dart';
import 'bulk_agent_model_change.dart';
import 'bulk_agent_model_dialog.dart';
import 'management_support.dart'
    show
        cachedServerFlag,
        rememberServerFlag,
        pageIdentity,
        readPageSnapshot,
        writePageSnapshot;
import '../data/runtime_account_usage.dart';

// ------------------------------------------------------------------ model

/// packages/shared runtimeCatalog getMachineRuntimeDisplayOptions(): the
/// supported, non-deprecated runtimes; `binary == ''` = in-process runtime.
const computerRuntimeOptions = <(String, String, bool)>[
  ('claude', 'Claude Code', false),
  ('codex', 'Codex CLI', false),
  ('grok', 'Grok Build', false),
  ('builtin', 'Built-in Pi', true),
  ('kimi-sdk', 'Kimi Code', true),
  ('copilot', 'Copilot CLI', false),
  ('cursor', 'Cursor CLI', false),
  ('opencode', 'OpenCode', false),
  ('pi', 'Pi', false),
];

final _semver = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$');

/// shared compareComputerVersions / isComputerSemver.
bool isComputerSemver(String? v) => v != null && _semver.hasMatch(v);
int compareComputerVersions(String a, String b) {
  final x = _semver.firstMatch(a)!, y = _semver.firstMatch(b)!;
  for (var i = 1; i <= 3; i++) {
    final d = int.parse(x[i]!).compareTo(int.parse(y[i]!));
    if (d != 0) return d;
  }
  if (x[4] == y[4]) return 0;
  if (x[4] == null) return 1;
  if (y[4] == null) return -1;
  return x[4]!.compareTo(y[4]!);
}

/// utils/computerVersionFact.ts: unknown | cannotCheck | current | outdated.
sealed class ComputerVersionFact {
  const ComputerVersionFact();
}

class ComputerVersionUnknown extends ComputerVersionFact {
  const ComputerVersionUnknown();
}

class ComputerVersionCannotCheck extends ComputerVersionFact {
  const ComputerVersionCannotCheck();
}

class ComputerVersionCurrent extends ComputerVersionFact {
  const ComputerVersionCurrent();
}

class ComputerVersionOutdated extends ComputerVersionFact {
  const ComputerVersionOutdated(this.available);
  final String available;
}

const _releaseLookupFailed = {
  'source_unparseable',
  'platform_unknown',
  'hands_unavailable',
  'hands_response_invalid',
  'hands_artifact_missing',
};

ComputerVersionFact computerVersionFact(Map m, String? latest) {
  final version = '${m['computerVersion'] ?? ''}'.trim();
  if (version.isEmpty) return const ComputerVersionUnknown();
  if (!isComputerSemver(version)) return const ComputerVersionCannotCheck();
  final policy = m['computerBroadcastPolicy'];
  final target = policy is Map && policy['eligibility'] == 'eligible'
      ? policy['targetVersion']
      : null;
  if (target is String &&
      isComputerSemver(target) &&
      compareComputerVersions(target, version) > 0) {
    return ComputerVersionOutdated(target);
  }
  final l = latest?.trim();
  if (l == null || l.isEmpty || !isComputerSemver(l)) {
    return const ComputerVersionCannotCheck();
  }
  if (compareComputerVersions(l, version) <= 0) {
    return const ComputerVersionCurrent();
  }
  if (policy is Map && _releaseLookupFailed.contains(policy['reasonCode'])) {
    return const ComputerVersionCannotCheck();
  }
  return ComputerVersionOutdated(l);
}

/// getComputerAvailableVersion: the `→ vX` a list row points at.
String? computerAvailableVersion(Map m, String? latest) {
  if (m['isComputer'] != true) return null;
  final fact = computerVersionFact(m, latest);
  if (fact is ComputerVersionOutdated) return fact.available;
  final policy = m['computerBroadcastPolicy'];
  if (fact is ComputerVersionUnknown &&
      m['computerUpgradeAvailable'] == true &&
      policy is Map &&
      policy['eligibility'] == 'eligible' &&
      policy['targetVersion'] is String) {
    return policy['targetVersion'] as String;
  }
  return null;
}

/// utils/machineRunLabel.ts.
(String, bool) computerRunLabel(Map m) {
  final kind = m['isComputer'] == true ? 'computer' : 'legacy';
  if (m['status'] != 'online') return ('$kind offline', true);
  final version = m['isComputer'] == true
      ? m['computerVersion']
      : m['daemonVersion'];
  if (version is String && version.isNotEmpty) {
    return ('$kind v$version', false);
  }
  return ('$kind online', false);
}

/// utils/fileSizePresentation.ts formatFileSizeBytes (en).
String computerFileSize(num bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// machineDiskLowPresentation: online and < 10% (and < the shared byte cap)
/// free. Returns (free, freePercent) or null.
(String, double)? computerDiskLow(Map m) {
  final disk = m['diskStatus'];
  if (m['status'] != 'online' || disk is! Map) return null;
  final available = disk['availableBytes'], total = disk['totalBytes'];
  if (available is! num || total is! num || total <= 0) return null;
  final percent = available / total * 100;
  // shared MACHINE_DISK_LOW_FREE_PERCENT 10, MAX_AVAILABLE_BYTES 20 GiB.
  if (percent >= 10 || available >= 20 * 1024 * 1024 * 1024) return null;
  return (computerFileSize(available), (percent * 10).floor() / 10);
}

String _pct(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// The Web agent row status text (utils/activity.ts formatActivityText via
/// resolveAgentDisplayState): [agentActivityText] over the row's ambient
/// display, so typed detail kinds and external presence apply.
String computerAgentActivityText(
  Map a, {
  DateTime? now,
  String Function(String source, Map<String, Object?> values)? translate,
  String Function(DateTime seen)? relativeTime,
}) {
  final display = agentRowAmbientDisplay(a, now: now);
  final seen = a['lastSeenAt'] is String
      ? DateTime.tryParse(a['lastSeenAt'] as String)
      : null;
  return translate == null
      ? agentDisplayText(display, lastSeenAt: seen, relativeTime: relativeTime)
      : agentDisplayText(
          display,
          lastSeenAt: seen,
          relativeTime: relativeTime,
          translate: translate,
        );
}

// ------------------------------------------------------------------ panel

/// Binds one machine row of the workspace directory to
/// [RaftComputerDetailView]: projects the row into view data and performs
/// every request (PATCH name/description, workspaces, restart, upgrade,
/// delete, bulk agent lifecycle).
class ComputerDetailPanel extends StatefulWidget {
  const ComputerDetailPanel({
    super.key,
    required this.controller,
    required this.machine,
    this.onClose,
    this.onOpenAgent,
    this.onCreateAgent,
    this.remoteUpgradeV2,
    this.now,
    this.deployment = const String.fromEnvironment(
      'RAFT_DEPLOYMENT_ENV',
      defaultValue: 'production',
    ),
  });

  final WorkspaceController controller;
  final Map<String, dynamic> machine;
  final VoidCallback? onClose;
  final ValueChanged<String>? onOpenAgent;
  final VoidCallback? onCreateAgent;

  /// `remote_computer_upgrade_v2` override; null = the controller's flag.
  final bool? remoteUpgradeV2;
  final DateTime Function()? now;

  /// VITE_DEPLOYMENT_ENV equivalent for the command bundle.
  final String deployment;

  @override
  State<ComputerDetailPanel> createState() => _ComputerDetailPanelState();
}

class _ComputerDetailPanelState extends State<ComputerDetailPanel> {
  WorkspaceController get w => widget.controller;
  Map<String, dynamic> get m => widget.machine;
  String get id => m['id'] as String;
  String get serverId => w.server?.id ?? '';
  DateTime _now() => widget.now?.call() ?? DateTime.now();
  bool get online => m['status'] == 'online';
  bool get isComputer => m['isComputer'] == true;

  /// A refused one-click upgrade (Web upgradeRefusalFromCode), held until
  /// the machine changes.
  String? upgradeRefusal;
  late String bulkScope;
  bool bulkModelEnabled = false;
  final receiptTimer = RaftIdleTimer(yieldToAnimation: false);
  String get receiptKey => 'bulk-model-receipt:$id';
  BulkModelReceipt? get receipt =>
      readPageSnapshot(w, receiptKey)?['receipt'] as BulkModelReceipt?;

  @override
  void initState() {
    super.initState();
    w.services.entityDirectory.addListener(_changed);
    w.addListener(_changed);
    w.services.entityDirectory.ensure([WorkspaceEntityKind.agents]);
    bulkScope = pageIdentity(w);
    bulkModelEnabled = cachedServerFlag(w, bulkModelFlag) ?? false;
    unawaited(_evaluateBulkModel());
    _scheduleReceipt();
  }

  @override
  void didUpdateWidget(ComputerDetailPanel old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, w)) {
      old.controller.services.entityDirectory.removeListener(_changed);
      old.controller.removeListener(_changed);
      w.services.entityDirectory.addListener(_changed);
      w.addListener(_changed);
      w.services.entityDirectory.ensure([WorkspaceEntityKind.agents]);
    }
    if (pageIdentity(w) != bulkScope || !identical(old.controller, w)) {
      bulkScope = pageIdentity(w);
      bulkModelEnabled = cachedServerFlag(w, bulkModelFlag) ?? false;
      unawaited(_evaluateBulkModel());
    }
    _scheduleReceipt();
    if (old.machine['id'] != id ||
        old.machine['computerVersion'] != m['computerVersion']) {
      upgradeRefusal = null;
    }
  }

  @override
  void dispose() {
    w.services.entityDirectory.removeListener(_changed);
    w.removeListener(_changed);
    receiptTimer.cancel();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (bulkScope != pageIdentity(w)) {
      bulkScope = pageIdentity(w);
      bulkModelEnabled = cachedServerFlag(w, bulkModelFlag) ?? false;
      unawaited(_evaluateBulkModel());
    }
    _scheduleReceipt();
    setState(() {});
  }

  Future<void> _evaluateBulkModel() async {
    final identity = pageIdentity(w), controller = w;
    try {
      final value = await controller.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: [bulkModelFlag],
          serverId: w.server?.id,
        ),
      );
      if (!mounted ||
          !identical(w, controller) ||
          identity != pageIdentity(w)) {
        return;
      }
      final evaluations = value is Map ? value['evaluations'] : null;
      final enabled =
          evaluations is List &&
          evaluations.any(
            (v) =>
                v is Map && v['key'] == bulkModelFlag && v['enabled'] == true,
          );
      rememberServerFlag(w, bulkModelFlag, enabled, identity);
      if (enabled != bulkModelEnabled) {
        setState(() => bulkModelEnabled = enabled);
      }
    } catch (_) {
      // A never-evaluated flag fails closed; an accepted cached value survives.
    }
  }

  void _scheduleReceipt() {
    receiptTimer.cancel();
    final value = receipt;
    if (value == null) return;
    final now = _now();
    final deadlines = [
      if (value.highlightUntil.isAfter(now)) value.highlightUntil,
      if (value.success && value.bannerUntil.isAfter(now)) value.bannerUntil,
    ]..sort();
    if (deadlines.isNotEmpty) {
      receiptTimer.start(deadlines.first.difference(now), () {
        if (mounted) {
          setState(() {});
          _scheduleReceipt();
        }
      });
    }
  }

  Future<bool> _changeModels(
    List<String> selected, {
    BulkModelReceipt? retry,
  }) async {
    final controller = w, machineId = id, identity = pageIdentity(w);
    bool authorized() =>
        mounted &&
        identical(w, controller) &&
        id == machineId &&
        identity == pageIdentity(w) &&
        bulkModelEnabled &&
        canManage;
    if (!authorized()) return false;
    final selectedIds = selected.toSet();
    final targets = [
      for (final agent in agents)
        if (selectedIds.contains(agent['id'])) agent['id'] as String,
    ];
    if (targets.isEmpty) return false;
    final result = await showBulkAgentModelDialog(
      context,
      controller: w,
      machine: m,
      agentIds: targets,
      authorized: authorized,
      onOpenAgent: widget.onOpenAgent,
      retry: retry,
      now: _now,
    );
    if (!authorized() || result == null) return false;
    writePageSnapshot(w, receiptKey, identity, {'receipt': result});
    _changed();
    return true;
  }

  Widget? _modelNotice() {
    final value = receipt;
    if (!bulkModelEnabled || value == null || !value.visibleAt(_now())) {
      return null;
    }
    final count = value.changed.length;
    final description = value.success
        ? '${raftFormat(context, count == 1 ? '{count} agent now uses {target}.' : '{count} agents now use {target}.', {'count': count, 'target': bulkModelLabel(value.target.runtime, value.target.model, withRuntime: true)})}${value.skipped.isEmpty ? '' : ' ${raftFormat(context, '{count} skipped.', {'count': value.skipped.length})}'}'
        : raftFormat(context, "{failed} of {total} changes didn't finish.", {
            'failed': value.unfinished.length,
            'total': value.total,
          });
    return RaftBanner(
      key: ValueKey(
        value.success
            ? 'bulk-model-success-banner'
            : 'bulk-model-partial-banner',
      ),
      status: value.success
          ? RaftBannerRecipeStatus.success
          : RaftBannerRecipeStatus.warning,
      size: RaftBannerRecipeSize.sm,
      description: description,
      descriptionWeight: FontWeight.w700,
      action: Wrap(
        spacing: RaftSpace.x1_5,
        children: [
          if (!value.success && canManage)
            RaftAgentDialogButton(
              key: const ValueKey('bulk-model-try-again'),
              label: raftText(context, 'Try again'),
              size: RaftButtonRecipeSize.sm,
              onPressed: () =>
                  _changeModels(value.unfinished.keys.toList(), retry: value),
            ),
          RaftAgentDialogButton(
            key: const ValueKey('bulk-model-dismiss'),
            label: raftText(context, 'Dismiss'),
            size: RaftButtonRecipeSize.sm,
            onPressed: () {
              w.resourceSnapshots.remove('page:$receiptKey');
              _changed();
            },
          ),
        ],
      ),
    );
  }

  bool get canManage {
    final me = w.client.user?.id;
    final creator = m['creator'];
    return m['computerAttachedByCurrentUser'] == true ||
        (me != null && creator is Map && creator['id'] == me) ||
        [
          'editMachines',
          'controlComputers',
          'removeMachines',
          'rotateMachineKeys',
          'createAgents',
          'migrateAgents',
        ].any(w.can);
  }

  List<Map<String, dynamic>> get agents => [
    for (final a in w.services.entityDirectory.rows(WorkspaceEntityKind.agents))
      if (a['deletedAt'] == null && a['machineId'] == id) a,
  ];

  bool get windows => '${m['os'] ?? ''}'.toLowerCase().startsWith('win');

  RaftComputerCommandSet? get commands {
    final c = ComputerCommands.build(
      slug: w.server?.string('slug') ?? '',
      serverUrl: w.client.origin,
      deployment: widget.deployment,
      windows: windows,
      machineId: isComputer ? null : id,
    );
    return c == null
        ? null
        : RaftComputerCommandSet(
            install: c.install,
            setup: c.setup,
            status: c.status,
            doctor: c.doctor,
            restart: c.restart,
            restartService: c.restartService,
          );
  }

  /// MachineDetailPanel CardState: one status sentence + next step.
  RaftComputerService service(ComputerVersionFact fact) {
    final policy = m['computerBroadcastPolicy'];
    final target = policy is Map ? policy['targetVersion'] as String? : null;
    final gated =
        policy is Map &&
        (policy['reasonCode'] == 'broadcast_disabled' ||
            policy['reasonCode'] == 'broadcast_gate_unavailable');
    final webUpgradeOn =
        (widget.remoteUpgradeV2 ?? w.remoteComputerUpgradeEnabled) && !gated;
    final oneClickTarget =
        m['computerUpgradeAvailable'] == true &&
            policy is Map &&
            policy['eligibility'] == 'eligible' &&
            target != null
        ? target
        : null;
    final request = m['upgradeRequest'];
    final pending = request is Map && request['state'] == 'pending';
    final supported =
        (m['remoteUpgradeSupported'] ??
            isComputerSemver('${m['computerVersion'] ?? ''}')) ==
        true;
    RaftComputerService card(
      RaftComputerServiceKind kind,
      String sentence, [
      String? version,
    ]) => RaftComputerService(
      kind: kind,
      sentence: sentence,
      version: version,
      webUpgradeOn: webUpgradeOn,
    );
    return switch (fact) {
      ComputerVersionUnknown() => card(
        RaftComputerServiceKind.reading,
        'Reading the version; check back shortly.',
      ),
      ComputerVersionCannotCheck() => card(
        RaftComputerServiceKind.cannotCheck,
        "Can't check for a new version right now. Try again later.",
      ),
      ComputerVersionCurrent() => card(
        RaftComputerServiceKind.upToDate,
        'Up to date.',
      ),
      ComputerVersionOutdated(:final available) when pending => card(
        RaftComputerServiceKind.upgrading,
        'Upgrading to v${request['targetVersion'] ?? available}. The Computer will disconnect briefly.',
        '${request['targetVersion'] ?? available}',
      ),
      ComputerVersionOutdated(:final available)
          when upgradeRefusal == 'not_allowed' =>
        card(
          RaftComputerServiceKind.commands,
          "This Computer can't be upgraded from the web right now.",
          available,
        ),
      ComputerVersionOutdated()
          when upgradeRefusal != 'web_upgrade_off' &&
              upgradeRefusal != 'too_old' &&
              webUpgradeOn &&
              supported &&
              oneClickTarget != null =>
        card(
          RaftComputerServiceKind.oneClick,
          'v$oneClickTarget is available.',
          oneClickTarget,
        ),
      ComputerVersionOutdated(:final available) => card(
        RaftComputerServiceKind.commands,
        'v$available is available. Run these two commands on that machine to upgrade:',
        available,
      ),
    };
  }

  RaftComputerDetailData data() {
    final fact = computerVersionFact(
      m,
      w.services.entityDirectory.latestComputerVersion,
    );
    final runtimes = [
      for (final r in (m['runtimes'] as List? ?? const [])) '$r',
    ];
    final created = DateTime.tryParse('${m['createdAt'] ?? ''}');
    final creator = m['creator'];
    final disk = computerDiskLow(m);
    final version = m['computerVersion'];
    return RaftComputerDetailData(
      id: id,
      name: '${m['name'] ?? ''}',
      description: m['description'] as String?,
      hostname: m['hostname'] as String?,
      os: m['os'] as String?,
      online: online,
      isComputer: isComputer,
      windows: windows,
      slug: w.server?.string('slug') ?? '',
      computerVersion: version is String && version.isNotEmpty ? version : null,
      versionKind: switch (fact) {
        ComputerVersionUnknown() => RaftComputerVersionKind.unknown,
        ComputerVersionCannotCheck() => RaftComputerVersionKind.cannotCheck,
        ComputerVersionCurrent() => RaftComputerVersionKind.current,
        ComputerVersionOutdated() => RaftComputerVersionKind.outdated,
      },
      availableVersion: fact is ComputerVersionOutdated ? fact.available : null,
      runtimes: [
        for (final (rid, name, inProcess) in computerRuntimeOptions)
          (
            runtimes.contains(rid)
                ? name
                : '$name${inProcess ? ' (update computer)' : ' (not installed)'}',
            runtimes.contains(rid),
          ),
      ],
      createdLabel: created == null
          ? ''
          : DateFormat.yMMMd('en').format(created.toUtc()),
      creator: creator is Map
          ? RaftComputerCreator(
              name: nonEmptyOr(creator['displayName'], creator['name']),
              handle: '${creator['name']}',
              avatarUrl: creator['avatarUrl'] as String?,
            )
          : null,
      diskLowTitle: disk == null
          ? null
          : 'Low disk space: ${disk.$1} free (${_pct(disk.$2)}%)',
      agents: [
        for (final a in agents)
          RaftComputerAgent(
            id: a['id'] as String,
            name: agentRowName(a),
            avatarUrl: a['avatarUrl'] as String?,
            subtitle: _agentSubtitle(a),
            activity: agentRowAmbientDisplay(a).activity,
            activityText: computerAgentActivityText(a),
          ),
      ],
      canManage: canManage,
      commands: commands,
      service: isComputer && online ? service(fact) : null,
      highlightedAgentIds: bulkModelEnabled
          ? receipt?.highlightsAt(_now()) ?? const {}
          : const {},
    );
  }

  static String _agentSubtitle(Map a) {
    final runtime = '${a['runtime'] ?? ''}';
    final model = '${a['model'] ?? ''}';
    return [
      sourceRuntimeDisplayNames[runtime] ?? runtime,
      if (model.isNotEmpty) sourceRuntimeModelLabels[runtime]?[model] ?? model,
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  Future<void> _refreshComputers() => w.services.entityDirectory.refresh(
    WorkspaceEntityKind.computers,
    force: true,
  );

  Future<void> _patch(Map<String, dynamic> body) async {
    await w.command('PATCH', '/servers/$serverId/machines/$id', data: body);
    await _refreshComputers();
  }

  Future<List<RaftComputerWorkspace>> _scan() async {
    final r = await w.query('/servers/$serverId/machines/$id/workspaces');
    return [
      if (r is List)
        for (final e in r.whereType<Map>())
          RaftComputerWorkspace(
            directoryName: '${e['directoryName']}',
            label: '${e['agentName'] ?? e['directoryName']}',
            status: '${e['status']}',
            sizeLabel: computerFileSize(e['totalSizeBytes'] as num? ?? 0),
            filesLabel:
                '${e['fileCount'] ?? 0} ${e['fileCount'] == 1 ? 'file' : 'files'}',
            modifiedLabel: switch (DateTime.tryParse(
              '${e['lastModified'] ?? ''}',
            )) {
              final at? =>
                'Modified ${DateFormat.MMMd('en').format(at.toUtc())}',
              null => null,
            },
          ),
    ];
  }

  Future<void> _restart() async {
    try {
      await w.command(
        'POST',
        '/servers/$serverId/machines/$id/computer/restart',
      );
    } catch (e) {
      // Web handleComputerRestart: the server's `error` text, else the restart
      // message; the `computer_offline` code gets its own copy.
      throw RaftComputerActionError(
        userErrorText(
          e,
          fallback: 'Failed to request restart. The Computer must be online.',
          codeText: const {'computer_offline': 'The Computer is offline.'},
          where: 'computer restart',
        ),
      );
    }
  }

  Future<void> _upgrade(String target) async {
    setState(() => upgradeRefusal = null);
    try {
      await w.command(
        'POST',
        '/servers/$serverId/machines/$id/computer/upgrade',
        data: {'targetVersion': target},
      );
    } catch (e) {
      // Web upgradeRefusalFromCode: the server's `code`, never its text.
      final code = e is RaftApiException ? e.details['code'] : null;
      logUserError(e, where: 'computer upgrade');
      if (mounted) {
        setState(
          () => upgradeRefusal = switch (code) {
            'remote_upgrade_disabled' => 'web_upgrade_off',
            'computer_remote_upgrade_unsupported' => 'too_old',
            'computer_broadcast_not_eligible' => 'not_allowed',
            _ => 'unknown',
          },
        );
      }
    } finally {
      unawaited(_refreshComputers());
    }
  }

  Future<void> _delete() async {
    await w.command('DELETE', '/servers/$serverId/machines/$id');
    await _refreshComputers();
    widget.onClose?.call();
  }

  Future<int> _bulk(RaftComputerBulk mode, List<String> ids) async {
    var failed = 0;
    final lifecycle =
        mode == RaftComputerBulk.start || mode == RaftComputerBulk.stop;
    await Future.wait([
      for (final agent in ids)
        (() async {
          try {
            await w.command(
              'POST',
              lifecycle
                  ? '/agents/$agent/${mode.name}'
                  : '/agents/$agent/reset',
              data: lifecycle ? {} : {'mode': mode.name},
            );
          } catch (_) {
            failed++;
          }
        })(),
    ]);
    return failed;
  }

  @override
  Widget build(BuildContext context) => RaftComputerDetailView(
    agentNotice: _modelNotice(),
    headerKey:
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint
        ? const Key('computer-mobile-header')
        : null,
    backKey: const Key('computer-mobile-back'),
    onBack:
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint
        ? widget.onClose ?? () => Navigator.of(context).maybePop()
        : null,
    data: data(),
    actions: RaftComputerDetailActions(
      rename: (name) => _patch({'name': name}),
      describe: (description) => _patch({'description': description}),
      scanWorkspaces: _scan,
      deleteWorkspace: (dir) => w.command(
        'DELETE',
        '/servers/$serverId/machines/$id/workspaces/$dir',
      ),
      restart: _restart,
      upgrade: _upgrade,
      deleteComputer: _delete,
      bulk: _bulk,
      openAgent: widget.onOpenAgent,
      createAgent: widget.onCreateAgent,
      runtimeChip: _runtimeChip,
      changeModel: bulkModelEnabled && canManage ? _changeModels : null,
    ),
  );

  /// MachineDetailPanel RuntimeAccountUsageGateChip: detected usage
  /// runtimes open the usage card for viewers allowed to inspect it.
  Widget? _runtimeChip(int index) {
    if (index >= computerRuntimeOptions.length) return null;
    final (rid, name, _) = computerRuntimeOptions[index];
    final detected = [
      for (final r in (m['runtimes'] as List? ?? const [])) '$r',
    ].contains(rid);
    if (!detected || runtimeUsageProvider(rid) == null) return null;
    final versions = m['runtimeVersions'];
    return runtimeUsageGateChip(
      controller: w,
      enabled: canViewRuntimeUsage(w, m),
      runtimeId: rid,
      machineId: id,
      // Web aria-label: the chip's children (label + availability suffix)
      // are not one string here, so it reads the provider name.
      label: runtimeUsageProviderName(runtimeUsageProvider(rid)!),
      runtimeVersion: versions is Map ? versions[rid] as String? : null,
      chip: (status) =>
          RaftRuntimeChip(label: name, detected: true, trailing: status),
    );
  }
}
