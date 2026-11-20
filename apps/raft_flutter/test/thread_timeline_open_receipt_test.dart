import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/history_reading_anchor.dart';
import 'package:raft_flutter/features/thread_outline_list.dart';
import 'package:raft_ui/raft_ui.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_context_transition_test.dart' show row;
import 'mounted_message_navigation_test.dart' show mountPage, pageFixture;

const _timeline = Key('chat-list-thread');
const _parentRow = ValueKey('thread-outline-row-parent');
const _lastReply = 'timeline-reply-60';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Timeline opens at its platform anchor and preserves the reader until selection '
      '(${dark ? 'dark' : 'light'})',
      (tester) async {
        final phone = defaultTargetPlatform == TargetPlatform.android;
        final size = phone ? const Size(390, 844) : const Size(1280, 800);
        final (workspace, api) = await pageFixture(tester);
        final parent = row('parent', 'c1', 1);
        final replies = [
          for (var i = 1; i <= 60; i++) row('timeline-reply-$i', 't1', i + 1),
        ];
        api.routes['GET /messages/context/parent'] = (_) => {
          'messages': [parent],
        };
        api.routes['GET /messages/channel/t1'] = (_) => {'messages': replies};
        api.routes['GET /messages/channel/t1/human-outline'] = (_) => {
          'items': [
            for (final message in [...replies.reversed, parent])
              {
                ...message,
                'senderName': 'Alice',
                'preview': message['content'],
              },
          ],
          'hasMore': false,
        };
        await tester.runAsync(() async {
          await workspace.openThreadIdentity(
            parentChannelId: 'c1',
            parentMessageId: 'parent',
            initialThreadChannelId: 't1',
          );
          for (
            var i = 0;
            i < 40 && workspace.messageDomain.threadParentLoading;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
        await mountPage(
          tester,
          workspace,
          dark,
          width: size.width,
          height: size.height,
        );
        final timeline = find.byKey(_timeline);
        final outline = find.byKey(
          Key(phone ? 'thread-timeline-sheet' : 'thread-timeline-popover'),
        );
        final outlineScroll = find.descendant(
          of: outline,
          matching: find.byType(Scrollable),
        );
        final parentRow = find.byKey(_parentRow);
        ScrollPosition outlinePosition() =>
            tester.state<ScrollableState>(outlineScroll).position;
        final route = workspace.location.uri;
        final receipts = <Map<String, Object?>>[];

        ({String first, double top, double pixels, double end, bool tail})
        receipt(String phase) {
          final context = tester.element(timeline);
          final anchor = captureTimelineReadingAnchor(
            context,
            threadParentKey: 'parent',
          )!;
          final scrollable = find
              .descendant(of: timeline, matching: find.byType(Scrollable))
              .first;
          final position = tester.state<ScrollableState>(scrollable).position;
          final tail = paintedMessage(tester, _lastReply) != null;
          expect(workspace.location.uri, route, reason: phase);
          final matchingTheme =
              Theme.of(context).brightness ==
              (dark ? Brightness.dark : Brightness.light);
          expect(matchingTheme, isTrue);
          receipts.add({
            'phase': phase,
            'viewport': position.viewportDimension,
            'first': anchor.messageKey,
            'offset': anchor.top,
            'pixels': position.pixels,
            'max': position.maxScrollExtent,
            'tailPainted': tail,
            'outlineOpen': outline.evaluate().isNotEmpty,
            if (outlineScroll.evaluate().isNotEmpty) ...{
              'outlinePixels': outlinePosition().pixels,
              'outlineMax': outlinePosition().maxScrollExtent,
              'parentRowVisible': parentRow.hitTestable().evaluate().isNotEmpty,
            },
          });
          return (
            first: anchor.messageKey,
            top: anchor.top,
            pixels: position.pixels,
            end: position.maxScrollExtent,
            tail: tail,
          );
        }

        Future<void> open() async {
          final options = find.byKey(const Key('thread-options')).hitTestable();
          expect(options, findsOneWidget);
          await tester.tap(options);
          await tester.pumpAndSettle();
          final item = find
              .byKey(const Key('thread-timeline-menu-item'))
              .hitTestable();
          expect(item, findsOneWidget);
          await tester.tap(item);
          await tester.pumpAndSettle();
          expect(outline.hitTestable(), findsOneWidget);
          if (phone) {
            expect(
              outlinePosition().extentBefore,
              closeTo(0, 0.01),
              reason: 'Every new Timeline drawer starts at the top',
            );
            expect(parentRow.hitTestable(), findsOneWidget);
          }
        }

        Future<void> close() async {
          if (phone) {
            final close = find
                .descendant(of: outline, matching: find.byType(RaftSheetClose))
                .hitTestable();
            expect(close, findsOneWidget);
            await tester.tap(close);
          } else {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          }
          await tester.pumpAndSettle();
          expect(outline, findsNothing);
        }

        try {
          final latest = receipt('latest');
          expect(latest.tail, isTrue);
          expect(latest.end - latest.pixels, closeTo(0, 1));
          await open();
          expect(receipt('open-latest'), latest);
          final currentTick = find.descendant(
            of: outline,
            matching: find.byWidgetPredicate(
              (w) => w is ThreadOutlineTick && w.current,
            ),
          );
          final currentRow = find.ancestor(
            of: currentTick,
            matching: find.byType(RaftInteractive),
          );
          expect(currentTick, findsOneWidget);
          expect(tester.widget<RaftInteractive>(currentRow).selected, isTrue);
          final openingHeight = tester.getSize(outline).height;
          if (phone) {
            expect(currentRow.hitTestable(), findsNothing);
            await tester.drag(outlineScroll, const Offset(0, -360));
            await tester.pumpAndSettle();
            expect(tester.getSize(outline).height, greaterThan(openingHeight));
            expect(outlinePosition().extentBefore, closeTo(0, 0.01));
            expect(receipt('drawer-expanded'), latest);

            await tester.drag(outlineScroll, const Offset(0, -360));
            await tester.pumpAndSettle();
            expect(outlinePosition().extentBefore, greaterThan(100));
            expect(parentRow.hitTestable(), findsNothing);
            expect(tester.widget<RaftInteractive>(currentRow).selected, isTrue);
            expect(receipt('drawer-scrolled'), latest);
            await tester.binding.handlePopRoute();
          } else {
            expect(outlinePosition().extentBefore, greaterThan(100));
            expect(currentRow.hitTestable(), findsOneWidget);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          }
          await tester.pumpAndSettle();
          expect(outline, findsNothing);
          expect(receipt(phone ? 'back' : 'escape'), latest);
          await open();
          expect(receipt('reopen-latest'), latest);
          expect(tester.getSize(outline).height, closeTo(openingHeight, 0.01));

          tester.view.physicalSize = Size(size.width, size.height - 60);
          await tester.pumpAndSettle();
          final resized = receipt('resize-open');
          expect(resized.tail, isTrue);
          expect(resized.end - resized.pixels, closeTo(0, 1));
          if (phone) {
            expect(outline.hitTestable(), findsOneWidget);
            await close();
          } else {
            // The desktop anchor dismisses its popover on window resize.
            // Reopen to check that the mounted reader remains in place.
            expect(outline, findsNothing);
            await open();
            expect(receipt('reopen-resized'), resized);
            await close();
          }
          expect(receipt('close-resized'), resized);

          if (phone) {
            await tester.drag(timeline, const Offset(0, 360));
          } else {
            await tester.sendEventToBinding(
              PointerScrollEvent(
                position: tester.getCenter(timeline),
                scrollDelta: const Offset(0, -360),
                kind: PointerDeviceKind.mouse,
              ),
            );
          }
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 250));
          final older = receipt('scrolled-older');
          expect(older.pixels, lessThan(resized.pixels - 100));
          await open();
          expect(receipt('open-older'), older);
          await close();
          expect(receipt('close-older'), older);
          await open();
          expect(receipt('reopen-older'), older);

          await tester.scrollUntilVisible(
            parentRow,
            -320,
            scrollable: outlineScroll,
            maxScrolls: 24,
          );
          expect(receipt('outline-scrolled-to-parent'), older);
          expect(parentRow.hitTestable(), findsOneWidget);
          await tester.tap(parentRow);
          await tester.pumpAndSettle();
          expect(outline, findsNothing);
          expect(receipt('explicit-parent-selection').first, 'parent');
          expect(paintedMessage(tester, 'parent'), isNotNull);

          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('message-timeline-reply-60')),
            360,
            scrollable: find
                .descendant(of: timeline, matching: find.byType(Scrollable))
                .first,
            maxScrolls: 24,
          );
          await tester.pumpAndSettle();
          expect(receipt('before-fixture-title').tail, isTrue);
          final title = find
              .descendant(
                of: find.byType(RaftThreadHeader),
                matching: find.text('Thread'),
              )
              .hitTestable();
          expect(title, findsOneWidget);
          await tester.tap(title);
          await tester.pumpAndSettle();
          final titleJump = receipt('after-fixture-title');
          expect(titleJump.first, 'parent');
          await open();
          expect(receipt('after-legacy-open'), titleJump);
          const replyId = 'timeline-reply-3';
          final reply = find.byKey(
            const ValueKey('thread-outline-row-$replyId'),
          );
          expect(reply.hitTestable(), findsOneWidget);
          await tester.tap(reply);
          await tester.pumpAndSettle();
          expect(outline, findsNothing);
          expect(paintedMessage(tester, replyId), isNotNull);
          receipt('explicit-reply-selection');

          await open();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          expect(outline, findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          debugPrint(
            'TIMELINE_RECEIPT ${jsonEncode(receipts)}',
            wrapWidth: 10000,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 300));
        }
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.linux,
      }),
    );
  }
}
