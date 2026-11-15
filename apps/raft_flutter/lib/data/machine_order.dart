// Web components/layout/sidebarMachineOrder.ts and features/agent/
// pickFallbackMachine.ts: the one order every list or picker of computers
// uses, and the rules for which computer a new agent defaults to.

/// `isMyComputer`: one the viewer attached (`computerAttachedByCurrentUser`,
/// server-derived) or one Raft records them as the owner of (`ownerUserId`;
/// null is a Public Computer, nobody's).
bool isMyComputer(Map<String, dynamic> machine, String? userId) {
  if (machine['computerAttachedByCurrentUser'] == true) return true;
  return userId != null &&
      userId.isNotEmpty &&
      machine['ownerUserId'] == userId;
}

/// `orderMachinesLikeSidebar`: this device (the machine the app runs on; none
/// in a browser or on a phone), then the viewer's own computers, then the
/// rest, each group keeping the server's relative order.
List<Map<String, dynamic>> orderMachinesLikeSidebar(
  Iterable<Map<String, dynamic>> machines, {
  String? pinnedMachineId,
  String? userId,
}) {
  final tiers = <List<Map<String, dynamic>>>[[], [], []];
  for (final machine in machines) {
    final tier = pinnedMachineId != null && machine['id'] == pinnedMachineId
        ? 0
        : isMyComputer(machine, userId)
        ? 1
        : 2;
    tiers[tier].add(machine);
  }
  return [for (final tier in tiers) ...tier];
}

final _semverTriple = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

List<int>? _triple(String? version) {
  final match = version == null ? null : _semverTriple.firstMatch(version);
  return match == null
      ? null
      : [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

/// `bothComputerVersionsKnown(a, b) && !isDaemonOutdated(a, b)`.
bool _atLeast(String? version, String minimum) {
  final current = _triple(version), wanted = _triple(minimum);
  if (current == null || wanted == null) return false;
  for (var i = 0; i < 3; i++) {
    if (current[i] != wanted[i]) return current[i] > wanted[i];
  }
  return true;
}

/// `machineMeetsDaemonRequirement`: with a minimum, the computer's daemon
/// version must be known and at least that.
bool machineMeetsDaemonRequirement(
  Map<String, dynamic>? machine,
  String? minimumDaemonVersion,
) =>
    machine != null &&
    (minimumDaemonVersion == null ||
        minimumDaemonVersion.isEmpty ||
        _atLeast(machine['daemonVersion'] as String?, minimumDaemonVersion));

/// `pickFallbackMachine`: an online computer of the viewer's own comes before
/// any other online one.
Map<String, dynamic>? pickFallbackMachine(
  List<Map<String, dynamic>> machines,
  String? minimumDaemonVersion,
  String? userId,
) {
  final usable = [
    for (final m in machines)
      if (m['status'] == 'online' &&
          machineMeetsDaemonRequirement(m, minimumDaemonVersion))
        m,
  ];
  return usable.where((m) => isMyComputer(m, userId)).firstOrNull ??
      usable.firstOrNull;
}
