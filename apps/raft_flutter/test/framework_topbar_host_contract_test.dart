import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mounted_message_navigation_test.dart' show pageFixture, mountPage;

// MainLayout shouldShowTopBar: a wide browser/tablet shell owns the bar; a
// native desktop joins global actions to its window chrome; narrow layouts have no global row.
void main() {
  testWidgets('mounted pointer chrome follows the Web frame geometry', (
    t,
  ) async {
    final (w, _) = await pageFixture(t);
    await mountPage(t, w, false, width: 1280);

    Rect bounds(String key) => t.getRect(find.byKey(Key(key)));
    try {
      final search = bounds('topbar-search');
      expect(search, const Rect.fromLTWH(380, 4.5, 520, 34));
      expect(bounds('topbar-history').right, search.left - 8);
      expect(bounds('topbar-forward').right, bounds('topbar-history').left - 2);
      expect(bounds('rail-chat'), const Rect.fromLTWH(6, 50, 36, 36));
      expect(bounds('rail-activity').top, 90);
      expect(bounds('rail-tasks').top, 130);
      expect(bounds('rail-help').top, 818);
      expect(bounds('rail-settings').top, 858);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('elastic search leaves room for every mounted workspace avatar', (
    t,
  ) async {
    final (w, _) = await pageFixture(t);
    const longName = 'Ein sehr langer Arbeitsbereich für Zusammenarbeit';
    final current = RaftRecord({...w.server!.json, 'name': longName});
    w
      ..server = current
      ..servers = [
        current,
        for (var i = 1; i <= 7; i++)
          RaftRecord({'id': 'extra-$i', 'name': '$longName $i'}),
      ];
    await mountPage(t, w, false, width: 1350);

    Finder avatar(int index) =>
        find.byKey(ValueKey('topbar-workspace-extra-$index'));
    try {
      for (final (width, visibleExtras) in [
        (1350.0, 2),
        (1280.0, 1),
        (1150.0, 0),
        (1040.0, 0),
      ]) {
        t.view.physicalSize = Size(width, 900);
        await t.pumpAndSettle();
        final search = t.getRect(find.byKey(const Key('topbar-search')));
        final back = t.getRect(find.byKey(const Key('topbar-back')));
        final history = t.getRect(find.byKey(const Key('topbar-history')));
        expect(search.center.dx, width / 2);
        expect(history.right, search.left - 8);
        if (visibleExtras > 0) {
          expect(avatar(visibleExtras), findsOneWidget);
          expect(t.getRect(avatar(visibleExtras)).right, lessThan(back.left));
        }
        expect(avatar(visibleExtras + 1), findsNothing);
      }
      expect(t.takeException(), isNull);
      await mountPage(
        t,
        w,
        false,
        width: 1040,
        builder: (_, child) => DesktopTitleBarScope(
          leadingInset: 88,
          trailingInset: 138,
          child: child!,
        ),
      );
      final workspace = t.getRect(find.byKey(const Key('topbar-workspace')));
      final back = t.getRect(find.byKey(const Key('topbar-back')));
      final search = t.getRect(find.byKey(const Key('topbar-search')));
      final bell = t.getRect(find.byKey(const Key('topbar-notifications')));
      expect(workspace.left, greaterThanOrEqualTo(88));
      expect(workspace.right, lessThan(back.left));
      expect(search.center.dx, 520);
      expect(search.right, lessThan(bell.left));
      expect(bell.right, lessThanOrEqualTo(1040 - 138));
      expect(t.takeException(), isNull);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final dark in [false, true]) {
    testWidgets('top bar pointer reorder saves Source order/$dark', (t) async {
      final (w, api) = await pageFixture(t);
      w.servers = [
        w.server!,
        for (final id in ['s2', 's3'])
          RaftRecord({'id': id, 'name': id, 'slug': id, 'role': 'owner'}),
      ];
      api.routes['GET /agents'] = (_) => [];
      api.routes['GET /servers/s1/members'] = (_) => [];
      api.routes['GET /servers/unread-summary'] = (_) => [];
      final writes = <dynamic>[];
      api.routes['PATCH /servers/order'] = (request) {
        writes.add(request.data);
        return request.data;
      };
      await mountPage(t, w, dark, width: 1280, browserHost: true);
      final uri = w.location.toString(), history = w.navigation.index;
      final other = find.byKey(const ValueKey('topbar-workspace-s2'));
      final target = find.byKey(const ValueKey('topbar-workspace-s3'));
      expect(other, findsOneWidget);
      expect(target, findsOneWidget);
      final trigger = find.byKey(const Key('topbar-workspace'));
      final currentAvatar = find.descendant(
        of: trigger,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is RaftStickerAvatar && widget.size == RaftAvatarSize.sm,
        ),
      );
      expect(currentAvatar, findsOneWidget);
      expect(t.getSize(currentAvatar), const Size.square(27));
      final mouse = await t.startGesture(
        t.getCenter(other),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveTo(t.getCenter(target));
      await t.pump();
      await mouse.up();
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await t.pumpAndSettle();
      expect(writes, [
        {
          'serverOrder': ['s1', 's3', 's2'],
        },
      ]);
      expect(w.servers.map((s) => s.id), ['s1', 's3', 's2']);
      expect(w.server!.id, 's1');
      expect(w.location.toString(), uri);
      expect(w.navigation.index, history);
      expect(t.getCenter(target).dx, lessThan(t.getCenter(other).dx));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }

  for (final width in [768.0, 800.0, 856.0]) {
    testWidgets('native caption room with three history buttons at $width', (
      t,
    ) async {
      final (w, _) = await pageFixture(t);
      final publicPage = width == 800;
      final name = publicPage
          ? 'مساحة عمل طويلة للتعاون مع الفريق'
          : 'Ein sehr langer Arbeitsbereich für Zusammenarbeit';
      final server = RaftRecord({
        ...w.server!.json,
        'name': name,
        'publicPageLive': publicPage,
      });
      w
        ..server = server
        ..servers = [server];
      const leadingInset = 88.0, trailingInset = 138.0;
      try {
        await mountPage(
          t,
          w,
          false,
          width: width,
          builder: (context, child) => DesktopTitleBarScope(
            leadingInset: leadingInset,
            trailingInset: trailingInset,
            // Keep the full history controls while real layout constraints
            // shrink. The normal narrow-window host uses compact History.
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(size: const Size(1040, 900)),
              child: Directionality(
                textDirection: publicPage
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: child!,
              ),
            ),
          ),
        );
        expect(t.takeException(), isNull);
        Finder control(String name) => find.byKey(Key('topbar-$name'));
        Rect bounds(String name) => t.getRect(control(name));
        final workspace = bounds('workspace');
        final back = bounds('back');
        final forward = bounds('forward');
        final history = bounds('history');
        final search = bounds('search');
        final bell = bounds('notifications');
        final first = publicPage ? history : back;
        final last = publicPage ? back : history;
        expect(workspace.left, greaterThanOrEqualTo(leadingInset));
        expect(workspace.width, greaterThanOrEqualTo(77));
        expect(workspace.right, lessThan(first.left));
        expect(first.right, lessThan(forward.left));
        expect(forward.right, lessThan(last.left));
        expect(last.right, search.left - 8);
        expect(search.width, lessThan(360));
        expect(search.center.dx, width / 2);
        expect(search.right, lessThan(bell.left));
        expect(bell.right, lessThanOrEqualTo(width - trailingInset));
        expect(find.bySemanticsLabel(name), findsOneWidget);
        if (publicPage) {
          final globe = t.getRect(
            find.descendant(
              of: control('workspace'),
              matching: find.byKey(const ValueKey('public-page-globe')),
            ),
          );
          expect(globe.left, greaterThan(workspace.left));
          expect(globe.right, lessThan(workspace.right));
        }

        await t.tap(control('workspace'));
        await t.pumpAndSettle();
        final menu = find.byKey(const Key('server-switcher-menu'));
        expect(menu, findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(menu, findsNothing);
        await t.tap(control('search'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('quick-switcher-input')), findsOneWidget);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }
  testWidgets(
    'short browser host keeps the bottom bar without a native side rail',
    (t) async {
      final (w, _) = await pageFixture(t);
      w.setSection('home');
      await mountPage(t, w, false, width: 390, height: 480, browserHost: true);
      expect(find.byType(RaftWorkspaceRail), findsNothing);
      expect(find.byKey(const Key('rail-workspace')), findsNothing);
      expect(find.byKey(const ValueKey('workspace-top-bar')), findsNothing);
      expect(find.bySemanticsLabel('Home'), findsWidgets);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'wide browser on Linux uses browser chrome rather than native window chrome',
    (t) async {
      final (w, _) = await pageFixture(t);
      await mountPage(t, w, false, width: 856, browserHost: true);
      expect(find.byKey(const ValueKey('workspace-top-bar')), findsOneWidget);
      expect(find.byKey(const Key('rail-workspace')), findsNothing);
      expect(find.byKey(const Key('rail-search')), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
  for (final dismiss in ['scrim', 'system back']) {
    testWidgets('browser topbar workspace menu closes with $dismiss', (
      t,
    ) async {
      final (w, _) = await pageFixture(t);
      await mountPage(t, w, false, width: 1280, browserHost: true);
      final uri = w.location.toString(), history = w.navigation.index;
      await t.tap(find.byKey(const Key('topbar-workspace')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('server-switcher-menu')), findsOneWidget);
      if (dismiss == 'scrim') {
        await t.tapAt(const Offset(1274, 894));
      } else {
        await t.binding.handlePopRoute();
      }
      await t.pumpAndSettle();
      expect(find.byKey(const Key('server-switcher-menu')), findsNothing);
      expect(w.location.toString(), uri);
      expect(w.navigation.index, history);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ]) {
    for (final width in [390.0, 856.0]) {
      testWidgets('$platform/$width mounted frame places global actions once', (
        t,
      ) async {
        final (w, _) = await pageFixture(t);
        w.servers = [w.server!];
        await mountPage(t, w, false, width: width);
        addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
        final bar = find.byKey(const ValueKey('workspace-top-bar'));
        final shows = width >= 768;
        expect(bar, shows ? findsOneWidget : findsNothing);
        if (shows) {
          final barHeight = platform == TargetPlatform.android ? 48.0 : 44.0;
          expect(t.getRect(bar), Rect.fromLTWH(0, 0, width, barHeight));
          expect(t.getTopLeft(find.byType(RaftWorkspaceRail)).dy, barHeight);
          expect(find.byKey(const Key('rail-search')), findsNothing);
          expect(find.byKey(const Key('rail-workspace')), findsNothing);
          expect(find.byType(RaftChatSidebarHeading), findsNothing);
          expect(find.byKey(const Key('topbar-notifications')), findsOneWidget);
          // The existing switcher menu remains real and keyboard dismissible.
          await t.tap(find.byKey(const Key('topbar-workspace')));
          await t.pumpAndSettle();
          final menu = find.byKey(const Key('server-switcher-menu'));
          expect(menu, findsOneWidget);
          expect(t.getTopLeft(menu).dy, greaterThanOrEqualTo(barHeight));
          final current = find.byKey(const Key('server-menu-row-s1'));
          expect(
            t.getSize(current).height,
            platform == TargetPlatform.android ? 48 : 40,
          );
          final avatar = find.descendant(
            of: current,
            matching: find.byType(RaftAvatarSlot),
          );
          expect(
            t.getSize(avatar),
            Size.square(platform == TargetPlatform.android ? 35 : 27),
          );
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await t.pumpAndSettle();
          expect(menu, findsNothing);
          await t.tap(find.byKey(const Key('topbar-search')));
          await t.pumpAndSettle();
          expect(find.byKey(const Key('quick-switcher-input')), findsOneWidget);
          final anchor = t.getRect(find.byKey(const Key('topbar-search')));
          final overlay = t.getRect(find.byType(RaftQuickSwitcherFrame));
          expect(overlay.top, anchor.top);
          expect(overlay.center.dx, width / 2);
          expect(overlay.width, 720);
        } else if (width >= 768) {
          expect(find.byKey(const Key('rail-search')), findsOneWidget);
          expect(find.byKey(const Key('rail-workspace')), findsOneWidget);
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(platform));
    }
  }
}
