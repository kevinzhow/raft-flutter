import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const mib = 1024 * 1024;

Widget host(bool dark, Widget child, {Locale? locale}) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Builder(
    builder: (context) {
      final body = Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      );
      return locale == null
          ? body
          : Localizations.override(
              context: context,
              locale: locale,
              child: body,
            );
    },
  ),
);

void main() {
  group('RaftTransferProgress', () {
    test('formats sizes in the unit of the total', () {
      expect(
        formatTransferSizes((1.2 * mib).round(), (3.4 * mib).round()),
        '1.2 / 3.4 MB',
      );
      expect(formatTransferSizes(512 * 1024, 900 * 1024), '512 / 900 KB');
      expect(formatTransferSizes(300, 900), '300 / 900 B');
      expect(formatTransferSizes(mib, null), '1.0 MB');
      // Never reports more than the total.
      expect(formatTransferSizes(5 * mib, 4 * mib), '4.0 / 4.0 MB');
    });
    test('fraction: unknown total and waiting are indeterminate', () {
      expect(
        const RaftTransferProgress(received: 50, total: 200).fraction,
        .25,
      );
      expect(const RaftTransferProgress(received: 50).fraction, isNull);
      expect(
        const RaftTransferProgress(received: 50, total: -1).fraction,
        isNull,
      );
      expect(
        const RaftTransferProgress(received: 0, total: 200).fraction,
        isNull,
      );
      expect(const RaftTransferProgress(received: 300, total: 200).fraction, 1);
      expect(RaftTransferProgress.connecting.waiting, isTrue);
    });
    test('percent-only progress: label, fraction and waiting', () {
      expect(const RaftTransferProgress.percent(40).sizeLabel, '40%');
      expect(const RaftTransferProgress.percent(40).fraction, .4);
      expect(const RaftTransferProgress.percent(0).waiting, isTrue);
      expect(const RaftTransferProgress.percent(0).fraction, isNull);
      expect(const RaftTransferProgress.percent(250).fraction, 1);
      expect(const RaftTransferProgress.percent(-3).received, 0);
      expect(
        const RaftTransferProgress.percent(40).withFallbackTotal(900).total,
        100,
      );
      expect(
        const RaftTransferProgress.percent(40) ==
            const RaftTransferProgress(received: 40, total: 100),
        isFalse,
      );
    });
    test('a fallback total only fills an unknown total', () {
      const unknown = RaftTransferProgress(received: 50, total: -1);
      expect(unknown.withFallbackTotal(200).fraction, .25);
      const known = RaftTransferProgress(received: 50, total: 100);
      expect(known.withFallbackTotal(200).fraction, .5);
      expect(unknown.withFallbackTotal(null).fraction, isNull);
      expect(unknown.withFallbackTotal(0).fraction, isNull);
    });
  });

  for (final dark in raftThemeMatrix([false, true])) {
    group('${dark ? 'dark' : 'light'}', () {
      testWidgets('bar paints edge strip at the recipe height', (tester) async {
        await tester.pumpWidget(
          host(
            dark,
            const SizedBox(width: 200, child: RaftTransferBar(value: .4)),
          ),
        );
        final recipe = RaftTransferRecipe(
          RaftTokens.of(tester.element(find.byType(RaftTransferBar))),
        );
        expect(
          tester.getSize(find.byType(RaftTransferBar)),
          Size(200, recipe.edgeHeight),
        );
        expect(recipe.edgeHeight, 4);
      });

      testWidgets('indeterminate bar animates; reduced motion freezes it', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(dark, const SizedBox(width: 200, child: RaftTransferBar())),
        );
        expect(tester.hasRunningAnimations, isTrue);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: host(
              dark,
              const SizedBox(width: 200, child: RaftTransferBar()),
            ),
          ),
        );
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('a determinate or failed bar schedules no frames', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            dark,
            const Column(
              children: [
                SizedBox(width: 200, child: RaftTransferBar(value: .5)),
                SizedBox(width: 200, child: RaftTransferBar(failed: true)),
              ],
            ),
          ),
        );
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets(
        'overlay: chip text follows the notifier and takes no pointer events',
        (tester) async {
          final progress = ValueNotifier<RaftTransferProgress?>(null);
          var taps = 0;
          await tester.pumpWidget(
            host(
              dark,
              SizedBox(
                width: 300,
                height: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () => taps++,
                      child: const ColoredBox(color: Colors.grey),
                    ),
                    RaftImageTransferOverlay(
                      progress: progress,
                      fallbackTotal: 4 * mib,
                    ),
                  ],
                ),
              ),
            ),
          );
          // Null: not on the network (queued / cache), nothing drawn.
          expect(find.byType(RaftTransferBar), findsNothing);
          expect(find.byType(RaftTransferChip), findsNothing);
          progress.value = RaftTransferProgress.connecting;
          await tester.pump();
          expect(find.text('Connecting…'), findsOneWidget);
          progress.value = const RaftTransferProgress(received: mib, total: -1);
          await tester.pump();
          // sizeBytes stands in for the missing Content-Length.
          expect(find.text('1.0 / 4.0 MB'), findsOneWidget);
          expect(
            tester.widget<RaftTransferBar>(find.byType(RaftTransferBar)).value,
            .25,
          );
          await tester.tapAt(const Offset(20, 20));
          await tester.tapAt(tester.getCenter(find.byType(RaftTransferChip)));
          expect(taps, 2, reason: 'the overlay never swallows the tile tap');
          progress.dispose();
        },
      );

      testWidgets('chip sits above the bar; labels localize', (tester) async {
        await tester.pumpWidget(
          host(
            dark,
            const SizedBox(
              width: 300,
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [RaftImageTransferOverlay.failed()],
              ),
            ),
            locale: const Locale('zh'),
          ),
        );
        expect(find.text('下载失败 · 点按重试'), findsOneWidget);
        final bar = tester.getRect(find.byType(RaftTransferBar));
        final chip = tester.getRect(find.byType(RaftTransferChip));
        expect(chip.bottom, lessThanOrEqualTo(bar.top));
        expect(bar.bottom, tester.getRect(find.byType(Stack).first).bottom);
      });

      testWidgets(
        'card: a pending image shows only the placeholder; a failed one a retry band',
        (tester) async {
          var retries = 0, opens = 0;
          await tester.pumpWidget(
            host(
              dark,
              Column(
                children: [
                  RaftAttachmentCard(
                    filename: 'a.jpg',
                    mimeType: 'image/jpeg',
                    imageExtent: const Size(300, 200),
                    previewPending: true,
                    onOpen: () => opens++,
                  ),
                  RaftAttachmentCard(
                    filename: 'b.jpg',
                    mimeType: 'image/jpeg',
                    imageExtent: const Size(300, 200),
                    error: 'x',
                    onRetry: () => retries++,
                    onOpen: () => opens++,
                  ),
                ],
              ),
            ),
          );
          // List tiles never show transfer text or a bar while loading: the
          // neutral placeholder only (Web's tinted image box).
          expect(find.byType(RaftTransferPlaceholder), findsNWidgets(2));
          expect(find.text('Connecting…'), findsNothing);
          expect(
            find.byType(RaftTransferBar),
            findsOneWidget,
            reason: 'failed tile only',
          );
          expect(find.byType(RaftTransferChip), findsOneWidget);
          expect(find.text('Download failed · tap to retry'), findsOneWidget);
          // The chip band retries; the rest of the failed tile still opens.
          await tester.tap(find.byKey(const ValueKey('attachment-retry')));
          expect(retries, 1);
          expect(opens, 0);
          final failed = find.byType(RaftAttachmentCard).last;
          await tester.tapAt(tester.getTopLeft(failed) + const Offset(150, 40));
          expect(opens, 1);
          expect(retries, 1);
        },
      );

      testWidgets('card: the failed retry is reachable by keyboard', (
        tester,
      ) async {
        var retries = 0;
        await tester.pumpWidget(
          host(
            dark,
            RaftAttachmentCard(
              filename: 'b.jpg',
              mimeType: 'image/jpeg',
              imageExtent: const Size(300, 200),
              error: 'x',
              onRetry: () => retries++,
              onOpen: () {},
            ),
          ),
        );
        // Tab order: the tile, then the retry band.
        bool onRetry() {
          var inside = false;
          FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
            element,
          ) {
            inside = element.widget.key == const ValueKey('attachment-retry');
            return !inside;
          });
          return inside;
        }

        for (var i = 0; i < 6 && !onRetry(); i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(onRetry(), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(retries, 1);
        expect(
          tester.getSemantics(find.byKey(const ValueKey('attachment-retry'))),
          matchesSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
            isFocused: true,
            label: 'Download failed · tap to retry',
          ),
        );
      });

      testWidgets('file panel: progress text, cancel, retry', (tester) async {
        final progress = ValueNotifier<RaftTransferProgress?>(
          RaftTransferProgress(
            received: (1.7 * mib).round(),
            total: (2.8 * mib).round(),
          ),
        );
        var cancels = 0, retries = 0;
        Widget panel({bool failed = false}) => host(
          dark,
          RaftFileTransferPanel(
            filename: '2026Q3-report.pdf',
            meta: 'PDF · 2.8 MB',
            progress: progress,
            failed: failed,
            onCancel: () => cancels++,
            onRetry: () => retries++,
          ),
        );
        await tester.pumpWidget(panel());
        expect(find.text('1.7 / 2.8 MB · 60%'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        expect(cancels, 1);
        await tester.pumpWidget(panel(failed: true));
        expect(find.text('PDF · 2.8 MB · Download failed'), findsOneWidget);
        await tester.tap(find.text('Retry'));
        expect(retries, 1);
        progress.dispose();
      });
    });
  }
}
