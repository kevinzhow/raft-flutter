import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Pinned Web db5e399f CreateChannelDialog / CreateJointChannelDialog:
// BannerTitle keeps the name's mono run; actions are outline + ghost. Only
// the ordinary create dialog has a BannerDescription. These are behavior and
// composition checks, not a claim of current real-screen visual acceptance.
Widget _app({
  required bool dark,
  bool hint = true,
  bool busy = false,
  bool canUnarchive = true,
  VoidCallback? unarchive,
  VoidCallback? changeName,
}) => MaterialApp(
  theme: raftTheme(pack: packForThemeId(raftThemePackId), dark: dark),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 480,
        child: RaftArchivedNameBanner(
          name: 'archive-me',
          showHint: hint,
          canUnarchive: canUnarchive,
          busy: busy,
          onUnarchive: unarchive ?? () {},
          onChangeName: changeName ?? () {},
        ),
      ),
    ),
  ),
);

void main() {
  for (final dark in [false, true]) {
    for (final hint in [false, true]) {
      testWidgets('archived-name source slots dark=$dark description=$hint', (
        tester,
      ) async {
        var restored = 0;
        var renamed = 0;
        await tester.pumpWidget(
          _app(
            dark: dark,
            hint: hint,
            unarchive: () => restored++,
            changeName: () => renamed++,
          ),
        );
        expect(find.byType(RaftBanner), findsOneWidget);
        if (hint) {
          final title = find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('#archive-me'),
          );
          final description = find.text(
            'Unarchive it to keep its history, or choose a different name.',
          );
          // Published banner root is grid gap-y-0; the title has no margin.
          expect(
            tester.getTopLeft(description).dy - tester.getBottomLeft(title).dy,
            0,
          );
        }
        final restoreButton = find.widgetWithText(RaftButton, 'Unarchive');
        final renameButton = find.widgetWithText(RaftButton, 'Change name');
        expect(restoreButton, findsOneWidget);
        expect(renameButton, findsOneWidget);
        expect(
          tester.widget<RaftButton>(restoreButton).resolvedVariant,
          RaftButtonVariant.outline,
        );
        expect(
          tester.widget<RaftButton>(renameButton).resolvedVariant,
          RaftButtonVariant.ghost,
        );
        expect(
          find.text(
            'Unarchive it to keep its history, or choose a different name.',
          ),
          hint ? findsOneWidget : findsNothing,
        );
        expect(find.text(''), findsNothing);
        final title = tester
            .widgetList<RichText>(find.byType(RichText))
            .firstWhere(
              (text) => text.text.toPlainText().contains('#archive-me'),
            );
        final runs = <InlineSpan>[];
        title.text.visitChildren((span) {
          runs.add(span);
          return true;
        });
        final name = runs.whereType<TextSpan>().firstWhere(
          (span) => span.text == '#archive-me',
        );
        final context = tester.element(find.byType(RaftArchivedNameBanner));
        expect(name.style?.fontFamily, RaftTokens.of(context).monoFont);
        await tester.tap(restoreButton);
        await tester.pump();
        expect(restored, 1);
        await tester.tap(renameButton);
        await tester.pump();
        expect(renamed, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'busy archived-name restore is disabled while rename still works',
    (tester) async {
      var restored = 0;
      var renamed = 0;
      await tester.pumpWidget(
        _app(
          dark: false,
          busy: true,
          unarchive: () => restored++,
          changeName: () => renamed++,
        ),
      );
      final restore = find.widgetWithText(RaftButton, 'Unarchiving…');
      expect(restore, findsOneWidget);
      await tester.tap(restore);
      await tester.pump();
      expect(restored, 0);
      await tester.tap(find.widgetWithText(RaftButton, 'Change name'));
      await tester.pump();
      expect(renamed, 1);
    },
  );

  testWidgets('unprivileged archived-name notice only offers rename', (
    tester,
  ) async {
    var renamed = 0;
    await tester.pumpWidget(
      _app(dark: true, canUnarchive: false, changeName: () => renamed++),
    );
    expect(find.widgetWithText(RaftButton, 'Unarchive'), findsNothing);
    expect(
      find.text('Pick a different name, or ask an admin to unarchive it.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(RaftButton, 'Change name'));
    await tester.pump();
    expect(renamed, 1);
  });
}
