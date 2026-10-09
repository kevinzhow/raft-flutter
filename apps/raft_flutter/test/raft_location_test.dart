import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';

void main() {
  test(
    '[N01] entity routes round-trip escaped identifiers and query slots',
    () {
      final value = RaftLocation.at(
        serverSlug: 'team space',
        route: RaftRoute.channel,
        entityId: 'c/一',
        query: {
          'thread': 'c:m',
          'task': 'other:task',
          'profile': 'external:c:author',
          'msg': 'm',
          'open': 'channel:c',
        },
        fragment: 'focus',
      );
      final parsed = RaftLocation.parse(value.toString());
      expect(parsed.serverSlug, 'team space');
      expect(parsed.entityId, 'c/一');
      expect(parsed.route, RaftRoute.channel);
      expect(parsed.thread!.itemId, 'm');
      expect(parsed.task!.channelId, 'other');
      expect(parsed.profile!.channelId, 'c');
      expect(parsed.profile!.id, 'author');
      expect(parsed.content!.messageId, 'm');
      expect(parsed.uri.fragment, 'focus');
    },
  );

  test('local parsing rejects non-workspace and external paths', () {
    for (final invalid in [
      '/login',
      '/s/',
      'channel/c',
      'https://host/s/team',
      '//host/s/team',
    ]) {
      expect(() => RaftLocation.parse(invalid), throwsFormatException);
    }
    expect(
      RaftLocation.parse('/s/team/custom?unknown=1').route,
      RaftRoute.unknown,
    );
    expect(
      () => RaftLocation.at(serverSlug: 'team', route: RaftRoute.agent),
      throwsArgumentError,
    );
  });

  test('malformed slots cannot manufacture a profile or content identity', () {
    for (final raw in ['channel', 'channel:', ':c', 'unknown:c']) {
      expect(RaftContentLocation.parse(raw), isNull);
    }
    for (final raw in [
      'external:c',
      'external:c:m:extra',
      'external::m',
      'external:c:',
      'other:id',
    ]) {
      expect(RaftProfileLocation.parse(raw), isNull);
    }
    expect(RaftAnchor.parse('c:m:more')!.itemId, 'm:more');
    expect(RaftAnchor.parse(':m'), isNull);
    expect(
      RaftContentLocation.parse('agent:a', messageId: 'm')!.messageId,
      isNull,
    );
  });

  test('overlay edits preserve unrelated duplicate parameters and hash', () {
    final start = RaftLocation.parse(
      '/s/team/search?q=exact+text&unknown=1&unknown=2&open=channel%3Ac#anchor',
    );
    final next = start.withQuery({'thread': 'c:m', 'profile': 'agent:a'});
    expect(next.uri.queryParametersAll['unknown'], ['1', '2']);
    expect(next.query('q'), 'exact text');
    expect(next.content!.id, 'c');
    expect(next.uri.fragment, 'anchor');
    expect(next.withoutMobileOverlays(), start);
  });

  test('task modal remains independent of side thread and legacy task binds thread', () {
    final side = RaftLocation.parse('/s/team/activity?thread=c:m');
    final modal = side.withQuery({'task': 'other:t'});
    expect(side.panelNavigationKindTo(modal), RaftNavigationKind.push);
    expect(modal.thread!.itemId, 'm');
    expect(modal.task!.itemId, 't');
    expect(
      modal.panelNavigationKindTo(modal.withQuery({'task': null})),
      RaftNavigationKind.replace,
    );
    expect(side.withQuery({'task': '1'}).task!.itemId, 'm');
    expect(RaftLocation.parse('/s/team?task=1').task, isNull);
  });

  test('adding, retargeting and closing panels use Source history kinds', () {
    final root = RaftLocation.parse('/s/team/activity?unknown=keep');
    final first = root.withQuery({'thread': 'c:m'});
    final retarget = first.withQuery({'thread': 'c:other'});
    expect(root.panelNavigationKindTo(first), RaftNavigationKind.push);
    expect(first.panelNavigationKindTo(retarget), RaftNavigationKind.replace);
    expect(retarget.panelNavigationKindTo(root), RaftNavigationKind.replace);
    expect(
      root.panelNavigationKindTo(first, replaceMode: true),
      RaftNavigationKind.replace,
    );
    expect(
      first.panelNavigationKindTo(
        first.withQuery({'thread': null, 'profile': 'agent:a'}),
      ),
      RaftNavigationKind.replace,
    );
  });

  test('legacy route identity is preserved and mobile homes match Source', () {
    final old = RaftLocation.parse('/s/team/machine/id?agentTab=activity');
    expect(old.route, RaftRoute.computer);
    expect(old.toString(), '/s/team/machine/id?agentTab=activity');
    expect(old.mobileTab, RaftMobileTab.settings);
    expect(old.tabHome().toString(), '/s/team/settings');
    expect(
      RaftLocation.parse('/s/team/search').tabHome().toString(),
      '/s/team',
    );
    expect(
      RaftLocation.parse('/s/team/agent/a').tabHome().toString(),
      '/s/team/members',
    );
    expect(RaftLocation.parse('/s/team/settings/server/danger').settingsPath, [
      'server',
      'danger',
    ]);
    expect(RaftLocation.parse('/s/team/inbox').route, RaftRoute.activity);
  });

  test(
    'unobserved and foreign history cannot be used to leave the workspace',
    () {
      final entries = nextRaftNavigationEntries(
        {},
        RaftNavigationKind.replace,
        3,
        '/s/team/channel/c',
      );
      final stack = raftNavigationStackFromEntries(entries, 3);
      expect(stack.take(3), everyElement(raftUnknownNavigationEntry));
      expect(resolveRaftMobileBack(stack, '/s/team'), '/s/team');
      expect(
        resolveRaftMobileBack(['/s/other', '/s/team/channel/c'], '/s/team'),
        '/s/team',
      );
      expect(
        resolveRaftMobileBack([
          '/s/team/activity',
          '/s/team/channel/c',
        ], '/s/team'),
        isNull,
      );
      final replaced = nextRaftNavigationStack(
        ['/s/team'],
        RaftNavigationKind.replace,
        '/s/team/channel/c',
      );
      expect(resolveRaftMobileBack(replaced, '/s/team'), '/s/team');
    },
  );
}
