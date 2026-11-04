import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_image_export.dart';
import 'package:raft_flutter/platform/image_clipboard.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
const _channel = MethodChannel('app.raft/image-clipboard');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test(
    'native PNG copy waits for acknowledgment and sends original bytes',
    () async {
      final receipt = Completer<bool>();
      MethodCall? received;
      messenger.setMockMethodCallHandler(_channel, (call) {
        received = call;
        return receipt.future;
      });
      var done = false;
      final copying = const ImageClipboard()
          .copyPng(_png)
          .then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(received?.method, 'copyPng');
      expect(received?.arguments, _png);
      expect(done, isFalse);
      receipt.complete(true);
      await copying;
      expect(done, isTrue);
    },
  );

  for (final response in [false, null]) {
    test('host $response cannot become a successful copy', () async {
      messenger.setMockMethodCallHandler(_channel, (_) async => response);
      await expectLater(
        const ImageClipboard().copyPng(_png),
        throwsA(isA<PlatformException>()),
      );
    });
  }

  test(
    'missing native host is a failure, never a silent clipboard fallback',
    () async {
      await expectLater(
        const ImageClipboard().copyPng(_png),
        throwsA(isA<MissingPluginException>()),
      );
    },
  );

  test('invalid PNG never reaches the clipboard writer', () async {
    var writes = 0;
    messenger.setMockMethodCallHandler(_channel, (_) async {
      writes++;
      return true;
    });
    final huge = Uint8List.fromList(_png);
    ByteData.sublistView(huge).setUint32(16, 16000001);
    final notHeader = Uint8List.fromList(_png)..[12] = 0;
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
      _png.sublist(0, 24),
      huge,
      notHeader,
    ]) {
      await expectLater(
        const ImageClipboard().copyPng(bytes),
        throwsFormatException,
      );
    }
    expect(writes, 0);
  });

  test(
    'unsupported capability cannot write even through an injected writer',
    () async {
      var writes = 0;
      await expectLater(
        ImageClipboard(
          supportedOverride: false,
          write: (_) async {
            writes++;
          },
        ).copyPng(_png),
        throwsUnsupportedError,
      );
      expect(writes, 0);
    },
  );

  for (final target in [
    (TargetPlatform.linux, const Size(390, 844)),
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
  ]) {
    testWidgets(
      '${target.$1} ${target.$2}: PNG copy, failure preserves clipboard and retry',
      (t) async {
        t.view.physicalSize = target.$2;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final (w, _) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          w.dispose();
          w.client.dispose();
        });
        final receipt = Completer<bool>();
        Object clipboard = 'previous clipboard';
        var writes = 0;
        messenger.setMockMethodCallHandler(_channel, (call) async {
          expect(call.method, 'copyPng');
          writes++;
          if (writes == 1) return false;
          await receipt.future;
          clipboard = Uint8List.fromList(call.arguments as Uint8List);
          return true;
        });
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: target.$1),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    DialogRoute<void>(
                      context: context,
                      builder: (_) => MessageImageReview(
                        controller: w,
                        bytes: _png,
                        filename: 'messages.png',
                        authorized: () => true,
                      ),
                    ),
                  ),
                  child: const Text('Review'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Review'));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('image-review-copy')), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('image-review-copy')));
        await t.pumpAndSettle();
        expect(clipboard, 'previous clipboard');
        expect(
          find.text("Couldn't copy the image. Use Download instead."),
          findsOneWidget,
        );
        expect(find.text('Copied'), findsNothing);
        await t.tap(find.byKey(const ValueKey('image-review-copy')));
        await t.pump();
        expect(clipboard, 'previous clipboard');
        expect(find.text('Copied'), findsNothing);
        receipt.complete(true);
        await t.pumpAndSettle();
        expect(clipboard, _png);
        expect(find.text('Copied'), findsOneWidget);
        expect(
          find.text("Couldn't copy the image. Use Download instead."),
          findsNothing,
        );
        Navigator.of(t.element(find.byType(MessageImageReview))).pop();
        await t.pumpAndSettle();
        expect(
          clipboard,
          _png,
          reason: 'closing the preview must not invalidate the exported image',
        );
      },
    );
  }
}
