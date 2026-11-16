// WP-DS2 `toast` group: the toast, lightbox and text-selection-toolbar
// families follow raft-ui 0.95.3 (Web v1.24) in the Raft look.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _mouseSize = Size(390, 844);
const _wide = Size(1280, 800);
const _foldA = Size(856, 944);
const _foldB = Size(944, 856);

ThemeData _theme({
  bool dark = false,
  TargetPlatform platform = TargetPlatform.linux,
}) => raftTheme(dark: dark).copyWith(platform: platform);

Future<void> _view(WidgetTester t, Size size) async {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<RaftToastController> _toastHost(
  WidgetTester t, {
  Size size = _mouseSize,
  bool dark = false,
  TargetPlatform platform = TargetPlatform.linux,
  bool reduceMotion = false,
}) async {
  await _view(t, size);
  final controller = RaftToastController();
  addTearDown(controller.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: _theme(dark: dark, platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(body: RaftToastPortal(controller: controller)),
    ),
  );
  return controller;
}

Color _onHud(WidgetTester t) =>
    RaftTokens.of(t.element(find.byType(RaftToast))).ui['foreground-on-hud'];

Future<void> _settle(WidgetTester t) async {
  // The first frame after a change starts the 220ms motion at zero.
  await t.pump(const Duration(milliseconds: 300));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  group('toast', () {
    for (final (tone, glyph) in [
      (RaftToastRecipeTone.success, RaftGlyph.checkCircle2),
      (RaftToastRecipeTone.info, RaftGlyph.info),
      (RaftToastRecipeTone.error, RaftGlyph.alertTriangle),
      (RaftToastRecipeTone.warning, RaftGlyph.alertTriangle),
    ]) {
      testWidgets(
        '${tone.name}: a 16px glyph in a 20px cell, no status pixel',
        (t) async {
          final c = await _toastHost(t);
          c.show('Saved', tone: tone);
          await _settle(t);
          expect(find.byType(RaftStatus), findsNothing);
          final icon = find.descendant(
            of: find.byType(RaftToast),
            matching: find.byType(RaftIcon),
          );
          expect(icon, findsOneWidget);
          final w = t.widget<RaftIcon>(icon);
          expect(w.glyph, glyph);
          expect(w.size, 16);
          expect(w.color, _onHud(t));
          final cell = find.ancestor(
            of: icon,
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.width == 20 && w.height == 20,
            ),
          );
          expect(cell, findsOneWidget);
          c.clear();
        },
      );
    }

    testWidgets('title-only toast reads the recipe: 44 high, 16/12 padding', (
      t,
    ) async {
      final c = await _toastHost(t);
      c.show('Copied', dismissible: false);
      await _settle(t);
      final box = t.getRect(find.byType(RaftToast));
      expect(box.height, 44);
      expect(box.width, greaterThanOrEqualTo(112));
      // Three grid tracks: the label starts 16 from the left, the two empty
      // tracks keep 12 + 12 on the right (see overlay_family_followup_test).
      expect(t.getRect(find.text('Copied')).left - box.left, 16);
      expect(t.getRect(find.text('Copied')).top - box.top, 12);
      c.clear();
    });

    testWidgets('with a description the icon starts at the first line', (
      t,
    ) async {
      final c = await _toastHost(t);
      c.show('Saved', description: 'All changes are stored');
      await _settle(t);
      final icon = find.descendant(
        of: find.byType(RaftToast),
        matching: find.byType(RaftIcon),
      );
      final cell = t.getRect(
        find.ancestor(
          of: icon,
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 20 && w.height == 20,
          ),
        ),
      );
      expect(cell.top, t.getRect(find.text('Saved')).top);
      expect(
        t.getRect(find.text('All changes are stored')).top,
        greaterThan(t.getRect(find.text('Saved')).top),
      );
      c.clear();
    });

    for (final dark in [false, true]) {
      testWidgets('description is on-hud at 70% (dark=$dark)', (t) async {
        final c = await _toastHost(t, dark: dark);
        c.show('Saved', description: 'Details');
        await _settle(t);
        final style = t.widget<Text>(find.text('Details')).style!;
        expect(style.color, _onHud(t).withValues(alpha: .7));
        c.clear();
      });
    }

    testWidgets('close shows only when the caller opts in', (t) async {
      final c = await _toastHost(t);
      final close = find.byKey(const Key('toast-close'));
      final icon = find.descendant(
        of: find.byType(RaftToast),
        matching: find.byType(RaftIcon),
      );
      c.show('plain');
      await _settle(t);
      expect(close, findsNothing);
      expect(icon, findsOneWidget, reason: 'a plain toast keeps its mark');
      c.show('opted in', dismissible: true);
      await _settle(t);
      expect(close, findsOneWidget);
      expect(icon, findsNWidgets(2));
      await t.tap(close);
      await _settle(t);
      expect(find.byType(RaftToast), findsNothing);
      // The selection toast (`dismissible: false`) has neither mark nor X.
      c.show('Copied', dismissible: false);
      await _settle(t);
      expect(close, findsNothing);
      expect(icon, findsNothing);
      // `icon: false` alone drops only the mark.
      c.show('no mark', icon: false);
      await _settle(t);
      expect(icon, findsNothing);
      expect(find.byType(RaftToast), findsOneWidget);
      c.clear();
    });

    testWidgets('lasts 5s, or 8s with an action or an error', (t) async {
      final c = await _toastHost(t);
      Future<void> expectLasts(Duration d) async {
        await t.pump(d - const Duration(milliseconds: 100));
        expect(find.byType(RaftToast), findsOneWidget);
        await t.pump(const Duration(milliseconds: 200));
        await _settle(t);
        expect(find.byType(RaftToast), findsNothing);
      }

      c.show('plain');
      await expectLasts(const Duration(seconds: 5));
      c.show('bad', tone: RaftToastRecipeTone.error);
      await expectLasts(const Duration(seconds: 8));
      c.show('with action', actionLabel: 'Undo', onAction: () {});
      await expectLasts(const Duration(seconds: 8));
      c.show('explicit', duration: const Duration(seconds: 2));
      await expectLasts(const Duration(seconds: 2));
    });

    testWidgets('action underlines on hover only and tints when pressed', (
      t,
    ) async {
      final c = await _toastHost(t);
      var done = 0;
      c.show('Removed', actionLabel: 'Undo', onAction: () => done++);
      await _settle(t);
      TextDecoration? decoration() => t
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('toast-action')),
              matching: find.text('Undo'),
            ),
          )
          .style
          ?.decoration;
      expect(decoration(), isNot(TextDecoration.underline));
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(t.getCenter(find.byKey(const Key('toast-action'))));
      await t.pump();
      expect(decoration(), TextDecoration.underline);
      await mouse.down(t.getCenter(find.byKey(const Key('toast-action'))));
      await t.pump();
      final tint = _onHud(t).withValues(alpha: .15);
      expect(
        find.descendant(
          of: find.byKey(const Key('toast-action')),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == tint,
          ),
        ),
        findsOneWidget,
      );
      await mouse.up();
      await t.pump();
      expect(done, 1);
      await mouse.removePointer();
    });

    testWidgets('keyboard focus rings the action', (t) async {
      final c = await _toastHost(t);
      c.show('Removed', actionLabel: 'Undo', onAction: () {});
      await _settle(t);
      // The toast root is the first tab stop, the action the second.
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      final ring = find.descendant(
        of: find.byKey(const Key('toast-action')),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).border ==
                  Border.all(color: _onHud(t), width: 2),
        ),
      );
      expect(ring, findsOneWidget);
      c.clear();
    });

    testWidgets('Escape closes a focused toast without running the action', (
      t,
    ) async {
      final c = await _toastHost(t);
      var done = 0;
      c.show('Removed', actionLabel: 'Undo', onAction: () => done++);
      await _settle(t);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(t);
      expect(find.byType(RaftToast), findsNothing);
      expect(done, 0);
    });

    for (final (name, size, platform) in [
      ('856x944 touch', _foldA, TargetPlatform.android),
      ('944x856 touch', _foldB, TargetPlatform.android),
    ]) {
      testWidgets('$name: a downward swipe dismisses, never the action', (
        t,
      ) async {
        final c = await _toastHost(t, size: size, platform: platform);
        var done = 0;
        c.show('Removed', actionLabel: 'Undo', onAction: () => done++);
        await _settle(t);
        await t.fling(find.byType(RaftToast), const Offset(0, 120), 1500);
        await _settle(t);
        expect(find.byType(RaftToast), findsNothing);
        expect(done, 0);
        c.show('Removed again', actionLabel: 'Undo', onAction: () => done++);
        await _settle(t);
        await t.fling(find.byType(RaftToast), const Offset(160, 0), 1500);
        await _settle(t);
        expect(find.byType(RaftToast), findsNothing);
        expect(done, 0);
        c.show('Slow drag', actionLabel: 'Undo', onAction: () => done++);
        await _settle(t);
        await t.drag(find.byType(RaftToast), const Offset(0, 6));
        await _settle(t);
        expect(find.byType(RaftToast), findsOneWidget, reason: 'small drag');
        c.clear();
      });
    }

    testWidgets('390x844 mouse: dragging does not dismiss', (t) async {
      final c = await _toastHost(t);
      c.show('Stays');
      await _settle(t);
      await t.fling(
        find.byType(RaftToast),
        const Offset(0, 120),
        1500,
        warnIfMissed: false,
      );
      await _settle(t);
      expect(find.byType(RaftToast), findsOneWidget);
      c.clear();
    });

    double opacityOf(WidgetTester t) => t
        .widgetList<FadeTransition>(
          find.descendant(
            of: find.byType(RaftToastPortal),
            matching: find.byType(FadeTransition),
          ),
        )
        .map((w) => w.opacity.value)
        .reduce((a, b) => a < b ? a : b);

    testWidgets('enters and leaves with opacity and scale', (t) async {
      final c = await _toastHost(t);
      c.show('Hello');
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(opacityOf(t), allOf(greaterThan(0), lessThan(1)));
      await _settle(t);
      expect(opacityOf(t), 1);
      c.clear();
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(find.byType(RaftToast), findsOneWidget, reason: 'still leaving');
      expect(opacityOf(t), allOf(greaterThan(0), lessThan(1)));
      await _settle(t);
      expect(find.byType(RaftToast), findsNothing);
    });

    testWidgets('reduced motion: no fade', (t) async {
      final c = await _toastHost(t, reduceMotion: true);
      c.show('Hello');
      await t.pump();
      await t.pump(const Duration(milliseconds: 1));
      expect(opacityOf(t), 1);
      c.clear();
      await t.pump();
      expect(find.byType(RaftToast), findsNothing);
    });

    group('above the composer', () {
      Future<void> mount(WidgetTester t, Size size, {bool dock = true}) async {
        await _view(t, size);
        await t.pumpWidget(
          MaterialApp(
            theme: _theme(),
            builder: (context, child) => RaftToastHost(child: child!),
            home: Scaffold(
              body: Column(
                children: [
                  const Expanded(child: SizedBox.expand()),
                  if (dock)
                    RaftComposer(onSend: (_) async => true)
                  else
                    const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
        await t.pump();
      }

      testWidgets('1280x800 mouse: a docked composer lifts the toast', (
        t,
      ) async {
        await mount(t, _wide);
        showRaftToast(t.element(find.byType(RaftComposer)), 'Saved');
        await _settle(t);
        final toast = t.getRect(find.byType(RaftToast));
        final composer = t.getRect(find.byType(RaftComposer));
        expect(toast.overlaps(composer), isFalse);
        expect(toast.bottom, lessThanOrEqualTo(composer.top - 8));
      });

      testWidgets('1280x800: no composer, the toast stays 16px up', (t) async {
        await mount(t, _wide, dock: false);
        final context = t.element(find.byType(Scaffold));
        showRaftToast(context, 'Saved');
        await _settle(t);
        expect(t.getRect(find.byType(RaftToast)).bottom, 800 - 16);
      });

      testWidgets('856x944 touch: lifted above the composer too', (t) async {
        await mount(t, _foldA);
        showRaftToast(t.element(find.byType(RaftComposer)), 'Saved');
        await _settle(t);
        expect(
          t.getRect(find.byType(RaftToast)).bottom,
          lessThanOrEqualTo(t.getRect(find.byType(RaftComposer)).top - 8),
        );
      });
    });
  });

  group('lightbox', () {
    // (name, size, platform, header height, action box)
    final modes = [
      ('1280x800 mouse', _wide, TargetPlatform.linux, 44.0, 34.0),
      ('390x844 mouse', _mouseSize, TargetPlatform.linux, 56.0, 44.0),
      ('856x944 touch', _foldA, TargetPlatform.android, 56.0, 44.0),
      ('944x856 touch', _foldB, TargetPlatform.android, 56.0, 44.0),
    ];

    Future<void> mountHeader(
      WidgetTester t,
      Size size,
      TargetPlatform platform, {
      Widget? leading,
      Widget? meta,
      double scale = 1,
      bool dark = false,
    }) async {
      await _view(t, size);
      await t.pumpWidget(
        MaterialApp(
          theme: _theme(platform: platform, dark: dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: RaftLightboxHeader(
                title: 'IMG_2041.jpg',
                leading: leading,
                meta: meta,
                onClose: () {},
                actions: [
                  RaftLightboxIconAction(
                    key: const Key('a1'),
                    glyph: RaftGlyph.copy,
                    label: 'Copy',
                    onPressed: () {},
                  ),
                  RaftLightboxIconAction(
                    key: const Key('a2'),
                    glyph: RaftGlyph.download,
                    label: 'Download',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    for (final (name, size, platform, height, action) in modes) {
      testWidgets(
        '$name: toolbar $height high, 1px seam, $action actions at 4px',
        (t) async {
          await mountHeader(t, size, platform);
          final header = find.byType(RaftLightboxHeader);
          expect(t.getSize(header).height, height);
          final tk = RaftTokens.of(t.element(header));
          final bar = t.widget<DecoratedBox>(
            find
                .descendant(of: header, matching: find.byType(DecoratedBox))
                .first,
          );
          final decoration = bar.decoration as BoxDecoration;
          expect(decoration.color, tk.colors['layer-canvas']);
          final border = decoration.border! as Border;
          expect(border.bottom.width, 1);
          expect(border.bottom.color, tk.colors['line-seam']);
          final a1 = t.getRect(find.byKey(const Key('a1')));
          final a2 = t.getRect(find.byKey(const Key('a2')));
          expect(a1.size, Size.square(action));
          expect(a2.size, Size.square(action));
          expect(a2.left - a1.right, 4);
          final close = t.getRect(find.byType(RaftLightboxIconAction).last);
          expect(close.left - a2.right, 4);
        },
      );
    }

    testWidgets('the counter is an outline badge with tabular figures', (
      t,
    ) async {
      await mountHeader(
        t,
        _wide,
        TargetPlatform.linux,
        meta: const RaftLightboxCounter(index: 1, count: 12),
      );
      final badge = t.widget<RaftBadge>(find.byType(RaftBadge));
      expect(badge.appearance, RaftBadgeRecipeAppearance.outline);
      // Outline badges set their figures in the mono face (tabular).
      final tk = RaftTokens.of(t.element(find.byType(RaftBadge)));
      final text = t.widget<Text>(find.text('2 / 12'));
      expect(
        text.style!.fontFamily,
        tk.scale(RaftTypeScale.monoMeta, mono: true).fontFamily,
      );
    });

    testWidgets('the image lightbox header keeps a 1px seam', (t) async {
      await _view(t, _wide);
      await t.pumpWidget(
        MaterialApp(
          theme: _theme(),
          home: RaftAttachmentLightbox(
            title: 'IMG_2041.jpg',
            onClose: () {},
            child: const SizedBox.expand(),
          ),
        ),
      );
      final header = find.byType(RaftLightboxHeader);
      final bar = t.widget<DecoratedBox>(
        find.descendant(of: header, matching: find.byType(DecoratedBox)).first,
      );
      expect(
        ((bar.decoration as BoxDecoration).border! as Border).bottom.width,
        1,
      );
      expect(t.getSize(header).height, 44);
    });

    testWidgets('the preview shell leads with the 32x16 type badge', (t) async {
      await _view(t, _wide);
      await t.pumpWidget(
        MaterialApp(
          theme: _theme(),
          home: RaftAttachmentPreviewShell(
            filename: 'notes.txt',
            onClose: () {},
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(t.getSize(find.byType(RaftFileTypeBadge)), const Size(32, 16));
    });

    testWidgets('the header label chip is gone in the Raft look', (t) async {
      await mountHeader(
        t,
        _wide,
        TargetPlatform.linux,
        leading: const RaftFileTypeBadge(
          filename: 'research.md',
          headerLabel: true,
        ),
      );
      expect(t.getSize(find.byType(RaftFileTypeBadge)).height, 16);
    });

    testWidgets('comments aside: canvas fill, 1px line-seam border', (t) async {
      await _view(t, _wide);
      await t.pumpWidget(
        MaterialApp(
          theme: _theme(),
          home: const Scaffold(
            body: Row(children: [RaftLightboxAside(child: Text('panel'))]),
          ),
        ),
      );
      final tk = RaftTokens.of(t.element(find.byType(RaftLightboxAside)));
      final box = t.widget<Container>(
        find
            .descendant(
              of: find.byType(RaftLightboxAside),
              matching: find.byType(Container),
            )
            .first,
      );
      final d = box.decoration! as BoxDecoration;
      expect(d.color, tk.colors['layer-canvas']);
      final border = d.border! as Border;
      expect(border.left.width, 1);
      expect(border.left.color, tk.colors['line-seam']);
    });

    testWidgets('failure tile: on-hud at 70%, 36px icon', (t) async {
      await _view(t, _wide);
      await t.pumpWidget(
        MaterialApp(
          theme: _theme(),
          home: const Scaffold(
            body: RaftLightboxFailure(title: 'a.png', message: 'Failed'),
          ),
        ),
      );
      final tk = RaftTokens.of(t.element(find.byType(RaftLightboxFailure)));
      final icon = t.widget<RaftIcon>(find.byType(RaftIcon));
      expect(icon.size, 36);
      expect(icon.color, tk.ui['foreground-on-hud'].withValues(alpha: .7));
    });

    group('thumbnail strip', () {
      Future<void> mountStrip(WidgetTester t, {int index = 1}) async {
        await _view(t, _wide);
        await t.pumpWidget(
          MaterialApp(
            theme: _theme(),
            home: Material(
              color: Colors.black,
              child: RaftMediaStrip(
                items: [
                  for (var i = 0; i < 3; i++)
                    RaftMediaStripItem(label: 'Item ${i + 1}'),
                ],
                index: index,
                onSelect: (_) {},
              ),
            ),
          ),
        );
      }

      BoxDecoration decorationOf(WidgetTester t, int i) {
        final box = find.descendant(
          of: find.byKey(ValueKey('lightbox-thumbnail-$i')),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).border != null,
          ),
        );
        return t.widget<Container>(box.first).decoration! as BoxDecoration;
      }

      testWidgets('4px radius, 1.5px border, selected ring on the active one', (
        t,
      ) async {
        await mountStrip(t);
        final tk = RaftTokens.of(t.element(find.byType(RaftMediaStrip)));
        final active = decorationOf(t, 1);
        expect(active.borderRadius, BorderRadius.circular(4));
        final border = active.border! as Border;
        expect(border.top.width, 1.5);
        expect(border.top.color, tk.colors['selected']);
        expect(active.boxShadow, hasLength(1));
        expect(active.boxShadow!.single.spreadRadius, 1.5);
        expect(active.boxShadow!.single.color, tk.colors['sticker-ink']);
        final idle = decorationOf(t, 0);
        expect(idle.borderRadius, BorderRadius.circular(4));
        expect(
          (idle.border! as Border).top.color,
          tk.ui['foreground-on-hud'].withValues(alpha: .3),
        );
        expect(idle.boxShadow, anyOf(isNull, isEmpty));
      });

      testWidgets('an idle thumbnail rises to full opacity on hover', (
        t,
      ) async {
        await mountStrip(t);
        double opacity() => t
            .widgetList<Opacity>(
              find.descendant(
                of: find.byKey(const ValueKey('lightbox-thumbnail-0')),
                matching: find.byType(Opacity),
              ),
            )
            .map((o) => o.opacity)
            .fold(1.0, (a, b) => a * b);
        expect(opacity(), closeTo(.6, 1e-6));
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(
          t.getCenter(find.byKey(const ValueKey('lightbox-thumbnail-0'))),
        );
        await t.pump(const Duration(milliseconds: 200));
        expect(opacity(), 1);
        expect(
          (decorationOf(t, 0).border! as Border).top.color,
          RaftTokens.of(t.element(find.byType(RaftMediaStrip)))
              .ui['foreground-on-hud']
              .withValues(alpha: .6),
        );
        await mouse.removePointer();
      });

      testWidgets('the number tile is mono', (t) async {
        await mountStrip(t);
        final tk = RaftTokens.of(t.element(find.byType(RaftMediaStrip)));
        final style = t.widget<Text>(find.text('1')).style!;
        expect(
          style.fontFamily,
          tk.scale(RaftTypeScale.monoMeta, mono: true).fontFamily,
        );
      });
    });
  });

  group('text selection shortcut bar', () {
    Future<void> mountBar(
      WidgetTester t,
      Size size,
      TargetPlatform platform,
    ) async {
      await _view(t, size);
      await t.pumpWidget(
        MaterialApp(
          theme: _theme(platform: platform),
          home: Scaffold(
            body: Stack(
              children: [
                RaftSelectionShortcutBar(
                  anchors: const TextSelectionToolbarAnchors(
                    primaryAnchor: Offset(200, 300),
                  ),
                  onQuote: () {},
                  onCopy: () {},
                ),
              ],
            ),
          ),
        ),
      );
    }

    for (final (name, size, platform, button) in [
      ('1280x800 mouse', _wide, TargetPlatform.linux, 34.0),
      ('390x844 mouse', _mouseSize, TargetPlatform.linux, 28.0),
      ('856x944 touch', _foldA, TargetPlatform.android, 28.0),
      ('944x856 touch', _foldB, TargetPlatform.android, 28.0),
    ]) {
      testWidgets('$name: buttons $button high, p-1 frame, 1x20 separator', (
        t,
      ) async {
        await mountBar(t, size, platform);
        final tk = RaftTokens.of(
          t.element(find.byType(RaftSelectionShortcutBar)),
        );
        expect(
          t.getSize(find.byKey(const Key('selection-shortcut-quote'))).height,
          button,
        );
        final frame = t.getRect(
          find.byKey(const Key('selection-shortcut-frame')),
        );
        final quote = t.getRect(
          find.byKey(const Key('selection-shortcut-quote')),
        );
        expect(quote.left - frame.left, 4);
        expect(quote.top - frame.top, 4);
        final frameBox = t.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(const Key('selection-shortcut-frame')),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = frameBox.decoration is RaftLayeredDecoration
            ? (frameBox.decoration as RaftLayeredDecoration).base
            : frameBox.decoration as BoxDecoration;
        expect(decoration.color, tk.colors['layer-popover']);
        expect(decoration.borderRadius, BorderRadius.circular(10));
        final sep = t.getSize(
          find.byKey(const Key('selection-shortcut-separator')),
        );
        expect(sep, const Size(1, 20));
        final label = t.widget<Text>(find.text('Quote')).style!;
        expect(label.fontWeight, FontWeight.w700);
      });
    }

    testWidgets('hover fills the button with fill-medium', (t) async {
      await mountBar(t, _wide, TargetPlatform.linux);
      final tk = RaftTokens.of(
        t.element(find.byType(RaftSelectionShortcutBar)),
      );
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        t.getCenter(find.byKey(const Key('selection-shortcut-copy'))),
      );
      await t.pump(const Duration(milliseconds: 200));
      final fill = find.descendant(
        of: find.byKey(const Key('selection-shortcut-copy')),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == tk.colors['fill-medium'],
        ),
      );
      expect(fill, findsOneWidget);
      await mouse.removePointer();
    });
  });
}
