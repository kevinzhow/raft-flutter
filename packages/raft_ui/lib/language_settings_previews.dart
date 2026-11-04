import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

/// Form presentation only; the application owns locale and persistence.
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
  String savedDisplay = 'en';
  bool languageDirty = false,
      dateTimeDirty = false,
      languageSaved = false,
      dateTimeSaved = false;
  void change(String key, String value, {bool dateTime = false}) =>
      setState(() {
        values[key] = value;
        if (dateTime) {
          dateTimeDirty = true;
          dateTimeSaved = false;
        } else {
          languageDirty = true;
          languageSaved = false;
        }
      });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(RaftSpace.x4),
    child: RaftLanguageRegionView(
      displayLanguage: values['display'] ?? 'en',
      displayLanguageOptions: const [('en', 'English'), ('zh-cn', '简体中文')],
      showChineseCoverageNotice: savedDisplay == 'zh-cn',
      translationMode: values['mode'] ?? 'manual',
      translationNotice: null,
      translationTarget: values['target'] ?? 'ja',
      translationTargetOptions: const [('ja', 'Japanese'), ('en', 'English')],
      translationTargetDescription:
          'The browser language resolves to JA in this browser.',
      translationDisplay: values['view'] ?? 'original',
      languageError: null,
      languageDirty: languageDirty,
      languageSave: languageSaved
          ? RaftLanguageSaveState.saved
          : RaftLanguageSaveState.idle,
      timezone: values['timezone'] ?? 'Asia/Tokyo',
      timezoneOptions: const [
        ('Asia/Tokyo', 'UTC+09:00 Asia/Tokyo'),
        ('UTC', 'UTC'),
      ],
      timeFormat: values['time'] ?? '24h',
      dateTimeError: null,
      dateTimeDirty: dateTimeDirty,
      dateTimeSave: dateTimeSaved
          ? RaftLanguageSaveState.saved
          : RaftLanguageSaveState.idle,
      disabled: false,
      onDisplayLanguage: (v) => change('display', v),
      onTranslationMode: (v) => change('mode', v),
      onTranslationTarget: (v) => change('target', v),
      onTranslationDisplay: (v) => change('view', v),
      onTimezone: (v) => change('timezone', v, dateTime: true),
      onTimeFormat: (v) => change('time', v, dateTime: true),
      onSaveLanguage: () => setState(() {
        savedDisplay = values['display'] ?? 'en';
        languageDirty = false;
        languageSaved = true;
      }),
      onSaveDateTime: () => setState(() {
        dateTimeDirty = false;
        dateTimeSaved = true;
      }),
    ),
  );
}
