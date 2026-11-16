// Web v1.24 shared runtimeCatalog getMachineRuntimeDisplayOptions() and
// components/machine/MachineRuntimeChips.tsx machineRuntimeChipGroups(): which
// runtimes the Computer page's Detected runtimes row lists and where each
// stands on this Computer, from the generated agent_runtime_catalog.dart.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart' show raftText;

import 'agent_runtime_catalog.dart' show runtimeInfos;

/// A runtime of the machine display options: supported and not deprecated, in
/// catalog order. [inProcess] is `binary == ''` (nothing to install on the
/// Computer: one it does not report predates the runtime).
typedef ComputerRuntimeOption = ({
  String id,
  String name,
  bool inProcess,
  bool experimental,
});

final List<ComputerRuntimeOption> computerRuntimeOptions = [
  for (final r in runtimeInfos)
    if (r.supported && !r.deprecated)
      (
        id: r.id,
        name: r.name,
        inProcess: r.binary.isEmpty,
        experimental: r.experimental,
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
