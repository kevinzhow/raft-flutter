import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'page_component_recipes.dart';

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
  @override
  void initState() {
    super.initState();
    startManagement();
  }

  @override
  void clearData() {
    pendingField = null;
    preferenceError = null;
  }

  @override
  Future<void> loadData(int request, int generation) async {}
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
        data: {key: value == 'auto' ? null : value},
      );
      if (!mounted || scope != authority) return;
      await w.client.reloadUser();
    } catch (e) {
      if (mounted && scope == authority) setState(() => preferenceError = '$e');
    } finally {
      if (mounted && scope == authority) setState(() => pendingField = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = w.client.user,
        recipe = RaftSettingsLayoutRecipe(RaftTokens.of(context));
    Widget selector(String key, String title, Map<String, String> options) {
      final accepted = user?.string(key) ?? '',
          value = options.containsKey(accepted) ? accepted : 'auto';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        const SizedBox(height: 16),
        selector('preferredTimeFormat', 'Time format', const {
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
