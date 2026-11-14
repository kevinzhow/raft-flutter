// Web utils/computerVersionTier.ts + hooks/useComputerVersionTier.ts: what a
// Computer's page says about its version against the version floor.
import 'computer_detail_view.dart'
    show compareComputerVersions, isComputerSemver;

/// shared COMPUTER_REMOTE_UPGRADE_MIN_VERSION / COMPUTER_VERSION_FLOOR.
const computerRemoteUpgradeMinVersion = '1.0.45';
const computerVersionFloorMin = '1.0.47';

/// How long an online Computer may go without a version before the page says
/// it needs a reinstall (UNREPORTED_VERSION_GRACE_MS).
const unreportedVersionGrace = Duration(seconds: 20);

enum ComputerTierKind { none, upgrade, reinstall, unreported }

class ComputerVersionTier {
  const ComputerVersionTier(
    this.kind, {
    this.reason = 'computer_version_unsupported',
    this.minVersion = computerVersionFloorMin,
    this.enforced = false,
    this.enforcedAt,
  });
  static const none = ComputerVersionTier(ComputerTierKind.none);
  final ComputerTierKind kind;
  final String reason;
  final String minVersion;
  final bool enforced;
  final DateTime? enforcedAt;
  bool get unknown => reason == 'computer_version_unknown';
  ComputerVersionTier as(ComputerTierKind next) => ComputerVersionTier(
    next,
    reason: reason,
    minVersion: minVersion,
    enforced: enforced,
    enforcedAt: enforcedAt,
  );
}

String _release(String v) => v.split('+').first.split('-').first;

/// The server's per-machine `versionGate`; a server that does not send the
/// field gets the same judgement against the floor on the client.
ComputerVersionTier computerVersionTier(Map m) {
  if (m['isComputer'] != true) return ComputerVersionTier.none;
  final version = '${m['computerVersion'] ?? ''}'.trim();
  final Map? gate;
  if (m.containsKey('versionGate')) {
    gate = m['versionGate'] is Map ? m['versionGate'] as Map : null;
  } else if (version.isEmpty || !isComputerSemver(version)) {
    gate = {
      'reason': 'computer_version_unknown',
      'minVersion': computerVersionFloorMin,
    };
  } else if (compareComputerVersions(
        _release(version),
        _release(computerVersionFloorMin),
      ) >=
      0) {
    gate = null;
  } else {
    gate = {
      'reason': 'computer_version_unsupported',
      'minVersion': computerVersionFloorMin,
    };
  }
  if (gate == null) return ComputerVersionTier.none;
  final base = ComputerVersionTier(
    ComputerTierKind.none,
    reason: '${gate['reason'] ?? 'computer_version_unsupported'}',
    minVersion: '${gate['minVersion'] ?? computerVersionFloorMin}',
    enforced: gate['enforced'] == true,
    enforcedAt: DateTime.tryParse('${gate['enforcedAt'] ?? ''}'),
  );
  if (version.isEmpty) {
    return m['status'] == 'online'
        ? ComputerVersionTier(
            ComputerTierKind.unreported,
            reason: 'computer_version_unknown',
            minVersion: base.minVersion,
            enforced: base.enforced,
            enforcedAt: base.enforcedAt,
          )
        : ComputerVersionTier.none;
  }
  final webCanUpgrade =
      isComputerSemver(version) &&
      compareComputerVersions(version, computerRemoteUpgradeMinVersion) >= 0;
  return base.as(
    webCanUpgrade ? ComputerTierKind.upgrade : ComputerTierKind.reinstall,
  );
}
