import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_system_webview/raft_system_webview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const root = SystemWebViewController.rootChannel;
  const view = MethodChannel('app.raft/system_webview/7');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(
      root,
      (_) async => {
        'id': 7,
        'protocol': 1,
        'ephemeral': true,
        'sandboxed': true,
      },
    );
    messenger.setMockMethodCallHandler(view, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(root, null);
    messenger.setMockMethodCallHandler(view, null);
  });
  test(
    'incomplete isolation metadata is refused and the created view closed',
    () async {
      for (final field in ['protocol', 'ephemeral', 'sandboxed']) {
        messenger.setMockMethodCallHandler(
          root,
          (_) async =>
              {'id': 7, 'protocol': 1, 'ephemeral': true, 'sandboxed': true}
                ..remove(field),
        );
        await expectLater(SystemWebViewController.create(), throwsStateError);
      }
      expect(calls.map((c) => c.method), ['dispose', 'dispose', 'dispose']);
    },
  );
  test(
    'layout updates carry monotonic sequence and exact GTK clipping',
    () async {
      final controller = await SystemWebViewController.create();
      await controller.layout(
        const SystemWebViewLayout(
          Rect.fromLTWH(0, 10, 50, 60),
          Rect.fromLTWH(0, 20, 50, 50),
        ),
      );
      await controller.layout(SystemWebViewLayout.hidden);
      expect((calls[0].arguments as Map)['sequence'], 1);
      expect((calls[0].arguments as Map)['clip'], [0.0, 20.0, 50.0, 50.0]);
      expect((calls[1].arguments as Map)['sequence'], 2);
      expect((calls[1].arguments as Map)['visible'], false);
      await controller.dispose();
    },
  );
  test(
    'dispose waits for real native completion and closes only once',
    () async {
      final gate = Completer<void>();
      messenger.setMockMethodCallHandler(view, (call) async {
        calls.add(call);
        if (call.method == 'dispose') await gate.future;
        return null;
      });
      final controller = await SystemWebViewController.create();
      final first = controller.dispose(), second = controller.dispose();
      expect(identical(first, second), true);
      await expectLater(controller.evaluate('1'), throwsStateError);
      gate.complete();
      await first;
      expect(calls.map((c) => c.method), ['dispose']);
    },
  );
  test('a reply arriving after disposal cannot revive evaluation', () async {
    final gate = Completer<Object?>();
    messenger.setMockMethodCallHandler(view, (call) async {
      if (call.method == 'evaluate') return gate.future;
      return null;
    });
    final controller = await SystemWebViewController.create();
    final evaluating = controller.evaluate('1');
    final rejected = expectLater(evaluating, throwsStateError);
    await controller.dispose();
    gate.complete('1');
    await rejected;
  });
}
