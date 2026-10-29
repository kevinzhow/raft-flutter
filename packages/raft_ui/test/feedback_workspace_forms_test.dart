import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Widget _host(Widget child, {bool dark = false}) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(body: SizedBox(width: 900, height: 700, child: child)),
);

final _png = Uint8List.fromList(const [
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  255,
  255,
  63,
  0,
  5,
  254,
  2,
  254,
  167,
  53,
  129,
  132,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    group('${dark ? 'dark' : 'light'}', () {
      testWidgets('composer: Enter submits, Shift+Enter and IME composition '
          'do not; the counter and actions render', (t) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        var submitted = 0;
        final changes = <String>[];
        await t.pumpWidget(
          _host(
            Padding(
              padding: const EdgeInsets.all(20),
              child: RaftFeedbackComposer(
                controller: controller,
                label: 'Reply',
                placeholder: 'Write a reply…',
                inputKey: const ValueKey('input'),
                actions: [
                  RaftComposerAction(
                    key: const ValueKey('send'),
                    glyph: RaftGlyph.send,
                    tooltip: 'Send Reply',
                    onPressed: () => submitted++,
                  ),
                ],
                onSubmit: () => submitted++,
                onChanged: changes.add,
              ),
            ),
            dark: dark,
          ),
        );
        expect(find.text('Write a reply…'), findsOneWidget);
        await t.enterText(find.byKey(const ValueKey('input')), 'Hello');
        await t.pump();
        expect(changes, ['Hello']);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(submitted, 1);
        await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        expect(submitted, 1);
        controller.value = const TextEditingValue(
          text: 'ni',
          composing: TextRange(start: 0, end: 2),
        );
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(submitted, 1);
        await t.tap(find.byKey(const ValueKey('send')));
        expect(submitted, 2);
      });

      testWidgets('composer: pending files show state; busy shows upload '
          'progress and removes the remove button; the error banner shows', (
        t,
      ) async {
        final controller = TextEditingController(text: 'x' * 10001);
        addTearDown(controller.dispose);
        final removed = <String>[];
        var images = 0, files = 0;
        Future<void> pump({required bool busy}) => t.pumpWidget(
          _host(
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: RaftFeedbackComposer(
                controller: controller,
                label: 'Message',
                newFeedback: true,
                placeholder: 'Describe…',
                busy: busy,
                error: 'Check the feedback details and try again.',
                attachments: [
                  RaftFeedbackPendingFile(
                    id: 'a',
                    name: 'one.png',
                    contentType: 'image/png',
                    bytes: _png,
                    progress: .5,
                  ),
                  const RaftFeedbackPendingFile(
                    id: 'b',
                    name: 'two.png',
                    contentType: 'image/png',
                    state: RaftFeedbackUploadState.failed,
                  ),
                  const RaftFeedbackPendingFile(
                    id: 'c',
                    name: 'three.gif',
                    contentType: 'image/gif',
                    state: RaftFeedbackUploadState.uploading,
                    progress: .5,
                  ),
                ],
                onRemoveAttachment: removed.add,
                onAttachImage: () => images++,
                onAttachFile: () => files++,
                actions: const [],
              ),
            ),
            dark: dark,
          ),
        );
        await pump(busy: false);
        expect(
          find.text('Check the feedback details and try again.'),
          findsOneWidget,
        );
        expect(find.text('10001/10000'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('feedback-pending-a')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('feedback-pending-b')),
          findsOneWidget,
        );
        expect(find.textContaining('Uploading'), findsNothing);
        await t.pumpWidget(const SizedBox());
        await pump(busy: true);
        expect(find.text('Uploading 33%'), findsOneWidget);
        expect(removed, isEmpty);
        expect([images, files], [0, 0]);
      });

      testWidgets('new form: back, kind picker and content', (t) async {
        var back = 0;
        final kinds = <bool>[];
        await t.pumpWidget(
          _host(
            RaftFeedbackNewForm(
              onBack: () => back++,
              problem: false,
              onKind: kinds.add,
              composer: const SizedBox(height: 40),
            ),
            dark: dark,
          ),
        );
        expect(find.text('New Feedback'), findsOneWidget);
        expect(find.text('Up to 3 images.'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('feedback-kind-bug')));
        await t.tap(find.byKey(const ValueKey('feedback-back')));
        expect(kinds, [true]);
        expect(back, 1);
      });

      testWidgets('conversation: messages with attachments and footers, the '
          'reply composer slot, loading, error with retry and load more', (
        t,
      ) async {
        var retried = 0, more = 0;
        Future<void> pump({
          bool loading = false,
          String? error,
          Widget? composer,
          bool loadingMore = false,
        }) => t.pumpWidget(
          _host(
            RaftFeedbackConversation(
              onBack: () {},
              loading: loading,
              error: error,
              onRetry: () => retried++,
              onLoadMore: () => more++,
              loadingMore: loadingMore,
              composer: composer,
              messages: const [
                RaftFeedbackMessageData(
                  id: 'm1',
                  author: RaftFeedbackAuthor.reporter,
                  sender: 'You',
                  time: 'Oct 1, 2026, 1:00 PM',
                  body: 'Hello\nthere',
                  attachments: [('shot.png', '12 kB')],
                  footer: [Text('footer')],
                ),
                RaftFeedbackMessageData(
                  id: 'm2',
                  author: RaftFeedbackAuthor.staff,
                  sender: 'Team',
                  time: 'Oct 2, 2026, 1:00 PM',
                  body: 'Thanks',
                ),
                RaftFeedbackMessageData(
                  id: 'm3',
                  author: RaftFeedbackAuthor.system,
                  sender: 'System',
                  time: 'Oct 3, 2026, 1:00 PM',
                  body: 'Closed',
                ),
              ],
            ),
            dark: dark,
          ),
        );
        await pump(composer: const SizedBox(height: 60, key: ValueKey('c')));
        expect(find.text('Hello there'), findsOneWidget);
        expect(find.textContaining('shot.png'), findsOneWidget);
        expect(find.text('footer'), findsOneWidget);
        expect(find.byKey(const ValueKey('c')), findsOneWidget);
        await pump(error: 'Couldn’t load feedback. Try again.');
        await t.tap(find.text('Try Again'));
        expect(retried, 1);
        await pump(loading: true);
        await pump(loadingMore: true);
        expect(more, 0);
      });
    });
  }

  testWidgets('view header: back and trailing', (t) async {
    var back = 0;
    await t.pumpWidget(
      _host(
        RaftFeedbackViewHeader(
          title: 'My Feedback',
          onBack: () => back++,
          trailing: const Text('trail'),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('feedback-back')));
    expect(back, 1);
    expect(find.text('trail'), findsOneWidget);
  });
}
