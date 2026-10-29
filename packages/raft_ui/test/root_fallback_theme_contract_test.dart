import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final themeId in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    testWidgets('$themeId preserves fallback copy and reload action', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      var reloaded = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(themeId)),
          home: RaftRootErrorFallback(
            message: 'Test error',
            onReload: () => reloaded++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Test error'), findsOneWidget);
      expect(find.text('Reload app'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('root-error-reload')));
      await tester.pumpAndSettle();
      expect(reloaded, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
