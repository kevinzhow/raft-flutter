import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  // Pinned Web CreateChannelDialog.tsx: flex-wrap gap-2 pt-1; both Button
  // size=lg, Cancel variant=ghost, submit variant=accent.
  for (final dark in [false, true]) {
    testWidgets('channel dialog uses Web action sizes and variants ($dark)', (
      t,
    ) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final name = TextEditingController();
      final description = TextEditingController();
      final search = TextEditingController();
      addTearDown(() {
        name.dispose();
        description.dispose();
        search.dispose();
      });
      var closes = 0, submits = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: RaftCreateChannelDialogView(
              name: name,
              description: description,
              search: search,
              visibility: 'public',
              onVisibilityChanged: (_) {},
              agents: const [],
              humans: const [],
              hasCandidates: false,
              isSelected: (_) => false,
              onToggle: (_) {},
              onClose: () => closes++,
              onSubmit: () => submits++,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final cancel = find.widgetWithText(RaftButton, 'Cancel');
      final create = find.widgetWithText(RaftButton, 'Create Channel');
      expect(cancel, findsOneWidget);
      expect(create, findsOneWidget);
      expect(t.widget<RaftButton>(cancel).uiVariant, RaftButtonVariant.ghost);
      expect(t.widget<RaftButton>(create).uiVariant, RaftButtonVariant.accent);
      expect(t.widget<RaftButton>(cancel).uiSize, RaftButtonSize.lg);
      expect(t.widget<RaftButton>(create).uiSize, RaftButtonSize.lg);
      expect(t.getRect(create).left - t.getRect(cancel).right, 8);
      expect(t.getSize(cancel).height, 44);
      expect(t.getSize(create).height, 44);
      await t.tap(cancel);
      await t.tap(create);
      expect(closes, 1);
      expect(submits, 1);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
}
