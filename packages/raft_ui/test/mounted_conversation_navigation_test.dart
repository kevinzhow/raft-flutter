import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final density in RaftDensity.values) {
      testWidgets(
        '$family/$dark/$density channel slot and count stay source-specific',
        (tester) async {
          var activations = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
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
          final tokens = raftTheme(family, dark: dark).extension<RaftTokens>()!;
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
          expect(
            tester.widget<RaftControl>(control).visualHeight,
            tokens.brutal ? 32 : 30,
          );
          expect(
            tester.getSize(control).height,
            density == RaftDensity.touch
                ? 48
                : tokens.brutal
                ? 32
                : 30,
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
          expect(
            decoration.color,
            family == RaftFamily.brutal
                ? tokens.colors['color-brutal-pink']
                : tokens.colors['accent-soft'],
          );
          expect(decoration.borderRadius, BorderRadius.circular(4));
          expect(
            container.padding,
            EdgeInsets.symmetric(
              horizontal: family == RaftFamily.brutal ? 6 : 4,
              vertical: family == RaftFamily.brutal ? 2 : 0,
            ),
          );
          final count = tester.widget<Text>(
            find.descendant(of: badge, matching: find.text('99+')),
          );
          expect(
            count.style!.color,
            family == RaftFamily.brutal
                ? Colors.white
                : tokens.colors['accent-strong'],
          );
          expect(
            count.style!.fontWeight,
            family == RaftFamily.brutal ? FontWeight.w700 : FontWeight.w400,
          );
          expect(count.style!.fontFeatures, const [
            FontFeature.tabularFigures(),
          ]);
          final dmIcon = tester.widget<RaftIcon>(
            find.descendant(
              of: find.byKey(const ValueKey('dm')),
              matching: find.byType(RaftIcon),
            ),
          );
          expect(dmIcon.size, family == RaftFamily.brutal ? 12 : 18);
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
          expect(genericIcon.size, family == RaftFamily.brutal ? 12 : 18);
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
      );
    }
    testWidgets(
      '$family/$dark unmounted generic channel slot is distinct and zero badge is absent',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
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
        expect(icon.size, family == RaftFamily.brutal ? 12 : 14);
        expect(icon.strokeWidth, 1.5);
        expect(find.byType(RaftConversationUnreadCount), findsNothing);
        final tokens = raftTheme(family, dark: dark).extension<RaftTokens>()!;
        expect(
          RaftConversationNavigationRecipe(
            tokens,
            kind: RaftConversationNavKind.directMessage,
          ).glyphSlotSize,
          isNull,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark selected channel does not manufacture unread emphasis',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
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
                      label: 'Count-only DM',
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
        expect(
          tester.widget<Text>(find.text('Count-only DM')).style!.fontSize,
          family == RaftFamily.brutal ? 14 : 13,
        );
        expect(find.byType(RaftConversationUnreadCount), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  // Actual compiled source CSS measurements, not inferred utility order:
  // short mobile, tall mobile, and wide desktop vary independently.
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final viewport in [
      const Size(390, 480),
      const Size(390, 720),
      const Size(1280, 720),
    ]) {
      testWidgets('$family/$dark compiled channel cadence $viewport', (
        tester,
      ) async {
        final expected = family == RaftFamily.brutal
            ? (viewport.width < 768 && viewport.height > 600 ? 40.0 : 32.0)
            : (viewport.height <= 600 ? 30.0 : 34.0);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
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
                              conversationKind: RaftConversationNavKind.channel,
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
        expect(a.height, expected);
        expect(b.top - a.top, expected);
        expect(
          tester.getSize(find.byType(RaftConversationUnreadCount).first).height,
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
      });
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
