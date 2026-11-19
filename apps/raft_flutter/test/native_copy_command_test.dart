import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/app_window.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('macOS menu copies only the focused message selection', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const channel = MethodChannel('app.raft/window');
    final states = <bool>[];
    final copied = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setWindowCommandsState') {
        states.add((call.arguments as Map)['copy'] == true);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> requestCopy() async {
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('copyRequested'),
        ),
        (_) {},
      );
      await tester.pump();
    }

    const message = 'Quartz347 fixture';
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: AppWindowCommands(
          navigatorKey: GlobalKey<NavigatorState>(),
          child: const Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RaftMessageBody(content: message),
                TextField(),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await tester.pumpAndSettle();
      expect(states.last, isFalse);
      final text = tester.getRect(find.text(message, findRichText: true));
      final mouse = await tester.startGesture(
        text.centerRight - const Offset(1, 0),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveTo(text.centerLeft);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(states.last, isTrue);

      await requestCopy();
      expect(copied, [message]);

      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      final selectionFocus = FocusManager.instance.primaryFocus;
      region.clearSelection();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(selectionFocus));
      expect(states.last, isFalse);
      await requestCopy();
      expect(copied, [message]);

      region.selectAll();
      await tester.pump();
      expect(states.last, isTrue);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(states.last, isFalse);
      await requestCopy();
      expect(copied, [message]);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  }, variant: const TargetPlatformVariant({TargetPlatform.macOS}));
}
