import 'dart:math' as math;

/// Actual useSystemNotifications append order. These records live in scoped
/// memory; dismissal storage persists fingerprints rather than private copy.
enum SystemNoticeKind { error, warning, info }

enum SystemNoticeDestination { billing, computer, computers, feedback }

class SystemNotice {
  const SystemNotice({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.destination,
    this.targetId,
    this.fingerprint,
    this.parameters = const {},
  });
  final String id, title, body;
  final SystemNoticeKind kind;
  final SystemNoticeDestination destination;
  final String? targetId, fingerprint;
  final Map<String, Object?> parameters;
}

List<SystemNotice> projectSystemNotifications({
  required Map<String, dynamic>? server,
  required List<Map<String, dynamic>> channels,
  required List<Map<String, dynamic>> machines,
  required List<Map<String, dynamic>> agents,
  required bool machinesReady,
  required bool canViewMachines,
  required bool mobile,
  required int feedbackUnread,
  required DateTime now,
}) {
  if (server == null) return const [];
  final notices = <SystemNotice>[];
  final downgraded = DateTime.tryParse('${server['planDowngradedAt'] ?? ''}');
  if (server['plan'] == 'free' && downgraded != null) {
    final deadline = downgraded.add(const Duration(days: 7));
    final expired = !now.isBefore(deadline);
    final days =
        (deadline.difference(now).inMilliseconds / Duration.millisecondsPerDay)
            .ceil();
    // Pinned shared PLAN_CONFIG.free and trial limits are unlimited for all
    // three resource types. Never invent obsolete 1/1/10 admission limits.
    notices.add(
      SystemNotice(
        id: 'plan-downgrade',
        parameters: {'expired': expired, 'count': math.max(0, days)},
        kind: expired ? SystemNoticeKind.error : SystemNoticeKind.warning,
        title: expired
            ? 'Excess agents have been stopped'
            : 'Plan downgraded to Free',
        body: expired
            ? 'Upgrade to reactivate the agents that were stopped.'
            : '${math.max(0, days)} ${days == 1 ? 'day' : 'days'} left to reduce resources or upgrade.',
        destination: SystemNoticeDestination.billing,
        fingerprint: 'plan-downgrade:${expired ? 'expired' : 'grace'}:0:0:0',
      ),
    );
  }
  if (['owner', 'admin'].contains(server['role'])) {
    for (final channel in channels) {
      if (channel['type'] != 'joint' || channel['archivedAt'] != null) continue;
      final raw = channel['jointOverLimitGraceEndsAt'];
      if (raw is! String || raw.isEmpty) continue;
      final deadline = DateTime.tryParse(raw);
      final locked =
          channel['jointBillingLocked'] == true ||
          deadline != null && !now.isBefore(deadline);
      notices.add(
        SystemNotice(
          id: 'joint-over-limit:${channel['id']}',
          parameters: {
            'locked': locked,
            'channel': channel['name'],
            'deadline': raw,
          },
          kind: locked ? SystemNoticeKind.error : SystemNoticeKind.warning,
          title:
              '#${channel['name']} ${locked ? 'is read-only' : 'will become read-only'}',
          body: locked
              ? 'This Joint Channel is read-only because it has more than 2 free servers. It becomes writable again when one server’s admin upgrades or a free server leaves.'
              : 'This Joint Channel has more than 2 free servers and becomes read-only on $raw. To keep it writable, one server’s admin needs to upgrade, or a free server needs to leave.',
          destination: SystemNoticeDestination.billing,
          fingerprint:
              'joint-over-limit:${channel['id']}:$raw:${locked ? 'locked' : 'grace'}',
        ),
      );
    }
  }
  if (canViewMachines && machinesReady) {
    final problems = machines
        .where(
          (m) =>
              m['isComputer'] == true &&
              (m['computerUpgradeAvailable'] == true ||
                  m['status'] == 'offline'),
        )
        .toList();
    if (mobile && problems.isNotEmpty) {
      final upgrade = problems
          .where((m) => m['computerUpgradeAvailable'] == true)
          .length;
      final offline = problems.length - upgrade;
      final ids = problems.map((m) => '${m['id']}').toList()..sort();
      final versions = problems.map((m) {
        final policy = m['computerBroadcastPolicy'];
        return '${m['id']}:${policy is Map ? policy['policyRevision'] ?? 'unknown-policy' : 'unknown-policy'}:${policy is Map ? policy['targetVersion'] ?? 'no-target' : 'no-target'}';
      }).toList()..sort();
      notices.add(
        SystemNotice(
          id: 'computer-attention',
          parameters: {'upgrade': upgrade, 'offline': offline},
          kind: SystemNoticeKind.warning,
          title: 'Computers need attention',
          body: [
            if (upgrade > 0)
              '$upgrade ${upgrade == 1 ? 'needs' : 'need'} upgrade',
            if (offline > 0) '$offline offline',
          ].join(' · '),
          destination: problems.length == 1
              ? SystemNoticeDestination.computer
              : SystemNoticeDestination.computers,
          targetId: problems.length == 1 ? '${problems.single['id']}' : null,
          fingerprint:
              'computer-attention:${versions.join(',')}:${ids.join(',')}:$upgrade:$offline',
        ),
      );
    }
    final offline = machines
        .where((m) => m['isComputer'] != true && m['status'] == 'offline')
        .toList();
    if (offline.isNotEmpty) {
      final ids = offline.map((m) => '${m['id']}').toList()..sort();
      final active = agents
          .where(
            (a) =>
                a['deletedAt'] == null &&
                a['status'] == 'active' &&
                ids.contains(a['machineId']),
          )
          .length;
      final names = offline.map((m) => '${m['name'] ?? ''}').join(', ');
      notices.add(
        SystemNotice(
          id: 'machine-offline',
          parameters: {
            'count': offline.length,
            'names': names,
            'active': active,
          },
          kind: active > 0 ? SystemNoticeKind.error : SystemNoticeKind.warning,
          title: '$names ${offline.length == 1 ? 'is' : 'are'} offline',
          body: active == 0
              ? 'No agents are active on this computer right now — reconnect when you need it next.'
              : '$active ${active == 1 ? 'agent is' : 'agents are'} active on this computer and can’t run until it reconnects.',
          destination: SystemNoticeDestination.computer,
          targetId: '${offline.first['id']}',
          fingerprint: 'machine-offline:${ids.join(',')}',
        ),
      );
    }
    final low =
        <
          ({
            Map<String, dynamic> machine,
            double percent,
            String band,
            int bytes,
          })
        >[];
    for (final machine in machines) {
      if (machine['isComputer'] != true ||
          machine['computerAttachedByCurrentUser'] != true ||
          machine['status'] != 'online') {
        continue;
      }
      final disk = machine['diskStatus'];
      if (disk is! Map) continue;
      final available = disk['availableBytes'], total = disk['totalBytes'];
      if (available is! int ||
          total is! int ||
          available < 0 ||
          total <= 0 ||
          available > total ||
          available > 9007199254740991 ||
          total > 9007199254740991) {
        continue;
      }
      final percent = available / total * 100;
      if (available >= 20 * 1024 * 1024 * 1024 || percent >= 10) continue;
      low.add((
        machine: machine,
        percent: (percent * 10).floor() / 10,
        band: percent < 1
            ? 'under1'
            : percent < 2
            ? 'under2'
            : percent < 5
            ? 'under5'
            : 'under10',
        bytes: available,
      ));
    }
    if (low.isNotEmpty) {
      final fingerprints =
          low.map((m) => '${m.machine['id']}=${m.band}').toList()..sort();
      final first = low.first;
      notices.add(
        SystemNotice(
          id: 'machine-disk-low',
          parameters: {
            'count': low.length,
            'free': systemNoticeBytes(first.bytes),
            'percent': first.percent,
          },
          kind: SystemNoticeKind.warning,
          title: low.length == 1
              ? 'A computer you added is low on disk space'
              : '${low.length} computers you added are low on disk space',
          body:
              '${systemNoticeBytes(first.bytes)} free (${first.percent}%). Agents may fail to save work or start until space is freed.',
          destination: SystemNoticeDestination.computer,
          targetId: '${first.machine['id']}',
          fingerprint: 'machine-disk-low:${fingerprints.join(',')}',
        ),
      );
    }
  }
  // Browser-only deferred PWA install prompt has no installed-native analogue.
  if (feedbackUnread > 0) {
    notices.add(
      SystemNotice(
        id: 'feedback-replies',
        parameters: {'count': feedbackUnread},
        kind: SystemNoticeKind.info,
        title: 'Feedback has new replies',
        body:
            '$feedbackUnread feedback ${feedbackUnread == 1 ? 'conversation has' : 'conversations have'} unread replies.',
        destination: SystemNoticeDestination.feedback,
      ),
    );
  }
  return List.unmodifiable(notices);
}

String systemNoticeBytes(int value) {
  if (value <= 0) return '0 B';
  if (value < 1024) return '$value B';
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  if (value < 1024 * 1024 * 1024) {
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
