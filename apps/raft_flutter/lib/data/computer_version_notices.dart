// Web components/layout/computerVersionNotifications.tsx +
// utils/computersNeedingReinstall.ts (v1.24.0): the Notification Center's
// `computer-reinstall` and `computer-upgrade-deadline` entries.
import '../features/computer_version_tier.dart';
import 'system_notification_projection.dart';

/// canManageMachine: attached by me, created by me, or a role that manages
/// machines at all.
bool canManageMachine(Map machine, String? userId, bool managesMachines) {
  final creator = machine['creator'];
  return machine['computerAttachedByCurrentUser'] == true ||
      (userId != null && creator is Map && creator['id'] == userId) ||
      managesMachines;
}

const reinstallDismissalPrefix = 'computer-reinstall:';
const upgradeDeadlineDismissalPrefix = 'computer-upgrade-deadline:';

bool _needsReinstall(Map m) =>
    m['isComputer'] != true ||
    computerVersionTier(m).kind == ComputerTierKind.reinstall;

bool _needsUpgradeByDeadline(Map m) {
  final tier = computerVersionTier(m);
  return tier.kind == ComputerTierKind.upgrade &&
      tier.enforcedAt != null &&
      !tier.enforced;
}

/// The earliest deadline among [machines] that has not taken effect, or null.
DateTime? earliestVersionDeadline(Iterable<Map> machines) {
  DateTime? earliest;
  for (final m in machines) {
    final tier = computerVersionTier(m);
    if (tier.kind == ComputerTierKind.none ||
        tier.enforced ||
        tier.enforcedAt == null) {
      continue;
    }
    if (earliest == null || tier.enforcedAt!.isBefore(earliest)) {
      earliest = tier.enforcedAt;
    }
  }
  return earliest;
}

/// Sorted ids of every machine that needs it, online or not, so a flap does
/// not change it; an earlier dismissed key that already covers all of them is
/// reused so fixing one machine does not bring the entry back for the rest.
String reinstallDismissalKey(
  Iterable<Map> candidates,
  Set<String> dismissed,
  String prefix,
) {
  final ids = [for (final m in candidates) '${m['id']}']..sort();
  for (final key in dismissed) {
    if (!key.startsWith(prefix)) continue;
    final covered = key.substring(prefix.length).split(',').toSet();
    if (ids.every(covered.contains)) return key;
  }
  return '$prefix${ids.join(',')}';
}

/// "reinstall" (Computers), "migrate" (legacy daemons) or "mixed".
String reinstallNoticeKind(List<Map> machines) {
  final legacy = machines.where((m) => m['isComputer'] != true).length;
  if (legacy == 0) return 'reinstall';
  return legacy == machines.length ? 'migrate' : 'mixed';
}

List<SystemNotice> computerVersionNotices({
  required List<Map<String, dynamic>> machines,
  required String? userId,
  required bool managesMachines,
  required Set<String> dismissed,
}) {
  final manageable = [
    for (final m in machines)
      if (canManageMachine(m, userId, managesMachines)) m,
  ];
  final out = <SystemNotice>[];
  final reinstallAny = manageable.where(_needsReinstall).toList();
  final reinstall = [
    for (final m in reinstallAny)
      if (m['status'] == 'online') m,
  ];
  if (reinstall.isNotEmpty) {
    final deadline = earliestVersionDeadline(reinstall);
    out.add(
      SystemNotice(
        id: 'computer-reinstall',
        kind: SystemNoticeKind.warning,
        title: 'Computers need a one-time reinstall',
        body: 'Your agents and files stay where they are.',
        destination: SystemNoticeDestination.computer,
        targetId: '${reinstall.first['id']}',
        fingerprint: reinstallDismissalKey(
          reinstallAny,
          dismissed,
          deadline == null
              ? reinstallDismissalPrefix
              : '$reinstallDismissalPrefix${deadline.toUtc().toIso8601String()}:',
        ),
        parameters: {
          'count': reinstall.length,
          'name': '${reinstall.first['name'] ?? ''}',
          'need': reinstallNoticeKind(reinstall),
          'date': ?deadline?.toUtc().toIso8601String(),
        },
      ),
    );
  }
  final upgradeAny = manageable.where(_needsUpgradeByDeadline).toList();
  final upgrade = [
    for (final m in upgradeAny)
      if (m['status'] == 'online') m,
  ];
  final upgradeDeadline = earliestVersionDeadline(upgrade);
  if (upgrade.isNotEmpty && upgradeDeadline != null) {
    out.add(
      SystemNotice(
        id: 'computer-upgrade-deadline',
        kind: SystemNoticeKind.warning,
        title: 'Computers need an upgrade',
        body: 'Upgrade it from its page in one click.',
        destination: SystemNoticeDestination.computer,
        targetId: '${upgrade.first['id']}',
        fingerprint: reinstallDismissalKey(
          upgradeAny,
          dismissed,
          '$upgradeDeadlineDismissalPrefix${upgradeDeadline.toUtc().toIso8601String()}:',
        ),
        parameters: {
          'count': upgrade.length,
          'name': '${upgrade.first['name'] ?? ''}',
          'date': upgradeDeadline.toUtc().toIso8601String(),
        },
      ),
    );
  }
  return out;
}
