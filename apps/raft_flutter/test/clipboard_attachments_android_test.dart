import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/clipboard_attachments.dart';

// Android copied files are content URIs that Dart cannot open; the native
// side (NativeClipboardAttachmentsBridge.kt) resolves them on the iOS channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('app.raft/clipboard-attachments');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    ClipboardAttachments.available.value = false;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('Android copied files resolve through the native channel', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return [
        {
          'name': 'report.pdf',
          'bytes': Uint8List.fromList([1, 2]),
        },
        {
          'name': 'IMG_0001.jpg',
          'bytes': Uint8List.fromList([3]),
        },
      ];
    });
    var images = 0;
    final files = await ClipboardAttachments(
      android: true,
      desktop: false,
      image: () async {
        images++;
        return null;
      },
    ).read();
    expect(calls, ['read']);
    expect([for (final f in files) f.name], ['report.pdf', 'IMG_0001.jpg']);
    expect(files.first.bytes, [1, 2]);
    // Resolved natively: the plugin's single-image read is not needed.
    expect(images, 0);
  });

  test('Android text-only clipboard yields nothing, so text pastes', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => <Object>[]);
    final files = await ClipboardAttachments(
      android: true,
      desktop: false,
      image: () async => null,
    ).read();
    expect(files, isEmpty);
  });

  test('watch tracks Android clipboard attachments', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var probes = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'available');
      probes++;
      return true;
    });
    ClipboardAttachments.watch();
    await Future<void>.delayed(Duration.zero);
    expect(probes, 1);
    expect(ClipboardAttachments.available.value, isTrue);
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('changed', false),
      ),
      (_) {},
    );
    expect(ClipboardAttachments.available.value, isFalse);
  });
}
