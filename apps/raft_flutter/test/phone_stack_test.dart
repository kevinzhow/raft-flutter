import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/phone_stack.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';

RaftLocation at(
  RaftRoute route, {
  String? id,
  List<String> settings = const [],
  Map<String, String> query = const {},
}) => RaftLocation.at(
  serverSlug: 'alpha',
  route: route,
  entityId: id,
  settingsPath: settings,
  query: query,
);

String tail(RaftLocation l) => l.toString().replaceFirst('/s/alpha', '');
List<String> paths(List<RaftLocation> stack) => stack.map(tail).toList();

void main() {
  const noTabs = <String>{};
  List<RaftLocation> stack(
    RaftLocation l, {
    Set<String> tabs = noTabs,
    RaftLocation? source,
  }) => phoneStackFor(l, tabs, source: source);

  group('phoneStackFor', () {
    test('tab roots are a single page', () {
      for (final route in [
        RaftRoute.home,
        RaftRoute.tasks,
        RaftRoute.members,
        RaftRoute.settings,
      ]) {
        final root = at(route);
        expect(stack(root), [root], reason: '$route');
      }
      expect(stack(at(RaftRoute.activity), tabs: {'activity'}), hasLength(1));
      expect(stack(at(RaftRoute.computers), tabs: {'computers'}), hasLength(1));
    });

    test(
      'conversation: root -> channel -> thread -> profile / task / page',
      () {
        final channel = at(RaftRoute.channel, id: 'ca');
        expect(paths(stack(channel)), ['', '/channel/ca']);
        expect(paths(stack(at(RaftRoute.dm, id: 'd1'))), ['', '/dm/d1']);
        final thread = channel.withQuery({'thread': 'ca:ma'});
        expect(paths(stack(thread)), [
          '',
          '/channel/ca',
          '/channel/ca?thread=ca%3Ama',
        ]);
        final profile = thread.withQuery({'profile': 'human:bob'});
        expect(stack(profile), hasLength(4));
        expect(stack(profile)[2].uri, thread.uri);
        final task = profile.withQuery({'task': '1'});
        expect(stack(task), hasLength(5));
        final page = channel.withQuery({'channelPage': 'settings:ca'});
        expect(paths(stack(page)), [
          '',
          '/channel/ca',
          '/channel/ca?channelPage=settings%3Aca',
        ]);
        // A focus message on the thread belongs to the thread, not the channel.
        final focused = thread.withQuery({'msg': 'reply-9'});
        expect(stack(focused)[1].query('msg'), isNull);
        final parentFocus = thread.withQuery({'msg': 'ma'});
        expect(stack(parentFocus)[1].query('msg'), 'ma');
      },
    );

    test('overlays on a tab root stack above the root', () {
      for (final route in [
        RaftRoute.home,
        RaftRoute.tasks,
        RaftRoute.members,
      ]) {
        final root = at(route);
        for (final slot in ['task', 'legacyTask']) {
          final s = stack(root.withQuery({slot: 'c:t'}));
          expect(s, hasLength(2));
          expect(s.first.uri, root.uri);
        }
      }
    });

    test('detail routes have their tab root under them', () {
      expect(paths(stack(at(RaftRoute.agent, id: 'a1'))), [
        '/members',
        '/agent/a1',
      ]);
      expect(paths(stack(at(RaftRoute.human, id: 'bob'))), [
        '/members',
        '/human/bob',
      ]);
      expect(paths(stack(at(RaftRoute.memberGraph))), [
        '/members',
        '/members/graph',
      ]);
      expect(paths(stack(at(RaftRoute.computer, id: 'm1'))), [
        '/settings',
        '/computer/m1',
      ]);
      expect(
        paths(stack(at(RaftRoute.computer, id: 'm1'), tabs: {'computers'})),
        ['/computers', '/computer/m1'],
      );
      expect(paths(stack(at(RaftRoute.settings, settings: ['appearance']))), [
        '/settings',
        '/settings/appearance',
      ]);
      expect(paths(stack(at(RaftRoute.releaseNotes))), [
        '/settings',
        '/release-notes',
      ]);
      expect(paths(stack(at(RaftRoute.search))), ['', '/search']);
      expect(paths(stack(at(RaftRoute.saved))), ['', '/saved']);
      expect(paths(stack(at(RaftRoute.activity))), ['', '/activity']);
    });

    test('a content slot is its own page above its list', () {
      for (final route in [RaftRoute.activity, RaftRoute.search]) {
        for (final open in [
          'channel:ca',
          'dm:d1',
          'agent:a1',
          'human:bob',
          'machine:m1',
        ]) {
          final slot = at(route, query: {'open': open, 'msg': 'm1'});
          final s = stack(slot);
          expect(s, hasLength(3), reason: open);
          expect(tail(s[1]), '/${route.name}');
          expect(s.last.uri, slot.uri);
        }
        final thread = at(
          route,
          query: {'open': 'thread:t1', 'thread': 'ca:ma', 'msg': 'r1'},
        );
        expect(stack(thread), hasLength(3));
        expect(stack(thread).last.uri, thread.uri);
      }
    });

    test('locationForPhone gives the conversation a slot stands for', () {
      for (final route in [RaftRoute.activity, RaftRoute.search]) {
        String phone(Map<String, String> query) =>
            tail(locationForPhone(at(route, query: query)));
        expect(
          phone({'open': 'channel:ca', 'msg': 'm1'}),
          '/channel/ca?msg=m1',
        );
        expect(phone({'open': 'dm:d1'}), '/dm/d1');
        expect(phone({'open': 'agent:a1'}), '/agent/a1');
        expect(phone({'open': 'human:bob'}), '/human/bob');
        expect(phone({'open': 'machine:m1'}), '/computer/m1');
        expect(
          phone({'open': 'thread:t1', 'thread': 'ca:ma', 'msg': 'r1'}),
          '/channel/ca?thread=ca%3Ama&msg=r1',
        );
        // An unresolvable thread slot degrades to its list.
        expect(phone({'open': 'thread:t1'}), '/${route.name}');
      }
    });

    test(
      'a list or tab the user came from is the only history-derived page',
      () {
        final channel = at(RaftRoute.channel, id: 'ca');
        expect(paths(stack(channel, source: at(RaftRoute.search))), [
          '',
          '/search',
          '/channel/ca',
        ]);
        expect(
          paths(
            stack(channel, tabs: {'activity'}, source: at(RaftRoute.activity)),
          ),
          ['/activity', '/channel/ca'],
        );
        expect(paths(stack(channel, source: at(RaftRoute.tasks))), [
          '/tasks',
          '/channel/ca',
        ]);
        expect(
          paths(stack(at(RaftRoute.tasks), source: at(RaftRoute.search))),
          ['/tasks'],
        );
      },
    );

    test('stacks are capped', () {
      final deep = at(RaftRoute.channel, id: 'ca').withQuery({
        'thread': 'ca:ma',
        'profile': 'agent:a1',
        'legacyTask': 'c:t',
        'task': '1',
        'channelPage': 'settings:ca',
      });
      expect(
        stack(deep, source: at(RaftRoute.search)).length,
        lessThanOrEqualTo(phonePageLimit),
      );
    });

    test('every level is a location whose own stack is a prefix', () {
      final shapes = <RaftLocation>[
        at(
          RaftRoute.channel,
          id: 'ca',
        ).withQuery({'thread': 'ca:ma', 'profile': 'human:bob'}),
        at(
          RaftRoute.channel,
          id: 'ca',
        ).withQuery({'thread': 'ca:ma', 'task': '1'}),
        at(
          RaftRoute.channel,
          id: 'ca',
        ).withQuery({'profile': 'agent:a1', 'agentTab': 'skills'}),
        at(
          RaftRoute.agent,
          id: 'a1',
        ).withQuery({'agentTab': 'skills', 'profile': 'human:bob'}),
      ];
      for (final shape in shapes) {
        final full = stack(shape);
        for (var i = 1; i < full.length; i++) {
          final sub = stack(full[i]);
          expect(
            paths(sub),
            paths(full.sublist(0, i + 1)),
            reason: tail(shape),
          );
        }
      }
    });
  });

  group('phoneReturnSource', () {
    final home = at(RaftRoute.home);
    final a = at(RaftRoute.channel, id: 'a');
    final b = at(RaftRoute.channel, id: 'b');
    RaftLocation? source(List<RaftLocation> entries, {int floor = 0}) =>
        phoneReturnSource(
          entries,
          entries.length - 1,
          entries.last,
          noTabs,
          floor: floor,
        );

    test('a channel opened from a channel returns to it on the phone', () {
      expect(tail(source([home, a, b])!), '/channel/a');
    });

    test('panel entries of the same page are skipped', () {
      final thread = a.withQuery({'thread': 'a:m'});
      expect(
        source([
          home,
          thread,
          a,
          a.withQuery({'msg': '1'}),
        ]),
        home,
      );
    });

    test('entries made before a layout crossing are not a phone journey', () {
      expect(source([home, a, b], floor: 2), isNull);
      expect(source([home, a, b], floor: 1)?.entityId, 'a');
    });

    test('lists and tab roots stay eligible across a crossing', () {
      final search = at(RaftRoute.search);
      expect(tail(source([home, search, a], floor: 2)!), '/search');
    });

    test('another server is never a source', () {
      final other = RaftLocation.at(serverSlug: 'beta', route: RaftRoute.home);
      expect(source([other, a]), isNull);
    });
  });

  group('direct overlays and channel page siblings', () {
    final activity = at(RaftRoute.activity);
    final channel = at(RaftRoute.channel, id: 'ca');
    final thread = channel.withQuery({'thread': 'ca:ma', 'msg': 'r'});

    test(
      'a thread opened straight from a list has no conversation under it',
      () {
        final entries = [at(RaftRoute.home), activity, thread];
        expect(openedDirectly(entries, 2, thread), isTrue);
        final s = phoneStackFor(thread, noTabs, source: activity, direct: true);
        expect(paths(s), ['', '/activity', tail(thread)]);
      },
    );

    test('a thread opened from the shown conversation keeps it', () {
      final entries = [at(RaftRoute.home), activity, channel, thread];
      expect(openedDirectly(entries, 3, thread), isFalse);
      expect(openedDirectly([thread], 0, thread), isFalse);
      expect(openedDirectly([channel], 0, channel), isFalse);
    });

    test('channel members opened from settings keep settings under them', () {
      final settings = channel.withQuery({'channelPage': 'settings:ca'});
      final members = channel.withQuery({'channelPage': 'members:ca'});
      expect(
        channelPageSibling([channel, settings, members], 2, members),
        settings,
      );
      expect(channelPageSibling([channel, members], 1, members), isNull);
      final s = phoneStackFor(members, noTabs, sibling: settings);
      expect(s.map((l) => l.query('channelPage')).toList(), [
        null,
        null,
        'settings:ca',
        'members:ca',
      ]);
    });
  });

  group('layout adapters', () {
    test('channelPage is phone-only', () {
      final page = at(RaftRoute.channel, id: 'ca').withQuery({
        'channelPage': 'members:ca',
        'channelPageAdd': '1',
        'thread': 'ca:ma',
      });
      expect(hasPhoneOnlyIdentity(page), isTrue);
      final wide = locationForWide(page);
      expect(wide.channelPage, isNull);
      expect(wide.query('channelPageAdd'), isNull);
      expect(wide.thread, isNotNull);
      final plain = at(
        RaftRoute.channel,
        id: 'ca',
      ).withQuery({'channelPage': 'settings:ca'});
      expect(locationForWide(plain).toString().contains('?'), isFalse);
      final other = at(
        RaftRoute.channel,
        id: 'ca',
      ).withQuery({'thread': 'ca:ma'});
      expect(locationForWide(other), other);
    });

    test('content slots only exist on Activity and Search', () {
      expect(
        hasContentSlot(at(RaftRoute.activity, query: {'open': 'channel:ca'})),
        isTrue,
      );
      expect(hasContentSlot(at(RaftRoute.activity)), isFalse);
      expect(hasContentSlot(at(RaftRoute.channel, id: 'ca')), isFalse);
      final channel = at(RaftRoute.channel, id: 'ca');
      expect(locationForPhone(channel), channel);
    });

    test('translateForLayout rewrites history for the phone', () {
      final n = WorkspaceNavigation()..bind('t', at(RaftRoute.home));
      n.navigate(at(RaftRoute.activity));
      n.navigate(
        at(RaftRoute.activity, query: {'open': 'channel:ca', 'msg': 'm1'}),
        kind: RaftNavigationKind.replace,
      );
      final t = n.translateForLayout(compact: true)!;
      expect(tail(t.to), '/channel/ca?msg=m1');
      expect(paths(n.entries), ['', '/activity', '/channel/ca?msg=m1']);
      expect(n.index, 2);
      expect(n.translateForLayout(compact: true), isNull);
      expect(paths(mobilePageStack(n)), [
        '',
        '/activity',
        '/channel/ca?msg=m1',
      ]);
      backMobilePage(n);
      expect(tail(n.location), '/activity');
      backMobilePage(n);
      expect(tail(n.location), '');
    });

    test('translateForLayout drops channelPage; a pushed page pops', () {
      final channel = at(RaftRoute.channel, id: 'ca');
      final n = WorkspaceNavigation()..bind('t', at(RaftRoute.home));
      n.navigate(channel);
      n.navigate(channel.withQuery({'channelPage': 'settings:ca'}));
      final t = n.translateForLayout(compact: false)!;
      expect(t.to.uri, channel.uri);
      expect(n.location.uri, channel.uri);
      expect(paths(n.entries), ['', '/channel/ca']);
      expect(n.translateForLayout(compact: false), isNull);
      // Cold page: no matching previous entry, replace in place.
      final cold = WorkspaceNavigation()
        ..bind('t', channel.withQuery({'channelPage': 'members:ca'}));
      cold.translateForLayout(compact: false);
      expect(paths(cold.entries), ['/channel/ca']);
    });

    test('collapseRepeatedEntries removes panel open/close leftovers', () {
      final channel = at(RaftRoute.channel, id: 'ca');
      final n = WorkspaceNavigation()..bind('t', at(RaftRoute.home));
      n.navigate(channel);
      n.navigate(channel.withQuery({'thread': 'ca:ma'}));
      n.navigate(channel, kind: RaftNavigationKind.replace);
      n.navigate(channel.withQuery({'thread': 'ca:mb'}));
      n.navigate(channel, kind: RaftNavigationKind.replace);
      expect(paths(n.entries), [
        '',
        '/channel/ca',
        '/channel/ca',
        '/channel/ca',
      ]);
      expect(n.collapseRepeatedEntries(), isTrue);
      expect(paths(n.entries), ['', '/channel/ca']);
      expect(n.index, 1);
      expect(n.collapseRepeatedEntries(), isFalse);
    });
  });
}
