// Computer detail data and requests for raft_ui RaftComputerDetailView (the
// port of Web MachineDetailPanel.tsx). Product rules (version fact, upgrade
// card state, command bundle, runtime availability) live here; the view
// owns only presentation and UI state.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'agent_detail_view.dart' show sourceRuntimeDisplayNames;
import 'agent_metadata_catalog.dart';
import 'computer_setup_commands.dart';
import 'runtime_usage_chip.dart';
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

/// The Web agent row status text (utils/activity.ts formatActivityText).
String computerAgentActivityText(Map a) {
  final activity = '${a['activity'] ?? 'offline'}';
  final detail = a['activityDetail'];
  if (detail is String && detail.isNotEmpty && activity != 'offline') {
    return detail;
  }
  return switch (activity) {
    'online' => 'Online',
    'thinking' => 'Thinking',
    'working' => 'Working',
    'error' => 'Error',
    _ => 'Offline',
  };
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
  bool get online => m['status'] == 'online';
  bool get isComputer => m['isComputer'] == true;

  /// A refused one-click upgrade (Web upgradeRefusalFromCode), held until
  /// the machine changes.
  String? upgradeRefusal;

  @override
  void initState() {
    super.initState();
    w.entityDirectory.addListener(_changed);
    w.entityDirectory.ensure([WorkspaceEntityKind.agents]);
  }

  @override
  void didUpdateWidget(ComputerDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.machine['id'] != id ||
        old.machine['computerVersion'] != m['computerVersion']) {
      upgradeRefusal = null;
    }
  }

  @override
  void dispose() {
    w.entityDirectory.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
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
    for (final a in w.entityDirectory.rows(WorkspaceEntityKind.agents))
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
      w.entityDirectory.latestComputerVersion,
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
              name: '${creator['displayName'] ?? creator['name']}',
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
            name: '${a['displayName'] ?? a['name'] ?? ''}',
            avatarUrl: a['avatarUrl'] as String?,
            subtitle: _agentSubtitle(a),
            activity: '${a['activity'] ?? 'offline'}',
            activityText: computerAgentActivityText(a),
          ),
      ],
      canManage: canManage,
      commands: commands,
      service: isComputer && online ? service(fact) : null,
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

  Future<void> _refreshComputers() =>
      w.entityDirectory.refresh(WorkspaceEntityKind.computers, force: true);

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
    } on RaftApiException catch (e) {
      throw RaftComputerActionError(
        '$e'.contains('computer_offline')
            ? 'The Computer is offline.'
            : 'Failed to request restart. The Computer must be online.',
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
      final code = e is RaftApiException ? '$e' : '';
      if (mounted) {
        setState(
          () => upgradeRefusal = code.contains('remote_upgrade_disabled')
              ? 'web_upgrade_off'
              : code.contains('computer_remote_upgrade_unsupported')
              ? 'too_old'
              : code.contains('computer_broadcast_not_eligible')
              ? 'not_allowed'
              : 'unknown',
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
      label: name,
      runtimeVersion: versions is Map ? versions[rid] as String? : null,
      chip: (status) =>
          RaftRuntimeChip(label: name, detected: true, trailing: status),
    );
  }
}
