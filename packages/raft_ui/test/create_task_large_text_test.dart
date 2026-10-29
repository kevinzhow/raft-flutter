import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/raft_ui/SpaceGrotesk')
      ..addFont(
        rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
      );
    await loader.load();
  });

  final scenarios = [
    (
      name: 'short phone',
      size: const Size(390, 500),
      platform: TargetPlatform.iOS,
    ),
    (
      name: 'narrow desktop',
      size: const Size(390, 844),
      platform: TargetPlatform.linux,
    ),
    (
      name: 'foldable portrait',
      size: const Size(856, 944),
      platform: TargetPlatform.android,
    ),
    (
      name: 'foldable landscape',
      size: const Size(944, 856),
      platform: TargetPlatform.android,
    ),
  ];

  for (final scenario in scenarios) {
    for (final dark in [false, true]) {
      for (final scale in [1.3, 2.0, 3.1]) {
        for (final count in [1, 6]) {
          testWidgets(
            '${scenario.name}/$dark/$scale/$count: task actions are reachable',
            (t) async {
              t.view.physicalSize = scenario.size;
              t.view.devicePixelRatio = 1;
              t.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(t.view.reset);
              addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
              final titles = List.generate(
                count,
                (i) => TextEditingController(text: 'Task $i'),
              );
              addTearDown(() {
                for (final controller in titles) {
                  controller.dispose();
                }
              });
              addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
              var closed = 0;
              var submitted = 0;
              await t.pumpWidget(
                MaterialApp(
                  theme: raftTheme(dark: dark)
                      .copyWith(platform: scenario.platform),
                  builder: (context, child) => RaftTextScaling(child: child!),
                  home: Scaffold(
                    body: RaftCreateTaskDialogView(
                      titles: titles,
                      filledCount: titles.length,
                      onClose: () => closed++,
                      onSubmit: () => submitted++,
                      onAddRow: () {},
                      onRemoveRow: (_) {},
                    ),
                  ),
                ),
              );
              await t.pumpAndSettle();
              expect(
                t.takeException(),
                isNull,
                reason: 'No content may overflow at large text size',
              );
              final cancel = find.byKey(const ValueKey('create-task-cancel'));
              final submit = find.byKey(const ValueKey('create-task-submit'));
              for (final button in [cancel, submit]) {
                await t.ensureVisible(button);
                await t.pumpAndSettle();
                expect(button.hitTestable(), findsOneWidget);
                final rect = t.getRect(button);
                for (final x in [rect.left + 2, rect.right - 2]) {
                  await t.tapAt(Offset(x, rect.center.dy));
                  await t.pump();
                }
              }
              expect(closed, 2);
              expect(submitted, 2);
              expect(t.takeException(), isNull);
              await t.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }
  }
}
