import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final themeId in raftThemeMatrix([raftThemePackId])) {
    testWidgets(
      '$themeId preserves fallback copy and reload action',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1280, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
        var reloaded = 0;
        var openedHome = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(themeId)),
            home: RaftRootErrorFallback(
              message: 'Test error',
              onReload: () => reloaded++,
              onOpenHome: () => openedHome++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Test error'), findsOneWidget);
        expect(find.text('Reload app'), findsOneWidget);
        final reload = find.byKey(const ValueKey('root-error-reload'));
        final home = find.byKey(const ValueKey('root-error-open-home'));
        expect(tester.getSize(reload).height, 44);
        expect(tester.getSize(home).height, 44);
        await tester.tap(home);
        await tester.tap(reload);
        await tester.pumpAndSettle();
        expect(openedHome, 1);
        expect(reloaded, 1);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.linux,
        TargetPlatform.android,
      }),
    );
  }
}
