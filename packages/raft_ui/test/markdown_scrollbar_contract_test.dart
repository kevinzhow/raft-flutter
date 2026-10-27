import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _source = '''
| Long header | State |
|---|---|
| Long body value | Ready |

```
unchanged_code
```

[Open link](https://example.com/)
''';

Future<List<int>> _pixels(WidgetTester tester, GlobalKey boundaryKey) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  try {
    return (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

void main() {
  testWidgets(
    'null hook and equivalent hook preserve stock table/code pixels',
    (tester) async {
      final boundaryKey = GlobalKey();
      final theme = ThemeData(platform: TargetPlatform.iOS);
      final sheet = MarkdownStyleSheet(
        tableColumnWidth: const IntrinsicColumnWidth(),
        tablePadding: const EdgeInsets.all(7),
        tableCellsPadding: const EdgeInsets.all(9),
        tableBorder: TableBorder.all(),
        codeblockPadding: const EdgeInsets.all(11),
      );
      Widget host(MarkdownScrollbarBuilder? hook) => MaterialApp(
        theme: theme,
        home: RepaintBoundary(
          key: boundaryKey,
          child: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: MarkdownBody(
                data: _source,
                styleSheet: sheet,
                scrollbarBuilder: hook,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(null));
      await tester.pump();
      final original = await _pixels(tester, boundaryKey);
      final table = tester.widget<Table>(find.byType(Table));
      final originalSize = tester.getSize(find.byType(Table));
      expect(table.defaultColumnWidth, same(sheet.tableColumnWidth));
      expect(table.border, sheet.tableBorder);
      expect(
        find.byWidgetPredicate((widget) => widget is RawScrollbar),
        findsNWidgets(2),
      );
      final originalControllers = tester
          .widgetList<RawScrollbar>(
            find.byWidgetPredicate((widget) => widget is RawScrollbar),
          )
          .map((widget) => widget.controller)
          .toSet();
      final replacementControllers = <ScrollController>{};
      var replacementCalls = 0;
      await tester.pumpWidget(
        host((context, controller, child, visible) {
          replacementCalls++;
          replacementControllers.add(controller);
          return Scrollbar(
            controller: controller,
            thumbVisibility: visible,
            child: child,
          );
        }),
      );
      await tester.pump();
      expect(replacementCalls, 2);
      expect(replacementControllers, unorderedEquals(originalControllers));
      expect(tester.getSize(find.byType(Table)), originalSize);
      expect(
        tester.widget<Table>(find.byType(Table)).defaultColumnWidth,
        same(sheet.tableColumnWidth),
      );
      expect(
        tester.widget<Table>(find.byType(Table)).border,
        sheet.tableBorder,
      );
      expect(await _pixels(tester, boundaryKey), original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hook gets existing table/pre controllers, padding and link behavior',
    (tester) async {
      final calls = <(ScrollController, SingleChildScrollView, bool?)>[];
      final links = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: MarkdownBody(
                data: _source,
                styleSheet: MarkdownStyleSheet(
                  tableColumnWidth: const IntrinsicColumnWidth(),
                  tablePadding: const EdgeInsets.all(7),
                  tableScrollbarThumbVisibility: true,
                  codeblockPadding: const EdgeInsets.all(11),
                ),
                scrollbarBuilder: (context, controller, child, visible) {
                  expect(child, isA<SingleChildScrollView>());
                  final scroll = child as SingleChildScrollView;
                  expect(scroll.controller, same(controller));
                  expect(scroll.scrollDirection, Axis.horizontal);
                  calls.add((controller, scroll, visible));
                  return child;
                },
                onTapLink: (_, href, _) => links.add(href),
              ),
            ),
          ),
        ),
      );
      expect(calls, hasLength(2));
      expect(calls.map((call) => call.$1).toSet(), hasLength(2));
      expect(calls[0].$2.padding, const EdgeInsets.all(7));
      expect(calls[0].$3, isTrue);
      expect(calls[1].$2.padding, const EdgeInsets.all(11));
      expect(calls[1].$3, isNull);
      expect(
        find.byWidgetPredicate((widget) => widget is RawScrollbar),
        findsNothing,
      );
      final table = tester.widget<Table>(find.byType(Table));
      expect(table.defaultColumnWidth, isA<IntrinsicColumnWidth>());
      expect(table.children, hasLength(2));
      expect(table.children.every((row) => row.children.length == 2), isTrue);
      await tester.tap(find.text('Open link', findRichText: true));
      expect(links, ['https://example.com/']);
      final controllers = [for (final call in calls) call.$1];
      for (final controller in controllers) {
        expect(ChangeNotifier.debugAssertNotDisposed(controller), isTrue);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      for (final controller in controllers) {
        expect(
          () => ChangeNotifier.debugAssertNotDisposed(controller),
          throwsFlutterError,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'embedded painter clears window padding while content keeps original media data',
    (tester) async {
      const padding = EdgeInsets.fromLTRB(8, 47, 9, 34);
      const original = MediaQueryData(
        size: Size(390, 844),
        padding: padding,
        viewPadding: padding,
        viewInsets: EdgeInsets.only(bottom: 200),
        textScaler: TextScaler.linear(1.3),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.iOS),
          home: const MediaQuery(
            data: original,
            child: Material(
              child: RaftMessageBody(
                content: '| A | B |\n|---|---|\n| Value | Ready |',
              ),
            ),
          ),
        ),
      );
      final scroll = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      final controller = tester
          .widget<SingleChildScrollView>(scroll)
          .controller;
      final scrollbar = find.byWidgetPredicate(
        (widget) => widget is RawScrollbar && widget.controller == controller,
      );
      expect(scrollbar, findsOneWidget);
      expect(MediaQuery.paddingOf(tester.element(scrollbar)), EdgeInsets.zero);
      expect(MediaQuery.of(tester.element(scroll)), original);
      expect(MediaQuery.of(tester.element(find.byType(Table))), original);
      expect(tester.takeException(), isNull);
    },
  );
}
