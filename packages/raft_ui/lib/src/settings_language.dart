// Presentation of the Web v1.24 Settings "Language & Region" tab
// (packages/web/src/features/settings/language-region/LanguageRegionSection.tsx):
// a Language group (display language, translation mode, translation target,
// default view) and a Date & time group (timezone, time format), each a
// `ListRowGroup` of plain settings rows whose control ends the row (under the
// text when the group is narrower than 32rem). Every choice applies the moment
// it is made: there is no Save button, nothing is said once it is stored, and
// a failed change shows its message under the row (`SaveStatus`). The app page
// owns the values, the requests and the failures.
import 'raft/segmented_control.dart'
    show RaftSegmentedControl, RaftSegmentedOption;

import 'package:flutter/material.dart';

import 'error_presentation.dart';
import 'icons.dart';
import 'localization.dart';
import 'notification_settings_rows.dart';
import 'save_status.dart';
import 'select_field.dart';
import 'settings_layout.dart';
import 'theme.dart';

/// One select / segmented option (`value`, English label key).
typedef RaftLanguageOption = (String value, String label);

class RaftLanguageRegionView extends StatelessWidget {
  const RaftLanguageRegionView({
    super.key,
    required this.displayLanguage,
    required this.displayLanguageOptions,
    required this.translationMode,
    required this.translationNotice,
    required this.translationTarget,
    required this.translationTargetOptions,
    this.anchor,
    required this.translationDisplay,
    required this.timezone,
    required this.timezoneOptions,
    required this.timezoneUnlisted,
    required this.timeFormat,
    required this.displayLanguageSave,
    required this.translationModeSave,
    required this.translationTargetSave,
    required this.translationDisplaySave,
    required this.timezoneSave,
    required this.timeFormatSave,
    required this.settingsError,
    required this.loading,
    required this.onDisplayLanguage,
    required this.onTranslationMode,
    required this.onTranslationTarget,
    required this.onTranslationDisplay,
    required this.onTimezone,
    required this.onTimeFormat,
  });

  final String displayLanguage;
  final List<RaftLanguageOption> displayLanguageOptions;
  final String translationMode; // auto | manual | off
  final String? translationNotice;
  final String translationTarget;
  final List<RaftLanguageOption> translationTargetOptions;

  /// Marks a setting's row as the target of `#<id>` (Web: `id="<id>"` on the
  /// row); the app wraps it in its anchor. Null leaves the rows plain.
  final RaftSettingsAnchorBuilder? anchor;
  final String translationDisplay; // translated | original | bilingual
  final String timezone;
  final List<RaftLanguageOption> timezoneOptions;

  /// Timezone values the open list leaves out: the empty choice and, with no
  /// preference, the device's zone it stands for (`hiddenTimezoneOptionValues`).
  final Set<String> timezoneUnlisted;
  final String timeFormat; // 12h | 24h

  /// Each row's own save: its control is disabled while it saves and a failure
  /// shows under it until its next change.
  final RaftImmediateSaveState displayLanguageSave,
      translationModeSave,
      translationTargetSave,
      translationDisplaySave,
      timezoneSave,
      timeFormatSave;

  /// The failed read of the translation settings, under both groups.
  final String? settingsError;

  /// The translation settings are being read: every control waits.
  final bool loading;
  final ValueChanged<String> onDisplayLanguage,
      onTranslationMode,
      onTranslationTarget,
      onTranslationDisplay,
      onTimezone,
      onTimeFormat;

  Widget _select({
    required Key key,
    required String value,
    required List<RaftLanguageOption> options,
    required ValueChanged<String> onChanged,
    required String label,
    required RaftImmediateSaveState save,
    String? placeholder,
    Set<String> unlisted = const {},
    bool hideSelected = false,
  }) => RaftSettingsSelect<String>(
    key: key,
    label: label,
    placeholder: placeholder,
    // An empty value is no choice (base-ui Select): the field shows its
    // placeholder, as Web's Timezone does with no preference.
    value: value.isNotEmpty && options.any((o) => o.$1 == value) ? value : null,
    items: [
      for (final (v, text) in options)
        RaftSelectItem(
          value: v,
          label: text,
          listed: !unlisted.contains(v) && !(hideSelected && v == value),
        ),
    ],
    onChanged: loading || save.saving
        ? null
        : (v) {
            if (v != null && v != value) onChanged(v);
          },
  );

  Widget _segmented(
    BuildContext context, {
    required Key key,
    required String value,
    required List<RaftLanguageOption> options,
    required ValueChanged<String> onChanged,
    required String label,
    required RaftImmediateSaveState save,
  }) => RaftSegmentedControl<String>(
    key: key,
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
    onChanged: loading || save.saving
        ? null
        : (v) {
            if (v != value) onChanged(v);
          },
  );

