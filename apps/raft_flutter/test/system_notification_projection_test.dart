import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/system_notification_projection.dart';

void main() {
  final now = DateTime.utc(2026, 10, 8);
  List<SystemNotice> project({
    Map<String, dynamic>? server,
    List<Map<String, dynamic>> machines = const [],
    List<Map<String, dynamic>> agents = const [],
    List<Map<String, dynamic>> channels = const [],
    bool ready = true,
    bool allowed = true,
    bool mobile = true,
    int feedback = 0,
  }) => projectSystemNotifications(
    server: server ?? {'id': 's', 'role': 'owner'},
    channels: channels,
    machines: machines,
    agents: agents,
    machinesReady: ready,
    canViewMachines: allowed,
    mobile: mobile,
    feedbackUnread: feedback,
    now: now,
  );
  test(
    'source append order and grace fingerprint preserve unlimited free limits',
    () {
      final entries = project(
        server: {
          'id': 's',
          'role': 'owner',
          'plan': 'free',
          'planDowngradedAt': '2026-10-06T00:00:00Z',
        },
        channels: [
          {
            'id': 'joint',
            'type': 'joint',
            'name': 'design',
            'jointOverLimitGraceEndsAt': '2026-10-07T00:00:00Z',
          },
        ],
        machines: [
          {
            'id': 'old',
            'name': 'Old',
            'status': 'offline',
            'isComputer': false,
          },
        ],
        feedback: 2,
      );
      expect(entries.map((e) => e.id), [
        'plan-downgrade',
        'joint-over-limit:joint',
        'machine-offline',
        'feedback-replies',
      ]);
      expect(entries.first.fingerprint, 'plan-downgrade:grace:0:0:0');
      expect(entries.first.body, contains('5 days'));
      expect(entries[1].kind, SystemNoticeKind.error);
      expect(entries.last.fingerprint, isNull);
    },
  );
  test('role, archive, readiness and permission each fail closed', () {
    final channel = {
      'id': 'private',
      'type': 'joint',
      'name': 'Private',
      'jointOverLimitGraceEndsAt': '2026-10-09T00:00:00Z',
    };
    final machine = {
      'id': 'computer',
      'name': 'Private computer',
      'status': 'offline',
      'isComputer': true,
    };
    expect(
      project(
        server: {'id': 's', 'role': 'member'},
        channels: [channel],
        machines: [machine],
        allowed: false,
      ),
      isEmpty,
    );
    expect(
      project(
        channels: [
          {...channel, 'archivedAt': '2026-10-01'},
        ],
        machines: [machine],
        ready: false,
      ),
      isEmpty,
    );
  });
  test('upgrade outranks offline and version changes resurface attention', () {
    final machines = [
      {
        'id': 'z',
        'status': 'offline',
        'isComputer': true,
        'computerUpgradeAvailable': true,
        'computerBroadcastPolicy': {
          'policyRevision': 3,
          'targetVersion': '1.0.44',
        },
      },
      {'id': 'a', 'status': 'offline', 'isComputer': true},
    ];
    final entry = project(machines: machines).single;
    expect(entry.body, '1 needs upgrade · 1 offline');
    expect(entry.destination, SystemNoticeDestination.computers);
    expect(
      entry.fingerprint,
      'computer-attention:a:unknown-policy:no-target,z:3:1.0.44:a,z:1:1',
    );
    expect(project(machines: machines, mobile: false), isEmpty);
    expect(project(machines: [machines.first]).single.targetId, 'z');
    expect(
      project(
        machines: [
          {
            ...machines.first,
            'computerBroadcastPolicy': {
              'policyRevision': 4,
              'targetVersion': '1.0.45',
            },
          },
        ],
      ).single.fingerprint,
      isNot(entry.fingerprint),
    );
  });
  test('offline impact escalates only nondeleted exactly active agents', () {
    final machine = {
      'id': 'm',
      'name': 'Local',
      'status': 'offline',
      'isComputer': false,
    };
    final ordinary = project(
      machines: [machine],
      agents: [
        {'id': 'a', 'machineId': 'm', 'status': 'stopped'},
        {'id': 'b', 'machineId': 'm', 'status': 'active', 'deletedAt': '2026'},
      ],
    ).single;
    expect(ordinary.kind, SystemNoticeKind.warning);
    final active = project(
      machines: [machine],
      agents: [
        {'id': 'c', 'machineId': 'm', 'status': 'active'},
      ],
    ).single;
    expect(active.kind, SystemNoticeKind.error);
    expect(active.fingerprint, ordinary.fingerprint);
  });
  test('disk requires online attached Computer and both strict thresholds', () {
    const gib = 1024 * 1024 * 1024;
    Map<String, dynamic> machine(int available, int total) => {
      'id': 'm',
      'name': 'Local',
      'status': 'online',
      'isComputer': true,
      'computerAttachedByCurrentUser': true,
      'diskStatus': {'availableBytes': available, 'totalBytes': total},
    };
    expect(project(machines: [machine(20 * gib, 1000 * gib)]), isEmpty);
    expect(project(machines: [machine(gib, 10 * gib)]), isEmpty);
    expect(
      project(
        machines: [
          machine(-1, 100 * gib),
          machine(11, 10),
          machine(1, 9007199254740992),
        ],
      ),
      isEmpty,
    );
    expect(
      project(
        machines: [
          {...machine(gib, 100 * gib), 'status': 'offline'},
        ],
      ).map((n) => n.id),
      ['computer-attention'],
    );
    expect(
      project(
        machines: [
          {...machine(gib, 100 * gib), 'computerAttachedByCurrentUser': false},
        ],
      ),
      isEmpty,
    );
    final under2 = project(machines: [machine(gib, 100 * gib)]).single;
    final under1 = project(machines: [machine(gib, 200 * gib)]).single;
    expect(under2.fingerprint, 'machine-disk-low:m=under2');
    expect(under1.fingerprint, 'machine-disk-low:m=under1');
    expect(under1.body, contains('1.0 GB free (0.5%)'));
  });
}
