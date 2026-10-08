import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'dark source inset paints inside field and survives border tween',
    (tester) async {
      final theme = raftTheme(RaftFamily.elegant, dark: true);
      final normal =
          theme.inputDecorationTheme.enabledBorder! as RaftFieldBorder;
      final focused =
          theme.inputDecorationTheme.focusedBorder! as RaftFieldBorder;
      final mid = ShapeBorder.lerp(normal, focused, .5)! as RaftFieldBorder;
      expect(mid.insets, isNotNull);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 300,
                  child: TextField(
                    style: theme.extension<RaftTokens>()!.fieldStyle,
                    decoration: InputDecoration(hintText: 'Name'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final data = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          return await image.toByteData(format: ImageByteFormat.rawRgba);
        } finally {
          image.dispose();
        }
      });
      expect(data, isNotNull);
      // A transparent 1px CSS border retains the fill at the border edge;
      // the black inset ring begins inside it, at the padding edge.
      final interior = data!.getUint8((19 * 300 + 150) * 4);
      expect(data.getUint8(150 * 4), interior);
      expect(data.getUint8((300 + 150) * 4), lessThan(interior));
      expect(data.getUint8((19 * 300) * 4), interior);
      expect(data.getUint8((19 * 300 + 1) * 4), lessThan(interior));
      expect(boundary.size, const Size(300, 38));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family dark=$dark disabled field renders named hint safely', (
      tester,
    ) async {
      final theme = raftTheme(family, dark: dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Channel name',
                hintText: 'Disabled field',
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Disabled field'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      final tokens = theme.extension<RaftTokens>()!;
      final style = WidgetStateProperty.resolveAs<TextStyle>(
        theme.inputDecorationTheme.hintStyle!,
        {WidgetState.disabled},
      );
      expect(
        style.color,
        family == RaftFamily.brutal
            ? tokens.colors['foreground-placeholder']
            : tokens.colors['foreground-disabled'],
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
