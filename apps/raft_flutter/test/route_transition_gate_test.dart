import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';
import 'package:raft_flutter/features/route_transition_gate.dart';

/// A live event: the store the pages listen to changes on every call. Pages
/// built from it count their rebuilds per route.
class _Store extends ChangeNotifier {
  int value = 0;
  void event() {
    value++;
    notifyListeners();
  }
}

class _Fixture {
  _Fixture(this.tester) {
    addTearDown(store.dispose);
  }
  final WidgetTester tester;
  final navigation = WorkspaceNavigation();
  final store = _Store();

  /// Builds per route that displayed a value it had not shown before.
  final builds = <String, int>{};
  final shown = <String, int>{};
  late StateSetter rebuild;
  var backs = 0;
  int deferred = 0;

  RaftLocation location(RaftRoute route) => RaftLocation.at(
    serverSlug: 'gate',
    route: route,
    entityId: route == RaftRoute.channel ? 'one' : null,
  );

  Future<void> pump() async {
    navigation.bind('isolated', location(RaftRoute.home));
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return MobileWorkspacePages(
              navigation: navigation,
              onBack: () => rebuild(() {
                backs++;
                backMobilePage(navigation);
              }),
              pageBuilder: (_, page) => QuietListenableBuilder(
                listenable: store,
                builder: (context, _) {
                  final name = page.route.name;
                  // Counts the builds that picked up a new event; a rebuild
                  // from the parent with nothing new is not one.
                  if (shown[name] != store.value) {
                    builds.update(name, (n) => n + 1, ifAbsent: () => 1);
                  }
                  shown[name] = store.value;
                  return Text('$name ${store.value}');
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> push() async {
    rebuild(() => navigation.navigate(location(RaftRoute.channel)));
    await tester.pump();
  }

  Future<void> gesture(String method, [double? progress]) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(
          method,
          progress == null
              ? null
              : <String, dynamic>{
                  'touchOffset': <double>[100, 300],
                  'progress': progress,
                  'swipeEdge': 0,
                },
        ),
      ),
      (_) {},
    );
    await tester.pump();
  }

  RouteTransitionGate get gate => RouteTransitionGate.of(
    ModalRoute.of(tester.element(find.byType(Text).first)),
  )!;

  /// Events during the next [frames] frames of 16 ms.
  Future<void> eventsWhile(int frames) async {
    for (var i = 0; i < frames; i++) {
      store.event();
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

void main() {
  testWidgets('a push holds the covered page and keeps the entering one live', (
    tester,
  ) async {
    final f = _Fixture(tester);
    await f.pump();
    final homeBefore = f.builds['home']!;
    await f.push();
    expect(f.gate.closed, isTrue);
    await f.eventsWhile(5);
    expect(f.builds['home'], homeBefore, reason: 'covered page is held');
    expect(f.shown['channel'], 5, reason: 'entering page applies each event');
    await tester.pumpAndSettle();
    expect(f.gate.closed, isFalse);
    expect(f.builds['home'], homeBefore + 1, reason: 'one rebuild at settle');
    expect(f.shown['home'], 5, reason: 'and it is current');
    // Quiet again: events apply immediately.
    f.store.event();
    await tester.pump();
    expect(f.shown['home'], 6);
  });

  testWidgets('a pop holds both pages and applies one rebuild at the end', (
    tester,
  ) async {
    final f = _Fixture(tester);
    await f.pump();
    await f.push();
    await tester.pumpAndSettle();
    final home = f.builds['home']!, channel = f.builds['channel']!;
    f.rebuild(() => backMobilePage(f.navigation));
    await tester.pump();
    await f.eventsWhile(6);
    expect(f.builds['home'], home);
    expect(f.builds['channel'], channel);
    await tester.pumpAndSettle();
    expect(f.navigation.location.route, RaftRoute.home);
    expect(f.builds['home'], home + 1);
    expect(f.shown['home'], 6);
    expect(f.gate.closed, isFalse);
  });

  for (final commit in [true, false]) {
    testWidgets(
      'predictive back ${commit ? 'commit' : 'cancel'} holds pages until it settles',
      (tester) async {
        final f = _Fixture(tester);
        await f.pump();
        await f.push();
        await tester.pumpAndSettle();
        final home = f.builds['home']!, channel = f.builds['channel']!;
        await f.gesture('startBackGesture', 0);
        await f.gesture('updateBackGestureProgress', 0.3);
        expect(f.gate.closed, isTrue);
        await f.eventsWhile(4);
        await f.gesture('updateBackGestureProgress', 0.5);
        await f.eventsWhile(4);
        expect(f.builds['home'], home, reason: 'revealed page is held');
        expect(f.builds['channel'], channel, reason: 'leaving page is held');
        await f.gesture(commit ? 'commitBackGesture' : 'cancelBackGesture');
        if (!commit) {
          expect(f.builds['channel'], channel);
        }
        await tester.pumpAndSettle();
        expect(f.gate.closed, isFalse);
        expect(f.backs, commit ? 1 : 0);
        expect(f.builds['home'], home + 1, reason: 'applied once');
        expect(f.shown['home'], 8);
        if (!commit) {
          expect(f.builds['channel'], channel + 1);
          expect(f.shown['channel'], 8);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a transition that never settles releases after the timeout', (
    tester,
  ) async {
    final f = _Fixture(tester);
    await f.pump();
    await f.push();
    await tester.pumpAndSettle();
    final home = f.builds['home']!;
    await f.gesture('startBackGesture', 0);
    await f.gesture('updateBackGestureProgress', 0.4);
    f.store.event();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(f.gate.closed, isTrue);
    expect(f.builds['home'], home);
    await tester.pump(const Duration(milliseconds: 600));
    expect(f.gate.closed, isFalse);
    expect(f.builds['home'], home + 1);
    expect(f.shown['home'], 1);
  });

  testWidgets('defer runs a held callback once when the transition ends', (
    tester,
  ) async {
    final f = _Fixture(tester);
    await f.pump();
    await f.push();
    await tester.pumpAndSettle();
    final context = tester.element(find.text('home 0', skipOffstage: false));
    await f.gesture('startBackGesture', 0);
    await f.gesture('updateBackGestureProgress', 0.4);
    final route = ModalRoute.of(context);
    void apply() => f.deferred++;
    expect(RouteTransitionGate.defer(route, apply), isTrue);
    expect(RouteTransitionGate.defer(route, apply), isTrue);
    expect(f.deferred, 0);
    await f.gesture('cancelBackGesture');
    await tester.pumpAndSettle();
    expect(f.deferred, 1);
    expect(RouteTransitionGate.defer(route, apply), isFalse);
  });
}
