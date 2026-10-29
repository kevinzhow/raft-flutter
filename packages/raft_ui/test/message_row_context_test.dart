import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final width in [767.0, 957.0, 1024.0]) {
      for (final rowContext in RaftMessageRowContext.values) {
        testWidgets('mounted row padding $dark/$width/$rowContext', (t) async {
          await t.binding.setSurfaceSize(Size(width, 400));
          addTearDown(() => t.binding.setSurfaceSize(null));
          var activated = 0;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
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
          // Web v1.21.23: px-2, a 35px slot/avatar, gap-3 at every width.
          // The existing timeline wrapper contributes its separate 12px inset.
          const inset = 12.0 + 8;
          expect(t.getTopLeft(find.byKey(const ValueKey('avatar'))).dx, inset);
          expect(
            t.getSize(find.byKey(const ValueKey('avatar'))),
            const Size.square(35),
          );
          expect(
            t.getTopLeft(find.byKey(const ValueKey('content'))).dx,
            inset + 35 + 12,
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
