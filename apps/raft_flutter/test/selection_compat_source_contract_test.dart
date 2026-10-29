import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/sidebar_sort_menu.dart';
import 'package:raft_flutter/features/task_selection_filter.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Fixed source: Web db5e399f, SelectionPopover.tsx, SidebarSortMenu.tsx and
// TasksPanel.tsx. These observe public behavior and the source's used geometry;
// replacing the old Panel/Header/Search helpers with SelectionPopover is valid.
const _capture = ValueKey('selection-compat-capture');

Widget _host(Widget child, {required bool dark}) {
  final theme = raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux);
  return MaterialApp(
    theme: theme,
    builder: (context, child) => RepaintBoundary(key: _capture, child: child),
    home: Scaffold(
      body: DefaultTextStyle(
        style: TextStyle(
          fontFamily: theme.extension<RaftTokens>()!.bodyFont,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
        ),
        child: child,
      ),
    ),
  );
}

TextStyle _style(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).text.style!;

RaftUnderlineSpan? _underline(WidgetTester tester, String label) {
  final text = tester.renderObject<RenderParagraph>(find.text(label)).text;
  if (text is RaftUnderlineSpan) return text;
  RaftUnderlineSpan? found;
  text.visitChildren((span) {
    if (span is RaftUnderlineSpan) found = span;
    return found == null;
  });
  return found;
}

Future<void> _retire(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

class _FilterOwner extends StatefulWidget {
  const _FilterOwner({super.key});

  @override
  State<_FilterOwner> createState() => _FilterOwnerState();
}

class _FilterOwnerState extends State<_FilterOwner> {
  MenuController? menu;
  final selected = <String>{'agent:design'};
  var clears = 0;
  var authorized = true;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: TaskSelectionFilter(
        field: 'Assignee',
        label: 'Filter people',
        options: const {
          'agent:design': 'Design',
          'user:operations': 'Operations',
          'unassigned': 'Unassigned',
        },
        selection: selected,
        valid: () => authorized,
        onToggle: (id) => setState(() {
          if (!selected.add(id)) selected.remove(id);
        }),
        onClear: () => setState(() {
          clears++;
          selected.clear();
        }),
        onController: (controller, live) => menu = live ? controller : null,
      ),
    ),
  );
}

Future<_FilterOwnerState> _openFilter(
  WidgetTester tester, {
  required bool dark,
}) async {
  final key = GlobalKey<_FilterOwnerState>();
  await tester.pumpWidget(_host(_FilterOwner(key: key), dark: dark));
  await tester.tap(find.text('Filter people'));
  await tester.pumpAndSettle();
  expect(find.byType(EditableText), findsOneWidget);
  return key.currentState!;
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'actual Sidebar sort uses source 160px no-header selection; dark=$dark',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(900, 844);
        addTearDown(tester.view.reset);
        final client = RaftClient(
          origin: 'https://fixture.invalid',
          sessionStore: MemorySessionStore(),
        )..user = RaftRecord({'id': 'viewer'});
        final workspace = WorkspaceController(client)
          ..server = RaftRecord({'id': 'server', 'role': 'owner'});
        final anchor = GlobalKey();
        String? result;
        try {
          await tester.pumpWidget(
            _host(
              Builder(
                builder: (context) => Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      key: anchor,
                      width: 72,
                      height: 36,
                      child: RaftButton(
                        label: 'Sort',
                        onPressed: () async {
                          result = await showSidebarSortMenu(
                            context,
                            workspace,
                            anchor,
                            'recent',
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              dark: dark,
            ),
          );
          await tester.tap(find.text('Sort'));
          await tester.pumpAndSettle();
          final popup = find.byKey(const Key('sidebar-sort-popover'));
          expect(tester.getRect(popup).size, const Size(160, 132));
          expect(
            tester.getRect(popup).right,
            tester.getRect(find.byKey(anchor)).right,
          );
          expect(_style(tester, 'Manual').fontSize, 14);
          expect(_style(tester, 'Manual').fontWeight, FontWeight.w500);
          expect(_style(tester, 'Recent').fontWeight, FontWeight.w700);
          final checks = tester
              .widgetList<RaftIcon>(
                find.descendant(of: popup, matching: find.byType(RaftIcon)),
              )
              .where((icon) => icon.glyph == RaftGlyph.check);
          expect(checks.single.size, 16);
          await tester.tap(find.byKey(const Key('sidebar-sort-az')));
          await tester.pumpAndSettle();
          expect(result, 'az');
          expect(popup, findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          if (find
              .byKey(const Key('sidebar-sort-popover'))
              .evaluate()
              .isNotEmpty) {
            await _key(tester, LogicalKeyboardKey.escape);
          }
          await _retire(tester);
          workspace.dispose();
          await client.dispose();
        }
      },
    );

    testWidgets(
      'actual Tasks filter shares source title Clear and search; dark=$dark',
      (tester) async {
        _FilterOwnerState? owner;
        try {
          owner = await _openFilter(tester, dark: dark);
          expect(_style(tester, 'Assignee').fontSize, 12);
          expect(_style(tester, 'Assignee').height, 16 / 12);
          expect(_style(tester, 'Assignee').fontWeight, FontWeight.w700);
          expect(_style(tester, 'Clear').fontSize, 12);
          expect(_style(tester, 'Clear').fontWeight, FontWeight.w600);
          final underline = _underline(tester, 'Clear');
          expect(underline, isNotNull);
          expect(underline!.active, isTrue);
          expect(underline.thickness, 1.5);
          expect(underline.offset, 3);
          final input = tester.widget<EditableText>(find.byType(EditableText));
          final tokens = raftTheme(dark: dark).extension<RaftTokens>()!;
          expect(input.style.fontSize, 14);
          expect(input.style.height, 20 / 14);
          expect(input.style.fontFamily, tokens.bodyFont);
          expect(
            tester.getRect(find.byType(EditableText)).center.dy -
                tester.getRect(find.text('Assignee')).center.dy,
            // Source header: pt10 + text16 + pb4. Search: h40 with a
            // layout-reserving 1px bottom hairline, so content center49.5
            // minus title center18 is31.5 (not the border-box center32).
            31.5,
          );
          final searchIcons = tester
              .widgetList<RaftIcon>(find.byType(RaftIcon))
              .where((icon) => icon.glyph == RaftGlyph.search);
          expect(searchIcons.single.size, 16);
          await tester.enterText(find.byType(EditableText), 'des');
          await tester.pumpAndSettle();
          expect(find.text('Design'), findsOneWidget);
          expect(find.text('Operations'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          owner?.menu?.close();
          await _retire(tester);
        }
      },
    );

    testWidgets(
      'actual Tasks search can Shift-Tab to Clear and activate it; dark=$dark',
      (tester) async {
        _FilterOwnerState? owner;
        try {
          owner = await _openFilter(tester, dark: dark);
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .focusNode
                .hasFocus,
            isTrue,
          );
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await _key(tester, LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await _key(tester, LogicalKeyboardKey.enter);
          expect(owner.clears, 1);
          expect(owner.selected, isEmpty);
          expect(find.text('Clear'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          owner?.menu?.close();
          await _retire(tester);
        }
      },
    );
  }
}
