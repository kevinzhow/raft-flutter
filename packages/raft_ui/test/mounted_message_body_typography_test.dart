import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_content_tokens.dart';

const prose =
    'Captured the Android visual artifact for #product:f8e569cb and queued React parity.';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'mounted prose uses source face/colour/tracking $family/$dark',
      (t) async {
        await t.runAsync(() async {
          final asset = family == RaftFamily.brutal
              ? 'HankenGrotesk.ttf'
              : 'Geist.ttf';
          ByteData data;
          try {
            data = await rootBundle.load(
              'packages/raft_ui/assets/fonts/$asset',
            );
          } on FlutterError {
            data = await rootBundle.load('assets/fonts/$asset');
          }
          final tokens = raftTheme(family, dark: dark).extension<RaftTokens>()!;
          await (FontLoader(
            tokens.bodyFont,
          )..addFont(Future.value(data))).load();
        });
        final theme = raftTheme(family, dark: dark);
        final tokens = theme.extension<RaftTokens>()!;
        Future<RenderParagraph> mount(bool mounted, double width) async {
          await t.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: RaftMessageBody(
                      content: prose,
                      mountedMessage: mounted,
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pump();
          return t.renderObject<RenderParagraph>(
            find
                .byWidgetPredicate(
                  (w) => w is RichText && w.text.toPlainText() == prose,
                )
                .first,
          );
        }

        final baseline = await mount(false, 531);
        final baselineHeight = baseline.size.height;
        final mounted = await mount(true, 531);
        TextStyle resolvedStyle(InlineSpan span, TextStyle inherited) {
          final own = inherited.merge(span.style);
          if (span is TextSpan) {
            if (span.text?.contains('Captured') == true) return own;
            for (final child in span.children ?? <InlineSpan>[]) {
              if (child.toPlainText().contains('Captured'))
                return resolvedStyle(child, own);
            }
          }
          throw StateError('Missing actual paragraph text span');
        }

        final style = resolvedStyle(mounted.text, const TextStyle());
        expect(style.fontFamily, tokens.bodyFont);
        expect(style.fontSize, 14);
        expect(style.height, 20 / 14);
        expect(style.letterSpacing, family == RaftFamily.brutal ? 0 : -.14);
        expect(
          style.color,
          // Mounted MessageItem overrides Brutal body to text-black;
          // generic/document prose still uses foreground-strong below.
          family == RaftFamily.brutal ? Colors.black : tokens.muted,
        );
        if (family == RaftFamily.elegant) {
          // Actual loaded Web Geist: 0 tracking=537.01px, -.14=525.39px.
          // 531px is the real desktop Main paragraph's available width.
          expect(baselineHeight, closeTo(40, .01));
          expect(mounted.size.height, closeTo(20, .01));
        }
        final mountedHeight = mounted.size.height;
        final narrow = await mount(true, 278);
        expect(narrow.size.height, greaterThan(mountedHeight));
        expect(t.takeException(), isNull);
      },
    );
    testWidgets('inline code padding preserves selected code $family/$dark', (
      t,
    ) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copied = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: const Scaffold(
            body: RaftMessageBody(
              content: 'prefix `a/<app>/latest` suffix',
              mountedMessage: true,
            ),
          ),
        ),
      );
      await t.pump();
      final paragraph = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('a/<app>/latest'),
      );
      await t.tap(paragraph.first);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await t.sendKeyEvent(LogicalKeyboardKey.keyC);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pump();
      expect(copied, 'prefix a/<app>/latest suffix');
      expect(t.takeException(), isNull);
    });
    for (final (size, line) in [(12.0, 16.0), (14.0, 20.0), (16.0, 24.0)]) {
      test(
        'mounted preference $size keeps source line height $family/$dark',
        () {
          final tokens = raftTheme(family, dark: dark).extension<RaftTokens>()!;
          final recipe = MessageContentRecipe(
            tokens,
            fontSize: size,
            mountedMessage: true,
          );
          expect(recipe.body.height! * size, line);
          expect(recipe.heading(1).letterSpacing, recipe.body.letterSpacing);
          expect(
            recipe.body.letterSpacing,
            family == RaftFamily.brutal ? 0 : -size * .01,
          );
          final generic = MessageContentRecipe(tokens, fontSize: size);
          final document = MessageContentRecipe(
            tokens,
            fontSize: size,
            document: true,
            mountedMessage: true,
          );
          expect(generic.body.letterSpacing, 0);
          expect(document.body.letterSpacing, 0);
          expect(document.body.height! * size, 24);
          expect(document.body.color, tokens.strong);
        },
      );
    }
  }
}
