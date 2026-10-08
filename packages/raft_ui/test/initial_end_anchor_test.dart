import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Future<void> frame(
    WidgetTester t,
    ScrollController c, {
    required double height,
    bool enabled = true,
    bool contentReady = true,
    bool presentationActive = true,
    VoidCallback? ready,
    Widget? action,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            width: 360,
            child: RaftInitialEndAnchor(
              controller: c,
              enabled: enabled,
              presentationActive: presentationActive,
              contentReady: contentReady,
              onInitialReady: ready,
              child: SingleChildScrollView(
                key: ValueKey(c),
                controller: c,
                child: Column(
                  children: [
                    SizedBox(height: height),
                    action ?? const Text('Latest row'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('hidden initial epoch pauses without retiring and resumes once', (
    t,
  ) async {
    final c = ScrollController();
    var retired = 0;
    await frame(t, c, height: 700, contentReady: false, ready: () => retired++);
    await frame(
      t,
      c,
      height: 1000,
      presentationActive: false,
      ready: () => retired++,
    );
    await t.pump(const Duration(seconds: 1));
    expect(c.offset, 0);
    expect(retired, 0);
    expect(t.binding.hasScheduledFrame, isFalse);
    await frame(t, c, height: 1000, ready: () => retired++);
    await t.pump(const Duration(milliseconds: 300));
    expect(c.offset, c.position.maxScrollExtent);
    expect(retired, 1);
    final offset = c.offset;
    await frame(
      t,
      c,
      height: 1400,
      presentationActive: false,
      ready: () => retired++,
    );
    await frame(t, c, height: 1400, ready: () => retired++);
    expect(c.offset, offset);
    expect(retired, 1);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'deferred empty page does not retire before real content, reading still owns viewport',
    (t) async {
      final c = ScrollController();
      var retired = 0;
      await frame(t, c, height: 0, contentReady: false, ready: () => retired++);
      await t.pump(const Duration(seconds: 1));
      expect(retired, 0);
      await frame(
        t,
        c,
        height: 1400,
        contentReady: true,
        ready: () => retired++,
      );
      await t.pump(const Duration(milliseconds: 300));
      expect(c.offset, c.position.maxScrollExtent);
      expect(retired, 1);
      c.jumpTo(100);
      await frame(t, c, height: 1600, ready: () => retired++);
      expect(c.offset, 100);
      expect(retired, 1);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'delayed initial growth follows actual end then retires before later append/prepend',
    (t) async {
      final c = ScrollController();
      var retired = 0;
      await frame(t, c, height: 700, ready: () => retired++);
      expect(c.offset, c.position.maxScrollExtent);
      await t.pump(const Duration(milliseconds: 100));
      await frame(t, c, height: 1000, ready: () => retired++);
      expect(c.offset, c.position.maxScrollExtent);
      await t.pump(const Duration(milliseconds: 300));
      expect(retired, 1);
      final kept = c.offset;
      await frame(t, c, height: 1300, ready: () => retired++);
      await t.pump(const Duration(milliseconds: 300));
      expect(c.offset, kept);
      expect(c.position.maxScrollExtent, greaterThan(kept));
      await frame(t, c, height: 1500, ready: () => retired++);
      expect(c.offset, kept);
      expect(retired, 1);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'late metrics requests its own correction frame and stops after retirement',
    (t) async {
      final c = ScrollController();
      var retired = 0;
      await frame(t, c, height: 700, ready: () => retired++);
      await t.pump(const Duration(milliseconds: 50));
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(retired, 0);
      // ScrollPosition delivers metrics outside the layout frame. Do not pump a
      // new frame before asserting that the component requested one itself.
      ScrollMetricsNotification(
        metrics: c.position.copyWith(),
        context: t.element(find.byType(SingleChildScrollView)),
      ).dispatch(t.element(find.byType(SingleChildScrollView)));
      expect(t.binding.hasScheduledFrame, isTrue);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(retired, 1);
      expect(t.binding.hasScheduledFrame, isFalse);
      ScrollMetricsNotification(
        metrics: c.position.copyWith(),
        context: t.element(find.byType(SingleChildScrollView)),
      ).dispatch(t.element(find.byType(SingleChildScrollView)));
      expect(t.binding.hasScheduledFrame, isFalse);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('programmatic history jump revokes queued initial corrections', (
    t,
  ) async {
    final c = ScrollController();
    var retired = 0;
    await frame(t, c, height: 700, ready: () => retired++);
    c.jumpTo(0);
    await frame(t, c, height: 1100, ready: () => retired++);
    await t.pump(const Duration(milliseconds: 300));
    expect(c.offset, 0);
    expect(retired, 1);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('real drag owns reading viewport before initial quiet timer', (
    t,
  ) async {
    final c = ScrollController();
    await frame(t, c, height: 700);
    await t.drag(find.byType(SingleChildScrollView), const Offset(0, 160));
    await t.pumpAndSettle();
    final kept = c.offset;
    expect(kept, lessThan(c.position.maxScrollExtent));
    await frame(t, c, height: 1200);
    await t.pump(const Duration(milliseconds: 300));
    expect(c.offset, kept);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('keyboard reading action retires before its content grows', (
    t,
  ) async {
    final c = ScrollController();
    final focus = FocusNode();
    var retired = 0, actions = 0;
    await frame(
      t,
      c,
      height: 700,
      ready: () => retired++,
      action: TextButton(
        focusNode: focus,
        onPressed: () => actions++,
        child: const Text('Show source'),
      ),
    );
    focus.requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(actions, 1);
    expect(retired, 1);
    final kept = c.offset;
    await frame(t, c, height: 1400);
    expect(c.offset, kept);
    await t.pumpWidget(const SizedBox());
    focus.dispose();
    c.dispose();
  });
  testWidgets(
    'highlighted none mode preserves history and replacement rejects old epoch',
    (t) async {
      final old = ScrollController(), next = ScrollController();
      await frame(t, old, height: 700);
      await frame(t, next, height: 1000, enabled: false);
      await t.pump(const Duration(milliseconds: 300));
      expect(next.offset, 0);
      expect(find.text('Latest row').hitTestable(), findsNothing);
      await t.pumpWidget(const SizedBox());
      old.dispose();
      next.dispose();
      expect(t.takeException(), isNull);
    },
  );
}
