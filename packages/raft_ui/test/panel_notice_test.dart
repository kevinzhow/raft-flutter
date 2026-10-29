import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Widget host(ThemeData theme, Widget child, {double width = 900}) => MaterialApp(
  theme: theme,
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 600)),
    child: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

RaftPanelNotice notice({
  RaftPanelNoticeRecipeStatus status = RaftPanelNoticeRecipeStatus.warning,
  List<Widget> actions = const [],
}) => RaftPanelNotice(
  status: status,
  actions: actions,
  content: (context, style) => Text('Agent will not start', style: style),
);

BoxDecoration decorationOf(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(RaftPanelNotice),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return box.decoration as BoxDecoration;
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'Raft look: status tint, seam below, 10 x 20 padding (dark=$dark)',
      (tester) async {
        final theme = raftTheme(dark: dark);
        final ui = theme.extension<RaftTokens>()!.ui;
        for (final (status, token) in [
          (RaftPanelNoticeRecipeStatus.warning, 'warning-soft'),
          (RaftPanelNoticeRecipeStatus.destructive, 'danger-soft'),
          (RaftPanelNoticeRecipeStatus.info, 'info-soft'),
          (RaftPanelNoticeRecipeStatus.success, 'success-soft'),
          (RaftPanelNoticeRecipeStatus.default_, 'fill-muted'),
        ]) {
          await tester.pumpWidget(host(theme, notice(status: status)));
          final d = decorationOf(tester);
          expect(d.color, ui[token], reason: '$status');
          final border = d.border! as Border;
          expect(border.bottom.width, 1);
          expect(border.bottom.color, ui['line-seam']);
          expect(border.top.style, BorderStyle.none);
        }
        await tester.pumpWidget(host(theme, notice()));
        expect(tester.getSize(find.byType(RaftPanelNotice)).height, 41);
        expect(tester.getTopLeft(find.text('Agent will not start')).dx, 20);
      },
    );

    testWidgets('phones pad 16 on the sides (dark=$dark)', (tester) async {
      await tester.pumpWidget(
        host(raftTheme(dark: dark), notice(), width: 390),
      );
      expect(tester.getTopLeft(find.text('Agent will not start')).dx, 16);
    });

    testWidgets(
      'actions are centred on the first line and add no height (dark=$dark)',
      (tester) async {
        await tester.pumpWidget(
          host(
            raftTheme(dark: dark),
            notice(
              actions: [
                SizedBox(key: const Key('a'), width: 32, height: 32),
                SizedBox(key: const Key('b'), width: 32, height: 32),
              ],
            ),
          ),
        );
        expect(tester.getSize(find.byType(RaftPanelNotice)).height, 41);
        final a = tester.getRect(find.byKey(const Key('a')));
        final b = tester.getRect(find.byKey(const Key('b')));
        expect(b.left - a.right, 12);
        expect(a.center.dy, 10 + 10, reason: 'centre of the first 20px line');
        expect(
          b.right,
          tester.getSize(find.byType(RaftPanelNotice)).width - 20,
        );
      },
    );
  }

  testWidgets(
    'Elegant keeps the soft tint with a line-muted rule and 20 x 8 padding',
    (tester) async {
      final theme = raftTheme(pack: packForThemeId(elegantThemePackId));
      final t = theme.extension<RaftTokens>()!;
      await tester.pumpWidget(host(theme, notice()));
      final d = decorationOf(tester);
      expect(d.color, t.colors['warning-soft']);
      expect((d.border! as Border).bottom.color, t.colors['line-muted']);
      expect(tester.getTopLeft(find.text('Agent will not start')).dx, 20);
    },
    skip: raftLookSkip(raftLookElegant),
  );
}
