import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.24 useMessageTouchTaps: on a touch screen a tap on a message opens
/// its thread (after waiting for a possible second tap), a double tap opens
/// the quick-reaction bar where the finger is, press and hold opens the menu
/// and is no tap; controls inside the message keep their own taps.
void main() {
  late List<String> events;

  Future<void> pump(
    WidgetTester t, {
    bool doubleTap = true,
    Widget? content,
  }) async {
    events = [];
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ListView(
            children: [
              RaftMessageRow(
                author: 'Alice',
                timestamp: '9:00',
                content:
                    content ??
                    RaftMessageBody(
                      content: 'Tap this text, or [the link](https://example.invalid)\n\n```\ncode\n```',
                      messagePipeline: true,
                      onLink: (_) => events.add('link'),
                    ),
                onTouchTap: () => events.add('thread'),
                onTouchDoubleTap: doubleTap
                    ? (at) => events.add('bar@${at.dx.round()}')
                    : null,
                onActionsAt: (_) => events.add('menu'),
              ),
            ],
          ),
        ),
      ),
    );
    await t.pump();
  }

  Offset textPoint(WidgetTester t) =>
      t.getTopLeft(find.textContaining('Tap this text', findRichText: true)) +
      const Offset(8, 6);

  testWidgets('a tap opens the thread once the double-tap window passes', (
    t,
  ) async {
    await pump(t);
    await t.tapAt(textPoint(t));
    await t.pump(const Duration(milliseconds: 100));
    expect(events, isEmpty);
    await t.pump(const Duration(milliseconds: 200));
    expect(events, ['thread']);
  });

  testWidgets('without a double tap the tap opens the thread at once', (
    t,
  ) async {
    await pump(t, doubleTap: false);
    await t.tapAt(textPoint(t));
    await t.pump();
    expect(events, ['thread']);
  });

  testWidgets('a double tap opens the reaction bar at the finger, no thread', (
    t,
  ) async {
    await pump(t);
    final at = textPoint(t);
    await t.tapAt(at);
    await t.pump(const Duration(milliseconds: 80));
    await t.tapAt(at);
    await t.pump(const Duration(milliseconds: 400));
    expect(events, ['bar@${at.dx.round()}']);
  });

  testWidgets('two taps far apart are two taps', (t) async {
    await pump(t);
    final at = textPoint(t);
    await t.tapAt(at);
    await t.pump(const Duration(milliseconds: 80));
    await t.tapAt(at + const Offset(60, 0));
    await t.pump(const Duration(milliseconds: 400));
    expect(events, ['thread', 'thread']);
  });

  testWidgets('a link and a code block keep their own taps', (t) async {
    await pump(
      t,
      content: RaftMessageBody(
        content: '[the link](https://example.invalid)',
        onLink: (_) => events.add('link'),
      ),
    );
    await t.tapAt(
      t.getTopLeft(find.textContaining('the link', findRichText: true)) +
          const Offset(10, 6),
    );
    await t.pump(const Duration(milliseconds: 400));
    expect(events, ['link']);
    await pump(t);
    await t.tapAt(t.getCenter(find.byType(RaftCodeBlock)));
    await t.pump(const Duration(milliseconds: 400));
    expect(events, isEmpty);
  });

  testWidgets('a mouse click is no touch tap', (t) async {
    await pump(t);
    await t.tapAt(textPoint(t), kind: PointerDeviceKind.mouse);
    await t.pump(const Duration(milliseconds: 400));
    expect(events, isEmpty);
  });

  testWidgets('press and hold opens the menu and is no tap', (t) async {
    await pump(t, content: const SizedBox(height: 40, width: 300));
    final at = t.getCenter(find.byType(RaftMessageRow)) + const Offset(0, 4);
    await t.longPressAt(at);
    await t.pump(const Duration(milliseconds: 400));
    expect(events, ['menu']);
  });

  testWidgets('a drag is no tap', (t) async {
    await pump(t);
    await t.dragFrom(textPoint(t), const Offset(0, -40));
    await t.pump(const Duration(milliseconds: 400));
    expect(events, isEmpty);
  });
}
