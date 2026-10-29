import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (raftThemePackId, false),
    (raftThemePackId, true),
    (brutalThemePackId, false),
    (elegantThemePackId, false),
    (elegantThemePackId, true),
  ], look: (v) => raftLookOf(v.$1))) {
    testWidgets('finder field, list and rows render in $family/$dark', (
      t,
    ) async {
      final controller = TextEditingController(text: 'de');
      final focus = FocusNode();
      addTearDown(() {
        controller.dispose();
        focus.dispose();
      });
      var opened = 0, hovered = -1, outside = 0;
      t.view.physicalSize = const Size(240, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(family), dark: dark),
          home: Material(
            child: Column(
              children: [
                RaftConversationFinderField(
                  controller: controller,
                  focusNode: focus,
                  hint: 'Find a conversation…',
                  onKeyEvent: (_, _) => KeyEventResult.ignored,
                  onTapOutside: () => outside++,
                ),
                RaftConversationFinderPanel(
                  children: [
                    for (final (i, label) in [
                      'design',
                      'a-very-long-name-' * 4,
                    ].indexed)
                      RaftConversationFinderRow(
                        leading: const RaftIcon(RaftGlyph.hash, size: 16),
                        label: label,
                        sublabel: i == 0 ? 'Design work' : null,
                        active: i == 0,
                        onPressed: () => opened++,
                        onHover: () => hovered = i,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull);
      expect(find.text('de'), findsOneWidget);
      expect(find.text('design'), findsOneWidget);
      expect(find.text('Design work'), findsOneWidget);
      // The field is the 36px control inside its inset.
      expect(
        t.getSize(find.byType(RaftConversationFinderField)).height,
        36 +
            RaftConversationFinderMetrics.fieldInset.top +
            RaftConversationFinderMetrics.fieldInset.bottom,
      );
      // The active row is announced as selected; a press opens the row.
      expect(
        t.getSemantics(find.text('design')),
        matchesSemantics(
          label: 'design, Design work',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasEnabledState: false,
          isFocusable: false,
        ),
      );
      await t.tap(find.text('design'));
      expect(opened, 1);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(t.getCenter(find.textContaining('a-very-long')));
      expect(hovered, 1);
      // The panel never grows past its maximum height.
      expect(
        t.getSize(find.byType(RaftConversationFinderPanel)).height,
        lessThanOrEqualTo(RaftConversationFinderMetrics.panelMaxHeight(600)),
      );
      // A press outside a focused field is reported to the host.
      await t.tap(find.byType(TextField));
      await t.pump();
      await t.tapAt(const Offset(200, 560));
      expect(outside, 1);
    });
  }

  testWidgets('an empty list says so', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Material(
          child: RaftConversationFinderPanel(
            children: [],
            emptyLabel: 'No matches',
          ),
        ),
      ),
    );
    expect(find.text('No matches'), findsOneWidget);
  });

  test('the list is at most 22rem or 60% of the window tall', () {
    expect(RaftConversationFinderMetrics.panelMaxHeight(2000), 352);
    expect(RaftConversationFinderMetrics.panelMaxHeight(500), 300);
  });
}
