/// Server deadline of an upgrade request (`UPGRADE_REQUEST_DEADLINE_MS`): past
/// it the server settles the request as `no_response`, so the client copy
/// cannot outlive it either.
const computerUpgradeRequestDeadline = Duration(minutes: 30);

/// How long an offline Computer with an upgrade in flight reads as "restarting
/// for the upgrade" (Web `UPGRADE_RECONNECT_GRACE_MS`). The installer downloads
/// while the Computer is still online; the offline part is only stop to start.
const upgradeReconnectGrace = Duration(minutes: 3);

/// The request the server accepted for this client's Upgrade click, kept by
/// the client. [acceptedAtMs] is the local clock, so the deadline is not
/// skewed by the server's (Web `AcceptedComputerUpgrade`).
class AcceptedComputerUpgrade {
  const AcceptedComputerUpgrade(this.request, this.acceptedAtMs);
  final Map<String, dynamic> request;
  final int acceptedAtMs;
}

int? _ms(Object? iso) =>
    iso is String ? DateTime.tryParse(iso)?.millisecondsSinceEpoch : null;

/// The upgrade request in flight for [machine], or null (Web
/// `computerUpgradeInFlight`).
///
/// The server's pending row is the answer when the row carries one. Otherwise
/// the request this client saw accepted stays in flight until there is evidence
/// it ended: the row shows that request (or a later one) settled, the machine
/// is online at the target version, or the deadline passed. A refresh that
/// lands without the pending row is not such evidence, so the page keeps
/// saying "upgrading" instead of dropping to the offline card mid-restart.
Map<String, dynamic>? computerUpgradeInFlight(
  Map<String, dynamic> machine,
  AcceptedComputerUpgrade? accepted,
  int nowMs,
) {
  final row = machine['upgradeRequest'];
  if (row is Map && row['state'] == 'pending') {
    return Map<String, dynamic>.from(row);
  }
  if (accepted == null) return null;
  final request = accepted.request;
  if (row is Map) {
    final requestedAt = _ms(row['requestedAt']);
    final acceptedAt = _ms(request['requestedAt']);
    if (row['id'] == request['id'] ||
        requestedAt != null &&
            acceptedAt != null &&
            requestedAt >= acceptedAt) {
      return null;
    }
  }
  if (machine['status'] == 'online' &&
      machine['computerVersion'] == request['targetVersion']) {
    return null;
  }
  if (nowMs >=
      accepted.acceptedAtMs + computerUpgradeRequestDeadline.inMilliseconds) {
    return null;
  }
  return request;
}

/// One answer to "is this Computer restarting for an upgrade" for every
/// surface that shows its connection (detail page, sidebar row), so they
/// cannot disagree (Web `useComputerUpgradeReconnect`).
class ComputerUpgradeReconnect {
  const ComputerUpgradeReconnect({
    this.inFlight,
    this.reconnecting = false,
    this.overdue = false,
    this.graceEndsAtMs,
  });
  static const none = ComputerUpgradeReconnect();

  /// The upgrade request in flight (server pending row, or the one this
  /// client saw accepted).
  final Map<String, dynamic>? inFlight;

  /// Offline inside the grace: the upgrade's restart, not an outage.
  final bool reconnecting;

  /// Offline past the grace with the upgrade still in flight.
  final bool overdue;

  /// When [reconnecting] ends; the host rebuilds then.
  final int? graceEndsAtMs;

  String get targetVersion => '${inFlight?['targetVersion'] ?? ''}';
}

/// [offlineObservedAtMs] is the moment this client saw the live online to
/// offline event: the row carries no disconnect time, so a transition seen
/// live is the best anchor, else the row's `lastHeartbeat` (the last pong
/// before the disconnect), never earlier than the request itself.
ComputerUpgradeReconnect computerUpgradeReconnect(
  Map<String, dynamic> machine, {
  required AcceptedComputerUpgrade? accepted,
  required int? offlineObservedAtMs,
  required int nowMs,
}) {
  final inFlight = computerUpgradeInFlight(machine, accepted, nowMs);
  final waitingOffline =
      machine['isComputer'] == true &&
      machine['status'] != 'online' &&
      inFlight != null;
  if (!waitingOffline) {
    return ComputerUpgradeReconnect(inFlight: inFlight);
  }
  final anchor = offlineObservedAtMs ?? _ms(machine['lastHeartbeat']) ?? 0;
  final offlineSince = [
    _ms(inFlight['requestedAt']) ?? 0,
    anchor,
  ].reduce((a, b) => a > b ? a : b);
  final graceEnds = offlineSince + upgradeReconnectGrace.inMilliseconds;
  final elapsed = nowMs >= graceEnds;
  return ComputerUpgradeReconnect(
    inFlight: inFlight,
    reconnecting: !elapsed,
    overdue: elapsed,
    graceEndsAtMs: elapsed ? null : graceEnds,
  );
}
