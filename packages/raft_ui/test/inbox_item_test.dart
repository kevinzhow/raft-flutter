import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// raft-ui 0.95.3 InboxItem (compact, the only density Web v1.24 mounts):
// Web measures a 379x60 row with padding 8/16, a 36x36 leading tile, a cell
// fill inset 8 and the focus on the open trigger.
typedef _Env = ({
  String name,
  Size size,
  TargetPlatform platform,
  bool dark,
  double scale,
});

const _sizes = [
  // Index 0 is the phone: the gate keeps every theme/scale variant there.
  ('linux 390x844', Size(390, 844), TargetPlatform.linux),
  ('linux 1440x900', Size(1440, 900), TargetPlatform.linux),
  ('android 856x944', Size(856, 944), TargetPlatform.android),
  ('android 944x856', Size(944, 856), TargetPlatform.android),
];
const _variants = [(false, 1.0), (true, 1.0), (false, 2.0), (true, 2.0)];

// matrix: nightly-full -- the gate runs light 1.0x at every size and the dark
// and 2.0x variants on the phone size (raftMatrixCell); RAFT_TEST_TIER=full
// runs every size x variant.
final _envs = <_Env>[
  for (final (v, (dark, scale)) in _variants.indexed)
    for (final (i, (name, size, platform)) in _sizes.indexed)
      if (raftMatrixCell(theme: v, size: i))
        (name: name, size: size, platform: platform, dark: dark, scale: scale),
];

String _label(_Env e) =>
    '${e.name} ${e.dark ? 'dark' : 'light'} text ${e.scale}x';

