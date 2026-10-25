import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Raft look. The legacy file (shell_primitives_test.dart) pins the Elegant
/// measurements; here the Raft banner and toast are asserted by behaviour and
/// by relations between their own parts, not by Elegant pixels.
void main() {
  Future<void> pump(WidgetTester tester, bool dark, Widget child) =>
      tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      );

  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'Banner title sits above its description ${dark ? 'dark' : 'light'}',
      (tester) async {
        await pump(
          tester,
          dark,
          const SizedBox(
            width: 448,
            child: RaftBanner(
              title: 'Saved',
              description: 'Your changes are live.',
            ),
          ),
        );
        final gap =
            tester.getTopLeft(find.text('Your changes are live.')).dy -
            tester.getBottomLeft(find.text('Saved')).dy;
        expect(gap, greaterThanOrEqualTo(0));
        expect(gap, lessThan(12));
        expect(
          tester.getTopLeft(find.text('Your changes are live.')).dx,
          tester.getTopLeft(find.text('Saved')).dx,
        );
      },
    );

    testWidgets(
      'Banner action is a row under the copy at any width ${dark ? 'dark' : 'light'}',
      (tester) async {
        // raft-ui 0.7: the action is `mt-2 flex flex-wrap`, in the text column
        // under the copy, wide or narrow.
        for (final width in [448.0, 358.0]) {
          await pump(
            tester,
            dark,
            SizedBox(
              width: width,
              child: const RaftBanner(
                description: 'A new version is available.',
                action: Text('Reload', key: Key('action')),
              ),
            ),
          );
          final text = tester.getBottomLeft(
            find.text('A new version is available.'),
          );
          final action = tester.getTopLeft(find.byKey(const Key('action')));
          expect(action.dy, greaterThanOrEqualTo(text.dy), reason: '$width');
          expect(action.dx, closeTo(text.dx, 0.5), reason: '$width');
          expect(
            tester.getTopRight(find.byKey(const Key('action'))).dx,
            lessThanOrEqualTo(width),
          );
        }
      },
    );

    testWidgets(
      'Toast wraps its title in padding and closes from its button ${dark ? 'dark' : 'light'}',
      (tester) async {
        await pump(
          tester,
          dark,
          const RaftToast(title: 'Copied 3 message links'),
        );
        final plain = tester.getSize(find.byType(RaftToast));
        final title = tester.getSize(find.text('Copied 3 message links'));
        expect(plain.width, greaterThan(title.width));
        expect(plain.height, greaterThanOrEqualTo(title.height));
        var closed = 0;
        await pump(
          tester,
          dark,
          RaftToast(title: 'Link Copied', icon: true, onClose: () => closed++),
        );
        expect(find.byType(RaftToast), findsOneWidget);
        expect(find.text('Link Copied'), findsOneWidget);
        await tester.tap(find.byKey(const Key('toast-close')));
        expect(closed, 1);
      },
    );
  }

  testWidgets('BottomSheet card sits in a p-3 root and adds its border', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RaftBottomSheet(
              contentPadding: EdgeInsets.all(16),
              child: SizedBox(height: 100, width: double.infinity),
            ),
          ),
        ),
      ),
    );
    final root = tester.getSize(find.byType(RaftBottomSheet));
    // 12 + (1 border + 16 padding) * 2 + 100 + 12 (Raft card border is 1 px;
    // the former Brutal sheet added 2 px).
    expect(root.height, 12 + 34 + 100 + 12);
  });
}
