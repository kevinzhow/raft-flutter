// Presentation of the Web Settings "Language & Region" tab
// (packages/web/src/components/settings/SettingsPanel.tsx
// LanguageRegionSection): a Language card (display language, translation
// mode, translation target, default view, Save) and a Date & Time card
// (timezone, time format, Save). The app page owns the draft state, loading
// and saving.
import 'raft/segmented_control.dart'
    show RaftSegmentedControl, RaftSegmentedOption, RaftSegmentedStyle;

import 'package:flutter/material.dart';

import 'error_presentation.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'select_field.dart';
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'theme.dart';

/// One select / segmented option (`value`, English label key).
typedef RaftLanguageOption = (String value, String label);

/// The Save button of a card: `Save` / `Saving…` / `<Check /> Saved`.
enum RaftLanguageSaveState { idle, saving, saved }

class RaftLanguageRegionView extends StatelessWidget {
  const RaftLanguageRegionView({
    super.key,
    required this.displayLanguage,
    required this.displayLanguageOptions,
    required this.showChineseCoverageNotice,
    required this.translationMode,
    required this.translationNotice,
    required this.translationTarget,
    required this.translationTargetOptions,
    required this.translationTargetDescription,
    required this.translationDisplay,
    required this.languageError,
    required this.languageDirty,
    required this.languageSave,
    required this.timezone,
    required this.timezoneOptions,
    required this.timeFormat,
    required this.dateTimeError,
    required this.dateTimeDirty,
    required this.dateTimeSave,
    required this.disabled,
    required this.onDisplayLanguage,
    required this.onTranslationMode,
    required this.onTranslationTarget,
    required this.onTranslationDisplay,
    required this.onSaveLanguage,
    required this.onTimezone,
    required this.onTimeFormat,
    required this.onSaveDateTime,
  });

  final String displayLanguage;
  final List<RaftLanguageOption> displayLanguageOptions;
  final bool showChineseCoverageNotice;
  final String translationMode; // auto | manual | off
  final String? translationNotice;
  final String translationTarget;
  final List<RaftLanguageOption> translationTargetOptions;
  final String translationTargetDescription;
  final String translationDisplay; // translated | original | bilingual
  final String? languageError;
  final bool languageDirty;
  final RaftLanguageSaveState languageSave;
  final String timezone;
  final List<RaftLanguageOption> timezoneOptions;
  final String timeFormat; // 12h | 24h
  final String? dateTimeError;
  final bool dateTimeDirty;
  final RaftLanguageSaveState dateTimeSave;
  final bool disabled;
  final ValueChanged<String> onDisplayLanguage,
      onTranslationMode,
      onTranslationTarget,
      onTranslationDisplay,
      onTimezone,
      onTimeFormat;
  final VoidCallback onSaveLanguage, onSaveDateTime;

  static const _maxSelectWidth = 384.0; // max-w-sm

