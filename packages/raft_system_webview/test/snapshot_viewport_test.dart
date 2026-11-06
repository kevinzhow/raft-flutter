import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_system_webview/raft_system_webview.dart';

Future<Uint8List> image(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xffff0000), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final pixels = await picture.toImage(width, height);
  picture.dispose();
  try {
    final bytes = (await pixels.toByteData(format: ui.ImageByteFormat.png))!;
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    pixels.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('app.raft/system_webview/73');
  var sequence = 0;
  var width = 600, height = 678;
  var nativeWidth = 600, nativeHeight = 678, scale = 1;
  late Uint8List png;
  setUp(() async {
    sequence = 0;
    width = 600;
    height = 678;
    nativeWidth = 600;
    nativeHeight = 678;
    scale = 1;
    png = await image(width, height);
    messenger.setMockMethodCallHandler(
      SystemWebViewController.rootChannel,
      (_) async => {
        'id': 73,
        'protocol': 1,
        'ephemeral': true,
        'sandboxed': true,
        'snapshot': true,
      },
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'layout') {
        sequence = (call.arguments as Map)['sequence'] as int;
      }
      if (call.method == 'snapshot') {
        return {
          'png': png,
          'width': width,
          'height': height,
          'sequence': sequence,
          'viewportWidth': nativeWidth,
          'viewportHeight': nativeHeight,
          'scale': scale,
        };
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

  SystemWebViewLayout viewport(double width, double height) =>
      SystemWebViewLayout(
        ui.Rect.fromLTWH(0, 32, width, height),
        ui.Rect.fromLTWH(0, 32, width, height),
      );

  test('a new sequence cannot relabel the previous viewport pixels', () async {
    final controller = await SystemWebViewController.create();
    try {
      await controller.layout(viewport(600, 678));
      expect((await controller.snapshot())?.width, 600);
      await controller.layout(viewport(360, 678));
      // GTK/WebKit can still return the preceding 600px backing snapshot even
      // though the method response carries the new layout's sequence number.
      expect(await controller.snapshot(), isNull);
      width = 360;
      nativeWidth = 360;
      png = await image(width, height);
      expect((await controller.snapshot())?.width, 360);
    } finally {
      await controller.dispose();
    }
  });

  test('one GTK scale applies to both viewport axes', () async {
    final controller = await SystemWebViewController.create();
    try {
      await controller.layout(viewport(360, 678));
      width = 720;
      height = 1356;
      nativeWidth = 360;
      nativeHeight = 678;
      scale = 2;
      png = await image(width, height);
      expect((await controller.snapshot())?.width, 720);
      height = 678;
      png = await image(width, height);
      expect(await controller.snapshot(), isNull);
    } finally {
      await controller.dispose();
    }
  });

  test(
    'occlusion retains the last valid viewport size for its snapshot',
    () async {
      final controller = await SystemWebViewController.create();
      try {
        await controller.layout(viewport(360, 678));
        await controller.layout(SystemWebViewLayout.hidden);
        expect(await controller.snapshot(), isNull);
        width = 360;
        nativeWidth = 360;
        png = await image(width, height);
        expect((await controller.snapshot())?.width, 360);
      } finally {
        await controller.dispose();
      }
    },
  );

  test(
    'a proportional resize does not misidentify stale pixels as HiDPI',
    () async {
      final controller = await SystemWebViewController.create();
      try {
        await controller.layout(viewport(600, 678));
        expect(await controller.snapshot(), isNotNull);
        await controller.layout(viewport(300, 339));
        // The old image happens to be twice the new width AND height.
        expect(await controller.snapshot(), isNull);
        nativeWidth = 300;
        nativeHeight = 339;
        scale = 2;
        expect((await controller.snapshot())?.width, 600);
      } finally {
        await controller.dispose();
      }
    },
  );

  test(
    'a resized blocked pane retains geometry without exposing input',
    () async {
      final controller = await SystemWebViewController.create();
      try {
        await controller.layout(viewport(600, 678));
        final blocked = SystemWebViewLayout.resolve(
          local: const ui.Rect.fromLTWH(0, 0, 360, 678),
          transform: Matrix4.translationValues(0, 32, 0),
          viewport: const ui.Rect.fromLTWH(0, 0, 800, 800),
          clips: const [],
          scale: 1,
          isOccluded: (_) => true,
        );
        expect(blocked.visible, false);
        expect(blocked.clip, ui.Rect.zero);
        expect(blocked.frame.size, const ui.Size(360, 678));
        await controller.layout(blocked);
        expect(await controller.snapshot(), isNull);
        nativeWidth = width = 360;
        png = await image(width, height);
        expect((await controller.snapshot())?.width, 360);
      } finally {
        await controller.dispose();
      }
    },
  );

  test(
    'fractional native bounds use the same inward edge rounding as GTK',
    () async {
      final controller = await SystemWebViewController.create();
      try {
        const frame = ui.Rect.fromLTWH(.4, 32.4, 360.8, 678.8);
        await controller.layout(const SystemWebViewLayout(frame, frame));
        nativeWidth = width = 360;
        nativeHeight = height = 678;
        png = await image(width, height);
        expect((await controller.snapshot())?.width, 360);
      } finally {
        await controller.dispose();
      }
    },
  );
}
