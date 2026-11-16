import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Message-list family against raft-ui 0.95.3: SystemMessage (message-system
// recipe), MessageListDateDivider (message-list recipe), MessageReplies,
// MessageListJumpPill (Button outline md) and MessageListEndFade.
// Input mode is set with RaftInteractionScope, never by width.

const _desktop = Size(1440, 900);
const _phone = Size(390, 844);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required bool touch,
  bool dark = false,
  double width = 340,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RaftInteractionScope(
      interaction: touch
          ? RaftInteraction.touchMode
          : RaftInteraction.pointerMode,
      child: MaterialApp(
        theme: raftTheme(dark: dark),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

RaftTokens _tokens(WidgetTester tester, Type type) =>
    RaftTokens.of(tester.element(find.byType(type).first));

void main() {
  final cases = <(String, Size, bool, bool)>[
    ('linux 1440x900 light', _desktop, false, false),
    ('linux 1440x900 dark', _desktop, false, true),
    ('android 390x844 light', _phone, true, false),
    ('android 390x844 dark', _phone, true, true),
  ];
  for (final (name, size, touch, dark) in cases) {
    final line = touch || size.width < 768 ? 16.0 : 18.0;
    group(name, () {
      testWidgets('system message: lead 12, mono hint, hairline rules', (
        tester,
      ) async {
        await _pump(
          tester,
          const RaftSystemMessage(
            content: 'Joined the channel',
            timestamp: '12:34',
          ),
          size: size,
          touch: touch,
          dark: dark,
        );
        final t = _tokens(tester, RaftSystemMessage);
        expect(
          tester.getSize(find.byType(RaftSystemMessage)).height,
          12 + line + 4,
        );
        for (final text in ['12:34', 'Joined the channel']) {
          final style = tester.widget<Text>(find.text(text)).style!;
          expect(style.fontSize, 12);
          expect(style.fontFamily, t.monoFont);
          expect(style.color, t.colors['foreground-hint']);
        }
        final before = tester.getRect(
          find.byKey(const ValueKey('system-message-rule-before')),
        );
        final after = tester.getRect(
          find.byKey(const ValueKey('system-message-rule-after')),
        );
        expect(before.height, 1);
        expect(after.height, 1);
        expect(before.left, 16);
        expect(before.width, greaterThanOrEqualTo(12));
        expect(340 - after.right, 16);
      });

      testWidgets('date divider: one nowrap mono line, no opacity', (
        tester,
      ) async {
        await _pump(
          tester,
          const RaftConversationDateHeader(label: 'Monday, November 16'),
          size: size,
          touch: touch,
          dark: dark,
        );
        final t = _tokens(tester, RaftConversationDateHeader);
        // pt = 24 - 4 - lh/2, pb = 24 - 12 - lh/2: 32 at both line heights.
        expect(
          tester.getSize(find.byType(RaftConversationDateHeader)).height,
          32,
        );
        final text = tester.widget<Text>(find.text('Monday, November 16'));
        expect(text.style!.fontSize, 12);
        expect(text.style!.color, t.colors['foreground-hint']);
        expect(text.maxLines, 1);
        expect(text.softWrap, false);
        expect(
          find.descendant(
            of: find.byType(RaftConversationDateHeader),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
        expect(
          tester
              .getRect(
                find
                    .descendant(
                      of: find.byType(RaftConversationDateHeader),
                      matching: find.byType(ColoredBox),
                    )
                    .first,
              )
              .left,
          16,
        );
      });

      testWidgets('jump pill is Button outline md with a 16 glyph', (
        tester,
      ) async {
        await _pump(
          tester,
          RaftTimelineBottomButtonBody(
            label: 'Back to bottom',
            onPressed: () {},
          ),
          size: size,
          touch: touch,
          dark: dark,
        );
        expect(
          tester.getSize(find.byType(RaftTimelineBottomButtonBody)).height,
          touch || size.width < 768 ? 32 : 34,
        );
        expect(tester.widget<RaftIcon>(find.byType(RaftIcon)).size, 16);
        expect(
          DefaultTextStyle.of(tester.element(find.text('Back to bottom')))
              .style
              .fontSize,
          touch || size.width < 768 ? 13 : 14,
        );
      });

      testWidgets('thread unread pill matches the button height', (
        tester,
      ) async {
        await _pump(
          tester,
          RaftThreadUnreadJumpPill(
            up: false,
            label: 'Next unread thread',
            dismissLabel: 'Dismiss',
            onJump: () {},
            onDismiss: () {},
          ),
          size: size,
          touch: touch,
          dark: dark,
          width: 390,
        );
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey('thread-unread-jump-pill-bottom')),
              )
              .height,
          touch || size.width < 768 ? 32 : 34,
        );
      });

      testWidgets('inline replies: fill-muted block, no border or radius', (
        tester,
      ) async {
        await _pump(
          tester,
          RaftInlineThreadSurface(
            replyCount: 1,
            summary: const Text('1 reply'),
            semanticLabel: 'Open thread',
            onOpen: () {},
            replies: const [
              RaftInlineReply(
                id: 'r1',
                author: 'Ada',
                preview: 'Looks good',
                senderType: 'user',
                timestamp: '12:34',
              ),
            ],
          ),
          size: size,
          touch: touch,
          dark: dark,
        );
        final t = _tokens(tester, RaftInlineThreadSurface);
        final box = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decoration = box.decoration! as BoxDecoration;
        expect(decoration.color, t.colors['fill-muted']);
        expect(decoration.border, isNull);
        expect(decoration.borderRadius, isNull);
        expect(
          box.padding,
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        );
        expect(
          tester.getTopLeft(find.byType(AnimatedContainer)).dy -
              tester.getTopLeft(find.byType(RaftInlineThreadSurface)).dy,
          8,
        );
        final sender = tester.widget<Text>(find.text('Ada')).style!;
        expect(sender.fontWeight, FontWeight.w600);
        expect(sender.fontSize, touch || size.width < 768 ? 13 : 12);
        expect(
          tester.widget<Text>(find.text('Looks good')).style!.color,
          t.colors['foreground-hint'],
        );
        final time = tester.widget<Text>(find.text('12:34')).style!;
        expect(time.fontFamily, t.monoFont);
        expect(time.color, t.colors['foreground-hint']);
      });

      testWidgets('end fade: 24px canvas to transparent, ignores pointer', (
        tester,
      ) async {
        await _pump(
          tester,
          const SizedBox(
            height: 100,
            child: Stack(children: [RaftMessageListEndFade()]),
          ),
          size: size,
          touch: touch,
          dark: dark,
        );
        final t = _tokens(tester, RaftMessageListEndFade);
        expect(tester.getSize(find.byType(RaftMessageListEndFade)).height, 24);
        expect(tester.getRect(find.byType(RaftMessageListEndFade)).bottom, 100);
        final fade = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(RaftMessageListEndFade),
            matching: find.byType(DecoratedBox),
          ),
        );
        final gradient =
            (fade.decoration as BoxDecoration).gradient! as LinearGradient;
        final canvas = t.colors['layer-canvas']!;
        expect(gradient.begin, Alignment.bottomCenter);
        expect(gradient.colors.first, canvas);
        expect(gradient.colors.last.a, 0);
        expect(
          find.descendant(
            of: find.byType(RaftMessageListEndFade),
            matching: find.byType(IgnorePointer),
          ),
          findsWidgets,
        );
      });
    });
  }
}
