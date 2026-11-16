import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/clipboard_attachments.dart';
import 'package:raft_ui/raft_ui.dart' show RaftPasteAttachmentsIntent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('app.raft/clipboard-attachments');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    ClipboardAttachments.debugResetWatch();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('iOS channel preserves filenames and drops empty attachments', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => [
        {
          'name': 'report.pdf',
          'bytes': Uint8List.fromList([1, 2]),
        },
        {'name': 'empty.png', 'bytes': Uint8List(0)},
      ],
    );
    final files = await const ClipboardAttachments(ios: true).read();
    expect(files.single.name, 'report.pdf');
    expect(files.single.bytes, [1, 2]);
  });

  for (final fails in [false, true]) {
    test(
      'iOS native ${fails ? 'error' : 'empty result'} falls back to image',
      () async {
        final files = await ClipboardAttachments(
          ios: true,
          native: () async {
            if (fails) throw PlatformException(code: 'unavailable');
            return [];
          },
          image: () async => Uint8List.fromList([3]),
        ).read();
        expect(files.single.name, 'image.png');
        expect(files.single.bytes, [3]);
      },
    );
  }

  test(
    'watch probes once and handles clipboard change notifications',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var probes = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'available');
        probes++;
        return true;
      });
      ClipboardAttachments.watch();
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
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('changed', true),
        ),
        (_) {},
      );
      expect(ClipboardAttachments.available.value, isTrue);
    },
  );

  testWidgets('a system Paste goes to the focused composer, else to text', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(channel, (call) async => false);
    ClipboardAttachments.watch();
    var taken = 0;
    var reads = true;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      Actions(
        actions: {
          RaftPasteAttachmentsIntent:
              CallbackAction<RaftPasteAttachmentsIntent>(
                onInvoke: (_) async {
                  taken++;
                  return reads;
                },
              ),
        },
        child: Focus(focusNode: focus, child: const SizedBox()),
      ),
    );
    const codec = StandardMethodCodec();
    Future<Object?> paste() async {
      ByteData? reply;
      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(const MethodCall('paste')),
        (data) => reply = data,
      );
      return codec.decodeEnvelope(reply!);
    }

    // Nothing focused takes attachments: the native text paste runs.
    expect(await paste(), isFalse);
    expect(taken, 0);
    focus.requestFocus();
    await tester.pump();
    expect(await paste(), isTrue);
    expect(taken, 1);
    // The composer took nothing (unreadable file): the text paste runs.
    reads = false;
    expect(await paste(), isFalse);
    expect(taken, 2);
    debugDefaultTargetPlatformOverride = null;
  });
}
