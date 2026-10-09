import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/page_layout.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark canonical mobile header matches measured source line boxes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
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
                      height: family == RaftFamily.brutal ? 62 : 56,
                      mobile: true,
                      leading: RaftPanelBackAction(onPressed: () {}),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Finder line(String label) =>
            find.byWidgetPredicate((w) => w is RaftCssText && w.data == label);
        final title = tester.getRect(line('Activity'));
        final subtitle = tester.getRect(line('3 active · 3 unread'));
        // Actual Source PanelHeader at the original 342px Activity fixture.
        expect(title.left, family == RaftFamily.brutal ? 59 : 61);
        expect(title.top, family == RaftFamily.brutal ? 12 : 7.375);
        expect(title.height, family == RaftFamily.brutal ? 20 : 21.25);
        expect(subtitle.top, family == RaftFamily.brutal ? 32 : 32.625);
        expect(subtitle.height, family == RaftFamily.brutal ? 16 : 15);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'source header geometry and typography follow the shared recipe at compact and normal heights',
    (tester) async {
      for (final family in RaftFamily.values) {
        for (final size in [const Size(390, 844), const Size(957, 600)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family),
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
          expect(
            tester.getSize(find.byKey(const Key('page-header-surface'))),
            Size(size.width, recipe.height),
          );
          expect(tester.widget<Text>(find.text('Tasks')).style, recipe.title);
          expect(
            tester.widget<Text>(find.text('4 channel tasks')).style,
            recipe.subtitle,
          );
          expect(tester.takeException(), isNull);
        }
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}
