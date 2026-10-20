// Stateful, seeded random walks over the navigation model. The single source
// of truth for "which pages are open" is WorkspaceNavigation (entries, index,
// location). The phone page stack is derived from it (phoneStackFor), the
// Navigator pages are derived from the stack, and the wide columns are derived
// from the location. Layout class, lifecycle and the keyboard may change what
// is *shown*, never what is *open*.
//
// Invariants, checked after every step:
//  I1  the visible shell shows exactly one non-blank page: on a phone the
//      Navigator has pages, its top page is the accepted location and paints
//      something; on a wide window the workspace paints something
//  I2  Back never lands on a blank page (I1 after every Back)
//  I3  a step that is not navigation (background -> resume, keyboard, resize
//      within one layout class) leaves the location and, on a phone, the page
//      stack as it was; a resize across the cut keeps the location
//  I4  closed pages stay closed: after Back the page that was on top is no
//      longer in the stack, and a lifecycle / keyboard / resize step never
//      reopens it
//  I5  Back is handled iff the phone stack has more than one page (the last
//      page hands Back to the system instead of emptying the Navigator)
//
// Failing sequences are recorded in [regressions] and replayed first.
@Tags(['slow'])
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'edge_to_edge_audit_test.dart' show richFixture, settle;
import 'layout_class_navigation_matrix_test.dart'
    show dm, dpr, desktop, folded, landscape, phone, unfolded;

enum Op {
  openActivity,
  openActivityChannel,
  openActivityThread,
  openActivityDm,
  openChannel,
  openThread,
  openProfile,
  back,
  backgroundResume,
  backgroundResumeFolded,
  keyboardUp,
  keyboardDown,
  resize,
}

/// Sequences that once failed (or guard a found counterexample), replayed
/// before the random walks. `start` is an index into [sizes].
const regressions = <(int, List<(Op, int)>)>[
  // seed 15 of a 120-seed hunt: Back from Activity returns to the channel the
  // user came from (the stack is reordered, not shorter).
  (
    1,
    [
      (Op.openActivityChannel, 0),
      (Op.openProfile, 0),
      (Op.back, 0),
      (Op.openThread, 0),
      (Op.openActivityChannel, 0),
      (Op.keyboardUp, 0),
      (Op.back, 0),
      (Op.back, 0),
      (Op.openActivityChannel, 0),
      (Op.openProfile, 0),
      (Op.openActivityChannel, 0),
      (Op.openActivity, 0),
      (Op.back, 0),
    ],
  ),
  // seed 46 of a 60-seed hunt.
  (
    3,
    [
      (Op.keyboardUp, 0),
      (Op.openThread, 0),
      (Op.openActivityDm, 0),
      (Op.keyboardUp, 0),
      (Op.openThread, 0),
      (Op.backgroundResume, 0),
      (Op.keyboardDown, 0),
      (Op.resize, 0),
      (Op.openActivityDm, 0),
      (Op.openProfile, 0),
      (Op.back, 0),
    ],
  ),
  (
    1,
    [
      (Op.openChannel, 0),
      (Op.openThread, 0),
      (Op.openProfile, 0),
      (Op.openThread, 0),
    ],
  ),
  (1, [(Op.openActivityThread, 0), (Op.openProfile, 0), (Op.openThread, 0)]),
  (
    1,
    [
      (Op.openActivityThread, 0),
      (Op.openProfile, 0),
      (Op.openActivityThread, 0),
    ],
  ),
  (1, [(Op.openChannel, 0), (Op.openProfile, 0), (Op.openThread, 0)]),
];

const sizes = [folded, phone, unfolded, desktop, landscape];

