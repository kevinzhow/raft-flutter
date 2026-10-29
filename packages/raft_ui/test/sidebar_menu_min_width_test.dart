import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Web db5e399f Sidebar.tsx mounts w-60 ContextMenuPopup for both the row
// menu and Move to section submenu. The published raft-ui 0.7.0 content
// independently declares min-w-60; a narrower legacy width cannot override it.
Finder _menu(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.role == SemanticsRole.menu &&
      widget.properties.label == label,
);

void _disposeMenu(WidgetTester tester) => addTearDown(() async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
});

Widget _app(
  String pack,
  bool dark, {
  double width = 192,
  bool sidebar = false,
  bool heading = false,
}) {
  final entries = [
    if (heading) const RaftSidebarMenuHeading('Section label'),
    const RaftSidebarMenuItem(label: 'Move to section', submenu: true),
  ];
  final submenuEntries = [
    RaftSidebarMenuItem(label: 'Project section', onPressed: () {}),
  ];
  return MaterialApp(
    theme: raftTheme(pack: packForThemeId(pack), dark: dark),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: sidebar
            ? RaftSidebarContextMenu.sidebar(
                label: 'Row options',
                legacyWidth: width,
                submenuLabel: 'Move target',
                entries: entries,
                submenuEntries: submenuEntries,
              )
            : RaftSidebarContextMenu(
                label: 'Row options',
                width: width,
                submenuLabel: 'Move target',
                entries: entries,
                submenuEntries: submenuEntries,
              ),
      ),
    ),
  );
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets('$dark source section labels use the published caption box', (
      tester,
    ) async {
      _disposeMenu(tester);
      await tester.pumpWidget(
        _app(raftThemePackId, dark, sidebar: true, heading: true),
      );
      await tester.pumpAndSettle();
      // Published contextMenu.label: text-caption (12/16), px-2.5, pt-2/pb-1.
      final text = find.text('Section label');
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect((paragraph.text as TextSpan).style!.fontSize, 12);
      expect(tester.getSize(text).height, 16);
      expect(
        tester.getTopLeft(text).dx - tester.getTopLeft(_menu('Row options')).dx,
        16,
        reason: '6px popup padding plus 10px generated label padding',
      );
    });

    testWidgets('$dark primary popup keeps the source minimum width', (
      tester,
    ) async {
      _disposeMenu(tester);
      for (final (requested, expected) in [
        (96.0, 240.0),
        (192.0, 240.0),
        (320.0, 320.0),
      ]) {
        await tester.pumpWidget(_app(raftThemePackId, dark, width: requested));
        await tester.pumpAndSettle();
        expect(tester.getSize(_menu('Row options')).width, expected);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('$dark Move to section popup keeps the same source minimum', (
      tester,
    ) async {
      _disposeMenu(tester);
      await tester.pumpWidget(_app(raftThemePackId, dark));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to section'));
      await tester.pumpAndSettle();
      expect(find.text('Project section'), findsOneWidget);
      expect(tester.getSize(_menu('Row options')).width, 240);
      expect(tester.getSize(_menu('Move target')).width, 240);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (pack, dark) in raftThemeMatrix(
    [
      for (final pack in [elegantThemePackId, brutalThemePackId])
        for (final dark in [false, true]) (pack, dark),
    ],
    look: (variant) => raftLookOf(variant.$1),
    dark: (variant) => variant.$2,
  )) {
    testWidgets('$pack/$dark frozen popup widths remain unchanged', (
      tester,
    ) async {
      _disposeMenu(tester);
      await tester.pumpWidget(_app(pack, dark));
      await tester.pumpAndSettle();
      expect(tester.getSize(_menu('Row options')).width, 192);
      await tester.tap(find.text('Move to section'));
      await tester.pumpAndSettle();
      expect(tester.getSize(_menu('Move target')).width, 224);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$pack/$dark source sidebar mount preserves frozen widths', (
      tester,
    ) async {
      _disposeMenu(tester);
      await tester.pumpWidget(
        _app(pack, dark, width: 256, sidebar: true, heading: true),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(_menu('Row options')).width, 256);
      final label = find.text('Section label');
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect((paragraph.text as TextSpan).style!.fontSize, 10);
      expect(tester.getSize(label).height, 15);
      await tester.tap(find.text('Move to section'));
      await tester.pumpAndSettle();
      expect(tester.getSize(_menu('Move target')).width, 224);
      expect(tester.takeException(), isNull);
    });
  }
}
