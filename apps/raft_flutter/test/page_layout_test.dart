import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/page_layout.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} mobile page header renders Web\'s phone PanelHeader',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(left: 1),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 341,
                    child: RaftPageHeader(
                      title: 'Activity',
                      subtitle: '3 active · 3 unread',
                      height: 56,
                      mobile: true,
                      onBack: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = tester.getRect(find.text('Activity'));
        final subtitle = tester.getRect(find.text('3 active · 3 unread'));
        // Web below md: `--shell-header-height` (62 brutal / 56 elegant),
        // `px-5` (elegant `max-md:pl-5`), boxed PanelAction Back, gap-3
        // (elegant gap-2), title + mono/sans meta.
        expect(find.byType(RaftMobilePageHeader), findsNothing);
        expect(tester.getSize(find.byType(RaftPanelHeaderBar)).height, 56);
        final back = tester.getRect(find.byType(RaftPanelAction));
        // Web PanelAction reserves a 44px target around its 32px face.
        expect(back.size, const Size(44, 44));
        // Web mobile pl-4 minus the leading -ml-[13px].
        expect(back.left, 1 + 3);
        expect(title.left, back.right + (8));
        expect(subtitle.left, title.left);
        expect(title.height, 22);
        expect(subtitle.top, greaterThanOrEqualTo(title.bottom));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'source header geometry and typography follow the shared recipe at compact and normal heights',
    (tester) async {
      for (final size in [const Size(390, 844), const Size(957, 600)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => Align(
                  alignment: Alignment.topLeft,
                  child: RaftPageHeader(
                    title: 'Tasks',
                    variant: RaftPanelHeaderVariant.tasks,
                    subtitle: '4 channel tasks',
                    height: raftPageHeaderHeight(context),
                    icon: const RaftIcon(RaftGlyph.checkSquare),
                    mobile: size.width < RaftLayoutMetrics.desktopBreakpoint,
                  ),
                ),
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(RaftPageHeader));
        final recipe = RaftPanelHeaderRecipe(
          RaftTokens.of(context),
          variant: RaftPanelHeaderVariant.tasks,
          viewportHeight: size.height,
          mobile: size.width < RaftLayoutMetrics.desktopBreakpoint,
        );
        if (size.width < RaftLayoutMetrics.desktopBreakpoint) {
          expect(
            tester.getSize(find.byType(RaftMobilePageHeader)),
            Size(size.width, recipe.height),
          );
          // Web TasksPanel header: h-panel-header (62 Brutal / 56 Elegant /
          // 48 short viewports), px-5, Brutal soft-signal fill.
          expect(recipe.height, size.height <= 600 ? 48 : (56));
          expect(tester.widget<Text>(find.text('Tasks')).style!.fontSize, 17);
          expect(
            tester.widget<Text>(find.text('4 channel tasks')).style!.fontSize,
            12,
          );
        } else {
          expect(
            tester.getSize(find.byKey(const Key('page-header-surface'))),
            Size(size.width, recipe.height),
          );
          // Raft look: the tasks head is the shared AppPanelHeader bar (no
          // icon tile, PanelTitle 17); the recipe styles are the pre-theme
          // 16px title.
          expect(tester.widget<Text>(find.text('Tasks')).style!.fontSize, 17);
          expect(
            tester.widget<Text>(find.text('4 channel tasks')).style!.fontSize,
            recipe.subtitle.fontSize,
          );
        }
        expect(tester.takeException(), isNull);
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}
