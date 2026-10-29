import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/message_translation_store.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart';

/// Source Language & Region preference contract. Delayed acknowledgements never
/// apply a previous principal's values to the next account's controls.
class LocaleSettingsPage extends StatefulWidget {
  const LocaleSettingsPage({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<LocaleSettingsPage> createState() => _LocaleSettingsPageState();
}

class _LocaleSettingsPageState extends ManagementState<LocaleSettingsPage> {
  @override
  WorkspaceController get w => widget.controller;
  @override
  String get authority => '${w.client.generation}|${w.client.user?.id}';
  late MessageTranslationStore translations = w.services.translations;
  @override
  void initState() {
    super.initState();
    _initializeTimezones();
    startManagement();
    translations.addListener(translationChanged);
    // Web LanguageRegionSection `loadSettings` on mount (retries a failure).
    translations.ensureSettings(force: translations.settingsError != null);
  }

  void translationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant LocaleSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(translations, w.services.translations)) {
      translations.removeListener(translationChanged);
      translations = w.services.translations..addListener(translationChanged);
      translations.ensureSettings();
    }
  }

  @override
  void dispose() {
    for (final timer in savedTimers.values) {
      timer.cancel();
    }
    translations.removeListener(translationChanged);
    super.dispose();
  }

  @override
  void clearData() {
    draftDisplayLanguage = draftMode = draftTarget = draftDisplay = null;
    draftTimezone = draftTimeFormat = null;
    languageError = dateTimeError = null;
    savingLanguage = savingDateTime = false;
  }

  @override
  Future<void> loadData(int request, int generation) async {}

  // Drafts of the two forms; null follows the saved value (Web re-syncs the
  // form state whenever the saved value changes).
  String? draftDisplayLanguage,
      draftMode,
      draftTarget,
      draftDisplay,
      draftTimezone,
      draftTimeFormat;
  final savedTimers = <bool, Timer>{};
  // ignore: raft_lints/avoid_imperative_notice_state -- Each clears when its form is edited, when its save starts, and on account change (clearData).
  String? languageError, dateTimeError;
  bool savingLanguage = false, savingDateTime = false;
  bool languageSaved = false, dateTimeSaved = false;

  String get savedMode => translations.settings.mode.name;
  String get savedTarget =>
      translations.settings.preferredLanguage ?? 'browser';
  String get savedDisplay => translations.settings.display.name;
  String get savedTimezone =>
      w.client.user?.string('preferredTimezone').trim() ?? '';

  /// `effectiveTimeFormat = preferred ?? detectBrowserTimeFormat()`
  /// (translationStore.ts:271): a null / `auto` preference follows the device.
  String get savedTimeFormat => effectiveTimeFormat(
    w.client.user?.json['preferredTimeFormat'],
    device24Hour: device24Hour,
  );

