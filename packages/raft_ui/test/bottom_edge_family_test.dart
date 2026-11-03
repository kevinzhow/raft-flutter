import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const _screen = Size(856, 944);
const _surface = Key('bottom-edge-family-surface');
const _publicAction = Key('bottom-edge-public-action');
const _appearance = Key('bottom-edge-zero-inset-appearance');

enum _Family { join, banner, archived, bench, public, setup, floating }

typedef _Look = ({String id, bool dark});
const _looks = <_Look>[
  (id: raftThemePackId, dark: false),
  (id: raftThemePackId, dark: true),
  (id: elegantThemePackId, dark: false),
  (id: elegantThemePackId, dark: true),
  (id: brutalThemePackId, dark: false),
];

Widget _child(_Family family, VoidCallback action) => switch (family) {
  _Family.join => RaftChannelJoinFooter(
    channelName: 'safe-area',
    label: 'Join safe-area',
    onJoin: action,
  ),
  _Family.banner => const RaftChannelBannerFooter(message: 'Read-only notice'),
  _Family.archived => const RaftChannelArchivedFooter(
    message: 'Archived notice',
  ),
  _Family.bench => const RaftbenchServiceDmNotice(),
  _Family.public => RaftPublicBottomBanner(
    message: 'Join the public server',
    actions: [
      RaftPublicActionButton(
        key: _publicAction,
        label: 'Join public',
        glyph: RaftGlyph.logIn,
        accent: true,
        onPressed: action,
      ),
    ],
  ),
  _Family.setup => RaftSetupResumeBar(onResume: action),
  _Family.floating => const RaftPublicFloatingBanner(
    message: 'Join failed',
    top: false,
    warning: true,
  ),
};

Finder _content(_Family family) => switch (family) {
  _Family.join => find.byType(RaftRecipeButton),
  _Family.archived => find.text('Archived notice'),
  _Family.public => find.byKey(_publicAction),
  _Family.setup => find.byKey(const ValueKey('server-setup-resume')),
  _ => find.byType(RaftBanner),
};

bool _unspentOverlay(_Family family) => switch (family) {
  _Family.public || _Family.setup || _Family.floating => true,
  _ => false,
};

