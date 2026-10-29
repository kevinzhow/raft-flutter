import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'flutter_test_config.dart' show leakDebt;

// The presentation primitive: which form a floating window takes, decided in
// one place from the window width, and the sheet form's scrolling.

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

/// Content with state of its own, to prove a form switch keeps it.
class _ProbeState extends State<_Probe> {
  final controller = TextEditingController(text: 'draft');
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    child: SizedBox(
      width: 300,
      height: 200,
      child: TextField(controller: controller),
    ),
  );
}

const _opener = ValueKey('open');

Widget _app({
  required RaftPresentationPolicy policy,
  required Widget Function(BuildContext, RaftSurfaceForm) content,
  double keyboard = 0,
  bool fills = false,
  double initialSize = RaftSheetMetrics.largeDetent,
  bool dark = false,
}) => MaterialApp(
  theme: raftTheme(dark: dark),
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
    child: home!,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          key: _opener,
          onPressed: () => showRaftPresented<void>(
            context,
            policy: policy,
            content: content,
            dialogMaxWidth: 400,
            sheetFillsHeight: fills,
            sheetInitialSize: initialSize,
          ),
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

/// The framework's sheet, drawn with the design system's look.
final _sheet = find.byType(BottomSheet);
final _handle = find.byKey(const ValueKey('raft-sheet-handle'));

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_opener));
  await tester.pumpAndSettle();
}

