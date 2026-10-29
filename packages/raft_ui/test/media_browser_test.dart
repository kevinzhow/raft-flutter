// The media browser components: strip (video badges, lazy, centring), phone
// immersive shell (chrome, landscape, caption, targets), drag-to-dismiss,
// the Hero route and the platform key helper.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

List<RaftMediaStripItem> _items(int count, {Set<int> videos = const {}}) => [
  for (var i = 0; i < count; i++)
    RaftMediaStripItem(
      label: 'Item ${i + 1}',
      video: videos.contains(i),
      duration: videos.contains(i) ? Duration(seconds: 19 + i) : null,
    ),
];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Material(color: Colors.black, child: child),
    ),
  );
}

Widget _shell({
  ValueNotifier<bool>? chrome,
  VoidCallback? onClose,
  String? caption,
  int stripItems = 3,
  List<RaftMediaAction> actions = const [],
  bool dismissEnabled = true,
}) {
  final shown = chrome ?? ValueNotifier(true);
  addTearDown(shown.dispose);
  return RaftMediaImmersiveShell(
    title: 'IMG_2041.jpg',
    subtitle: 'Alice Chen · Oct 13, 2:02 PM',
    chrome: shown,
    onClose: onClose ?? () {},
    counter: const RaftLightboxCounter(index: 0, count: 3),
    actions: actions,
    caption: caption,
    dismissEnabled: dismissEnabled,
    strip: stripItems == 0
        ? null
        : RaftMediaStrip(
            compact: true,
            items: _items(stripItems),
            index: 0,
            onSelect: (_) {},
          ),
    child: const ColoredBox(
      key: ValueKey('stage'),
      color: Colors.blue,
      child: SizedBox.expand(),
    ),
  );
}

