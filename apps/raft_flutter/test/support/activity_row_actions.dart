import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Reveal the desktop row action with real hover input before clicking it.
Future<void> clickActivityDone(WidgetTester tester) async {
  final row = find.byType(RaftConversationCard).first;
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(0, 0));
  try {
    await mouse.moveTo(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 200));
    final action = find.byTooltip('Mark Conversation Done').hitTestable();
    expect(action, findsOneWidget);
    await tester.tap(action);
  } finally {
    await mouse.removePointer();
  }
}
