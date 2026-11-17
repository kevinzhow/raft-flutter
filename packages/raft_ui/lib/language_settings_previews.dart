import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

/// Form presentation only; the application owns locale and persistence. Every
/// choice applies at once; choosing the timezone "fails" so the row's failure
/// line is on show.
@RaftPreviews('Language & Region', size: Size(390, 844))
Widget languageSettingsReferencePreview() => const _LanguageSettingsPreview();

class _LanguageSettingsPreview extends StatefulWidget {
  const _LanguageSettingsPreview();
  @override
  State<_LanguageSettingsPreview> createState() =>
      _LanguageSettingsPreviewState();
}

class _LanguageSettingsPreviewState extends State<_LanguageSettingsPreview> {
  final values = <String, String>{
    'display': 'en',
    'mode': 'manual',
    'target': 'ja',
    'view': 'original',
    'timezone': 'Asia/Tokyo',
    'time': '24h',
  };
  bool timezoneRefused = false;
  void change(String key, String value) => setState(() => values[key] = value);
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(RaftSpace.x4),
    child: RaftLanguageRegionView(
      displayLanguage: values['display'] ?? 'en',
      displayLanguageOptions: const [('en', 'English'), ('zh-cn', '简体中文')],
      translationMode: values['mode'] ?? 'manual',
      translationNotice: null,
      translationTarget: values['target'] ?? 'ja',
      translationTargetOptions: const [
        ('display', 'Same as display language'),
        ('ja', 'Japanese'),
        ('en', 'English'),
      ],
      translationDisplay: values['view'] ?? 'original',
      timezone: values['timezone'] ?? 'Asia/Tokyo',
      timezoneOptions: const [
        ('', 'UTC+09:00 Tokyo'),
        ('Asia/Tokyo', 'UTC+09:00 Tokyo'),
        ('UTC', 'UTC+00:00 UTC'),
      ],
      timezoneUnlisted: const {''},
      timeFormat: values['time'] ?? '24h',
      displayLanguageSave: RaftImmediateSaveState.idle,
      translationModeSave: RaftImmediateSaveState.idle,
      translationTargetSave: RaftImmediateSaveState.idle,
      translationDisplaySave: RaftImmediateSaveState.idle,
      timezoneSave: RaftImmediateSaveState(
        failure: timezoneRefused
            ? 'Failed to update date and time preferences'
            : null,
      ),
      timeFormatSave: RaftImmediateSaveState.idle,
      settingsError: null,
      loading: false,
      onDisplayLanguage: (v) => change('display', v),
      onTranslationMode: (v) => change('mode', v),
      onTranslationTarget: (v) => change('target', v),
      onTranslationDisplay: (v) => change('view', v),
      onTimezone: (v) => setState(() => timezoneRefused = true),
      onTimeFormat: (v) => change('time', v),
    ),
  );
}
