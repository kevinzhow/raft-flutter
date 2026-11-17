import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_select_text_sheet.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  const markdown = 'Hello **world**\n- item';

  Future<List<String>> open(WidgetTester t) async {
    final quoted = <String>[];
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                showMessageSelectTextSheet(
                  context,
                  senderName: 'Ada',
                  time: '10:30',
                  markdown: markdown,
                  onQuote: quoted.add,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    return quoted;
  }

  testWidgets('shows title, hint, sender line and the text', (t) async {
    await open(t);
    expect(find.text('Select text'), findsOneWidget);
    expect(find.text('Press and hold to select text.'), findsOneWidget);
    expect(find.text('Ada · 10:30'), findsOneWidget);
    expect(find.text(markdown), findsOneWidget);
  });

  testWidgets('Copy with no selection copies the whole message', (t) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(t);
    await t.tap(find.text('Copy'));
    await t.pumpAndSettle();
    expect(copied, markdown);
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('Quote hands over the whole message and closes', (t) async {
    final quoted = await open(t);
    await t.tap(find.text('Quote'));
    await t.pumpAndSettle();
    expect(quoted, [markdown]);
    expect(find.text('Select text'), findsNothing);
  });

  testWidgets('the close button closes', (t) async {
    await open(t);
    await t.tap(find.bySemanticsLabel('Close'));
    await t.pumpAndSettle();
    expect(find.text('Select text'), findsNothing);
  });
}
