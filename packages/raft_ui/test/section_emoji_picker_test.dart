import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// SidebarSectionDialog emoji button -> SidebarSectionEmojiPicker popover.
void main() {
  Future<void> mount(
    WidgetTester tester, {
    String initialEmoji = '',
    void Function(String, String?)? onSubmit,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Center(
            child: RaftSidebarSectionDialog(
              title: 'New Section',
              submitLabel: 'Create section',
              initialEmoji: initialEmoji,
              onClose: () {},
              onSubmit: onSubmit ?? (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the emoji button opens the picker and a pick fills the button', (
    tester,
  ) async {
    String? submitted;
    await mount(tester, onSubmit: (name, emoji) => submitted = emoji);
    expect(find.byType(RaftEmojiPicker), findsNothing);
    await tester.tap(find.byKey(sectionEmojiButtonKey));
    await tester.pump();
    expect(find.byType(RaftEmojiPicker), findsOneWidget);
    // Autofocused search, nine category buttons, Smileys & People first.
    expect(find.text('Smileys & People'), findsOneWidget);
    expect(find.byType(RaftEmojiNavIcon), findsNWidgets(9));
    await tester.tap(find.text('\u{1F600}').first);
    await tester.pump();
    expect(find.byType(RaftEmojiPicker), findsNothing);
    expect(find.text('\u{1F600}'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Work');
    await tester.pump();
    await tester.tap(find.text('Create section'));
    expect(submitted, '\u{1F600}');
  });

  testWidgets('search narrows the grid to matching words', (tester) async {
    await mount(tester);
    await tester.tap(find.byKey(sectionEmojiButtonKey));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('emoji-picker-search')),
      'grinning face',
    );
    await tester.pump();
    expect(find.text('\u{1F600}'), findsOneWidget);
    expect(find.text('\u{1F62D}'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('emoji-picker-search')),
      'zzzznotanemoji',
    );
    await tester.pump();
    expect(find.text('No results found'), findsOneWidget);
  });

  testWidgets('a chosen emoji offers No emoji, which clears it', (tester) async {
    String? submitted = 'unset';
    await mount(
      tester,
      initialEmoji: '\u{1F680}',
      onSubmit: (_, emoji) => submitted = emoji,
    );
    await tester.tap(find.byKey(sectionEmojiButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('section-no-emoji')));
    await tester.pump();
    expect(find.byType(RaftEmojiPicker), findsNothing);
    await tester.enterText(find.byType(TextField), 'Launch');
    await tester.pump();
    await tester.tap(find.text('Create section'));
    expect(submitted, isNull);
  });

  testWidgets('the skin tone swatch applies to emoji with variants', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byKey(sectionEmojiButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('emoji-tone-button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('emoji-tone-2')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('emoji-picker-search')),
      'waving hand',
    );
    await tester.pump();
    // U+1F44B with the medium-light modifier U+1F3FC.
    expect(find.text('\u{1F44B}\u{1F3FC}'), findsOneWidget);
  });
}
