import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart'
    show raftDisplayLanguageId, raftDisplayLanguages;
import 'package:shared_preferences/shared_preferences.dart';

import 'device_preferences.dart';

/// Web locale.ts: the pre-auth UI language cache, separate from message
/// translation preferences and never written back to an account on sign-in.
const displayLanguagePreferenceKey = 'slock.displayLanguage';
final displayLanguageOptions = List<(String, String)>.unmodifiable(
  raftDisplayLanguages.entries.map((entry) => (entry.key, entry.value.$2)),
);
final supportedDisplayLocales = List<Locale>.unmodifiable(
  raftDisplayLanguages.values.map((entry) => entry.$1),
);

String? _supported(String? value) =>
    raftDisplayLanguages.containsKey(value) ? value : null;

/// Device-only UI language. The preloaded record is available before the first
/// frame. An explicit account language wins; an unset account preference keeps
/// the local fallback. Neither resolution writes an account or this record.
class DisplayLanguagePreferences extends ValueNotifier<String?> {
  DisplayLanguagePreferences() : super(_read(DevicePreferences.current));
  Future<void> _writes = Future.value();
  bool _disposed = false;

  static String? _read(SharedPreferences? preferences) {
    try {
      return _supported(preferences?.getString(displayLanguagePreferenceKey));
    } catch (_) {
      return null;
    }
  }

  void adopt(SharedPreferences preferences) {
    if (!_disposed) value = _read(preferences);
  }

  Locale resolve(String? accountLanguage, {required bool signedIn}) =>
      displayLocale(signedIn ? _normalized(accountLanguage) ?? value : value);

  Future<void> save(String next) {
    if (_disposed || _supported(next) == null) return Future.value();
    value = next;
    // Preserve the last chosen order even if storage is temporarily slow.
    return _writes = _writes.then((_) async {
      try {
        await (await SharedPreferences.getInstance()).setString(
          displayLanguagePreferenceKey,
          next,
        );
      } catch (_) {
        // Web rememberLocale: storage failure leaves the visit's choice live.
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final _languageTag = RegExp(r'^[a-z]{2,3}(?:-[a-z0-9]{1,8})*$');
final _scriptTag = RegExp(r'^[a-z]{4}$');
final _regionTag = RegExp(r'^(?:[a-z]{2}|\d{3})$');

String? _normalized(String? preference, {bool system = false}) {
  final tag = preference?.trim().toLowerCase().replaceAll('_', '-');
  if (tag == null || !_languageTag.hasMatch(tag)) return null;
  final [language, ...subtags] = tag.split('-');
  if (language == 'pt') return 'pt-br';
  if (language != 'zh') return _supported(language);
  final script = subtags.where(_scriptTag.hasMatch).firstOrNull;
  if (script != null) {
    return switch (script) {
      'hant' => 'zh-tw',
      'hans' => 'zh-cn',
      _ => system ? 'zh-cn' : null,
    };
  }
  final region = subtags.where(_regionTag.hasMatch).firstOrNull;
  return const ['tw', 'hk', 'mo'].contains(region) ? 'zh-tw' : 'zh-cn';
}

String systemDisplayLanguage(Iterable<String> languages) {
  var englishFirst = false;
  for (final tag in languages) {
    final id = _normalized(tag, system: true);
    if (id == null) continue;
    if (id == 'en') {
      englishFirst = true;
    } else if (!englishFirst || id.startsWith('zh-')) {
      return id;
    }
  }
  return 'en';
}

/// The server stores only locales shipped by the UI. Translation is separate.
Locale displayLocale(String? preference, {Locale? device}) {
  final id =
      _normalized(preference) ??
      (device == null
          ? systemDisplayLanguage(
              WidgetsBinding.instance.platformDispatcher.locales.map(
                (locale) => locale.toLanguageTag(),
              ),
            )
          : raftDisplayLanguageId(device));
  return raftDisplayLanguages[id]!.$1;
}
