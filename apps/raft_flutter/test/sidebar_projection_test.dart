import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/sidebar_projection.dart';

RaftChannel channel(
  String id, {
  String? name,
  String type = 'channel',
  String? activity,
  String? created,
}) => RaftChannel({
  'id': id,
  'name': name ?? id,
  'type': type,
  'lastMessageAt': ?activity,
  'createdAt': ?created,
});

void main() {
  test('custom section and pinned identities claim conversations once in explicit section order', () {
    final groups = projectSidebar(
      channels: [
        channel('a'),
        channel('b'),
        channel('joint', type: 'joint'),
        RaftChannel({'id': 'archived', 'archivedAt': '2026-01-01'}),
      ],
      dms: [
        RaftChannel({
          'id': 'dm1',
          'type': 'dm',
          'peerType': 'agent',
          'peerId': 'agent1',
          'peerName': 'Cindy',
        }),
        channel('hidden', type: 'dm'),
      ],
      agents: [
        {'id': 'agent1', 'name': 'Cindy'},
      ],
      preferences: {
        'pinned': [
          {'kind': 'agent', 'id': 'agent1'},
        ],
        'hiddenDmIds': ['hidden'],
        'customSections': [
          {'id': 's', 'name': 'My work', 'emoji': '🧭'},
        ],
        'sectionPlacements': [
          {'kind': 'channel', 'id': 'b', 'sectionId': 's', 'position': 0},
          {'kind': 'agent', 'id': 'agent1', 'sectionId': 's', 'position': 1},
        ],
        'sectionOrder': ['s', 'system:dms', 'system:pinned'],
      },
    );
    expect(groups.map((g) => g.id).take(3), [
      's',
      'system:dms',
      'system:pinned',
    ]);
    expect(groups.first.label, '🧭 My work');
    expect(groups.first.entries.single.channel!.id, 'b');
    expect(
      groups
          .singleWhere((g) => g.id == 'system:pinned')
          .entries
          .single
          .agent!['id'],
      'agent1',
    );
    expect(
      groups
          .singleWhere((g) => g.id == 'system:channels')
          .entries
          .single
          .channel!
          .id,
      'a',
    );
    expect(
      groups
          .singleWhere((g) => g.id == 'system:joint')
          .entries
          .single
          .channel!
          .id,
      'joint',
    );
    expect(groups.singleWhere((g) => g.id == 'system:dms').entries, isEmpty);
    expect(
      groups
          .expand((g) => g.entries)
          .where((e) => e.channel?.id == 'dm1')
          .length,
      1,
    );
  });
  test('manual order preserves remaining wire order while alphabetical is explicit', () {
    final values = [channel('z'), channel('a'), channel('m')];
    List<String> order(Map<String, dynamic> prefs) =>
        projectSidebar(channels: values, dms: [], preferences: prefs)
            .singleWhere((g) => g.id == 'system:channels')
            .entries
            .map((e) => e.label)
            .toList();
    expect(
      order({
        'channelOrder': ['m'],
      }),
      ['m', 'z', 'a'],
    );
    expect(
      order({
        'channelOrder': ['m'],
        'channelSortMode': 'az',
      }),
      ['a', 'm', 'z'],
    );
  });
  test('recent uses real message timestamps, preserves manual ties, never substitutes creation time', () {
    final groups = projectSidebar(
      channels: [
        channel('a', activity: '2026-10-01T10:00:00Z'),
        channel('b', activity: '2026-10-01T11:00:00Z'),
        channel('missing', created: '2099-01-01T00:00:00Z'),
        channel('also-missing'),
      ],
      dms: [],
      preferences: {
        'channelOrder': ['also-missing', 'missing', 'a', 'b'],
        'channelSortMode': 'recent',
      },
      activity: {'a': DateTime.utc(2026, 10, 1, 12)},
    );
    expect(
      groups
          .singleWhere((g) => g.id == 'system:channels')
          .entries
          .map((e) => e.label),
      ['a', 'b', 'also-missing', 'missing'],
    );
  });
  test(
    'unavailable agent directory retains a real DM without inventing an agent',
    () {
      final dm = RaftChannel({
        'id': 'd',
        'type': 'dm',
        'peerType': 'agent',
        'peerId': 'a',
        'peerName': 'Cindy',
      });
      final groups = projectSidebar(
        channels: [],
        dms: [dm],
        preferences: {
          'pinned': [
            {'kind': 'agent', 'id': 'a'},
            {'kind': 'agent', 'id': 'absent'},
          ],
        },
      );
      expect(groups.first.entries.single.channel, dm);
      expect(groups.first.entries.single.agent, isNull);
      expect(groups.singleWhere((g) => g.id == 'system:dms').entries, isEmpty);
    },
  );
}
