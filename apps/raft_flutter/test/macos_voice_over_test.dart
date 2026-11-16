import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/macos_voice_over.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.raft/voiceover');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> push(bool on) => messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall('changed', on)),
    (_) {},
  );

  test('reads the Runner\'s answer, then follows each pushed toggle', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isEnabled');
      return true;
    });
    final voiceOver = MacosVoiceOver(channel: channel);
    addTearDown(voiceOver.dispose);
    expect(
      voiceOver.value,
      isFalse,
      reason: 'semantics are off until answered',
    );
    await pumpEventQueue();
    expect(voiceOver.value, isTrue);
    await push(false);
    expect(voiceOver.value, isFalse);
    await push(true);
    expect(voiceOver.value, isTrue);
  });

  test('a shell without the channel keeps the semantics reading', () async {
    final voiceOver = MacosVoiceOver(channel: channel);
    addTearDown(voiceOver.dispose);
    await pumpEventQueue();
    expect(voiceOver.value, isFalse);
  });
}
