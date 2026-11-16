import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/phone_stack.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';

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

void main() {
  const barTabs = {'chat', 'activity', 'tasks', 'search'};

  group('Web v1.24 bottom bar preferences', () {
    test('the configurable tabs are Home, Activity, Tasks, Search', () {
      expect(MobileTabs.configurable, ['chat', 'activity', 'tasks', 'search']);
      expect(MobileTabbarSettings.defaults.visible, [
        'chat',
        'activity',
        'tasks',
        'search',
      ]);
      expect(MobileTabbarSettings.parse(null), MobileTabbarSettings.defaults);
      expect(MobileTabbarSettings.defaults.isDefault, isTrue);
    });

    test('a value stored by the last release keeps its choice', () {
      // Release with Members / Computers tabs, customised bar.
      final next = MobileTabbarSettings.parse(
        '{"order":["chat","tasks","members","computers","activity"],'
        '"enabled":["chat","activity","members"]}',
      );
      // Members is gone, Search is new and fits, the rest is kept in order.
      expect(next.visible, ['chat', 'activity', 'search']);
      expect(next.order, ['chat', 'tasks', 'activity', 'search']);
    });

    test('Search that was already placed stays where the user put it', () {
      final next = MobileTabbarSettings.parse(
        '{"order":["search","chat","activity","tasks"],"enabled":["chat"]}',
      );
      expect(next.visible, ['chat']);
      expect(next.order.first, 'search');
    });

    test('a value that only held removed tabs reads as the default bar', () {
      final next = MobileTabbarSettings.parse(
        '{"order":["members","computers","chat","tasks","activity"],'
        '"enabled":["members","computers"]}',
      );
      expect(next, MobileTabbarSettings.defaults);
      final none = MobileTabbarSettings.parse('{"order":[],"enabled":[]}');
      expect(none, MobileTabbarSettings.defaults);
    });

    test('a bare list of ids is read as the enabled ids', () {
      final next = MobileTabbarSettings.parse('["tasks","members","chat"]');
      expect(next.visible, ['tasks', 'chat']);
    });

    test('no account rule hides a configurable tab', () {
      expect(
        MobileTabbarSettings.defaults.effective(guest: true, can: (_) => false),
        ['chat', 'activity', 'tasks', 'search'],
      );
    });
  });

  group('Web v1.24 tab roots and phone stack', () {
    List<String> stack(
      RaftLocation l, {
      Set<String> tabs = barTabs,
      RaftLocation? source,
    }) => phoneStackFor(l, tabs, source: source).map(tail).toList();

    test('Home, Activity, Tasks and Search are roots', () {
      for (final route in [
        RaftRoute.home,
        RaftRoute.activity,
        RaftRoute.tasks,
        RaftRoute.search,
      ]) {
        expect(WorkspaceNavigation.rootTabOf(at(route), barTabs), isNotNull);
        expect(stack(at(route)), hasLength(1), reason: '$route');
      }
      expect(
        WorkspaceNavigation.rootTabOf(at(RaftRoute.search), barTabs),
        'search',
      );
    });

    test('Members, Computers and Settings are pushed pages', () {
      for (final route in [
        RaftRoute.members,
        RaftRoute.computers,
        RaftRoute.settings,
      ]) {
        expect(WorkspaceNavigation.rootTabOf(at(route), barTabs), isNull);
        expect(stack(at(route)), ['', tail(at(route))], reason: '$route');
      }
    });

    test('Back from a pushed page returns to the root it came from', () {
      for (final route in [
        RaftRoute.members,
        RaftRoute.computers,
        RaftRoute.settings,
      ]) {
        for (final from in [RaftRoute.activity, RaftRoute.tasks]) {
          expect(stack(at(route), source: at(from)), [
            tail(at(from)),
            tail(at(route)),
          ]);
        }
      }
    });

    test('details sit above their pushed list', () {
      expect(stack(at(RaftRoute.agent, id: 'a1')), [
        '',
        '/members',
        '/agent/a1',
      ]);
      expect(
        stack(at(RaftRoute.human, id: 'h1'), source: at(RaftRoute.members)),
        ['', '/members', '/human/h1'],
      );
      expect(stack(at(RaftRoute.computer, id: 'm1')), [
        '',
        '/computers',
        '/computer/m1',
      ]);
      expect(stack(at(RaftRoute.settings, settings: ['appearance'])), [
        '',
        '/settings',
        '/settings/appearance',
      ]);
    });

    test('a pushed page opened from a pushed page keeps both', () {
      expect(stack(at(RaftRoute.computers), source: at(RaftRoute.settings)), [
        '',
        '/settings',
        '/computers',
      ]);
    });

    test('coming back to a list from its own detail never stacks it twice', () {
      expect(
        stack(
          at(RaftRoute.settings),
          source: at(RaftRoute.settings, settings: ['appearance']),
        ),
        ['', '/settings'],
      );
      expect(
        stack(at(RaftRoute.members), source: at(RaftRoute.agent, id: 'a1')),
        ['', '/members'],
      );
    });

    test('with the left rail Members, Computers and Settings stay roots', () {
      const rail = {
        'chat',
        'activity',
        'tasks',
        'members',
        'computers',
        'settings',
      };
      for (final route in [
        RaftRoute.members,
        RaftRoute.computers,
        RaftRoute.settings,
      ]) {
        expect(stack(at(route), tabs: rail), hasLength(1));
      }
      expect(stack(at(RaftRoute.agent, id: 'a1'), tabs: rail), [
        '/members',
        '/agent/a1',
      ]);
    });
  });
}
