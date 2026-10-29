import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  testWidgets(
    'dark 0.7.1 field paints a layer-card fill inside an ink border and survives border tween',
    (tester) async {
      final theme = raftTheme(dark: true);
      final normal =
          theme.inputDecorationTheme.enabledBorder! as RaftFieldBorder;
      final focused =
          theme.inputDecorationTheme.focusedBorder! as RaftFieldBorder;
      final mid = ShapeBorder.lerp(normal, focused, .5)! as RaftFieldBorder;
      // 0.7.1 fields have no inset shadows (controls never cast shadows): the border is a plain 1.5px outline.
      expect(mid.insets, isNull);
      expect(mid.borderSide.width, 1.5);
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
      final ui = RaftUiColors.of(true);
      int px(int x, int y) => (y * 300 + x) * 4;
      Color at(int x, int y) => Color.fromARGB(
        data!.getUint8(px(x, y) + 3),
        data.getUint8(px(x, y)),
        data.getUint8(px(x, y) + 1),
        data.getUint8(px(x, y) + 2),
      );
      // The fill is `layer-card`, the outline `line-strong` (the 1.5px border covers pixels 0 and 1).
      expect(at(150, 22), ui.layerCard);
      expect(at(150, 0), ui.lineStrong);
      expect(at(150, 1).a, 1);
      expect(boundary.size, const Size(300, 44));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} disabled field renders named hint safely',
      (tester) async {
        final theme = raftTheme(dark: dark);
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
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        final tokens = theme.extension<RaftTokens>()!;
        final style = WidgetStateProperty.resolveAs<TextStyle>(
          theme.inputDecorationTheme.hintStyle!,
          {WidgetState.disabled},
        );
        expect(style.color, tokens.colors['foreground-disabled']);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
