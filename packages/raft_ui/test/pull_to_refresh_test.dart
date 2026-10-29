import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final empty in [false, true]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} empty=$empty pulls once and retains content while busy',
        (t) async {
          final gate = Completer<void>();
          var reads = 0;
          final semantics = t.ensureSemantics();
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark)
                  .copyWith(platform: TargetPlatform.android),
              home: Scaffold(
                body: RaftPullToRefresh(
                  onRefresh: () {
                    reads++;
                    return gate.future;
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [if (!empty) const Text('Held row')],
                  ),
                ),
              ),
            ),
          );
          await t.drag(find.byType(ListView), const Offset(0, 400));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(reads, 1);
          if (!empty) expect(find.text('Held row'), findsOneWidget);
          expect(find.byType(RefreshProgressIndicator), findsOneWidget);
          expect(
            t.getSemantics(find.byType(RefreshProgressIndicator)).label,
            'Refresh',
          );
          await t.drag(find.byType(ListView), const Offset(0, 400));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(reads, 1);
          gate.complete();
          await t.pumpAndSettle();
          expect(find.byType(RefreshProgressIndicator), findsNothing);
          expect(t.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  }

  testWidgets(
    'horizontal child and drag away from top do not refresh; keyboard focus survives',
    (t) async {
      final scroll = ScrollController();
      final focus = FocusNode();
      addTearDown(scroll.dispose);
      addTearDown(focus.dispose);
      var reads = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Column(
              children: [
                TextButton(
                  focusNode: focus,
                  onPressed: () {},
                  child: const Text('Action'),
                ),
                Expanded(
                  child: RaftPullToRefresh(
                    onRefresh: () async {
                      reads++;
                    },
                    child: ListView(
                      controller: scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 120,
                          child: ListView(
                            key: const Key('horizontal'),
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (var i = 0; i < 10; i++)
                                SizedBox(width: 100, child: Text('$i')),
                            ],
                          ),
                        ),
                        for (var i = 0; i < 30; i++)
                          SizedBox(height: 60, child: Text('Row $i')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(focus.hasFocus, isTrue);
      await t.drag(find.byKey(const Key('horizontal')), const Offset(-250, 0));
      await t.pumpAndSettle();
      expect(reads, 0);
      scroll.jumpTo(400);
      await t.pump();
      await t.drag(find.byType(RaftPullToRefresh), const Offset(0, 80));
      await t.pumpAndSettle();
      expect(reads, 0);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('disabled desktop wrapper does not insert an indicator', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: RaftPullToRefresh(
          enabled: false,
          onRefresh: () async {},
          child: ListView(children: const [Text('Desktop')]),
        ),
      ),
    );
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.text('Desktop'), findsOneWidget);
  });
}
