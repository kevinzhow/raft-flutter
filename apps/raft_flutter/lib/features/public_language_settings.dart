// Settings > Language & Region for a signed-out visitor of a public server
// (Web SettingsPanel `LanguageRegionSection` with `browserLocalPreferences`):
// the same form as the account's, saved on this device instead of /auth/me.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/message_translation_store.dart';
import '../data/display_language_preferences.dart';
import 'locale_settings_page.dart'
    show effectiveTimeFormat, localeTimezoneChoices;
import 'public_translation.dart';
import 'translation_language_options.dart';

class PublicLanguageRegionPage extends StatefulWidget {
  const PublicLanguageRegionPage({
    super.key,
    required this.preferences,
    required this.translations,
    this.displayLanguage,
  });
  final PublicLocalPreferences preferences;
  final MessageTranslationStore translations;
  final DisplayLanguagePreferences? displayLanguage;

  @override
  State<PublicLanguageRegionPage> createState() =>
      _PublicLanguageRegionPageState();
}

class _PublicLanguageRegionPageState extends State<PublicLanguageRegionPage> {
  DisplayLanguagePreferences? localDisplayLanguage;
  DisplayLanguagePreferences get displayLanguage =>
      widget.displayLanguage ??
      (localDisplayLanguage ??= DisplayLanguagePreferences());
  bool device24Hour = false;

  MessageTranslationSettings get settings => widget.translations.settings;
  Map<String, dynamic> get saved => widget.preferences.json;

  String get savedMode => settings.mode.name;
  String get savedTarget =>
      settings.preferredLanguage ?? followDisplayLanguageTarget;
  String get savedDisplay => settings.display.name;
  String get savedTimezone => '${saved['preferredTimezone'] ?? ''}'.trim();
  String get savedTimeFormat => effectiveTimeFormat(
    saved['preferredTimeFormat'],
    device24Hour: device24Hour,
  );

  @override
  void initState() {
    super.initState();
    widget.preferences.addListener(changed);
    widget.translations.addListener(changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    device24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    localDisplayLanguage?.dispose();
    widget.preferences.removeListener(changed);
    widget.translations.removeListener(changed);
    super.dispose();
  }

  /// Web `browserLocalPreferences`: a choice is written on this device at once
  /// (the store's update returns without a request), so there is nothing to
  /// wait for and nothing that can fail.
  void store(Map<String, Object?> fields) {
    unawaited(widget.preferences.update(fields));
    widget.translations.publicPreferencesChanged();
  }

  void changeDisplayLanguage(String next) {
    // Apply the UI choice before any asynchronous local write. A page may
    // close while storage is pending; the app-root owner outlives the form.
    unawaited(displayLanguage.save(next));
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final live = Localizations.localeOf(context).languageCode == 'zh'
        ? 'zh-cn'
        : 'en';
    final choices = localeTimezoneChoices(savedTimezone);
    return RaftLanguageRegionView(
      displayLanguage: live,
      displayLanguageOptions: displayLanguageOptions,
      translationMode: savedMode,
      translationNotice: !s.loaded || s.available
          ? null
          : !s.serverEnabled
          ? 'Translation is not enabled on this server yet.'
          : 'This deployment has no translation provider configured, so translations cannot run yet.',
      translationTarget: savedTarget,
      translationTargetOptions: translationTargetOptions(context),
      translationDisplay: savedDisplay,
      timezone: savedTimezone,
      timezoneOptions: choices.options,
      timezoneUnlisted: choices.unlisted,
      timeFormat: savedTimeFormat,
      displayLanguageSave: RaftImmediateSaveState.idle,
      translationModeSave: RaftImmediateSaveState.idle,
      translationTargetSave: RaftImmediateSaveState.idle,
      translationDisplaySave: RaftImmediateSaveState.idle,
      timezoneSave: RaftImmediateSaveState.idle,
      timeFormatSave: RaftImmediateSaveState.idle,
      settingsError: null,
      loading: false,
      onDisplayLanguage: changeDisplayLanguage,
      onTranslationMode: (v) => store({'preferredTranslationMode': v}),
      onTranslationTarget: (v) => store({
        'preferredLanguage': v == followDisplayLanguageTarget ? null : v,
      }),
      onTranslationDisplay: (v) => store({'preferredTranslationDisplay': v}),
      onTimezone: (v) => store({'preferredTimezone': v.isEmpty ? null : v}),
      onTimeFormat: (v) => store({'preferredTimeFormat': v}),
    );
  }
}
