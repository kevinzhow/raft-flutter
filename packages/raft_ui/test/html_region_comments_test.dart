import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const region = RaftHtmlRegion(
  rect: Rect.fromLTWH(20, 130, 120, 80),
  viewportWidth: 500,
  document: Size(1000, 3000),
  quote: 'Context quote',
);

class Geometry implements RaftHtmlRegionController {
  @override
  bool active = true;
  final captures = <Completer<RaftHtmlRegionLocation?>>[];
  final jumps = <Completer<RaftHtmlRegionLocation?>>[];
  final rectangles = <Rect>[];
  double y = 100;
  int measures = 0, scrolls = 0;
  RaftHtmlGeometry shape(Size size) => RaftHtmlGeometry(
    viewport: size,
    visible: size,
    scroll: Offset(0, y),
    document: const Size(1000, 3000),
  );
  RaftHtmlRegionLocation result(Size size, {RaftHtmlRegion value = region}) =>
      RaftHtmlRegionLocation(shape(size), value);
  @override
  Future<RaftHtmlGeometry?> measure(Size host) async {
    measures++;
    return shape(host);
  }

  @override
  Future<RaftHtmlRegionLocation?> capture(Rect rect, Size host) {
    rectangles.add(rect);
    final p = Completer<RaftHtmlRegionLocation?>();
    captures.add(p);
    return p.future;
  }

  @override
  Future<RaftHtmlRegionLocation?> jump(RaftHtmlRegion region, Size host) {
    final p = Completer<RaftHtmlRegionLocation?>();
    jumps.add(p);
    return p.future;
  }

  @override
  Future<RaftHtmlGeometry?> scrollBy(Offset delta, Size host) async {
    scrolls++;
    y += delta.dy;
    return shape(host);
  }
}

