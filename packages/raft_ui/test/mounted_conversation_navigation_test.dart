// Frozen a57b9dab Elegant contract. Current Raft source geometry is covered
// by framework_navigation_contract_test and framework_sidebar_phone_contract_test.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final density in RaftDensity.values) {
      testWidgets(
        '${dark ? 'dark' : 'light'}/$density channel slot and count stay source-specific',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var activations = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(
                pack: packForThemeId(elegantThemePackId),
                dark: dark,
              ),
              home: Scaffold(
                body: RaftDensityScope(
                  density: density,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 300,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RaftNavItem(
                            key: const ValueKey('channel'),
                            label: 'general 中文',
                            glyph: RaftGlyph.hash,
                            conversationKind: RaftConversationNavKind.channel,
                            unread: 104,
                            onTap: () => activations++,
                          ),
                          RaftNavItem(
                            key: const ValueKey('dm'),
                            label: 'Peer',
                            glyph: RaftGlyph.user,
                            conversationKind:
                                RaftConversationNavKind.directMessage,
                            unread: 1,
                            onTap: () {},
                          ),
                          RaftNavItem(
                            key: const ValueKey('generic'),
                            label: 'Management',
                            glyph: RaftGlyph.hash,
                            unread: 1,
                            onTap: () {},
                          ),
                          RaftNavItem(
                            key: const ValueKey('activity'),
                            label: 'Activity',
                            role: RaftNavItemRole.activity,
                            glyph: RaftGlyph.activity,
                            unread: 1,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final tokens = raftTheme(
            pack: packForThemeId(elegantThemePackId),
            dark: dark,
          ).extension<RaftTokens>()!;
          final channel = find.byKey(const ValueKey('channel'));
          final iconFinder = find.descendant(
            of: channel,
            matching: find.byType(RaftIcon),
          );
          final icon = tester.widget<RaftIcon>(iconFinder);
          expect(icon.size, 14);
          expect(icon.strokeWidth, 2);
          expect(tester.getSize(iconFinder), const Size(14, 14));
          final slot = find.descendant(
            of: channel,
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.width == 18 && w.height == 18,
            ),
          );
          expect(slot, findsOneWidget);
          expect(tester.getCenter(iconFinder), tester.getCenter(slot));
          expect(tester.getSemantics(channel).label, contains('general 中文'));
          expect(tester.getSemantics(channel).label, contains('104'));
          final channelTitle = tester.widget<Text>(
            find.descendant(of: channel, matching: find.text('general 中文')),
          );
          expect(channelTitle.style!.fontSize, 14);
          expect(channelTitle.style!.height, 20 / 14);
          expect(channelTitle.style!.fontWeight, FontWeight.w700);

          final control = find.descendant(
            of: channel,
            matching: find.byType(RaftControl),
          );
          // The row height is a contract token. The default (Raft) pack keeps one
          // height at every viewport and density, so read it rather than assuming
          // the 30 this asserted while the value was a single literal.
          final rowHeight = raftTheme(
            pack: packForThemeId(elegantThemePackId),
            dark: dark,
          ).extension<RaftTokens>()!.size('size.navRow', fallback: 34);
          expect(tester.widget<RaftControl>(control).visualHeight, rowHeight);
          // The row box is Web's in every density; touch only widens the hit
          // and semantics rectangle to 48dp (RaftTouchTarget).
          expect(tester.getSize(control).height, rowHeight);
          if (density == RaftDensity.touch) {
            expect(find.byType(RaftTouchTarget), findsWidgets);
          }
          final dm = find.byKey(const ValueKey('dm'));
          expect(
            tester.getRect(dm).top - tester.getRect(control).bottom,
            2,
            reason: 'Mounted SidebarItem bottom margin is separate from the row box.',
          );
          final badge = find.descendant(
            of: channel,
            matching: find.byType(RaftConversationUnreadCount),
          );
          expect(
            find.descendant(of: badge, matching: find.text('99+')),
            findsOneWidget,
          );
          expect(tester.getSize(badge).height, 16);
          final container = tester.widget<Container>(
            find.descendant(of: badge, matching: find.byType(Container)),
          );
          final decoration = container.decoration! as BoxDecoration;
          expect(decoration.color, tokens.colors['accent-soft']);
          expect(decoration.borderRadius, BorderRadius.circular(4));
          expect(
            container.padding,
            EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          );
          final count = tester.widget<Text>(
            find.descendant(of: badge, matching: find.text('99+')),
          );
          expect(count.style!.color, tokens.colors['accent-strong']);
          expect(count.style!.fontWeight, FontWeight.w400);
          expect(count.style!.fontFeatures, const [
            FontFeature.tabularFigures(),
          ]);
          final dmIcon = tester.widget<RaftIcon>(
            find.descendant(
              of: find.byKey(const ValueKey('dm')),
              matching: find.byType(RaftIcon),
            ),
          );
          expect(dmIcon.size, 18);
          final generic = find.byKey(const ValueKey('generic'));
          expect(
            find.descendant(
              of: generic,
              matching: find.byType(RaftConversationUnreadCount),
            ),
            findsNothing,
          );
          final genericIcon = tester.widget<RaftIcon>(
            find.descendant(of: generic, matching: find.byType(RaftIcon)),
          );
          expect(genericIcon.size, 18);
          final activity = tester.widget<RaftControl>(
            find.descendant(
              of: find.byKey(const ValueKey('activity')),
              matching: find.byType(RaftControl),
            ),
          );
          expect(activity.recipe, isA<RaftMountedSidebarNavigationRecipe>());
          await tester.tap(channel);
          await tester.pump();
          expect(activations, 1);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(activations, 2);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        skip: raftLookSkip(raftLookElegant),
      );
    }
    testWidgets(
      '${dark ? 'dark' : 'light'} unmounted generic channel slot is distinct and zero badge is absent',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(
              pack: packForThemeId(elegantThemePackId),
              dark: dark,
            ),
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: RaftNavItem(
                  label: 'SDK channel slot',
                  glyph: RaftGlyph.hash,
                  onTap: () {},
                  conversationKind: RaftConversationNavKind.channel,
                  channelGlyphVariant: RaftChannelGlyphVariant.genericComponent,
                ),
              ),
            ),
          ),
        );
        final icon = tester.widget<RaftIcon>(find.byType(RaftIcon));
        expect(icon.size, 14);
        expect(icon.strokeWidth, 1.5);
        expect(find.byType(RaftConversationUnreadCount), findsNothing);
        final tokens = raftTheme(
          pack: packForThemeId(elegantThemePackId),
          dark: dark,
        ).extension<RaftTokens>()!;
        expect(
          RaftConversationNavigationRecipe(
            tokens,
            kind: RaftConversationNavKind.directMessage,
          ).glyphSlotSize,
          isNull,
        );
        await tester.pumpWidget(const SizedBox());
      },
      skip: raftLookSkip(raftLookElegant),
    );
  }

  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} selected channel does not manufacture unread emphasis',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(
              pack: packForThemeId(elegantThemePackId),
              dark: dark,
            ),
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: Column(
                  children: [
                    RaftNavItem(
                      label: 'Selected channel',
                      glyph: RaftGlyph.hash,
                      conversationKind: RaftConversationNavKind.channel,
                      selected: true,
                      onTap: () {},
                    ),
                    RaftNavItem(
                      label: 'Generic selected',
                      glyph: RaftGlyph.hash,
                      selected: true,
                      onTap: () {},
                    ),
                    RaftNavItem(
                      label: 'Mounted Source DM',
                      glyph: RaftGlyph.user,
                      conversationKind: RaftConversationNavKind.directMessage,
                      unread: 1,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final selected = tester.widget<Text>(find.text('Selected channel'));
        expect(selected.style!.fontSize, 14);
        expect(selected.style!.height, 20 / 14);
        expect(selected.style!.fontWeight, FontWeight.w500);
        expect(
          tester.widget<Text>(find.text('Generic selected')).style!.fontWeight,
          FontWeight.w700,
        );
        // Source Sidebar.tsx1001 uses text-sm; the actual three-theme
        // browser capture reads 14px/20px. Only actual unread makes it bold.
        final dm = tester.widget<Text>(find.text('Mounted Source DM'));
        expect(dm.style!.fontSize, 14);
        expect(dm.style!.height, 20 / 14);
        expect(dm.style!.fontWeight, FontWeight.w700);
        expect(find.byType(RaftConversationUnreadCount), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      skip: raftLookSkip(raftLookElegant),
    );
  }

  // Actual compiled source CSS measurements, not inferred utility order:
  // short mobile, tall mobile, and wide desktop vary independently.
  for (final dark in raftThemeMatrix([false, true])) {
    for (final viewport in [
      const Size(390, 480),
      const Size(390, 720),
      const Size(1280, 720),
    ]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} compiled channel cadence $viewport',
        (tester) async {
          // Read the expectation from the theme rather than a literal: the row
          // height is a contract token now, and the default (Raft) pack keeps one
          // height at every viewport and density.
          final rowTokens = raftTheme(
            pack: packForThemeId(elegantThemePackId),
            dark: dark,
          ).extension<RaftTokens>()!;
          final expected = viewport.height <= 600
              ? rowTokens.size('size.navRowCompact', fallback: 30)
              : rowTokens.size('size.navRow', fallback: 34);
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(
                pack: packForThemeId(elegantThemePackId),
                dark: dark,
              ),
              home: MediaQuery(
                data: MediaQueryData(size: viewport),
                child: Scaffold(
                  body: RaftDensityScope(
                    density: RaftDensity.desktop,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 300,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var index = 0; index < 2; index++)
                              RaftNavItem(
                                key: ValueKey('row-$index'),
                                label: 'general $index',
                                glyph: RaftGlyph.hash,
                                conversationKind:
                                    RaftConversationNavKind.channel,
                                unread: 24,
                                onTap: () {},
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final a = tester.getRect(find.byKey(const ValueKey('row-0')));
          final b = tester.getRect(find.byKey(const ValueKey('row-1')));
          final margin = 2.0;
          expect(a.height, expected + margin);
          expect(b.top - a.top, expected + margin);
          expect(
            tester
                .getSize(
                  find.descendant(
                    of: find.byKey(const ValueKey('row-0')),
                    matching: find.byType(RaftControl),
                  ),
                )
                .height,
            expected,
          );
          expect(
            tester
                .getSize(find.byType(RaftConversationUnreadCount).first)
                .height,
            16,
          );
          final count = tester.widget<Text>(find.text('24').first);
          expect(
            count.style!.fontFamily,
            RaftTokens.of(tester.element(find.text('24').first)).bodyFont,
          );
          expect(count.style!.fontSize, 10);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        skip: raftLookSkip(raftLookElegant),
      );
    }
  }

  testWidgets(
    'GitBranch renders pinned branch stem and two open node circles',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: const SizedBox.square(
                dimension: 24,
                child: RaftIcon(
                  RaftGlyph.gitBranch,
                  size: 24,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 4);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          int alpha(int x, int y) =>
              bytes.getUint8(((y * 4) * image.width + x * 4) * 4 + 3);
          expect(alpha(6, 8), greaterThan(200)); // branch stem
          expect(
            alpha(9, 9),
            greaterThan(100),
          ); // curved branch, not a Link glyph
          expect(alpha(18, 3), greaterThan(100)); // top node ring
          expect(alpha(6, 15), greaterThan(100)); // bottom node ring
          expect(alpha(18, 6), 0); // open circle centers, unlike a filled glyph
          expect(alpha(6, 18), 0);
          expect(alpha(1, 1), 0);
        } finally {
          image.dispose();
        }
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
}
