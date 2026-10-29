import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  test(
    'mounted history precedence keeps sentinel as sole pagination owner',
    () {
      expect(
        raftThreadHistoryState(hasMore: true, historyLimited: true),
        RaftThreadHistoryState.older,
      );
      expect(
        raftThreadHistoryState(hasMore: false, historyLimited: true),
        RaftThreadHistoryState.limited,
      );
      expect(
        raftThreadHistoryState(hasMore: false, historyLimited: false),
        RaftThreadHistoryState.beginning,
      );
    },
  );

  for (final dark in raftThemeMatrix([false, true])) {
    Future<void> mount(
      WidgetTester tester,
      Widget child, {
      RaftDensity density = RaftDensity.desktop,
      double width = 390,
      double height = 600,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, height);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: RaftDensityScope(density: density, child: child),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
    }

    test(
      '${dark ? 'dark' : 'light'} side/modal/mobile-modal exact width predicates',
      () {
        final t = raftTheme(dark: dark).extension<RaftTokens>()!;
        for (final presentation in RaftThreadPresentation.values) {
          for (final width in [767.0, 768.0, 1023.0, 1024.0]) {
            final r = RaftThreadCompositionRecipe(
              t,
              viewportWidth: width,
              viewportHeight: 800,
              presentation: presentation,
            );
            expect(
              r.showBack,
              width <
                  (presentation == RaftThreadPresentation.side ? 1024 : 768),
            );
            expect(
              r.showClose,
              presentation == RaftThreadPresentation.modal ||
                  presentation == RaftThreadPresentation.side && width >= 1024,
            );
            expect(r.headerHeight, 56);
            expect(r.parentInset, const EdgeInsets.all(12));
            expect(r.parentBorder.width, 1);
            expect(r.headerBorder.width, 1);
            expect(r.headerBorder.style, BorderStyle.solid);
            expect(r.headerBorder.color, t.colors['line-muted']);
          }
        }
        final compact = RaftThreadCompositionRecipe(
          t,
          viewportWidth: 390,
          viewportHeight: 600,
          presentation: RaftThreadPresentation.side,
        );
        expect(compact.headerHeight, 48);
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} folded header title/back/menu callbacks independent',
      (tester) async {
        var back = 0, close = 0, jump = 0, overflow = 0;
        Widget header(RaftThreadPresentation presentation, double width) =>
            Align(
              alignment: Alignment.topLeft,
              child: RaftThreadHeader(
                presentation: presentation,
                viewportWidth: width,
                viewportHeight: 800,
                threadLabel: 'Thread',
                parentLabel: '#公开中文 日本語',
                jumpLabel: 'Scroll Thread to First Message',
                backLabel: 'Back',
                closeLabel: 'Close Thread',
                onBack: () => back++,
                onClose: () => close++,
                onJumpToStart: () => jump++,
                backKey: const ValueKey('thread-back'),
                closeKey: const ValueKey('thread-close'),
                jumpKey: const ValueKey('thread-start'),
                actions: [
                  RaftThreadOverflowAction(
                    key: const ValueKey('thread-menu'),
                    label: 'Thread Actions',
                    onPressed: () => overflow++,
                  ),
                ],
              ),
            );
        await mount(
          tester,
          header(RaftThreadPresentation.side, 957),
          width: 957,
        );
        expect(find.byKey(const ValueKey('thread-back')), findsOneWidget);
        expect(find.byKey(const ValueKey('thread-close')), findsNothing);
        expect(
          find.text('Thread\uFFFC— #公开中文 日本語', findRichText: true),
          findsOneWidget,
        );
        final semantics = tester.ensureSemantics();
        try {
          final node = tester.getSemantics(
            find.bySemanticsLabel('Scroll Thread to First Message'),
          );
          expect(node.label, 'Scroll Thread to First Message');
          expect(node.flagsCollection.isButton, true);
        } finally {
          semantics.dispose();
        }
        await tester.tap(find.byKey(const ValueKey('thread-start')));
        await tester.tap(find.byKey(const ValueKey('thread-menu')));
        await tester.tap(find.byKey(const ValueKey('thread-back')));
        expect([jump, overflow, back, close], [1, 1, 1, 0]);
        await mount(
          tester,
          header(RaftThreadPresentation.side, 1280),
          width: 1280,
        );
        expect(find.byKey(const ValueKey('thread-back')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('thread-close')));
        expect(close, 1);
        await mount(tester, header(RaftThreadPresentation.modal, 390));
        // ThreadPanel below md: a `modal` presentation keeps both the boxed
        // PanelAction Back (`md:hidden`) and the X close; `mobile-modal`
        // (the full-screen phone overlay) draws no X.
        expect(find.byKey(const ValueKey('thread-back')), findsOneWidget);
        expect(find.byKey(const ValueKey('thread-close')), findsOneWidget);
        await mount(tester, header(RaftThreadPresentation.mobileModal, 390));
        expect(find.byKey(const ValueKey('thread-back')), findsOneWidget);
        expect(find.byKey(const ValueKey('thread-close')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} single parent sliver retains natural height and scrolls with replies',
      (tester) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await mount(
          tester,
          CustomScrollView(
            controller: scroll,
            slivers: [
              const RaftThreadTimelineTopSliver(
                parentKey: ValueKey('source-parent-region'),
                parentSlot: Text('permitted parent task slot'),
                parent: SizedBox(
                  height: 600,
                  child: Text('long real parent body'),
                ),
                hasMore: true,
                historyLimited: true,
                loadingOlder: false,
                loadingOlderLabel: 'Loading older replies...',
                historyLimitedLabel:
                    'Older replies are limited by the current plan',
                beginningLabel: 'Beginning of replies',
                replyCountLabel: '12 replies',
              ),
              SliverList.builder(
                itemCount: 12,
                itemBuilder: (_, i) =>
                    SizedBox(height: 60, child: Text('reply-$i')),
              ),
            ],
          ),
          height: 400,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('source-parent-region')))
              .height,
          624 + (1),
        );
        expect(find.byType(Scrollable), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.text('Loading older replies...'), findsNothing);
        expect(
          find.text('Older replies are limited by the current plan'),
          findsNothing,
        );
        expect(find.text('12 replies'), findsOneWidget);
        final start = tester
            .getTopLeft(find.byKey(const ValueKey('source-parent-region')))
            .dy;
        scroll.jumpTo(640);
        await tester.pump();
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('source-parent-region')))
              .dy,
          start - 640,
        );
        expect(find.text('reply-1').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} full localized history transitions without extra fetch control',
      (tester) async {
        Widget history(bool hasMore, bool limited, bool busy) =>
            RaftThreadHistoryTopState(
              hasMore: hasMore,
              historyLimited: limited,
              loadingOlder: busy,
              loadingOlderLabel: '正在载入更早的回复…',
              historyLimitedLabel: '较早的回复受当前方案限制',
              beginningLabel: '回复的开始',
            );
        await mount(tester, history(true, true, false));
        expect(find.byType(Text), findsNothing);
        await mount(tester, history(true, true, true));
        expect(find.text('正在载入更早的回复…'), findsOneWidget);
        await mount(tester, history(false, true, false));
        expect(find.text('较早的回复受当前方案限制'), findsOneWidget);
        expect(find.byType(RaftIcon), findsOneWidget);
        expect(
          tester.widget<RaftIcon>(find.byType(RaftIcon)).glyph,
          RaftGlyph.lock,
        );
        await mount(tester, history(false, false, false));
        expect(find.text('回复的开始'), findsOneWidget);
        expect(find.byType(RaftControl), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} native touch slots remain separate and keyboard title activates',
      (tester) async {
        var jumps = 0;
        await mount(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: RaftThreadHeader(
              presentation: RaftThreadPresentation.mobileModal,
              threadLabel: 'Thread',
              parentLabel: '@公开用户',
              jumpLabel: 'Scroll Thread to First Message',
              backLabel: 'Back',
              closeLabel: 'Close Thread',
              onBack: () {},
              onClose: () {},
              onJumpToStart: () => jumps++,
              backKey: const ValueKey('back-target'),
              closeKey: const ValueKey('close-target'),
              jumpKey: const ValueKey('title-target'),
            ),
          ),
          density: RaftDensity.touch,
          width: 390,
          height: 800,
        );
        expect(find.byKey(const ValueKey('close-target')), findsNothing);
        final backRect = tester.getRect(
          find.byKey(const ValueKey('back-target')),
        );
        final titleRect = tester.getRect(
          find.byKey(const ValueKey('title-target')),
        );
        // Back is Web's boxed PanelAction (26x28 brutal / 32x32 elegant); its
        // touch target is extended to 48 without moving the title.
        expect(backRect.size, const Size(44, 44));
        expect(titleRect.height, greaterThanOrEqualTo(48));
        expect(backRect.overlaps(titleRect), false);
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        semantics.dispose();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(jumps, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
