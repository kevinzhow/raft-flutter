import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

bool _presented(Element element) {
  var presented = element.mounted;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is IgnorePointer && widget.ignoring ||
        widget is Opacity && widget.opacity == 0 ||
        widget is Offstage && widget.offstage) {
      presented = false;
      return false;
    }
    return true;
  });
  return presented;
}

bool _scrolling(Element element) {
  var changing = false;
  element.visitAncestorElements((ancestor) {
    if (ancestor is StatefulElement && ancestor.state is ScrollableState) {
      final position = (ancestor.state as ScrollableState).position;
      changing |= position.outOfRange || position.isScrollingNotifier.value;
    }
    return true;
  });
  return changing;
}

/// Reveals the accepted, painted owner before a single native pointer press.
/// Hidden context preparation and the retained old timeline cannot own input.
/// No gesture is sent by this helper, and no failed gesture is retried.
Future<Finder> revealNativeControl(WidgetTester tester, Finder target) async {
  Element? owner;
  for (var i = 0; i < 100; i++) {
    final current = target.evaluate().where(_presented).toList();
    if (current.length == 1) {
      owner = current.single;
      break;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (owner == null) {
    throw TestFailure('Native control has no unique painted input owner.');
  }
  final painted = find.byElementPredicate((e) => identical(e, owner));
  if (painted.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(painted);
  }
  Rect? previous;
  for (var i = 0; i < 30; i++) {
    final visible = target.hitTestable().evaluate().where(_presented).toList();
    if (visible.length == 1 && !_scrolling(visible.single)) {
      final candidate = find.byElementPredicate(
        (e) => identical(e, visible.single),
      );
      final rect = tester.getRect(candidate);
      if (previous == rect) return target.hitTestable();
      previous = rect;
    } else {
      previous = null;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw TestFailure(
    'Native control did not finish its visible scroll/layout before input.',
  );
}