void _cleanup(WidgetTester tester) {
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

void _insets(
  WidgetTester tester, {
  double nav = 0,
  double keyboard = 0,
  double top = 0,
  double left = 0,
  double right = 0,
  Size size = _screen,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = FakeViewPadding(
    top: top,
    left: left,
    right: right,
    bottom: nav,
  );
  tester.view.padding = FakeViewPadding(
    top: top,
    left: left,
    right: right,
    bottom: keyboard == 0 ? nav : 0,
  );
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
}

Future<void> _mount(
  WidgetTester tester,
  _Family family,
  _Look look,
  VoidCallback action, {
  double nav = 0,
  double keyboard = 0,
  bool consumed = false,
}) async {
  _insets(tester, nav: nav, keyboard: keyboard);
  final surface = KeyedSubtree(key: _surface, child: _child(family, action));
  Widget body = Stack(
    fit: StackFit.expand,
    children: [
      if (family == _Family.floating)
        surface
      else
        Positioned(left: 0, right: 0, bottom: 0, child: surface),
    ],
  );
  if (consumed) {
    body = SafeArea(top: false, left: false, right: false, child: body);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(
        pack: packForThemeId(look.id),
        dark: look.dark,
        platform: TargetPlatform.android,
      ),
      home: RepaintBoundary(
        key: _appearance,
        child: _unspentOverlay(family)
            ? Material(child: body)
            : Scaffold(resizeToAvoidBottomInset: true, body: body),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void _recordZeroInsets(_Family family, _Look look, Rect face, Rect surface) {
  final path = Platform.environment['RAFT_SAFE_AREA_METRICS'];
  if (path == null) return;
  List<double> rect(Rect value) => [
    value.left,
    value.top,
    value.width,
    value.height,
  ];
  File(path).writeAsStringSync(
    '${jsonEncode({'family': family.name, 'look': look.id, 'dark': look.dark, 'face': rect(face), 'surface': rect(surface)})}\n',
    mode: FileMode.append,
  );
}

Future<void> _captureZeroInsets(
  WidgetTester tester,
  _Family family,
  _Look look,
) async {
  final path = Platform.environment['RAFT_SAFE_AREA_APPEARANCE_DIR'];
  if (path == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_appearance),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(path)..createSync(recursive: true);
      File(
        '${directory.path}/${family.name}-${look.id}-'
        '${look.dark ? 'dark' : 'light'}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  for (final look in raftThemeMatrix(
    _looks,
    look: (value) => raftLookOf(value.id),
    dark: (value) => value.dark,
  )) {
    for (final family in _Family.values) {
      testWidgets(
        '${family.name} owns remaining bottom edge (${look.id}, dark=${look.dark})',
        (tester) async {
          _cleanup(tester);
          var presses = 0;
          void action() => presses++;
          await _mount(tester, family, look, action);
          final restFace = tester.getRect(_content(family));
          final restSurface = tester.getRect(find.byKey(_surface));
          expect(restFace.isEmpty, isFalse);
          _recordZeroInsets(family, look, restFace, restSurface);
          await _captureZeroInsets(tester, family, look);

          await _mount(tester, family, look, action, nav: 48);
          final navFace = tester.getRect(_content(family));
          final navSurface = tester.getRect(find.byKey(_surface));
          expect(
            navFace.bottom,
            closeTo(restFace.bottom - 48, .01),
            reason: 'the whole control clears the 48dp system bar once',
          );
          expect(navFace.size, restFace.size);
          if (family == _Family.floating) {
            expect(navSurface.bottom, closeTo(restSurface.bottom - 48, .01));
            expect(navSurface.size, restSurface.size);
          } else {
            expect(navSurface.bottom, _screen.height);
            expect(navSurface.height, closeTo(restSurface.height + 48, .01));
          }
          if (family == _Family.join ||
              family == _Family.public ||
              family == _Family.setup) {
            await tester.tap(_content(family));
            await tester.pump();
            expect(presses, 1, reason: 'the inset-safe action stays reachable');
          }

          await _mount(tester, family, look, action, nav: 48, consumed: true);
          expect(
            tester.getRect(_content(family)).bottom,
            closeTo(restFace.bottom - 48, .01),
            reason: 'an owning ancestor consumes the system inset once',
          );
          expect(
            tester.getRect(find.byKey(_surface)).height,
            restSurface.height,
          );

          await _mount(tester, family, look, action, nav: 48, keyboard: 300);
          final imeFace = tester.getRect(_content(family));
          final imeSurface = tester.getRect(find.byKey(_surface));
          expect(
            imeFace.bottom,
            closeTo(restFace.bottom - 300, .01),
            reason: 'keyboard space is spent once, never keyboard plus nav',
          );
          expect(imeFace.size, restFace.size);
          if (family == _Family.floating) {
            expect(imeSurface.bottom, closeTo(restSurface.bottom - 300, .01));
          } else {
            expect(
              imeSurface.bottom,
              _unspentOverlay(family) ? _screen.height : _screen.height - 300,
            );
            expect(
              imeSurface.height,
              closeTo(
                restSurface.height + (_unspentOverlay(family) ? 300 : 0),
                .01,
              ),
            );
          }
        },
      );
    }

    testWidgets('top floating banner owns status inset without following IME '
        '(${look.id}, dark=${look.dark})', (tester) async {
      _cleanup(tester);
      Future<Rect> paint(double nav, double keyboard, {double top = 0}) async {
        _insets(tester, nav: nav, keyboard: keyboard, top: top);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(look.id), dark: look.dark),
            home: const Stack(
              children: [
                RaftPublicFloatingBanner(message: 'Sign in', top: true),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        return tester.getRect(find.byType(RaftBanner));
      }

      final rest = await paint(0, 0);
      expect(await paint(48, 0), rest);
      expect(await paint(48, 300), rest);
      final status = await paint(0, 0, top: 24);
      expect(status.top, closeTo(rest.top + 24, .01));
      expect(status.size, rest.size);
      expect(await paint(48, 300, top: 24), status);
    });

    testWidgets('public footer owns exposed sides but not a rail-shielded side '
        '(${look.id}, dark=${look.dark})', (tester) async {
      _cleanup(tester);
      const message =
          'Read public channels and join the server to follow '
          'updates. The whole action stays reachable beside a system bar. '
          'Read public channels and join the server to follow updates.';
      final mismatches = <String>[];
      for (final (rail, direction) in [
        (false, TextDirection.ltr),
        (true, TextDirection.ltr),
        (true, TextDirection.rtl),
      ]) {
        Future<(Rect, Rect)> paint(double left, double right) async {
          _insets(
            tester,
            left: left,
            right: right,
            top: 24,
            size: const Size(390, 844),
          );
          late EdgeInsets inherited;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: packForThemeId(look.id), dark: look.dark),
              home: Directionality(
                textDirection: direction,
                child: RaftPublicServerLayout(
                  rail: rail ? const SizedBox(width: 72) : null,
                  columns: Builder(
                    builder: (context) {
                      inherited = MediaQuery.paddingOf(context);
                      return Column(
                        children: [
                          const Expanded(child: SizedBox()),
                          RaftPublicBottomBanner(
                            message: message,
                            actions: [
                              RaftPublicActionButton(
                                key: _publicAction,
                                label: 'Join public',
                                glyph: RaftGlyph.logIn,
                                accent: true,
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            inherited.top,
            0,
            reason: 'public layout keeps its already-consumed status inset',
          );
          if (rail && direction == TextDirection.ltr) {
            expect(inherited.right, right);
          } else if (rail) {
            expect(inherited.left, left);
          } else {
            expect(inherited.left, left);
            expect(inherited.right, right);
          }
          return (
            tester.getRect(find.text(message)),
            tester.getRect(find.byKey(_publicAction)),
          );
        }

        final (rest, restAction) = await paint(0, 0);
        final (safe, action) = await paint(32, 48);
        // The public row may shrink its action through FittedBox. Assert the
        // outer content edges, not a fixed width for either sibling.
        final rtl = direction == TextDirection.rtl;
        final left = rtl ? action.left : safe.left;
        final right = rtl ? safe.right : action.right;
        final expectedLeft =
            (rtl ? restAction.left : rest.left) + (rail && !rtl ? 0 : 32);
        final expectedRight =
            (rtl ? rest.right : restAction.right) - (rail && rtl ? 0 : 48);
        if ((left - expectedLeft).abs() > .01 ||
            (right - expectedRight).abs() > .01 ||
            action.left < 32 ||
            action.right > 390 - 48) {
          mismatches.add(
            'rail=$rail direction=$direction: copy=$safe action=$action; '
            'expected outer content sides $expectedLeft..$expectedRight',
          );
        }
      }
      expect(mismatches, isEmpty);
    });

    testWidgets('public floating banners clear both exposed side insets '
        '(${look.id}, dark=${look.dark})', (tester) async {
      _cleanup(tester);
      for (final top in [false, true]) {
        _insets(tester, left: 32, right: 48, size: const Size(390, 844));
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(look.id), dark: look.dark),
            home: Stack(
              children: [
                RaftPublicFloatingBanner(message: 'Join failed', top: top),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final box = tester.getRect(find.byType(RaftBanner));
        expect(box.left, greaterThanOrEqualTo(32));
        expect(box.right, lessThanOrEqualTo(390 - 48));
      }
    });
  }
}
