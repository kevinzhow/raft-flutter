import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Measured on the Web DOM (components.shell.* extension cases).
void main() {
  Future<void> pump(WidgetTester tester, bool dark, Widget child) =>
      tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(
            pack: packForThemeId(elegantThemePackId),
            dark: dark,
          ),
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      );

  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'Banner title/description gap and action wrap ${dark ? 'dark' : 'light'}',
      (tester) async {
        // Brutal title `mb-0.5`, Elegant `gap-y-1`.
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
        expect(gap, 4);

        // Above 24rem the action sits in the row, at or below it drops to its
        // own end-aligned row (`@max-[24rem]`).
        Widget banner(double width) => SizedBox(
          width: width,
          child: const RaftBanner(
            description: 'A new version is available.',
            action: Text('Reload', key: Key('action')),
          ),
        );
        await pump(tester, dark, banner(448));
        final wide = tester.getTopLeft(find.byKey(const Key('action'))).dy;
        final wideText = tester
            .getTopLeft(find.text('A new version is available.'))
            .dy;
        expect(wide, lessThan(wideText + 16)); // same row as the text
        await pump(tester, dark, banner(358));
        final narrow = tester.getTopLeft(find.byKey(const Key('action')));
        final narrowText = tester.getBottomLeft(
          find.text('A new version is available.'),
        );
        expect(narrow.dy, greaterThan(narrowText.dy));
        expect(
          tester.getTopRight(find.byKey(const Key('action'))).dx,
          lessThanOrEqualTo(358 - 12),
        );
      },
    );

    testWidgets(
      'Toast grid keeps both column gaps ${dark ? 'dark' : 'light'}',
      (tester) async {
        await pump(
          tester,
          dark,
          const RaftToast(title: 'Copied 3 message links'),
        );
        final plain = tester.getSize(find.byType(RaftToast));
        final title = tester.getSize(find.text('Copied 3 message links'));
        // padding 12+12 plus the two empty-track gaps (12+12).
        expect(plain.width - title.width, 48 + (0));
        await pump(
          tester,
          dark,
          RaftToast(title: 'Link Copied', icon: true, onClose: () {}),
        );
        expect(find.byType(RaftToast), findsOneWidget);
        expect(tester.getSize(find.byType(RaftToast)).height, 56);
      },
    );
  }

  testWidgets('BottomSheet card sits in a p-3 root and adds its border', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
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
