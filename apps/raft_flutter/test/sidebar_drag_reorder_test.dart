import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/sidebar_projection.dart';
import 'package:raft_flutter/features/sidebar_reorder.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'support/app_services_fixture.dart';

/// Sidebar.tsx drag-and-drop inside a section: a long press lifts a row of a
/// manually sorted section, the drop persists through `updateSidebarOrder`
/// (PATCH /servers/:id/sidebar-order) as `sectionPlacements`, `pinned`,
/// `channelOrder` or `dmOrder`. A long press on a section header lifts the
/// whole section (`SortableSidebarSection`) and persists `sectionOrder`.
void main() {
  RaftChannel channel(
    String id,
    String name, {
    String type = 'channel',
    bool joined = true,
  }) => RaftChannel({'id': id, 'name': name, 'type': type, 'joined': joined});
  RaftChannel dm(String id, String peer, String name, {bool agent = false}) =>
      RaftChannel({
        'id': id,
        'name': name,
        'type': 'dm',
        'joined': true,
        'peerType': agent ? 'agent' : 'user',
        'peerId': peer,
        'peerName': name.toLowerCase(),
        'peerDisplayName': name,
      });

  final channels = [
    channel('c1', 'general'),
    channel('c2', 'random'),
    channel('c3', 'design'),
    channel('c4', 'ops'),
    channel('c5', 'eng'),
    channel('j1', 'joint', type: 'joint'),
  ];
  final dms = [
    dm('d1', 'u2', 'Alice'),
    dm('d2', 'u3', 'Bob'),
    dm('d3', 'a1', 'Helper', agent: true),
    dm('d4', 'u4', 'Carol'),
  ];
  final agents = [
    {'id': 'a1', 'name': 'helper', 'displayName': 'Helper'},
  ];
  Map<String, dynamic> preferences() => {
    'pinned': [
      {'kind': 'channel', 'id': 'c3'},
      {'kind': 'human', 'id': 'u3'},
      {'kind': 'channel', 'id': 'gone'},
      {'kind': 'agent', 'id': 'a1'},
    ],
    'customSections': [
      {'id': 's1', 'name': 'Launch', 'sortMode': 'manual'},
      {'id': 's2', 'name': 'Later', 'sortMode': 'az'},
    ],
    'sectionPlacements': [
      {'kind': 'channel', 'id': 'c2', 'sectionId': 's1', 'position': 1},
      {'kind': 'channel', 'id': 'c1', 'sectionId': 's1', 'position': 0},
      {'kind': 'channel', 'id': 'deleted', 'sectionId': 's1', 'position': 2},
      {'kind': 'channel', 'id': 'c4', 'sectionId': 's2', 'position': 0},
    ],
    'channelOrder': ['j1', 'c5', 'archived', 'c4'],
    'dmOrder': ['d4', 'd1'],
    'sectionsVersion': 3,
  };
  List<SidebarGroup> project(Map<String, dynamic> prefs) => projectSidebar(
    channels: channels,
    dms: dms,
    preferences: prefs,
    agents: agents,
  );
  SidebarGroup groupOf(Map<String, dynamic> prefs, String id) =>
      project(prefs).singleWhere((g) => g.id == id);
  List<String> labels(SidebarGroup g) => [for (final e in g.entries) e.label];

  Map<String, dynamic> reorder(
    Map<String, dynamic> prefs,
    String id,
    int from,
    int to, {
    List<SidebarEntry>? shown,
  }) {
    final g = groupOf(prefs, id);
    final updates = sidebarReorderUpdates(
      group: g,
      shown: shown ?? g.entries,
      preferences: prefs,
      from: from,
      to: to,
    );
    expect(updates, isNotNull);
    return updates!;
  }

  group('sidebarReorderUpdates', () {
    test('custom section: positions are rewritten in the dropped order', () {
      final prefs = preferences();
      expect(labels(groupOf(prefs, 's1')), ['general', 'random']);
      final updates = reorder(prefs, 's1', 1, 0);
      expect(updates, {
        'sectionPlacements': [
          {'kind': 'channel', 'id': 'c4', 'sectionId': 's2', 'position': 0},
          {'kind': 'channel', 'id': 'c2', 'sectionId': 's1', 'position': 0},
          {'kind': 'channel', 'id': 'c1', 'sectionId': 's1', 'position': 1},
          // An unresolved placement keeps its place after the shown rows.
          {
            'kind': 'channel',
            'id': 'deleted',
            'sectionId': 's1',
            'position': 2,
          },
        ],
      });
      expect(labels(groupOf({...prefs, ...updates}, 's1')), [
        'random',
        'general',
      ]);
    });

    test('custom section: an agent placement keeps its agent ref', () {
      final prefs = preferences()
        ..['pinned'] = <Object>[]
        ..['sectionPlacements'] = [
          {'kind': 'channel', 'id': 'c1', 'sectionId': 's1', 'position': 0},
          {'kind': 'agent', 'id': 'a1', 'sectionId': 's1', 'position': 1},
          {'kind': 'channel', 'id': 'c2', 'sectionId': 's1', 'position': 2},
        ];
      expect(labels(groupOf(prefs, 's1')), ['general', 'Helper', 'random']);
      final updates = reorder(prefs, 's1', 0, 2);
      expect(updates['sectionPlacements'], [
        {'kind': 'agent', 'id': 'a1', 'sectionId': 's1', 'position': 0},
        {'kind': 'channel', 'id': 'c2', 'sectionId': 's1', 'position': 1},
        {'kind': 'channel', 'id': 'c1', 'sectionId': 's1', 'position': 2},
      ]);
      expect(labels(groupOf({...prefs, ...updates}, 's1')), [
        'Helper',
        'random',
        'general',
      ]);
    });

    test('pinned: the refs follow the dropped order, stale refs stay', () {
      final prefs = preferences();
      expect(labels(groupOf(prefs, 'system:pinned')), [
        'design',
        'Bob',
        'Helper',
      ]);
      final updates = reorder(prefs, 'system:pinned', 2, 0);
      expect(updates, {
        'pinned': [
          {'kind': 'agent', 'id': 'a1'},
          {'kind': 'channel', 'id': 'c3'},
          {'kind': 'human', 'id': 'u3'},
          {'kind': 'channel', 'id': 'gone'},
        ],
      });
      expect(labels(groupOf({...prefs, ...updates}, 'system:pinned')), [
        'Helper',
        'design',
        'Bob',
      ]);
    });

    test('pinned: dragging down lands after the row it passed', () {
      final prefs = preferences();
      final updates = reorder(prefs, 'system:pinned', 0, 1);
      expect(labels(groupOf({...prefs, ...updates}, 'system:pinned')), [
        'Bob',
        'design',
        'Helper',
      ]);
    });

    test('channels: the group takes its own slots of channelOrder', () {
      final prefs = preferences();
      // c4 is placed in s2; the joint channel and archived id are not rows.
      expect(labels(groupOf(prefs, 'system:channels')), ['eng']);
      final more = {
        ...prefs,
        'sectionPlacements': <Object>[],
        'pinned': <Object>[],
      };
      expect(labels(groupOf(more, 'system:channels')), [
        'eng',
        'ops',
        'general',
        'random',
        'design',
      ]);
      final updates = reorder(more, 'system:channels', 3, 0);
      expect(updates, {
        // random, eng, ops take the group's slots; general, design follow.
        'channelOrder': ['j1', 'c2', 'archived', 'c5', 'c4', 'c1', 'c3'],
      });
      expect(labels(groupOf({...more, ...updates}, 'system:channels')), [
        'random',
        'eng',
        'ops',
        'general',
        'design',
      ]);
      expect(labels(groupOf({...more, ...updates}, 'system:joint')), ['joint']);
    });

    test('channels: a filtered subset keeps the hidden rows in place', () {
      final prefs = {
        ...preferences(),
        'sectionPlacements': <Object>[],
        'pinned': <Object>[],
      };
      final g = groupOf(prefs, 'system:channels');
      // Joined-only view hides "ops" (index 1).
      final shown = [
        for (final e in g.entries)
          if (e.label != 'ops') e,
      ];
      final updates = reorder(prefs, 'system:channels', 0, 3, shown: shown);
      expect(labels(groupOf({...prefs, ...updates}, 'system:channels')), [
        'general',
        'ops',
        'random',
        'design',
        'eng',
      ]);
    });

    test('direct messages: dmOrder follows the drop', () {
      final prefs = preferences();
      expect(labels(groupOf(prefs, 'system:dms')), ['Carol', 'Alice']);
      final updates = reorder(prefs, 'system:dms', 0, 1);
      expect(updates, {
        'dmOrder': ['d1', 'd4'],
      });
    });

    test('sorted groups and no-op drops produce nothing', () {
      final prefs = {
        ...preferences(),
        'pinnedSortMode': 'az',
        'dmSortMode': 'recent',
      };
      for (final id in ['system:pinned', 'system:dms', 's2']) {
        final g = groupOf(prefs, id);
        expect(sidebarGroupReorderable(g, prefs), isFalse, reason: id);
      }
      expect(
        sidebarReorderUpdates(
          group: groupOf(prefs, 'system:pinned'),
          shown: groupOf(prefs, 'system:pinned').entries,
          preferences: prefs,
          from: 0,
          to: 1,
        ),
        isNull,
      );
      final s1 = groupOf(prefs, 's1');
      expect(sidebarGroupReorderable(s1, prefs), isTrue);
      expect(
        sidebarReorderUpdates(
          group: s1,
          shown: s1.entries,
          preferences: prefs,
          from: 1,
          to: 1,
        ),
        isNull,
      );
      expect(
        sidebarReorderUpdates(
          group: s1,
          shown: s1.entries,
          preferences: prefs,
          from: 0,
          to: 5,
        ),
        isNull,
      );
      // An absent sort mode is manual.
      expect(
        sidebarGroupReorderable(groupOf(const {}, 'system:channels'), const {}),
        isTrue,
      );
    });

    test('replaceSidebarSubsetOrder appends ids the order lacked', () {
      expect(
        replaceSidebarSubsetOrder(['x', 'a', 'y'], ['a', 'b'], ['b', 'a']),
        ['x', 'b', 'y', 'a'],
      );
    });
  });

  group('sidebarSectionReorderUpdates', () {
    const system = [
      'system:pinned',
      'system:joint',
      'system:channels',
      'system:dms',
    ];

    test('the stored order is completed with every section once', () {
      expect(sidebarSectionOrder(const {}), system);
      expect(
        sidebarSectionOrder({
          'sectionOrder': ['s2', 'system:dms', 's2', 'missing', 7],
          'customSections': [
            {'id': 's1', 'name': 'Launch'},
            {'id': 's2', 'name': 'Later'},
          ],
        }),
        [
          's2',
          'system:dms',
          'system:pinned',
          'system:joint',
          'system:channels',
          's1',
        ],
      );
    });

    test('a section dropped on another takes its slot', () {
      final prefs = preferences();
      // Dragging up lands before the target.
      expect(
        sidebarSectionReorderUpdates(
          preferences: prefs,
          fromId: 's1',
          toId: 'system:joint',
        ),
        {
          'sectionOrder': [
            'system:pinned',
            's1',
            'system:joint',
            'system:channels',
            'system:dms',
            's2',
          ],
        },
      );
      // Dragging down lands after it.
      final updates = sidebarSectionReorderUpdates(
        preferences: prefs,
        fromId: 'system:pinned',
        toId: 'system:channels',
      )!;
      expect(updates['sectionOrder'], [
        'system:joint',
        'system:channels',
        'system:pinned',
        'system:dms',
        's1',
        's2',
      ]);
      // The projection follows the new order.
      expect(
        [
          for (final g in project({...prefs, ...updates})) g.id,
        ],
        [
          'system:joint',
          'system:channels',
          'system:pinned',
          'system:dms',
          's1',
          's2',
        ],
      );
    });

    test('a stored partial order is moved as the full list', () {
      expect(
        sidebarSectionReorderUpdates(
          preferences: {
            'sectionOrder': ['system:dms'],
          },
          fromId: 'system:channels',
          toId: 'system:dms',
        ),
        {
          'sectionOrder': [
            'system:channels',
            'system:dms',
            'system:pinned',
            'system:joint',
          ],
        },
      );
    });

    test('no-op and unknown drops produce nothing', () {
      final prefs = preferences();
      for (final (from, to) in [
        ('system:dms', 'system:dms'),
        ('missing', 'system:dms'),
        ('system:dms', 'missing'),
      ]) {
        expect(
          sidebarSectionReorderUpdates(
            preferences: prefs,
            fromId: from,
            toId: to,
          ),
          isNull,
          reason: '$from -> $to',
        );
      }
    });
  });

  group('mounted sidebar', () {
    Future<(WorkspaceController, List<Object?>)> setup(
      WidgetTester tester,
      Map<String, dynamic> prefs, {
      List<RaftChannel>? rowChannels,
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.loading = false;
      w.messageDomain.ledger.switchServer('s1');
      w.channels =
          rowChannels ?? [channel('c1', 'general'), channel('c2', 'random')];
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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (w, patches);
    }

    Finder row(String id) => find.byKey(ValueKey('sidebar-channel-$id'));

    /// Long press [from], then drag it onto [onto] in small steps.
    Future<void> longPressDrag(
      WidgetTester tester,
      Finder from,
      Finder onto,
    ) async {
      final start = tester.getCenter(from), end = tester.getCenter(onto);
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      final delta = end - start;
      final offset = delta + Offset(0, delta.dy.sign * 8);
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(start + offset * (i / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    final sectionPrefs = {
      'customSections': [
        {'id': 's1', 'name': 'Launch', 'sortMode': 'manual'},
      ],
      'sectionPlacements': [
        {'kind': 'channel', 'id': 'c1', 'sectionId': 's1', 'position': 0},
        {'kind': 'channel', 'id': 'c2', 'sectionId': 's1', 'position': 1},
      ],
      'sectionsVersion': 3,
    };

    testWidgets('custom section: a long-press drag patches the placements', (
      tester,
    ) async {
      final (w, patches) = await setup(tester, sectionPrefs);
      expect(
        tester.getCenter(row('c1')).dy,
        lessThan(tester.getCenter(row('c2')).dy),
      );
      await longPressDrag(tester, row('c2'), row('c1'));
      expect(patches.single, {
        'sectionPlacements': [
          {'kind': 'channel', 'id': 'c2', 'sectionId': 's1', 'position': 0},
          {'kind': 'channel', 'id': 'c1', 'sectionId': 's1', 'position': 1},
        ],
        'sectionsVersion': 3,
      });
      // The optimistic order moves the row at once.
      expect(
        tester.getCenter(row('c2')).dy,
        lessThan(tester.getCenter(row('c1')).dy),
      );
      expect(find.text('Move to section'), findsNothing);
      expect(w.sidebarOrder['sectionPlacements'], hasLength(2));
    });

    testWidgets('pinned: a long-press drag patches the pinned list', (
      tester,
    ) async {
      final (_, patches) = await setup(tester, {
        'pinned': [
          {'kind': 'channel', 'id': 'c1'},
          {'kind': 'human', 'id': 'u3'},
        ],
      });
      await longPressDrag(tester, row('d2'), row('c1'));
      expect(patches.single, {
        'pinned': [
          {'kind': 'human', 'id': 'u3'},
          {'kind': 'channel', 'id': 'c1'},
        ],
      });
    });

    testWidgets('channels: a manual group patches channelOrder', (
      tester,
    ) async {
      final (_, patches) = await setup(tester, {
        'channelOrder': ['c1', 'c2'],
      });
      await longPressDrag(tester, row('c1'), row('c2'));
      expect(patches.single, {
        'channelOrder': ['c2', 'c1'],
      });
    });

    testWidgets('a sorted group takes no reorder of its own rows', (
      tester,
    ) async {
      final (_, patches) = await setup(tester, {
        'dmOrder': ['d1', 'd2'],
        'dmSortMode': 'az',
      });
      // The rows can be lifted (to leave for Pinned or a section) but the
      // sorted group is no destination for them.
      expect(find.byType(SidebarDragRow), findsWidgets);
      await longPressDrag(tester, row('d2'), row('d1'));
      expect(patches, isEmpty);
      expect(
        tester.getCenter(row('d1')).dy,
        lessThan(tester.getCenter(row('d2')).dy),
      );
      // The long press still opens the row menu directly.
      await tester.longPress(row('d2'));
      await tester.pumpAndSettle();
      expect(find.text('Close Chat'), findsOneWidget);
      expect(patches, isEmpty);
    });

    Finder header(String id) => find.byKey(ValueKey('sidebar-section-$id'));
    double top(WidgetTester tester, String id) =>
        tester.getTopLeft(header(id)).dy;

    testWidgets('system sections: a long-press drag patches sectionOrder', (
      tester,
    ) async {
      final (w, patches) = await setup(tester, {'sectionsVersion': 3});
      expect(
        top(tester, 'system:channels'),
        lessThan(top(tester, 'system:dms')),
      );
      await longPressDrag(
        tester,
        header('system:dms'),
        header('system:channels'),
      );
      expect(patches.single, {
        'sectionOrder': [
          'system:pinned',
          'system:joint',
          'system:dms',
          'system:channels',
        ],
        'sectionsVersion': 3,
      });
      // The whole section moves at once, rows included.
      expect(
        top(tester, 'system:dms'),
        lessThan(top(tester, 'system:channels')),
      );
      expect(
        tester.getCenter(row('d1')).dy,
        lessThan(top(tester, 'system:channels')),
      );
      expect(w.sidebarOrder['sectionOrder'], hasLength(4));
      expect(find.text('Hide empty sections'), findsNothing);
    });

    testWidgets('custom section: its header drags above a system section', (
      tester,
    ) async {
      final (_, patches) = await setup(tester, sectionPrefs);
      expect(top(tester, 'system:pinned'), lessThan(top(tester, 's1')));
      await longPressDrag(tester, header('s1'), header('system:pinned'));
      expect(patches.single, {
        'sectionOrder': [
          's1',
          'system:pinned',
          'system:joint',
          'system:channels',
          'system:dms',
        ],
        'sectionsVersion': 3,
      });
      expect(top(tester, 's1'), lessThan(top(tester, 'system:pinned')));
    });

    testWidgets('a dragged header shows its card and the drop indicator', (
      tester,
    ) async {
      final (_, patches) = await setup(tester, {'sectionsVersion': 3});
      final start = tester.getCenter(header('system:dms'));
      final end = tester.getCenter(header('system:channels'));
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(start + (end - start) * (i / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // The source stays in place, faded; the card follows the pointer.
      expect(
        tester
            .widget<Opacity>(
              find
                  .descendant(
                    of: find.byKey(
                      const ValueKey('sidebar-section-drag-system:dms'),
                    ),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        lessThan(1),
      );
      expect(find.text('DIRECT MESSAGES'), findsNWidgets(2));
      // The target marks the edge the section will land on.
      final drop = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('sidebar-section-drop-system:channels')),
      );
      expect((drop.decoration as BoxDecoration).border, isNotNull);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('DIRECT MESSAGES'), findsOneWidget);
      expect(patches, hasLength(1));
    });

    testWidgets('section header: right click and a long press in place open '
        'the menu, a tap still collapses it', (tester) async {
      final (_, patches) = await setup(tester, {'sectionsVersion': 3});
      await tester.tapAt(
        tester.getCenter(header('system:channels')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      expect(find.text('Hide empty sections'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Hide empty sections'), findsNothing);

      await tester.longPress(header('system:channels'));
      await tester.pumpAndSettle();
      expect(find.text('Hide empty sections'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(row('c1'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('sidebar-disclosure-system:channels')),
      );
      await tester.pumpAndSettle();
      expect(row('c1'), findsNothing);
      expect(patches, isEmpty);
    });

    testWidgets('reorderable row: tap opens, right click and a long press '
        'in place open the menu', (tester) async {
      final (w, patches) = await setup(tester, sectionPrefs);
      await tester.tapAt(
        tester.getCenter(row('c2')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      expect(find.text('Move to section'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Move to section'), findsNothing);

      await tester.longPress(row('c2'));
      await tester.pumpAndSettle();
      expect(find.text('Move to section'), findsOneWidget);
      expect(patches, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(w.location.entityId, isNot('c2'));
      await tester.tap(row('c2'));
      await tester.pumpAndSettle();
      expect(w.location.entityId, 'c2');
      expect(find.text('Move to section'), findsNothing);
      expect(patches, isEmpty);
    });

    Future<void> nudge(WidgetTester tester, Finder target) async {
      final start = tester.getCenter(target);
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveTo(start + const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('a short move of a row opens the menu and does not reorder', (
      tester,
    ) async {
      final (_, patches) = await setup(tester, sectionPrefs);
      await nudge(tester, row('c2'));
      expect(patches, isEmpty);
      expect(find.text('Move to section'), findsOneWidget);
    });

    testWidgets(
      'a short move of a section header opens the menu and does not reorder',
      (tester) async {
        final (_, patches) = await setup(tester, {'sectionsVersion': 3});
        await nudge(tester, header('system:channels'));
        expect(patches, isEmpty);
        expect(find.text('Hide empty sections'), findsOneWidget);
      },
    );

    testWidgets('the lifted section card counts the rows on screen', (
      tester,
    ) async {
      final (_, patches) = await setup(
        tester,
        {'sectionsVersion': 3},
        rowChannels: [
          channel('c1', 'general'),
          channel('c2', 'random', joined: false),
        ],
      );
      await tester.tapAt(
        tester.getCenter(header('system:channels')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show joined channels only'));
      await tester.pumpAndSettle();
      expect(row('c2'), findsNothing);
      final start = tester.getCenter(header('system:channels'));
      final gesture = await tester.startGesture(start);
      try {
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveTo(start + const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 16));
        String? countBeside(Element label) {
          String? count;
          label.visitAncestorElements((ancestor) {
            if (ancestor.widget is! Row) return true;
            ancestor.visitChildElements((child) {
              void walk(Element node) {
                final widget = node.widget;
                if (widget is Text &&
                    widget.data != null &&
                    widget.data != 'CHANNELS') {
                  count = widget.data;
                }
                node.visitChildElements(walk);
              }

              walk(child);
            });
            return false;
          });
          return count;
        }

        final labels = find.text('CHANNELS').evaluate().toList();
        expect(labels, hasLength(2));
        expect(labels.map(countBeside), ['1', '1']);
      } finally {
        await gesture.moveTo(start);
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();
        await tester.pumpAndSettle();
      }
      expect(patches, isEmpty);
    });
  });
}
