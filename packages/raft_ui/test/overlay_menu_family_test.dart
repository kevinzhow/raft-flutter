// WP-DS2 menu group: the overlay family follows raft-ui 0.95.3 as Web v1.24
// uses it (SelectionPopover search row, first menu icon 16, dropdown
// separator, hover card width, tooltip recipe, popover body padding).
import 'dart:ui' show SemanticsRole;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/focus_visible.dart';

const _sizes = <(String, Size, TargetPlatform)>[
  ('856x944 Android', Size(856, 944), TargetPlatform.android),
  ('944x856 Android', Size(944, 856), TargetPlatform.android),
  ('390x844 Linux', Size(390, 844), TargetPlatform.linux),
];
const _wide = Size(1024, 800);

Widget _host(
  Widget child, {
  bool dark = false,
  TargetPlatform platform = TargetPlatform.linux,
}) => MaterialApp(
  theme: raftTheme(dark: dark).copyWith(platform: platform),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

(TextEditingController, FocusNode) _search(WidgetTester t) {
  final c = TextEditingController(), f = FocusNode();
  addTearDown(c.dispose);
  addTearDown(f.dispose);
  return (c, f);
}

void _view(WidgetTester t, Size size) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

RaftTokens _tokens(WidgetTester t, Finder f) =>
    RaftTokens.of(t.element(f.first));

/// The search row's recipe box: the nearest ancestor of the input as wide as
/// the popover.
RaftRecipeBox _searchRow(WidgetTester t, double width) {
  final boxes = find.ancestor(
    of: find.byType(EditableText),
    matching: find.byType(RaftRecipeBox),
  );
  for (final e in boxes.evaluate()) {
    if (t.getSize(find.byElementPredicate((x) => x == e)).width == width) {
      return e.widget as RaftRecipeBox;
    }
  }
  throw StateError('no search row');
}

Finder _searchRowFinder(WidgetTester t, double width) {
  final boxes = find.ancestor(
    of: find.byType(EditableText),
    matching: find.byType(RaftRecipeBox),
  );
  for (final e in boxes.evaluate()) {
    final f = find.byElementPredicate((x) => x == e);
    if (t.getSize(f).width == width) return f;
  }
  throw StateError('no search row');
}

Widget _selection(
  TextEditingController c,
  FocusNode f, {
  TargetPlatform platform = TargetPlatform.linux,
}) => _host(
  platform: platform,
  RaftSelectionPopover(
    title: 'Channels',
    width: 260,
    searchController: c,
    searchFocusNode: f,
    onClear: () {},
    options: [
      RaftSelectionOption(label: 'Design', checked: false, onTap: () {}),
    ],
  ),
);

void main() {
  tearDown(() => RaftFocusVisible.shared.keyboard = true);

  group('SelectionPopover search row (MIR:UI-1455)', () {
    testWidgets('34 with a mouse from 768', (t) async {
      _view(t, _wide);
      final (c, f) = _search(t);
      await t.pumpWidget(_selection(c, f));
      expect(t.getSize(_searchRowFinder(t, 260)).height, 34);
    });
    for (final (name, size, platform) in _sizes) {
      testWidgets('40 by touch / narrow at $name', (t) async {
        _view(t, size);
        final (c, f) = _search(t);
        await t.pumpWidget(_selection(c, f, platform: platform));
        expect(t.getSize(_searchRowFinder(t, 260)).height, 40);
      });
    }
    testWidgets('the focus ring shows on keyboard focus only', (t) async {
      _view(t, _wide);
      final (c, f) = _search(t);
      await t.pumpWidget(_selection(c, f));
      expect(_searchRow(t, 260).style['box-shadow'], isNull);
      f.requestFocus();
      await t.pump();
      expect(_searchRow(t, 260).style['box-shadow'], isNotNull);
      // A pointer press moves the modality: the ring goes.
      RaftFocusVisible.shared.update(false);
      await t.pump();
      expect(_searchRow(t, 260).style['box-shadow'], isNull);
      RaftFocusVisible.shared.update(true);
      await t.pump();
      expect(_searchRow(t, 260).style['box-shadow'], isNotNull);
    });
  });

  group('first menu icon is 16 (MIR:UI-2047)', () {
    testWidgets('raftMessageMenuIcon and the message menu box', (t) async {
      await t.pumpWidget(
        _host(
          RaftMessageContextMenu(
            sections: [
              [
                RaftMessageContextMenuItem(
                  label: 'Copy',
                  icon: Builder(
                    builder: (_) => raftMessageMenuIcon(RaftGlyph.copy),
                  ),
                  onPressed: () {},
                ),
              ],
            ],
          ),
        ),
      );
      expect(t.widget<RaftIcon>(find.byType(RaftIcon)).size, 16);
      expect(t.getSize(find.byType(RaftIcon)), const Size(16, 16));
    });
    testWidgets('RaftMenuItem dropdown', (t) async {
      await t.pumpWidget(
        _host(
          Semantics(
            role: SemanticsRole.menu,
            child: const SizedBox(
              width: 240,
              child: RaftMenuItem(label: 'Copy', glyph: RaftGlyph.copy),
            ),
          ),
        ),
      );
      expect(t.widget<RaftIcon>(find.byType(RaftIcon)).size, 16);
    });
    testWidgets('RaftContextMenuContent item', (t) async {
      await t.pumpWidget(
        _host(
          RaftContextMenuContent(
            entries: [
              RaftContextMenuContentItem(
                label: 'Copy',
                glyph: RaftGlyph.copy,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(t.widget<RaftIcon>(find.byType(RaftIcon)).size, 16);
    });
    testWidgets('inline badge menu check', (t) async {
      await t.pumpWidget(
        _host(
          RaftInlineBadgeEditor(
            label: 'Status',
            selectedId: 'todo',
            options: const [
              RaftInlineBadgeOption(id: 'todo', label: 'To do'),
              RaftInlineBadgeOption(id: 'done', label: 'Done'),
            ],
            onSelect: (_) {},
            background: Colors.yellow,
            foreground: Colors.black,
          ),
        ),
      );
      await t.tap(find.text('Status'));
      await t.pumpAndSettle();
      final check = find.byWidgetPredicate(
        (w) => w is RaftIcon && w.glyph == RaftGlyph.check,
      );
      expect(check, findsWidgets);
      expect(t.widget<RaftIcon>(check.first).size, 16);
    });
  });

  testWidgets('dropdown separator is 1px and bleeds through the inset', (
    t,
  ) async {
    _view(t, _wide);
    await t.pumpWidget(
      _host(
        RaftDropdownMenu(
          label: 'Actions',
          defaultOpen: true,
          entries: [
            RaftMenuEntry(label: 'Copy', onPressed: () {}),
            const RaftMenuEntry.separator(),
            RaftMenuEntry(label: 'Delete', onPressed: () {}),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    final sep = find.byKey(const ValueKey('raft-menu-separator'));
    expect(sep, findsOneWidget);
    final size = t.getSize(sep);
    expect(size.height, 1);
    expect(sep, paints..rect(rect: Rect.fromLTRB(-4, 0, size.width + 4, 1)));
  });

  group('tooltip follows the generated recipe', () {
    Future<void> show(
      WidgetTester t, {
      bool dark = false,
      TargetPlatform p = TargetPlatform.linux,
    }) async {
      await t.pumpWidget(
        _host(
          dark: dark,
          platform: p,
          RaftTooltipProvider(
            delay: const Duration(milliseconds: 600),
            child: const Padding(
              padding: EdgeInsets.all(80),
              child: RaftTooltip(
                message: 'Help text',
                child: SizedBox(width: 80, height: 32, child: Text('A')),
              ),
            ),
          ),
        ),
      );
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(t.getCenter(find.text('A')));
      await t.pump(const Duration(milliseconds: 600));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
    }

    testWidgets('12px with a mouse from 768, no tracking', (t) async {
      _view(t, _wide);
      await show(t);
      final style = t.widget<Text>(find.text('Help text')).style!;
      expect(style.fontSize, 12);
      expect(style.letterSpacing, isNull);
    });
    for (final (name, size, platform) in _sizes) {
      testWidgets('13px by touch / narrow at $name', (t) async {
        _view(t, size);
        await show(t, p: platform);
        expect(t.widget<Text>(find.text('Help text')).style!.fontSize, 13);
      });
    }
    for (final dark in [false, true]) {
      testWidgets('colours are hud tokens ${dark ? 'dark' : 'light'}', (
        t,
      ) async {
        _view(t, _wide);
        await show(t, dark: dark);
        final tokens = _tokens(t, find.text('Help text'));
        expect(
          t.widget<Text>(find.text('Help text')).style!.color,
          tokens.colors['foreground-on-hud'],
        );
        final box = t.widget<DecoratedBox>(
          find.byKey(const ValueKey('raft-tooltip-surface')),
        );
        expect(
          (box.decoration as BoxDecoration).color,
          tokens.colors['layer-hud'],
        );
        // No inner edge: Web draws only the outer float shadow.
        final inner = find.descendant(
          of: find.byKey(const ValueKey('raft-tooltip-surface')),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.foregroundPainter != null,
          ),
        );
        expect(inner, findsNothing);
      });
    }
  });

  group('popover body padding 16/16/12', () {
    testWidgets('task backlog reason panel', (t) async {
      _view(t, _wide);
      await t.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: RaftTaskReasonPanel(
              kind: RaftTaskReasonKind.backlog,
              onSubmit: (_) async => true,
              onCancel: () {},
            ),
          ),
        ),
      );
      final panel = t.getRect(
        find.byKey(const ValueKey('task-backlog-reason')),
      );
      final input = t.getRect(find.byType(RaftTextInput));
      final confirm = t.getRect(
        find.byKey(const ValueKey('task-backlog-reason-confirm')),
      );
      expect(input.left - panel.left, 16);
      expect(input.top - panel.top, 16);
      expect(panel.right - input.right, 16);
      expect(panel.bottom - confirm.bottom, 16);
    });

    testWidgets('profile preview header', (t) async {
      _view(t, _wide);
      Widget card({String? description}) => _host(
        SizedBox(
          width: 300,
          child: RaftProfilePreviewCard(
            avatar: const SizedBox(key: ValueKey('av'), width: 48, height: 48),
            name: 'Ada',
            subtitle: '@ada',
            avatarTopInset: 0,
            description: description,
          ),
        ),
      );
      await t.pumpWidget(card());
      var root = t.getRect(find.byKey(const ValueKey('profile-preview-card')));
      var av = t.getRect(find.byKey(const ValueKey('av')));
      expect(av.left - root.left, 16);
      expect(av.top - root.top, 16);
      // Last section: pb-4.
      expect(root.height, 16 + 48 + 16);
      await t.pumpWidget(card(description: 'About'));
      root = t.getRect(find.byKey(const ValueKey('profile-preview-card')));
      final desc = t.getRect(
        find.byKey(const ValueKey('profile-preview-description')),
      );
      // Not last: pb-3.
      expect(desc.top - root.top, 16 + 48 + 12);
    });
  });
}
