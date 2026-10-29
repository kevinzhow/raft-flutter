import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Web db5e399f / raft-ui 0.7.0, actual MainLayout desktop-shell DOM:
// rail 57px including its seam, controls 40px, glyphs 20px.
void main() {
  for (final dark in [false, true]) {
    Future<void> rail(
      WidgetTester t, {
      VoidCallback? activate,
      Widget? footer,
    }) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: const ValueKey('frame-paint'),
                child: Builder(
                  builder: (context) => SizedBox(
                    width: RaftLayoutMetrics.railWidth(
                      RaftTokens.of(context),
                      800,
                    ),
                    child: RaftWorkspaceRail(
                      workspaceName: 'Visual',
                      onWorkspace: () {},
                      selected: 'chat',
                      destinations: const [
                        RaftRailDestination(
                          id: 'chat',
                          label: 'Chat',
                          glyph: RaftGlyph.messageSquare,
                        ),
                      ],
                      onSelected: (_) => activate?.call(),
                      footer: footer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('Raft $dark mounted rail geometry matches source frame', (
      t,
    ) async {
      var calls = 0;
      await rail(t, activate: () => calls++);
      expect(t.getSize(find.byType(RaftWorkspaceRail)).width, 57);
      final button = find.byKey(const ValueKey('rail-chat'));
      expect(t.getRect(button), const Rect.fromLTWH(8, 66, 40, 40));
      final glyph = find.descendant(
        of: button,
        matching: find.byType(RaftIcon),
      );
      expect(t.widget<RaftIcon>(glyph.first).size, 20);
      await t.tapAt(t.getCenter(button));
      expect(calls, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Raft $dark actual rail paint uses frame and active surface', (
      t,
    ) async {
      await rail(t);
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('frame-paint')),
      );
      final pixels = await t.runAsync(() async {
        final image = await boundary.toImage();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        List<int> sample(int x, int y) =>
            data.buffer.asUint8List((y * image.width + x) * 4, 4).toList();
        final result = [sample(2, 400), sample(20, 70)];
        image.dispose();
        return result;
      });
      expect(pixels![0], dark ? [13, 13, 11, 255] : [255, 212, 64, 255]);
      expect(pixels[1], dark ? [255, 212, 64, 255] : [255, 255, 255, 255]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets(
      'Raft $dark footer geometry and activation match the mounted source',
      (t) async {
        final calls = <String>[];
        await rail(
          t,
          footer: RaftWorkspaceRailFooter(
            children: [
              for (final (label, glyph) in [
                ('Notifications', RaftGlyph.bell),
                ('Help', RaftGlyph.circleHelp),
                ('Settings', RaftGlyph.settings),
              ])
                RaftWorkspaceRailAction(
                  label: label,
                  glyph: glyph,
                  onPressed: () => calls.add(label),
                ),
            ],
          ),
        );
        final actions = find.descendant(
          of: find.byType(RaftWorkspaceRailFooter),
          matching: find.byType(RaftWorkspaceRailAction),
        );
        expect(actions, findsNWidgets(3));
        for (var i = 0; i < 3; i++) {
          expect(
            t.getRect(actions.at(i)),
            Rect.fromLTWH(8, 660 + i * 46, 40, 40),
          );
          final glyph = find.descendant(
            of: actions.at(i),
            matching: find.byType(RaftIcon),
          );
          expect(t.widget<RaftIcon>(glyph.first).size, 20);
          await t.tapAt(t.getCenter(actions.at(i)));
        }
        expect(calls, ['Notifications', 'Help', 'Settings']);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('Raft $dark notification rail trigger shares the 20px glyph', (
      t,
    ) async {
      await rail(
        t,
        footer: RaftWorkspaceRailFooter(
          children: [
            RaftMobileNotificationButton(rail: true, onPressed: () {}),
          ],
        ),
      );
      final glyph = find.descendant(
        of: find.byType(RaftMobileNotificationButton),
        matching: find.byType(RaftIcon),
      );
      expect(t.widget<RaftIcon>(glyph.first).size, 20);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Raft $dark rail attention keeps the original icon unmasked', (
      t,
    ) async {
      await rail(
        t,
        footer: RaftWorkspaceRailFooter(
          children: [
            RaftWorkspaceRailAction(
              label: 'Help',
              glyph: RaftGlyph.circleHelp,
              attention: true,
              onPressed: () {},
            ),
          ],
        ),
      );
      expect(find.byKey(const ValueKey('rail-attention-mask')), findsNothing);
      expect(
        t.getSize(find.byKey(const ValueKey('rail-attention-indicator'))),
        const Size(8, 8),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Raft $dark workspace fallback is the source ink tile', (
      t,
    ) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final menu = RaftMenuController();
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: const ValueKey('server-paint'),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: RaftServerSwitcher(
                    controller: menu,
                    workspaceName: 'Visual',
                    label: 'Switch Server',
                    rows: const [],
                    actions: const [],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(t.getSize(find.byType(RaftAvatarSlot)), const Size(35, 35));
      final initial = t.widget<Text>(find.text('V'));
      expect(initial.style!.fontSize, 15);
      expect(initial.style!.color, const Color(0xffffd440));
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('server-paint')),
      );
      final pixel = await t.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final result = bytes.buffer
            .asUint8List((14 * image.width + 20) * 4, 4)
            .toList();
        image.dispose();
        return result;
      });
      expect(pixel, [20, 17, 17, 255]);
      await t.pumpWidget(const SizedBox());
      menu.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Raft $dark saved entry retains mounted 36px box', (t) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 223,
                child: RaftNavItem(
                  label: 'Saved',
                  glyph: RaftGlyph.bookmark,
                  onTap: () {},
                  count: 5,
                  role: RaftNavItemRole.saved,
                ),
              ),
            ),
          ),
        ),
      );
      expect(t.getSize(find.byType(RaftNavItem)), const Size(223, 38));
      final control = t.widget<RaftControl>(find.byType(RaftControl));
      expect(control.visualHeight, 36);
      expect(control.recipe!.textStyle.fontSize, 15);
      expect(t.widget<RaftIcon>(find.byType(RaftIcon)).size, 16);
      expect(t.getTopLeft(find.text('Saved')).dx, 36);
      expect(t.getTopRight(find.text('5')).dx, 212);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets(
      'Raft $dark conversation row uses mounted typography and active paint',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: const ValueKey('row-paint'),
                  child: SizedBox(
                    width: 223,
                    child: RaftNavItem(
                      label: 'design',
                      glyph: RaftGlyph.hash,
                      onTap: () {},
                      selected: true,
                      unread: 12,
                      conversationKind: RaftConversationNavKind.channel,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(t.getSize(find.byType(RaftNavItem)), const Size(223, 37));
        final title = t.widget<Text>(find.text('design'));
        expect(title.style!.fontSize, 15);
        expect(title.style!.height, 20 / 15);
        expect(t.widget<RaftIcon>(find.byType(RaftIcon).first).size, 16);
        final count = t.getSize(find.byType(RaftSidebarUnreadCount));
        expect(count.height, 20);
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('row-paint')),
        );
        final pixel = await t.runAsync(() async {
          final image = await boundary.toImage();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final result = data.buffer
              .asUint8List((4 * image.width + 100) * 4, 4)
              .toList();
          image.dispose();
          return result;
        });
        expect(pixel, [255, 212, 64, 255]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'Raft $dark section controls keep the source header height and edge hits',
      (t) async {
        var actions = 0;
        var disclosures = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 223,
                  child: RaftSidebarSectionHeader(
                    label: 'Pinned',
                    count: 2,
                    expanded: true,
                    onExpandedChanged: (_) => disclosures++,
                    disclosureKey: const ValueKey('disclosure'),
                    actions: [
                      for (final label in ['Sort', 'Add'])
                        RaftSidebarSectionAction(
                          label: label,
                          glyph: RaftGlyph.plus,
                          testKey: ValueKey(label),
                          onPressed: () => actions++,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          t.getSize(find.byType(RaftSidebarSectionHeader)),
          const Size(223, 40),
        );
        final first = t.getRect(find.byKey(const ValueKey('Sort')));
        final second = t.getRect(find.byKey(const ValueKey('Add')));
        expect(first, const Rect.fromLTWH(155, 11, 28, 28));
        expect(second, const Rect.fromLTWH(187, 11, 28, 28));
        final disclosure = t.getRect(find.byKey(const ValueKey('disclosure')));
        expect(disclosure, const Rect.fromLTWH(8, 16, 139, 18));
        expect(
          t.getTopLeft(find.text('2')).dx -
              t.getTopRight(find.text('Pinned')).dx,
          6,
        );
        await t.tapAt(first.topLeft + const Offset(2, 2));
        await t.tapAt(second.bottomRight - const Offset(2, 2));
        expect(actions, 2);
        expect(disclosures, 0);
        await t.tapAt(disclosure.center);
        expect(disclosures, 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'Raft $dark sidebar heading and disclosure preserve source type',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: 240,
                child: Column(
                  children: [
                    const RaftChatSidebarHeading(label: 'Chat'),
                    RaftSidebarSectionHeader(
                      label: 'Pinned',
                      count: 2,
                      expanded: true,
                      onExpandedChanged: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final title = t.widget<Text>(find.text('Chat'));
        expect(title.style!.fontSize, 17);
        expect(title.style!.height, 22 / 17);
        final section = t.widget<Text>(find.text('Pinned'));
        expect(section.style!.fontSize, 13);
        expect(section.style!.height, 18 / 13);
        expect(section.style!.fontWeight, FontWeight.w700);
        final count = t.widget<Text>(find.text('2'));
        expect(count.style!.fontWeight, FontWeight.w400);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }
}
