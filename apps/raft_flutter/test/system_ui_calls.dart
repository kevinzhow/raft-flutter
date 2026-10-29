import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The system UI modes the app asked the platform for, in order. The media
/// viewer must ask for none (its immersive mode is the app's own chrome).
List<String> recordSystemUiModes(WidgetTester tester) {
  final modes = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
        modes.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return modes;
}