Future<RootFixture> mount(WidgetTester t, Size dp) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final f = richFixture();
  f.overrides['GET /agents'] = (_) => [
    {
      'id': 'agent-1',
      'name': 'cindy',
      'displayName': 'Cindy',
      'status': 'online',
    },
  ];
  f.overrides['GET /agents/agent-1'] = (_) => {
    'id': 'agent-1',
    'name': 'cindy',
    'displayName': 'Cindy',
    'status': 'active',
    'runtime': 'claude',
    'model': 'sonnet',
  };
  f.overrides['GET /agents/agent-1/skills'] = (_) => {
    'global': <dynamic>[],
    'workspace': <dynamic>[],
  };
  f.overrides['GET /channels/dm'] = (_) => [dm];
  f.overrides['GET /channels/dm1'] = (_) => dm;
  f.overrides['GET /messages/channel/dm1'] = (_) => {
    'messages': <dynamic>[],
    'hasMore': false,
    'hasNewer': false,
  };
  f.overrides['POST /channels/dm1/read'] = (_) => {};
  f.overrides['POST /channels/ca/read'] = (_) => {};
  f.overrides['GET /messages/context/first-dm'] = (_) => {
    'messages': <dynamic>[],
  };
  f.overrides['GET /channels/inbox'] = (_) => {
    'items': [
      {
        'kind': 'channel',
        'channelId': 'ca',
        'channelName': 'alpha',
        'lastMessagePreview': 'Edge to edge sample',
        'unreadCount': 2,
        'firstUnreadMessageId': 'ma',
        'lastMessageId': 'ma',
      },
      {
        'kind': 'dm',
        'channelId': 'dm1',
        'channelName': 'Cindy',
        'lastMessagePreview': 'hello',
        'unreadCount': 1,
        'firstUnreadMessageId': 'first-dm',
        'lastMessageId': 'first-dm',
      },
      {
        'kind': 'thread',
        'threadChannelId': 'task-thread',
        'parentChannelId': 'ca',
        'parentMessageId': 'task-parent',
        'parentMessagePreview': 'Parent',
        'latestActivityPreview': 'reply',
        'unreadCount': 1,
        'firstUnreadMessageId': 'task-parent',
        'latestActivityMessageId': 'task-parent',
      },
    ],
    'hasMore': false,
    'totalUnreadCount': 4,
  };
  await f.mount(
    t,
    'elegant-light',
    dp.width,
    uri: Uri.parse('/s/alpha/activity'),
  );
  t.view.devicePixelRatio = dpr;
  t.view.physicalSize = dp * dpr;
  const top = 40 * dpr;
  t.view.viewPadding = const FakeViewPadding(top: top, bottom: 126);
  t.view.padding = const FakeViewPadding(top: top, bottom: 126);
  addTearDown(() {
    t.view.resetPadding();
    t.view.resetViewPadding();
    t.view.resetViewInsets();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  await f.flush(t);
  await settle(t);
  return f;
}

bool wideAt(Size dp) => dp.width >= 768;

/// What the walk believes about the window.
class Model {
  Size size;
  bool keyboard = false;
  Model(this.size);
}

String describe(RootFixture f, WidgetTester t) {
  final w = f.workspace(t);
  return '${w.location.uri} stack=${_stack(w)}';
}

List<String> _stack(dynamic w) => [
  for (final page in mobilePageStack(w.navigation))
    mobilePageIdentity(page).replaceAll('/s/alpha', ''),
];

bool paints(WidgetTester t, Finder scope) =>
    find
        .descendant(of: scope, matching: find.byType(RichText))
        .evaluate()
        .isNotEmpty ||
    find
        .descendant(of: scope, matching: find.byType(EditableText))
        .evaluate()
        .isNotEmpty ||
    find
            .descendant(of: scope, matching: find.byType(CustomPaint))
            .evaluate()
            .length >
        2;

/// I1.
void expectOnePage(WidgetTester t, RootFixture f, Size dp, String where) {
  final w = f.workspace(t);
  if (!wideAt(dp)) {
    final navigator = find.descendant(
      of: find.byType(MobileWorkspacePages),
      matching: find.byType(Navigator),
    );
    expect(navigator, findsOneWidget, reason: '$where: phone navigator');
    final pages = t.widget<Navigator>(navigator).pages;
    expect(pages, isNotEmpty, reason: '$where: Navigator has no page');
    final stack = mobilePageStack(w.navigation);
    expect(
      pages.length,
      stack.length,
      reason: '$where: pages ${pages.length} vs stack ${_stack(w)}',
    );
    // The top page is on stage and paints. Each page wraps its body in a
    // PageStorage; the outermost ones, in tree order, are the stack.
    final roots = <Element>[];
    for (final e
        in find
            .descendant(of: navigator, matching: find.byType(PageStorage))
            .evaluate()) {
      var nested = false;
      e.visitAncestorElements((a) {
        if (a == navigator.evaluate().single) return false;
        if (a.widget is PageStorage) nested = true;
        return !nested;
      });
      if (!nested) roots.add(e);
    }
    // Opaque routes hide (and do not build) the pages below them.
    expect(roots, isNotEmpty, reason: '$where: no page is built');
    final top = find.byElementPredicate((e) => e == roots.last);
    final box = t.renderObject<RenderBox>(top);
    expect(box.size.isEmpty, isFalse, reason: '$where: top page has no size');
    expect(
      paints(t, top),
      isTrue,
      reason: '$where: BLANK top page, ${describe(f, t)}',
    );
  } else {
    expect(
      find.byType(MobileWorkspacePages),
      findsNothing,
      reason: '$where: wide shell',
    );
    expect(
      paints(t, find.byType(Scaffold).first),
      isTrue,
      reason: '$where: BLANK wide shell, ${describe(f, t)}',
    );
  }
}

Future<void> step(
  WidgetTester t,
  RootFixture f,
  Model m,
  Op op,
  int arg,
  Random rng,
) async {
  final w = f.workspace(t);
  Future<void> settleAll([int n = 6]) async {
    await f.flush(t);
    await settle(t, n);
  }

  Future<void> tapKey(Key key) async {
    final finder = find.byKey(key);
    if (finder.evaluate().isEmpty) return;
    await t.ensureVisible(finder.first);
    await t.tap(finder.first, warnIfMissed: false);
    await settleAll();
  }

  switch (op) {
    case Op.openActivity:
      w.setSection('activity');
      await settleAll();
    case Op.openActivityChannel:
      await tapKey(const ValueKey('activity-channel-ca'));
    case Op.openActivityThread:
      await tapKey(const ValueKey('activity-thread-task-thread'));
    case Op.openActivityDm:
      await tapKey(const ValueKey('activity-dm-dm1'));
    case Op.openChannel:
      unawaited(w.jumpToMessage('ca', null));
      await settleAll();
    case Op.openThread:
      unawaited(
        w.openThreadIdentity(parentChannelId: 'ca', parentMessageId: 'ma'),
      );
      await settleAll();
    case Op.openProfile:
      w.openProfile(RaftProfileKind.agent, 'agent-1');
      await settleAll();
    case Op.back:
      final before = _stack(w);
      final phoneNow = !wideAt(m.size);
      final handled = await t.binding.handlePopRoute();
      await settleAll(8);
      if (phoneNow) {
        // I5.
        expect(
          handled,
          before.length > 1,
          reason: 'Back handled=$handled with stack $before',
        );
        // I4: Back either leaves the top page (a pop, or the one return to
        // where the user came from, which reorders the stack), or is consumed
        // by something that is not a page (a selection, the drawer, a stale
        // thread) and leaves the same page on stage; then the next Backs make
        // progress.
        var presses = 0;
        while (before.length > 1 && _stack(w).last == before.last) {
          expect(_stack(w), before, reason: 'Back changed another page');
          expect(presses++, lessThan(3), reason: 'Back is stuck on $before');
          expectOnePage(t, f, m.size, 'a consumed Back on $before');
          await t.binding.handlePopRoute();
          await settleAll(8);
        }
      }
    case Op.backgroundResume:
    case Op.backgroundResumeFolded:
      final b = t.binding;
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        b.handleAppLifecycleStateChanged(s);
        await t.pump(const Duration(milliseconds: 50));
      }
      if (op == Op.backgroundResumeFolded) {
        // The device was folded / unfolded while the app was away.
        m.size = wideAt(m.size) ? folded : unfolded;
        t.view.physicalSize = m.size * dpr;
      }
      // The platform replays a stale IME inset around resume (flutter#118761).
      t.view.viewInsets = FakeViewPadding(bottom: 300 * dpr);
      await t.pump(const Duration(milliseconds: 50));
      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        b.handleAppLifecycleStateChanged(s);
        await t.pump(const Duration(milliseconds: 50));
      }
      t.view.viewInsets = FakeViewPadding(bottom: m.keyboard ? 300 * dpr : 0);
      await settleAll(10);
    case Op.keyboardUp:
      m.keyboard = true;
      t.view.viewInsets = FakeViewPadding(bottom: 300 * dpr);
      await settleAll();
    case Op.keyboardDown:
      m.keyboard = false;
      t.view.viewInsets = FakeViewPadding.zero;
      await settleAll();
    case Op.resize:
      m.size = sizes[arg % sizes.length];
      t.view.physicalSize = m.size * dpr;
      await settleAll(8);
  }
}

