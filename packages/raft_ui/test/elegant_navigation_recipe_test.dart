import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    Future<void> mount(
      WidgetTester tester,
      Widget child, {
      double height = 900,
      double width = 1280,
    }) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: RaftDensityScope(density: RaftDensity.desktop, child: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      '[K09b] $family/$dark rail server uses actual AvatarSlot shape at tall and compact heights',
      (tester) async {
        var workspaceCalls = 0;
        for (final height in [900.0, 568.0]) {
          await mount(
            tester,
            SizedBox(
              width: family == RaftFamily.brutal ? 64 : 56,
              child: RaftWorkspaceRail(
                destinations: const [
                  RaftRailDestination(
                    id: 'chat',
                    label: 'Chat',
                    glyph: RaftGlyph.messageSquare,
                  ),
                ],
                selected: 'chat',
                onSelected: (_) {},
                workspaceName: 'Visual Server',
                onWorkspace: () => workspaceCalls++,
              ),
            ),
            height: height,
          );
          final frame = find.byType(RaftMountedAvatarFrame);
          final extent = height <= 600 ? 32.0 : 36.0;
          expect(tester.getSize(frame), Size.square(extent));
          final decorated = tester.widget<DecoratedBox>(
            find.byKey(const ValueKey('mounted-avatar-frame')),
          );
          final decoration = decorated.decoration as BoxDecoration;
          expect(
            decoration.borderRadius,
            BorderRadius.circular(family == RaftFamily.brutal ? 0 : extent / 2),
          );
          expect(decoration.border!.top.width, 2);
          expect(
            decoration.border!.top.color,
            family == RaftFamily.brutal ? Colors.black : Colors.transparent,
          );
          final initial = tester.widget<Text>(find.text('V'));
          expect(initial.style!.fontSize, 14);
          expect(initial.style!.fontWeight, FontWeight.w700);
          await tester.tap(find.byKey(const Key('rail-workspace')));
          await tester.pump();
        }
        expect(workspaceCalls, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[K09c] $family/$dark explicit rail numeric unread uses AppRailItemBadge recipe',
      (tester) async {
        await mount(
          tester,
          SizedBox(
            width: family == RaftFamily.brutal ? 64 : 56,
            child: RaftWorkspaceRail(
              destinations: const [
                RaftRailDestination(
                  id: 'chat',
                  label: 'Chat',
                  glyph: RaftGlyph.messageSquare,
                ),
                RaftRailDestination(
                  id: 'activity',
                  label: 'Activity',
                  glyph: RaftGlyph.activity,
                  unread: 12,
                ),
              ],
              selected: 'chat',
              onSelected: (_) {},
              workspaceName: 'Visual Server',
              onWorkspace: () {},
            ),
          ),
        );
        expect(find.byType(Badge), findsNothing);
        expect(find.byType(RaftRailUnreadCount), findsOneWidget);
        final tokens = RaftTokens.of(
          tester.element(find.byType(RaftRailUnreadCount)),
        );
        final recipeBox = tester.widget<RaftRecipeBox>(
          find.descendant(
            of: find.byType(RaftRailUnreadCount),
            matching: find.byType(RaftRecipeBox),
          ),
        );
        final expected = RaftAppRailRecipe.resolve(
          theme: tokens.recipeTheme,
          states: tokens.recipeStates(),
          tokens: tokens.recipeTokens,
        ).itemBadge;
        expect(recipeBox.style.text(tokens.recipeTokens).fontSize, 10);
        expect(
          recipeBox.style.text(tokens.recipeTokens).fontWeight,
          expected.text(tokens.recipeTokens).fontWeight,
        );
        expect(
          recipeBox.style.decoration(tokens.recipeTokens).color,
          expected.decoration(tokens.recipeTokens).color,
        );
        expect(
          recipeBox.style.decoration(tokens.recipeTokens).borderRadius,
          expected.decoration(tokens.recipeTokens).borderRadius,
        );
        final counter = tester.getRect(find.byType(RaftRailUnreadCount));
        final surface = tester.getRect(
          find.byKey(const ValueKey('rail-activity')),
        );
        // Absolute CSS offsets use the button's padding box, inside its border.
        final border = family == RaftFamily.brutal ? 2 : 1;
        expect(counter.right, surface.right - border + 4);
        expect(counter.top, surface.top + border - 4);
        expect(
          tester
              .getSemantics(find.byKey(const ValueKey('rail-activity')))
              .toString(),
          contains('12'),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '[K09d] $family/$dark actual conversation tabs retain Source heights and painted underline through keyboard selection',
      (tester) async {
        for (final width in [390.0, 1280.0]) {
          final boundary = GlobalKey();
          var selected = RaftConversationTabId.chat;
          await mount(
            tester,
            Column(
              children: [
                RepaintBoundary(
                  key: boundary,
                  child: StatefulBuilder(
                    builder: (context, update) => RaftConversationTabs(
                      tabs: const [
                        RaftConversationTab(
                          id: RaftConversationTabId.chat,
                          label: 'Chat',
                        ),
                        RaftConversationTab(
                          id: RaftConversationTabId.files,
                          label: 'Files',
                        ),
                      ],
                      value: selected,
                      onChanged: (value) => update(() => selected = value),
                    ),
                  ),
                ),
              ],
            ),
            width: width,
          );
          final strip = find.byType(RaftConversationTabs);
          final mobile = width < 768;
          expect(
            tester.getSize(strip).height,
            family == RaftFamily.brutal
                ? 30
                : mobile
                ? 41
                : 48,
          );
          final chat = find.byKey(const ValueKey('panel-tab-chat'));
          expect(
            tester.getSize(chat).height,
            family == RaftFamily.brutal
                ? 28
                : mobile
                ? 40
                : 28,
          );
          if (family == RaftFamily.elegant) {
            final primary = RaftTokens.of(tester.element(strip))
                .colors['primary-400']!
                .toARGB32();
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final x = tester.getRect(chat).center.dx.toInt();
            await tester.runAsync(() async {
              final image = await render.toImage();
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              final border = mobile ? 1 : 0;
              final height = mobile ? 1 : 2;
              for (
                var row = image.height - border - height;
                row < image.height - border;
                row++
              ) {
                final p = (row * image.width + x) * 4;
                expect(bytes.getUint8(p), primary >> 16 & 255);
                expect(bytes.getUint8(p + 1), primary >> 8 & 255);
                expect(bytes.getUint8(p + 2), primary & 255);
              }
              image.dispose();
            });
          }
          await tester.tap(chat);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expect(selected, RaftConversationTabId.files);
          expect(
            tester.getSize(strip).height,
            family == RaftFamily.brutal
                ? 30
                : mobile
                ? 41
                : 48,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  }
}
