import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

void windowMetrics(WidgetTester t, double bottom, {double keyboard = 0}) {
  t.view.viewPadding = FakeViewPadding(top: 59, bottom: bottom);
  t.view.padding = FakeViewPadding(top: 59, bottom: keyboard == 0 ? bottom : 0);
  t.view.viewInsets = FakeViewPadding(bottom: keyboard);
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final inset = platform == TargetPlatform.iOS ? 34.0 : 48.0;
    for (final (pack, theme) in raftThemeMatrix([
      (raftThemePackId, 'light'),
      (raftThemePackId, 'dark'),
      (elegantThemePackId, 'light'),
      (elegantThemePackId, 'dark'),
      (brutalThemePackId, 'light'),
      (brutalThemePackId, 'dark'),
    ], look: (v) => raftLookOf(v.$1))) {
      testWidgets(
        '$platform $pack $theme root controls clear the system gesture area',
        (t) async {
          addTearDown(t.view.reset);
          windowMetrics(t, inset);
          final f = RootFixture();
          await f.mount(
            t,
            theme,
            390,
            uri: Uri.parse('/s/alpha'),
            preferences: {appearanceThemeKey: pack},
          );
          final w = f.workspace(t);
          final nav = find.byKey(const Key('workspace-mobile-navigation'));
          final screenBottom = t.view.physicalSize.height;
          final tokens = RaftTokens.of(t.element(nav));
          final floating =
              tokens.option('mobileNav.style', or: 'docked') ==
              'floatingCapsule';

          void expectBarClearance() {
            expect(t.getRect(nav).bottom, closeTo(screenBottom - inset, .01));
            for (final id in ['home', 'tasks', 'members', 'settings']) {
              expect(
                t.getRect(find.byKey(Key('mobile-tab-$id'))).bottom,
                lessThanOrEqualTo(screenBottom - inset),
              );
            }
            final surface = find.byKey(
              ValueKey(
                floating
                    ? 'mobile-nav-source-capsule'
                    : 'mobile-nav-source-docked',
              ),
            );
            expect(
              t.getRect(surface).bottom,
              closeTo(screenBottom - inset - (floating ? 8 : 0), .01),
              reason:
                  'Only the floating capsule leaves a gap above the safe area.',
            );
          }

          expectBarClearance();
          final sidebar = find.byKey(const Key('workspace-sidebar'));
          expect(
            t.getRect(sidebar).bottom,
            floating ? screenBottom : t.getRect(nav).top,
          );
          if (floating) {
            // The overlaid list retains scroll clearance for the capsule.
            final sliver = t.widget<CustomScrollView>(sidebar).slivers.first;
            expect(
              (sliver as SliverPadding).padding
                  .resolve(TextDirection.ltr)
                  .bottom,
              68 + inset,
            );
          }

          // The keyboard covers the tab bar rather than lifting it. Its dismissal
          // restores the same geometry, with the safe inset consumed once.
          windowMetrics(t, inset, keyboard: 300);
          await t.pump();
          expectBarClearance();
          windowMetrics(t, inset);
          await t.pump();
          expectBarClearance();

          for (final root in ['tasks', 'members', 'settings']) {
            await t.tap(find.byKey(Key('mobile-tab-$root')));
            await f.flush(t);
            await t.pump(const Duration(milliseconds: 500));
            expectBarClearance();
          }

          w.navigation.navigate(RaftLocation.parse('/s/alpha/channel/ca'));
          w.notifyListeners();
          await f.flush(t);
          await t.pump(const Duration(milliseconds: 500));
          expect(nav, findsNothing);
          final editor = find.descendant(
            of: find.byType(RaftComposer),
            matching: find.byType(EditableText),
          );
          expect(editor, findsOneWidget);
          expect(
            t.getRect(editor).bottom,
            lessThanOrEqualTo(screenBottom - inset),
            reason: 'A detail composer must also clear the home indicator.',
          );
          windowMetrics(t, inset, keyboard: 300);
          await t.pump();
          expect(
            t.getRect(editor).bottom,
            lessThanOrEqualTo(screenBottom - 300),
            reason: 'The keyboard must not add a second safe-area gap.',
          );
          await f.close(t);
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