Future<void> _pump(WidgetTester tester, _Env e, Widget child) async {
  tester.view.physicalSize = e.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: raftTheme(dark: e.dark).copyWith(platform: e.platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(e.scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _item({
  Key? key = const ValueKey('item'),
  bool selected = false,
  bool unread = false,
  bool disabled = false,
  bool withActions = true,
  bool withBadge = false,
  VoidCallback? onOpen,
  VoidCallback? onAction,
}) => RaftInboxItem(
  key: key,
  semanticLabel: 'Release notes, Draft is in the launch channel, 10:40',
  selected: selected,
  unread: unread,
  disabled: disabled,
  onOpen: onOpen ?? () {},
  leading: const Icon(Icons.inbox, size: 18),
  leadingBadge: withBadge ? const Icon(Icons.circle, size: 10) : null,
  title: const Text('Release notes'),
  timestamp: const Text('10:40'),
  body: const Text('Draft is in the launch channel'),
  marks: const [Text('2')],
  actions: withActions
      ? [
          RaftIconButton(
            key: const ValueKey('action-done'),
            glyph: RaftGlyph.checkCircle2,
            semanticLabel: 'Done',
            onPressed: onAction ?? () {},
          ),
        ]
      : const [],
);

Finder get _fill => find.byKey(const ValueKey('inbox-item-fill'));

Color? _fillColor(WidgetTester tester) {
  final box = find
      .descendant(of: _fill, matching: find.byType(DecoratedBox))
      .first;
  final decoration = tester.widget<DecoratedBox>(box).decoration;
  return decoration is BoxDecoration ? decoration.color : null;
}

double _opacityOf(WidgetTester tester, Finder f) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: f, matching: find.byType(AnimatedOpacity)).first,
    )
    .opacity;

TextStyle _styleOf(WidgetTester tester, String text) =>
    DefaultTextStyle.of(tester.element(find.text(text))).style
        .merge(tester.widget<Text>(find.text(text)).style);

void main() {
  for (final e in _envs) {
    final touch = e.platform == TargetPlatform.android;
    final wide = e.size.width >= 768;
    final desktop = !touch && wide;
    final colors = e.dark ? RaftDark.fillCellHover : RaftLight.fillCellHover;

    testWidgets('${_label(e)}: row geometry, 36 leading, fill inset 8', (
      tester,
    ) async {
      await _pump(tester, e, SizedBox(width: 379, child: _item()));
      final row = tester.getRect(find.byKey(const ValueKey('item')));
      final leading = tester.getRect(
        find.byKey(const ValueKey('inbox-item-leading')),
      );
      expect(leading.size, const Size(36, 36));
      final padX = desktop ? 16.0 : 20.0;
      expect(leading.left - row.left, padX);
      final fill = tester.getRect(_fill);
      expect(fill.left - row.left, 8);
      expect(row.right - fill.right, 8);
      expect(fill.height, row.height);
      expect(find.byType(Divider), findsNothing);
      if (e.scale == 1) {
        if (desktop) expect(row.height, 60);
        if (touch) expect(row.height, greaterThanOrEqualTo(56));
        if (!desktop && !touch) expect(row.height, 64);
      } else {
        expect(row.height, greaterThan(60));
      }
      // Text grows, never clips or overflows.
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.text('Release notes'));
      final body = tester.getRect(find.text('Draft is in the launch channel'));
      expect(title.top, greaterThanOrEqualTo(row.top));
      expect(body.bottom, lessThanOrEqualTo(row.bottom));
      expect(title.bottom, lessThanOrEqualTo(body.top));
    });

    testWidgets('${_label(e)}: fill states and keyboard ring', (tester) async {
      await _pump(tester, e, SizedBox(width: 379, child: _item()));
      expect(_fillColor(tester)?.a ?? 0, 0);
      expect(find.byKey(const ValueKey('inbox-item-focus-ring')), findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(-10, -10));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Release notes')));
      await tester.pumpAndSettle();
      if (touch) {
        expect(_fillColor(tester)?.a ?? 0, 0, reason: 'no hover on touch');
      } else {
        expect(_fillColor(tester), colors);
      }
      await mouse.moveTo(const Offset(-10, -10));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final ring = find.byKey(const ValueKey('inbox-item-focus-ring'));
      expect(ring, findsOneWidget);
      final ringBox =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: ring,
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect((ringBox.border as Border).top.width, 2);
      expect(tester.getRect(ring), tester.getRect(_fill));
    });

    testWidgets('${_label(e)}: selected fill, unread title', (tester) async {
      await _pump(
        tester,
        e,
        SizedBox(width: 379, child: _item(selected: true, unread: true)),
      );
      expect(
        _fillColor(tester),
        e.dark ? RaftDark.fillCellSelected : RaftLight.fillCellSelected,
      );
      final title = _styleOf(tester, 'Release notes');
      expect(title.fontWeight, FontWeight.w700);
      final body = _styleOf(tester, 'Draft is in the launch channel');
      expect(title.color, isNot(body.color));
      // Selected rows ignore the hover wash.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.byType(RaftInboxItem)),
      );
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      expect(
        _fillColor(tester),
        e.dark ? RaftDark.fillCellSelected : RaftLight.fillCellSelected,
      );
    });

    testWidgets('${_label(e)}: one Tab stop, actions and timestamp reveal', (
      tester,
    ) async {
      var opened = 0;
      var done = 0;
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        e,
        SizedBox(
          width: 379,
          child: _item(onOpen: () => opened++, onAction: () => done++),
        ),
      );
      final actions = find.byKey(const ValueKey('action-done'));
      expect(
        _opacityOf(tester, actions),
        touch ? 1 : 0,
        reason: 'actions reveal on hover, always on touch',
      );
      expect(find.text('10:40'), findsNothing);

      if (!touch) {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(-10, -10));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.text('Release notes')));
        await tester.pumpAndSettle();
        expect(_opacityOf(tester, actions), 1);
        expect(find.text('10:40'), findsOneWidget);
        await mouse.moveTo(const Offset(-10, -10));
        await tester.pumpAndSettle();
        expect(_opacityOf(tester, actions), 0);
      }

      // The trigger is the first Tab stop and carries the semantics label.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, actions), 1, reason: 'focus-within reveals');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, 1);
      expect(done, 0);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('inbox-item-open')))
            .label,
        'Release notes, Draft is in the launch channel, 10:40',
      );
      // The action is a separate stop.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(done, 1);
      expect(opened, 1);
      // Tapping the action never opens the row.
      await tester.tap(actions);
      await tester.pump();
      expect(done, 2);
      expect(opened, 1);
      // Tapping the text opens it.
      await tester.tap(find.text('Draft is in the launch channel'));
      await tester.pump();
      expect(opened, 2);
      semantics.dispose();
    });

    testWidgets('${_label(e)}: disabled row does not open or wash', (
      tester,
    ) async {
      var opened = 0;
      await _pump(
        tester,
        e,
        SizedBox(
          width: 379,
          child: _item(disabled: true, onOpen: () => opened++),
        ),
      );
      await tester.tap(find.text('Release notes'));
      await tester.pump();
      expect(opened, 0);
    });

    testWidgets('${_label(e)}: skeleton has the loaded row height', (
      tester,
    ) async {
      await _pump(
        tester,
        e,
        SizedBox(
          width: 379,
          child: Column(
            children: [
              _item(),
              const RaftInboxItemSkeleton(key: ValueKey('skeleton')),
            ],
          ),
        ),
      );
      final loaded = tester.getSize(find.byKey(const ValueKey('item'))).height;
      final skeleton = tester
          .getSize(find.byKey(const ValueKey('skeleton')))
          .height;
      expect(skeleton, loaded);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${_label(e)}: list group and heading', (tester) async {
      await _pump(
        tester,
        e,
        SizedBox(
          width: 379,
          child: RaftInboxItemListGroup(
            heading: 'Today',
            children: [
              _item(key: const ValueKey('a')),
              _item(key: const ValueKey('b')),
            ],
          ),
        ),
      );
      final heading = find.byKey(const ValueKey('inbox-item-list-heading'));
      final text = tester.getRect(find.text('Today'));
      expect(text.left - tester.getRect(heading).left, desktop ? 16 : 20);
      final style = _styleOf(tester, 'Today');
      expect(style.fontWeight, FontWeight.w700);
      final a = tester.getRect(find.byKey(const ValueKey('a')));
      final b = tester.getRect(find.byKey(const ValueKey('b')));
      expect(b.top - a.bottom, 2, reason: 'gap-0.5, no hairline');
    });
  }

  for (final touch in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'activity toolbar bar height ${touch ? 'touch 856x944' : 'mouse 1440x900'} ${dark ? 'dark' : 'light'}',
        (tester) async {
          await _pump(
            tester,
            (
              name: 'toolbar',
              size: touch ? const Size(856, 944) : const Size(1440, 900),
              platform: touch ? TargetPlatform.android : TargetPlatform.linux,
              dark: dark,
              scale: 1,
            ),
            SizedBox(
              width: 1000,
              child: RaftActivityScopeToolbar(
                view: RaftActivityView.all,
                compact: false,
                onView: (_) {},
                onOpenSwitcher: () {},
                sort: 'desc',
                onSort: (_) {},
              ),
            ),
          );
          expect(
            tester.getSize(find.byType(RaftActivityScopeToolbar)).height,
            touch ? 68 : 44,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
