import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/computer_version_notices.dart';

Map<String, dynamic> machine(
  String id, {
  String version = '1.0.46',
  String status = 'online',
  bool mine = true,
  bool computer = true,
  String? enforcedAt,
  bool enforced = false,
}) => {
  'id': id,
  'name': 'Mac $id',
  'isComputer': computer,
  'status': status,
  'computerVersion': version,
  'computerAttachedByCurrentUser': mine,
  'versionGate': {
    'reason': 'computer_version_unsupported',
    'minVersion': '1.0.47',
    'enforced': enforced,
    'enforcedAt': ?enforcedAt,
  },
};

List<String> ids(List<dynamic> notices) => [for (final n in notices) n.id];

void main() {
  List<dynamic> run(
    List<Map<String, dynamic>> machines, {
    bool manages = false,
    Set<String> dismissed = const {},
  }) => computerVersionNotices(
    machines: machines,
    userId: 'alice',
    managesMachines: manages,
    dismissed: dismissed,
  );

  test('a Computer too old for the web asks for a reinstall', () {
    final out = run([machine('a', version: '1.0.30')]);
    expect(ids(out), ['computer-reinstall']);
    expect(out.single.parameters['need'], 'reinstall');
    expect(out.single.targetId, 'a');
    expect(out.single.fingerprint, 'computer-reinstall:a');
  });

  test('a legacy daemon is a migration; both together are mixed', () {
    expect(
      run([machine('d', computer: false)]).single.parameters['need'],
      'migrate',
    );
    expect(
      run([
        machine('d', computer: false),
        machine('a', version: '1.0.30'),
      ]).single.parameters['need'],
      'mixed',
    );
  });

  test('only machines the person manages count', () {
    expect(run([machine('a', version: '1.0.30', mine: false)]), isEmpty);
    expect(
      ids(run([machine('a', version: '1.0.30', mine: false)], manages: true)),
      ['computer-reinstall'],
    );
  });

  test('an upgradable Computer is announced only while a deadline is ahead', () {
    expect(run([machine('a')]), isEmpty);
    final out = run([machine('a', enforcedAt: '2026-12-01T00:00:00Z')]);
    expect(ids(out), ['computer-upgrade-deadline']);
    expect(out.single.parameters['date'], '2026-12-01T00:00:00.000Z');
    expect(
      run([machine('a', enforcedAt: '2026-12-01T00:00:00Z', enforced: true)]),
      isEmpty,
    );
  });

  test('the fingerprint covers offline machines and survives a fix', () {
    final both = [
      machine('a', version: '1.0.30'),
      machine('b', version: '1.0.30', status: 'offline'),
    ];
    final first = run(both).single;
    expect(first.fingerprint, 'computer-reinstall:a,b');
    expect(first.targetId, 'a', reason: 'only online machines are listed');
    // The person dismissed it, then fixed b: the dismissal still covers a.
    final after = run([
      machine('a', version: '1.0.30'),
    ], dismissed: {'computer-reinstall:a,b'}).single;
    expect(after.fingerprint, 'computer-reinstall:a,b');
    // A new machine no dismissal covered brings it back.
    final fresh = run([
      machine('a', version: '1.0.30'),
      machine('c', version: '1.0.30'),
    ], dismissed: {'computer-reinstall:a,b'}).single;
    expect(fresh.fingerprint, 'computer-reinstall:a,c');
  });
}