  Widget _select(
    BuildContext context, {
    required String value,
    required List<RaftLanguageOption> options,
    required ValueChanged<String> onChanged,
    required String label,
    Key? key,
  }) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxSelectWidth),
      child: RaftSelectField<String>(
        key: key,
        label: label,
        value: options.any((o) => o.$1 == value) ? value : null,
        items: [
          for (final (v, text) in options)
            RaftSelectItem(value: v, label: raftText(context, text)),
        ],
        onChanged: disabled
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
      ),
    ),
  );

  Widget _segmented(
    BuildContext context, {
    required String value,
    required List<RaftLanguageOption> options,
    required ValueChanged<String> onChanged,
    required String label,
    Key? key,
  }) => Align(
    alignment: Alignment.centerLeft,
    child: RaftSegmentedControl<String>(
      key: key,
      legacyStyle: RaftSegmentedStyle.recipe,
      label: raftText(context, label),
      value: value,
      // settings.language.modeOff is 关闭; the plain `Off` catalog entry is
      // 已关闭 (a state), which other Web keys use.
      items: [
        for (final (v, text) in options)
          RaftSegmentedOption(
            value: v,
            label: text == 'Off' ? raftTextZh(context, 'Off', '关闭') : text,
          ),
      ],
      onChanged: disabled ? null : onChanged,
    ),
  );

  Widget _save(
    RaftLanguageSaveState state,
    bool dirty,
    VoidCallback onPressed, {
    Key? key,
  }) => Align(
    alignment: Alignment.centerLeft,
    child: RaftSettingsRecipeButton(
      key: key,
      label: switch (state) {
        RaftLanguageSaveState.saving => 'Saving…',
        RaftLanguageSaveState.saved => 'Saved',
        _ => 'Save',
      },
      glyph: state == RaftLanguageSaveState.saved ? RaftGlyph.check : null,
      glyphSize: 14,
      variant: RaftButtonRecipeVariant.accent,
      size: RaftButtonRecipeSize.sm,
      onPressed: !dirty || state == RaftLanguageSaveState.saving || disabled
          ? null
          : onPressed,
    ),
  );

  Widget _selectBlock(Widget block) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: block);

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16); // `space-y-4`
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RaftSettingsSectionHeader(
          label: 'Language',
          glyph: RaftGlyph.languages,
        ),
        RaftSettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A Select's trailing hidden <input> makes `space-y-3` leave the
              // Select a 12px bottom margin inside its block.
              _selectBlock(
                RaftSettingsPreference(
                  title: 'Display language',
                  description: 'Choose the language for the app interface. This is separate from message translation.',
                  child: _select(
                    context,
                    key: const ValueKey('display-language-select'),
                    label: 'Display language',
                    value: displayLanguage,
                    options: displayLanguageOptions,
                    onChanged: onDisplayLanguage,
                  ),
                ),
              ),
              if (showChineseCoverageNotice)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    raftTextZh(
                      context,
                      'Simplified Chinese is still being refined; some pages may still appear in English.',
                      '简体中文仍在完善，部分页面可能仍显示英文。',
                    ),
                    style: RaftSettingsText(RaftTokens.of(context)).description,
                  ),
                ),
              RaftSettingsPreference(
                gapBefore: 16,
                title: 'Translation mode',
                description: 'Auto translates visible messages. Manual adds Translate to each message menu. Off keeps originals only.',
                notice: translationNotice,
                child: _segmented(
                  context,
                  key: const ValueKey('translation-mode'),
                  label: 'Message translation mode',
                  value: translationMode,
                  options: const [
                    ('auto', 'Auto'),
                    ('manual', 'Manual'),
                    ('off', 'Off'),
                  ],
                  onChanged: onTranslationMode,
                ),
              ),
              if (translationMode != 'off') ...[
                _selectBlock(
                  RaftSettingsPreference(
                    gapBefore: 16,
                    title: 'Translation target',
                    description: translationTargetDescription,
                    child: _select(
                      context,
                      key: const ValueKey('translation-target'),
                      label: 'Translation target',
                      value: translationTarget,
                      options: translationTargetOptions,
                      onChanged: onTranslationTarget,
                    ),
                  ),
                ),
                RaftSettingsPreference(
                  gapBefore: 16,
                  title: 'Default view',
                  description: 'Choose whether messages show translation, original, or both.',
                  child: _segmented(
                    context,
                    key: const ValueKey('translation-display'),
                    label: 'Message translation display',
                    value: translationDisplay,
                    options: const [
                      ('translated', 'Translated'),
                      ('original', 'Original'),
                      ('bilingual', 'Bilingual'),
                    ],
                    onChanged: onTranslationDisplay,
                  ),
                ),
              ],
              if (languageError != null) ...[
                gap,
                // `<Banner intent="warning" density="sm" className="font-bold">`
                RaftErrorBanner(languageError!, small: true, bold: true),
              ],
              gap,
              _save(
                languageSave,
                languageDirty,
                onSaveLanguage,
                key: const ValueKey('language-save'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24), // mb-6
        const RaftSettingsSectionHeader(
          label: 'Date & Time',
          glyph: RaftGlyph.clock,
        ),
        RaftSettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftSettingsPreference(
                title: 'Timezone',
                description:
                    'Used for local timestamps and scheduling defaults.',
                child: _select(
                  context,
                  key: const ValueKey('timezone-select'),
                  label: 'Timezone',
                  value: timezone,
                  options: timezoneOptions,
                  onChanged: onTimezone,
                ),
              ),
              RaftSettingsPreference(
                gapBefore: 12,
                title: 'Time format',
                description: 'Display only. Does not affect agent behavior.',
                child: _segmented(
                  context,
                  key: const ValueKey('time-format'),
                  label: 'Time format',
                  value: timeFormat,
                  options: const [('12h', '12-hour'), ('24h', '24-hour')],
                  onChanged: onTimeFormat,
                ),
              ),
              if (dateTimeError != null) ...[
                gap,
                // `<Banner intent="warning" density="sm" className="font-bold">`
                RaftErrorBanner(dateTimeError!, small: true, bold: true),
              ],
              gap,
              _save(
                dateTimeSave,
                dateTimeDirty,
                onSaveDateTime,
                key: const ValueKey('date-time-save'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24), // mb-6
      ],
    );
  }
}
