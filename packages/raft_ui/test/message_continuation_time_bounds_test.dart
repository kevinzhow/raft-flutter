import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (dark) in raftThemeMatrix([(false), (true)], full: true)) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} width $width continuation clock stays within its gutter',
        (t) async {
          await t.runAsync(() async {
            ByteData data;
            try {
              data = await rootBundle.load(
                'packages/raft_ui/assets/fonts/SpaceMono.ttf',
              );
            } on FlutterError {
              data = await rootBundle.load('assets/fonts/SpaceMono.ttf');
            }
            await (FontLoader(
              'packages/raft_ui/SpaceMono',
            )..addFont(Future.value(data))).load();
          });
          await t.binding.setSurfaceSize(Size(width, 480));
          addTearDown(() => t.binding.setSurfaceSize(null));
          final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.addPointer(location: const Offset(2, 300));
          addTearDown(mouse.removePointer);
          try {
            for (final scale in [1.0, 2.0]) {
              for (final time in ['16:48', '04:48 PM']) {
                await t.pumpWidget(
                  MaterialApp(
                    theme: raftTheme(dark: dark),
                    home: MediaQuery(
                      data: MediaQueryData(
                        size: Size(width, 480),
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: Scaffold(
                        body: Align(
                          alignment: Alignment.topLeft,
                          child: RaftMessageRow(
                            author: 'Public author',
                            timestamp: time,
                            continuation: true,
                            content: const Text('Public message body'),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                final clock = find.text(time);
                final body = find.text('Public message body');
                final initial = t.getRect(body);
                await mouse.moveTo(t.getCenter(body));
                await t.pump();
                expect(t.widget<Text>(clock).style!.color!.a, greaterThan(0));
                final recipe = RaftMessageRowRecipe(
                  RaftTokens.of(t.element(body)),
                  viewportWidth: width,
                );
                final gutter = find.ancestor(
                  of: clock,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is SizedBox &&
                        w.height != null &&
                        w.height! >= 14 &&
                        w.width == recipe.gutterWidth,
                  ),
                );
                final bounds = t.getRect(gutter);
                final paint = t.getRect(clock);
                expect(
                  paint.left,
                  greaterThanOrEqualTo(bounds.left - .01),
                  reason: '$time at text scale $scale escaped the gutter',
                );
                expect(paint.right, lessThanOrEqualTo(bounds.right - 4 + .01));
                expect(t.getRect(body), initial);
                await mouse.moveTo(const Offset(2, 300));
                await t.pump();
                expect(t.widget<Text>(clock).style!.color!.a, 0);
                expect(t.getRect(body), initial);
                expect(t.takeException(), isNull);
              }
            }
          } finally {
            await t.pumpWidget(const SizedBox());
            await t.pump();
          }
        },
      );
    }
  }
}
