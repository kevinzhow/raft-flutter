@Tags(['slow'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';

import 'mobile_computer_navigation_test.dart' show fixture, finishPageAnimation;

void main() {
  testWidgets('Computer detail returns while stretch is settling', (t) async {
    if (ui.ImageFilter.isShaderFilterSupported) {
      await t.runAsync(() async {
        await ui.FragmentProgram.fromAsset('shaders/stretch_effect.frag');
      });
    }
    final f = fixture();
    await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/computers'));
    final w = f.workspace(t);
    final card = find.byKey(const ValueKey('fleet-computer-a'));
    await finishPageAnimation(t, card);
    for (var cycle = 0; cycle < 20; cycle++) {
      await t.tap(card);
      await f.flush(t);
      final back = find.byKey(const Key('computer-mobile-back'));
      await finishPageAnimation(t, back);
      final scroll = find.byType(SingleChildScrollView).last;
      final touch = await t.startGesture(t.getCenter(scroll));
      await touch.moveBy(const Offset(0, 140));
      await t.pump(const Duration(milliseconds: 16));
      await touch.moveBy(const Offset(0, 100));
      await t.pump(const Duration(milliseconds: 16));
      await touch.up();
      await t.pump(const Duration(milliseconds: 16));
      final strengths = t
          .widgetList<StretchEffect>(find.byType(StretchEffect))
          .map((effect) => effect.stretchStrength)
          .toList();
      expect(strengths.any((strength) => strength != 0), isTrue);
      for (final (method, progress) in [
        ('startBackGesture', 0.0),
        ('updateBackGestureProgress', 1.0),
        ('commitBackGesture', null),
      ]) {
        await t.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/backgesture',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(
              method,
              progress == null
                  ? null
                  : {
                      'touchOffset': [100.0, 300.0],
                      'progress': progress,
                      'swipeEdge': 0,
                    },
            ),
          ),
          (_) {},
        );
        await t.pump();
      }
      await t.pump();
      await f.flush(t);
      expect(w.location.route, RaftRoute.computers);
      await finishPageAnimation(t, card);
      expect(t.takeException(), isNull);
    }
    await f.close(t);
  });
}
