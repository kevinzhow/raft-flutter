// Foldable layout switches (768dp breakpoint). One canonical RaftLocation is
// projected as columns (wide) or as a page stack (phone); crossing the
// breakpoint must keep the visible page and make Back walk the phone chain,
// not the history wide panels left behind.
@Tags(['slow'])
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'edge_to_edge_audit_test.dart' show richFixture, settle, openChannel;

const _dpr = 2.625;
const wide = Size(816, 900), phone = Size(412, 900);

Future<RootFixture> mount(WidgetTester t, Size dp, String path) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final f = richFixture();
  f.overrides['GET /agents'] = (_) => [
    {
      'id': 'agent-1',
      'name': 'cindy',
      'displayName': 'Cindy',
      'description': 'Engineering operator',
      'status': 'online',
    },
  ];
  await f.mount(t, 'elegant-light', dp.width, uri: Uri.parse(path));
  t.view.devicePixelRatio = _dpr;
  t.view.physicalSize = dp * _dpr;
  const top = 40 * _dpr;
  t.view.viewPadding = const FakeViewPadding(top: top, bottom: 126);
  t.view.padding = const FakeViewPadding(top: top, bottom: 126);
  addTearDown(() {
    t.view.resetPadding();
    t.view.resetViewPadding();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  await f.flush(t);
  await settle(t);
  return f;
}

Future<void> resize(WidgetTester t, RootFixture f, Size dp) async {
  t.view.physicalSize = dp * _dpr;
  await f.flush(t);
  await settle(t);
}

String _short(Uri uri) => uri
    .toString()
    .replaceFirst('/s/alpha', '')
    .replaceFirst(RegExp(r'\?$'), '');

String where(RootFixture f, WidgetTester t) =>
    _short(f.workspace(t).location.uri);

List<String> history(RootFixture f, WidgetTester t) {
  final n = f.workspace(t).navigation;
  return [for (final e in n.entries.take(n.index + 1)) _short(e.uri)];
}

/// Android Back until the app would exit; returns where each press landed.
Future<List<String>> backWalk(
  WidgetTester t,
  RootFixture f, {
  int limit = 8,
}) async {
  final landed = <String>[];
  for (var i = 0; i < limit; i++) {
    final handled = await t.binding.handlePopRoute();
    await f.flush(t);
    await settle(t);
    if (!handled) return landed;
    landed.add(where(f, t));
  }
  fail('Back never reached the app exit: $landed');
}

int mountedPages(WidgetTester t) => t
    .widget<Navigator>(
      find.descendant(
        of: find.byType(MobileWorkspacePages),
        matching: find.byType(Navigator),
      ),
    )
    .pages
    .length;

void scenario(String name, Future<void> Function(WidgetTester t) body) =>
    testWidgets(name, (t) async {
      try {
        await body(t);
        expect(t.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

bool wideShown(WidgetTester t) =>
    find.byType(MobileWorkspacePages).evaluate().isEmpty;

/// The chat columns (channel sidebar) are on stage.
bool sidebarShown(WidgetTester t) =>
    find.byKey(const Key('workspace-sidebar-panel')).evaluate().isNotEmpty;
bool phoneShown(WidgetTester t) =>
    find.byType(MobileWorkspacePages).evaluate().isNotEmpty;

void main() {
  // R1: history written by wide panel open/close must not leak into the phone.
  scenario('R1 wide thread/profile open+close, fold: Back is channel -> Home', (
    t,
  ) async {
    final f = await mount(t, wide, '/s/alpha');
    await openChannel(t, f);
    final w = f.workspace(t);
    unawaited(
      w.openThreadIdentity(parentChannelId: 'ca', parentMessageId: 'ma'),
    );
    await f.flush(t);
    await settle(t);
    w.openProfile(RaftProfileKind.human, 'bob');
    await settle(t);
    w.closeProfile();
    await settle(t);
    w.closeThread();
    await settle(t);
    expect(where(f, t), '/channel/ca');
    await resize(t, f, phone);
    expect(where(f, t), '/channel/ca');
    expect(mountedPages(t), 2, reason: 'Home + channel only');
    expect(await backWalk(t, f), [''], reason: 'one Back reaches Home');
  });

  scenario('R1b wide thread open then fold: thread -> channel -> Home', (
    t,
  ) async {
    final f = await mount(t, wide, '/s/alpha');
    await openChannel(t, f);
    final w = f.workspace(t);
    unawaited(
      w.openThreadIdentity(parentChannelId: 'ca', parentMessageId: 'ma'),
    );
    await f.flush(t);
    w.openProfile(RaftProfileKind.human, 'bob');
    await settle(t);
    await resize(t, f, phone);
    expect(mountedPages(t), 4, reason: 'Home, channel, thread, profile');
    expect(await backWalk(t, f), [
      '/channel/ca?thread=ca%3Ama',
      '/channel/ca',
      '',
    ]);
  });

  // R2: channelPage is a phone page; wide has the dialog.
  scenario('R2 channel page on phone, unfold: dialog over the columns', (
    t,
  ) async {
    final f = await mount(t, phone, '/s/alpha');
    await openChannel(t, f);
    final w = f.workspace(t);
    w.navigation.navigate(w.location.withQuery({'channelPage': 'settings:ca'}));
    w.notifyListeners();
    await settle(t);
    expect(find.byType(ChannelSettings), findsOneWidget);
    await resize(t, f, wide);
    await settle(t);
    expect(where(f, t), '/channel/ca', reason: 'phone-only param dropped');
    expect(history(f, t), ['', '/channel/ca'], reason: 'pushed page popped');
    expect(sidebarShown(t), isTrue, reason: 'columns, not a full-window page');
    expect(find.byType(ChannelSettings), findsOneWidget, reason: 'dialog');
    expect(
      t.widget<ChannelSettings>(find.byType(ChannelSettings)).page,
      isFalse,
      reason: 'the dialog presentation, not the phone page',
    );
    // The dialog survives folding; the location is the plain conversation.
    await resize(t, f, phone);
    expect(find.byType(ChannelSettings), findsOneWidget);
    expect(where(f, t), '/channel/ca');
  });

  scenario('R2b cold wide link with channelPage opens the dialog', (t) async {
    final f = await mount(
      t,
      wide,
      '/s/alpha/channel/ca?channelPage=settings:ca',
    );
    expect(where(f, t), '/channel/ca');
    expect(wideShown(t), isTrue);
  });

  scenario('R2c wide Activity preview, fold: conversation page over Activity', (
    t,
  ) async {
    final f = await mount(t, wide, '/s/alpha/activity?open=channel:ca');
    expect(where(f, t), '/activity?open=channel:ca');
    await resize(t, f, phone);
    expect(where(f, t), '/channel/ca');
    expect(history(f, t), ['', '/activity', '/channel/ca']);
    expect(mountedPages(t), 3, reason: 'Home, Activity, conversation');
    expect(await backWalk(t, f), ['/activity', '']);
  });

  scenario('R2d wide Search result slot, fold: Back returns to Search', (
    t,
  ) async {
    final f = await mount(t, wide, '/s/alpha/search?open=channel:ca&msg=m2');
    await resize(t, f, phone);
    expect(where(f, t), '/channel/ca?msg=m2');
    expect(await backWalk(t, f), ['/search', '']);
  });

  // R3: the layout follows the live width even with a route above it.
  scenario('R3 dialog across the breakpoint follows the live layout', (
    t,
  ) async {
    final f = await mount(t, wide, '/s/alpha');
    await openChannel(t, f);
    final ctx = t.element(find.byType(WorkspaceView).first);
    unawaited(
      showDialog<void>(
        context: ctx,
        builder: (_) => const AlertDialog(title: Text('Dialog')),
      ),
    );
    await settle(t);
    await resize(t, f, phone);
    expect(phoneShown(t), isTrue);
    expect(find.byKey(const Key('workspace-sidebar-panel')), findsNothing);
    expect(find.text('Dialog'), findsOneWidget, reason: 'dialogs stay open');
    await resize(t, f, wide);
    expect(phoneShown(t), isFalse);
    expect(wideShown(t), isTrue);
    expect(find.text('Dialog'), findsOneWidget);
    await resize(t, f, phone);
    expect(find.text('Dialog'), findsOneWidget);
    Navigator.of(t.element(find.text('Dialog')), rootNavigator: true).pop();
    await settle(t);
    expect(phoneShown(t), isTrue);
  });

  scenario('R3b full pages without a URL stay open with the dialogs', (t) async {
    final f = await mount(t, wide, '/s/alpha');
    await openChannel(t, f);
    final ctx = t.element(find.byType(WorkspaceView).first);
    final navigator = Navigator.of(ctx, rootNavigator: true);
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Pushed page')),
        ),
      ),
    );
    await settle(t);
    expect(find.text('Pushed page'), findsOneWidget);
    await resize(t, f, phone);
    // A layout change is not the user leaving the page (layout_class_
    // navigation_matrix_test walks every kind of page).
    expect(find.text('Pushed page'), findsOneWidget);
    expect(where(f, t), '/channel/ca');
    expect(phoneShown(t), isTrue);
  });

  // R5: the location survives every crossing; Back always walks to Home.
  const shapes = <String>[
    '/s/alpha',
    '/s/alpha/channel/ca',
    '/s/alpha/channel/ca?thread=ca:ma',
    '/s/alpha/channel/ca?profile=agent:agent-1',
    '/s/alpha/channel/ca?thread=ca:ma&profile=human:bob',
    '/s/alpha/tasks',
    '/s/alpha/members',
    '/s/alpha/settings',
    '/s/alpha/settings/appearance',
    '/s/alpha/agent/agent-1',
    '/s/alpha/human/bob',
    '/s/alpha/search',
    '/s/alpha/activity',
  ];
  for (final path in shapes) {
    scenario('R5 round trip $path', (t) async {
      final f = await mount(t, phone, path);
      final start = where(f, t);
      await resize(t, f, wide);
      expect(where(f, t), start, reason: 'phone -> wide');
      expect(wideShown(t), isTrue);
      await resize(t, f, phone);
      expect(where(f, t), start, reason: 'wide -> phone');
      expect(phoneShown(t), isTrue);
      // Back-walk to exit after the transitions never revisits stale pages.
      final landed = await backWalk(t, f);
      expect(landed.length, lessThanOrEqualTo(6), reason: '$landed');
      expect(
        landed.toSet().length,
        landed.length,
        reason: 'no page twice: $landed',
      );
      final n = f.workspace(t).navigation;
      final root = n.mobileRootTabOf(n.location) != null;
      expect(
        root,
        isTrue,
        reason:
            'ended at a root: $start $landed ${where(f, t)} ${history(f, t)}',
      );
    });

    scenario('R5b wide start, fold, unfold $path', (t) async {
      final f = await mount(t, wide, path);
      final start = where(f, t);
      await resize(t, f, phone);
      final folded = where(f, t);
      await resize(t, f, wide);
      expect(where(f, t), folded);
      await resize(t, f, phone);
      expect(where(f, t), folded);
      if (!start.contains('open=')) expect(folded, start);
      final landed = await backWalk(t, f);
      expect(landed.length, lessThanOrEqualTo(6), reason: '$landed');
    });
  }

  scenario('R5c phone Back from channel after wide Activity detour', (t) async {
    final f = await mount(t, phone, '/s/alpha');
    await openChannel(t, f);
    await resize(t, f, wide);
    await resize(t, f, phone);
    expect(await backWalk(t, f), ['']);
  });

  // The reader's place in a conversation survives the layout switch.
  scenario('R10 scrolled conversation keeps its place across fold and unfold', (
    t,
  ) async {
    Map<String, dynamic> row(int i) => {
      'id': 'row-$i',
      'channelId': 'ca',
      'seq': '$i',
      'senderId': 'alice',
      'senderName': 'Alice',
      'content': 'Row $i marker',
      'createdAt': DateTime.utc(
        2026,
        10,
        10,
        0,
        0,
      ).add(Duration(minutes: i)).toIso8601String(),
    };
    final f = RootFixtureHolder.rows(row, 120);
    await f.mount(t, phone, '/s/alpha');
    await openChannel(t, f.fixture);
    expect(find.text('Row 120 marker'), findsOneWidget);
    // Read upwards: ~40 rows above the latest end.
    final list = find.byKey(const ValueKey('chat-list-channel'));
    for (var i = 0; i < 5; i++) {
      await t.drag(list, const Offset(0, 500));
      await settle(t, 3);
    }
    int topRow() {
      final view = t.getRect(list);
      int? best;
      double bestTop = double.infinity;
      for (final e in find.textContaining('marker').evaluate()) {
        final box = e.renderObject! as RenderBox;
        final top = box.localToGlobal(Offset.zero).dy;
        if (top >= view.top && top < bestTop) {
          bestTop = top;
          best = int.parse(
            RegExp(r'Row (\d+)').firstMatch(_plain(e.widget))![1]!,
          );
        }
      }
      return best!;
    }

    final before = topRow();
    expect(before, inInclusiveRange(2, 100), reason: 'mid-conversation');
    expect(find.text('Row 120 marker'), findsNothing);
    await resize(t, f.fixture, wide);
    final unfolded = topRow();
    expect(
      (unfolded - before).abs(),
      lessThanOrEqualTo(3),
      reason: 'same place after unfold: was $before, now $unfolded',
    );
    await resize(t, f.fixture, phone);
    final refolded = topRow();
    expect(
      (refolded - before).abs(),
      lessThanOrEqualTo(3),
      reason: 'same place after fold: was $before, now $refolded',
    );
  });
}

String _plain(Widget w) => switch (w) {
  Text(:final data?) => data,
  Text(:final textSpan?) => textSpan.toPlainText(),
  RichText(:final text) => text.toPlainText(),
  _ => '',
};

/// A fixture with a long conversation in channel `ca`.
class RootFixtureHolder {
  RootFixtureHolder.rows(Map<String, dynamic> Function(int) row, int count)
    : fixture = richFixture() {
    fixture.overrides['GET /messages/channel/ca'] = (_) => {
      'messages': [for (var i = 1; i <= count; i++) row(i)],
      'hasMore': false,
      'hasNewer': false,
    };
  }
  final RootFixture fixture;
  Future<void> mount(WidgetTester t, Size dp, String path) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await fixture.mount(t, 'elegant-light', dp.width, uri: Uri.parse(path));
    t.view.devicePixelRatio = _dpr;
    t.view.physicalSize = dp * _dpr;
    const top = 40 * _dpr;
    t.view.viewPadding = const FakeViewPadding(top: top, bottom: 126);
    t.view.padding = const FakeViewPadding(top: top, bottom: 126);
    addTearDown(() {
      t.view.resetPadding();
      t.view.resetViewPadding();
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    await fixture.flush(t);
    await settle(t);
  }
}
