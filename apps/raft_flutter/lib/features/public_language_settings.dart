// Settings > Language & Region for a signed-out visitor of a public server
// (Web SettingsPanel `LanguageRegionSection` with `browserLocalPreferences`):
// the same form as the account's, saved on this device instead of /auth/me.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/message_translation_store.dart';
import 'locale_settings_page.dart'
    show effectiveTimeFormat, localeTimezoneOptions;
import 'public_translation.dart';

class PublicLanguageRegionPage extends StatefulWidget {
  const PublicLanguageRegionPage({
    super.key,
    required this.preferences,
    required this.translations,
  });
  final PublicLocalPreferences preferences;
  final MessageTranslationStore translations;

  @override
  State<PublicLanguageRegionPage> createState() =>
      _PublicLanguageRegionPageState();
}

class _PublicLanguageRegionPageState extends State<PublicLanguageRegionPage> {
  // Drafts of the two forms; null follows the saved value.
  String? draftMode, draftTarget, draftDisplay, draftTimezone, draftTimeFormat;
  bool languageSaved = false, dateTimeSaved = false;
  final timers = <bool, Timer>{};
  bool device24Hour = false;

  MessageTranslationSettings get settings => widget.translations.settings;
  Map<String, dynamic> get saved => widget.preferences.json;

  String get savedMode => settings.mode.name;
  String get savedTarget => settings.preferredLanguage ?? 'browser';
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
    for (final timer in timers.values) {
      timer.cancel();
    }
    widget.preferences.removeListener(changed);
    widget.translations.removeListener(changed);
    super.dispose();
  }

  void edit(void Function() change, {bool language = true}) => setState(() {
    change();
    if (language) {
      languageSaved = false;
    } else {
      dateTimeSaved = false;
    }
  });

  void flash(bool language) {
    timers[language]?.cancel();
    timers[language] = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        if (language) {
          languageSaved = false;
        } else {
          dateTimeSaved = false;
        }
      });
    });
  }

  Future<void> saveLanguage() async {
    await widget.preferences.update({
      if ((draftTarget ?? savedTarget) != savedTarget)
        'preferredLanguage': draftTarget == 'browser' ? null : draftTarget,
      if ((draftMode ?? savedMode) != savedMode)
        'preferredTranslationMode': draftMode,
      if ((draftDisplay ?? savedDisplay) != savedDisplay)
        'preferredTranslationDisplay': draftDisplay,
    });
    if (!mounted) return;
    widget.translations.publicPreferencesChanged();
    setState(() {
      draftMode = draftTarget = draftDisplay = null;
      languageSaved = true;
    });
    flash(true);
  }

  Future<void> saveDateTime() async {
    await widget.preferences.update({
      if ((draftTimezone ?? savedTimezone) != savedTimezone)
        'preferredTimezone': draftTimezone!.isEmpty ? null : draftTimezone,
      if ((draftTimeFormat ?? savedTimeFormat) != savedTimeFormat)
        'preferredTimeFormat': draftTimeFormat,
    });
    if (!mounted) return;
    widget.translations.publicPreferencesChanged();
    setState(() {
      draftTimezone = draftTimeFormat = null;
      dateTimeSaved = true;
    });
    flash(false);
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final live = Localizations.localeOf(context).languageCode == 'zh'
        ? 'zh-cn'
        : 'en';
    final mode = draftMode ?? savedMode;
    return RaftLanguageRegionView(
      // The app's display language follows the device while signed out: the
      // form shows the live one, and offers no other.
      displayLanguage: live,
      displayLanguageOptions: [
        if (live == 'zh-cn') ('zh-cn', '简体中文') else ('en', 'English'),
      ],
      showChineseCoverageNotice: live == 'zh-cn',
      translationMode: mode,
      translationNotice: !s.loaded || s.available
          ? null
          : !s.serverEnabled
          ? 'Translation is not enabled on this server yet.'
          : 'This deployment has no translation provider configured, so translations cannot run yet.',
      translationTarget: draftTarget ?? savedTarget,
      translationTargetOptions: [
        ('browser', 'Browser language'),
        for (final e in messageTranslationLanguages.entries) (e.key, e.value),
      ],
      translationTargetDescription: raftFormat(
        context,
        'Browser language resolves to {language} for this browser.',
        {'language': s.effectiveLanguage.toUpperCase()},
      ),
      translationDisplay: draftDisplay ?? savedDisplay,
      languageError: null,
      languageDirty:
          (draftTarget ?? savedTarget) != savedTarget ||
          mode != savedMode ||
          (draftDisplay ?? savedDisplay) != savedDisplay,
      languageSave: languageSaved
          ? RaftLanguageSaveState.saved
          : RaftLanguageSaveState.idle,
      timezone: draftTimezone ?? savedTimezone,
      timezoneOptions: localeTimezoneOptions(savedTimezone),
      timeFormat: draftTimeFormat ?? savedTimeFormat,
      dateTimeError: null,
      dateTimeDirty:
          (draftTimezone ?? savedTimezone) != savedTimezone ||
          (draftTimeFormat ?? savedTimeFormat) != savedTimeFormat,
      dateTimeSave: dateTimeSaved
          ? RaftLanguageSaveState.saved
          : RaftLanguageSaveState.idle,
      disabled: false,
      onDisplayLanguage: (_) {},
      onTranslationMode: (v) => edit(() => draftMode = v),
      onTranslationTarget: (v) => edit(() => draftTarget = v),
      onTranslationDisplay: (v) => edit(() => draftDisplay = v),
      onSaveLanguage: () => unawaited(saveLanguage()),
      onTimezone: (v) => edit(() => draftTimezone = v, language: false),
      onTimeFormat: (v) => edit(() => draftTimeFormat = v, language: false),
      onSaveDateTime: () => unawaited(saveDateTime()),
    );
  }
}