void main() {
  // Flutter 3.47.6: a modal bottom sheet closed by a drag rebinds its animation
  // to a CurvedAnimation (`_ModalBottomSheetState.handleDragEnd`) that nothing
  // disposes.
  leakDebt(const ['CurvedAnimation']);
  group('layout classes', () {
    test('cuts are 768 and 1024', () {
      expect(raftLayoutClassForWidth(0), RaftLayoutClass.compact);
      expect(raftLayoutClassForWidth(390), RaftLayoutClass.compact);
      expect(raftLayoutClassForWidth(767.9), RaftLayoutClass.compact);
      expect(raftLayoutClassForWidth(768), RaftLayoutClass.medium);
      expect(raftLayoutClassForWidth(834), RaftLayoutClass.medium);
      expect(raftLayoutClassForWidth(1023.9), RaftLayoutClass.medium);
      expect(raftLayoutClassForWidth(1024), RaftLayoutClass.wide);
      expect(raftLayoutClassForWidth(1920), RaftLayoutClass.wide);
    });

    test('the compact cut is the app compact predicate', () {
      expect(
        RaftAdaptiveWorkspace.desktopMinWidth,
        RaftLayoutMetrics.desktopBreakpoint,
      );
      expect(
        raftLayoutClassForWidth(RaftAdaptiveWorkspace.desktopMinWidth - 1),
        RaftLayoutClass.compact,
      );
    });
  });

  group('policies', () {
    const sheet = RaftSurfaceForm.sheet,
        dialog = RaftSurfaceForm.dialog,
        side = RaftSurfaceForm.side,
        page = RaftSurfaceForm.page,
        popover = RaftSurfaceForm.popover;
    final table = <String, (RaftPresentationPolicy, List<RaftSurfaceForm>)>{
      'confirm': (RaftPresentationPolicy.confirm, [dialog, dialog, dialog]),
      'form': (RaftPresentationPolicy.form, [sheet, dialog, dialog]),
      'editor': (RaftPresentationPolicy.editor, [sheet, dialog, dialog]),
      'detail': (RaftPresentationPolicy.detail, [page, side, side]),
      'picker': (RaftPresentationPolicy.picker, [sheet, popover, popover]),
      'menu': (RaftPresentationPolicy.menu, [popover, popover, popover]),
      'viewer': (RaftPresentationPolicy.viewer, [page, dialog, dialog]),
    };
    for (final entry in table.entries) {
      test('${entry.key} maps compact, medium, wide', () {
        final (policy, forms) = entry.value;
        for (final (i, layout) in RaftLayoutClass.values.indexed) {
          expect(policy.formFor(layout), forms[i], reason: '${layout.name}');
        }
      });
    }
  });

  group('one route, form follows the live width', () {
    testWidgets('a width picks the frame', (tester) async {
      for (final (size, sheet, dialog) in [
        (const Size(412, 915), true, false),
        (const Size(767, 900), true, false),
        (const Size(768, 900), false, true),
        (const Size(834, 1194), false, true),
        (const Size(1440, 900), false, true),
      ]) {
        _size(tester, size);
        await tester.pumpWidget(
          _app(
            policy: RaftPresentationPolicy.editor,
            content: (context, form) => const _Probe(),
          ),
        );
        await _open(tester);
        expect(_sheet.evaluate().isNotEmpty, sheet, reason: '$size sheet');
        expect(
          find.byType(RaftDialogFrame).evaluate().isNotEmpty,
          dialog,
          reason: '$size dialog',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('crossing the breakpoint switches the form and keeps the '
        'content state', (tester) async {
      _size(tester, const Size(1000, 800));
      final forms = <RaftSurfaceForm>[];
      await tester.pumpWidget(
        _app(
          policy: RaftPresentationPolicy.editor,
          content: (context, form) {
            forms.add(form);
            return const _Probe();
          },
        ),
      );
      await _open(tester);
      final state = tester.state<_ProbeState>(find.byType(_Probe));
      state.controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 3,
      );
      expect(forms.last, RaftSurfaceForm.dialog);
      tester.view.physicalSize = const Size(500, 800);
      await tester.pumpAndSettle();
      expect(forms.last, RaftSurfaceForm.sheet);
      expect(_sheet, findsOneWidget);
      expect(tester.state<_ProbeState>(find.byType(_Probe)), same(state));
      tester.view.physicalSize = const Size(1000, 800);
      await tester.pumpAndSettle();
      expect(forms.last, RaftSurfaceForm.dialog);
      expect(_sheet, findsNothing);
      expect(find.byType(_Probe), findsOneWidget);
      expect(tester.state<_ProbeState>(find.byType(_Probe)), same(state));
      expect(state.controller.text, 'draft');
      expect(
        state.controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 3),
      );
    });

    testWidgets('a detail policy is a page on a phone and a side panel wide', (
      tester,
    ) async {
      _size(tester, const Size(412, 915));
      await tester.pumpWidget(
        _app(
          policy: RaftPresentationPolicy.detail,
          content: (context, form) => const _Probe(),
        ),
      );
      await _open(tester);
      expect(find.byType(RaftPageFrame), findsOneWidget);
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpAndSettle();
      expect(find.byType(RaftSideFrame), findsOneWidget);
      expect(find.byType(RaftPageFrame), findsNothing);
    });

    testWidgets('every form closes with Esc and with Back', (tester) async {
      for (final size in [const Size(412, 915), const Size(1000, 800)]) {
        for (final exit in ['esc', 'back']) {
          _size(tester, size);
          await tester.pumpWidget(
            _app(
              policy: RaftPresentationPolicy.editor,
              content: (context, form) => const _Probe(),
            ),
          );
          await _open(tester);
          expect(find.byType(_Probe), findsOneWidget);
          if (exit == 'esc') {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
          expect(find.byType(_Probe), findsNothing, reason: '$size $exit');
          await tester.pumpWidget(const SizedBox());
        }
      }
    });

    testWidgets('a tap on the scrim closes the sheet and the dialog', (
      tester,
    ) async {
      for (final size in [const Size(412, 915), const Size(1000, 800)]) {
        _size(tester, size);
        await tester.pumpWidget(
          _app(
            policy: RaftPresentationPolicy.editor,
            content: (context, form) => const _Probe(),
          ),
        );
        await _open(tester);
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.byType(_Probe), findsNothing, reason: '$size');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('sheet', () {
    const phone = Size(412, 915);
    // A tall form: pinned title and footer, one scrolling body.
    Widget tall(BuildContext context, RaftSurfaceForm form) => Material(
      child: RaftSheet(
        header: const Center(
          key: ValueKey('sheet-header'),
          child: Text('Title'),
        ),
        headerExtent: 48,
        body: Column(
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 48, child: Text('row $i')),
            const TextField(key: ValueKey('sheet-field')),
            const SizedBox(height: 16),
          ],
        ),
        footer: const SizedBox(
          key: ValueKey('sheet-footer'),
          height: 56,
          child: Center(child: Text('Save')),
        ),
      ),
    );
    final scrollView = find.byType(CustomScrollView);
    ScrollableState scroll(WidgetTester t) => t.state<ScrollableState>(
      find.descendant(of: scrollView, matching: find.byType(Scrollable)).first,
    );

    testWidgets('is the framework modal bottom sheet route, in our look', (
      tester,
    ) async {
      _size(tester, phone);
      await tester.pumpWidget(
        _app(policy: RaftPresentationPolicy.form, content: tall),
      );
      await _open(tester);
      final route = ModalRoute.of(tester.element(find.byType(RaftSheet)));
      expect(route, isA<ModalBottomSheetRoute<void>>());
      expect(route, isA<RaftPresentedRoute<void>>());
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.byType(RaftSheetHandle), findsOneWidget);
    });

    testWidgets('opens at its detent and a drag on the handle takes it to the '
        'large detent', (tester) async {
      _size(tester, phone);
      await tester.pumpWidget(
        _app(
          policy: RaftPresentationPolicy.form,
          content: tall,
          initialSize: RaftSheetMetrics.mediumDetent,
        ),
      );
      await _open(tester);
      expect(
        tester.getSize(_sheet).height,
        closeTo(phone.height * RaftSheetMetrics.mediumDetent, 2),
      );
      await tester.fling(_handle, const Offset(0, -300), 2000);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(_sheet).height,
        closeTo(phone.height * RaftSheetMetrics.largeDetent, 2),
      );
      expect(_sheet, findsOneWidget);
    });

    testWidgets('never wider than 640 on a wide window', (tester) async {
      _size(tester, const Size(700, 900));
      await tester.pumpWidget(
        _app(policy: RaftPresentationPolicy.form, content: tall),
      );
      await _open(tester);
      expect(
        tester.getSize(find.byType(RaftSheet)).width,
        RaftSheetMetrics.maxWidth,
      );
    });

    testWidgets('tall content scrolls, with one vertical scroll region, and '
        'scrolling never closes the sheet', (tester) async {
      _size(tester, phone);
      await tester.pumpWidget(
        _app(policy: RaftPresentationPolicy.form, content: tall),
      );
      await _open(tester);
      final regions = find.descendant(
        of: _sheet,
        // A single-line text field scrolls horizontally; count the vertical
        // regions only.
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.vertical,
        ),
      );
      expect(regions, findsOneWidget);
      expect(scroll(tester).position.pixels, 0);
      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(scroll(tester).position.pixels, greaterThan(200));
      // Back down, still inside the content: the sheet stays.
      await tester.drag(scrollView, const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(scroll(tester).position.pixels, greaterThan(50));
      // A long flick up and down through the content never closes it.
      await tester.fling(scrollView, const Offset(0, -600), 3000);
      await tester.pumpAndSettle();
      await tester.fling(scrollView, const Offset(0, 100), 600);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
    });

    testWidgets('a drag down at the top of the content closes the sheet', (
      tester,
    ) async {
      _size(tester, phone);
      await tester.pumpWidget(
        _app(policy: RaftPresentationPolicy.form, content: tall),
      );
      await _open(tester);
      expect(scroll(tester).position.pixels, 0);
      await tester.fling(scrollView, const Offset(0, 600), 2500);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
    });

    testWidgets('a short pull at the top springs back', (tester) async {
      _size(tester, phone);
      await tester.pumpWidget(
        _app(policy: RaftPresentationPolicy.form, content: tall),
      );
      await _open(tester);
      await tester.drag(scrollView, const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(
        tester.getSize(_sheet).height,
        closeTo(phone.height * RaftSheetMetrics.largeDetent, 2),
      );
    });

    testWidgets('the handle and the pinned header both drag it down', (
      tester,
    ) async {
      _size(tester, phone);
      for (final target in [
        _handle,
        find.byKey(const ValueKey('sheet-header')),
      ]) {
        await tester.pumpWidget(
          _app(policy: RaftPresentationPolicy.form, content: tall),
        );
        await _open(tester);
        await tester.fling(target, const Offset(0, 600), 2500);
        await tester.pumpAndSettle();
        expect(_sheet, findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the header and the footer stay pinned while the body '
        'scrolls', (tester) async {
      _size(tester, phone);
      await tester.pumpWidget(
        _app(policy: RaftPresentationPolicy.form, content: tall),
      );
      await _open(tester);
      final header = find.byKey(const ValueKey('sheet-header'));
      final footer = find.byKey(const ValueKey('sheet-footer'));
      final headerAt = tester.getRect(header),
          footerAt = tester.getRect(footer);
      await tester.drag(scrollView, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(header), headerAt);
      expect(tester.getRect(footer), footerAt);
      expect(footerAt.bottom, lessThanOrEqualTo(phone.height));
      expect(headerAt.top, greaterThan(tester.getRect(_sheet).top));
    });

    testWidgets('a focused field near the bottom is visible above the '
        'keyboard', (tester) async {
      const keyboard = 300.0;
      _size(tester, phone);
      await tester.pumpWidget(
        _app(
          policy: RaftPresentationPolicy.form,
          content: tall,
          keyboard: keyboard,
        ),
      );
      await _open(tester);
      // The content shrank to sit above the keyboard.
      expect(
        tester.getRect(find.byType(RaftSheet)).bottom,
        lessThanOrEqualTo(phone.height - keyboard),
      );
      final field = find.byKey(const ValueKey('sheet-field'));
      await tester.dragUntilVisible(field, scrollView, const Offset(0, -200));
      await tester.tap(field);
      await tester.pumpAndSettle();
      final rect = tester.getRect(field);
      final header = tester.getRect(find.byKey(const ValueKey('sheet-header')));
      expect(rect.bottom, lessThanOrEqualTo(phone.height - keyboard));
      expect(rect.top, greaterThan(header.bottom - 1));
      expect(
        tester.getRect(find.byKey(const ValueKey('sheet-footer'))).bottom,
        lessThanOrEqualTo(phone.height - keyboard),
      );
    });

    // A desktop window narrowed to phone width: scroll views ignore mouse
    // drags on desktop, so the handle and the header move the sheet
    // themselves (Kevin, a mouse drag on the handle did nothing).
    testWidgets(
      'a mouse drag on the handle moves the sheet and lets it settle',
      (tester) async {
        _size(tester, phone);
        await tester.pumpWidget(
          _app(
            policy: RaftPresentationPolicy.form,
            content: tall,
            initialSize: .6,
          ),
        );
        await _open(tester);
        final opened = tester.getTopLeft(_sheet).dy;
        final mouse = await tester.startGesture(
          tester.getCenter(_handle),
          kind: PointerDeviceKind.mouse,
        );
        for (var i = 0; i < 10; i++) {
          await mouse.moveBy(const Offset(0, -20));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.getTopLeft(_sheet).dy, lessThan(opened - 100));
        await mouse.up();
        await tester.pumpAndSettle();
        // Let go near the top: it settles at the large detent.
        expect(
          tester.getSize(_sheet).height,
          closeTo(phone.height * RaftSheetMetrics.largeDetent, 2),
        );
        // The header is a handle too.
        final header = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('sheet-header'))),
          kind: PointerDeviceKind.mouse,
        );
        for (var i = 0; i < 10; i++) {
          await header.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await header.up();
        await tester.pumpAndSettle();
        expect(
          tester.getSize(_sheet).height,
          lessThan(phone.height * RaftSheetMetrics.largeDetent - 100),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    // The handle sits in the body's scroll view: once the body was scrolled
    // (a chat transcript that follows its newest line), a finger on the
    // handle scrolled the text and the sheet never grew (the Agent orb on
    // the G100).
    testWidgets('a finger drag on the handle moves the sheet even when the '
        'body is scrolled', (tester) async {
      _size(tester, phone);
      await tester.pumpWidget(
        _app(policy: RaftPresentationPolicy.form, content: tall, initialSize: .6),
      );
      await _open(tester);
      scroll(tester).position.jumpTo(200);
      await tester.pump();
      final opened = tester.getTopLeft(_sheet).dy;
      final finger = await tester.startGesture(tester.getCenter(_handle));
      for (var i = 0; i < 10; i++) {
        await finger.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.getTopLeft(_sheet).dy, lessThan(opened - 100));
      await finger.up();
      await tester.pumpAndSettle();
      expect(
        tester.getSize(_sheet).height,
        closeTo(phone.height * RaftSheetMetrics.largeDetent, 2),
      );
      expect(scroll(tester).position.pixels, 200);
    });

    group('closing asks the route (Back, drag and scrim alike)', () {
      final popped = <bool>[];
      // The same tall sheet, optionally vetoing every pop.
      Widget guarded(BuildContext context, RaftSurfaceForm form) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) => popped.add(didPop),
        child: tall(context, form),
      );

      setUp(popped.clear);

      testWidgets('a drag down on a guarded sheet snaps back, says '
          'didPop: false and stays open', (tester) async {
        _size(tester, phone);
        await tester.pumpWidget(
          _app(policy: RaftPresentationPolicy.form, content: guarded),
        );
        await _open(tester);
        final opened = tester.getSize(_sheet).height;
        await tester.fling(_handle, const Offset(0, 700), 2500);
        await tester.pumpAndSettle();
        expect(popped, [false]);
        expect(_sheet, findsOneWidget);
        expect(tester.getSize(_sheet).height, closeTo(opened, 2));
        // Asked again, answered again: the sheet keeps coming back.
        await tester.fling(
          find.byKey(const ValueKey('sheet-header')),
          const Offset(0, 700),
          2500,
        );
        await tester.pumpAndSettle();
        expect(popped, [false, false]);
        expect(_sheet, findsOneWidget);
      });

      testWidgets('a mouse drag to the bottom asks the route too', (
        tester,
      ) async {
        _size(tester, phone);
        await tester.pumpWidget(
          _app(policy: RaftPresentationPolicy.form, content: guarded),
        );
        await _open(tester);
        final opened = tester.getSize(_sheet).height;
        final mouse = await tester.startGesture(
          tester.getCenter(_handle),
          kind: PointerDeviceKind.mouse,
        );
        for (var i = 0; i < 30; i++) {
          await mouse.moveBy(const Offset(0, 25));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await mouse.up();
        await tester.pumpAndSettle();
        expect(popped, [false]);
        expect(_sheet, findsOneWidget);
        expect(tester.getSize(_sheet).height, closeTo(opened, 2));
      }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

      testWidgets('a drag down on a sheet that allows the pop closes it, '
          'through the same check', (tester) async {
        _size(tester, phone);
        final asked = <bool>[];
        await tester.pumpWidget(
          _app(
            policy: RaftPresentationPolicy.form,
            content: (context, form) => PopScope(
              canPop: true,
              onPopInvokedWithResult: (didPop, _) => asked.add(didPop),
              child: tall(context, form),
            ),
          ),
        );
        await _open(tester);
        await tester.fling(_handle, const Offset(0, 700), 2500);
        await tester.pumpAndSettle();
        expect(_sheet, findsNothing);
        expect(asked, [true]);
      });

      testWidgets('a scrim tap is answered like the drag', (tester) async {
        _size(tester, phone);
        await tester.pumpWidget(
          _app(policy: RaftPresentationPolicy.form, content: guarded),
        );
        await _open(tester);
        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();
        expect(popped, [false]);
        expect(_sheet, findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          _app(policy: RaftPresentationPolicy.form, content: tall),
        );
        await _open(tester);
        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();
        expect(_sheet, findsNothing);
      });

      testWidgets('Back is answered the same way', (tester) async {
        _size(tester, phone);
        await tester.pumpWidget(
          _app(policy: RaftPresentationPolicy.form, content: guarded),
        );
        await _open(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(popped, [false]);
        expect(_sheet, findsOneWidget);
      });
    });

    testWidgets('brutal and elegant dark draw a handle and stay in the '
        'window', (tester) async {
      for (final (dark) in raftThemeMatrix([(true)])) {
        _size(tester, phone);
        await tester.pumpWidget(
          _app(policy: RaftPresentationPolicy.form, content: tall, dark: dark),
        );
        await _open(tester);
        expect(_handle, findsOneWidget);
        expect(tester.getRect(_sheet).left, 0);
        expect(tester.getRect(_sheet).right, phone.width);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
