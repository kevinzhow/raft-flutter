import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_system_webview/raft_system_webview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('app.raft/system_webview/11');
  var sequence = 0, snapshots = 0;
  Completer<Object?>? delayed;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
  );
  Map<String, Object> packet(int serial) => {
    'png': png,
    'width': 1,
    'height': 1,
    'sequence': serial,
  };
  setUp(() {
    sequence = snapshots = 0;
    delayed = null;
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      (_) async => {
        'id': 11,
        'protocol': 1,
        'ephemeral': true,
        'sandboxed': true,
        'snapshot': true,
      },
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'layout')
        sequence = (call.arguments as Map)['sequence'] as int;
      if (call.method == 'snapshot') {
        snapshots++;
        return delayed?.future ?? packet(sequence);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      null,
    );
    messenger.setMockMethodCallHandler(channel, null);
  });
  test(
    'native snapshot is accepted only for its current layout sequence',
    () async {
      final controller = await SystemWebViewController.create();
      const frame = SystemWebViewLayout(
        Rect.fromLTWH(0, 0, 300, 200),
        Rect.fromLTWH(0, 0, 300, 200),
      );
      await controller.layout(frame);
      expect((await controller.snapshot())?.sequence, 1);
      delayed = Completer<Object?>();
      final first = controller.snapshot();
      await Future<void>.delayed(Duration.zero);
      await controller.layout(frame);
      delayed!.complete(packet(1));
      expect(await first, isNull);
      expect(snapshots, 2);
      await controller.dispose();
      expect(await controller.snapshot(), isNull);
    },
  );
  test('host pixel invalidation is not a page or pointer event', () async {
    final controller = await SystemWebViewController.create();
    final events = <Map<Object?, Object?>>[];
    final subscription = controller.events.listen(events.add);
    controller.markSnapshotDirty();
    expect(events, [
      {'type': 'snapshotDirty'},
    ]);
    await controller.dispose();
    controller.markSnapshotDirty();
    expect(events, [
      {'type': 'snapshotDirty'},
      {'type': 'closed'},
    ]);
    await subscription.cancel();
  });
  testWidgets(
    'closing a controller retires an image while its pane stays mounted',
    (tester) async {
      final controller = await SystemWebViewController.create();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SystemWebView(controller: controller, visible: true),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        final raw = tester.widget<RawImage>(find.byType(RawImage));
        if (raw.image != null) break;
      }
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      await controller.dispose();
      await tester.pump();
      expect(find.byType(RawImage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
