import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('packages/raft_ui/SpaceGrotesk')..addFont(
          rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
        ))
        .load();
  });

  testWidgets('phone permission table shows the complete access value', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RaftAppPermissionsTable(
              rows: const [
                RaftAppPermissionRow(
                  id: 'reminder',
                  label: 'Agent reminders',
                  summary: 'Write due reminders (official apps only)',
                  selected: false,
                  accessLabel: 'Agent reminders access',
                  writeAccess: true,
                ),
              ],
              onChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    final summary = find.text('Write due reminders (official apps only)');
    expect(tester.widget<Text>(summary).style?.fontSize, 13);
    expect(
      find.ancestor(of: summary, matching: find.byType(RaftCard)),
      findsOneWidget,
    );
    final access = find.text('No access');
    final paragraph = tester.renderObject(access) as RenderParagraph;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '${paragraph.size.width}px for ${paragraph.text.style}',
    );
    final cells = find.byWidgetPredicate(
      (widget) =>
          widget is RaftRecipeBox &&
          widget.style.classes.contains('wrap-anywhere'),
    );
    expect(cells, findsNWidgets(2));
    expect(
      tester
          .widgetList<RaftRecipeBox>(cells)
          .map((cell) => cell.style.length('border-bottom-width')),
      everyElement(0),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