void main() {
  group('RaftMediaStrip', () {
    testWidgets('video thumbnails carry a play badge with the duration', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          height: 80,
          child: RaftMediaStrip(
            items: _items(3, videos: {1}),
            index: 0,
            onSelect: (_) {},
          ),
        ),
      );
      expect(find.text('0:20'), findsOneWidget);
      expect(find.text('0:19'), findsNothing, reason: 'image 0 has no badge');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('lightbox-thumbnail-1')),
          matching: find.byType(RaftIcon),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('lightbox-thumbnail-0')),
          matching: find.byType(RaftIcon),
        ),
        findsNothing,
      );
    });

    testWidgets('thumbnails are built lazily and the active one is ringed', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        SizedBox(
          height: 80,
          child: RaftMediaStrip(
            items: _items(200),
            index: 100,
            onSelect: (_) {},
          ),
        ),
      );
      await tester.pump();
      final built = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key as ValueKey).value}'.startsWith('lightbox-thumbnail-') &&
            '${(w.key as ValueKey).value}' != 'lightbox-thumbnail-scroll',
      );
      expect(built.evaluate().length, lessThan(20));
      // Centred on the active one, which semantics report as selected.
      final active = tester.getCenter(
        find.byKey(const ValueKey('lightbox-thumbnail-100')),
      );
      expect(active.dx, closeTo(195, 1));
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey('lightbox-thumbnail-100')),
        ),
        matchesSemantics(
          label: 'Item 101',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('compact thumbnails are 44 dp in a 56 dp band', (tester) async {
      await _pump(
        tester,
        SizedBox(
          height: raftMediaStripBand,
          child: RaftMediaStrip(
            compact: true,
            items: _items(3),
            index: 0,
            onSelect: (_) {},
          ),
        ),
      );
      final thumb = tester.getSize(
        find.byKey(const ValueKey('lightbox-thumbnail-0')),
      );
      expect(thumb, const Size(44, 44));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('lightbox-thumbnails')))
            .height,
        raftMediaStripBand,
      );
    });

    testWidgets('index changes glide the strip (jump with reduced motion)', (
      tester,
    ) async {
      Future<void> mount(int index, bool reduce) => _pump(
        tester,
        SizedBox(
          height: 80,
          child: RaftMediaStrip(
            items: _items(40),
            index: index,
            onSelect: (_) {},
          ),
        ),
        reduceMotion: reduce,
      );
      double offset() => tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      await mount(0, false);
      await mount(30, false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(offset(), inExclusiveRange(0, 30 * 54));
      await tester.pump(const Duration(milliseconds: 200));
      expect(offset(), greaterThan(1000));
      await mount(0, true);
      await tester.pump();
      await tester.pump();
      expect(offset(), 0, reason: 'reduced motion jumps');
    });
  });

  group('RaftMediaImmersiveShell', () {
    testWidgets('top bar: 44 dp targets, title, sub-line, counter, actions', (
      tester,
    ) async {
      final pressed = <String>[];
      await _pump(
        tester,
        _shell(
          actions: [
            RaftMediaAction(
              glyph: RaftGlyph.share2,
              label: 'Share',
              onPressed: (_) => pressed.add('share'),
            ),
            RaftMediaAction(
              glyph: RaftGlyph.ellipsis,
              label: 'More',
              onPressed: (rect) => pressed.add('more ${rect.size}'),
            ),
          ],
        ),
      );
      expect(find.text('IMG_2041.jpg'), findsOneWidget);
      expect(find.text('Alice Chen · Oct 13, 2:02 PM'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      for (final label in ['Back', 'Share', 'More']) {
        final box = tester.getSize(find.bySemanticsLabel(label).first);
        expect(box.shortestSide, greaterThanOrEqualTo(44), reason: label);
      }
      await tester.tap(find.bySemanticsLabel('Share'));
      await tester.tap(find.bySemanticsLabel('More'));
      expect(pressed, ['share', 'more Size(44.0, 44.0)']);
    });

    testWidgets('safe areas: bars sit below the status bar and above the '
        'gesture bar', (tester) async {
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.resetPadding);
      await _pump(tester, _shell());
      expect(
        tester.getTopLeft(find.text('IMG_2041.jpg')).dy,
        greaterThanOrEqualTo(47),
      );
      expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('lightbox-thumbnails')))
            .dy,
        lessThanOrEqualTo(844 - 34),
      );
      // The stage itself runs edge to edge under both bars.
      final stage = tester.getRect(find.byKey(const ValueKey('stage')));
      expect(stage, const Rect.fromLTWH(0, 0, 390, 844));
    });

    testWidgets('light status bar icons over the black stage', (tester) async {
      await _pump(tester, _shell());
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.statusBarColor, Colors.transparent);
      expect(region.value.systemNavigationBarColor, Colors.transparent);
    });

    testWidgets('the chrome fades together and ignores touches while hidden', (
      tester,
    ) async {
      final chrome = ValueNotifier(true);
      var closed = 0;
      await _pump(tester, _shell(chrome: chrome, onClose: () => closed++));
      double opacity() => tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((o) => o.opacity)
          .reduce((a, b) => a + b);
      expect(opacity(), 2);
      chrome.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacity(), 0);
      await tester.tapAt(const Offset(30, 30));
      expect(closed, 0, reason: 'the hidden Back button is not tappable');
      chrome.value = true;
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(closed, 1);
    });

    testWidgets('a screen reader keeps the chrome visible', (tester) async {
      final chrome = ValueNotifier(false);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pump(tester, _shell(chrome: chrome));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .map((o) => o.opacity),
        everyElement(1.0),
      );
    });

    testWidgets('reduced motion: the chrome toggles without a fade', (
      tester,
    ) async {
      await _pump(tester, _shell(), reduceMotion: true);
      expect(
        tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .map((o) => o.duration),
        everyElement(Duration.zero),
      );
    });

    testWidgets(
      'landscape drops the strip and the caption, keeps the top bar',
      (tester) async {
        await _pump(
          tester,
          _shell(caption: 'A long story'),
          size: const Size(844, 390),
        );
        expect(find.byKey(const ValueKey('lightbox-thumbnails')), findsNothing);
        expect(find.byKey(const ValueKey('media-caption')), findsNothing);
        expect(find.text('IMG_2041.jpg'), findsOneWidget);
        await _pump(tester, _shell(caption: 'A long story'));
        expect(
          find.byKey(const ValueKey('lightbox-thumbnails')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('media-caption')), findsOneWidget);
      },
    );

    testWidgets('caption: two lines, tap expands, none without text', (
      tester,
    ) async {
      final text = List.filled(30, 'caption words').join(' ');
      await _pump(tester, _shell(caption: text));
      Text caption() => tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('media-caption')),
          matching: find.byType(Text),
        ),
      );
      expect(caption().maxLines, 2);
      expect(
        tester.getSize(find.byKey(const ValueKey('media-caption'))).height,
        lessThanOrEqualTo(raftMediaCaptionHeight),
      );
      await tester.tap(find.byKey(const ValueKey('media-caption')));
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const ValueKey('media-caption'))).height,
        greaterThan(raftMediaCaptionHeight),
        reason: 'expanded: all the lines show (an ellipsis would cut it to one)',
      );
      expect(caption().maxLines, isNull);
      await _pump(tester, _shell());
      expect(find.byKey(const ValueKey('media-caption')), findsNothing);
    });

    testWidgets('draws its own chrome (scrims, no solid bars)', (tester) async {
      await _pump(tester, _shell());
      final solid = find.byWidgetPredicate(
        (w) =>
            (w is Container || w is DecoratedBox) &&
            _decorationOf(w) is BoxDecoration &&
            (_decorationOf(w)! as BoxDecoration).color == Colors.black,
      );
      expect(solid.evaluate().isNotEmpty, isFalse);
      final gradient = find.byWidgetPredicate(
        (w) =>
            (w is Container || w is DecoratedBox) &&
            _decorationOf(w) is BoxDecoration &&
            (_decorationOf(w)! as BoxDecoration).gradient != null,
      );
      expect(gradient.evaluate().isNotEmpty, isTrue);
    });
  });

  group('RaftMediaDismissible', () {
    Future<(ValueNotifier<double>, List<int>)> mount(
      WidgetTester tester, {
      bool enabled = true,
      bool reduce = false,
    }) async {
      final progress = ValueNotifier<double>(0);
      addTearDown(progress.dispose);
      final dismissed = <int>[];
      await _pump(
        tester,
        RaftMediaDismissible(
          enabled: enabled,
          progress: progress,
          onDismiss: () => dismissed.add(1),
          // A competitor in the arena, as the page and the zoom surface are.
          child: GestureDetector(
            onTap: () {},
            child: const SizedBox.expand(key: ValueKey('page')),
          ),
        ),
        reduceMotion: reduce,
      );
      return (progress, dismissed);
    }

    testWidgets('follows the finger, scales to 0.82 at 260 dp', (tester) async {
      final (progress, _) = await mount(tester);
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 130));
      await tester.pump();
      expect(progress.value, closeTo((130 + 22) / 260, .1));
      final rect = tester.getRect(find.byKey(const ValueKey('page')));
      expect(rect.top, greaterThan(100));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      expect(progress.value, 1);
      final scaled = tester.getRect(find.byKey(const ValueKey('page')));
      expect(scaled.width, closeTo(390 * raftMediaDismissScale, .5));
      await gesture.up();
    });

    testWidgets('released short it springs back in 200 ms and does not close', (
      tester,
    ) async {
      final (progress, dismissed) = await mount(tester);
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 60));
      await gesture.up(timeStamp: const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(progress.value, inExclusiveRange(0, .3));
      await tester.pump(const Duration(milliseconds: 150));
      expect(progress.value, 0);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('page'))),
        Offset.zero,
      );
      expect(dismissed, isEmpty);
    });

    testWidgets('released past 120 dp closes', (tester) async {
      final (_, dismissed) = await mount(tester);
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 130));
      await gesture.up(timeStamp: const Duration(seconds: 2));
      await tester.pump();
      expect(dismissed, [1]);
    });

    testWidgets('a short fast fling closes (> 700 dp/s)', (tester) async {
      final (_, dismissed) = await mount(tester);
      await tester.flingFrom(const Offset(200, 300), const Offset(0, 70), 1500);
      await tester.pump();
      expect(dismissed, [1]);
    });

    testWidgets('a slow short drag past the slop does not close', (
      tester,
    ) async {
      final (_, dismissed) = await mount(tester);
      await tester.flingFrom(const Offset(200, 300), const Offset(0, 70), 200);
      await tester.pumpAndSettle();
      expect(dismissed, isEmpty);
    });

    testWidgets('disabled (zoomed, video seek rail, desktop): nothing moves', (
      tester,
    ) async {
      final (progress, dismissed) = await mount(tester, enabled: false);
      await tester.flingFrom(
        const Offset(200, 300),
        const Offset(0, 300),
        3000,
      );
      await tester.pump();
      expect(progress.value, 0);
      expect(dismissed, isEmpty);
    });

    testWidgets('touch only: a mouse drag does not dismiss', (tester) async {
      final (progress, dismissed) = await mount(tester);
      final mouse = await tester.startGesture(
        const Offset(200, 300),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await mouse.moveBy(const Offset(0, 40));
      await mouse.moveBy(const Offset(0, 200));
      await mouse.up();
      await tester.pump();
      expect(progress.value, 0);
      expect(dismissed, isEmpty);
    });

    testWidgets('a second finger (pinch) cancels the dismiss', (tester) async {
      final (progress, dismissed) = await mount(tester);
      final a = await tester.startGesture(const Offset(150, 300), pointer: 1);
      final b = await tester.startGesture(const Offset(250, 300), pointer: 2);
      await a.moveBy(const Offset(0, 80));
      await b.moveBy(const Offset(0, 80));
      await a.up();
      await b.up();
      await tester.pump();
      expect(progress.value, 0);
      expect(dismissed, isEmpty);
    });

    testWidgets('reduced motion: follows the finger without scaling', (
      tester,
    ) async {
      final (_, _) = await mount(tester, reduce: true);
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();
      final rect = tester.getRect(find.byKey(const ValueKey('page')));
      expect(rect.width, 390);
      expect(rect.top, greaterThan(150));
      await gesture.up();
    });

    testWidgets('inside the shell the scrim and the chrome fade with the '
        'drag', (tester) async {
      await _pump(tester, _shell());
      double chromeOpacity() => tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((o) => o.opacity)
          .reduce((a, b) => a + b);
      expect(chromeOpacity(), 2);
      final gesture = await tester.startGesture(const Offset(200, 400));
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(chromeOpacity(), 0, reason: 'gone within the first 40 dp');
      final scrim = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((c) => c.color)
          .where((c) => c.a < 1 && c.a > 0);
      expect(scrim, isNotEmpty, reason: 'the black scrim fades with the drag');
      await gesture.up();
    });
  });

  group('RaftMediaBrowserRoute', () {
    Future<NavigatorState> mount(
      WidgetTester tester, {
      bool reduce = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: const Scaffold(body: Text('chat')),
        ),
      );
      return tester.state<NavigatorState>(find.byType(Navigator));
    }

    testWidgets('fades in over the page below, then lets it rest', (
      tester,
    ) async {
      final navigator = await mount(tester);
      unawaited(
        navigator.push(
          RaftMediaBrowserRoute<void>(
            builder: (_) =>
                const ColoredBox(color: Colors.black, child: Text('viewer')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('chat'), findsOneWidget, reason: 'still painted');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('viewer'), findsOneWidget);
      expect(
        find.text('chat'),
        findsNothing,
        reason: 'the page below stops painting once the route settles',
      );
    });

    testWidgets('a drag makes the page below visible again', (tester) async {
      final navigator = await mount(tester);
      unawaited(
        navigator.push(
          RaftMediaBrowserRoute<void>(
            builder: (_) => Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    RaftMediaBrowserRoute.maybeOf(context)!
                        .setTranslucent(true),
                child: const Text('viewer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('chat'), findsNothing);
      await tester.tap(find.text('viewer'));
      await tester.pump();
      expect(find.text('chat'), findsOneWidget);
    });

    testWidgets('reduced motion cross-fades in 80 ms', (tester) async {
      final navigator = await mount(tester);
      unawaited(
        navigator.push(
          RaftMediaBrowserRoute<void>(
            reducedMotion: true,
            builder: (_) => const Text('viewer'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(find.text('chat'), findsNothing, reason: 'settled after 80 ms');
    });
  });

  group('RaftMediaHero', () {
    testWidgets('the shuttle shows the bitmap and rounds off in flight', (
      tester,
    ) async {
      final provider = MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    RaftMediaBrowserRoute<void>(
                      builder: (_) => Align(
                        alignment: Alignment.bottomRight,
                        child: SizedBox(
                          width: 200,
                          height: 300,
                          child: RaftMediaHero(
                            tag: 't',
                            image: provider,
                            child: const ColoredBox(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: RaftMediaHero(
                      tag: 't',
                      image: provider,
                      radius: BorderRadius.circular(8),
                      child: const ColoredBox(color: Colors.green),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final shuttle = find.byKey(const ValueKey('media-hero-shuttle'));
      expect(shuttle, findsOneWidget);
      final radius = tester.widget<ClipRRect>(shuttle).borderRadius;
      expect(
        (radius as BorderRadius).topLeft.x,
        inExclusiveRange(0, 8),
        reason: 'rounder than the stage, squarer than the card',
      );
      await tester.pumpAndSettle();
      expect(shuttle, findsNothing);
      await tester.pumpWidget(const SizedBox());
      imageCache.clear();
      imageCache.clearLiveImages();
    });
  });

  group('RaftPlatformKeys', () {
    for (final (platform, apple) in [
      (TargetPlatform.macOS, true),
      (TargetPlatform.iOS, true),
      (TargetPlatform.linux, false),
      (TargetPlatform.windows, false),
      (TargetPlatform.android, false),
    ]) {
      test('$platform commands use ${apple ? 'Cmd' : 'Ctrl'}', () {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final key = RaftPlatformKeys.command(LogicalKeyboardKey.digit0);
        expect(key.meta, apple);
        expect(key.control, !apple);
      });
    }
  });
}

Decoration? _decorationOf(Widget w) => w is Container
    ? w.decoration
    : w is DecoratedBox
    ? w.decoration
    : null;
