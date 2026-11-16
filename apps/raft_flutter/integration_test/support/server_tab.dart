import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Web v1.24: Members, Computers and Settings are not tabs; the phone's server
/// tab opens them as pushed pages (no bottom bar, Back at the top). The one
/// way every device test reaches them.
Future<void> openServerPage(WidgetTester tester, String page) async {
  await tester.tap(find.byKey(const Key('mobile-tab-server')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('mobile-server-tab-$page')));
  await tester.pumpAndSettle();
}
