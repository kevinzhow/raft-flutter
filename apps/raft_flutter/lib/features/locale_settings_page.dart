import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/message_translation_store.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'immediate_save.dart';
import 'management_support.dart';
import 'settings_anchor.dart';
import 'translation_language_options.dart';

/// Web `LanguageRegionSection`: every choice applies the moment it is made.
/// One request per change, nothing said once it is stored, and a failure
/// shows under its row while the control goes back to the stored value.
/// Delayed acknowledgements never apply a previous principal's values to the
/// next account's controls.
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
    translations.removeListener(translationChanged);
    super.dispose();
  }

  @override
  void clearData() {
    for (final save in saves) {
      save.reset();
    }
  }

  @override
  Future<void> loadData(int request, int generation) async {}

  void changed() {
    if (mounted) setState(() {});
  }

  late final displayLanguageSave = ImmediateSave<String>(changed),
      modeSave = ImmediateSave<String>(changed),
      targetSave = ImmediateSave<String>(changed),
      displaySave = ImmediateSave<String>(changed),
      timezoneSave = ImmediateSave<String>(changed),
      timeFormatSave = ImmediateSave<String>(changed);
  List<ImmediateSave<String>> get saves => [
    displayLanguageSave,
    modeSave,
    targetSave,
    displaySave,
    timezoneSave,
    timeFormatSave,
  ];

  String get savedMode => translations.settings.mode.name;
  String get savedTarget =>
      translations.settings.preferredLanguage ?? followDisplayLanguageTarget;
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

  /// One `PATCH /auth/me`, then the answer joins the signed-in user (Web
  /// `useAuthStore.setState({ user: { ...user, ...data } })`): no second read.
  /// What was sent holds where the answer does not name it. An answer for a
  /// previous account is dropped.
  Future<void> _store(Map<String, Object?> fields) async {
    final scope = authority;
    final data = await w.client.patch('/auth/me', data: fields);
    if (!mounted || scope != authority) return;
    final current = w.client.user?.json;
    if (current == null) return;
    await w.client.replaceUser({
      ...current,
      ...fields,
      if (data is Map) ...Map<String, dynamic>.from(data),
    });
  }

  String _languageFailure(Object e) => userErrorText(
    e,
    fallback: 'Failed to update language preferences',
    where: 'language settings',
  );
  String _dateTimeFailure(Object e) => userErrorText(
    e,
    fallback: 'Failed to update date and time preferences',
    where: 'date and time settings',
  );

  void changeDisplayLanguage(String next) {
    if (next == liveLocale(context)) return;
    // Web persistDisplayLanguage: whatever went wrong, the select says the
    // setting's own message, not the server's.
    unawaited(
      displayLanguageSave.run(
        next,
        () => _store({'displayLanguage': next}),
        (_) => 'Failed to update language preferences',
      ),
    );
  }

  void changeMode(String next) => unawaited(
    modeSave.run(
      next,
      () => _store({'preferredTranslationMode': next}),
      _languageFailure,
    ),
  );

  void changeTarget(String next) => unawaited(
    targetSave.run(
      next,
      () => _store({
        'preferredLanguage': next == followDisplayLanguageTarget ? null : next,
      }),
      _languageFailure,
    ),
  );

  void changeDisplay(String next) => unawaited(
    displaySave.run(
      next,
      () => _store({'preferredTranslationDisplay': next}),
      _languageFailure,
    ),
  );

  void changeTimezone(String next) => unawaited(
    timezoneSave.run(
      next,
      () => _store({'preferredTimezone': next.isEmpty ? null : next}),
      _dateTimeFailure,
    ),
  );

  void changeTimeFormat(String next) => unawaited(
    timeFormatSave.run(
      next,
      () => _store({'preferredTimeFormat': next}),
      _dateTimeFailure,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final settings = translations.settings;
    final choices = localeTimezoneChoices(savedTimezone);
    return RaftLanguageRegionView(
      displayLanguage: displayLanguageSave.pending ?? liveLocale(context),
      displayLanguageOptions: const [('en', 'English'), ('zh-cn', '简体中文')],
      translationMode: modeSave.pending ?? savedMode,
      translationNotice: !settings.loaded || settings.available
          ? null
          : !settings.serverEnabled
          ? settings.canManage
                ? 'Translation is not enabled on this server yet. Turn it on under Administration → Translation.'
                : 'Translation is not enabled on this server yet.'
          : 'This deployment has no translation provider configured, so translations cannot run yet.',
      translationTarget: targetSave.pending ?? savedTarget,
      translationTargetOptions: translationTargetOptions(context),
      translationDisplay: displaySave.pending ?? savedDisplay,
      timezone: timezoneSave.pending ?? savedTimezone,
      timezoneOptions: choices.options,
      timezoneUnlisted: choices.unlisted,
      timeFormat: timeFormatSave.pending ?? savedTimeFormat,
      displayLanguageSave: displayLanguageSave.state,
      translationModeSave: modeSave.state,
      translationTargetSave: targetSave.state,
      translationDisplaySave: displaySave.state,
      timezoneSave: timezoneSave.state,
      timeFormatSave: timeFormatSave.state,
      settingsError: translations.settingsError,
      loading: translations.settingsLoading,
      onDisplayLanguage: changeDisplayLanguage,
      onTranslationMode: changeMode,
      onTranslationTarget: changeTarget,
      onTranslationDisplay: changeDisplay,
      onTimezone: changeTimezone,
      onTimeFormat: changeTimeFormat,
      anchor: (id, child) => RaftSettingsAnchor(id: id, child: child),
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

/// Web `formatTimezoneLabel`: `UTC+08:00 Shanghai`, the offset then the
/// zone's city with spaces (Jasper, #triage:c95a5e53); a zone without a
/// region (UTC) keeps its id.
String _timezoneLabel(String zone, DateTime now) {
  final minutes = _offsetMinutes(zone, now);
  final abs = minutes.abs();
  final sign = minutes < 0 ? '-' : '+';
  final city = zone.substring(zone.lastIndexOf('/') + 1).replaceAll('_', ' ');
  return 'UTC$sign${(abs ~/ 60).toString().padLeft(2, '0')}:${(abs % 60).toString().padLeft(2, '0')} $city';
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

/// The timezone choices of Language & Region for a [preferred] zone ('' = the
/// device's) and the values the open list leaves out (`hiddenTimezoneOptionValues`:
/// the empty choice and, with no preference, the device zone it stands for).
({List<RaftLanguageOption> options, Set<String> unlisted}) _timezoneChoices(
  String preferred,
) {
  final now = DateTime.now();
  final effective = preferred.isEmpty ? _detectTimezone(now) : preferred;
  final ids = {..._commonTimezones, effective}.toList()
    ..sort((a, b) {
      final byOffset = _offsetMinutes(a, now).compareTo(_offsetMinutes(b, now));
      return byOffset != 0 ? byOffset : a.compareTo(b);
    });
  return (
    options: [
      ('', _timezoneLabel(effective, now)),
      for (final id in ids) (id, _timezoneLabel(id, now)),
    ],
    unlisted: {'', if (preferred.isEmpty) effective},
  );
}

/// The timezone choices of Language & Region for a [preferred] zone, and the
/// values its open list leaves out; also for the signed-out public page.
({List<RaftLanguageOption> options, Set<String> unlisted})
localeTimezoneChoices(String preferred) {
  _initializeTimezones();
  return _timezoneChoices(preferred);
}

/// The timezone options of [localeTimezoneChoices].
List<RaftLanguageOption> localeTimezoneOptions(String preferred) =>
    localeTimezoneChoices(preferred).options;
