import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Web v1.24: Members, Computers and Settings are not tabs; the server tab
/// opens them. The one way every test reaches them.
const serverTabKey = Key('mobile-tab-server');
const serverPopoverKey = Key('mobile-server-tab-popover');

Key serverPageKey(String page) => Key('mobile-server-tab-$page');

Future<void> _settle(WidgetTester t, Future<void> Function(WidgetTester)? f) =>
    f != null
    ? f(t)
    : () async {
        for (var i = 0; i < 6; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }();

/// Opens the server tab's popover (a tap), then pushes [page] (`members`,
/// `computers` or `settings`). [flush] is the fixture's own settle (for
/// example `f.flush`); without it a bounded pump loop settles.
Future<void> openServerPage(
  WidgetTester t,
  String page, {
  Future<void> Function(WidgetTester)? flush,
}) async {
  await openServerPopover(t, flush: flush);
  await t.tap(find.byKey(serverPageKey(page)));
  await _settle(t, flush);
  // The push animates; the popover has closed.
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openServerPopover(
  WidgetTester t, {
  Future<void> Function(WidgetTester)? flush,
}) async {
  await t.tap(find.byKey(serverTabKey));
  await _settle(t, flush);
  await t.pump(const Duration(milliseconds: 100));
}
