import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/member_graph_layout.dart';

/// `member_graph_reference.json` holds the inputs and the output of Web's
/// own `buildMemberLinks` / `computeMemberNetworkLayout`
/// (`MemberGraphSection.tsx` at the pinned reference, run under node).
void main() {
  // The sharded runner starts tests from another directory than `flutter test`
  // inside the package: find the fixture relative to this file first.
  final fixture = [
    File.fromUri(Platform.script.resolve('member_graph_reference.json')),
    File('test/member_graph_reference.json'),
    File('packages/raft_ui/test/member_graph_reference.json'),
    // The sharded runner: cwd is apps/raft_flutter.
    File('../../packages/raft_ui/test/member_graph_reference.json'),
  ].firstWhere((f) => f.existsSync());
  final reference =
      jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;

  for (final entry in reference.entries) {
    test('layout of "${entry.key}" matches the Web layout', () {
      final input = entry.value['input'] as Map<String, dynamic>;
      final expected = entry.value['expected'] as Map<String, dynamic>;
      List<RaftGraphMember> members(String k) => [
        for (final m in input[k] as List)
          RaftGraphMember.fromJson(Map<String, dynamic>.from(m as Map)),
      ];
      final sorted = raftSortedGraphMembers(
        members('humans'),
        members('agents'),
      );
      expect([for (final m in sorted) m.key], expected['order']);
      final channels = raftSortedGraphChannels([
        for (final c in input['channels'] as List)
          RaftGraphChannel.fromJson(Map<String, dynamic>.from(c as Map)),
      ]);
      final links = raftBuildMemberLinks(sorted, channels);
      expect(links.length, expected['links']);
      final dense = raftGraphDense(sorted.length, links.length);
      expect(dense, expected['dense']);
      final layout = raftComputeMemberNetworkLayout(sorted, links, dense);
      final degrees = expected['degrees'] as Map<String, dynamic>;
      for (final m in sorted) {
        expect(layout.degrees[m.key], degrees[m.key] ?? 0, reason: m.key);
      }
      final positions = expected['positions'] as Map<String, dynamic>;
      for (final m in sorted) {
        final want = (positions[m.key] as List).cast<num>();
        final got = layout.positions[m.key]!;
        // Both sides are IEEE doubles; trig may differ in the last ulp.
        expect(got.x, closeTo(want[0].toDouble(), 1e-6), reason: '${m.key}.x');
        expect(got.y, closeTo(want[1].toDouble(), 1e-6), reason: '${m.key}.y');
      }
    });
  }

  test(
    'a lone member sits on its initial ring point and nothing is linked',
    () {
      final one = RaftGraphMember.fromJson({
        'type': 'human',
        'id': 'a',
        'name': 'a',
      });
      final layout = raftComputeMemberNetworkLayout([one], const [], false);
      expect(layout.degrees['human:a'], 0);
      expect(layout.positions.keys, ['human:a']);
    },
  );

  test(
    'links ignore the all channel and rooms over 36, falling back to them',
    () {
      RaftGraphMember m(String id, List<String> channels) =>
          RaftGraphMember(agent: false, id: id, name: id, channelIds: channels);
      final members = [
        m('a', ['all', 'big']),
        m('b', ['all', 'big']),
        m('c', ['all']),
      ];
      const all = RaftGraphChannel(
        id: 'all',
        name: 'all',
        humanCount: 3,
        agentCount: 0,
        memberCount: 3,
      );
      const big = RaftGraphChannel(
        id: 'big',
        name: 'big',
        humanCount: 40,
        agentCount: 0,
        memberCount: 40,
      );
      // No focused channel: only `all` is dropped, `big` is the fallback.
      final links = raftBuildMemberLinks(members, [all, big]);
      expect(links.map((l) => '${l.source}|${l.target}|${l.weight}'), [
        'human:a|human:b|1',
      ]);
      expect(links.single.channelNames, ['big']);
    },
  );

  test(
    'the zoom keeps the point under the pointer and stays inside the extent',
    () {
      const w = 640.0, h = 524.0;
      var z = RaftGraphZoom.identity;
      z = z.zoomAt(320, 262, RaftGraphZoom.wheelDelta(-100), w, h);
      expect(z.k, closeTo(1.148698354997035, 1e-9));
      // The content point that was under the pointer is still under it.
      expect(z.invertX(320), closeTo(320, 1e-9));
      expect(z.invertY(262), closeTo(262, 1e-9));
      // Zooming out beyond 1 is clamped.
      expect(z.zoomAt(10, 10, -5, w, h).k, 1);
      // Zooming in is capped at 4.
      var big = z;
      for (var i = 0; i < 20; i++) {
        big = big.zoomAt(600, 500, 1, w, h);
      }
      expect(big.k, 4);
      // Panning never leaves the translate extent.
      final panned = big.pan(10000, 10000, w, h);
      expect(panned.x, closeTo(0, 1e-9));
      expect(panned.y, closeTo(0, 1e-9));
      final other = big.pan(-10000, -10000, w, h);
      expect(other.x, closeTo(w - w * 4, 1e-9));
      expect(other.y, closeTo(h - h * 4, 1e-9));
    },
  );

  test('the view box follows the transform', () {
    final vb = raftGraphViewBox(const RaftGraphZoom(2, -320, -262), 640, 524);
    expect(vb.width, 460);
    expect(vb.height, 280);
    expect(vb.x, closeTo(230, 1e-9));
    expect(vb.y, closeTo(140, 1e-9));
    final whole = raftGraphViewBox(RaftGraphZoom.identity, 0, 0);
    expect(whole.width, 920);
  });

  test('locale compare orders like ICU for member names', () {
    final names = ['bob', 'Alice', 'alice', 'Äpfel', 'zed', '10x', '_u', 'Zed'];
    names.sort(raftLocaleCompare);
    expect(names, [
      '_u',
      '10x',
      'alice',
      'Alice',
      'Äpfel',
      'bob',
      'zed',
      'Zed',
    ]);
  });

  test('short labels cut with an ellipsis', () {
    expect(
      raftGraphShortLabel('abcdefghijklmnopqrstu', 16),
      'abcdefghijklmno…',
    );
    expect(raftGraphShortLabel('short', 16), 'short');
  });
}
