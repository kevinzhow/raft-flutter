import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/sidebar_drop.dart';
import 'package:raft_flutter/features/sidebar_projection.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'support/app_services_fixture.dart';

/// Sidebar.tsx `handleSidebarDragEnd` across sections: a lifted row can be
/// dropped into Pinned or a custom section from any section, and back into
/// its own section, as long as the destination sorts manually.
void main() {
  RaftChannel channel(String id, String name, {String type = 'channel'}) =>
      RaftChannel({'id': id, 'name': name, 'type': type, 'joined': true});
  RaftChannel dm(String id, String peer, String name, {bool agent = false}) =>
      RaftChannel({
        'id': id,
        'name': name,
        'type': 'dm',
        'joined': true,
        'peerType': agent ? 'agent' : 'user',
        'peerId': peer,
        'peerDisplayName': name,
      });

  final channels = [
    channel('c1', 'general'),
    channel('c2', 'random'),
    channel('c3', 'design'),
  ];
  final dms = [dm('d1', 'u2', 'Alice'), dm('d2', 'u3', 'Bob')];

  List<SidebarGroup> project(Map<String, dynamic> prefs) =>
      projectSidebar(channels: channels, dms: dms, preferences: prefs);
  SidebarGroup groupOf(Map<String, dynamic> prefs, String id) =>
      project(prefs).singleWhere((g) => g.id == id);
  SidebarEntry entryOf(
    Map<String, dynamic> prefs,
    String groupId,
    String key,
  ) => groupOf(prefs, groupId).entries.singleWhere((e) => e.key == key);

  group('sidebarCrossMoveUpdates', () {
    final prefs = <String, dynamic>{
      'pinned': [
        {'kind': 'channel', 'id': 'c3'},
      ],
      'customSections': [
        {'id': 's1', 'name': 'Launch', 'sortMode': 'manual'},
        {'id': 's2', 'name': 'Sorted', 'sortMode': 'az'},
      ],
      'sectionPlacements': [
        {'kind': 'channel', 'id': 'c2', 'sectionId': 's1', 'position': 0},
      ],
      'channelOrder': ['c1', 'c3'],
      'dmOrder': ['d1', 'd2'],
    };

    test('into Pinned: pins at the drop slot and drops the placement', () {
      final pinned = groupOf(prefs, 'system:pinned');
      final updates = sidebarCrossMoveUpdates(
        entry: entryOf(prefs, 's1', 'channel:c2'),
        dest: pinned,
        shown: pinned.entries,
        index: 0,
        preferences: prefs,
      );
      expect(updates, {
        'pinned': [
          {'kind': 'channel', 'id': 'c2'},
          {'kind': 'channel', 'id': 'c3'},
        ],
        'sectionPlacements': <Object>[],
      });
    });

    test('a DM pins as its peer, an agent DM as the agent', () {
      final pinned = groupOf(prefs, 'system:pinned');
      final updates = sidebarCrossMoveUpdates(
        entry: entryOf(prefs, 'system:dms', 'channel:d2'),
        dest: pinned,
        shown: pinned.entries,
        index: 1,
        preferences: prefs,
      );
      expect(updates, {
        'pinned': [
          {'kind': 'channel', 'id': 'c3'},
          {'kind': 'human', 'id': 'u3'},
        ],
      });
    });

    test('into a custom section: placed at the slot, pin dropped', () {
      final withPin = {
        ...prefs,
        'pinned': [
          {'kind': 'channel', 'id': 'c1'},
        ],
      };
      final s1 = groupOf(withPin, 's1');
      final updates = sidebarCrossMoveUpdates(
        entry: entryOf(withPin, 'system:pinned', 'channel:c1'),
        dest: s1,
        shown: s1.entries,
        index: 0,
        preferences: withPin,
      );
      expect(updates, {
        'sectionPlacements': [
          {'kind': 'channel', 'id': 'c1', 'sectionId': 's1', 'position': 0},
          {'kind': 'channel', 'id': 'c2', 'sectionId': 's1', 'position': 1},
        ],
        'pinned': <Object>[],
      });
    });

    test(
      'back home: the section list takes the slot, pin and placement go',
      () {
        final channelsGroup = groupOf(prefs, 'system:channels');
        final updates = sidebarCrossMoveUpdates(
          entry: entryOf(prefs, 's1', 'channel:c2'),
          dest: channelsGroup,
          shown: channelsGroup.entries,
          index: 1,
          preferences: prefs,
        );
        expect(updates, {
          // c3 is pinned, so Channels lists c1 alone; c2 takes the next slot.
          'channelOrder': ['c1', 'c3', 'c2'],
          'sectionPlacements': <Object>[],
        });
      },
    );

    test(
      'a section that sorts itself takes no drop; a foreign home neither',
      () {
        final s2 = groupOf(prefs, 's2');
        final channelEntry = entryOf(prefs, 'system:channels', 'channel:c1');
        expect(sidebarDropAllowed(channelEntry, s2, prefs), isFalse);
        final dmsGroup = groupOf(prefs, 'system:dms');
        expect(sidebarDropAllowed(channelEntry, dmsGroup, prefs), isFalse);
        expect(
          sidebarCrossMoveUpdates(
            entry: channelEntry,
            dest: dmsGroup,
            shown: dmsGroup.entries,
            index: 0,
            preferences: prefs,
          ),
          isNull,
        );
        // Pinned that sorts by name is closed too.
        final sortedPins = {...prefs, 'pinnedSortMode': 'az'};
        expect(
          sidebarDropAllowed(
            channelEntry,
            groupOf(sortedPins, 'system:pinned'),
            sortedPins,
          ),
          isFalse,
        );
      },
    );
  });

  group('mounted sidebar', () {
    Future<(WorkspaceController, List<Object?>)> setup(
      WidgetTester tester,
      Map<String, dynamic> prefs, {
      PersonalPresentationStore? presentation,
      List<RaftChannel>? rows,
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.loading = false;
      w.messageDomain.ledger.switchServer('s1');
      w.channels = rows ?? [channel('c1', 'general'), channel('c2', 'random')];
      w.dms = [dm('d1', 'u2', 'Alice'), dm('d2', 'u3', 'Bob')];
      w.section = 'chat';
      w.sidebarOrder = prefs;
      final patches = <Object?>[];
      api.routes['PATCH /servers/s1/sidebar-order'] = (o) {
        patches.add(o.data);
        return {};
      };
      api.routes['GET /servers/s1/sidebar-order'] = (_) => prefs;
      api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      api.routes['GET /servers/s1/setup-projection'] = (_) => {
        'phase': 'complete',
        'surface': 'complete',
        'blocksChat': false,
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: withAppServices(
            WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: RaftFamily.elegant),
              onAppearance: (_) async {},
              onLogout: () async {},
              presentation: presentation,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (w, patches);
    }

    Finder row(String id) => find.byKey(ValueKey('sidebar-channel-$id'));

    /// Long press [from], then drag it to [to] in small steps.
    Future<void> longPressDragTo(
      WidgetTester tester,
      Finder from,
      Offset to, {
      PointerDeviceKind kind = PointerDeviceKind.touch,
    }) async {
      final start = tester.getCenter(from);
      final gesture = await tester.startGesture(start, kind: kind);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(start + (to - start) * (i / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('a channel dropped on the empty Pinned hint pins it', (
      tester,
    ) async {
      final (w, patches) = await setup(tester, {
        'channelOrder': ['c1', 'c2'],
      });
      final hint = find.text('Drag channels or DMs here to pin');
      expect(hint, findsOneWidget);
      final start = tester.getCenter(row('c2'));
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
      expect(SidebarDrag.active, isTrue);
      await gesture.moveTo(tester.getCenter(hint));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(0, 1));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(patches.single, {
        'pinned': [
          {'kind': 'channel', 'id': 'c2'},
        ],
      });
      expect(w.sidebarOrder['pinned'], hasLength(1));
      expect(SidebarDrag.active, isFalse);
    });

    testWidgets('a row of a section that sorts itself still goes to a custom '
        'section, below the row it is dropped on', (tester) async {
      final (_, patches) = await setup(tester, {
        'channelSortMode': 'az',
        'customSections': [
          {'id': 's1', 'name': 'Launch', 'sortMode': 'manual'},
        ],
        'sectionPlacements': [
          {'kind': 'channel', 'id': 'c1', 'sectionId': 's1', 'position': 0},
        ],
        'sectionsVersion': 3,
      });
      // c1 sits in Launch; c2 is in Channels (sorted by name).
      final target = tester.getBottomLeft(row('c1')) + const Offset(40, 20);
      await longPressDragTo(tester, row('c2'), target);
      expect(patches.single, {
        'sectionPlacements': [
          {'kind': 'channel', 'id': 'c1', 'sectionId': 's1', 'position': 0},
          {'kind': 'channel', 'id': 'c2', 'sectionId': 's1', 'position': 1},
        ],
        'sectionsVersion': 3,
      });
    });

    testWidgets('a drop on a section that sorts itself changes nothing', (
      tester,
    ) async {
      final (_, patches) = await setup(tester, {
        'pinned': [
          {'kind': 'channel', 'id': 'c1'},
        ],
        'pinnedSortMode': 'az',
        'channelOrder': ['c2'],
      });
      await longPressDragTo(tester, row('c2'), tester.getCenter(row('c1')));
      expect(patches, isEmpty);
    });

    testWidgets(
      'a row dropped back on its own section keeps the list reorder',
      (tester) async {
        final (_, patches) = await setup(tester, {
          'channelOrder': ['c1', 'c2'],
        });
        await longPressDragTo(
          tester,
          row('c1'),
          tester.getCenter(row('c2')) + const Offset(0, 8),
        );
        expect(patches.single, {
          'channelOrder': ['c2', 'c1'],
        });
      },
    );

    testWidgets('the lifted row moves live: it shows faded in the section '
        'under the pointer and the section it left closes up', (tester) async {
      final (_, patches) = await setup(tester, {
        'channelOrder': ['c2'],
        'customSections': [
          {'id': 's1', 'name': 'Launch', 'sortMode': 'manual'},
        ],
        'sectionPlacements': [
          {'kind': 'channel', 'id': 'c1', 'sectionId': 's1', 'position': 0},
        ],
        'sectionsVersion': 3,
      });
      double top(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('sidebar-section-$id'))).dy;
      final channelsBefore = top('system:dms') - top('system:channels');
      final start = tester.getCenter(row('c2'));
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      final target = tester.getCenter(row('c1')) - const Offset(0, 8);
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(start + (target - start) * (i / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // c2 sits in Launch now, above c1, faded; Channels has closed up.
      expect(row('c2'), findsNWidgets(2), reason: 'the row and its card');
      final ghost = find
          .ancestor(of: row('c2'), matching: find.byType(Opacity))
          .evaluate()
          .map((e) => (e.widget as Opacity).opacity);
      expect(ghost, contains(.12));
      expect(
        tester.getTopLeft(row('c2').first).dy,
        lessThan(tester.getTopLeft(row('c1')).dy),
      );
      expect(top('s1'), lessThan(tester.getTopLeft(row('c2').first).dy));
      expect(
        top('system:dms') - top('system:channels'),
        lessThan(channelsBefore),
      );
      expect(patches, isEmpty, reason: 'nothing is sent before the drop');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(patches.single, {
        'sectionPlacements': [
          {'kind': 'channel', 'id': 'c2', 'sectionId': 's1', 'position': 0},
          {'kind': 'channel', 'id': 'c1', 'sectionId': 's1', 'position': 1},
        ],
        'sectionsVersion': 3,
      });
      expect(row('c2'), findsOneWidget);
    });

    testWidgets('a drag released outside every section changes nothing and '
        'the row returns', (tester) async {
      final (_, patches) = await setup(tester, {
        'channelOrder': ['c1', 'c2'],
      });
      final before = tester.getCenter(row('c1'));
      final start = before;
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 1; i <= 6; i++) {
        await gesture.moveTo(start + Offset(900, 0) * (i / 6));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(patches, isEmpty);
      expect(tester.getCenter(row('c1')), before);
      expect(SidebarDrag.active, isFalse);
    });

    testWidgets('empty custom sections stay visible when empty sections are '
        'hidden', (tester) async {
      final presentation = PersonalPresentationStore(desktop: false);
      addTearDown(presentation.dispose);
      await setup(tester, {
        'customSections': [
          {'id': 's1', 'name': 'Launch', 'sortMode': 'manual'},
        ],
        'sectionsVersion': 3,
      }, presentation: presentation);
      presentation.update(presentation.key, hideEmptySections: true);
      await tester.pumpAndSettle();
      expect(presentation.value.hideEmptySections, isTrue);
      // Pinned has nothing and goes; the custom section stays, with its hint.
      expect(
        find.byKey(const ValueKey('sidebar-section-system:pinned')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('sidebar-section-s1')), findsOneWidget);
      expect(find.text('No conversations'), findsOneWidget);
    });

    testWidgets('a lifted row held at the edge of the list scrolls it', (
      tester,
    ) async {
      final rows = [for (var i = 0; i < 40; i++) channel('x$i', 'room $i')];
      await setup(tester, {
        'channelOrder': [for (final c in rows) c.id],
      }, rows: rows);
      final list = find.descendant(
        of: find.byKey(const Key('workspace-sidebar')),
        matching: find.byType(Scrollable),
      );
      ScrollPosition position() =>
          tester.state<ScrollableState>(list.first).position;
      expect(position().pixels, 0);
      final start = tester.getCenter(row('x2'));
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      final bottom = tester.getBottomLeft(
        find.byKey(const Key('workspace-sidebar')),
      );
      for (var i = 1; i <= 8; i++) {
        await gesture.moveTo(
          Offset(start.dx, start.dy + (bottom.dy - 20 - start.dy) * i / 8),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 500));
      final held = position().pixels;
      expect(held, greaterThan(100));
      await gesture.up();
      await tester.pumpAndSettle();
      // Released: the scrolling stops with the drag.
      await tester.pump(const Duration(milliseconds: 500));
      expect(position().pixels, held);
      expect(SidebarDrag.active, isFalse);
    });
  });
}
