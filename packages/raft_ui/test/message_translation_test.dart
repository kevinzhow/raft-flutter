import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark translation status, skeleton and original', (
      t,
    ) async {
      final semantics = t.ensureSemantics();
      var toggles = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RaftMessageTranslationSkeleton(fontSize: 16),
                RaftMessageTranslationStatus(
                  tone: RaftMessageTranslationTone.normal,
                  actionLabel: 'Show original',
                  tooltip: 'Translated. Show original',
                  onAction: () => toggles++,
                ),
                const RaftMessageTranslationStatus(
                  tone: RaftMessageTranslationTone.pending,
                  message: 'Translating…',
                  tooltip: 'Translating',
                ),
                const RaftMessageTranslationStatus(
                  tone: RaftMessageTranslationTone.failed,
                  message: 'Translation unavailable',
                  actionLabel: 'Retry',
                  tooltip: 'Translation unavailable',
                ),
                const RaftMessageTranslationOriginal(
                  label: 'Original',
                  child: Text('你好'),
                ),
              ],
            ),
          ),
        ),
      );
      // 16px body: one 24px line box with the w-44 (176px) h-3 bar.
      expect(
        t.getSize(find.byType(RaftMessageTranslationSkeleton)),
        const Size(800, 24),
      );
      expect(t.getSize(find.byType(RaftSkeleton)), const Size(176, 12));
      expect(find.bySemanticsLabel('Show original'), findsOneWidget);
      await t.tap(find.text('Show original'));
      expect(toggles, 1);
      // Brutal uppercases the original label (`uppercase`).
      expect(
        find.text(family == RaftFamily.brutal ? 'ORIGINAL' : 'Original'),
        findsOneWidget,
      );
      expect(find.text('·'), findsOneWidget);
      semantics.dispose();
      await t.pumpWidget(const SizedBox());
    });
  }
}
