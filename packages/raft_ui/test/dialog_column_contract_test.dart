import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

RaftThemePack gapPack(double gap) => RaftThemePack.parse(
  jsonEncode({
    'format': raftThemePackFormat,
    'id': 'user:dialog-gap-test',
    'name': {'en': 'Dialog gap test'},
    'version': '1',
    'extends': 'raft',
    'modes': {
      'light': {
        'geometry': {'space.dialogPartGap': gap},
      },
      'dark': {
        'geometry': {'space.dialogPartGap': gap},
      },
    },
  }),
);

void main() {
  testWidgets('dialog preserves a caller Column key and its layout', (t) async {
    final columnKey = GlobalKey();
    const first = Key('first');
    const second = Key('second');
    Widget buildDialog() => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftDialog(
          child: Column(
            key: columnKey,
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            verticalDirection: VerticalDirection.up,
            textBaseline: TextBaseline.ideographic,
            spacing: 7,
            children: const [
              SizedBox(key: first, width: 25, height: 10),
              SizedBox(key: second, width: 40, height: 10),
            ],
          ),
        ),
      ),
    );
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(buildDialog());
    await t.pumpAndSettle();

    expect(find.byKey(columnKey), findsOneWidget);
    final originalContext = columnKey.currentContext;
    expect(originalContext, isNotNull);
    final column = t.widget<Column>(find.byKey(columnKey));
    expect(column.mainAxisAlignment, MainAxisAlignment.end);
    expect(column.mainAxisSize, MainAxisSize.max);
    expect(column.crossAxisAlignment, CrossAxisAlignment.start);
    expect(column.textDirection, TextDirection.rtl);
    expect(column.verticalDirection, VerticalDirection.up);
    expect(column.textBaseline, TextBaseline.ideographic);
    expect(column.spacing, 7);
    final columnRect = t.getRect(find.byKey(columnKey));
    final firstRect = t.getRect(find.byKey(first));
    final secondRect = t.getRect(find.byKey(second));
    expect(firstRect.right, columnRect.right);
    expect(secondRect.right, columnRect.right);
    expect(secondRect.top, columnRect.top);
    expect(firstRect.top - secondRect.bottom, 7);

    await t.pumpWidget(buildDialog());
    await t.pumpAndSettle();
    expect(columnKey.currentContext, same(originalContext));
    expect(t.takeException(), isNull);
  });

  testWidgets('keyed dialog children retain input when reordered', (t) async {
    var reverse = false;
    late StateSetter rebuild;
    const one = Key('one');
    const two = Key('two');
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              final fields = <Widget>[
                TextFormField(key: one, initialValue: 'one'),
                TextFormField(key: two, initialValue: 'two'),
              ];
              return RaftDialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: reverse ? fields.reversed.toList() : fields,
                ),
              );
            },
          ),
        ),
      ),
    );
    await t.enterText(find.byKey(one), 'edited');
    rebuild(() => reverse = true);
    await t.pumpAndSettle();
    final firstEditor = find.descendant(
      of: find.byKey(one),
      matching: find.byType(EditableText),
    );
    expect(t.widget<EditableText>(firstEditor).controller.text, 'edited');
    expect(t.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'caller spacing and explicit dialog gap combine once dark=$dark',
      (t) async {
        final columnKey = GlobalKey();
        const first = Key('gap-first');
        const second = Key('gap-second');
        addTearDown(() => t.pumpWidget(const SizedBox()));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: gapPack(9), dark: dark),
            home: Scaffold(
              body: RaftDialog(
                child: Column(
                  key: columnKey,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 7,
                  children: const [
                    SizedBox(key: first, width: 20, height: 10),
                    SizedBox(key: second, width: 20, height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byKey(columnKey), findsOneWidget);
        expect(
          t.getRect(find.byKey(second)).top -
              t.getRect(find.byKey(first)).bottom,
          16,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
