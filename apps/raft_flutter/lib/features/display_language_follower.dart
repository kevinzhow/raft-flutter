import 'dart:ui' show Locale;

import 'package:flutter/scheduler.dart';

import '../data/message_translation_store.dart';

/// Keeps the translation target of a person with no preference on the display
/// language: Web `App` calls translationStore `followDisplayLanguage(locale)`
/// whenever the locale changes. Called by [buildRaftApplication] with the
/// locale it builds the app in.
void followDisplayLanguage(Locale locale) {
  final id = locale.languageCode == 'zh' ? 'zh-cn' : 'en';
  if (id == MessageTranslationStore.displayLanguageTarget) return;
  // The stores tell their listeners; that is not for the middle of a build.
  SchedulerBinding.instance.addPostFrameCallback((_) {
    MessageTranslationStore.followDisplayLanguage(id);
  });
}
