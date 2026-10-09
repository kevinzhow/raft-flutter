import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

// WidgetTester's mouse gestures all default to device 1, including pointers
// created by earlier taps. Native mouse tracking must receive one add/remove
// pair per owned device, without adding an already active default device.
int _mouseDevice = 1000;
TestGesture createNativeMouse(WidgetTester tester, {int buttons = kPrimaryMouseButton}) {
  final id = _mouseDevice++;
  return TestGesture(dispatcher: tester.sendEventToBinding,
    pointer: id, device: id, kind: PointerDeviceKind.mouse, buttons: buttons);
}

/// Use the platform's real context action on the message's padding, where text
/// selection does not intercept the press. Assert the actual menu entry opens.
Future<void> openNativeMessageMenu(
  WidgetTester tester,
  Finder row, {
  required Finder entry,
}) async {
  for (var i = 0; i < 100 && row.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(row, findsOneWidget);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  final rect = tester.getRect(row);
  final press = Offset(rect.left + 2, rect.center.dy);
  if (Platform.isLinux) {
    final mouse = createNativeMouse(tester, buttons: kSecondaryMouseButton);
    await mouse.addPointer(location: press);
    try {
      await mouse.down(press);
      await mouse.up();
    } finally {
      await mouse.removePointer();
    }
  } else {
    await tester.longPressAt(press);
  }
  for (var i = 0; i < 100 && entry.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(entry, findsOneWidget);
}
