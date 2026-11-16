import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_header_mask.dart';

const _author = ValueKey('message-author');

/// A viewport and the platform that decides touch or pointer.
class _Surface {
  const _Surface(this.name, this.size, this.platform);
  final String name;
  final Size size;
  final TargetPlatform platform;
  bool get fine => platform == TargetPlatform.linux;
}

const _desktop = _Surface(
  '1024x768 linux',
  Size(1024, 768),
  TargetPlatform.linux,
);
const _narrowDesktop = _Surface(
  '390x844 linux',
  Size(390, 844),
  TargetPlatform.linux,
);
const _foldable = _Surface(
  '856x944 android',
  Size(856, 944),
  TargetPlatform.android,
);
const _foldableLandscape = _Surface(
  '944x856 android',
  Size(944, 856),
  TargetPlatform.android,
);

Future<void> _mount(
  WidgetTester tester,
  _Surface surface,
  List<Widget> rows, {
  bool dark = false,
}) async {
  tester.view.physicalSize = surface.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: surface.platform),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Widget _row(
  int i, {
  bool continuation = false,
  bool highlighted = false,
  bool searchMatch = false,
  bool checked = false,
  bool toolbar = false,
  RaftMessageFollowedBy? followedBy,
}) => RaftMessageRow(
  key: ValueKey('row-$i'),
  author: 'Alice',
  timestamp: '14:30',
  continuation: continuation,
  highlighted: highlighted,
  searchMatch: searchMatch,
  checked: checked,
  followedBy: followedBy,
  avatar: ColoredBox(key: ValueKey('avatar-$i'), color: Colors.blue),
  content: Text('Body $i', key: ValueKey('body-$i')),
  toolbar: toolbar
      ? RaftMessageToolbar(
          children: [
            for (var a = 0; a < 5; a++)
              RaftMessageToolbarAction(
                label: 'Action $a',
                icon: const SizedBox(),
                onPressed: () {},
              ),
          ],
        )
      : null,
);

Finder _in(int i, Finder f) =>
    find.descendant(of: find.byKey(ValueKey('row-$i')), matching: f);

Finder _fillFinder(int i) => _in(
  i,
  find.byWidgetPredicate(
    (w) => w is DecoratedBox && w.decoration is RaftCssBoxDecoration,
  ),
);

Rect _fill(WidgetTester t, int i) => t.getRect(_fillFinder(i).first);
Color? _fillColor(WidgetTester t, int i) =>
    (t.widget<DecoratedBox>(_fillFinder(i).first).decoration as BoxDecoration)
        .color;
Rect _body(WidgetTester t, int i) => t.getRect(find.byKey(ValueKey('body-$i')));
Rect _rowRect(WidgetTester t, int i) =>
    t.getRect(find.byKey(ValueKey('row-$i')));

final _mice = Expando<TestGesture>('mouse');

Future<TestGesture> _hover(WidgetTester t, int i) async {
  var mouse = _mice[t];
  if (mouse == null) {
    mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    addTearDown(mouse.removePointer);
    _mice[t] = mouse;
  }
  await mouse.moveTo(
    t.getCenter(find.byKey(ValueKey('row-$i'))) + const Offset(20, 0),
  );
  await mouse.moveTo(t.getCenter(find.byKey(ValueKey('row-$i'))));
  await t.pump();
  return mouse;
}

