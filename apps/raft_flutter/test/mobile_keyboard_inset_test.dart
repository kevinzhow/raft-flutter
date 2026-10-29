import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/app_services_fixture.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  final removedMetadata = <String>{};
  final agentRows = <Map<String, dynamic>>[];
  final pendingMetadata = <String, Completer<dynamic>>{};
  Completer<Map<String, dynamic>>? pendingMessages;
  final channelRows = [
    RaftChannel({'id': 'c', 'name': 'design', 'joined': true}),
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
  }) async {
    calls.add('messages:$id');
    if (pendingMessages != null) return pendingMessages!.future;
    return {
      'messages': [message('m')],
      'threadSummariesByParentMessageId': {},
    };
  }

  Map<String, dynamic> message(String id) => {
    'id': id,
    'channelId': 'c',
    'serverId': 's',
    'seq': id == 'm' ? '1' : '2',
    'content': 'Public fixture',
    'senderId': 'other',
    'senderType': 'user',
    'createdAt': '2026-10-08T00:00:00Z',
  };
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path == '/agents') return agentRows;
    if (path.startsWith('/agents/')) {
      return agentRows
              .where((row) => row['id'] == path.split('/').last)
              .firstOrNull ??
          {};
    }
    if (pendingMetadata[path] case final pending?) return pending.future;
    if (removedMetadata.contains(path)) {
      throw const RaftApiException('Channel not found', status: 404);
    }
    if (path == '/channels/c') {
      return {'id': 'c', 'serverId': 's', 'name': 'design', 'joined': true};
    }
    if (path.startsWith('/messages/context/')) {
      return {
        'messages': [message(path.split('/').last)],
      };
    }
    if (path == '/channels/unread') {
      return {
        'channels': {'c': 1},
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
    calls.add('POST:$path');
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '2', 'readStateVersion': '1'};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }
}

const _screen = Size(390, 844);
const _keyboard = FakeViewPadding(bottom: 320);

/// Keyboard-inset research: documents how the tab bar reacts to viewInsets and
/// that no widget state outlives the keyboard (every sequence recovers).

/// Drives the real mobile workspace shell under an Android-like window.
class _Rig {
  _Rig(this.tester);
  final WidgetTester tester;
  late final _Client c;
  late final WorkspaceController w;

  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> start() async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1;
    // Edge-to-edge Android: a gesture-bar padding, transparent system bars.
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    c = _Client()..selectServer('s');
    w = WorkspaceController(c, mobileNavigation: true);
    await tester.runAsync(w.bootstrap);
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: RaftAppearance(mode: ThemeMode.light),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await settle();
  }

  /// Software keyboard. [up] animates nothing: the test sets the final value.
  void keyboard(bool up) {
    tester.view.viewInsets = up ? _keyboard : FakeViewPadding.zero;
    // Android reports the IME as part of padding-less viewInsets; the
    // gesture-bar stays in padding/viewPadding.
  }

  Finder get bar => find.byKey(const Key('workspace-mobile-navigation'));
  double get barBottom => tester.getRect(bar).bottom;
  double get lift => _screen.height - barBottom;
  Future<void> focusComposer() async {
    final field = find.descendant(
      of: find.byType(RaftComposer),
      matching: find.byType(EditableText),
    );
    await tester.tap(field.first);
    await tester.pump();
  }
}

