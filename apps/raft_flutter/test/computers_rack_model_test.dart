// The Computers rack's rules (Web v1.24 features/computer/
// computersRackFilter.ts, computersRackSort.ts, utils/computerAttentionSeen.ts),
// with the Web's own cases from computersRackFilter.behavior.test.ts.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/computers_rack/computer_attention_seen.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_model.dart';
import 'package:raft_flutter/features/computers_rack/computers_rack_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> machine(
  String id, [
  Map<String, dynamic> extra = const {},
]) => {
  'id': id,
  'name': id,
  'status': 'online',
  'runtimes': ['claude'],
  'hostname': '$id.local',
  'os': 'linux',
  'isComputer': true,
  'computerVersion': '1.0.53',
  'computerUpgradeAvailable': false,
  ...extra,
};

Map<String, dynamic> owner(String id, String name) => {
  'ownerUserId': id,
  'owner': {'type': 'human', 'id': id, 'name': name, 'displayName': name},
};

final fleet = [
  machine('hetzner-ax42-1', {
    'hostProvider': 'hetzner',
    'runtimes': ['claude', 'codex'],
    ...owner('u-stdrc', 'stdrc'),
  }),
  machine('hetzner-ax42-2', {
    'hostProvider': 'hetzner',
    'runtimes': ['claude', 'codex'],
    ...owner('u-me', 'atlas'),
  }),
  machine('aws-gpu-1', {
    'hostProvider': 'aws',
    'runtimes': ['codex'],
    'status': 'offline',
    ...owner('u-ricky', 'ricky'),
  }),
  machine('mac-studio', {
    'hostProvider': null,
    'runtimes': ['claude', 'cursor'],
    ...owner('u-stdrc', 'stdrc'),
  }),
  machine('kimi-box-1', {
    'hostProvider': 'vultr',
    'runtimes': ['kimi-sdk'],
  }),
];

List<String> ids(List<RackMachine> ms) => [for (final m in ms) '${m['id']}'];

List<RackMachine> filter(
  List<RackMachine> ms, {
  String query = '',
  RackStatusFilter status = RackStatusFilter.all,
  List<String> runtimes = const [],
}) => filterRackMachines(ms, query: query, status: status, runtimes: runtimes);

List<List<String>> prefixGroups(List<String> names) => [
  for (final g in groupRackMachines(
    [for (final n in names) machine(n)],
    RackGroupBy.prefix,
    personalLabel: 'Personal computers',
    otherLabel: 'Other',
  ))
    [g.title, ...ids(g.machines)],
];

