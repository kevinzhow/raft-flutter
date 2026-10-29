import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.7.0 `SelectTrigger` (Button outline md merged with the `select` recipe `trigger`): 44px, 14px start / 12px
// end padding, 15px semibold value (hint-coloured medium placeholder), 16px hint chevron.
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    final ui = RaftUiColors.of(dark);

    Future<void> pump(WidgetTester t, String? value) => t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: RaftSelectField<String>(
                value: value,
                placeholder: 'Pick one',
                items: const [
                  RaftSelectItem(value: 'a', label: 'Alpha'),
                  RaftSelectItem(value: 'b', label: 'Beta', enabled: false),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('$mode the trigger is 44px with the semibold value', (t) async {
      await pump(t, 'a');
      expect(t.getSize(find.byType(RaftSelectField<String>)).height, 44);
      final text = t.widget<Text>(find.text('Alpha'));
      final style = DefaultTextStyle.of(t.element(find.text('Alpha'))).style;
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, ui.foreground);
      expect(text.data, 'Alpha');
    });

    testWidgets('$mode the placeholder reads foreground-hint', (t) async {
      await pump(t, null);
      final style = DefaultTextStyle.of(t.element(find.text('Pick one'))).style;
      expect(style.color, ui.foregroundHint);
      expect(style.fontWeight, FontWeight.w500);
    });

    testWidgets('$mode the chevron is the 16px hint icon', (t) async {
      await pump(t, 'a');
      final icon = t.widget<RaftIcon>(find.byType(RaftIcon));
      expect(icon.size, 16);
      expect(icon.color, ui.foregroundHint);
    });
  }
}
