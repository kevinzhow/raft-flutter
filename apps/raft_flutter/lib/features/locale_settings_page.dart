import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/message_translation_store.dart';
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
  String? pendingField, preferenceError;
  late MessageTranslationStore translations = w.translations;
  @override
  void initState() {
    super.initState();
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
    if (!identical(translations, w.translations)) {
      translations.removeListener(translationChanged);
      translations = w.translations..addListener(translationChanged);
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
    pendingField = null;
    preferenceError = null;
  }

  @override
  Future<void> loadData(int request, int generation) async {}

  /// `auto` (and the translation target's `browser`) clear the preference.
  Future<void> setPreference(String key, String value) async {
    if (pendingField != null) return;
    final scope = authority;
    setState(() {
      pendingField = key;
      preferenceError = null;
    });
    try {
      if (!mounted || scope != authority) return;
      await w.client.patch(
        '/auth/me',
        data: {
          key: switch ((key, value)) {
            ('preferredTranslationMode', _) => value,
            (_, 'auto' || 'browser') => null,
            _ => value,
          },
        },
      );
      if (!mounted || scope != authority) return;
      await w.client.reloadUser();
    } catch (e) {
      if (mounted && scope == authority) setState(() => preferenceError = '$e');
    } finally {
      if (mounted && scope == authority) setState(() => pendingField = null);
    }
  }

  /// Web LanguageRegionSection translation mode, target and default view.
  List<Widget> translationControls(
    BuildContext context,
    Widget Function(
      String key,
      String title,
      Map<String, String> options, {
      String fallback,
      double gapBefore,
    })
    selector,
  ) {
    final settings = translations.settings;
    final busy = pendingField != null || translations.settingsLoading;
    final off = settings.mode == MessageTranslationMode.off;
    return [
      RaftSettingsPreference(
        key: const ValueKey('setting-preferredTranslationMode'),
        gapBefore: 16,
        title: 'Translation mode',
        description: 'Auto translates visible messages. Manual adds Translate to each message menu. Off keeps originals only.',
        // The menu action needs the server gate and a configured provider.
        notice: !settings.loaded || settings.available
            ? null
            : !settings.serverEnabled
            ? settings.canManage
                  ? 'Translation is not enabled on this server yet. Turn it on under Administration → Translation.'
                  : 'Translation is not enabled on this server yet.'
            : 'This deployment has no translation provider configured, so translations cannot run yet.',
        error: translations.settingsError,
        child: RaftSegmentedControl<MessageTranslationMode>(
          style: RaftSegmentedStyle.tabs,
          value: settings.mode,
          label: raftText(context, 'Message translation mode'),
          items: [
            for (final (mode, label) in const [
              (MessageTranslationMode.auto, 'Auto'),
              (MessageTranslationMode.manual, 'Manual'),
              (MessageTranslationMode.off, 'Off'),
            ])
              RaftSegmentedOption(value: mode, label: raftText(context, label)),
          ],
          onChanged: busy
              ? null
              : (mode) => setPreference('preferredTranslationMode', mode.name),
        ),
      ),
      if (!off) ...[
        selector(
          'preferredLanguage',
          'Translation target',
          {'browser': 'Device default', ...messageTranslationLanguages},
          fallback: 'browser',
          gapBefore: 16,
        ),
        RaftSettingsPreference(
          key: const ValueKey('setting-preferredTranslationDisplay'),
          gapBefore: 16,
          title: 'Default view',
          description:
              'Choose whether messages show translation, original, or both.',
          child: RaftSegmentedControl<MessageTranslationDisplay>(
            style: RaftSegmentedStyle.tabs,
            value: settings.display,
            label: raftText(context, 'Message translation display'),
            items: [
              for (final (display, label) in const [
                (MessageTranslationDisplay.translated, 'Translated'),
                (MessageTranslationDisplay.original, 'Original'),
                (MessageTranslationDisplay.bilingual, 'Bilingual'),
              ])
                RaftSegmentedOption(
                  value: display,
                  label: raftText(context, label),
                ),
            ],
            onChanged: busy
                ? null
                : (display) => setPreference(
                    'preferredTranslationDisplay',
                    display.name,
                  ),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = w.client.user,
        recipe = RaftSettingsLayoutRecipe(RaftTokens.of(context));
    Widget selector(
      String key,
      String title,
      Map<String, String> options, {
      String fallback = 'auto',
      double gapBefore = 0,
    }) {
      final accepted = user?.string(key) ?? '',
          value = options.containsKey(accepted) ? accepted : fallback;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (gapBefore > 0) SizedBox(height: gapBefore),
          Text(raftText(context, title), style: recipe.sectionTitle),
          const SizedBox(height: 8),
          RaftSelectField<String>(
            key: ValueKey('setting-$key'),
            label: title,
            value: value,
            items: [
              for (final option in options.entries)
                DropdownMenuItem(
                  value: option.key,
                  child: Text(raftText(context, option.value)),
                ),
            ],
            onChanged: pendingField != null
                ? null
                : (v) {
                    if (v != null) setPreference(key, v);
                  },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        selector('displayLanguage', 'Display language', const {
          'auto': 'Device default',
          'en': 'English',
          'zh-cn': '简体中文',
        }),
        ...translationControls(context, selector),
        selector('preferredTimeFormat', 'Time format', gapBefore: 16, const {
          'auto': 'Device default',
          '12h': '12-hour',
          '24h': '24-hour',
        }),
        if (pendingField != null)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
        if (preferenceError != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Semantics(
              liveRegion: true,
              child: Text(
                preferenceError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
      ],
    );
  }
}
