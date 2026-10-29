import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'sliver keeps task section geometry ${dark ? 'dark' : 'light'}',
      (t) async {
        t.view.physicalSize = const Size(390, 720);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        Widget row(int i) => SourceTaskRowExtent(
          key: ValueKey(i),
          child: RaftTaskCard(title: 'Task $i', number: '$i', status: 'todo'),
        );
        Future<void> mount(Widget body) async {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(body: body),
            ),
          );
          await t.pumpAndSettle();
        }

        await mount(
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RaftTaskSection(
                status: 'todo',
                count: 3,
                triggerKey: const Key('heading'),
                children: [for (var i = 0; i < 3; i++) row(i)],
              ),
            ],
          ),
        );
        final heading = t.getRect(find.byKey(const Key('heading')));
        final rows = [
          for (final e in find.byType(SourceTaskRowExtent).evaluate())
            t.getRect(find.byWidget(e.widget)),
        ];
        await mount(
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: RaftSliverTaskSection(
                  status: 'todo',
                  count: 3,
                  triggerKey: const Key('heading'),
                  itemBuilder: (_, i) => row(i),
                ),
              ),
            ],
          ),
        );
        expect(t.getRect(find.byKey(const Key('heading'))), heading);
        expect([
          for (final e in find.byType(SourceTaskRowExtent).evaluate())
            t.getRect(find.byWidget(e.widget)),
        ], rows);
        await mount(
          CustomScrollView(
            slivers: [
              RaftSliverTaskSection(
                status: 'done',
                count: 0,
                emptyLabel: 'No done tasks',
                itemBuilder: (_, _) =>
                    throw StateError('Empty section built a row'),
              ),
            ],
          ),
        );
        expect(find.text('No done tasks'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      'lazy task rows, collapse and semantics ${dark ? 'dark' : 'light'}',
      (t) async {
        t.view.physicalSize = const Size(390, 720);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final semantics = t.ensureSemantics();
        var collapsed = false, opened = -1;
        final built = <int>{};
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, update) => CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: RaftSliverTaskSection(
                        status: 'todo',
                        count: 600,
                        collapsed: collapsed,
                        triggerKey: const Key('group'),
                        onToggle: () => update(() => collapsed = !collapsed),
                        itemBuilder: (_, i) {
                          built.add(i);
                          return SourceTaskRowExtent(
                            key: ValueKey(i),
                            child: RaftTaskCard(
                              title: 'Task $i',
                              number: '$i',
                              status: 'todo',
                              onTap: () => opened = i,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(built.length, inInclusiveRange(1, 15));
        expect(find.text('600'), findsOneWidget);
        expect(find.bySemanticsLabel('Hide Todo'), findsOneWidget);
        await t.tap(find.text('Task 0'));
        await t.pumpAndSettle();
        expect(opened, 0);
        await t.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await t.pumpAndSettle();
        expect(built.length, lessThan(20));
        expect(find.byType(RaftTaskCard).evaluate().length, lessThan(15));
        await t.drag(find.byType(CustomScrollView), const Offset(0, 900));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('group')));
        await t.pumpAndSettle();
        expect(find.byType(RaftTaskCard), findsNothing);
        expect(find.bySemanticsLabel('Show Todo'), findsOneWidget);
        await t.tap(find.byKey(const Key('group')));
        await t.pumpAndSettle();
        expect(find.text('Task 0'), findsOneWidget);
        expect(t.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
