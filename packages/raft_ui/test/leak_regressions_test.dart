// Leak-tracking regressions: each test builds the widget, tears it down and
// ends; the object-leak report that `flutter_test_config.dart` enables fails
// this file when the widget leaves a TextPainter or OverlayEntry undisposed.
// None of these classes may ever be added to that file's ignore list.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show OwnedFrameCodec;

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
);

class _FakeCodec implements ui.Codec {
  _FakeCodec(this._next);
  final Future<ui.FrameInfo> _next;
  @override
  int get frameCount => 1;
  @override
  int get repetitionCount => 0;
  @override
  Future<ui.FrameInfo> getNextFrame() => _next;
  @override
  void dispose() {}
}

void main() {
  test('the raft_ui leak ignore list never hides what these tests guard', () {
    final ignored = LeakTesting.settings.ignoredLeaks.notDisposed.byClass.keys;
    expect(ignored, isNot(contains('TextPainter')));
    expect(ignored, isNot(contains('OverlayEntry')));
  });

  testWidgets('DM header measures its texts with painters it disposes', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: false),
        home: const Scaffold(
          body: RaftDmHeader(
            name: 'A rather long peer display name',
            avatar: SizedBox(width: 36, height: 36),
            activity: RaftActivityTone.working,
            activityText: 'Thinking about something long',
            muted: true,
          ),
        ),
      ),
    );
    // Every rebuild measures again.
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: true),
        home: const Scaffold(
          body: RaftDmHeader(
            name: 'Peer',
            avatar: SizedBox(width: 36, height: 36),
          ),
        ),
      ),
    );
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the toast host keeps one overlay entry and disposes it', (
    t,
  ) async {
    final controller = RaftToastController();
    addTearDown(controller.dispose);
    Widget app(String label) => MaterialApp(
      theme: raftTheme(dark: false),
      home: RaftToastHost(
        controller: controller,
        child: Scaffold(body: Text(label)),
      ),
    );
    await t.pumpWidget(app('one'));
    // A host rebuild used to create (and drop) a fresh OverlayEntry each time.
    await t.pumpWidget(app('two'));
    await t.pumpWidget(app('three'));
    controller.show('Copied', dismissible: false);
    await t.pump();
    expect(find.text('Copied'), findsOneWidget);
    await t.pump(const Duration(seconds: 30)); // the auto-dismiss timer
    await t.pumpWidget(const SizedBox());
  });

  test('a frame that lands after its codec was disposed is disposed', () async {
    // The shape of Flutter's MultiFrameImageStreamCompleter leak: the last
    // listener leaves (the codec is disposed) while getNextFrame is in flight.
    final real = await ui.instantiateImageCodec(_png);
    final late = Completer<ui.FrameInfo>();
    final codec = OwnedFrameCodec(_FakeCodec(late.future));
    final pending = codec.getNextFrame();
    codec.dispose();
    final frame = await real.getNextFrame();
    late.complete(frame);
    final delivered = await pending;
    expect(delivered.image.debugDisposed, isTrue);
    // A frame that lands while the codec is alive belongs to its caller.
    final other = await ui.instantiateImageCodec(_png);
    final alive = OwnedFrameCodec(_FakeCodec(other.getNextFrame()));
    final kept = await alive.getNextFrame();
    expect(kept.image.debugDisposed, isFalse);
    kept.image.dispose();
    other.dispose();
    real.dispose();
  });
}
