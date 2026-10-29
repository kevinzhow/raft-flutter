import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Interaction follows the input (the platform), layout follows the width. An
// unfolded foldable is 856 dp wide and still touched; a narrow desktop window
// is 390 dp wide and still driven by a mouse.
const _foldable = Size(856, 944);
const _foldableLandscape = Size(944, 856);
const _phone = Size(390, 844);
const _desktop = Size(1280, 800);

Future<BuildContext> _mount(
  WidgetTester t, {
  required Size size,
  required TargetPlatform platform,
  Widget child = const SizedBox(),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  return t.element(find.byType(Scaffold));
}

void main() {
  test('every target platform resolves to one input mode', () {
    for (final platform in TargetPlatform.values) {
      final touch = {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
      }.contains(platform);
      expect(
        RaftInteraction.platformIsTouch(platform),
        touch,
        reason: '$platform',
      );
      expect(RaftInteraction.forPlatform(platform).touch, touch);
      expect(RaftInteraction.forPlatform(platform).pointer, !touch);
    }
  });

  test('touch has no hover, no Enter-to-send and no shortcut hints', () {
    const touch = RaftInteraction.touchMode;
    expect(touch.hover, isFalse);
    expect(touch.enterSends, isFalse);
    expect(touch.shortcutHints, isFalse);
    const pointer = RaftInteraction.pointerMode;
    expect(pointer.hover, isTrue);
    expect(pointer.enterSends, isTrue);
    expect(pointer.shortcutHints, isTrue);
  });

  for (final (label, size) in [
    ('foldable portrait', _foldable),
    ('foldable landscape', _foldableLandscape),
    ('phone', _phone),
    ('desktop-width window', _desktop),
  ]) {
    testWidgets('Android is touch at any width: $label', (t) async {
      final context = await _mount(
        t,
        size: size,
        platform: TargetPlatform.android,
      );
      expect(RaftInteraction.of(context).touch, isTrue);
      expect(RaftDensityScope.of(context), RaftDensity.touch);
    });

    testWidgets('Linux is pointer at any width: $label', (t) async {
      final context = await _mount(
        t,
        size: size,
        platform: TargetPlatform.linux,
      );
      expect(RaftInteraction.of(context).pointer, isTrue);
      expect(RaftDensityScope.of(context), RaftDensity.desktop);
    });
  }

  testWidgets('iOS is touch on a wide window', (t) async {
    final context = await _mount(
      t,
      size: _foldable,
      platform: TargetPlatform.iOS,
    );
    expect(RaftInteraction.of(context).touch, isTrue);
  });

  testWidgets('macOS is pointer on a narrow window', (t) async {
    final context = await _mount(
      t,
      size: _phone,
      platform: TargetPlatform.macOS,
    );
    expect(RaftInteraction.of(context).pointer, isTrue);
  });

  testWidgets('a scope overrides the platform for its subtree', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        home: RaftInteractionScope(
          interaction: RaftInteraction.pointerMode,
          child: Builder(
            builder: (context) => Text(
              '${RaftInteraction.of(context).mode.name}/'
              '${RaftDensityScope.of(context).name}',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );
    expect(find.text('pointer/desktop'), findsOneWidget);
  });

  testWidgets('an explicit density scope sets the interaction too', (t) async {
    late BuildContext inner;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        home: RaftDensityScope(
          density: RaftDensity.desktop,
          child: Builder(
            builder: (context) {
              inner = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(RaftDensityScope.of(inner), RaftDensity.desktop);
    expect(RaftInteraction.of(inner).pointer, isTrue);
  });

  // The 48 dp touch target of a panel header action follows the input, not the
  // 768 dp breakpoint.
  for (final (label, size, platform, expected) in [
    ('foldable, touch', _foldable, TargetPlatform.android, 48.0),
    ('phone, touch', _phone, TargetPlatform.android, 48.0),
    ('desktop-width, pointer', _desktop, TargetPlatform.linux, 0.0),
    ('narrow window, pointer', _phone, TargetPlatform.linux, 0.0),
  ]) {
    testWidgets('panel action target: $label', (t) async {
      var presses = 0;
      await _mount(
        t,
        size: size,
        platform: platform,
        child: RaftPanelAction(
          glyph: RaftGlyph.arrowLeft,
          tooltip: 'Back',
          minHitExtent: RaftMetrics.touchTarget,
          onPressed: () => presses++,
        ),
      );
      final expander = t.widget<RaftTouchTargetExpander>(
        find
            .descendant(
              of: find.byType(RaftPanelAction),
              matching: find.byType(RaftTouchTargetExpander),
            )
            .first,
      );
      expect(expander.minSize, Size.square(expected));
      final bounds = t.getRect(find.byType(RaftPanelAction));
      await t.tapAt(Offset(bounds.left - 1, bounds.center.dy));
      await t.pump();
      expect(presses, expected > 0 ? 1 : 0);
      await t.tapAt(bounds.center);
      await t.pump();
      expect(presses, expected > 0 ? 2 : 1);
    });
  }
}
