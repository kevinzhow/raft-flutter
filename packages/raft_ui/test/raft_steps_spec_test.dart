import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.0 `Steps`: 20px sticker-cornered markers (outline ahead, brand sticker current, solid ink with a check
// finished, orange sticker failed) joined by 16px seam connectors; finished steps carry the check, not a number.
Widget _app(bool dark, Widget child, {double width = 900}) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 600)),
    child: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

const _steps = [
  RaftStep(title: 'Connect'),
  RaftStep(title: 'Channels'),
  RaftStep(title: 'Health'),
];

// The same paint assertions support the old frozen painter and the published
// recipe painter. This only changes how the actual rendered marker is found.
Finder _markers() => find.byWidgetPredicate(
  (w) =>
      w is RaftCssBox ||
      w is RaftRecipeBox && w.style.width == 20 && w.style.height == 20,
);
Color? _fill(Widget w) => switch (w) {
  RaftCssBox() => w.fill,
  RaftRecipeBox() => w.style.backgroundColor?.resolve(w.tokens),
  _ => null,
};
Color? _border(Widget w) => switch (w) {
  RaftCssBox() => w.borderColor,
  RaftRecipeBox() => w.style.borderColor?.resolve(w.tokens),
  _ => null,
};
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    testWidgets('$mode the markers read finish, process and wait', (t) async {
      addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
      await t.pumpWidget(
        _app(dark, const RaftSteps(steps: _steps, current: 1)),
      );
      final boxes = t.widgetList<Widget>(_markers()).toList();
      expect(boxes.map(_fill), [ui.foreground, ui.brand, ui.layerCard]);
      expect(boxes.map(_border), [ui.foreground, ui.stickerInk, ui.lineSeam]);
      expect(t.getSize(_markers().first), const Size(20, 20));
      // The finished step shows the check, the others their number.
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets(
      '$mode an error status makes the current step the warning sticker',
      (t) async {
        addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
        await t.pumpWidget(
          _app(
            dark,
            const RaftSteps(
              steps: _steps,
              current: 0,
              status: RaftStepStatus.error,
            ),
          ),
        );
        final first = t.widget<Widget>(_markers().first);
        expect(_fill(first), ui.warning);
      },
    );

    testWidgets(
      '$mode a wide row puts connectors between steps, not after the last',
      (t) async {
        addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
        await t.pumpWidget(
          _app(dark, const RaftSteps(steps: _steps, current: 0)),
        );
        final a = t.getTopLeft(find.text('Connect'));
        final b = t.getTopLeft(find.text('Channels'));
        // title (~56) + 8 + 16 + 8 between the two titles' markers.
        expect(b.dx - a.dx, greaterThan(20 + 8 + 16 + 8));
        expect(t.getTopLeft(find.text('Health')).dy, a.dy);
      },
    );

    testWidgets('$mode a narrow screen stacks the title under the marker', (
      t,
    ) async {
      addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
      await t.pumpWidget(
        _app(dark, const RaftSteps(steps: _steps, current: 0), width: 360),
      );
      final marker = t.getTopLeft(_markers().first);
      expect(
        t.getTopLeft(find.text('Connect')).dy,
        greaterThan(marker.dy + 20),
      );
    });
  }
}