void main() {
  group('keyboard inset on the mobile shell', () {
    testWidgets('baseline: bar sits at the bottom with no keyboard', (
      tester,
    ) async {
      final r = _Rig(tester);
      await r.start();
      expect(r.bar, findsOneWidget);
      // floating capsule (bottom space).
      debugPrint('baseline lift=${r.lift}');
      expect(r.lift, lessThan(60));
    });

    testWidgets('Home: bar stays at rest when the keyboard is up', (
      tester,
    ) async {
      final r = _Rig(tester);
      await r.start();
      final rest = r.lift;
      r.keyboard(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      debugPrint('Home keyboard UP lift=${r.lift} (rest $rest)');
      // Fixed: the workspace Scaffold no longer resizes for the keyboard;
      // the adaptive workspace shrinks only the content above the bar, and
      // the bar reads the stable system inset, so it never follows the IME.
      expect(r.lift, closeTo(rest, .5), reason: 'bar must ignore viewInsets');
      r.keyboard(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      debugPrint('Home keyboard DOWN lift=${r.lift}');
      expect(r.lift, closeTo(rest, .5), reason: 'restored after keyboard');
    });

    testWidgets('Home: bar stays put with the engine padding (nav bar 0)', (
      tester,
    ) async {
      // Real Android: padding = max(0, viewPadding - viewInsets), so the
      // keyboard replaces the nav-bar padding while viewPadding keeps it.
      // A stale (flutter#118761) inset after hide must not leave the bar
      // lifted either: this models the stuck state, bar stays at rest.
      final r = _Rig(tester);
      await r.start();
      final rest = r.lift;
      r.keyboard(true);
      tester.view.padding = const FakeViewPadding(top: 24);
      await tester.pump(const Duration(milliseconds: 400));
      expect(r.lift, closeTo(rest, .5), reason: 'IME must not lift the bar');
      // Stuck state: system bar back, viewInsets still non-zero.
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      await tester.pump(const Duration(milliseconds: 400));
      expect(r.lift, closeTo(rest, .5), reason: 'stale inset must not lift');
      r.keyboard(false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(r.lift, closeTo(rest, .5));
    });

    testWidgets('channel composer focus, Back to Home, keyboard down', (
      tester,
    ) async {
      final r = _Rig(tester);
      await r.start();
      final rest = r.lift;
      await r.w.selectChannel(r.w.channels.single);
      await r.settle();
      await r.focusComposer();
      r.keyboard(true);
      await r.settle();
      // Back while the keyboard is still up.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      debugPrint('mid-pop (kbd up) lift=${r.lift}');
      await r.settle();
      debugPrint('Home settled, keyboard still up lift=${r.lift}');
      r.keyboard(false);
      await r.settle();
      debugPrint('Home, keyboard down lift=${r.lift} (rest $rest)');
      expect(r.lift, closeTo(rest, .5));
    });

    testWidgets('Back from a focused composer releases focus and the IME', (
      tester,
    ) async {
      final r = _Rig(tester);
      await r.start();
      await r.w.selectChannel(r.w.channels.single);
      await r.settle();
      await r.focusComposer();
      await r.settle();
      expect(tester.testTextInput.isVisible, isTrue);
      debugPrint('before Back focus=${FocusManager.instance.primaryFocus}');
      await tester.binding.handlePopRoute();
      await r.settle();
      debugPrint(
        'after Back focus=${FocusManager.instance.primaryFocus} '
        'imeVisible=${tester.testTextInput.isVisible}',
      );
      expect(tester.testTextInput.isVisible, isFalse);
    });

    for (final commit in [true, false]) {
      testWidgets(
        'predictive back with the keyboard going down mid-gesture commit=$commit',
        (tester) async {
          final r = _Rig(tester);
          await r.start();
          final rest = r.lift;
          await r.w.selectChannel(r.w.channels.single);
          await r.settle();
          await r.focusComposer();
          r.keyboard(true);
          await r.settle();
          Future<void> back(String m, [Map<String, Object?>? args]) async {
            await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
              'flutter/backgesture',
              const StandardMethodCodec().encodeMethodCall(MethodCall(m, args)),
              (_) {},
            );
            await tester.pump(const Duration(milliseconds: 16));
          }

          Map<String, Object?> ev(double p) => {
            'touchOffset': [2.0 + 300 * p, 400.0],
            'progress': p,
            'swipeEdge': 0,
          };
          await back('startBackGesture', ev(0));
          for (final p in [.2, .5, .8]) {
            await back('updateBackGestureProgress', ev(p));
          }
          // The IME hides when the gesture ends/starts committing.
          r.keyboard(false);
          await tester.pump(const Duration(milliseconds: 16));
          await back(commit ? 'commitBackGesture' : 'cancelBackGesture');
          await r.settle();
          debugPrint(
            'predictive commit=$commit -> bar ${r.bar.evaluate().length} '
            'lift=${r.bar.evaluate().isEmpty ? -1 : r.lift} (rest $rest)',
          );
          if (commit) expect(r.lift, closeTo(rest, .5));
        },
      );
    }

    testWidgets('keyboard flips during a push animation (route snapshot)', (
      tester,
    ) async {
      final r = _Rig(tester);
      await r.start();
      final rest = r.lift;
      final push = r.w.selectChannel(r.w.channels.single);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      r.keyboard(true);
      await tester.pump(const Duration(milliseconds: 100));
      r.keyboard(false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => push);
      await r.settle();
      expect(
        find.byKey(const ValueKey('entering-snapshot')),
        findsNothing,
        reason: 'a settled route never keeps its entering picture',
      );
      await tester.binding.handlePopRoute();
      await r.settle();
      expect(r.lift, closeTo(rest, .5));
    });

    testWidgets('keyboard goes down in the middle of the pop animation', (
      tester,
    ) async {
      final r = _Rig(tester);
      await r.start();
      final rest = r.lift;
      await r.w.selectChannel(r.w.channels.single);
      await r.settle();
      await r.focusComposer();
      r.keyboard(true);
      await r.settle();
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      r.keyboard(false);
      await tester.pump(const Duration(milliseconds: 50));
      await r.settle();
      debugPrint('keyboard down mid-pop -> lift=${r.lift} (rest $rest)');
      expect(r.lift, closeTo(rest, .5));
    });

    testWidgets('keyboard goes down before the pop is even handled', (
      tester,
    ) async {
      final r = _Rig(tester);
      await r.start();
      final rest = r.lift;
      await r.w.selectChannel(r.w.channels.single);
      await r.settle();
      await r.focusComposer();
      r.keyboard(true);
      await r.settle();
      r.keyboard(false);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await r.settle();
      expect(r.lift, closeTo(rest, .5));
    });

    testWidgets('tab switch while the keyboard is up, then down', (
      tester,
    ) async {
      final r = _Rig(tester);
      await r.start();
      final rest = r.lift;
      r.keyboard(true);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('mobile-tab-members')));
      await r.settle();
      debugPrint('members tab, keyboard up lift=${r.lift}');
      r.keyboard(false);
      await r.settle();
      debugPrint('members tab, keyboard down lift=${r.lift}');
      expect(r.lift, closeTo(rest, .5));
      await tester.tap(find.byKey(const Key('mobile-tab-home')));
      await r.settle();
      expect(r.lift, closeTo(rest, .5));
    });

    testWidgets('keyboard ups and downs across Search push and pop', (
      tester,
    ) async {
      final r = _Rig(tester);
      await r.start();
      final rest = r.lift;
      await tester.tap(find.byKey(const Key('nav-search')));
      await r.settle();
      expect(r.bar, findsNothing);
      r.keyboard(true);
      await r.settle();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      await r.settle();
      debugPrint('after search pop (kbd up) lift=${r.lift}');
      r.keyboard(false);
      await r.settle();
      debugPrint('after search pop (kbd down) lift=${r.lift}');
      expect(r.lift, closeTo(rest, .5));
    });
  });
}
