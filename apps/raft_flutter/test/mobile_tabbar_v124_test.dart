import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/phone_stack.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'support/server_tab.dart';

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

  group('layout and input', () {
    Future<void> remount(RootFixture f, WidgetTester t, Size size) async {
      await f.mount(t, 'light', size.width, uri: Uri.parse('/s/alpha'));
      t.view.physicalSize = size;
      await f.flush(t);
    }

    // The phone bar follows the width, not the device: an unfolded fold is as
    // wide as a desktop window and has the rail instead (RaftAdaptiveWorkspace).
    for (final size in const [Size(856, 944), Size(944, 856)]) {
      testWidgets(
        'an unfolded Android ${size.width.toInt()}x${size.height.toInt()} has '
        'the rail, no bar and no server tab',
        (t) async {
          final f = RootFixture();
          await remount(f, t, size);
          expect(
            find.byKey(const Key('workspace-mobile-navigation')),
            findsNothing,
          );
          expect(find.byKey(serverTabKey), findsNothing);
          expect(find.byKey(const Key('rail-settings')), findsOneWidget);
          await f.close(t);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }

    testWidgets('a narrow Linux window keeps the bar and opens it by mouse', (
      t,
    ) async {
      final f = RootFixture();
      await remount(f, t, const Size(390, 844));
      expect(
        find.byKey(const Key('workspace-mobile-navigation')),
        findsOneWidget,
      );
      final mouse = await t.startGesture(
        t.getCenter(find.byKey(serverTabKey)),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.up();
      await f.flush(t);
      expect(find.byKey(serverPopoverKey), findsOneWidget);
      // Escape closes it, as it does a menu.
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await f.flush(t);
      expect(find.byKey(serverPopoverKey), findsNothing);
      await f.close(t);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('a folded Android phone (touch) opens it by tap', (t) async {
      final f = RootFixture();
      await remount(f, t, const Size(390, 844));
      await openServerPopover(t, flush: f.flush);
      expect(find.byKey(serverPopoverKey), findsOneWidget);
      await f.close(t);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
