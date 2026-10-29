import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/activity_selected_previews.dart';
import 'package:raft_ui/test_themes.dart';

import 'panel_header_content_test.dart' show fonts;

void main() {
  testWidgets('shrinking inbox track keeps Mentions visible and tappable', (
    t,
  ) async {
    await fonts(t);
    var selected = 'all';
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 191,
              child: RaftSegmentedControl<String>(
                value: selected,
                shrinkFrame: true,
                minimumTargetSize: 32,
                items: const [
                  RaftSegmentedOption(value: 'all', label: 'All'),
                  RaftSegmentedOption(value: 'unread', label: 'Unread'),
                  RaftSegmentedOption(value: 'mentions', label: 'Mentions'),
                ],
                onChanged: (value) => selected = value,
              ),
            ),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    await t.tap(find.text('Mentions'));
    await t.pump();
    expect(selected, 'mentions');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('larger inbox labels remain reachable by scrolling', (t) async {
    await fonts(t);
    var selected = 'all';
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 191,
              child: RaftResourceFilterViewport(
                child: RaftSegmentedControl<String>(
                  value: selected,
                  shrinkFrame: true,
                  minimumTargetSize: 32,
                  items: const [
                    RaftSegmentedOption(value: 'all', label: 'All'),
                    RaftSegmentedOption(value: 'unread', label: 'Unread'),
                    RaftSegmentedOption(value: 'mentions', label: 'Mentions'),
                  ],
                  onChanged: (value) => selected = value,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await t.drag(find.byType(SingleChildScrollView), const Offset(-180, 0));
    await t.pumpAndSettle();
    await t.tap(find.text('Mentions'));
    await t.pump();
    expect(selected, 'mentions');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('selected flat row keeps its selected fill while hovered', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 342,
            child: RaftConversationCard(
              selected: true,
              onOpen: () {},
              child: const SizedBox(height: 40),
            ),
          ),
        ),
      ),
    );
    final frame = find
        .descendant(
          of: find.byType(RaftConversationCard),
          matching: find.byType(Material),
        )
        .first;
    final before = t.widget<Material>(frame).color;
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: t.getCenter(find.byType(RaftConversationCard)),
    );
    await t.pump();
    expect(t.widget<Material>(frame).color, before);
    await mouse.removePointer();
    await t.pumpWidget(const SizedBox());
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Raft resource row has the measured flat content box dark=$dark',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(raftThemePackId), dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 342,
                  child: RaftConversationCard(
                    onOpen: () {},
                    child: const SizedBox(
                      key: Key('content'),
                      width: 100,
                      height: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final row = t.getRect(find.byType(RaftConversationCard));
        final body = t.getRect(find.byKey(const Key('content')));
        // Web v1.21.23 InboxRow / Saved ListRow: px-4 py-3, no card border.
        expect(body.left - row.left, 16);
        expect(body.top - row.top, 12);
        expect(row.height, 44);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    testWidgets('$id resource toolbar preview keeps both actions connected', (
      t,
    ) async {
      await fonts(t);
      final semantics = t.ensureSemantics();
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id)),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 390, child: resourceToolbarPreview()),
              ),
            ),
          ),
        );
        await t.tap(find.text('Unread'));
        await t.pumpAndSettle();
        expect(find.text('Filter: unread; read actions: 0'), findsOneWidget);
        expect(find.bySemanticsLabel('Mark all read'), findsOneWidget);
        await t.tap(find.text('Mark all read'));
        await t.pumpAndSettle();
        expect(find.text('Filter: unread; read actions: 1'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(find.text('Filter: unread; read actions: 2'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    });
    testWidgets('$id resource badge uses its approved shape', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(id)),
          home: const Scaffold(
            body: RaftResourceBadge(
              label: '2 new',
              variant: RaftBadgeRecipeVariant.accent,
            ),
          ),
        ),
      );
      expect(
        find.byType(RaftBadge),
        id == raftThemePackId ? findsOneWidget : findsNothing,
      );
      expect(find.text('2 new'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }
}