  /// The device's 24-hour clock setting; refreshed with the MediaQuery.
  bool device24Hour = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    device24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
  }

  /// The live UI locale in Web's `Locale` ids.
  String liveLocale(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh' ? 'zh-cn' : 'en';

  bool languageDirty(BuildContext context) =>
      (draftDisplayLanguage ?? liveLocale(context)) != liveLocale(context) ||
      (draftTarget ?? savedTarget) != savedTarget ||
      (draftMode ?? savedMode) != savedMode ||
      (draftDisplay ?? savedDisplay) != savedDisplay;
  bool get dateTimeDirty =>
      (draftTimezone ?? savedTimezone) != savedTimezone ||
      (draftTimeFormat ?? savedTimeFormat) != savedTimeFormat;

  void edit(void Function() change, {bool language = true}) => setState(() {
    change();
    if (language) {
      languageSaved = false;
      languageError = null;
    } else {
      dateTimeSaved = false;
      dateTimeError = null;
    }
  });

  Future<void> patch(
    Map<String, Object?> fields, {
    required bool language,
    required String failure,
  }) async {
    if (fields.isEmpty) return;
    final scope = authority;
    setState(() {
      // Web handleSave*: the previous attempt's error and "saved" end here.
      if (language) {
        savingLanguage = true;
        languageSaved = false;
        languageError = null;
      } else {
        savingDateTime = true;
        dateTimeSaved = false;
        dateTimeError = null;
      }
    });
    try {
      await w.client.patch('/auth/me', data: fields);
      if (!mounted || scope != authority) return;
      await w.client.reloadUser();
      if (!mounted || scope != authority) return;
      setState(() {
        if (language) {
          draftDisplayLanguage = draftMode = draftTarget = draftDisplay = null;
          languageSaved = true;
        } else {
          draftTimezone = draftTimeFormat = null;
          dateTimeSaved = true;
        }
      });
      savedTimers[language]?.cancel();
      savedTimers[language] = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            if (language) {
              languageSaved = false;
            } else {
              dateTimeSaved = false;
            }
          });
        }
      });
    } catch (e) {
      if (mounted && scope == authority) {
        setState(() {
          final message = userErrorText(
            e,
            fallback: failure,
            where: 'locale settings',
          );
          if (language) {
            languageError = message;
          } else {
            dateTimeError = message;
          }
        });
      }
    } finally {
      if (mounted && scope == authority) {
        setState(() {
          if (language) {
            savingLanguage = false;
          } else {
            savingDateTime = false;
          }
        });
      }
    }
  }

  Future<void> saveLanguage(BuildContext context) => patch(
    {
      if ((draftDisplayLanguage ?? liveLocale(context)) != liveLocale(context))
        'displayLanguage': draftDisplayLanguage,
      if ((draftTarget ?? savedTarget) != savedTarget)
        'preferredLanguage': draftTarget == 'browser' ? null : draftTarget,
      if ((draftMode ?? savedMode) != savedMode)
        'preferredTranslationMode': draftMode,
      if ((draftDisplay ?? savedDisplay) != savedDisplay)
        'preferredTranslationDisplay': draftDisplay,
    },
    language: true,
    failure: 'Failed to update language preferences',
  );

  Future<void> saveDateTime() => patch(
    {
      if ((draftTimezone ?? savedTimezone) != savedTimezone)
        'preferredTimezone': draftTimezone!.isEmpty ? null : draftTimezone,
      if ((draftTimeFormat ?? savedTimeFormat) != savedTimeFormat)
        'preferredTimeFormat': draftTimeFormat,
    },
    language: false,
    failure: 'Failed to update date and time preferences',
  );

  @override
  Widget build(BuildContext context) {
    final settings = translations.settings;
    final busy = translations.settingsLoading;
    final mode = draftMode ?? savedMode;
    final effective = settings.effectiveLanguage.toUpperCase();
    final zones = _timezoneOptions(savedTimezone);
    return RaftLanguageRegionView(
      displayLanguage: draftDisplayLanguage ?? liveLocale(context),
      displayLanguageOptions: const [('en', 'English'), ('zh-cn', '简体中文')],
      showChineseCoverageNotice: liveLocale(context) == 'zh-cn',
      translationMode: mode,
      translationNotice: !settings.loaded || settings.available
          ? null
          : !settings.serverEnabled
          ? settings.canManage
                ? 'Translation is not enabled on this server yet. Turn it on under Administration → Translation.'
                : 'Translation is not enabled on this server yet.'
          : 'This deployment has no translation provider configured, so translations cannot run yet.',
      translationTarget: draftTarget ?? savedTarget,
      translationTargetOptions: [
        ('browser', 'Browser language'),
        for (final e in messageTranslationLanguages.entries) (e.key, e.value),
      ],
      translationTargetDescription: raftFormat(
        context,
        'Browser language resolves to {language} for this browser.',
        {'language': effective},
      ),
      translationDisplay: draftDisplay ?? savedDisplay,
      languageError: languageError ?? translations.settingsError,
      languageDirty: languageDirty(context),
      languageSave: savingLanguage
          ? RaftLanguageSaveState.saving
          : languageSaved
          ? RaftLanguageSaveState.saved
          : RaftLanguageSaveState.idle,
      timezone: draftTimezone ?? savedTimezone,
      timezoneOptions: zones,
      timeFormat: draftTimeFormat ?? savedTimeFormat,
      dateTimeError: dateTimeError ?? translations.settingsError,
      dateTimeDirty: dateTimeDirty,
      dateTimeSave: savingDateTime
          ? RaftLanguageSaveState.saving
          : dateTimeSaved
          ? RaftLanguageSaveState.saved
          : RaftLanguageSaveState.idle,
      disabled: busy || savingLanguage || savingDateTime,
      onDisplayLanguage: (v) => edit(() => draftDisplayLanguage = v),
      onTranslationMode: (v) => edit(() => draftMode = v),
      onTranslationTarget: (v) => edit(() => draftTarget = v),
      onTranslationDisplay: (v) => edit(() => draftDisplay = v),
      onSaveLanguage: () => saveLanguage(context),
      onTimezone: (v) => edit(() => draftTimezone = v, language: false),
      onTimeFormat: (v) => edit(() => draftTimeFormat = v, language: false),
      onSaveDateTime: saveDateTime,
    );
  }
}