/// Runs one sequence; returns null, or a description of the failure.
Future<String?> run(
  WidgetTester t,
  int start,
  List<(Op, int)> ops,
  String label,
) async {
  final rng = Random(0);
  final m = Model(sizes[start]);
  final f = await mount(t, m.size);
  final done = <String>[];
  try {
    expectOnePage(t, f, m.size, '$label: mount');
    for (final (op, arg) in ops) {
      final w = f.workspace(t);
      final before = w.location.uri.toString();
      final stackBefore = _stack(w);
      final sizeBefore = m.size;
      await step(t, f, m, op, arg, rng);
      done.add('${op.name}${op == Op.resize ? ':$arg' : ''}');
      final where = '$label after ${done.join(' > ')}';
      expectOnePage(t, f, m.size, where);
      // I3: a step that is not navigation changes neither location nor stack.
      final passive = {
        Op.backgroundResume,
        Op.keyboardUp,
        Op.keyboardDown,
      }.contains(op);
      final after = f.workspace(t);
      if (passive) {
        expect(after.location.uri.toString(), before, reason: where);
        if (!wideAt(sizeBefore)) {
          expect(_stack(after), stackBefore, reason: '$where: stack');
        }
      }
      if (op == Op.resize || op == Op.backgroundResumeFolded) {
        // Crossing the cut translates the location only for the identities
        // that exist in one layout (channelPage, ?open=); never to another
        // conversation or to nothing.
        expect(
          after.location.route,
          isNotNull,
          reason: '$where: location lost',
        );
        if (!before.contains('open=') && !before.contains('channelPage=')) {
          expect(after.location.uri.toString(), before, reason: where);
        }
      }
      expect(t.takeException(), isNull, reason: where);
    }
    return null;
  } on TestFailure catch (e) {
    return '$label: ${e.message}\nsequence: ${done.join(' > ')}';
  } finally {
    FocusManager.instance.primaryFocus?.unfocus();
    t.view.resetViewInsets();
  }
}

