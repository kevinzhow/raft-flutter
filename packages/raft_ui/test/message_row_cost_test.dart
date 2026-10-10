import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _code = '```dart\nfinal answer = 42;\nString greet() => "hi";\n```';
const _body = 'First prose paragraph.\n\n$_code\n\nLast prose paragraph.';

Widget _host(Widget child, {bool dark = false}) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant, dark: dark),
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 600, child: child)),
  ),
);

void main() {
  setUp(() {
    raftCodeSpanCache.clear();
    raftMarkdownAstCache.clear();
  });

  testWidgets('code tokens and Markdown are computed once per message', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const RaftMessageBody(content: _body)));
    expect(raftCodeSpanCache.misses, 1);
    expect(raftMarkdownAstCache.misses, 2);
    final text = find.byType(SelectableText);
    final span = tester.widget<SelectableText>(text).textSpan;

    // Hover and focus feedback rebuild the copy control, not the tokens.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(text));
    await tester.pump();
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(tester.widget<SelectableText>(text).textSpan, same(span));
    expect(raftCodeSpanCache.misses + raftCodeSpanCache.hits, 1);

    // Remounting the same message (scrolled away and back) reuses both.
    await tester.pumpWidget(_host(const SizedBox()));
    await tester.pumpWidget(_host(const RaftMessageBody(content: _body)));
    expect(raftCodeSpanCache.misses, 1);
    expect(raftMarkdownAstCache.misses, 2);
    expect(raftMarkdownAstCache.hits, 2);
    expect(tester.widget<SelectableText>(text).textSpan, same(span));

    // A different token theme is a different highlight input.
    await tester.pumpWidget(
      _host(const RaftMessageBody(content: _body), dark: true),
    );
    await tester.pumpAndSettle();
    expect(raftCodeSpanCache.misses, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cached Markdown renders exactly like a fresh parse', (
    tester,
  ) async {
    const content =
        '## Heading\n\n**Bold** *em* `code` [link](https://example.invalid)\n\n'
        '- one\n- two\n\n| a | b |\n|---|---|\n|  | 2 |\n\n> quote';
    Future<List<Rect>> layout() async {
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpWidget(_host(const RaftMessageBody(content: content)));
      return [
        for (final e in find.byType(RichText).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
    }

    final fresh = await layout();
    expect(raftMarkdownAstCache.misses, 1);
    final cached = await layout();
    expect(raftMarkdownAstCache.hits, greaterThan(0));
    expect(cached, fresh);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one selection region spans prose around a code block', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(_host(const RaftMessageBody(content: _body)));
    expect(find.byType(SelectionArea), findsOneWidget);
    final first = find.text('First prose paragraph.', findRichText: true);
    final last = find.text('Last prose paragraph.', findRichText: true);
    final gesture = await tester.startGesture(
      tester.getTopLeft(first) + const Offset(1, 2),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(tester.getBottomRight(last) - const Offset(1, 2));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(copied, startsWith('First prose paragraph.'));
    expect(copied, endsWith('Last prose paragraph.'));
    // Code-block controls never join the prose selection.
    expect(copied, isNot(contains('Copy code')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long content shows its toggle in its first frame', (
    tester,
  ) async {
    final content = List.generate(30, (i) => 'Paragraph $i.').join('\n\n');
    await tester.pumpWidget(
      _host(RaftCollapsible(child: RaftMessageBody(content: content))),
    );
    // No second pump: the toggle and the capped viewport are final at once.
    expect(find.text('Show more'), findsOneWidget);
    final firstToggle = tester.getRect(find.text('Show more'));
    final firstSize = tester.getSize(find.byType(RaftCollapsible));
    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byType(RaftCollapsible),
                  matching: find.byType(ClipRect),
                )
                .first,
          )
          .height,
      320,
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getRect(find.text('Show more')), firstToggle);
    expect(tester.getSize(find.byType(RaftCollapsible)), firstSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('code block layout is final at first frame and on hover', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const RaftMessageBody(content: _code)));
    final box = find.byKey(const ValueKey('code-container'));
    final first = tester.getRect(box);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(box));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(box), first);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'idle rows build no toolbar; keyboard traversal still reaches every action',
    (tester) async {
      final activated = <String>[];
      Widget row(int i) => RaftMessageRow(
        key: ValueKey('row-$i'),
        author: 'Author $i',
        timestamp: '12:0$i',
        content: Text('Body $i'),
        toolbar: RaftMessageToolbar(
          children: [
            for (final name in ['reply', 'save'])
              RaftMessageToolbarAction(
                key: ValueKey('$name-$i'),
                label: '$name $i',
                icon: const SizedBox(),
                onPressed: () => activated.add('$name-$i'),
              ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: Column(children: [row(0), row(1)])),
        ),
      );
      expect(
        find.byType(RaftMessageToolbar, skipOffstage: false),
        findsNothing,
        reason: 'A mounted idle row must not build its hidden action strip.',
      );
      bool focused(String key) =>
          Focus.of(tester.element(find.byKey(ValueKey(key)))).hasFocus;
      Future<void> tab({bool shift = false}) async {
        if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        await tester.pump();
      }

      await tab();
      expect(focused('reply-0'), isTrue);
      await tab();
      expect(focused('save-0'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activated, ['save-0']);
      await tab();
      expect(focused('reply-1'), isTrue);
      expect(find.byKey(const ValueKey('save-0')), findsNothing);
      await tab(shift: true);
      expect(focused('save-0'), isTrue, reason: 'Shift+Tab enters at the end.');
      expect(find.byType(RaftMessageToolbar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
