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

  for (final scenario in [
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
    (name: 'phone', size: const Size(390, 844), platform: TargetPlatform.iOS),
  ]) {
    testWidgets(
      '${scenario.name}: input edge and remove action remain independent',
      (t) async {
        t.view.physicalSize = scenario.size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final all = [
          TextEditingController(text: 'First'),
          TextEditingController(text: 'Second'),
        ];
        final active = [...all];
        final removed = <int>[];
        addTearDown(() {
          for (final c in all) {
            c.dispose();
          }
        });
        addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: scenario.platform),
            builder: (context, child) => RaftTextScaling(child: child!),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => RaftCreateTaskDialogView(
                  titles: active,
                  filledCount: active.length,
                  onClose: () {},
                  onSubmit: () {},
                  onAddRow: () => update(() {
                    final c = TextEditingController();
                    all.add(c);
                    active.add(c);
                  }),
                  onRemoveRow: (i) => update(() {
                    removed.add(i);
                    active.removeAt(i);
                  }),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        final field = find.byKey(const ValueKey('create-task-title-0'));
        final box = find.ancestor(
          of: field,
          matching: find.byType(RaftDialogTextInput),
        );
        final input = t.getRect(box);
        await t.tapAt(Offset(input.right - 2, input.center.dy));
        await t.pumpAndSettle();
        expect(
          removed,
          isEmpty,
          reason: 'touch expansion must not steal the input edge',
        );
        expect(
          t
              .widget<EditableText>(
                find.descendant(of: field, matching: find.byType(EditableText)),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        final remove = find.byKey(const ValueKey('create-task-remove-0'));
        await t.tap(remove);
        await t.pumpAndSettle();
        expect(removed, [0]);
        expect(active.single.text, 'Second');
        await t.tap(find.byKey(const ValueKey('create-task-add-row')));
        await t.pumpAndSettle();
        expect(active.length, 2);
        expect(t.takeException(), isNull);
      },
    );
  }
}