List<(Op, int)> randomOps(Random rng, int n) => [
  for (var i = 0; i < n; i++)
    (Op.values[rng.nextInt(Op.values.length)], rng.nextInt(sizes.length)),
];

/// Seeds per run; RAFT_WALK_SEEDS / RAFT_WALK_FROM widen the search (local
/// hunts: 120 seeds of 24 steps from 1 passed).
final walks = int.tryParse(Platform.environment['RAFT_WALK_SEEDS'] ?? '') ?? 12;
final first = int.tryParse(Platform.environment['RAFT_WALK_FROM'] ?? '') ?? 1;

void main() {
  Future<void> guarded(
    WidgetTester t,
    Future<List<String>> Function() body,
  ) async {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      prior?.call(details);
    };
    List<String> failures;
    try {
      failures = await body();
    } finally {
      FlutterError.onError = prior;
      debugDefaultTargetPlatformOverride = null;
    }
    expect(failures, isEmpty, reason: failures.join('\n---\n'));
  }

  for (final (i, (start, ops)) in regressions.indexed) {
    testWidgets(
      'regression $i: ${ops.map((o) => o.$1.name).join(' > ')}',
      (t) => guarded(t, () async {
        final failure = await run(t, start, ops, 'regression $i');
        return [?failure];
      }),
    );
  }

  testWidgets(
    'seeded random walks keep exactly one non-blank page',
    (t) => guarded(t, () async {
      for (var seed = first; seed < first + walks; seed++) {
        final rng = Random(seed);
        final start = rng.nextInt(sizes.length);
        final failure = await run(
          t,
          start,
          randomOps(rng, 24),
          'seed $seed start ${sizes[start]}',
        );
        // The state of a failed walk is not reusable: report it and stop.
        if (failure != null) return [failure];
        await t.pumpWidget(const SizedBox());
      }
      return [];
    }),
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
