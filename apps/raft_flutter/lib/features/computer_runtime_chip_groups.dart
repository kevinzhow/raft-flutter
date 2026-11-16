// Web v1.24 shared runtimeCatalog getMachineRuntimeDisplayOptions() and
// components/machine/MachineRuntimeChips.tsx machineRuntimeChipGroups(): which
// runtimes the Computer page's Detected runtimes row lists and where each
// stands on this Computer. The generated agent_runtime_catalog.dart is the
// v1.21 list (no Qwen Code, Qoder, CodeBuddy), so the display list lives here.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart' show raftText;

/// A runtime of the machine display options: supported and not deprecated, in
/// catalog order. [inProcess] is `binary == ''` (nothing to install on the
/// Computer: one it does not report predates the runtime).
typedef ComputerRuntimeOption = ({
  String id,
  String name,
  bool inProcess,
  bool experimental,
});

const computerRuntimeOptions = <ComputerRuntimeOption>[
  (id: 'claude', name: 'Claude Code', inProcess: false, experimental: false),
  (id: 'codex', name: 'Codex CLI', inProcess: false, experimental: false),
  (id: 'grok', name: 'Grok Build', inProcess: false, experimental: false),
  (id: 'builtin', name: 'Built-in Pi', inProcess: true, experimental: false),
  (id: 'kimi-sdk', name: 'Kimi Code', inProcess: true, experimental: false),
  (id: 'cursor', name: 'Cursor CLI', inProcess: false, experimental: false),
  (id: 'opencode', name: 'OpenCode', inProcess: false, experimental: false),
  (id: 'pi', name: 'Pi', inProcess: false, experimental: false),
  (id: 'qwen', name: 'Qwen Code', inProcess: false, experimental: true),
  (id: 'qoder', name: 'Qoder', inProcess: false, experimental: true),
  (
    id: 'codebuddy',
    name: 'CodeBuddy Code',
    inProcess: false,
    experimental: true,
  ),
];

/// Where each display runtime stands on one Computer, from what it reports.
class ComputerRuntimeChipGroups {
  const ComputerRuntimeChipGroups({
    required this.detected,
    required this.updateComputer,
    required this.notInstalled,
  });

  /// Reported by the Computer.
  final List<ComputerRuntimeOption> detected;

  /// In-process runtimes the Computer does not report: it predates them.
  final List<ComputerRuntimeOption> updateComputer;

  /// Local CLIs the Computer did not detect.
  final List<ComputerRuntimeOption> notInstalled;
}

ComputerRuntimeChipGroups computerRuntimeChipGroups(
  Iterable<String> machineRuntimeIds,
) {
  final reported = machineRuntimeIds.toSet();
  final detected = <ComputerRuntimeOption>[];
  final update = <ComputerRuntimeOption>[];
  final missing = <ComputerRuntimeOption>[];
  for (final r in computerRuntimeOptions) {
    if (reported.contains(r.id)) {
      detected.add(r);
    } else if (r.inProcess) {
      update.add(r);
    } else {
      missing.add(r);
    }
  }
  return ComputerRuntimeChipGroups(
    detected: detected,
    updateComputer: update,
    notInstalled: missing,
  );
}

/// formatRuntimeLabelWithStatus for a listed (not deprecated) runtime: the
/// name, plus " (experimental)" for a preview runtime.
String computerRuntimeLabel(BuildContext context, ComputerRuntimeOption r) =>
    r.experimental
    ? '${r.name}${raftText(context, ' (experimental)')}'
    : r.name;