/// Web `effectiveTimeFormat`: an explicit `12h` / `24h` preference, else the
/// device default (`normalizeTimeFormatPreference` drops anything else).
String effectiveTimeFormat(Object? preferred, {required bool device24Hour}) =>
    switch (preferred) {
      '12h' => '12h',
      '24h' => '24h',
      _ => device24Hour ? '24h' : '12h',
    };

// ------------------------------------------------------------- timezones

/// Web `COMMON_TIMEZONE_IDS` (translationStore.ts).
const _commonTimezones = [
  'UTC',
  'America/Anchorage',
  'America/Los_Angeles',
  'America/Denver',
  'America/Phoenix',
  'America/Chicago',
  'America/New_York',
  'America/Toronto',
  'America/Mexico_City',
  'America/Bogota',
  'America/Lima',
  'America/Sao_Paulo',
  'America/Argentina/Buenos_Aires',
  'Europe/London',
  'Europe/Dublin',
  'Europe/Paris',
  'Europe/Berlin',
  'Europe/Madrid',
  'Europe/Rome',
  'Europe/Amsterdam',
  'Europe/Zurich',
  'Europe/Stockholm',
  'Europe/Warsaw',
  'Europe/Istanbul',
  'Europe/Moscow',
  'Africa/Cairo',
  'Africa/Johannesburg',
  'Asia/Dubai',
  'Asia/Kolkata',
  'Asia/Bangkok',
  'Asia/Singapore',
  'Asia/Shanghai',
  'Asia/Hong_Kong',
  'Asia/Taipei',
  'Asia/Tokyo',
  'Asia/Seoul',
  'Australia/Sydney',
  'Pacific/Auckland',
];

int _offsetMinutes(String zone, DateTime now) {
  if (zone == 'UTC') return 0;
  return tz.TZDateTime.from(now, tz.getLocation(zone)).timeZoneOffset.inMinutes;
}

/// `formatTimezoneLabel`: `UTC+08:00 Asia/Shanghai`.
String _timezoneLabel(String zone, DateTime now) {
  final minutes = _offsetMinutes(zone, now);
  final abs = minutes.abs();
  final sign = minutes < 0 ? '-' : '+';
  return 'UTC$sign${(abs ~/ 60).toString().padLeft(2, '0')}:${(abs % 60).toString().padLeft(2, '0')} $zone';
}

/// The browser's IANA zone: `TZ` when it names one (Linux hosts, tests), else
/// the first common zone sharing the device's current UTC offset.
String _detectTimezone(DateTime now) {
  final env = Platform.environment['TZ'];
  if (env != null && env.isNotEmpty) {
    try {
      tz.getLocation(env);
      return env;
    } catch (_) {}
  }
  final offset = now.timeZoneOffset.inMinutes;
  for (final zone in _commonTimezones) {
    if (_offsetMinutes(zone, now) == offset) return zone;
  }
  return 'UTC';
}

bool _timezonesReady = false;
void _initializeTimezones() {
  if (_timezonesReady) return;
  tzdata.initializeTimeZones();
  _timezonesReady = true;
}

List<RaftLanguageOption> _timezoneOptions(String preferred) {
  final now = DateTime.now();
  final effective = preferred.isEmpty ? _detectTimezone(now) : preferred;
  final ids = {..._commonTimezones, effective}.toList()
    ..sort((a, b) {
      final byOffset = _offsetMinutes(a, now).compareTo(_offsetMinutes(b, now));
      return byOffset != 0 ? byOffset : a.compareTo(b);
    });
  return [
    ('', _timezoneLabel(effective, now)),
    for (final id in ids) (id, _timezoneLabel(id, now)),
  ];
}

/// The timezone choices of Language & Region for a [preferred] zone ('' = the
/// device's), for the signed-out public page's own preferences form.
List<RaftLanguageOption> localeTimezoneOptions(String preferred) {
  _initializeTimezones();
  return _timezoneOptions(preferred);
}
