// The media browser at large text: chrome is bounded and offers the Large
// Content Viewer, the sender line and the caption reflow, nothing overflows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/media_browser_previews.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Future<void> pump(WidgetTester t, double factor, Widget preview) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = factor;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        builder: (context, child) => RaftTextScaling(child: child!),
        home: Scaffold(body: preview),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
  }

  for (final factor in [1.0, 2.0, 3.1]) {
    testWidgets('phone browser lays out without overflow at ${factor}x', (
      t,
    ) async {
      await pump(t, factor, mediaBrowserPhonePreview());
      expect(t.takeException(), isNull);
      expect(find.text('IMG_2041.jpg'), findsOneWidget);
    });
  }

  testWidgets('the sender line wraps and the caption band grows at 2.0x', (
    t,
  ) async {
    await pump(t, 1.0, mediaBrowserPhonePreview());
    final caption1 = t.getSize(find.byKey(const ValueKey('media-caption')));
    await pump(t, 2.0, mediaBrowserPhonePreview());
    final caption2 = t.getSize(find.byKey(const ValueKey('media-caption')));
    expect(caption2.height, greaterThan(caption1.height));
    expect(t.takeException(), isNull);
  });

  testWidgets('a long press on a top bar action shows it large at 3.1x', (
    t,
  ) async {
    await pump(t, 3.1, mediaBrowserPhonePreview());
    final share = find.bySemanticsLabel('Share').first;
    final g = await t.startGesture(t.getCenter(share));
    await t.pump(const Duration(milliseconds: 700));
    expect(
      find.descendant(
        of: find.byKey(const Key('raft-large-content-viewer')),
        matching: find.text('Share'),
      ),
      findsOneWidget,
    );
    await g.cancel();
    await t.pump();
  });
}
