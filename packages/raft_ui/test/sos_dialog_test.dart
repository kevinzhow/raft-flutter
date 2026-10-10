import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Finder _button(String key) => find.byKey(ValueKey(key));

VoidCallback? _onPressed(WidgetTester tester, String key) =>
    tester.widget<RaftButton>(_button(key)).onPressed;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark confirm → stopping → stopped → resume', (
      tester,
    ) async {
      final stop = Completer<String?>();
      final resume = Completer<String?>();
      final guidance = <String>[];
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: Center(
              child: RaftSosDialog(
                channelName: 'release',
                onStop: () => stop.future,
                onResume: (text) {
                  guidance.add(text);
                  return resume.future;
                },
                onClose: () => closed++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('STOP ALL AGENTS'), findsOneWidget);
      expect(
        find.text(
          'All running agents in #release will stop immediately. You can provide new guidance before resuming them.',
        ),
        findsOneWidget,
      );
      await tester.tap(_button('sos-stop'));
      await tester.pump();
      // Optimistic busy state: the action reads Stopping… and cannot repeat.
      expect(find.text('Stopping…'), findsOneWidget);
      expect(_onPressed(tester, 'sos-stop'), isNull);
      stop.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('AGENTS STOPPED'), findsOneWidget);
      expect(find.text('All agents have been stopped.'), findsOneWidget);
      // Resume requires non-blank guidance.
      expect(_onPressed(tester, 'sos-resume'), isNull);
      final field = find.descendant(
        of: _button('sos-guidance'),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
      await tester.enterText(field, '   ');
      await tester.pump();
      expect(_onPressed(tester, 'sos-resume'), isNull);
      await tester.enterText(field, '  Only touch the frontend.  ');
      await tester.pump();
      await tester.tap(_button('sos-resume'));
      await tester.pump();
      expect(guidance, ['Only touch the frontend.']);
      expect(find.text('Resuming…'), findsOneWidget);
      expect(_onPressed(tester, 'sos-keep-stopped'), isNull);
      expect(_onPressed(tester, 'sos-resume'), isNull);
      resume.complete(null);
      await tester.pumpAndSettle();
      expect(closed, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failures keep the phase and show the error', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Center(
            child: RaftSosDialog(
              channelName: 'release',
              onStop: () async => 'Agents could not be stopped. Try again.',
              onResume: (_) async => 'Server busy',
              onClose: () => closed++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(_button('sos-stop'));
    await tester.pumpAndSettle();
    expect(find.text('STOP ALL AGENTS'), findsOneWidget);
    expect(
      find.text('Agents could not be stopped. Try again.'),
      findsOneWidget,
    );
    expect(_onPressed(tester, 'sos-stop'), isNotNull);
    await tester.tap(_button('sos-cancel'));
    expect(closed, 1);
  });

  testWidgets('a failed resume keeps the guidance for another try', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: Center(
            child: RaftSosDialog(
              channelName: 'release',
              initialPhase: RaftSosPhase.stopped,
              onStop: () async => null,
              onResume: (_) async => 'Server busy',
              onClose: () => closed++,
            ),
          ),
        ),
      ),
    );
    final field = find.descendant(
      of: _button('sos-guidance'),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, 'Revert the schema change');
    await tester.pump();
    await tester.tap(_button('sos-resume'));
    await tester.pumpAndSettle();
    expect(find.text('Server busy'), findsOneWidget);
    expect(find.text('Revert the schema change'), findsOneWidget);
    expect(_onPressed(tester, 'sos-resume'), isNotNull);
    expect(closed, 0);
    await tester.tap(_button('sos-keep-stopped'));
    expect(closed, 1);
  });

  testWidgets('copy is localized', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('zh'),
              child: Center(
                child: RaftSosDialog(
                  channelName: 'release',
                  onStop: () async => null,
                  onResume: (_) async => null,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('停止所有 AGENT'), findsOneWidget);
    expect(
      find.text('#release 中所有正在运行的 Agent 都会立即停止。恢复前，你可以提供新的指导。'),
      findsOneWidget,
    );
    expect(find.text('停止'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}
