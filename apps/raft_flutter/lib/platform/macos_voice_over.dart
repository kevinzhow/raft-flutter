import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Whether macOS VoiceOver itself is on (`NSWorkspace.isVoiceOverEnabled`), not just any
/// accessibility client. The Runner (`RaftVoiceOverChannel` in
/// macos/Runner/MainFlutterWindow.swift) answers `isEnabled` and pushes `changed` on each toggle.
///
/// Until the first answer it reads whether semantics are on (the earlier, stricter rule), and it
/// keeps that if the read fails. Elsewhere it is always false.
class MacosVoiceOver extends ValueNotifier<bool> {
  @visibleForTesting
  MacosVoiceOver({
    MethodChannel channel = const MethodChannel('app.raft/voiceover'),
  }) : super(SemanticsBinding.instance.semanticsEnabled) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed' && call.arguments is bool) {
        value = call.arguments as bool;
      }
    });
    unawaited(
      channel
          .invokeMethod<bool>('isEnabled')
          .then(
            (on) {
              if (on != null) value = on;
            },
            onError: (Object _) {
              // MissingPluginException / PlatformException: keep the semantics reading.
            },
          ),
    );
  }

  static ValueListenable<bool>? _instance;

  /// This isolate's reading (each desktop window has its own engine and channel).
  static ValueListenable<bool> get instance =>
      _instance ??= !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS
      ? MacosVoiceOver()
      : const _Off();
}

/// Never on, never changes (not a notifier: nothing to dispose).
class _Off implements ValueListenable<bool> {
  const _Off();
  @override
  bool get value => false;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}
