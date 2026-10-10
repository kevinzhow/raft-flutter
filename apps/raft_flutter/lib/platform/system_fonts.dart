import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

class NativeSystemFonts extends ValueNotifier<RaftFontFamilies> {
  NativeSystemFonts._() : super(const RaftFontFamilies());

  static final instance = NativeSystemFonts._();
  static const _channel = MethodChannel('app.raft/system-fonts');
  bool _initialized = false;
  Future<void>? _refresh;
  final _loadedFamilies = <String>{};

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (!_supported || _initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await refresh();
    });
    await refresh();
  }

  Future<void> refresh() {
    if (!_supported) return Future<void>.value();
    return _refresh ??= _read().whenComplete(() => _refresh = null);
  }

  Future<void> _read() async {
    try {
      final fonts = await _channel
          .invokeMapMethod<String, dynamic>('read')
          .timeout(const Duration(seconds: 2));
      if (fonts == null) return;
      final body = _family(fonts, 'body', value.body);
      final heading = _family(fonts, 'heading', value.heading);
      if (value.body == body && value.heading == heading) return;
      final loaded = await _loadFaces(body, heading);
      value = loaded;
    } on MissingPluginException {
      // Hosts without the bridge retain the platform's generic families.
    } on PlatformException {
      // A failed refresh must not discard an already resolved device family.
    } on TimeoutException {
      // A delayed native font query must not prevent app startup.
    }
  }

  String _family(Map<dynamic, dynamic> fonts, String key, String fallback) {
    final candidate = fonts[key];
    return candidate is String && candidate.trim().isNotEmpty
        ? candidate.trim()
        : fallback;
  }

  Future<RaftFontFamilies> _loadFaces(String body, String heading) async {
    final selected = RaftFontFamilies(body: body, heading: heading);
    // Generic families already have engine support. The pinned Android font
    // manager resolves product fonts against /system/fonts, so OEM families
    // stored in /product/fonts require registration from their actual files.
    if (body == 'sans-serif' && heading == 'sans-serif') return selected;
    final response = await _channel
        .invokeMapMethod<String, dynamic>('faces')
        .timeout(const Duration(seconds: 2));
    final faces = response?['faces'];
    if (faces is! List || faces.isEmpty) return selected;
    final paths = <String, Set<String>>{};
    for (final face in faces) {
      if (face is Map && face['role'] is String && face['path'] is String) {
        paths
            .putIfAbsent(face['role'] as String, () => {})
            .add(face['path'] as String);
      }
    }
    final fallback = <String>[];
    for (final entry in paths.entries) {
      final family = switch (entry.key) {
        'body' => body,
        'heading' => heading,
        'body-fallback' => '$body fallback',
        'heading-fallback' => '$heading fallback',
        _ => null,
      };
      if (family == null) continue;
      if (!_loadedFamilies.contains(family)) {
        final loader = FontLoader(family);
        try {
          for (final path in entry.value) {
            final bytes = await File(path).readAsBytes();
            loader.addFont(Future.value(ByteData.sublistView(bytes)));
          }
          await loader.load();
          _loadedFamilies.add(family);
        } on FileSystemException {
          // Some OEMs protect font files; retain their system family name.
          continue;
        }
      }
      if (entry.key.endsWith('-fallback')) fallback.add(family);
    }
    return RaftFontFamilies(body: body, heading: heading, fallback: fallback);
  }
}
