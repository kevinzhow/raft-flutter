import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/rail_side_preference.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_flutter/platform/system_gesture_exclusion.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_services_fixture.dart';

/// Phone layout navigation placement: the bottom tab bar on ordinary tall
/// phones, the desktop left rail on wide / short windows (wide foldable inner
/// screens, landscape phones, 600-767 dp). The page stack, routes and dialogs
/// stay the phone ones; only the navigation chrome swaps.

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final channelRows = [
    for (var i = 0; i < 30; i++)
      RaftChannel({'id': 'c$i', 'name': 'design-$i', 'joined': true}),
  ];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'}),
  ];
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? [] : channelRows;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {
    'messages': [
      for (var i = 1; i <= 40; i++)
        {
          'id': 'm$i',
          'channelId': id,
          'serverId': 's',
          'seq': '$i',
          'content': 'Public fixture message $i',
          'senderId': 'other',
          'senderType': 'user',
          'createdAt': '2026-10-08T00:00:${i.toString().padLeft(2, '0')}Z',
        },
    ],
    'threadSummariesByParentMessageId': {},
  };
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/agents') return [];
    if (path.startsWith('/channels/c') && !path.contains('/', 10)) {
      final id = path.split('/').last;
      return {'id': id, 'serverId': 's', 'name': id, 'joined': true};
    }
    if (path == '/channels/unread') {
      return {
        'channels': {'c0': 1},
      };
    }
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path == '/auth/identities') {
      return {'passwordConfigured': true, 'identities': []};
    }
    if (path == '/auth/providers') return {'providers': []};
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '40', 'readStateVersion': '1'};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }
}

enum _Chrome { bottom, rail, desktop }

class _Case {
  const _Case(this.width, this.height, this.chrome);
  final double width, height;
  final _Chrome chrome;
  Size get size => Size(width, height);
  @override
  String toString() => '${width.round()}x${height.round()}';
}

const _cases = [
  _Case(390, 844, _Chrome.bottom),
  _Case(430, 932, _Chrome.bottom),
  _Case(440, 707, _Chrome.rail),
  _Case(528, 848, _Chrome.rail),
  _Case(707, 440, _Chrome.rail),
  _Case(600, 960, _Chrome.rail),
  _Case(669, 951, _Chrome.rail),
  _Case(704, 933, _Chrome.rail),
  _Case(760, 840, _Chrome.rail),
  _Case(767, 1000, _Chrome.rail),
  _Case(768, 1024, _Chrome.desktop),
];

final _bar = find.byKey(const Key('workspace-mobile-navigation'));
Finder _rail(String id) => find.byKey(ValueKey('rail-$id'));

/// The hit target a finger gets: the control, or its [RaftTouchTarget]
/// expansion (touch density extends the target without inflating layout).
Size _hit(WidgetTester tester, Finder f) {
  final size = tester.getSize(f);
  final inner = find.descendant(of: f, matching: find.byType(RaftTouchTarget));
  final outer = find.ancestor(of: f, matching: find.byType(RaftTouchTarget));
  final target = inner.evaluate().isNotEmpty ? inner : outer;
  if (target.evaluate().isEmpty) return size;
  final min = tester.widget<RaftTouchTarget>(target.first).minSize;
  return Size(
    size.width < min.width ? min.width : size.width,
    size.height < min.height ? min.height : size.height,
  );
}

const _railIds = [
  'workspace',
  'search',
  'chat',
  'activity',
  'tasks',
  'members',
  'computers',
  'settings',
];

class _Rig {
  _Rig(
    this.tester, {
    this.rtl = false,
    this.textScale = 1.0,
    this.themeId = raftThemePackId,
    required this.size,
    this.padding = const FakeViewPadding(top: 24, bottom: 24),
    this.displayFeatures = const [],
    this.railSide,
  });
  final RailSideStore? railSide;
  final List<DisplayFeature> displayFeatures;
  final WidgetTester tester;
  final bool rtl;
  final double textScale;
  final String themeId;
  Size size;
  final FakeViewPadding padding;
  late final _Client c;
  late final WorkspaceController w;

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> resize(Size next) async {
    size = next;
    tester.view.physicalSize = next;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> start() async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    tester.view.displayFeatures = displayFeatures;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    if (railSide != null) addTearDown(railSide!.dispose);
    c = _Client()..selectServer('s');
    w = WorkspaceController(c, mobileNavigation: size.width < 768);
    await tester.runAsync(w.bootstrap);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(themeId)),
        builder: (context, child) => Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            railSide: railSide,
            appearance: RaftAppearance(mode: ThemeMode.light, themeId: themeId),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await settle();
  }

  Future<void> tapRail(String id) async {
    await tester.tap(_rail(id));
    await settle();
  }
}