Widget frame(
  RaftAttachmentCommentState state,
  Geometry controller, {
  bool enabled = true,
  bool touch = false,
  Size size = const Size(856, 944),
  double scale = 1,
}) => MaterialApp(
  theme: raftTheme().copyWith(
    platform: touch ? TargetPlatform.android : TargetPlatform.linux,
  ),
  home: MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: RaftAttachmentCommentScope(
        state: state,
        child: RaftHtmlRegionCommentSurface(
          controller: controller,
          enabled: enabled,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  ),
);
Future<void> drag(
  WidgetTester t, {
  Offset from = const Offset(20, 30),
  Offset to = const Offset(140, 110),
}) async {
  final box = t.getTopLeft(find.byKey(const ValueKey('html-region-capture')));
  final g = await t.startGesture(box + from, kind: PointerDeviceKind.mouse);
  await g.moveTo(box + to);
  await g.up();
  await t.pump();
}

void main() {
  for (final (size, touch) in [
    (const Size(856, 944), true),
    (const Size(944, 856), true),
    (const Size(390, 844), false),
  ]) {
    testWidgets('input policy at $size touch=$touch and stored jump flash', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final state = RaftAttachmentCommentState()..commentMode = true;
      final c = Geometry();
      await t.pumpWidget(frame(state, c, touch: touch, size: size));
      expect(
        find.byKey(const ValueKey('html-region-capture')),
        touch ? findsNothing : findsOneWidget,
      );
      final pending = state.jumpAsync(region.anchor);
      await t.pump();
      expect(c.jumps.length, 1);
      c.jumps.single.complete(c.result(size));
      await t.pump();
      expect(await pending, isTrue);
      await t.pump();
      expect(find.byKey(const ValueKey('html-region-flash')), findsOneWidget);
      expect(
        t.widget<RaftHtmlRegionMarker>(find.byType(RaftHtmlRegionMarker)).rect,
        const Rect.fromLTWH(20, 30, 120, 80),
      );
      c.y = 120;
      await t.pump(const Duration(milliseconds: 120));
      await t.pump();
      expect(
        t
            .widget<RaftHtmlRegionMarker>(find.byType(RaftHtmlRegionMarker))
            .rect
            .top,
        10,
      );
      await t.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('html-region-flash')), findsNothing);
      await t.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
  testWidgets(
    'reverse drag and click capture; last capture wins; mode close invalidates late results',
    (t) async {
      final s = RaftAttachmentCommentState()..commentMode = true;
      final c = Geometry();
      await t.pumpWidget(frame(s, c));
      await drag(t, from: const Offset(140, 110), to: const Offset(20, 30));
      expect(c.rectangles.single, const Rect.fromLTWH(20, 30, 120, 80));
      await drag(t, from: const Offset(30, 40), to: const Offset(30, 40));
      expect(c.rectangles.last, const Rect.fromLTWH(30, 40, 0, 0));
      c.captures[1].complete(c.result(const Size(800, 600)));
      await t.pump();
      expect(s.pendingAnchor, region.anchor);
      s.clearAnchor();
      c.captures[0].complete(c.result(const Size(800, 600)));
      await t.pump();
      expect(s.pendingAnchor, isNull);
      await drag(t);
      s.commentMode = false;
      await t.pump();
      c.captures.last.complete(c.result(const Size(800, 600)));
      await t.pump();
      expect(s.pendingAnchor, isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets(
    'revocation, replacement, close and resize invalidate in-flight captures',
    (t) async {
      for (final action in ['flag', 'replace', 'close', 'resize']) {
        final s = RaftAttachmentCommentState()..commentMode = true;
        final c = Geometry();
        await t.pumpWidget(frame(s, c));
        await drag(t);
        if (action == 'flag') await t.pumpWidget(frame(s, c, enabled: false));
        if (action == 'replace') await t.pumpWidget(frame(s, Geometry()));
        if (action == 'close') await t.pumpWidget(const SizedBox());
        if (action == 'resize') {
          t.view.physicalSize = const Size(400, 700);
          await t.pump();
        }
        c.captures.single.complete(c.result(const Size(800, 600)));
        await t.pump();
        expect(s.pendingAnchor, isNull, reason: action);
        await t.pumpWidget(const SizedBox());
        s.dispose();
        t.view.reset();
      }
    },
  );
  testWidgets(
    'last jump wins; failed or closing jump never folds a comments sheet',
    (t) async {
      final s = RaftAttachmentCommentState()..commentMode = true;
      final c = Geometry();
      await t.pumpWidget(frame(s, c));
      final first = s.jumpAsync(region.anchor),
          second = s.jumpAsync(region.anchor);
      await t.pump();
      c.jumps.last.complete(c.result(const Size(800, 600)));
      await t.pump();
      expect(await second, isTrue);
      c.jumps.first.complete(c.result(const Size(800, 600)));
      expect(await first, isFalse);
      final third = s.jumpAsync(region.anchor);
      await t.pump();
      await t.pumpWidget(frame(s, c, enabled: false));
      c.jumps.last.complete(c.result(const Size(800, 600)));
      expect(await third, isFalse);
      expect(s.jumpHandler, isNull);
      expect(s.asyncJumpHandler, isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets(
    'wheel forwards to document; marker measure stops on background and removal',
    (t) async {
      final s = RaftAttachmentCommentState()..commentMode = true;
      final c = Geometry();
      await t.pumpWidget(frame(s, c));
      await t.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(30, 40),
          scrollDelta: Offset(0, 50),
        ),
      );
      await t.pump();
      expect(c.scrolls, 1);
      final jump = s.jumpAsync(region.anchor);
      await t.pump();
      c.jumps.single.complete(c.result(const Size(800, 600)));
      await t.pump();
      expect(await jump, isTrue);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      expect(find.byKey(const ValueKey('html-region-flash')), findsNothing);
      final measured = c.measures;
      await t.pump(const Duration(seconds: 2));
      expect(c.measures, measured);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets(
    'retiring a surface clears a published anchor during rebuild and unmount',
    (t) async {
      final s = RaftAttachmentCommentState()..commentMode = true;
      final c = Geometry();
      await t.pumpWidget(frame(s, c));
      s.pushAnchor(region.anchor);
      await t.pump();
      await t.pumpWidget(frame(s, c, enabled: false));
      await t.pump();
      expect(s.pendingAnchor, isNull);
      expect(t.takeException(), isNull);
      await t.pumpWidget(frame(s, c));
      s.pushAnchor(region.anchor);
      await t.pump();
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(s.pendingAnchor, isNull);
      expect(t.takeException(), isNull);
      s.dispose();
    },
  );
}
