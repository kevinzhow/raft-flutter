import 'package:flutter/material.dart';
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
        if (family == RaftFamily.brutal) {
          expect(t.getSize(find.text('首页专修')).height, 20);
          expect(t.getTopLeft(find.text('首页专修')).dy, 12);
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
  }
}