Color _tokenColor(String name, {bool dark = false}) =>
    RaftTokens.theme(dark: dark).colors[name]!;

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets(
      'turn start: 8 unpainted above the fill, 4 inside, fill = text + 8 ($mode)',
      (tester) async {
        await _mount(tester, _desktop, [_row(0), _row(1)], dark: dark);
        final fill = _fill(tester, 0);
        expect(
          fill.top - _rowRect(tester, 0).top,
          8,
          reason: 'margin-top sits outside the fill',
        );
        final header = tester.getRect(_in(0, find.byKey(_author)).first);
        expect(header.top - fill.top, 4);
        expect(fill.bottom - _body(tester, 0).bottom, 4);
        expect(_rowRect(tester, 0).bottom, fill.bottom);
      },
    );

    testWidgets(
      'continuation: 4 above and below, fill = text + 8, totals 16 / 8 ($mode)',
      (tester) async {
        await _mount(tester, _desktop, [
          _row(0, followedBy: RaftMessageFollowedBy.compact),
          _row(
            1,
            continuation: true,
            followedBy: RaftMessageFollowedBy.compact,
          ),
          _row(2, continuation: true),
          _row(3),
        ], dark: dark);
        final fill = _fill(tester, 1);
        expect(_body(tester, 1).top - fill.top, 4);
        expect(fill.bottom - _body(tester, 1).bottom, 4);
        expect(fill.top - _rowRect(tester, 1).top, 0);
        expect(_body(tester, 2).top - _body(tester, 1).bottom, 8);
        expect(_body(tester, 1).top - _body(tester, 0).bottom, 8);
        // Text to text across a turn: 4 + 8 + 4 = 16 (body bottom to next line top).
        final nextAuthor = tester.getRect(_in(3, find.byKey(_author)).first);
        expect(nextAuthor.top - _body(tester, 2).bottom, 16);
      },
    );
  }

  for (final surface in [
    _desktop,
    _narrowDesktop,
    _foldable,
    _foldableLandscape,
  ]) {
    testWidgets('type steps follow the input, not the width: ${surface.name}', (
      tester,
    ) async {
      await _mount(tester, surface, [_row(0)]);
      final wide = surface.size.width >= 768 && surface.fine;
      final body = tester
          .widget<DefaultTextStyle>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('body-0')),
                  matching: find.byType(DefaultTextStyle),
                )
                .first,
          )
          .style;
      expect(body.fontSize, wide ? 14 : 16);
      expect(body.fontSize! * body.height!, wide ? 22 : 24);
      final name = tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(_author).first,
                  matching: find.byType(Text),
                )
                .first,
          )
          .style!;
      expect(
        name.fontSize! * name.height!,
        wide ? 22 : 20,
        reason: 'subhead 14/22 or 15/20',
      );
      final time = tester
          .widget<RichText>(
            find
                .descendant(
                  of: find.text('14:30').first,
                  matching: find.byType(RichText),
                )
                .first,
          )
          .text
          .style!;
      expect(time.fontSize, 12);
      expect(time.fontSize! * time.height!, wide ? 18 : 16);
    });
  }

  testWidgets('size tiers move the steps: body +-2/+-4, name +-2, meta +-1', (
    tester,
  ) async {
    await _mount(tester, _desktop, [
      RaftMessageRow(
        key: const ValueKey('row-0'),
        author: 'A',
        timestamp: '1',
        sizeTier: RaftMessageSizeTier.lg,
        content: const Text('lg', key: ValueKey('body-0')),
      ),
    ]);
    final body = tester
        .widget<DefaultTextStyle>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('body-0')),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        )
        .style;
    expect(body.fontSize, 16);
    expect(body.fontSize! * body.height!, 26);
    final name = tester
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(_author).first,
                matching: find.byType(Text),
              )
              .first,
        )
        .style!;
    expect(name.fontSize, 16);
    expect(name.fontSize! * name.height!, 24);
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets(
      'hover and popup fill is fill-subtle, located is info-soft without a ring ($mode)',
      (tester) async {
        await _mount(tester, _desktop, [
          _row(0),
          _row(1, highlighted: true),
          _row(2, searchMatch: true),
          _row(3, checked: true),
          _row(4),
        ], dark: dark);
        expect(_fillColor(tester, 0), Colors.transparent);
        final infoSoft = _tokenColor('info-soft', dark: dark);
        for (final i in [1, 2, 3]) {
          expect(_fillColor(tester, i), infoSoft, reason: 'row $i');
        }
        final ring = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(const ValueKey('row-1')),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is DecoratedBox &&
                      w.position == DecorationPosition.foreground,
                ),
              )
              .first,
        );
        expect(
          (ring.decoration as BoxDecoration).border,
          isNull,
          reason: 'no ring on a located row',
        );
        await _hover(tester, 0);
        expect(_fillColor(tester, 0), _tokenColor('fill-subtle', dark: dark));
        await _hover(tester, 2);
        expect(
          _fillColor(tester, 2),
          infoSoft,
          reason: 'a search match is not changed by hover',
        );
        await _hover(tester, 3);
        expect(
          _fillColor(tester, 3),
          infoSoft,
          reason: 'a checked row is not changed by hover',
        );
        await _hover(tester, 1);
        expect(_fillColor(tester, 1), infoSoft);
      },
    );
  }

  testWidgets('popup-open fill is fill-subtle', (tester) async {
    await _mount(tester, _desktop, [
      RaftMessageRow(
        key: const ValueKey('row-0'),
        author: 'A',
        timestamp: '1',
        popupOpen: true,
        content: const Text('x', key: ValueKey('body-0')),
      ),
    ]);
    expect(_fillColor(tester, 0), _tokenColor('fill-subtle'));
  });

  testWidgets(
    'continuation time: mono-meta 12 from the type slot, right 0, hint colour only on hover',
    (tester) async {
      await _mount(tester, _desktop, [_row(0), _row(1, continuation: true)]);
      RichText clock() => tester.widget<RichText>(
        find
            .descendant(
              of: _in(1, find.text('14:30')).first,
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(clock().text.style!.color, Colors.transparent);
      await _hover(tester, 1);
      final style = clock().text.style!;
      expect(style.fontSize, 12);
      expect(style.fontSize! * style.height!, 18);
      expect(style.color, _tokenColor('foreground-hint'));
      final text = tester.getRect(_in(1, find.text('14:30')).first);
      final gutterRight = _rowRect(tester, 1).left + 8 + 35;
      expect(text.right, gutterRight, reason: 'right: 0 of the gutter');
      expect(text.top - _body(tester, 1).top, 2, reason: '(22 - 18) / 2');
      expect(
        text.width,
        greaterThan(30),
        reason: 'no FittedBox: 12px "14:30" keeps its width',
      );
    },
  );

  testWidgets(
    'header time sits right after the name; the mask covers the toolbar plus 8',
    (tester) async {
      await _mount(tester, _desktop, [_row(0, toolbar: true)]);
      final name = tester.getRect(_in(0, find.byKey(_author)).first);
      final time = tester.getRect(_in(0, find.text('14:30')).first);
      expect(time.left - name.right, 6, reason: 'inline, gap-1.5');
      expect(time.height, 18);
      expect(name.height, 22);
      expect(
        tester
            .widget<RaftMessageHeaderMask>(find.byType(RaftMessageHeaderMask))
            .toolbarWidth,
        isNull,
      );
      await _hover(tester, 0);
      await tester.pump();
      final toolbar = tester.getRect(find.byType(RaftMessageToolbar));
      final mask = tester.widget<RaftMessageHeaderMask>(
        find.byType(RaftMessageHeaderMask),
      );
      expect(mask.toolbarWidth, toolbar.width);
      expect(
        tester.getRect(_in(0, find.text('14:30')).first).left,
        time.left,
        reason: 'the time does not move',
      );
    },
  );

  for (final (surface, expected) in [
    (_desktop, 8.0),
    (_narrowDesktop, 12.0),
    (_foldable, 12.0),
    (_foldableLandscape, 12.0),
  ]) {
    testWidgets(
      'timeline inset is 8 at >= 768 with a fine pointer, else 12: ${surface.name}',
      (tester) async {
        late EdgeInsets inset;
        await _mount(tester, surface, [
          Builder(
            builder: (context) {
              inset = const RaftTimelineCompositionRecipe().messageInsetOf(
                context,
              );
              return const SizedBox();
            },
          ),
        ]);
        expect(inset, EdgeInsets.symmetric(horizontal: expected));
      },
    );
  }
}
