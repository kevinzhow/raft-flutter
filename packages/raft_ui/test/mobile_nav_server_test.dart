import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/mobile_nav_server_previews.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// raft-ui 0.95.3 mobile-nav-server: the server tab cell of the bottom bar and
/// its popover (list, footer group, destinations).
const _popover = ValueKey('server-popover');
const _items = [
  RaftMobileNavItem(id: 'chat', label: 'Home', glyph: RaftGlyph.home),
  RaftMobileNavItem(id: 'tasks', label: 'Tasks', glyph: RaftGlyph.squareCheck),
  RaftMobileNavItem(id: 'members', label: 'Members', glyph: RaftGlyph.users),
  RaftMobileNavItem(id: 'more', label: 'Settings', glyph: RaftGlyph.settings),
];

class _Fixture {
  _Fixture() {
    addTearDown(focus.dispose);
  }
  final picked = <int>[];
  final reordered = <(int, int)>[];
  final opened = <bool>[];
  final focus = FocusNode(debugLabel: 'server tab');
  VoidCallback? close;
}

Widget _content(
  _Fixture fx, {
  int servers = 3,
  int current = 1,
  int destinations = 3,
  int footer = 1,
  bool reorder = false,
  bool attentionOnFirstDestination = false,
}) => Builder(
  builder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RaftMobileNavServerPopoverList(
        onReorder: reorder ? (a, b) => fx.reordered.add((a, b)) : null,
        children: [
          for (var i = 0; i < servers; i++)
            RaftMobileNavServerPopoverRow(
              key: ValueKey('server-$i'),
              leading: const SizedBox.square(dimension: 20),
              label: 'Server $i',
              description: '/server-$i',
              current: i == current,
              onPressed: () => fx.picked.add(i),
            ),
        ],
      ),
      const RaftMobileNavServerPopoverSeparator(),
      RaftMobileNavServerPopoverGroup(
        children: [
          for (var i = 0; i < footer; i++)
            RaftMobileNavServerPopoverRow(
              leading: const RaftIcon(RaftGlyph.plus),
              label: 'Footer $i',
              onPressed: fx.close,
            ),
        ],
      ),
      const RaftMobileNavServerPopoverSeparator(),
      RaftMobileNavServerPopoverDestinations(
        semanticLabel: 'Raft Studio',
        children: [
          for (var i = 0; i < destinations; i++)
            RaftMobileNavServerPopoverDestination(
              key: ValueKey('dest-$i'),
              glyph: RaftGlyph.settings,
              label: 'Page $i',
              attention: attentionOnFirstDestination && i == 0,
              onPressed: () {},
            ),
        ],
      ),
    ],
  ),
);

Widget _app(
  _Fixture fx, {
  bool dark = false,
  TargetPlatform platform = TargetPlatform.android,
  bool attention = false,
  double textScale = 1,
  bool trailing = true,
  Widget Function(_Fixture)? content,
}) => MaterialApp(
  theme: raftTheme(dark: dark).copyWith(platform: platform),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: Column(
      children: [
        const Expanded(child: SizedBox.expand()),
        RaftMobileNav(
          items: _items,
          selectedId: 'chat',
          onSelected: (_) {},
          trailing: trailing
              ? RaftMobileNavServerTab(
                  label: 'Raft Studio',
                  semanticLabel: 'Raft Studio, other servers unread',
                  attention: attention,
                  focusNode: fx.focus,
                  popoverKey: _popover,
                  onOpenChanged: fx.opened.add,
                  avatar: Container(
                    key: const ValueKey('avatar'),
                    color: const Color(0xFFCC3333),
                  ),
                  contentBuilder: (context, close) {
                    fx.close = close;
                    return (content ?? (f) => _content(f))(fx);
                  },
                )
              : null,
        ),
      ],
    ),
  ),
);

