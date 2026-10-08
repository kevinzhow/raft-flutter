import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/page_layout.dart';

void main() {
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
