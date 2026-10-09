import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in const [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family dark=$dark mobile channel retains identity description and scoped actions',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var backs = 0, searches = 0, settings = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  RaftChannelHeader(
                    name: '首页专修',
                    kind: 'private',
                    description: 'Public description across more than one line and still inside the identity header.',
                    onBack: () => ++backs,
                    onSearch: () => ++searches,
                    onSettings: () => ++settings,
                  ),
                ],
              ),
            ),
          ),
        );
        expect(find.text('首页专修'), findsOneWidget);
        final titleBox = find.ancestor(
          of: find.text('首页专修'),
          matching: find.byType(RaftCssText),
        );
        if (family == RaftFamily.brutal) {
          expect(t.getSize(titleBox).height, 20);
          expect(t.getTopLeft(titleBox).dy, 12);
        }
        for (final label in ['Search this channel', 'Channel settings']) {
          expect(t.getSize(find.bySemanticsLabel(label)), const Size(28, 28));
        }
        expect(
          t.widget<Text>(find.textContaining('Public description')).maxLines,
          2,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is RaftIcon && w.glyph == RaftGlyph.lock,
          ),
          findsOneWidget,
        );
        await t.tap(find.bySemanticsLabel('Back'));
        await t.tap(find.bySemanticsLabel('Search this channel'));
        await t.tap(find.bySemanticsLabel('Channel settings'));
        expect([backs, searches, settings], [1, 1, 1]);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '$family dark=$dark header icon preserves touch and keyboard access',
      (t) async {
        var searches = 0;
        Future<void> mount({required bool enabled}) => t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Center(
                child: RaftDensityScope(
                  density: RaftDensity.touch,
                  child: RaftPanelIconButton(
                    glyph: RaftGlyph.search,
                    tooltip: 'Search this channel',
                    onPressed: enabled ? () => ++searches : null,
                  ),
                ),
              ),
            ),
          ),
        );
        await mount(enabled: true);
        final button = find.byType(RaftPanelIconButton);
        final rect = t.getRect(button);
        expect(rect.size, const Size(28, 28));
        await t.tapAt(Offset(rect.center.dx, rect.bottom + 6));
        await t.pump();
        expect(searches, 1);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(searches, 2);
        final semantics = t.ensureSemantics();
        expect(t, meetsGuideline(androidTapTargetGuideline));
        expect(t, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
        await mount(enabled: false);
        await t.tapAt(rect.center);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(searches, 2);
        expect(t.takeException(), isNull);
      },
    );
  }
}
