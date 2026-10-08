import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
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
          final isBrutal = family == RaftFamily.brutal;
          final internal = isBrutal
              ? 6.0
              : rowContext == RaftMessageRowContext.thread && width < 1024
              ? 12.0
              : width < 768
              ? 16.0
              : 28.0;
          final expectedAvatar =
              12 + (isBrutal ? 12 : 0) + (isBrutal ? 2 : 1) + internal;
          expect(
            t.getTopLeft(find.byKey(const ValueKey('avatar'))).dx,
            expectedAvatar,
          );
          final expectedContent =
              expectedAvatar +
              (isBrutal || width >= 768 ? 36 : 32) +
              (isBrutal || width >= 768 ? 12 : 8);
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
