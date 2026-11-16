import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'support/server_tab.dart';

/// Web v1.24 MobileServerTab on the real workspace shell at phone width: the
/// bar's last cell and its popover (server list, switcher actions, pages).
const _list = Key('mobile-server-tab-list');
const _actions = Key('mobile-server-tab-actions');
const _pages = Key('mobile-server-tab-pages');
const _bar = Key('workspace-mobile-navigation');

Future<RootFixture> _mount(
  WidgetTester t, {
  String uri = '/s/alpha',
  String role = 'owner',
  List<Map<String, dynamic>> unread = const [],
  Map<String, Object>? preferences,
  void Function(RootFixture)? setup,
}) async {
  final f = RootFixture();
  f.servers[0] = {...f.servers[0], 'role': role};
  f.overrides['GET /servers/unread-summary'] = (_) => unread;
  setup?.call(f);
  await f.mount(
    t,
    'light',
    390,
    uri: Uri.parse(uri),
    preferences: preferences ?? const {},
  );
  return f;
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the bar is four tabs and the server tab, named Primary', (
    t,
  ) async {
    final f = await _mount(t);
    final handle = t.ensureSemantics();
    expect(find.byKey(serverTabKey), findsOneWidget);
    for (final id in ['home', 'activity', 'tasks', 'search']) {
      expect(find.byKey(Key('mobile-tab-$id')), findsOneWidget, reason: id);
    }
    expect(find.byKey(const Key('mobile-tab-settings')), findsNothing);
    expect(find.byKey(const Key('mobile-tab-members')), findsNothing);
    expect(find.bySemanticsLabel('Primary'), findsOneWidget);
    // The server's name is the tab's label and its semantics.
    expect(
      find.descendant(
        of: find.byKey(serverTabKey),
        matching: find.text('Alpha'),
      ),
      findsWidgets,
    );
    expect(find.bySemanticsLabel(RegExp(r'^Alpha$')), findsOneWidget);
    expect(find.byKey(_bar), findsOneWidget);
    handle.dispose();
    await f.close(t);
  });

  testWidgets('the popover lists the servers, the actions and the pages', (
    t,
  ) async {
    final f = await _mount(t);
    await openServerPopover(t, flush: f.flush);
    expect(find.byKey(serverPopoverKey), findsOneWidget);
    expect(find.byKey(_list), findsOneWidget);
    expect(find.byKey(_actions), findsOneWidget);
    expect(find.byKey(_pages), findsOneWidget);
    final a = find.byKey(const Key('mobile-server-tab-server-a'));
    final b = find.byKey(const Key('mobile-server-tab-server-b'));
    expect(a, findsOneWidget);
    expect(b, findsOneWidget);
    // Same servers in the same order as the Home switcher; the open one is
    // current.
    expect(t.getTopLeft(a).dy, lessThan(t.getTopLeft(b).dy));
    expect(t.widget<RaftMobileNavServerPopoverRow>(a).current, isTrue);
    expect(t.widget<RaftMobileNavServerPopoverRow>(b).current, isFalse);
    expect(find.text('/alpha'), findsOneWidget);
    expect(find.text('/beta'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-server-tab-join-community')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-server-tab-switch-or-create')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-server-tab-invite')), findsOneWidget);
    for (final page in ['members', 'computers', 'settings']) {
      expect(find.byKey(serverPageKey(page)), findsOneWidget, reason: page);
    }
    // Artifacts and Apps have no Flutter page yet: not offered.
    expect(find.byKey(serverPageKey('artifacts')), findsNothing);
    expect(find.byKey(serverPageKey('apps')), findsNothing);
    await f.close(t);
  });

  testWidgets('a guest has Settings only', (t) async {
    final f = await _mount(t, role: 'guest');
    await openServerPopover(t, flush: f.flush);
    expect(find.byKey(serverPageKey('settings')), findsOneWidget);
    expect(find.byKey(serverPageKey('members')), findsNothing);
    expect(find.byKey(serverPageKey('computers')), findsNothing);
    expect(find.byKey(const Key('mobile-server-tab-invite')), findsNothing);
    await f.close(t);
  });

  testWidgets('the avatar dot means another server has unread items', (
    t,
  ) async {
    var f = await _mount(
      t,
      unread: [
        // Its own unread never lights the dot.
        {'serverId': 'a', 'unreadCount': 4, 'activityUnreadCount': 4},
      ],
    );
    expect(find.byKey(const Key('mobile-tab-server-unread-dot')), findsNothing);
    await f.close(t);
    f = await _mount(
      t,
      unread: [
        {'serverId': 'b', 'unreadCount': 3, 'activityUnreadCount': 3},
      ],
    );
    await _settle(t);
    final handle = t.ensureSemantics();
    expect(
      find.byKey(const Key('mobile-tab-server-unread-dot')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Alpha, another server has unread items')),
      findsOneWidget,
    );
    await openServerPopover(t, flush: f.flush);
    // The count shows on the other server's row, never on the current one.
    expect(find.byKey(const Key('server-row-unread-b')), findsOneWidget);
    expect(find.byKey(const Key('server-row-unread-a')), findsNothing);
    handle.dispose();
    await f.close(t);
  });

  testWidgets('the Activity tab shows a dot, never a number, never selected', (
    t,
  ) async {
    final f = await _mount(t);
    final handle = t.ensureSemantics();
    const dot = Key('mobile-tab-activity-unread-dot');
    expect(find.byKey(dot), findsNothing);
    final store = f.workspace(t).activityUnread;
    store.acceptWindow(
      {'items': const <Object>[], 'totalUnreadCount': 7},
      scope: store.scope,
      firstPage: true,
    );
    await t.pump();
    expect(find.byKey(dot), findsOneWidget);
    expect(find.byKey(const Key('mobile-nav-badge-activity')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Unread activity')), findsOneWidget);
    // Search never has a dot; Activity hides it while it is the page shown.
    expect(
      find.descendant(
        of: find.byKey(const Key('mobile-tab-search')),
        matching: find.byType(RaftStatus),
      ),
      findsNothing,
    );
    await t.tap(find.byKey(const Key('mobile-tab-activity')));
    await f.flush(t);
    expect(find.byKey(dot), findsNothing);
    await t.tap(find.byKey(const Key('mobile-tab-tasks')));
    await f.flush(t);
    // The Activity page replaced the seeded window with its own (empty) one.
    store.acceptWindow(
      {'items': const <Object>[], 'totalUnreadCount': 7},
      scope: store.scope,
      firstPage: true,
    );
    await t.pump();
    expect(find.byKey(dot), findsOneWidget);
    handle.dispose();
    await f.close(t);
  });

  testWidgets('pages push with Back, and focus returns to the server tab', (
    t,
  ) async {
    final f = await _mount(t, uri: '/s/alpha/tasks');
    final w = f.workspace(t);
    final focus = t
        .widget<RaftMobileNavServerTab>(find.byKey(serverTabKey))
        .focusNode!;
    for (final page in ['members', 'computers', 'settings']) {
      await openServerPage(t, page, flush: f.flush);
      expect(w.location.route.name, page);
      expect(find.byKey(_bar), findsNothing, reason: page);
      expect(
        find
                .byKey(const Key('server-page-mobile-back'))
                .evaluate()
                .isNotEmpty ||
            find.byKey(const Key('mobile-detail-back')).evaluate().isNotEmpty,
        isTrue,
        reason: page,
      );
      // Back returns to the tab root it was opened from, with its bar.
      expect(await t.binding.handlePopRoute(), isTrue);
      await f.flush(t);
      await _settle(t);
      expect(w.location.route, RaftRoute.tasks, reason: page);
      expect(find.byKey(_bar), findsOneWidget, reason: page);
      expect(focus.hasFocus, isTrue, reason: '$page: focus is the server tab');
    }
    // Reaching the bar any other way does not take the focus.
    await t.tap(find.byKey(const Key('mobile-tab-home')));
    await f.flush(t);
    expect(focus.hasFocus, isFalse);
    await f.close(t);
  });

  testWidgets('Computers and Settings carry their attention dots', (t) async {
    final f = await _mount(
      t,
      setup: (f) {
        f.overrides['GET /servers/a/machines'] = (_) => {
          'machines': [
            {
              'id': 'computer-a',
              'name': 'Build Computer',
              'isComputer': true,
              'status': 'offline',
              'userId': 'alice',
            },
          ],
        };
        f.overrides['GET /product-feedback/tickets'] = (_) => {
          'tickets': const <Object>[],
          'unread_total': 2,
        };
      },
    );
    await _settle(t);
    final handle = t.ensureSemantics();
    await openServerPopover(t, flush: f.flush);
    await _settle(t);
    expect(find.byKey(const Key('computers-attention-dot')), findsOneWidget);
    expect(find.byKey(const Key('settings-attention-dot')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Computers, ')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Settings, Feedback has new replies'),
      findsOneWidget,
    );
    // Opening Computers sees its attention state; the dot is gone on return.
    await t.tap(find.byKey(serverPageKey('computers')));
    await f.flush(t);
    await _settle(t);
    expect(await t.binding.handlePopRoute(), isTrue);
    await f.flush(t);
    await _settle(t);
    await openServerPopover(t, flush: f.flush);
    expect(find.byKey(const Key('computers-attention-dot')), findsNothing);
    expect(find.byKey(const Key('settings-attention-dot')), findsOneWidget);
    handle.dispose();
    await f.close(t);
  });

  testWidgets('switching keeps the tab and replaces the history entry', (
    t,
  ) async {
    for (final tab in ['tasks', 'activity', 'search']) {
      final f = await _mount(t, uri: '/s/alpha/$tab');
      await openServerPopover(t, flush: f.flush);
      await t.tap(find.byKey(const Key('mobile-server-tab-server-b')));
      await f.flush(t);
      await _settle(t);
      expect(f.workspace(t).server!.id, 'b', reason: tab);
      expect(
        f.router(t).currentConfiguration.path,
        '/s/beta/$tab',
        reason: tab,
      );
      expect(find.byKey(Key('mobile-tab-$tab')), findsOneWidget);
      expect(t.widget<RaftMobileNav>(find.byKey(_bar)).selectedId, tab);
      // Back cannot cross into the previous server.
      expect(await t.binding.handlePopRoute(), isFalse, reason: tab);
      await f.close(t);
    }
  });

  testWidgets('Home stays Home on a switch', (t) async {
    final f = await _mount(t);
    await openServerPopover(t, flush: f.flush);
    await t.tap(find.byKey(const Key('mobile-server-tab-server-b')));
    await f.flush(t);
    await _settle(t);
    expect(f.router(t).currentConfiguration.path, '/s/beta');
    await f.close(t);
  });

  testWidgets('a dragged server order is saved through the switcher\'s path', (
    t,
  ) async {
    final writes = <dynamic>[];
    final f = await _mount(
      t,
      setup: (f) => f.overrides['PATCH /servers/order'] = (request) {
        writes.add(request.data);
        return request.data;
      },
    );
    await openServerPopover(t, flush: f.flush);
    t.widget<RaftMobileNavServerPopoverList>(find.byKey(_list)).onReorder!(
      0,
      1,
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await f.flush(t);
    expect(writes, [
      {
        'serverOrder': ['b', 'a'],
      },
    ]);
    expect(f.workspace(t).servers.map((s) => s.id), ['b', 'a']);
    await f.close(t);
  });

  testWidgets('the footer actions use the switcher\'s callbacks', (t) async {
    final f = await _mount(t);
    await openServerPopover(t, flush: f.flush);
    await t.tap(find.byKey(const Key('mobile-server-tab-switch-or-create')));
    await f.flush(t);
    // The popover closed and the server chooser opened.
    expect(find.byKey(serverPopoverKey), findsNothing);
    expect(f.router(t).currentConfiguration.toString(), '/');
    await f.close(t);
  });

  testWidgets('tapping the selected Search tab focuses the field', (t) async {
    final f = await _mount(t);
    await t.tap(find.byKey(const Key('mobile-tab-search')));
    await f.flush(t);
    await _settle(t);
    final w = f.workspace(t);
    final index = w.navigation.index;
    EditableText field() =>
        t.widget<EditableText>(find.byType(EditableText).first);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    expect(field().focusNode.hasFocus, isFalse);
    await t.tap(find.byKey(const Key('mobile-tab-search')));
    await f.flush(t);
    await t.pump();
    expect(w.navigation.index, index, reason: 'no navigation');
    expect(field().focusNode.hasFocus, isTrue);
    await f.close(t);
  });
}
