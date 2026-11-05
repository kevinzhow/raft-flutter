import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'fixtures/html_region_native_fixture.dart';

void main() {
  testWidgets(
    'native input uses SDK capture geometry and monotonic generation',
    (tester) async {
      final session = RaftAttachmentCommentState()..commentMode = true;
      final controller = NativeGeometry();
      await tester.pumpWidget(nativeFrame(session, controller));
      await tester.pump();
      expect(controller.frames, isNotEmpty);
      final frame = controller.frames.last;
      expect(frame.captureEnabled, isTrue);
      controller.send(
        frame,
        RaftHtmlNativeRegionPhase.down,
        1,
        const Offset(.25, .2),
      );
      controller.send(
        frame,
        RaftHtmlNativeRegionPhase.move,
        2,
        const Offset(.5, .4),
      );
      controller.send(
        frame,
        RaftHtmlNativeRegionPhase.up,
        3,
        const Offset(.5, .4),
      );
      await tester.pump();
      expect(
        controller.captures.single.$1,
        Rect.fromLTWH(
          frame.viewport.width * .25,
          frame.viewport.height * .2,
          frame.viewport.width * .25,
          frame.viewport.height * .2,
        ),
      );
      expect(session.pendingAnchor?['type'], 'html-region');
      await tester.pumpWidget(const SizedBox());
      await controller.input.close();
      session.dispose();
    },
  );
  testWidgets(
    'old generations, wrong panes, invalid coordinates and duplicate sequences are ignored',
    (tester) async {
      final session = RaftAttachmentCommentState()..commentMode = true;
      final controller = NativeGeometry();
      await tester.pumpWidget(nativeFrame(session, controller));
      await tester.pump();
      final frame = controller.frames.last;
      controller.input.add(
        RaftHtmlNativeRegionInput(
          generation: frame.generation - 1,
          sequence: 1,
          phase: RaftHtmlNativeRegionPhase.down,
          position: const Offset(.1, .1),
          viewport: frame.viewport,
        ),
      );
      controller.input.add(
        RaftHtmlNativeRegionInput(
          generation: frame.generation,
          sequence: 2,
          phase: RaftHtmlNativeRegionPhase.down,
          position: const Offset(.1, .1),
          viewport: frame.viewport + const Offset(1, 0),
        ),
      );
      controller.send(
        frame,
        RaftHtmlNativeRegionPhase.down,
        3,
        const Offset(double.nan, .1),
      );
      controller.send(
        frame,
        RaftHtmlNativeRegionPhase.up,
        4,
        const Offset(.2, .2),
      );
      await tester.pump();
      expect(controller.captures, isEmpty);
      controller.send(
        frame,
        RaftHtmlNativeRegionPhase.down,
        5,
        const Offset(.1, .1),
      );
      controller.send(
        frame,
        RaftHtmlNativeRegionPhase.up,
        5,
        const Offset(.2, .2),
      );
      expect(controller.captures, isEmpty);
      controller.send(
        frame,
        RaftHtmlNativeRegionPhase.up,
        6,
        const Offset(.2, .2),
      );
      await tester.pump();
      expect(controller.captures, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await controller.input.close();
      session.dispose();
    },
  );

  testWidgets(
    'mode close and background retire input; resume and resize issue new generations',
    (tester) async {
      final session = RaftAttachmentCommentState()..commentMode = true;
      final controller = NativeGeometry();
      await tester.pumpWidget(nativeFrame(session, controller));
      await tester.pump();
      final old = controller.frames.last;
      session.commentMode = false;
      await tester.pump();
      expect(controller.frames.last.captureEnabled, isFalse);
      session.commentMode = true;
      await tester.pump();
      expect(controller.frames.last.generation, greaterThan(old.generation));
      controller.send(
        old,
        RaftHtmlNativeRegionPhase.down,
        1,
        const Offset(.1, .1),
      );
      controller.send(
        old,
        RaftHtmlNativeRegionPhase.up,
        2,
        const Offset(.2, .2),
      );
      expect(controller.captures, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final hidden = controller.frames.last;
      expect(hidden.captureEnabled, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.frames.last.captureEnabled, isTrue);
      expect(controller.frames.last.generation, greaterThan(hidden.generation));
      final beforeResize = controller.frames.last;
      tester.view.physicalSize = const Size(420, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pump();
      expect(controller.frames.last.viewport, const Size(420, 700));
      expect(
        controller.frames.last.generation,
        greaterThan(beforeResize.generation),
      );
      controller.send(
        beforeResize,
        RaftHtmlNativeRegionPhase.down,
        1,
        const Offset(.1, .1),
      );
      controller.send(
        beforeResize,
        RaftHtmlNativeRegionPhase.up,
        2,
        const Offset(.2, .2),
      );
      expect(controller.captures, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await controller.input.close();
      session.dispose();
    },
  );

  testWidgets('late capture cannot cross controller replacement or disable', (
    tester,
  ) async {
    final session = RaftAttachmentCommentState()..commentMode = true;
    final first = NativeGeometry()
      ..pendingCapture = Completer<RaftHtmlRegionLocation?>();
    final second = NativeGeometry();
    await tester.pumpWidget(nativeFrame(session, first));
    await tester.pump();
    final frame = first.frames.last;
    first.send(frame, RaftHtmlNativeRegionPhase.down, 1, const Offset(.1, .1));
    first.send(frame, RaftHtmlNativeRegionPhase.up, 2, const Offset(.2, .2));
    expect(first.captures, hasLength(1));
    await tester.pumpWidget(nativeFrame(session, second));
    await tester.pump();
    first.pendingCapture!.complete(
      RaftHtmlRegionLocation(
        first.shape(frame.viewport),
        RaftHtmlRegion(
          rect: const Rect.fromLTWH(1, 2, 3, 4),
          viewportWidth: 800,
          document: const Size(2000, 3000),
        ),
      ),
    );
    await tester.pump();
    expect(session.pendingAnchor, isNull);
    expect(first.frames.last.captureEnabled, isFalse);
    final next = second.frames.last;
    await tester.pumpWidget(nativeFrame(session, second, enabled: false));
    await tester.pump();
    second.send(next, RaftHtmlNativeRegionPhase.down, 1, const Offset(.1, .1));
    second.send(next, RaftHtmlNativeRegionPhase.up, 2, const Offset(.2, .2));
    expect(second.captures, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await first.input.close();
    await second.input.close();
    session.dispose();
  });

  testWidgets(
    'touch policy disables native capture and real wheel uses pane normalization',
    (tester) async {
      final session = RaftAttachmentCommentState()..commentMode = true;
      final controller = NativeGeometry();
      await tester.pumpWidget(nativeFrame(session, controller, touch: true));
      await tester.pump();
      final touch = controller.frames.last;
      expect(touch.captureEnabled, isFalse);
      controller.send(
        touch,
        RaftHtmlNativeRegionPhase.down,
        1,
        const Offset(.1, .1),
      );
      controller.send(
        touch,
        RaftHtmlNativeRegionPhase.up,
        2,
        const Offset(.2, .2),
      );
      expect(controller.captures, isEmpty);
      await tester.pumpWidget(nativeFrame(session, controller));
      await tester.pumpAndSettle();
      final pointer = controller.frames.last;
      expect(pointer.captureEnabled, isTrue);
      controller.send(
        pointer,
        RaftHtmlNativeRegionPhase.scroll,
        1,
        const Offset(.2, .2),
        delta: const Offset(0, .1),
      );
      await tester.pump();
      expect(
        controller.scrolls.single,
        Offset(0, pointer.viewport.height * .1),
      );
      controller.send(
        pointer,
        RaftHtmlNativeRegionPhase.down,
        2,
        const Offset(.1, .1),
      );
      controller.send(
        pointer,
        RaftHtmlNativeRegionPhase.cancel,
        3,
        const Offset(.1, .1),
      );
      controller.send(
        pointer,
        RaftHtmlNativeRegionPhase.up,
        4,
        const Offset(.2, .2),
      );
      expect(controller.captures, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await controller.input.close();
      session.dispose();
    },
  );
  testWidgets(
    'a hidden ticker generation cannot finish a previously accepted capture',
    (tester) async {
      final session = RaftAttachmentCommentState()..commentMode = true;
      final controller = NativeGeometry()
        ..pendingCapture = Completer<RaftHtmlRegionLocation?>();
      await tester.pumpWidget(nativeFrame(session, controller));
      await tester.pump();
      final frame = controller.frames.last;
      controller.send(
        frame,
        RaftHtmlNativeRegionPhase.down,
        1,
        const Offset(.1, .1),
      );
      controller.send(
        frame,
        RaftHtmlNativeRegionPhase.up,
        2,
        const Offset(.2, .2),
      );
      expect(controller.captures, hasLength(1));
      await tester.pumpWidget(nativeFrame(session, controller, tickers: false));
      await tester.pump();
      expect(controller.frames.last.captureEnabled, isFalse);
      controller.pendingCapture!.complete(
        RaftHtmlRegionLocation(
          controller.shape(frame.viewport),
          RaftHtmlRegion(
            rect: const Rect.fromLTWH(1, 2, 3, 4),
            viewportWidth: 800,
            document: const Size(2000, 3000),
          ),
        ),
      );
      await tester.pump();
      expect(session.pendingAnchor, isNull);
      await tester.pumpWidget(nativeFrame(session, controller));
      await tester.pump();
      expect(controller.frames.last.captureEnabled, isTrue);
      expect(controller.frames.last.generation, greaterThan(frame.generation));
      await tester.pumpWidget(const SizedBox());
      await controller.input.close();
      session.dispose();
    },
  );
}
