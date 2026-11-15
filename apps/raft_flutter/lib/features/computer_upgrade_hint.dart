// What the Computer page and the rack row both say about a web upgrade that
// may not work (Web useComputerUpgradeCard: upgradeFailureHint,
// recommendRepair; ComputerManualInstall's commands). One place, so the page
// banner and the row popover cannot disagree.
import 'package:raft_ui/raft_ui.dart';

import 'computer_setup_commands.dart';
import 'computer_upgrade_outcome.dart';

/// The install line(s) for this machine's platform (what Add Computer shows):
/// one copyable line, or the two Windows / non-production steps.
List<RaftComputerInstallLine> computerInstallLines({
  required String slug,
  required String serverUrl,
  required String deployment,
  required bool windows,
}) {
  final c = ComputerCommands.build(
    slug: slug,
    serverUrl: serverUrl,
    deployment: deployment,
    windows: windows,
  );
  if (c == null) return const [];
  final one = windows ? null : c.installAndSetup;
  if (one != null) {
    return [
      (label: null, command: one, copyLabel: 'Copy Computer CLI command'),
    ];
  }
  return [
    (
      label: '1. Install',
      command: c.install,
      copyLabel: 'Copy 1. install command',
    ),
    (label: '2. Setup', command: c.setup, copyLabel: 'Copy 2. setup command'),
  ];
}

/// `upgradeRequest.failureHint`, offered only while the last request failed
/// and the Computer still runs the version it failed on.
RaftUpgradeFailureHint? computerUpgradeFailureHint(Map m) {
  final request = m['upgradeRequest'];
  if (request is! Map || request['state'] != 'failed') return null;
  if (computerUpgradeRequestOutcome(m) != RaftComputerUpgradeOutcome.failed) {
    return null;
  }
  final observed = request['observedVersion'];
  if (observed != null && observed != m['computerVersion']) return null;
  final hint = request['failureHint'];
  if (hint is! Map) return null;
  final reason = hint['reason'];
  if (reason != 'unsafe_kill_mode' && reason != 'installation_held') {
    return null;
  }
  String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
  return RaftUpgradeFailureHint(
    unsafeKillMode: reason == 'unsafe_kill_mode',
    unit: text(hint['unit']),
    scope: text(hint['scope']),
    killMode: text(hint['killMode']),
  );
}

/// The installer state looks unfinished (`installerRepairHint`).
bool computerRecommendRepair(Map m) =>
    m['installerRepairHint'] is Map &&
    (m['installerRepairHint'] as Map)['reason'] == 'unrecovered_operation';
