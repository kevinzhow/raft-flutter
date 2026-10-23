import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.21.23 MessageItem: the Saved badge in the footer, the sender menu
/// on the name and avatar, the selected-text Quote / Copy pair and the read
/// marker on an @mentioned agent.
/// A mouse drag across the body's text.
Future<void> dragSelect(WidgetTester tester) async {
  final rect = tester.getRect(
    find.textContaining('Select', findRichText: true),
  );
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: rect.centerLeft + const Offset(1, 0));
  await tester.pump();
  await mouse.down(rect.centerLeft + const Offset(1, 0));
  await mouse.moveTo(rect.centerRight - const Offset(1, 0));
  await mouse.up();
  await mouse.removePointer();
  await tester.pump();
}

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );

  test('a quote is a Markdown blockquote, appended below the draft', () {
    expect(
      raftFormatSelectedTextQuote('a\n\nb  \r\nc\n'),
      '> a\n>\n> b  \n> c',
    );
    expect(raftHasQuotableSelection(' \n '), isFalse);
    expect(raftAppendQuoteToComposer('', '> a'), '> a\n\n');
    expect(raftAppendQuoteToComposer('hi  ', '> a'), 'hi\n\n> a\n\n');
  });

  testWidgets('a saved message shows the Saved badge and unsaves from it', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      host(
        RaftMessageTile(
          author: 'Ada',
          content: 'hello',
          timestamp: '09:41',
          savedIndicator: RaftMessageSavedIndicator(onPressed: () => pressed++),
        ),
      ),
    );
    expect(find.text('Saved'), findsOneWidget);
    await tester.tap(find.byKey(const Key('message-saved-badge')));
    expect(pressed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('right-click on the name or avatar opens the sender menu', (
    tester,
  ) async {
    final opened = <Offset>[];
    await tester.pumpWidget(
      host(
        RaftMessageRow(
          author: 'Ada',
          timestamp: '09:41',
          avatar: const ColoredBox(key: Key('avatar'), color: Colors.blue),
          content: const Text('Body'),
          onAuthorMenu: opened.add,
        ),
      ),
    );
    for (final target in [find.text('Ada'), find.byKey(const Key('avatar'))]) {
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await mouse.down(tester.getCenter(target));
      await mouse.up();
      await tester.pump();
    }
    expect(opened, hasLength(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a mouse selection offers Quote and Copy beside it', (
    tester,
  ) async {
    final quoted = <String>[];
    await tester.pumpWidget(
      host(
        RaftSelectionShortcutScope(
          onQuote: quoted.add,
          child: const RaftMessageBody(
            content: 'Select this sentence',
            mountedMessage: true,
          ),
        ),
      ),
    );
    await dragSelect(tester);
    await tester.pump(
      raftSelectionShortcutDelay + const Duration(milliseconds: 20),
    );
    await tester.pump();
    expect(find.text('Quote'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Quote'));
    await tester.pump();
    expect(quoted, ['Select this sentence']);
    expect(find.text('Quote'), findsNothing, reason: 'the pair closes');
    await dragSelect(tester);
    await tester.pump(
      raftSelectionShortcutDelay + const Duration(milliseconds: 20),
    );
    await tester.pump();
    expect(find.text('Copy'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Copy'), findsNothing, reason: 'Escape closes the pair');
    await tester.pumpWidget(const SizedBox());
    // A pointer-and-keyboard desktop; the test default is a phone.
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a quote lands below the draft and focuses the composer', (
    tester,
  ) async {
    final handle = RaftComposerHandle();
    await tester.pumpWidget(
      host(
        RaftComposer(
          initialDraft: 'hello',
          handle: handle,
          onSend: (text) async => true,
        ),
      ),
    );
    handle.quoteSelection('first\nsecond');
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'hello\n\n> first\n> second\n\n');
    handle.quoteSelection('   ');
    await tester.pump();
    expect(field.controller!.text, 'hello\n\n> first\n> second\n\n');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without a composer in scope a selection shows no pair', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const RaftMessageBody(
          content: 'Select this sentence',
          mountedMessage: true,
        ),
      ),
    );
    await dragSelect(tester);
    await tester.pump(
      raftSelectionShortcutDelay + const Duration(milliseconds: 20),
    );
    expect(find.text('Quote'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an @mentioned agent carries a read marker, others do not', (
    tester,
  ) async {
    RaftReferenceAppearance? appearance(String href) => RaftReferenceAppearance(
      RaftReferenceKind.mention,
      agentRead: switch (href) {
        'raft-ref://mention/agent/read' => true,
        'raft-ref://mention/agent/unread' => false,
        _ => null,
      },
    );
    await tester.pumpWidget(
      host(
        RaftMessageBody(
          content: '@Ada @Bo @Cy',
          mountedMessage: true,
          references: const [
            RaftTextReference(
              text: '@Ada',
              href: 'raft-ref://mention/agent/read',
            ),
            RaftTextReference(
              text: '@Bo',
              href: 'raft-ref://mention/agent/unread',
            ),
            RaftTextReference(
              text: '@Cy',
              href: 'raft-ref://mention/user/human',
            ),
          ],
          referenceAppearance: appearance,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('mention-read-read')), findsOneWidget);
    expect(find.byKey(const ValueKey('mention-read-unread')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