void main() {
  group('placement matrix', () {
    for (final c in _cases) {
      testWidgets('$c LTR 1.0x', (tester) async {
        final r = _Rig(tester, size: c.size);
        await r.start();
        expect(tester.takeException(), isNull);
        switch (c.chrome) {
          case _Chrome.bottom:
            expect(_bar, findsOneWidget);
            expect(_rail('chat'), findsNothing);
            expect(_rail('settings'), findsNothing);
          case _Chrome.rail:
            expect(_bar, findsNothing);
            for (final id in _railIds) {
              expect(_rail(id), findsOneWidget, reason: 'rail-$id');
            }
            // Leading edge, clear of the content region.
            final rect = tester.getRect(
              find.byKey(const Key('workspace-sidebar')),
            );
            final railRect = tester.getRect(_rail('chat'));
            expect(railRect.left, greaterThanOrEqualTo(0));
            expect(railRect.right, lessThanOrEqualTo(rect.left + .5));
            for (final id in _railIds) {
              final size = _hit(tester, _rail(id));
              expect(
                size.shortestSide,
                greaterThanOrEqualTo(48),
                reason: 'rail-$id hit target',
              );
            }
          case _Chrome.desktop:
            expect(_bar, findsNothing);
            expect(_rail('chat'), findsOneWidget);
        }
      });
    }

    for (final c in [_cases[0], _cases[2], _cases[4], _cases[9]]) {
      testWidgets('$c RTL 2.0x text', (tester) async {
        final r = _Rig(tester, size: c.size, rtl: true, textScale: 2.0);
        await r.start();
        expect(tester.takeException(), isNull);
        if (c.chrome == _Chrome.rail) {
          expect(_bar, findsNothing);
          // The rail sits on the leading (right) edge.
          final rail = tester.getRect(find.byType(RaftWorkspaceRail));
          expect(rail.right, c.width);
          expect(rail.left, greaterThan(c.width / 2));
          expect(
            tester.getRect(find.byKey(const Key('workspace-sidebar'))).right,
            lessThanOrEqualTo(rail.left + .5),
          );
          for (final id in _railIds) {
            expect(
              _hit(tester, _rail(id)).shortestSide,
              greaterThanOrEqualTo(48),
              reason: 'rail-$id at 2.0x',
            );
          }
        } else {
          expect(_bar, findsOneWidget);
        }
      });
    }
  });

  group('rail behaviour', () {
    testWidgets('rail routes through the phone navigation', (tester) async {
      final r = _Rig(tester, size: const Size(440, 707));
      await r.start();
      expect(r.w.location.route, RaftRoute.home);
      await r.tapRail('tasks');
      expect(r.w.location.route, RaftRoute.tasks);
      // A root tab: the rail stays; the chat entry now carries the unread
      // attention dot the desktop rail shows for an inactive Chat.
      expect(_rail('chat'), findsOneWidget);
      expect(find.byType(RaftRailAttention), findsWidgets);
      await r.tapRail('activity');
      expect(r.w.location.route, RaftRoute.activity);
      expect(_rail('chat'), findsOneWidget);
      await r.tapRail('members');
      expect(r.w.location.route, RaftRoute.members);
      await r.tapRail('computers');
      expect(r.w.location.route, RaftRoute.computers);
      expect(_rail('chat'), findsOneWidget);
      // Its header sits beside the rail, not above it: the rail starts at
      // the top of the safe area like on every other root page.
      expect(
        tester.getRect(find.byType(RaftWorkspaceRail)).top,
        closeTo(24, .5),
      );
      expect(find.byKey(const Key('mobile-detail-back')), findsNothing);
      // Settings: the rail stays and the Bottom bar row is not offered
      // (and neither is the bottom-bar-only Computers shortcut).
      await r.tapRail('settings');
      expect(r.w.location.route, RaftRoute.settings);
      expect(
        find.byKey(const ValueKey('workspace-settings-nav-appearance')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workspace-settings-nav-bottom-bar')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('workspace-settings-nav-computers')),
        findsNothing,
      );
      await r.tapRail('chat');
      expect(r.w.location.route, RaftRoute.home);
      // Search is the Home list's pushed page: a full-width page.
      await r.tapRail('search');
      expect(r.w.location.route, RaftRoute.search);
      expect(_rail('chat'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('short landscape rail scrolls to every entry', (tester) async {
      final r = _Rig(tester, size: const Size(707, 440));
      await r.start();
      final rail = find.descendant(
        of: find.byType(RaftWorkspaceRail),
        matching: find.byType(Scrollable),
      );
      for (final id in ['computers', 'settings']) {
        await tester.scrollUntilVisible(_rail(id), 60, scrollable: rail);
        await tester.pump();
        expect(
          tester.getRect(_rail(id)).bottom,
          lessThanOrEqualTo(440),
          reason: 'rail-$id on screen',
        );
      }
      await tester.tap(_rail('settings'));
      await r.settle();
      expect(r.w.location.route, RaftRoute.settings);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bottom bar keeps its Settings Bottom bar row', (tester) async {
      final r = _Rig(tester, size: const Size(390, 844));
      await r.start();
      await tester.tap(find.byKey(const Key('mobile-tab-settings')));
      await r.settle();
      expect(
        find.byKey(const ValueKey('workspace-settings-nav-bottom-bar')),
        findsOneWidget,
      );
    });

    testWidgets('live-activity-free rail keeps the system inset', (
      tester,
    ) async {
      // Landscape with a side cutout / navigation bar: the rail paints under
      // the inset and keeps its buttons clear of it; the content starts after
      // the rail.
      final r = _Rig(
        tester,
        size: const Size(707, 440),
        padding: const FakeViewPadding(left: 40, top: 0, bottom: 20),
      );
      await r.start();
      expect(tester.takeException(), isNull);
      final chat = tester.getRect(_rail('chat'));
      expect(chat.left, greaterThanOrEqualTo(40));
      expect(
        _hit(tester, _rail('chat')).shortestSide,
        greaterThanOrEqualTo(48),
      );
      final list = tester.getRect(find.byKey(const Key('workspace-sidebar')));
      expect(list.left, greaterThan(chat.right - 1));
    });
  });

  group('placement switch keeps the page', () {
    testWidgets('Home list keeps its element and scroll offset', (
      tester,
    ) async {
      final r = _Rig(tester, size: const Size(390, 844));
      await r.start();
      final list = find.byKey(const Key('workspace-sidebar'));
      final element = identityHashCode(tester.element(list));
      await tester.drag(list, const Offset(0, -400));
      await r.settle();
      double offset() => tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position
          .pixels;
      final before = offset();
      expect(before, greaterThan(100));
      final pages = identityHashCode(
        tester.state(find.byType(MobileWorkspacePages)),
      );
      for (final next in [
        const Size(707, 440),
        const Size(390, 844),
        const Size(440, 707),
        const Size(430, 932),
      ]) {
        await r.resize(next);
        expect(tester.takeException(), isNull, reason: '$next');
        expect(
          _bar.evaluate().isNotEmpty,
          next.width < 600 && next.height / next.width >= 1.75,
          reason: '$next bar',
        );
        expect(identityHashCode(tester.element(list)), element);
        expect(
          identityHashCode(tester.state(find.byType(MobileWorkspacePages))),
          pages,
        );
        expect(offset(), closeTo(before, .5), reason: '$next offset');
      }
    });

    testWidgets('channel page keeps scroll offset and draft', (tester) async {
      final r = _Rig(tester, size: const Size(440, 707));
      await r.start();
      await r.w.selectChannel(r.w.channels.first);
      await r.settle();
      final composer = find.descendant(
        of: find.byType(RaftComposer),
        matching: find.byType(EditableText),
      );
      await tester.enterText(composer.first, 'half-written reply');
      await tester.pump();
      final scrollables = find.descendant(
        of: find.byType(RaftChatView),
        matching: find.byType(Scrollable),
      );
      // The message timeline is the tallest scrollable of the page.
      final timeline = scrollables
          .evaluate()
          .map((e) => find.byElementPredicate((x) => x == e))
          .reduce(
            (a, b) =>
                tester.getSize(a).height >= tester.getSize(b).height ? a : b,
          );
      double offset() =>
          tester.state<ScrollableState>(timeline).position.pixels;
      final initial = offset();
      await tester.drag(timeline, const Offset(0, 500));
      await r.settle();
      final before = offset();
      expect(
        (before - initial).abs(),
        greaterThan(50),
        reason: 'the drag scrolled the timeline',
      );
      final editor = identityHashCode(tester.element(composer.first));
      final page = identityHashCode(
        tester.element(find.byType(RaftChatView).first),
      );
      final location = r.w.location.uri;
      for (final next in [
        const Size(707, 440),
        const Size(390, 844),
        const Size(669, 951),
        const Size(440, 707),
      ]) {
        await r.resize(next);
        expect(tester.takeException(), isNull, reason: '$next');
        expect(r.w.location.uri, location, reason: '$next stays on page');
        expect(identityHashCode(tester.element(composer.first)), editor);
        expect(
          identityHashCode(tester.element(find.byType(RaftChatView).first)),
          page,
        );
        expect(
          tester.widget<EditableText>(composer.first).controller.text,
          'half-written reply',
          reason: '$next draft',
        );
        expect(offset(), closeTo(before, .5), reason: '$next offset');
      }
    });
  });

  group('display features (fold / hinge)', () {
    testWidgets('a vertical hinge mid-window: rail stays leading, '
        'clear of the hinge; placement is size based', (tester) async {
      // A 4:3 wide foldable half-opened: the hinge splits 760 dp in two.
      const hinge = Rect.fromLTRB(375, 0, 385, 840);
      final r = _Rig(
        tester,
        size: const Size(760, 840),
        displayFeatures: [
          DisplayFeature(
            bounds: hinge,
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );
      await r.start();
      expect(tester.takeException(), isNull);
      expect(_bar, findsNothing);
      final rail = tester.getRect(find.byType(RaftWorkspaceRail));
      expect(rail.left, 0);
      expect(rail.overlaps(hinge), isFalse, reason: 'rail clear of hinge');
      for (final id in _railIds) {
        expect(
          tester.getRect(_rail(id)).overlaps(hinge),
          isFalse,
          reason: 'rail-$id clear of hinge',
        );
      }
      debugPrint(
        'hinge $hinge: rail ${rail.left}..${rail.right}, '
        'content starts at '
        '${tester.getRect(find.byKey(const Key('workspace-sidebar'))).left}',
      );
    });

    testWidgets('a separating fold inside the rail strip keeps the '
        'bottom bar', (tester) async {
      final r = _Rig(
        tester,
        size: const Size(760, 840),
        displayFeatures: [
          DisplayFeature(
            bounds: const Rect.fromLTRB(20, 0, 30, 840),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );
      await r.start();
      expect(_bar, findsOneWidget);
      expect(_rail('chat'), findsNothing);
    });

    testWidgets('a flat fold or cutout never changes placement', (
      tester,
    ) async {
      final r = _Rig(
        tester,
        size: const Size(440, 707),
        displayFeatures: [
          DisplayFeature(
            bounds: const Rect.fromLTRB(20, 0, 30, 707),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
          ),
          DisplayFeature(
            bounds: const Rect.fromLTRB(0, 0, 40, 40),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );
      await r.start();
      expect(_bar, findsNothing);
      expect(_rail('chat'), findsOneWidget);
    });
  });

  group('rail side (left / right)', () {
    const channel = MethodChannel('app.raft/gesture-exclusion');
    late List<MethodCall> calls;
    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      SystemGestureExclusion.instance = SystemGestureExclusion(
        channel: channel,
        supported: true,
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      SystemGestureExclusion.instance = SystemGestureExclusion();
    });

    Rect railRect(WidgetTester t) => t.getRect(find.byType(RaftWorkspaceRail));
    Rect contentRect(WidgetTester t) =>
        t.getRect(find.byKey(const Key('workspace-sidebar')));
    List<MethodCall> sets() => [
      for (final c in calls)
        if (c.method == 'set') c,
    ];

    for (final size in const [Size(440, 707), Size(707, 440)]) {
      for (final rtl in [false, true]) {
        for (final end in [false, true]) {
          testWidgets('${size.width.round()}x${size.height.round()} '
              '${rtl ? 'RTL' : 'LTR'} ${end ? 'end' : 'start'}', (
            tester,
          ) async {
            final store = RailSideStore();
            if (end) store.update(RaftRailSide.end);
            final r = _Rig(
              tester,
              size: size,
              rtl: rtl,
              railSide: store,
              padding: const FakeViewPadding(
                left: 30,
                right: 36,
                top: 24,
                bottom: 24,
              ),
            );
            await r.start();
            expect(tester.takeException(), isNull);
            expect(_bar, findsNothing);
            final onRight = end != rtl;
            final rail = railRect(tester);
            final content = contentRect(tester);
            if (onRight) {
              // On the right edge, painting under the trailing inset.
              expect(rail.right, size.width);
              expect(content.right, lessThanOrEqualTo(rail.left + .5));
              expect(content.left, greaterThanOrEqualTo(30));
            } else {
              expect(rail.left, 0);
              expect(content.left, greaterThanOrEqualTo(rail.right - .5));
              expect(content.right, lessThanOrEqualTo(size.width - 36));
            }
            // Buttons stay clear of the system inset on their side.
            final chat = tester.getRect(_rail('chat'));
            if (onRight) {
              expect(chat.right, lessThanOrEqualTo(size.width - 36 + .5));
            } else {
              expect(chat.left, greaterThanOrEqualTo(30 - .5));
            }
            expect(_hit(tester, _rail('chat')).shortestSide, 48);
            // The gesture exclusion belongs to a rail on the right edge.
            final excluded = sets();
            if (onRight) {
              expect(excluded, hasLength(1));
              final raw = (excluded.single.arguments as Map)['rects'] as List;
              final rect = raw.single as List;
              expect(rect[2], size.width, reason: 'to the window edge');
              expect(rect[3] - rect[1], lessThanOrEqualTo(200));
              expect(rect[0], greaterThanOrEqualTo(size.width - 100));
              // It covers the destination buttons it protects.
              expect(rect[1], lessThanOrEqualTo(chat.top));
            } else {
              expect(excluded, isEmpty);
            }
          });
        }
      }
    }

    testWidgets('exclusion follows side and visibility', (tester) async {
      final store = RailSideStore()..update(RaftRailSide.end);
      final r = _Rig(tester, size: const Size(440, 707), railSide: store);
      await r.start();
      expect(sets(), hasLength(1));
      // Pushing a page covers the rail: the back gesture is free again.
      await r.w.selectChannel(r.w.channels.first);
      await r.settle();
      expect(calls.last.method, 'clear');
      // Back: excluded again. Then the left side: cleared for good.
      await tester.binding.handlePopRoute();
      await r.settle();
      expect(calls.last.method, 'set');
      store.update(RaftRailSide.start);
      await r.settle();
      expect(calls.last.method, 'clear');
      // Resize keeps the rect inside the 200 dp cap.
      store.update(RaftRailSide.end);
      await r.resize(const Size(707, 440));
      await r.settle();
      final rect =
          ((calls.last.arguments as Map)['rects'] as List).single as List;
      expect(rect[3] - rect[1], lessThanOrEqualTo(200));
      expect(rect[2], 707);
    });

    testWidgets('Appearance offers the choice only where the rail can appear', (
      tester,
    ) async {
      Future<_Rig> open(Size size, {bool rtl = false}) async {
        final r = _Rig(tester, size: size, rtl: rtl, railSide: RailSideStore());
        await r.start();
        await tester.tap(
          find.byKey(
            size.width < 768 && size.height / size.width >= 1.75
                ? const Key('mobile-tab-settings')
                : _rail('settings').evaluate().isNotEmpty
                ? const ValueKey('rail-settings')
                : const Key('rail-settings'),
          ),
        );
        await r.settle();
        await tester.tap(
          find.byKey(const ValueKey('workspace-settings-nav-appearance')),
        );
        await r.settle();
        return r;
      }

      final choice = find.byKey(const ValueKey('appearance-rail-side'));
      // Rail window: the row is there, Left / Right, and it moves the rail.
      final r = await open(const Size(440, 707));
      await tester.ensureVisible(choice);
      await tester.pump();
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
      await tester.tap(find.text('Right'));
      await r.settle();
      expect(r.railSide!.side, RaftRailSide.end);
      // The detail page has no rail; back on the Settings root it is right.
      await tester.binding.handlePopRoute();
      await r.settle();
      expect(railRect(tester).right, 440);
      expect(railRect(tester).left, greaterThan(300));
    });

    Future<void> openAppearance(WidgetTester tester, _Rig r) async {
      await tester.tap(
        find.byKey(
          r.size.width < 768 && r.size.height / r.size.width >= 1.75
              ? const Key('mobile-tab-settings')
              : const Key('rail-settings'),
        ),
      );
      await r.settle();
      await tester.tap(
        find.byKey(const ValueKey('workspace-settings-nav-appearance')),
      );
      await r.settle();
    }

    final choice = find.byKey(const ValueKey('appearance-rail-side'));
    const description = 'Applies when the screen is wide or in landscape';

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final size in const [
        Size(390, 844),
        Size(440, 707),
        Size(880, 1000),
      ]) {
        testWidgets('touch platform $platform always offers the choice at '
            '${size.width.round()}x${size.height.round()}', (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          try {
            final r = _Rig(tester, size: size, railSide: RailSideStore());
            await r.start();
            await openAppearance(tester, r);
            await tester.ensureVisible(choice);
            await tester.pump();
            expect(choice, findsOneWidget);
            expect(find.text('Navigation rail'), findsOneWidget);
            expect(find.text(description), findsOneWidget);
            expect(find.text('Left'), findsOneWidget);
            expect(find.text('Right'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }
    }

    for (final platform in [TargetPlatform.macOS, TargetPlatform.linux]) {
      testWidgets('computer $platform: no choice in the desktop layout', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          final desktop = _Rig(
            tester,
            size: const Size(880, 1000),
            railSide: RailSideStore(),
          );
          await desktop.start();
          await openAppearance(tester, desktop);
          await tester.ensureVisible(
            find.byKey(const ValueKey('appearance-hide-empty')),
          );
          expect(choice, findsNothing);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('a computer offers the choice where a narrow window shows '
        'the phone rail', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final r = _Rig(
          tester,
          size: const Size(440, 707),
          railSide: RailSideStore(),
        );
        await r.start();
        await openAppearance(tester, r);
        await tester.ensureVisible(choice);
        expect(choice, findsOneWidget);
        // A tall narrow window has no rail: nothing to choose.
        final tall = _Rig(
          tester,
          size: const Size(390, 844),
          railSide: RailSideStore(),
        );
        await tall.start();
        await openAppearance(tester, tall);
        await tester.ensureVisible(
          find.byKey(const ValueKey('appearance-hide-empty')),
        );
        expect(choice, findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('RTL shows the real visual side in the labels', (tester) async {
      final r = _Rig(
        tester,
        size: const Size(440, 707),
        rtl: true,
        railSide: RailSideStore(),
      );
      await r.start();
      await tester.tap(_rail('settings'));
      await r.settle();
      await tester.tap(
        find.byKey(const ValueKey('workspace-settings-nav-appearance')),
      );
      await r.settle();
      final choice = find.byKey(const ValueKey('appearance-rail-side'));
      await tester.ensureVisible(choice);
      await tester.pump();
      // Start in RTL is the right edge: the first (leading) option reads
      // Right, drawn on the right.
      final right = tester.getCenter(find.text('Right'));
      final left = tester.getCenter(find.text('Left'));
      expect(right.dx, greaterThan(left.dx));
      await tester.tap(find.text('Left'));
      await r.settle();
      expect(r.railSide!.side, RaftRailSide.end);
      await tester.binding.handlePopRoute();
      await r.settle();
      expect(railRect(tester).left, 0);
    });

    testWidgets('switching the side keeps the page, scroll and draft', (
      tester,
    ) async {
      final store = RailSideStore();
      final r = _Rig(tester, size: const Size(440, 707), railSide: store);
      await r.start();
      await r.w.selectChannel(r.w.channels.first);
      await r.settle();
      final composer = find.descendant(
        of: find.byType(RaftComposer),
        matching: find.byType(EditableText),
      );
      await tester.enterText(composer.first, 'half-written reply');
      await tester.pump();
      final editor = identityHashCode(tester.element(composer.first));
      final page = identityHashCode(
        tester.element(find.byType(RaftChatView).first),
      );
      final location = r.w.location.uri;
      for (final side in [
        RaftRailSide.end,
        RaftRailSide.start,
        RaftRailSide.end,
      ]) {
        store.update(side);
        await r.settle();
        expect(r.w.location.uri, location);
        expect(identityHashCode(tester.element(composer.first)), editor);
        expect(
          identityHashCode(tester.element(find.byType(RaftChatView).first)),
          page,
        );
        expect(
          tester.widget<EditableText>(composer.first).controller.text,
          'half-written reply',
        );
      }
      // Home list: scroll offset survives the side change too.
      await tester.binding.handlePopRoute();
      await r.settle();
      final list = find.byKey(const Key('workspace-sidebar'));
      final element = identityHashCode(tester.element(list));
      await tester.drag(list, const Offset(0, -400));
      await r.settle();
      double offset() => tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position
          .pixels;
      final before = offset();
      for (final side in [RaftRailSide.start, RaftRailSide.end]) {
        store.update(side);
        await r.settle();
        expect(identityHashCode(tester.element(list)), element);
        expect(offset(), closeTo(before, .5));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('menus open toward the content from a right rail', (
      tester,
    ) async {
      final store = RailSideStore()..update(RaftRailSide.end);
      final r = _Rig(tester, size: const Size(440, 707), railSide: store);
      await r.start();
      await tester.tap(_rail('workspace'));
      await r.settle();
      final menu = tester.getRect(find.byType(RaftServerMenuPanel).last);
      expect(menu.right, lessThanOrEqualTo(railRect(tester).left + .5));
      expect(menu.left, greaterThanOrEqualTo(8));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a fold in the trailing strip keeps the bottom bar, the '
        'leading side does not care', (tester) async {
      const hinge = Rect.fromLTRB(410, 0, 420, 707);
      final features = [
        DisplayFeature(
          bounds: hinge,
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ];
      final end = _Rig(
        tester,
        size: const Size(440, 707),
        displayFeatures: features,
        railSide: RailSideStore()..update(RaftRailSide.end),
      );
      await end.start();
      expect(_bar, findsOneWidget);
      expect(_rail('chat'), findsNothing);
      expect(sets(), isEmpty);
    });

    testWidgets('a fold at the other edge leaves the rail where it is', (
      tester,
    ) async {
      final r = _Rig(
        tester,
        size: const Size(440, 707),
        displayFeatures: [
          DisplayFeature(
            bounds: const Rect.fromLTRB(410, 0, 420, 707),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
        railSide: RailSideStore(),
      );
      await r.start();
      expect(_bar, findsNothing);
      expect(_rail('chat'), findsOneWidget);
      expect(railRect(tester).left, 0);
    });
  });

  group('rail side in the desktop layout', () {
    const channel = MethodChannel('app.raft/gesture-exclusion');
    late List<MethodCall> calls;
    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      SystemGestureExclusion.instance = SystemGestureExclusion(
        channel: channel,
        supported: true,
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      SystemGestureExclusion.instance = SystemGestureExclusion();
    });

    const size = Size(880, 1000);
    Rect railRect(WidgetTester t) => t.getRect(find.byType(RaftWorkspaceRail));
    Rect sidebarRect(WidgetTester t) =>
        t.getRect(find.byKey(const Key('workspace-sidebar-panel')));
    Rect chatRect(WidgetTester t) =>
        t.getRect(find.byType(ConversationPanel).first);
    Border sidebarBorder(WidgetTester t) =>
        (t
                        .widget<Container>(
                          find.byKey(const Key('workspace-sidebar-panel')),
                        )
                        .decoration!
                    as BoxDecoration)
                .border!
            as Border;

    for (final rtl in [false, true]) {
      for (final end in [false, true]) {
        testWidgets('touch ${rtl ? 'RTL' : 'LTR'} '
            '${end ? 'end' : 'start'}: the column sits on its side', (
          tester,
        ) async {
          for (final pack in raftThemeMatrix([
            raftThemePackId,
            elegantThemePackId,
          ], look: raftLookOf)) {
            final store = RailSideStore();
            if (end) store.update(RaftRailSide.end);
            final r = _Rig(
              tester,
              size: size,
              rtl: rtl,
              railSide: store,
              themeId: pack,
            );
            await r.start();
            expect(tester.takeException(), isNull);
            final onRight = end != rtl;
            final rail = railRect(tester);
            final bar = sidebarRect(tester);
            final content = chatRect(tester);
            if (onRight) {
              expect(rail.right, size.width);
              expect(bar.right, closeTo(rail.left, .5));
              expect(content.right, lessThanOrEqualTo(bar.left + .5));
              expect(content.left, 0);
              // The divider faces the content.
              expect(sidebarBorder(tester).left.width, greaterThan(0));
              expect(sidebarBorder(tester).right, BorderSide.none);
            } else {
              expect(rail.left, 0);
              expect(bar.left, closeTo(rail.right, .5));
              expect(content.left, greaterThanOrEqualTo(bar.right - .5));
              expect(content.right, size.width);
              expect(sidebarBorder(tester).right.width, greaterThan(0));
              expect(sidebarBorder(tester).left, BorderSide.none);
            }
            // Rail and sidebar are one unit, full height, same width as ever.
            expect(bar.width, 240);
            expect(rail.top, bar.top);
            expect(rail.height, bar.height);
            // Source puts workspace switching in the top bar. Keep the frozen
            // rail-menu direction checks as well, using its actual Elegant host.
            final headerMenu = pack == raftThemePackId;
            final trigger = headerMenu
                ? find.byKey(const Key('topbar-workspace'))
                : _rail('workspace');
            expect(trigger, findsOneWidget);
            final anchor = tester.getRect(trigger);
            await tester.tap(trigger);
            await r.settle();
            final menu = tester.getRect(find.byType(RaftServerMenuPanel).last);
            if (headerMenu) {
              expect(_rail('workspace'), findsNothing);
              expect(menu.top, greaterThanOrEqualTo(anchor.bottom));
              expect(menu.left, greaterThanOrEqualTo(8));
              expect(menu.right, lessThanOrEqualTo(size.width - 8));
            } else if (onRight) {
              expect(menu.right, lessThanOrEqualTo(rail.left + .5));
            } else {
              expect(menu.left, greaterThanOrEqualTo(rail.right - .5));
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        });
      }
    }

    testWidgets('a computer keeps the column on the left whatever the side', (
      tester,
    ) async {
      try {
        for (final platform in [
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux,
        ]) {
          debugDefaultTargetPlatformOverride = platform;
          final r = _Rig(
            tester,
            size: size,
            railSide: RailSideStore()..update(RaftRailSide.end),
          );
          await r.start();
          expect(railRect(tester).left, 0, reason: '$platform');
          expect(sidebarRect(tester).left, closeTo(railRect(tester).right, .5));
          expect(chatRect(tester).right, size.width);
          await tester.pumpWidget(const SizedBox());
          calls.clear();
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('switching the setting moves the column live and keeps the '
        'page and draft', (tester) async {
      final store = RailSideStore();
      final r = _Rig(tester, size: size, railSide: store);
      await r.start();
      await r.w.selectChannel(r.w.channels.first);
      await r.settle();
      final composer = find.descendant(
        of: find.byType(RaftComposer),
        matching: find.byType(EditableText),
      );
      await tester.enterText(composer.first, 'half-written reply');
      await tester.pump();
      final editor = identityHashCode(tester.element(composer.first));
      final sidebar = identityHashCode(
        tester.element(find.byKey(const Key('workspace-sidebar'))),
      );
      expect(railRect(tester).left, 0);
      for (final side in [
        RaftRailSide.end,
        RaftRailSide.start,
        RaftRailSide.end,
      ]) {
        store.update(side);
        await r.settle();
        expect(
          railRect(tester).left,
          side == RaftRailSide.end ? size.width - railRect(tester).width : 0,
        );
        expect(identityHashCode(tester.element(composer.first)), editor);
        expect(
          identityHashCode(
            tester.element(find.byKey(const Key('workspace-sidebar'))),
          ),
          sidebar,
        );
        expect(
          tester.widget<EditableText>(composer.first).controller.text,
          'half-written reply',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sidebar handle is on the content side and drags toward '
        'the content to grow', (tester) async {
      final r = _Rig(
        tester,
        size: size,
        railSide: RailSideStore()..update(RaftRailSide.end),
      );
      await r.start();
      final handle = find.byKey(const Key('sidebar-resize-handle'));
      expect(
        tester.getCenter(handle).dx,
        closeTo(sidebarRect(tester).left, .5),
      );
      final before = sidebarRect(tester).width;
      await tester.drag(handle, const Offset(-40, 0));
      await r.settle();
      expect(sidebarRect(tester).width, closeTo(before + 40, 1));
      expect(sidebarRect(tester).right, closeTo(railRect(tester).left, .5));
      // Left side: the handle is on the right edge of the sidebar.
      final left = _Rig(tester, size: size, railSide: RailSideStore());
      await left.start();
      expect(
        tester.getCenter(handle).dx,
        closeTo(sidebarRect(tester).right, .5),
      );
    });

    testWidgets('Android keeps the back swipe off a right column, capped', (
      tester,
    ) async {
      final store = RailSideStore();
      final r = _Rig(tester, size: size, railSide: store);
      await r.start();
      expect(calls.where((c) => c.method == 'set'), isEmpty);
      store.update(RaftRailSide.end);
      await r.settle();
      final sets = calls.where((c) => c.method == 'set').toList();
      expect(sets, isNotEmpty);
      final rect =
          ((sets.last.arguments as Map)['rects'] as List).single as List;
      expect(rect[2], size.width, reason: 'to the window edge');
      expect(rect[3] - rect[1], lessThanOrEqualTo(200));
      expect(rect[0], greaterThanOrEqualTo(size.width - 100));
      store.update(RaftRailSide.start);
      await r.settle();
      expect(calls.last.method, 'clear');
    });

    testWidgets('a separating fold inside the column keeps it on the left', (
      tester,
    ) async {
      final r = _Rig(
        tester,
        size: size,
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTRB(size.width - 200, 0, size.width - 190, 1000),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
        railSide: RailSideStore()..update(RaftRailSide.end),
      );
      await r.start();
      expect(railRect(tester).left, 0);
      expect(calls.where((c) => c.method == 'set'), isEmpty);
    });

    testWidgets('a fold in the middle of the window leaves the right column', (
      tester,
    ) async {
      final r = _Rig(
        tester,
        size: size,
        displayFeatures: [
          DisplayFeature(
            bounds: const Rect.fromLTRB(435, 0, 445, 1000),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
        railSide: RailSideStore()..update(RaftRailSide.end),
      );
      await r.start();
      expect(railRect(tester).right, size.width);
    });
  });
}
