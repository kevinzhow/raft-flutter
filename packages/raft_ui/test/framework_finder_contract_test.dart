import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// db5e399f SidebarConversationFinder: text-subhead=15/20; the 1.5px CSS
// border resolves to 1px at DPR1. Frozen packs retain 14/20 and 1.5px.
void main() {
  for (final pack in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets('$pack/$dark finder follows its mounted contract', (t) async {
        final controller = TextEditingController(text: 'design');
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(pack), dark: dark),
            home: Material(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 240,
                  child: RaftConversationFinderField(
                    controller: controller,
                    focusNode: focus,
                    hint: 'Find a conversation…',
                    onKeyEvent: (_, _) => KeyEventResult.ignored,
                    onTapOutside: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final field = find.byType(TextField);
        final style = t.widget<TextField>(field).style!;
        expect([
          style.fontSize,
          style.fontSize! * style.height!,
          t.getTopLeft(field).dx,
        ], pack == raftThemePackId ? [15, 20, 43] : [14, 20, 43.5]);
        expect(t.getSize(find.byType(RaftConversationFinderField)).height, 54);
        await t.enterText(field, 'engineering');
        expect(controller.text, 'engineering');
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
    }
  }

  testWidgets('finder grows to contain its editable line at 2x text', (
    t,
  ) async {
    final controller = TextEditingController(text: '中文 descender gj');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 240,
                child: RaftConversationFinderField(
                  controller: controller,
                  focusNode: focus,
                  hint: 'Find',
                  onKeyEvent: (_, _) => KeyEventResult.ignored,
                  onTapOutside: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      t.getSize(find.byType(EditableText)).height,
      greaterThanOrEqualTo(40),
    );
    expect(
      t.getSize(find.byType(RaftConversationFinderField)).height,
      greaterThan(54),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
