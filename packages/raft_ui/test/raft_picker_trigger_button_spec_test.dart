import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.0 `PickerTriggerButton`: 32px, `rounded-control`, footnote semibold muted text, a `line-seam` inset ring at
// rest, `info-soft` fill with foreground text once a value is chosen, 16px indicator slot with a hint chevron.
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    Future<void> pump(WidgetTester t, {bool selected = false}) => t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RaftPickerTriggerButton(
              label: 'Channel',
              glyph: RaftGlyph.hash,
              selected: selected,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    RaftRecipeBox box(WidgetTester t) =>
        t.widget<RaftRecipeBox>(find.byType(RaftRecipeBox).first);

    testWidgets('$mode the trigger is 32px with the footnote label', (t) async {
      await pump(t);
      expect(t.getSize(find.byType(RaftPickerTriggerButton)).height, 32);
      final style = DefaultTextStyle.of(t.element(find.text('Channel'))).style;
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, ui.foregroundMuted);
    });

    testWidgets('$mode a chosen value fills the trigger with info-soft', (
      t,
    ) async {
      await pump(t);
      final rest = box(t);
      expect(rest.style.backgroundColor?.resolve(rest.tokens)?.a ?? 0, 0);
      await pump(t, selected: true);
      final b = box(t);
      expect(b.style.backgroundColor?.resolve(b.tokens), ui['info-soft']);
      final style = DefaultTextStyle.of(t.element(find.text('Channel'))).style;
      expect(style.color, ui.foreground);
    });

    testWidgets('$mode the indicator is a 16px slot with the hint chevron', (
      t,
    ) async {
      await pump(t);
      final icons = t.widgetList<RaftIcon>(find.byType(RaftIcon)).toList();
      expect(icons.last.color, ui.foregroundHint);
      expect(icons.last.size, 14);
    });
  }
}
