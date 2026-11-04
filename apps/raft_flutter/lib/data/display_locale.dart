import 'package:flutter/widgets.dart';

/// The server stores only locales shipped by the UI. Translation language is separate.
Locale displayLocale(String? preference, {Locale? device}) {
  final language = preference?.toLowerCase().replaceAll('_', '-');
  if (language == 'zh-cn' || language == 'zh-hans') {
    return const Locale('zh', 'CN');
  }
  if (language == 'en' || language?.startsWith('en-') == true) {
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
