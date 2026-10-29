import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/mobile_tabbar_config_previews.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const preview = Key('mobile-tabbar-preview');
const screen = Size(390, 844);

void metrics(WidgetTester t, double inset, {double keyboard = 0}) {
  t.view.physicalSize = screen;
  t.view.devicePixelRatio = 1;
  t.view.viewPadding = FakeViewPadding(bottom: inset);
  t.view.padding = FakeViewPadding(bottom: keyboard == 0 ? inset : 0);
  t.view.viewInsets = FakeViewPadding(bottom: keyboard);
}

Finder previewNav() => find.descendant(
  of: find.byKey(preview),
  matching: find.byType(RaftMobileNav),
);

void main() {
  for (final (pack, dark, floating) in raftThemeMatrix([
    (raftThemePackId, false, false),
    (raftThemePackId, true, false),
    (elegantThemePackId, false, true),
    (elegantThemePackId, true, true),
    (brutalThemePackId, false, false),
    (brutalThemePackId, true, true),
  ], look: (v) => raftLookOf(v.$1))) {
    for (final inset in [0.0, 24.0, 48.0]) {
      testWidgets(
        '$pack ${dark ? 'dark' : 'light'} preview clears $inset system inset and IME',
        (t) async {
          addTearDown(t.view.reset);
          metrics(t, inset);
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(
                pack: packForThemeId(pack),
                dark: dark,
              ).copyWith(platform: TargetPlatform.android),
              home: Scaffold(body: mobileTabbarConfigDefaultPreview()),
            ),
          );
          final nav = previewNav();
          expect(t.getRect(nav).bottom, screen.height - inset);
          final navHeight = t.getSize(nav).height;
          if (pack == raftThemePackId) {
            expect(
              navHeight,
              52,
              reason: 'Preview matches the real docked bar; no capsule gap.',
            );
          }
          expect(
            t
                .getRect(
                  find.byKey(
                    ValueKey(
                      floating
                          ? 'mobile-nav-source-capsule'
                          : 'mobile-nav-source-docked',
                    ),
                  ),
                )
                .bottom,
            screen.height - inset - (floating ? 16 : 0),
          );

          // A pinned preview leaves the scrollable form usable on short bodies.
          await t.tap(
            find.byKey(const ValueKey('mobile-tabbar-switch-activity')),
          );
          await t.pump();
          expect(
            t.widget<RaftMobileNav>(nav).items.map((i) => i.id),
            contains('activity'),
          );
          expect(t.getRect(nav).bottom, screen.height - inset);
          expect(t.getSize(nav).height, navHeight);
          // Scaffold has already consumed the IME: no second navigation inset.
          metrics(t, inset, keyboard: 300);
          await t.pump();
          expect(t.getRect(nav).bottom, screen.height - 300);
          expect(t.getSize(nav).height, navHeight);
          metrics(t, inset);
          await t.pump();
          expect(t.getRect(nav).bottom, screen.height - inset);
          expect(t.takeException(), isNull);
        },
      );
    }
    testWidgets(
      '$pack ${dark ? 'dark' : 'light'} parent SafeArea consumes the inset once',
      (t) async {
        addTearDown(t.view.reset);
        metrics(t, 48);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(pack), dark: dark),
            home: Scaffold(
              body: SafeArea(
                top: false,
                child: mobileTabbarConfigDefaultPreview(),
              ),
            ),
          ),
        );
        expect(t.getRect(previewNav()).bottom, screen.height - 48);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '$pack ${dark ? 'dark' : 'light'} dock paints to the edge with matching icon contrast',
      (t) async {
        addTearDown(t.view.reset);
        metrics(t, 48);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(pack), dark: dark),
            home: Scaffold(body: mobileTabbarConfigDefaultPreview()),
          ),
        );
        final dock = find.ancestor(
          of: find.byKey(preview),
          matching: find.byType(RaftBottomInsetSurface),
        );
        expect(dock, findsOneWidget);
        expect(t.getRect(dock).bottom, screen.height);
        expect(t.getRect(previewNav()).bottom, screen.height - 48);
        final style = t
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.descendant(
                of: dock,
                matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
              ),
            )
            .value;
        expect(style.systemNavigationBarColor, Colors.transparent);
        expect(style.systemNavigationBarContrastEnforced, isFalse);
        expect(
          style.systemNavigationBarIconBrightness,
          dark ? Brightness.light : Brightness.dark,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
