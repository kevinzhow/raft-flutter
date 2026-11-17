import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (size, platform) in [
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
    (const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets(
      'member choices support checkbox semantics and keyboard toggle at $size',
      (t) async {
        final search = TextEditingController();
        addTearDown(search.dispose);
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var selected = false;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: RaftChannelMembersModal(
                  page: true,
                  channelName: 'work',
                  search: search,
                  addView: true,
                  hasCandidates: true,
                  onClose: () {},
                  candidateAgents: const [
                    RaftPickerItem(
                      key: 'agent:a',
                      label: 'Assistant',
                      avatar: SizedBox(width: 28, height: 28),
                    ),
                  ],
                  isChecked: (_) => selected,
                  onToggle: (_) => setState(() => selected = !selected),
                ),
              ),
            ),
          ),
        );
        final row = find.byKey(const ValueKey('add-candidate-agent:a'));
        final semantics = t.ensureSemantics();
        expect(
          t.getSemantics(row).flagsCollection.isChecked,
          CheckedState.isFalse,
        );
        await t.tap(row);
        await t.pump();
        expect(selected, isTrue);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(selected, isFalse);
        await t.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'member picker always offers search and clears it through its visible button',
    (t) async {
      final search = TextEditingController();
      addTearDown(search.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftMemberPickerContent(
              search: search,
              agents: const [
                RaftPickerItem(
                  key: 'agent:a',
                  label: 'Assistant',
                  avatar: SizedBox(width: 28, height: 28),
                ),
              ],
              humans: const [],
              hasCandidates: true,
              isSelected: (_) => false,
              onToggle: (_) {},
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), 'missing');
      await t.pumpAndSettle();
      final clear = find.byTooltip('Clear search');
      expect(clear, findsOneWidget);
      await t.tap(clear);
      await t.pumpAndSettle();
      expect(search.text, isEmpty);
      expect(find.text('Assistant'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'chosen member rows stay available while searching and deselecting',
    (t) async {
      final search = TextEditingController();
      addTearDown(search.dispose);
      var selected = true;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: RaftMemberPickerContent(
                search: search,
                agents: const [
                  RaftPickerItem(
                    key: 'agent:a',
                    label: 'Assistant',
                    avatar: SizedBox(width: 28, height: 28),
                  ),
                ],
                humans: const [],
                hasCandidates: true,
                isSelected: (_) => selected,
                onToggle: (_) => setState(() => selected = !selected),
              ),
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), 'missing');
      await t.pumpAndSettle();
      expect(find.text('Assistant'), findsOneWidget);
      expect(find.text('No members match "missing"'), findsOneWidget);
      await t.tap(find.text('Assistant'));
      await t.pumpAndSettle();
      expect(selected, false);
      expect(find.text('Assistant'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'different');
      await t.pumpAndSettle();
      expect(find.text('Assistant'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}
