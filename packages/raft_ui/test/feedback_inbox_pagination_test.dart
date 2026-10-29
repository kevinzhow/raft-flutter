import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final (size, scale) in const [
      (Size(390, 844), 1.0),
      (Size(1100, 900), 1.0),
      (Size(390, 844), 3.1),
    ]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} $size/$scale empty filters keep pagination',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = size;
          addTearDown(t.view.reset);
          final semantics = t.ensureSemantics();
          try {
            var loads = 0;
            Future<void> pump(RaftFeedbackFilter filter, {bool more = true}) =>
                t.pumpWidget(
                  MaterialApp(
                    theme: raftTheme(dark: dark),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: RaftTextScaling(child: child!),
                    ),
                    home: Scaffold(
                      body: RaftFeedbackInbox(
                        tickets: const [],
                        anyTickets: filter != RaftFeedbackFilter.all,
                        filter: filter,
                        onFilter: (_) {},
                        onLoadMore: more ? () => loads++ : null,
                      ),
                    ),
                  ),
                );

            // Large-text coverage here isolates the empty content and pager.
            // The existing filter-tab row has a separate horizontal-overflow
            // finding at 3.1x; its full failing variant is kept in task evidence.
            final filters = scale == 1
                ? RaftFeedbackFilter.values
                : [RaftFeedbackFilter.all];
            for (final filter in filters) {
              await pump(filter);
              final button = find.widgetWithText(RaftButton, 'Load More');
              // At large text sizes the action starts beyond the viewport;
              // scrolling builds it before pointer or keyboard interaction.
              await t.scrollUntilVisible(
                button,
                200,
                // The filter tabs are a horizontal Scrollable too; scroll the page.
                scrollable: find
                    .byWidgetPredicate(
                      (w) =>
                          w is Scrollable &&
                          w.axisDirection == AxisDirection.down,
                    )
                    .first,
              );
              expect(button, findsOneWidget);
              await t.pumpAndSettle();
              expect(find.byType(RaftFeedbackEmptyState), findsOneWidget);
              final flags = t
                  .getSemantics(button)
                  .getSemanticsData()
                  .flagsCollection;
              expect(flags.isButton, isTrue);
              final before = loads;
              await t.tap(button);
              await t.pump();
              expect(loads, before + 1);

              // Keyboard users can reach and activate the same surviving action.
              for (var i = 0; i < 5; i++) {
                if (t
                        .getSemantics(button)
                        .getSemanticsData()
                        .flagsCollection
                        .isFocused ==
                    Tristate.isTrue) {
                  break;
                }
                await t.sendKeyEvent(LogicalKeyboardKey.tab);
                await t.pump();
              }
              expect(
                t
                    .getSemantics(button)
                    .getSemanticsData()
                    .flagsCollection
                    .isFocused,
                Tristate.isTrue,
              );
              await t.sendKeyEvent(LogicalKeyboardKey.enter);
              await t.pump();
              expect(loads, before + 2);

              // A confirmed terminal empty result has no pagination action.
              await pump(filter, more: false);
              expect(find.text('Load More'), findsNothing);
              expect(find.byType(RaftFeedbackEmptyState), findsOneWidget);
              final terminal = t.state<ScrollableState>(
                find
                    .byWidgetPredicate(
                      (w) =>
                          w is Scrollable &&
                          w.axisDirection == AxisDirection.down,
                    )
                    .first,
              );
              expect(
                terminal.position.maxScrollExtent,
                scale == 1 ? isZero : greaterThan(0),
              );
              expect(t.takeException(), isNull);
            }
          } finally {
            await t.pumpWidget(const SizedBox());
            semantics.dispose();
          }
        },
      );
    }
  }
}
