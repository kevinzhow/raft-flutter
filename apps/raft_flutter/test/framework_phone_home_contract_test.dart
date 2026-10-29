import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mounted_message_navigation_test.dart' show pageFixture, mountPage;

// Pinned Sidebar.tsx MOBILE_WORKSPACE_PILL_CLASS and NotificationTrigger's
// mobile-navbar: the live phone Home host, including its short-height branch.
void main() {
  for (final width in [390.0, 856.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'native $width/$dark Back from notification popup keeps Home and history',
        (t) async {
          final (w, _) = await pageFixture(t);
          w.setSection('settings');
          w.setSection('home');
          await mountPage(
            t,
            w,
            dark,
            width: width,
            height: width == 390 ? 844 : 944,
            browserHost: false,
          );
          final uri = w.location.toString();
          final history = w.navigation.index;
          expect(w.section, 'home');
          await t.tap(find.byType(RaftMobileNotificationButton));
          await t.pumpAndSettle();
          expect(find.byType(RaftNotificationCenter), findsOneWidget);
          await t.binding.handlePopRoute();
          await t.pumpAndSettle();
          expect(find.byType(RaftNotificationCenter), findsNothing);
          expect(w.section, 'home');
          expect(w.location.toString(), uri);
          expect(w.navigation.index, history);
          await t.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
  for (final height in [480.0, 844.0]) {
    for (final dark in [false, true]) {
      testWidgets('phone Home $height/$dark uses the source workspace title', (
        t,
      ) async {
        final (w, _) = await pageFixture(t);
        w.setSection('home');
        await mountPage(
          t,
          w,
          dark,
          width: 390,
          height: height,
          browserHost: true,
        );
        final selector = find.byKey(const Key('mobile-server-selector'));
        final control = find.descendant(
          of: selector,
          matching: find.byType(RaftControl),
        );
        expect(t.widget<RaftControl>(control).visualHeight, 36);
        final text = t.widget<Text>(
          find.descendant(of: selector, matching: find.text(w.server!.name)),
        );
        expect(text.style!.fontSize, 17);
        expect(text.style!.height, 22 / 17);
        final tokens = RaftTokens.of(t.element(selector));
        expect(
          text.style!.color,
          tokens.colors[height <= 600 ? 'foreground-on-frame' : 'brand-400'],
        );
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
      testWidgets('phone Home $height/$dark collapses adjacent entry margins', (
        t,
      ) async {
        final (w, _) = await pageFixture(t);
        w.setSection('home');
        await mountPage(
          t,
          w,
          dark,
          width: 390,
          height: height,
          browserHost: true,
        );
        Finder control(String key) => find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(RaftControl),
        );
        final search = t.getRect(control('nav-search'));
        final activity = control('nav-activity');
        final saved = t.getRect(control('nav-saved'));
        // Source Sidebar.tsx's block-flow my-px: adjacent margins collapse
        // to one pixel. Tall rows are 46, short rows are 44.
        final step = height <= 600 ? 45.0 : 47.0;
        if (activity.evaluate().isNotEmpty) {
          expect(t.getRect(activity).top - search.top, step);
          expect(saved.top - search.top, step * 2);
        } else {
          expect(saved.top - search.top, step);
        }
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
      testWidgets('phone Home $height/$dark places the full frame bell', (
        t,
      ) async {
        final (w, _) = await pageFixture(t);
        w.setSection('home');
        await mountPage(
          t,
          w,
          dark,
          width: 390,
          height: height,
          browserHost: true,
        );
        final bell = find.byType(RaftMobileNotificationButton);
        expect(bell, findsOneWidget);
        expect(
          t.getRect(bell),
          Rect.fromLTWH(343, height <= 600 ? 1.5 : 5.5, 44, 44),
        );
        final glyph = find.descendant(
          of: bell,
          matching: find.byWidgetPredicate(
            (w) => w is RaftIcon && w.glyph == RaftGlyph.bell,
          ),
        );
        expect(t.widget<RaftIcon>(glyph).size, 22);
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }
  }
}
