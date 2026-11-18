import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Reveal the desktop row action with real hover input before clicking it.
Future<void> clickActivityDone(WidgetTester tester) async {
  final row = find.byType(RaftInboxItem).first;
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(0, 0));
  try {
    await mouse.moveTo(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 200));
    final action = find.byKey(const ValueKey('inbox-row-done')).hitTestable();
    expect(action, findsOneWidget);
    await tester.tap(action);
  } finally {
    await mouse.removePointer();
  }
}

/// The unread count mark of an Activity row (`conversation-card-new-badge`)
/// showing [count]: Web's row shows the number, not "N new".
Finder activityNewCount(int count) => find.descendant(
  of: find.byKey(const ValueKey('conversation-card-new-badge')),
  matching: find.text('$count'),
);
