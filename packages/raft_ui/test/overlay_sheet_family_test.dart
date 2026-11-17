import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;

// WP-DS2 sheet family: the phone form sheet follows raft-ui 0.95.3 Drawer
// (layer-popover fill, ring + float shadow, 16px top radius, 36x4 line-seam
// handle, ease-slide 240/180ms) and Web NarrowDialog's sheet head (close X at
// the start, title, commit at the end, a seam, no footer).

const _opener = ValueKey('open');

/// No motion: one frame, never a zero-length animation (a route popped during
/// build must not notify synchronously).
const _frame = Duration(milliseconds: 1);
final _mark = find.byKey(const ValueKey('raft-sheet-handle'));

Color _color(WidgetTester tester, String name) =>
    RaftTokens.of(tester.element(find.byType(Scaffold).first)).colors[name]!;

Widget _app({
  bool dark = false,
  bool reduceMotion = false,
  required Future<void> Function(BuildContext) open,
  TargetPlatform? platform,
}) => MaterialApp(
  theme: raftTheme(dark: dark, platform: platform),
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: home!,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          key: _opener,
          onPressed: () => open(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _form(BuildContext context) => RaftFormDialog(
  title: 'Create channel',
  submitLabel: 'Save',
  fields: const [RaftFormField('name', 'Name')],
  onSubmit: (_) async {},
);

RaftPresentedRoute<void>? _route;

Future<void> _openForm(
  WidgetTester tester, {
  bool dark = false,
  bool reduceMotion = false,
  bool settle = true,
  bool dismissible = true,
  bool dragDismissible = true,
  WidgetBuilder? builder,
  TargetPlatform? platform,
}) async {
  await tester.pumpWidget(
    _app(
      dark: dark,
      reduceMotion: reduceMotion,
      platform: platform,
      open: (context) async {
        final route = raftFormRoute<void>(
          context,
          builder: builder ?? _form,
          guardUnsaved: false,
          dismissible: dismissible,
          dragDismissible: dragDismissible,
        );
        _route = route;
        await Navigator.of(context, rootNavigator: true).push(route);
      },
    ),
  );
  await tester.tap(find.byKey(_opener));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Finder get _surface => find.byType(RaftSheetSurface);

Material _material(WidgetTester tester) => tester.widget<Material>(
  find.descendant(of: _surface, matching: find.byType(Material)).first,
);

Future<void> _pumpSurface(WidgetTester tester, {bool dark = false}) async {
  _size(tester, const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: const Scaffold(
        body: RaftSheetSurface(
          height: 400,
          child: RaftSheet.fixed(child: SizedBox.expand()),
        ),
      ),
    ),
  );
}

void main() {
  leakDebt(const ['CurvedAnimation']);

  group('drawer surface', () {
    for (final dark in [false, true]) {
      testWidgets('Raft look ${dark ? 'dark' : 'light'}: layer-popover fill, '
          'ring + float shadow, 16px top radius', (tester) async {
        await _pumpSurface(tester, dark: dark);
        final material = _material(tester);
        expect(material.color, _color(tester, 'layer-popover'));
        final shape = material.shape as RoundedRectangleBorder;
        expect(
          shape.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(16)),
        );
        final decorated = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: _surface,
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .expand((d) => d.boxShadow ?? const <BoxShadow>[])
            .toList();
        expect(decorated, isNotEmpty, reason: 'shadow-float');
        expect(
          decorated.any(
            (s) =>
                s.color == _color(tester, 'line-seam') && s.spreadRadius == 1,
          ),
          isTrue,
          reason: 'ring-1 ring-line-seam',
        );
      });
    }
  });

  group('handle', () {
    testWidgets('Raft look: a 16px box with the 36x4 line-seam mark at y=6', (
      tester,
    ) async {
      await _pumpSurface(tester);
      final box = find.byType(RaftSheetHandle);
      expect(tester.getSize(box).height, 16);
      expect(tester.getSize(_mark), const Size(36, 4));
      expect(tester.getTopLeft(_mark).dy - tester.getTopLeft(box).dy, 6);
      final mark = tester.widget<DecoratedBox>(
        find.descendant(of: _mark, matching: find.byType(DecoratedBox)),
      );
      expect(
        (mark.decoration as BoxDecoration).color,
        _color(tester, 'line-seam'),
      );
    });

    for (final size in const [
      (Size(390, 844), TargetPlatform.linux),
      (Size(390, 844), TargetPlatform.android),
    ]) {
      testWidgets('the drag target of a presented sheet is at least 44dp tall '
          '(${size.$1.width.toInt()}, ${size.$2.name})', (tester) async {
        _size(tester, size.$1);
        await _openForm(tester, platform: size.$2);
        final drag = find.ancestor(
          of: _mark,
          matching: find.byWidgetPredicate(
            (w) => w is GestureDetector && w.onVerticalDragUpdate != null,
          ),
        );
        expect(drag, findsOneWidget);
        expect(tester.getSize(drag).height, greaterThanOrEqualTo(44));
      });
    }
  });

  group('presented sheet route', () {
    testWidgets('the scrim is layer-backdrop', (tester) async {
      _size(tester, const Size(390, 844));
      await _openForm(tester, dark: true);
      final box = tester.widget<RaftRecipeBox>(
        find.descendant(
          of: find.byType(RaftDialogBarrier),
          matching: find.byType(RaftRecipeBox),
        ),
      );
      final t = RaftTokens.of(tester.element(find.byType(RaftFormSheet)));
      expect(
        box.style.backgroundColor?.resolve(t.recipeTokens),
        t.colors['layer-backdrop'],
      );
    });

    testWidgets('the route paints the drawer fill, not the panel', (
      tester,
    ) async {
      _size(tester, const Size(390, 844));
      await _openForm(tester, dark: true);
      final t = RaftTokens.of(tester.element(find.byType(RaftFormSheet)));
      final sheet = find.ancestor(
        of: find.byType(RaftFormSheet),
        matching: find.byType(Material),
      );
      final fills = tester
          .widgetList<Material>(sheet)
          .map((m) => m.color)
          .whereType<Color>();
      expect(fills, contains(t.colors['layer-popover']));
      expect(fills, isNot(contains(t.panel)));
    });

    testWidgets('opens in 240ms and closes in 180ms on ease-slide', (
      tester,
    ) async {
      _size(tester, const Size(390, 844));
      await _openForm(tester);
      final route = _route!;
      expect(route.transitionDuration, const Duration(milliseconds: 240));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 180),
      );
      expect(route.sheetAnimationStyle?.curve, RaftEase.slide);
      expect(route.sheetAnimationStyle?.reverseCurve, RaftEase.slide);
    });

    testWidgets('reduced motion has no sheet motion', (tester) async {
      _size(tester, const Size(390, 844));
      await _openForm(tester, reduceMotion: true);
      expect(_route!.transitionDuration, _frame);
      expect(_route!.reverseTransitionDuration, _frame);
    });

    testWidgets('a presented dialog form has no fade or scale', (tester) async {
      _size(tester, const Size(1280, 800));
      await _openForm(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 20));
      final content = find.byType(RaftFormDialog);
      expect(content, findsOneWidget);
      expect(_route!.transitionDuration, _frame);
      expect(
        find.ancestor(of: content, matching: find.byType(ScaleTransition)),
        findsNothing,
      );
      final fades = tester.widgetList<FadeTransition>(
        find.ancestor(of: content, matching: find.byType(FadeTransition)),
      );
      expect(fades.where((f) => f.opacity.value < 1), isEmpty);
    });
  });

  group('sheet head', () {
    final head = find.byKey(const ValueKey('raft-form-sheet-head'));
    final seam = find.byKey(const ValueKey('raft-form-sheet-head-seam'));

    testWidgets('close X at the start, title, commit at the end, a seam, '
        'no footer and no Cancel', (tester) async {
      _size(tester, const Size(390, 844));
      await _openForm(tester);
      expect(find.byType(RaftFormSheet), findsOneWidget);
      expect(head, findsOneWidget);
      expect(tester.getSize(head).height, 56);
      expect(seam, findsOneWidget);
      final close = find.descendant(
        of: head,
        matching: find.byType(RaftCloseButton),
      );
      final title = find.descendant(
        of: head,
        matching: find.text('Create channel'),
      );
      final commit = find.descendant(of: head, matching: find.text('Save'));
      expect(close, findsOneWidget);
      expect(title, findsOneWidget);
      expect(commit, findsOneWidget);
      expect(tester.getRect(close).left, lessThan(tester.getRect(title).left));
      expect(
        tester.getRect(title).right,
        lessThanOrEqualTo(tester.getRect(commit).left),
      );
      expect(tester.getRect(commit).right, lessThanOrEqualTo(390));
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Save'), findsOneWidget, reason: 'one commit only');
    });

    testWidgets('the body has 16px padding on the sides and below the seam', (
      tester,
    ) async {
      _size(tester, const Size(390, 844));
      await _openForm(tester);
      final field = find.byType(TextFormField).first;
      expect(tester.getRect(field).left, 16);
      expect(tester.getRect(field).right, 390 - 16);
      expect(
        tester.getRect(field).top - tester.getRect(seam).bottom,
        greaterThanOrEqualTo(16),
      );
    });

    testWidgets('the commit in the head submits the form', (tester) async {
      _size(tester, const Size(390, 844));
      Map<String, String>? sent;
      await _openForm(
        tester,
        builder: (_) => RaftFormDialog(
          title: 'Create channel',
          submitLabel: 'Save',
          fields: const [RaftFormField('name', 'Name')],
          onSubmit: (values) async => sent = values,
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'general');
      await tester.tap(find.descendant(of: head, matching: find.text('Save')));
      await tester.pumpAndSettle();
      expect(sent, {'name': 'general'});
    });

    testWidgets('the X closes the sheet', (tester) async {
      _size(tester, const Size(390, 844));
      await _openForm(tester);
      await tester.tap(
        find.descendant(of: head, matching: find.byType(RaftCloseButton)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RaftFormSheet), findsNothing);
    });

    testWidgets('the drag handle stays above the head', (tester) async {
      _size(tester, const Size(390, 844));
      await _openForm(tester);
      expect(_mark, findsOneWidget);
      expect(
        tester.getBottomLeft(_mark).dy,
        lessThan(tester.getTopLeft(head).dy),
      );
    });

    testWidgets('a dialog from 768 keeps its card, no sheet head', (
      tester,
    ) async {
      for (final size in const [Size(856, 944), Size(944, 856)]) {
        _size(tester, size);
        await _openForm(tester, platform: TargetPlatform.android);
        expect(find.byType(RaftFormSheet), findsNothing);
        expect(head, findsNothing);
        expect(find.text('Cancel'), findsOneWidget);
        Navigator.of(tester.element(find.byType(RaftFormDialog))).pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a sheet with only a footer keeps the footer', (tester) async {
      _size(tester, const Size(390, 844));
      await _openForm(
        tester,
        builder: (context) => RaftFormSheet(
          title: 'Rename',
          onClose: () => Navigator.pop(context),
          body: const Text('body'),
          footer: const Text('footer action'),
        ),
      );
      expect(head, findsNothing);
      expect(find.text('footer action'), findsOneWidget);
    });

    testWidgets('a step dialog that no pointer may close still closes by X '
        'and ignores the drag', (tester) async {
      _size(tester, const Size(390, 844));
      await _openForm(tester, dismissible: false, dragDismissible: false);
      final top = tester.getTopLeft(_mark).dy;
      await tester.fling(_mark, const Offset(0, 700), 2500);
      await tester.pumpAndSettle();
      expect(find.byType(RaftFormSheet), findsOneWidget);
      expect(tester.getTopLeft(_mark).dy, moreOrLessEquals(top, epsilon: 1));
      await tester.tap(
        find.descendant(of: head, matching: find.byType(RaftCloseButton)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RaftFormSheet), findsNothing);
    });
  });

  // raft-ui `DrawerClose` (drawer.mjs:110-131, recipe closeButton/closeIcon):
  // a ghost bar button, 44 with radius 10 and a 22px X by touch or in a narrow
  // window, 28 / radius 6 / 18px X with a mouse from 768. The caller places it
  // (Web MessageSelectTextDrawer: on the title row).
  group('drawer close', () {
    for (final (name, size, platform, box, icon) in [
      (
        '856x944 touch',
        const Size(856, 944),
        TargetPlatform.android,
        44.0,
        22.0,
      ),
      (
        '944x856 touch',
        const Size(944, 856),
        TargetPlatform.android,
        44.0,
        22.0,
      ),
      ('390x844 mouse', const Size(390, 844), TargetPlatform.linux, 44.0, 22.0),
      (
        '1280x800 mouse',
        const Size(1280, 800),
        TargetPlatform.linux,
        28.0,
        18.0,
      ),
    ]) {
      testWidgets('$name: a ${box.toInt()}px button with a ${icon.toInt()}px X '
          'that closes', (tester) async {
        _size(tester, size);
        var closed = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            home: Scaffold(
              body: Center(child: RaftSheetClose(onPressed: () => closed++)),
            ),
          ),
        );
        final close = find.byType(RaftSheetClose);
        expect(tester.getSize(close), Size(box, box));
        final x = tester.widget<RaftIcon>(
          find.descendant(of: close, matching: find.byType(RaftIcon)),
        );
        expect(x.glyph, RaftGlyph.x);
        expect(x.size, icon);
        expect(find.bySemanticsLabel('Close'), findsOneWidget);
        await tester.tap(close);
        expect(closed, 1);
      });
    }
  });
}
