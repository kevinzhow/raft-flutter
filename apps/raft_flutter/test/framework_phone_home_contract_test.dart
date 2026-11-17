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
        // Web v1.24 WorkspaceButton: on-frame md (36 tall) with the avatar,
        // the name and the chevron; the title colour is the button's own.
        final selector = find.byKey(const Key('mobile-server-selector'));
        final control = find.descendant(
          of: selector,
          matching: find.byType(RaftButton),
        );
        expect(t.getSize(control).height, 36);
        expect(
          find.descendant(of: selector, matching: find.byType(RaftAvatarSlot)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: selector,
            matching: find.byWidgetPredicate(
              (w) => w is RaftIcon && w.glyph == RaftGlyph.chevronDown,
            ),
          ),
          findsOneWidget,
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
        // Web v1.24: Search and Activity are bottom-bar tabs, Home lists
        // neither (SidebarHomeEntries: Saved, Drafts, the assistant).
        expect(find.byKey(const Key('nav-search')), findsNothing);
        expect(find.byKey(const Key('nav-activity')), findsNothing);
        final saved = t.getRect(control('nav-saved'));
        // Source Sidebar.tsx's block-flow my-px: adjacent margins collapse
        // to one pixel. Tall rows are 46, short rows are 44.
        expect(saved.height, height <= 600 ? 44.0 : 46.0);
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
          Rect.fromLTWH(337, height <= 600 ? 1.5 : 5.5, 44, 44),
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