void main() {
  test(
    'search matches the name, the hostname or the owner, case-insensitively',
    () {
      expect(ids(filter(fleet, query: 'AX42')), [
        'hetzner-ax42-1',
        'hetzner-ax42-2',
      ]);
      expect(ids(filter(fleet, query: 'ricky')), ['aws-gpu-1']);
      expect(ids(filter(fleet, query: 'mac-studio.local')), ['mac-studio']);
      final mac = fleet[3];
      expect(rackSearchMatch(mac, ' studio '), (
        name: true,
        hostname: true,
        owner: false,
      ));
      expect(rackSearchMatch(fleet[2], 'RICKY'), (
        name: false,
        hostname: false,
        owner: true,
      ));
      expect(rackSearchMatch(fleet[0], '   '), isNull);
      final handled = {
        ...mac,
        'owner': {'id': 'u', 'name': 'std-handle', 'displayName': 'Standard'},
      };
      expect(rackSearchMatch(handled, 'std-handle')!.owner, isTrue);
      expect(rackSearchMatch(handled, 'standard')!.owner, isTrue);
    },
  );

  test('Runtime keeps a computer with any chosen runtime; Other has no usage provider', () {
    expect(ids(filter(fleet, runtimes: ['kimi'])), ['kimi-box-1']);
    expect(ids(filter(fleet, runtimes: ['other'])), ['mac-studio']);
    expect(
      ids(
        filter(
          fleet,
          runtimes: ['claude', 'codex'],
          status: RackStatusFilter.online,
        ),
      ),
      ['hetzner-ax42-1', 'hetzner-ax42-2', 'mac-studio'],
    );
    final columns = rackRuntimeColumns(fleet);
    expect(
      [for (final c in columns.usage) c.provider],
      ['claude', 'codex', 'kimi'],
    );
    expect(columns.other, ['cursor']);
    expect(runtimeFilterOptions(columns), ['claude', 'codex', 'kimi', 'other']);
    // A runtime chosen earlier whose computers have gone filters nothing.
    expect(
      effectiveRuntimeFilter(['grok', 'codex'], runtimeFilterOptions(columns)),
      ['codex'],
    );
  });

  test('Needs attention follows the server summary, else upgrade, offline or low disk', () {
    expect(
      rackNeedsAttention(
        machine('a', {
          'attention': {'count': 0},
          'status': 'offline',
        }),
      ),
      isFalse,
    );
    expect(
      rackNeedsAttention(
        machine('b', {
          'attention': {'count': 2},
        }),
      ),
      isTrue,
    );
    expect(
      rackNeedsAttention(machine('c', {'computerUpgradeAvailable': true})),
      isTrue,
    );
    expect(rackNeedsAttention(machine('d', {'status': 'offline'})), isTrue);
    expect(
      rackNeedsAttention(
        machine('e', {
          'diskStatus': {'availableBytes': 1 << 30, 'totalBytes': 100 << 30},
        }),
      ),
      isTrue,
    );
    expect(rackNeedsAttention(machine('f')), isFalse);
    expect(ids(filter(fleet, status: RackStatusFilter.attention)), [
      'aws-gpu-1',
    ]);
    expect(ids(filter(fleet, status: RackStatusFilter.offline)), ['aws-gpu-1']);
  });

  test('a name prefix drops a trailing number; a prefix of one computer goes to Other, last', () {
    final groups = groupRackMachines(
      fleet,
      RackGroupBy.prefix,
      personalLabel: 'Personal computers',
      otherLabel: 'Other',
    );
    expect(
      [for (final g in groups) (g.title, g.machines.length)],
      [('hetzner-ax42', 2), ('Other', 3)],
    );
  });

  test('#triage:#291: the longest shared word prefix; a lone member folds up; lone names go to Other', () {
    expect(
      prefixGroups([
        'armbian-1', 'armbian-kitchen', 'armbian-lab', //
        'atlas-fluence-claude', 'atlas-fluence-root', 'atlas-hostinger-root',
        'Alices-MacBook-Air.local', 'DESKTOP-AB12CD3',
        'hetzner-ax42-1', 'hetzner-ax42-4',
        'hetzner-ex63-3', 'hetzner-ex63-4', 'hetzner-ex63-6',
      ]),
      [
        ['armbian', 'armbian-1', 'armbian-kitchen', 'armbian-lab'],
        [
          'atlas',
          'atlas-fluence-claude',
          'atlas-fluence-root',
          'atlas-hostinger-root',
        ],
        ['hetzner-ax42', 'hetzner-ax42-1', 'hetzner-ax42-4'],
        ['hetzner-ex63', 'hetzner-ex63-3', 'hetzner-ex63-4', 'hetzner-ex63-6'],
        ['Other', 'Alices-MacBook-Air.local', 'DESKTOP-AB12CD3'],
      ],
    );
    expect(
      prefixGroups(['atlas-fluence-claude', 'atlas-fluence-root', 'solo']),
      [
        ['atlas-fluence', 'atlas-fluence-claude', 'atlas-fluence-root'],
        ['Other', 'solo'],
      ],
    );
  });

  test('name prefixes: case, _ and . split words, a whole name that prefixes another joins it', () {
    expect(prefixGroups(['Build-a', 'build-b']), [
      ['Build', 'Build-a', 'build-b'],
    ]);
    expect(prefixGroups(['build-c', 'Build-a', 'build-b']), [
      ['build', 'build-c', 'Build-a', 'build-b'],
    ]);
    expect(prefixGroups(['gpu_node_1', 'gpu_node_2', 'gpu.node.3']), [
      ['gpu_node', 'gpu_node_1', 'gpu_node_2', 'gpu.node.3'],
    ]);
    expect(prefixGroups(['armbian', 'armbian-2', 'pi']), [
      ['armbian', 'armbian', 'armbian-2'],
      ['Other', 'pi'],
    ]);
    expect(prefixGroups(['web-1', 'web-2', 'web-10']), [
      ['web', 'web-1', 'web-2', 'web-10'],
    ]);
    expect(prefixGroups(['alpha', 'beta-1', 'gamma.local']), [
      ['Other', 'alpha', 'beta-1', 'gamma.local'],
    ]);
    expect(
      prefixGroups([
        'gpu-a-1',
        'gpu-a-2',
        'gpu-a-3',
        'gpu-b-1',
        'gpu-b-2',
        'gpu-c',
      ]),
      [
        ['gpu', 'gpu-b-1', 'gpu-b-2', 'gpu-c'],
        ['gpu-a', 'gpu-a-1', 'gpu-a-2', 'gpu-a-3'],
      ],
    );
    expect(prefixGroups(['raspberrypi', 'raspberrypi', 'ubuntu']), [
      ['raspberrypi', 'raspberrypi', 'raspberrypi'],
      ['Other', 'ubuntu'],
    ]);
    expect(rackNamePrefixGroups(['x.local', 'X-local']), [
      (key: 'x-local', title: 'X-local'),
      (key: 'x-local', title: 'X-local'),
    ]);
    expect(rackNamePrefixGroups(['', '  ', '-', 'a']), [
      null,
      null,
      null,
      null,
    ]);
  });

  test(
    'Provider groups by the cloud; no provider is Personal computers, last',
    () {
      final groups = groupRackMachines(
        fleet,
        RackGroupBy.provider,
        personalLabel: 'Personal computers',
        otherLabel: 'Other',
      );
      expect(
        [for (final g in groups) g.title],
        ['AWS', 'Hetzner Cloud', 'Vultr', 'Personal computers'],
      );
    },
  );

  test('Mine first: the viewer\'s own computers lead, each tier in the server order', () {
    expect(ids(orderRackMachines(fleet, 'u-stdrc')), [
      'hetzner-ax42-1',
      'mac-studio',
      'hetzner-ax42-2',
      'aws-gpu-1',
      'kimi-box-1',
    ]);
  });

  test('sorts: names A to Z with numbers by value, used share high to low, no value last', () {
    final names = [machine('web-10'), machine('Web-2'), machine('web-1')];
    expect(
      ids(
        sortRackMachines(names, const RackSort('name', RackSortDirection.asc)),
      ),
      ['web-1', 'Web-2', 'web-10'],
    );
    final disks = [
      machine('half', {
        'diskStatus': {'availableBytes': 50, 'totalBytes': 100},
      }),
      machine('none'),
      machine('full', {
        'diskStatus': {'availableBytes': 10, 'totalBytes': 100},
      }),
      machine('off', {
        'status': 'offline',
        'diskStatus': {'availableBytes': 0, 'totalBytes': 100},
      }),
    ];
    expect(
      ids(
        sortRackMachines(disks, RackSort('disk', firstSortDirection('disk'))),
      ),
      ['full', 'half', 'none', 'off'],
    );
    expect(
      ids(
        sortRackMachines(disks, const RackSort('disk', RackSortDirection.asc)),
      ),
      ['half', 'full', 'none', 'off'],
    );
    // A runtime that has gone with its computers sorts nothing.
    final columns = rackRuntimeColumns(fleet);
    expect(
      effectiveRackSort(
        const RackSort('remaining:grok', RackSortDirection.desc),
        columns,
      ),
      isNull,
    );
    expect(
      parseRackSort('{"key":"memory","direction":"asc"}'),
      const RackSort('memory', RackSortDirection.asc),
    );
    expect(parseRackSort('{"key":"cpu","direction":"asc"}'), isNull);
    expect(parseRackSort('not json'), isNull);
  });

  test(
    'counts: computers, online, agents, and attention only from a summary',
    () {
      expect(rackCounts(fleet, (_) => 2), (
        computers: 5,
        online: 4,
        agents: 10,
        attention: null,
      ));
      final summarized = [
        machine('a', {
          'attention': {'count': 1},
        }),
        machine('b', {
          'attention': {'count': 0},
        }),
      ];
      expect(rackCounts(summarized, (_) => 0).attention, 1);
    },
  );

  group('attention dot', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DevicePreferences.load();
    });
    tearDown(DevicePreferences.reset);

    test('lit for an unseen pair; opening Computers marks it seen; leaving and re-entering lights it again', () {
      var machines = [
        machine('m1', {'status': 'offline'}),
      ];
      bool dot() => computerAttentionDot(
        userId: 'u',
        serverId: 's',
        guest: false,
        loaded: true,
        machines: machines,
      );
      expect(dot(), isTrue);
      markComputerAttentionSeen(
        userId: 'u',
        serverId: 's',
        guest: false,
        loaded: true,
        machines: machines,
      );
      expect(dot(), isFalse);
      machines = [machine('m1')];
      expect(dot(), isFalse);
      machines = [
        machine('m1', {'status': 'offline'}),
      ];
      expect(dot(), isTrue);
      // A guest cannot open Computers: never lit.
      expect(
        computerAttentionDot(
          userId: 'u',
          serverId: 's',
          guest: true,
          loaded: true,
          machines: machines,
        ),
        isFalse,
      );
    });

    test('the server summary is the one attention state', () {
      expect(
        computerAttentionPairs([
          machine('m1', {
            'attention': {'count': 0},
            'status': 'offline',
          }),
          machine('m2', {
            'attention': {'count': 1},
          }),
          machine('m3', {
            'computerUpgradeAvailable': true,
            'status': 'offline',
          }),
        ]),
        ['m2\u0000attention', 'm3\u0000offline', 'm3\u0000upgrade'],
      );
    });
  });

  test('the grouping, sort and view are kept on the device; search and filters reset per server', () async {
    SharedPreferences.setMockInitialValues({});
    await DevicePreferences.load();
    addTearDown(DevicePreferences.reset);
    final prefs = ComputersRackPreferences.instance..resetForTests();
    expect(prefs.view, RackView.cards);
    prefs
      ..adoptServer('s1')
      ..setGroupBy(RackGroupBy.provider)
      ..setView(RackView.list)
      ..setSort(const RackSort('name', RackSortDirection.desc))
      ..setQuery('gpu')
      ..setStatus(RackStatusFilter.offline);
    prefs.resetForTests();
    expect(prefs.groupBy, RackGroupBy.provider);
    expect(prefs.view, RackView.list);
    expect(prefs.sort, const RackSort('name', RackSortDirection.desc));
    prefs
      ..adoptServer('s1')
      ..setQuery('gpu')
      ..adoptServer('s2');
    expect(prefs.query, '');
    prefs
      ..setStatus(RackStatusFilter.online)
      ..clearFilters();
    expect(prefs.status, RackStatusFilter.all);
    expect(prefs.groupBy, RackGroupBy.provider);
    prefs.resetForTests();
  });
}
