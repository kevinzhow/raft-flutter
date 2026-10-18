/// Web v1.21.12 `resolveAddMachineConnectedMachine`: setup creates its own
/// Computer row instead of using the raw-daemon registration placeholder.
/// A different row must belong to this user and be new or newly online.
({Map<String, dynamic> machine, bool requiresConfirmation})?
resolveComputerConnectionMatch(
  Iterable<Map<String, dynamic>> machines,
  String pendingId,
  List<Map<String, dynamic>> baseline,
) {
  final pending = machines.where((m) => m['id'] == pendingId).firstOrNull;
  if (pending?['status'] == 'online') {
    return (machine: pending!, requiresConfirmation: false);
  }
  bool eligible(Map<String, dynamic> m) =>
      m['isComputer'] == true &&
      m['status'] == 'online' &&
      m['computerAttachedByCurrentUser'] == true;
  Map<String, dynamic>? before(Map<String, dynamic> m) =>
      baseline.where((b) => b['id'] == m['id']).firstOrNull;
  final candidates = machines
      .where((m) => eligible(m) && before(m)?['status'] != 'online')
      .toList();
  if (candidates.isEmpty) return null;
  final selected = candidates.first;
  final freshSingle =
      !baseline.any(eligible) &&
      candidates.length == 1 &&
      before(selected) == null;
  return (machine: selected, requiresConfirmation: !freshSingle);
}
