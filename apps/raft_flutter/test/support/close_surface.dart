import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'close_support.dart';

/// A way to dismiss a surface.
enum Affordance {
  /// A visible × (close) button.
  x,

  /// A visible Back chevron that leaves the surface.
  back,

  /// The Escape key (desktop / hardware keyboard).
  esc,

  /// A tap on the scrim / outside the surface.
  scrim,

  /// The Android system back gesture / hardware Back.
  systemBack,

  /// Dragging the sheet's handle down (bottom sheets).
  drag,
}

enum SurfaceKind { panel, page, dialog, drawer, popup, viewer, toast }

/// One closable surface and the affordances Web gives it, per width.
///
/// [phone] is 390 wide, [fold] 816 (a wide layout: the compact cut is 768) and
/// [desktop] 1280. An affordance listed for a width must exist there and close
/// the surface (docs/close-affordances.md). A width with an empty set is a
/// bug unless [none] says why the surface is not shown at that width.
class CloseSurface {
  const CloseSurface(
    this.id, {
    required this.kind,
    required this.web,
    this.phone = const {},
    this.fold = const {},
    this.desktop = const {},
    this.files = const [],
    this.status = 'ok',
    this.fix = '',
    this.none = const {},
  });
  final String id;
  final SurfaceKind kind;

  /// What Web gives the same surface (file and affordances).
  final String web;
  final Set<Affordance> phone, fold, desktop;

  /// Source files that build or open the surface (relative to the app root).
  /// The registry test fails when a dialog / sheet / menu API is called from a
  /// file no surface lists.
  final List<String> files;

  /// `ok`, `fixed`, `approved` (owner-approved difference), `no-web`
  /// (Flutter-only surface) or `n/a`.
  final String status;
  final String fix;

  /// Widths ('phone' / 'fold' / 'desktop') where the surface does not exist,
  /// with the reason.
  final Map<String, String> none;

  Set<Affordance> at(String width) => switch (width) {
    'phone' => phone,
    'fold' || 'foldable' => fold,
    _ => desktop,
  };
}

/// What a harness reports about an opened surface.
class SurfaceProbe {
  const SurfaceProbe({
    required this.isOpen,
    this.x,
    this.back,
    this.scrim,
    this.dragHandle,
  });

  /// True while the surface is on screen.
  final bool Function() isOpen;

  /// The × button / the Back chevron.
  final Finder? x, back;

  /// A global point outside the surface that the scrim covers.
  final Offset? scrim;

  /// The drag handle of a bottom sheet.
  final Finder? dragHandle;
}

/// Opens a surface at [size] and describes it. Called once per affordance.
typedef OpenSurface = Future<SurfaceProbe> Function(WidgetTester t, Size size);

String widthKey(String name) => name == 'foldable' ? 'fold' : name;

/// Performs [affordance] on the opened surface and checks it closed.
Future<void> expectCloses(
  WidgetTester t,
  CloseSurface surface,
  String width,
  Affordance affordance,
  SurfaceProbe probe,
) async {
  final label = '${surface.id} @ $width: ${affordance.name}';
  expect(probe.isOpen(), isTrue, reason: '$label - the surface did not open');
  switch (affordance) {
    case Affordance.x:
      expect(
        probe.x,
        isNotNull,
        reason: '$label - the harness has no x finder',
      );
      expect(
        probe.x!.hitTestable(),
        findsWidgets,
        reason: '$label - no visible × button',
      );
      await t.tap(probe.x!.hitTestable().first);
      await frames(t, 20);
    case Affordance.back:
      expect(probe.back, isNotNull, reason: '$label - no back finder');
      expect(
        probe.back!.hitTestable(),
        findsWidgets,
        reason: '$label - no visible Back chevron',
      );
      await t.tap(probe.back!.hitTestable().first);
      await frames(t, 20);
    case Affordance.esc:
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(t, 20);
    case Affordance.scrim:
      expect(probe.scrim, isNotNull, reason: '$label - no scrim point');
      await t.tapAt(probe.scrim!);
      await frames(t, 20);
    case Affordance.systemBack:
      await t.binding.handlePopRoute();
      await frames(t, 20);
    case Affordance.drag:
      expect(probe.dragHandle, isNotNull, reason: '$label - no handle finder');
      expect(
        probe.dragHandle!.hitTestable(),
        findsWidgets,
        reason: '$label - no visible drag handle',
      );
      await t.fling(
        probe.dragHandle!.hitTestable().first,
        const Offset(0, 500),
        2000,
      );
      await frames(t, 20);
  }
  expect(probe.isOpen(), isFalse, reason: '$label - the surface stayed open');
}
