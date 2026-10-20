import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    for (final width in [767.0, 957.0, 1024.0]) {
      for (final rowContext in RaftMessageRowContext.values) {
        testWidgets('mounted row padding $family/$dark/$width/$rowContext', (
          t,
        ) async {
          await t.binding.setSurfaceSize(Size(width, 400));
          addTearDown(() => t.binding.setSurfaceSize(null));
          var activated = 0;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(size: Size(width, 400)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const RaftTimelineCompositionRecipe().messageInset,
                  child: RaftMessageRow(
                    rowContext: rowContext,
                    author: 'Public author',
                    timestamp: '10:30',
                    avatar: const SizedBox(
                      key: ValueKey('avatar'),
                      width: 36,
                      height: 36,
                    ),
                    content: const SizedBox(
                      key: ValueKey('content'),
                      height: 20,
                    ),
                    onAuthor: () => activated++,
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          // Web v1.21.12 (raft-ui 0.5.36+): the row carries 8 of its own
          // (elegant 7 + 1 border, brutal 6 + 2) next to the wrapper's 12 at
          // every width; the thread context no longer changes the padding.
          final isBrutal = family == RaftFamily.brutal;
          final inset = 12 + (isBrutal ? 2 + 6 : 1 + 7);
          final mobile = width < 768;
          // The avatar (32, 28 below 768) is centred in the 36 (32) slot.
          expect(
            t.getTopLeft(find.byKey(const ValueKey('avatar'))).dx,
            inset + 2,
          );
          expect(
            t.getSize(find.byKey(const ValueKey('avatar'))),
            Size.square(mobile ? 28 : 32),
          );
          final expectedContent =
              inset + (mobile ? 32 : 36) + (isBrutal || !mobile ? 12 : 8);
          expect(
            t.getTopLeft(find.byKey(const ValueKey('content'))).dx,
            expectedContent,
          );
          await t.tap(find.text('Public author'));
          await t.pump();
          expect(activated, 1);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
