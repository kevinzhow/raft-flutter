// The central text scaling policy and the Large Content Viewer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// A platform scaler that is not linear (Android 14+ style): small text grows
/// more than large text, with a different curve from Apple's.
class _NonlinearPlatform extends TextScaler {
  const _NonlinearPlatform();
  @override
  double scale(double fontSize) => fontSize + 8 * (fontSize / (fontSize + 20));
  @override
  double get textScaleFactor => scale(17) / 17;
  @override
  bool operator ==(Object other) => other is _NonlinearPlatform;
  @override
  int get hashCode => 1;
}

/// OS factor of an iOS category: its body size over 17.
double _ios(double bodyPt) => bodyPt / 17;

void main() {
  group('RaftTextScaler', () {
    test('is the identity at the default text size', () {
      final s = RaftTextScaler(TextScaler.noScaling);
      for (final size in [9.0, 11.0, 13.0, 17.0, 28.0, 34.0, 60.0]) {
        expect(s.scale(size), size);
      }
    });

    test('reproduces the Dynamic Type table at the largest iOS size', () {
      final s = RaftTextScaler(TextScaler.linear(_ios(53)));
      expect(s.scale(17), closeTo(53, 0.01), reason: 'body');
      expect(s.scale(13), closeTo(44, 0.01), reason: 'footnote');
      expect(s.scale(12), closeTo(40, 0.01), reason: 'caption');
      expect(s.scale(28), closeTo(58, 0.01), reason: 'title 1');
      expect(s.scale(34), closeTo(60, 0.01), reason: 'large title');
    });

    test('reproduces the table at intermediate iOS sizes', () {
      expect(
        RaftTextScaler(TextScaler.linear(_ios(23))).scale(13),
        closeTo(19, 0.01),
        reason: 'footnote at xxxLarge',
      );
      expect(
        RaftTextScaler(TextScaler.linear(_ios(33))).scale(34),
        closeTo(48, 0.01),
        reason: 'large title at accessibility 2',
      );
    });

    test('headline styles grow less than body, body less than captions', () {
      for (final f in [1.3, 1.65, 2.0, 2.76, 3.11]) {
        final s = RaftTextScaler(TextScaler.linear(f));
        double ratio(double size) => s.scale(size) / size;
        expect(ratio(34), lessThan(ratio(28)), reason: '$f');
        expect(ratio(28), lessThan(ratio(17)), reason: '$f');
        expect(ratio(17), lessThan(ratio(13)), reason: '$f');
      }
    });

    test('is monotonic in both the font size and the system factor', () {
      double? lastAtSize;
      for (final f in [1.0, 1.1, 1.3, 1.5, 2.0, 2.5, 3.0, 3.11, 4.0]) {
        final s = RaftTextScaler(TextScaler.linear(f));
        var last = 0.0;
        for (var size = 8.0; size <= 64; size += 0.5) {
          final v = s.scale(size);
          expect(v, greaterThanOrEqualTo(last), reason: '$f $size');
          last = v;
        }
        final body = s.scale(17);
        if (lastAtSize != null) expect(body, greaterThan(lastAtSize));
        lastAtSize = body;
      }
    });

    test('keeps growing beyond the largest iOS size', () {
      final s = RaftTextScaler(TextScaler.linear(4.0));
      expect(
        s.scale(17),
        greaterThan(RaftTextScaler(TextScaler.linear(_ios(53))).scale(17)),
      );
    });

    test('does not curve a reduction', () {
      expect(
        RaftTextScaler(TextScaler.linear(0.8)).scale(20),
        closeTo(16, 1e-9),
      );
    });

    test('passes a nonlinear platform scaler through', () {
      const platform = _NonlinearPlatform();
      final s = RaftTextScaler(platform);
      expect(s.appliesCurve, isFalse);
      for (final size in [11.0, 17.0, 34.0]) {
        expect(s.scale(size), platform.scale(size));
      }
    });

    test('compares equal for the same platform scaler', () {
      expect(
        RaftTextScaler(TextScaler.linear(2)),
        RaftTextScaler(TextScaler.linear(2)),
      );
      expect(
        RaftTextScaler(TextScaler.linear(2)),
        isNot(RaftTextScaler(TextScaler.linear(1.3))),
      );
    });
  });

  Future<void> pumpScaled(WidgetTester t, double factor, Widget child) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = factor;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: false),
        builder: (context, child) => RaftTextScaling(child: child!),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('RaftTextScaling and RaftChrome', () {
    testWidgets('content text uses the Apple curve, chrome is bounded', (
      t,
    ) async {
      late TextScaler content;
      late TextScaler chrome;
      late bool engaged;
      await pumpScaled(
        t,
        _ios(53),
        Builder(
          builder: (context) {
            content = MediaQuery.textScalerOf(context);
            return RaftChrome(
              child: Builder(
                builder: (context) {
                  chrome = MediaQuery.textScalerOf(context);
                  engaged = RaftChrome.engagedOf(context);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      );
      expect(content, isA<RaftTextScaler>());
      expect(content.scale(17), closeTo(53, 0.01));
      expect(
        chrome.scale(12),
        closeTo(12 * RaftTextScaling.chromeMaxScale, 1e-6),
      );
      expect(chrome.scale(100), closeTo(135, 1e-6));
      expect(engaged, isTrue);
    });

    testWidgets('chrome follows the text size below the bound', (t) async {
      late TextScaler chrome;
      late bool engaged;
      await pumpScaled(
        t,
        1.15,
        RaftChrome(
          child: Builder(
            builder: (context) {
              chrome = MediaQuery.textScalerOf(context);
              engaged = RaftChrome.engagedOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(engaged, isFalse);
      expect(
        chrome.scale(13),
        RaftTextScaler(TextScaler.linear(1.15)).scale(13),
      );
    });

    testWidgets('chrome is unscaled at the default text size', (t) async {
      late TextScaler chrome;
      await pumpScaled(
        t,
        1.0,
        RaftChrome(
          child: Builder(
            builder: (context) {
              chrome = MediaQuery.textScalerOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(chrome.scale(13), 13);
    });

    testWidgets('nested chrome keeps the outer content scaler', (t) async {
      late TextScaler content;
      await pumpScaled(
        t,
        2.0,
        RaftChrome(
          child: RaftChrome(
            child: Builder(
              builder: (context) {
                content = RaftChrome.contentScalerOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(content.scale(13), greaterThan(13 * 1.35));
    });
  });

  group('RaftLargeContentViewer', () {
    Widget item(
      String label,
      List<String> log, {
      required Key key,
      bool withIcon = true,
    }) => RaftLargeContentViewer(
      label: label,
      onActivate: () => log.add('activate $label'),
      iconBuilder: withIcon
          ? (context, size) => Icon(Icons.chat_bubble_outline, size: size)
          : null,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () => log.add('tap $label'),
        child: SizedBox(
          width: 100,
          height: 48,
          child: Center(child: Text(label)),
        ),
      ),
    );

    Widget bar(List<String> log) => RaftChrome(
      child: RaftLargeContentScope(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            item('Chat', log, key: const Key('chat')),
            item('Tasks', log, key: const Key('tasks'), withIcon: false),
          ],
        ),
      ),
    );

    final viewer = find.byKey(const Key('raft-large-content-viewer'));

    testWidgets('does nothing at the default text size', (t) async {
      final log = <String>[];
      await pumpScaled(t, 1.0, bar(log));
      final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('chat'))),
      );
      await t.pump(const Duration(seconds: 1));
      expect(viewer, findsNothing);
      await g.up();
      await t.pump();
      expect(log, ['tap Chat']);
    });

    testWidgets('a tap still activates at a large text size', (t) async {
      final log = <String>[];
      await pumpScaled(t, _ios(53), bar(log));
      await t.tap(find.byKey(const Key('chat')));
      await t.pump(const Duration(seconds: 1));
      expect(viewer, findsNothing);
      expect(log, ['tap Chat']);
    });

    testWidgets('a long press shows the item large and release activates it', (
      t,
    ) async {
      final log = <String>[];
      await pumpScaled(t, _ios(53), bar(log));
      final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('chat'))),
      );
      await t.pump(const Duration(milliseconds: 700));
      expect(viewer, findsOneWidget);
      expect(
        find.descendant(of: viewer, matching: find.text('Chat')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: viewer, matching: find.byType(Icon)),
        findsOneWidget,
      );
      // Large: the label is at the content scale, far above the chrome bound.
      final style = t.widget<Text>(
        find.descendant(of: viewer, matching: find.text('Chat')),
      );
      final size = t.getSize(
        find.descendant(of: viewer, matching: find.text('Chat')),
      );
      expect(size.height, greaterThan(30));
      expect(style.data, 'Chat');
      expect(
        t.getCenter(viewer).dx,
        closeTo(t.view.physicalSize.width / 2, 1),
        reason: 'centered on screen',
      );
      expect(log, isEmpty);
      await g.up();
      await t.pump();
      expect(viewer, findsNothing);
      expect(log, ['activate Chat']);
    });

    testWidgets('sliding to a sibling shows and activates the sibling', (
      t,
    ) async {
      final log = <String>[];
      await pumpScaled(t, _ios(53), bar(log));
      final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('chat'))),
      );
      await t.pump(const Duration(milliseconds: 700));
      await g.moveTo(t.getCenter(find.byKey(const Key('tasks'))));
      await t.pump();
      expect(
        find.descendant(of: viewer, matching: find.text('Tasks')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: viewer, matching: find.text('Chat')),
        findsNothing,
      );
      await g.up();
      await t.pump();
      expect(viewer, findsNothing);
      expect(log, ['activate Tasks']);
    });

    testWidgets('releasing away from every item activates nothing', (t) async {
      final log = <String>[];
      await pumpScaled(t, _ios(53), bar(log));
      final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('chat'))),
      );
      await t.pump(const Duration(milliseconds: 700));
      await g.moveTo(const Offset(5, 5));
      await t.pump();
      await g.up();
      await t.pump();
      expect(viewer, findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('a cancelled press closes the viewer', (t) async {
      final log = <String>[];
      await pumpScaled(t, _ios(53), bar(log));
      final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('chat'))),
      );
      await t.pump(const Duration(milliseconds: 700));
      expect(viewer, findsOneWidget);
      await g.cancel();
      await t.pump();
      expect(viewer, findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('an item removed while the viewer shows it closes the viewer', (
      t,
    ) async {
      final log = <String>[];
      await pumpScaled(t, _ios(53), bar(log));
      final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('chat'))),
      );
      await t.pump(const Duration(milliseconds: 700));
      expect(viewer, findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await g.cancel();
      await t.pump();
      expect(viewer, findsNothing);
    });

    testWidgets('a standalone item works without a scope', (t) async {
      final log = <String>[];
      await pumpScaled(
        t,
        _ios(53),
        RaftChrome(child: item('Files', log, key: const Key('files'))),
      );
      final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('files'))),
      );
      await t.pump(const Duration(milliseconds: 700));
      expect(viewer, findsOneWidget);
      await g.up();
      await t.pump();
      expect(log, ['activate Files']);
    });

    testWidgets('the viewer is announced to screen readers', (t) async {
      final handle = t.ensureSemantics();
      final log = <String>[];
      await pumpScaled(t, _ios(53), bar(log));
      final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('chat'))),
      );
      await t.pump(const Duration(milliseconds: 700));
      final node = t.getSemantics(viewer);
      expect(node.label, startsWith('Chat'));
      expect(node.flagsCollection.isLiveRegion, isTrue);
      await g.up();
      await t.pump();
      handle.dispose();
    });
  });
}