  /// The row as the target of `#<id>`.
  Widget Function(Widget row)? _anchored(String id) =>
      anchor == null ? null : (row) => anchor!(id, row);

  RaftSettingsRowSpec _row({
    required Key key,
    required String title,
    required Widget control,
    required RaftImmediateSaveState save,
    Widget Function(Widget row)? wrap,
    String? notice,
    bool wrapNarrow = true,
  }) => RaftSettingsRowSpec(
    key: key,
    title: title,
    status: _status(notice: notice, save: save),
    control: control,
    wrapNarrow: wrapNarrow,
    wrap: wrap,
  );

  // Notice then failure, both under the title (Web: the unavailable line, then
  // `ImmediateSaveStatus`).
  Widget? _status({String? notice, required RaftImmediateSaveState save}) {
    if (notice == null && save.failure == null) return null;
    return Builder(
      builder: (context) {
        final t = RaftTokens.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  raftText(context, notice),
                  key: const ValueKey('translation-unavailable-notice'),
                  style: RaftSettingsText(t, semanticTypography: true)
                      .description
                      .copyWith(
                        fontWeight: FontWeight.w700,
                        color: t.colors['warning-strong'],
                      ),
                ),
              ),
            if (save.failure case final failure?) RaftSaveStatus(failure),
          ],
        );
      },
    );
  }

  Widget _banner(String? message) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12), // mt-3
          child: RaftErrorBanner(message, small: true),
        );

  @override
  Widget build(BuildContext context) {
    final off = translationMode == 'off';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RaftSettingsSectionHeader(
          label: 'Language',
          glyph: RaftGlyph.languages,
        ),
        RaftSettingsRowGroup(
          key: const ValueKey('language-region-card'),
          rows: [
            _row(
              key: const ValueKey('display-language'),
              wrap: _anchored('display-language'),
              title: 'Display language',
              save: displayLanguageSave,
              control: _select(
                key: const ValueKey('display-language-select'),
                label: 'Display language',
                value: displayLanguage,
                options: displayLanguageOptions,
                onChanged: onDisplayLanguage,
                save: displayLanguageSave,
              ),
            ),
            _row(
              key: const ValueKey('translation-mode-row'),
              wrap: _anchored('translation-mode'),
              title: 'Translation mode',
              notice: translationNotice,
              save: translationModeSave,
              control: _segmented(
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
                save: translationModeSave,
              ),
            ),
            if (!off)
              _row(
                key: const ValueKey('translation-target-row'),
                title: 'Translation target',
                save: translationTargetSave,
                control: _select(
                  key: const ValueKey('translation-target'),
                  label: 'Translation target',
                  placeholder: 'Preferred language',
                  value: translationTarget,
                  options: translationTargetOptions,
                  onChanged: onTranslationTarget,
                  save: translationTargetSave,
                  hideSelected: true,
                ),
              ),
            if (!off)
              _row(
                key: const ValueKey('translation-display-row'),
                title: 'Default view',
                save: translationDisplaySave,
                control: _segmented(
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
                  save: translationDisplaySave,
                ),
              ),
          ],
        ),
        _banner(settingsError),
        const SizedBox(height: 24), // mb-6
        const RaftSettingsSectionHeader(
          label: 'Date & time',
          glyph: RaftGlyph.clock,
        ),
        RaftSettingsRowGroup(
          key: const ValueKey('date-time-card'),
          rows: [
            _row(
              key: const ValueKey('timezone-row'),
              wrap: _anchored('timezone'),
              title: 'Timezone',
              save: timezoneSave,
              control: _select(
                key: const ValueKey('timezone-select'),
                label: 'Timezone',
                placeholder: 'Timezone',
                value: timezone,
                options: timezoneOptions,
                onChanged: onTimezone,
                save: timezoneSave,
                unlisted: timezoneUnlisted,
                hideSelected: true,
              ),
            ),
            _row(
              key: const ValueKey('time-format-row'),
              wrap: _anchored('time-format'),
              title: 'Time format',
              save: timeFormatSave,
              control: _segmented(
                context,
                key: const ValueKey('time-format'),
                label: 'Time format',
                value: timeFormat,
                options: const [('12h', '12-hour'), ('24h', '24-hour')],
                onChanged: onTimeFormat,
                save: timeFormatSave,
              ),
            ),
          ],
        ),
        _banner(settingsError),
        const SizedBox(height: 24), // mb-6
      ],
    );
  }
}
