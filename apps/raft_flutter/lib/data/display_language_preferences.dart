import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_preferences.dart';

/// Web locale.ts: the pre-auth UI language cache, separate from message
/// translation preferences and never written back to an account on sign-in.
const displayLanguagePreferenceKey = 'slock.displayLanguage';
const displayLanguageOptions = [('en', 'English'), ('zh-cn', '简体中文')];

/// Only the two shipped display languages can be saved as a device choice.
String? _supported(String? value) =>
    value == 'en' || value == 'zh-cn' ? value : null;

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

String? _normalized(String? preference) {
  final language = preference?.toLowerCase().replaceAll('_', '-');
  if (language == 'zh-cn' || language == 'zh-hans') return 'zh-cn';
  if (language == 'en' || language?.startsWith('en-') == true) return 'en';
  return null;
}

/// The server stores only locales shipped by the UI. Translation is separate.
Locale displayLocale(String? preference, {Locale? device}) {
  final language = _normalized(preference);
  if (language == 'zh-cn') {
    return const Locale('zh', 'CN');
  }
  if (language == 'en') {
    return const Locale('en');
  }
  final resolved = device ?? WidgetsBinding.instance.platformDispatcher.locale;
  return resolved.languageCode == 'zh' &&
          (resolved.countryCode == 'CN' ||
              resolved.scriptCode == 'Hans' ||
              resolved.countryCode == null)
      ? const Locale('zh', 'CN')
      : const Locale('en');
}