Future<void> _size(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Finder get _tab => find.byType(RaftMobileNavServerTab);
Finder get _bar => find.byKey(const ValueKey('mobile-nav-source-docked'));
Finder get _pop => find.byKey(_popover);

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('trailing cell', () {
    testWidgets('is one more equal-width cell; no trailing leaves the bar', (
      t,
    ) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(_app(fx, trailing: false));
      final plain = [
        for (final id in ['chat', 'tasks', 'members', 'more'])
          t.getRect(find.byKey(ValueKey('mobile-nav-sticker-$id'))),
      ];
      final barPlain = t.getSize(_bar);
      expect(plain[1].left - plain[0].left, closeTo((390 - 16) / 4, .01));
      await t.pumpWidget(_app(fx));
      expect(t.getSize(_bar), barPlain);
      final withTab = [
        for (final id in ['chat', 'tasks', 'members', 'more'])
          t.getRect(find.byKey(ValueKey('mobile-nav-sticker-$id'))),
      ];
      const cell = (390 - 16) / 5;
      expect(withTab[1].left - withTab[0].left, closeTo(cell, .01));
      final tab = t.getRect(_tab);
      expect(tab.width, closeTo(cell, .01));
      expect(tab.left, closeTo(8 + 4 * cell, .01));
      // The avatar is 22px, centred over the label like a glyph.
      expect(
        t.getSize(find.byKey(const ValueKey('avatar'))),
        const Size(22, 22),
      );
      expect(find.text('Raft Studio'), findsOneWidget);
    });

    testWidgets(
      'also joins the floating capsule as one more cell',
      skip: raftLookSkip(raftLookElegant),
      (t) async {
        await _size(t, const Size(390, 844));
        final fx = _Fixture();
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: builtInElegantTheme),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: RaftMobileNav(
                  items: _items,
                  selectedId: 'chat',
                  onSelected: (_) {},
                  trailing: RaftMobileNavServerTab(
                    label: 'Raft Studio',
                    avatar: const SizedBox.expand(),
                    contentBuilder: (context, close) => _content(fx),
                  ),
                ),
              ),
            ),
          ),
        );
        final capsule = t.getRect(
          find.byKey(const ValueKey('mobile-nav-source-capsule')),
        );
        final tab = t.getRect(_tab);
        expect(capsule.width, 8 + 5 * 44 + 4 * 8);
        expect(capsule.contains(tab.center), isTrue);
        expect(
          tab.left,
          greaterThan(t.getRect(find.byType(RaftControl).last).left - 1),
        );
      },
    );
  });

  for (final (size, platform) in [
    (const Size(856, 944), TargetPlatform.android),
    (const Size(390, 844), TargetPlatform.linux),
  ]) {
    group('open and close at ${size.width.toInt()} ${platform.name}', () {
      testWidgets('a press opens, a second press closes', (t) async {
        await _size(t, size);
        final fx = _Fixture();
        await t.pumpWidget(_app(fx, platform: platform));
        expect(_pop, findsNothing);
        await t.tap(_tab);
        await _settle(t);
        expect(_pop, findsOneWidget);
        expect(fx.opened, [true]);
        await t.tap(_tab);
        await _settle(t);
        expect(_pop, findsNothing);
        expect(fx.opened, [true, false]);
      });

      testWidgets('Escape, an outside tap and Android back close it', (
        t,
      ) async {
        await _size(t, size);
        final fx = _Fixture();
        await t.pumpWidget(_app(fx, platform: platform));
        await t.tap(_tab);
        await _settle(t);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await _settle(t);
        expect(_pop, findsNothing, reason: 'Escape');
        await t.tap(_tab);
        await _settle(t);
        await t.tapAt(const Offset(20, 20));
        await _settle(t);
        expect(_pop, findsNothing, reason: 'outside tap');
        await t.tap(_tab);
        await _settle(t);
        expect(await t.binding.handlePopRoute(), isTrue);
        await _settle(t);
        expect(_pop, findsNothing, reason: 'Android back');
        await t.tap(_tab);
        await _settle(t);
        fx.close!();
        await _settle(t);
        expect(_pop, findsNothing, reason: 'close()');
      });
    });
  }

  testWidgets('a 500ms hold opens it and the lift never closes it', (t) async {
    await _size(t, const Size(390, 844));
    final fx = _Fixture();
    await t.pumpWidget(_app(fx));
    final g = await t.startGesture(t.getCenter(_tab));
    await t.pump(const Duration(milliseconds: 450));
    expect(_pop, findsNothing);
    await t.pump(const Duration(milliseconds: 100));
    await t.pump();
    expect(_pop, findsOneWidget);
    await g.up();
    await _settle(t);
    expect(_pop, findsOneWidget, reason: 'the lift after a hold keeps it open');
    // The next press is an ordinary press again: it closes.
    await t.tap(_tab);
    await _settle(t);
    expect(_pop, findsNothing);
    // A hold on the open popover's tab does not close it on the lift either.
    await t.tap(_tab);
    await _settle(t);
    final h = await t.startGesture(t.getCenter(_tab));
    await t.pump(const Duration(milliseconds: 600));
    await h.up();
    await _settle(t);
    expect(_pop, findsOneWidget);
  });

  testWidgets('a move over 10px cancels the hold', (t) async {
    await _size(t, const Size(390, 844));
    final fx = _Fixture();
    await t.pumpWidget(_app(fx));
    final g = await t.startGesture(t.getCenter(_tab));
    await g.moveBy(const Offset(0, -14));
    await t.pump(const Duration(milliseconds: 700));
    expect(_pop, findsNothing);
    await g.up();
  });

  group('focus', () {
    testWidgets('keyboard open focuses the current row; close returns it', (
      t,
    ) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(_app(fx, platform: TargetPlatform.linux));
      fx.focus.requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(t);
      expect(_pop, findsOneWidget);
      final row = FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<RaftMobileNavServerPopoverRow>();
      expect(row?.label, 'Server 1');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(t);
      expect(fx.focus.hasPrimaryFocus, isTrue);
    });

    testWidgets('a mouse open focuses the current row too', (t) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(_app(fx, platform: TargetPlatform.linux));
      final g = await t.startGesture(
        t.getCenter(_tab),
        kind: PointerDeviceKind.mouse,
      );
      await g.up();
      await _settle(t);
      final row = FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<RaftMobileNavServerPopoverRow>();
      expect(row?.label, 'Server 1');
    });

    testWidgets('a touch open focuses the current row too (Web v1.24)', (
      t,
    ) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(_app(fx));
      await t.tap(_tab);
      await _settle(t);
      final row = FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<RaftMobileNavServerPopoverRow>();
      expect(row?.label, 'Server 1');
      await t.tap(_tab);
      await _settle(t);
      expect(fx.focus.hasPrimaryFocus, isTrue);
    });
  });

  group('geometry', () {
    testWidgets('bar width minus 16, 8px above the bar, centred', (t) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(_app(fx));
      await t.tap(_tab);
      await _settle(t);
      final bar = t.getRect(_bar), pop = t.getRect(_pop);
      expect(pop.width, closeTo(bar.width - 16, .01));
      expect(pop.left, closeTo(bar.left + 8, .01));
      expect(pop.bottom, closeTo(bar.top - 8, .01));
      // Content height: list (3 two-line rows + p-1) + footer + destinations.
      expect(pop.height, lessThan(.6 * 844));
    });

    testWidgets('at most 60% of the viewport, the list scrolls inside', (
      t,
    ) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(
        _app(fx, content: (f) => _content(f, servers: 40, current: 0)),
      );
      await t.tap(_tab);
      await _settle(t);
      final pop = t.getRect(_pop);
      expect(pop.height, closeTo(.6 * 844, .5));
      expect(
        t.getSize(find.byKey(const ValueKey('dest-0'))).height,
        greaterThan(0),
        reason: 'the destinations stay in view under a long list',
      );
      expect(
        t.getRect(find.byKey(const ValueKey('dest-0'))).bottom,
        lessThanOrEqualTo(pop.bottom),
      );
    });

    testWidgets('grows past 60% to keep one whole two-line row', (t) async {
      await _size(t, const Size(390, 520));
      final fx = _Fixture();
      await t.pumpWidget(
        _app(
          fx,
          content: (f) =>
              _content(f, servers: 40, footer: 6, destinations: 6, current: 0),
        ),
      );
      await t.tap(_tab);
      await _settle(t);
      final pop = t.getRect(_pop), bar = t.getRect(_bar);
      expect(pop.height, greaterThan(.6 * 520));
      expect(pop.bottom, closeTo(bar.top - 8, .01));
      expect(pop.top, greaterThanOrEqualTo(8));
      // The list kept exactly its floor: one two-line row (36 + 16) and p-1.
      final list = t.getRect(find.byType(RaftMobileNavServerPopoverList));
      expect(list.height, closeTo(60, .01));
    });

    testWidgets('where even the floor does not fit, everything scrolls', (
      t,
    ) async {
      await _size(t, const Size(390, 360));
      final fx = _Fixture();
      await t.pumpWidget(
        _app(fx, content: (f) => _content(f, footer: 6, destinations: 6)),
      );
      await t.tap(_tab);
      await _settle(t);
      final pop = t.getRect(_pop), bar = t.getRect(_bar);
      // available height: above the bar, less the 8px gap and 8px padding.
      expect(pop.top, closeTo(8, .5));
      expect(pop.bottom, closeTo(bar.top - 8, .01));
      expect(t.takeException(), isNull);
      final dest = find.byKey(const ValueKey('dest-5'));
      expect(
        t.getRect(dest).bottom,
        greaterThan(pop.bottom),
        reason: 'the footer and pages scroll with the popover',
      );
    });

    testWidgets('the list opens on the current row, with no animation', (
      t,
    ) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(
        _app(fx, content: (f) => _content(f, servers: 40, current: 30)),
      );
      await t.tap(_tab);
      await t.pump();
      await t.pump();
      final pop = t.getRect(_pop);
      final row = t.getRect(find.byKey(const ValueKey('server-30')));
      expect(row.top, greaterThanOrEqualTo(pop.top));
      expect(row.bottom, lessThanOrEqualTo(pop.bottom));
      expect(row.height, closeTo(52, .01), reason: 'two lines: 36 + 16');
    });
  });

  group('content', () {
    testWidgets('rows: 36 for one line, a second line adds its own height', (
      t,
    ) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(_app(fx));
      await t.tap(_tab);
      await _settle(t);
      expect(t.getSize(find.byKey(const ValueKey('server-0'))).height, 52);
      expect(
        t
            .getSize(
              find.widgetWithText(RaftMobileNavServerPopoverRow, 'Footer 0'),
            )
            .height,
        36,
      );
    });

    testWidgets('up to 4 destinations sit in one row, 5 make a 3 column grid', (
      t,
    ) async {
      await _size(t, const Size(390, 844));
      for (final (count, columns) in [(3, 3), (4, 4), (5, 3), (6, 3)]) {
        final fx = _Fixture();
        await t.pumpWidget(
          _app(fx, content: (f) => _content(f, destinations: count)),
        );
        await t.tap(_tab);
        await _settle(t);
        final cells = [
          for (var i = 0; i < count; i++)
            t.getRect(find.byKey(ValueKey('dest-$i'))),
        ];
        final firstRow = cells.where((c) => c.top == cells.first.top).length;
        expect(firstRow, columns, reason: '$count destinations');
        if (count > 4) {
          expect(
            cells[3].left,
            cells[0].left,
            reason: 'the last row starts left',
          );
          expect(cells[3].top, greaterThan(cells[0].top));
          expect(cells[0].width, closeTo(cells[1].width, .01));
        }
        await t.tap(_tab);
        await _settle(t);
      }
    });

    testWidgets('attention dots: avatar corner and beside a destination icon', (
      t,
    ) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(
        _app(
          fx,
          attention: true,
          content: (f) => _content(f, attentionOnFirstDestination: true),
        ),
      );
      final avatar = t.getRect(find.byKey(const ValueKey('avatar')));
      final dot = t.getRect(
        find.descendant(of: _tab, matching: find.byType(RaftStatus)),
      );
      expect(dot.center.dx, closeTo(avatar.right, .01));
      expect(dot.center.dy, closeTo(avatar.top, .01));
      await t.tap(_tab);
      await _settle(t);
      final dest = t.getRect(find.byKey(const ValueKey('dest-0')));
      final ddot = t.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('dest-0')),
          matching: find.byType(RaftStatus),
        ),
      );
      expect(ddot.top, closeTo(dest.top + 4, .01));
      expect(ddot.left, closeTo(dest.center.dx + 6, .01));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('dest-1')),
          matching: find.byType(RaftStatus),
        ),
        findsNothing,
      );
    });

    testWidgets('rows ignore a press while disabled', (t) async {
      await _size(t, const Size(390, 844));
      var pressed = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Column(
              children: [
                RaftMobileNavServerPopoverRow(
                  label: 'Off',
                  enabled: false,
                  onPressed: () => pressed++,
                ),
                RaftMobileNavServerPopoverRow(
                  label: 'On',
                  onPressed: () => pressed += 10,
                ),
              ],
            ),
          ),
        ),
      );
      await t.tap(find.text('Off'));
      await t.tap(find.text('On'));
      expect(pressed, 10);
    });
  });

  group('semantics', () {
    testWidgets(
      'button label, selected current row, named destinations group',
      (t) async {
        await _size(t, const Size(390, 844));
        final handle = t.ensureSemantics();
        final fx = _Fixture();
        await t.pumpWidget(_app(fx));
        expect(
          find.bySemanticsLabel('Raft Studio, other servers unread'),
          findsOneWidget,
        );
        final node = t.getSemantics(
          find.bySemanticsLabel('Raft Studio, other servers unread'),
        );
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isSelected, isNot(ui.Tristate.isTrue));
        await t.tap(_tab);
        await _settle(t);
        final current = t.getSemantics(
          find.bySemanticsLabel(RegExp('Server 1')),
        );
        expect(current.flagsCollection.isSelected, ui.Tristate.isTrue);
        expect(current.label, contains('Server 1'));
        final other = t.getSemantics(find.bySemanticsLabel(RegExp('Server 0')));
        expect(other.flagsCollection.isSelected, isNot(ui.Tristate.isTrue));
        expect(find.bySemanticsLabel('Raft Studio'), findsWidgets);
        handle.dispose();
      },
    );
  });

  group('themes and text scale', () {
    for (final dark in raftThemeMatrix([false, true])) {
      testWidgets('tokens resolve in ${dark ? 'dark' : 'light'}: open sticker '
          'and hover fill', (t) async {
        await _size(t, const Size(390, 844));
        final fx = _Fixture();
        await t.pumpWidget(
          _app(fx, dark: dark, platform: TargetPlatform.linux),
        );
        late RaftTokens tokens;
        tokens = RaftTokens.of(t.element(_tab));
        Color? sticker() =>
            (t
                        .widget<Container>(
                          find.byKey(
                            const ValueKey('mobile-nav-server-sticker'),
                          ),
                        )
                        .decoration!
                    as BoxDecoration)
                .color;
        expect(sticker(), isNot(tokens.colors['fill-medium']));
        await t.tap(_tab);
        await _settle(t);
        expect(sticker(), tokens.colors['fill-medium']);
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await mouse.moveTo(
          t.getCenter(
            find.widgetWithText(RaftMobileNavServerPopoverRow, 'Footer 0'),
          ),
        );
        await t.pump(const Duration(milliseconds: 300));
        final hovered = find.descendant(
          of: find.widgetWithText(RaftMobileNavServerPopoverRow, 'Footer 0'),
          matching: find.byType(DecoratedBox),
        );
        final colors = [
          for (final box in t.widgetList<DecoratedBox>(hovered))
            if (box.decoration is BoxDecoration)
              (box.decoration as BoxDecoration).color,
        ];
        expect(colors, contains(tokens.colors['brand-soft']));
        await mouse.removePointer();
      });
    }

    testWidgets('touch input has no hover fill', (t) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(_app(fx));
      late RaftTokens tokens;
      tokens = RaftTokens.of(t.element(_tab));
      await t.tap(_tab);
      await _settle(t);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(
        t.getCenter(
          find.widgetWithText(RaftMobileNavServerPopoverRow, 'Footer 0'),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
      final boxes = t.widgetList<DecoratedBox>(
        find.descendant(
          of: find.widgetWithText(RaftMobileNavServerPopoverRow, 'Footer 0'),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect([
        for (final b in boxes) (b.decoration as BoxDecoration).color,
      ], isNot(contains(tokens.colors['brand-soft'])));
      await mouse.removePointer();
    });

    for (final scale in [1.0, 2.0, 3.1]) {
      testWidgets(
        'text scale $scale does not overflow; the tab cell is chrome',
        (t) async {
          await _size(t, const Size(390, 844));
          final fx = _Fixture();
          await t.pumpWidget(_app(fx, textScale: scale, attention: true));
          await t.tap(_tab);
          await _settle(t);
          expect(t.takeException(), isNull);
          final label = t.widget<RichText>(
            find.descendant(of: _tab, matching: find.byType(RichText)).first,
          );
          expect(
            label.textScaler.scale(10),
            lessThanOrEqualTo(10 * 1.35 + .01),
            reason: 'fixed chrome is capped at 1.35x',
          );
          final row = t.widget<RichText>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('server-0')),
                  matching: find.byType(RichText),
                )
                .first,
          );
          expect(
            row.textScaler.scale(14),
            closeTo(14 * scale, .01),
            reason: 'the popover is content: it follows the system size',
          );
        },
      );
    }
  });

  group('reorder', () {
    testWidgets('a touch long press then a move drags a row', (t) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(
        _app(fx, content: (f) => _content(f, servers: 4, reorder: true)),
      );
      await t.tap(_tab);
      await _settle(t);
      final row = find.byKey(const ValueKey('server-0'));
      final g = await t.startGesture(t.getCenter(row));
      await t.pump(const Duration(milliseconds: 600));
      for (var i = 0; i < 12; i++) {
        await g.moveBy(const Offset(0, 10));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await _settle(t);
      expect(fx.reordered, isNotEmpty);
      expect(fx.reordered.single.$1, 0);
      expect(fx.reordered.single.$2, greaterThan(0));
      expect(fx.picked, isEmpty, reason: 'a drag is not a press');
    });

    testWidgets(
      'a finger that held and lifted without moving presses nothing',
      (t) async {
        await _size(t, const Size(390, 844));
        final fx = _Fixture();
        await t.pumpWidget(
          _app(fx, content: (f) => _content(f, servers: 4, reorder: true)),
        );
        await t.tap(_tab);
        await _settle(t);
        final row = find.byKey(const ValueKey('server-2'));
        final g = await t.startGesture(t.getCenter(row));
        await t.pump(const Duration(milliseconds: 700));
        await g.up();
        await _settle(t);
        expect(fx.picked, isEmpty);
        expect(fx.reordered, isEmpty);
        await t.tap(row);
        await _settle(t);
        expect(fx.picked, [2], reason: 'a plain tap still presses');
      },
    );

    testWidgets('a mouse drags a row after 6px', (t) async {
      await _size(t, const Size(390, 844));
      final fx = _Fixture();
      await t.pumpWidget(
        _app(
          fx,
          platform: TargetPlatform.linux,
          content: (f) => _content(f, servers: 4, reorder: true),
        ),
      );
      await t.tap(_tab);
      await _settle(t);
      final row = find.byKey(const ValueKey('server-0'));
      final g = await t.startGesture(
        t.getCenter(row),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(0, 4));
      await t.pump();
      expect(fx.reordered, isEmpty);
      for (var i = 0; i < 12; i++) {
        await g.moveBy(const Offset(0, 10));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await _settle(t);
      expect(fx.reordered, isNotEmpty);
      expect(fx.reordered.single.$1, 0);
    });
  });

  group('previews', () {
    for (final dark in raftThemeMatrix([false, true])) {
      testWidgets('render in ${dark ? 'dark' : 'light'} without errors', (
        t,
      ) async {
        await _size(t, const Size(390, 700));
        for (final preview in [
          mobileNavServerTabPreview,
          mobileNavServerPopoverGridPreview,
          mobileNavServerPopoverRowPreview,
        ]) {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(body: preview()),
            ),
          );
          await t.pump();
          expect(t.takeException(), isNull);
        }
        expect(find.text('Computers'), findsOneWidget);
      });
    }
  });
}
