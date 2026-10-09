import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// Use the platform's real context action on the message's padding, where text
/// selection does not intercept the press. Assert the actual menu entry opens.
Future<void> openNativeMessageMenu(
  WidgetTester tester,
  Finder row, {
  required Finder entry,
}) async {
  expect(row, findsOneWidget);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  final rect = tester.getRect(row);
  final press = Offset(rect.left + 2, rect.center.dy);
  if (Platform.isLinux) {
    await tester.tapAt(
      press,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
  } else {
    await tester.longPressAt(press);
  }
  for (var i = 0; i < 100 && entry.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(entry, findsOneWidget);
}
