import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'agent_runtime_catalog.dart';
import 'agent_runtime_draft.dart' show runtimeModelLabel;

/// The rows of the legacy Runtime editor's Model combobox (Web
/// `RuntimeConfigFields` modelOptions + `RuntimeChoiceCombobox`): the
/// Computer's / catalog's models by name (the stored id as the second line),
/// plus, once the Computer's list is live, the saved model it no longer
/// reports as "{model} (not in this computer's config)". A stored value that
/// is still not listed (a model typed on purpose, or a retired one while the
/// list is not live) stays selectable as its own first row, marked "Custom"
/// or "Not in the current list".
List<RaftComboboxItem> runtimeModelComboboxItems(
  BuildContext context, {
  required String runtime,
  required List<RuntimeModelInfo> models,
  required bool live,
  required String model,
  required bool customModelMode,
}) {
  RaftComboboxItem listed(String id, String label) =>
      RaftComboboxItem(id, label, hint: id, keywords: id);
  final items = [for (final m in models) listed(m.id, m.label)];
  if (live &&
      !customModelMode &&
      model.isNotEmpty &&
      !items.any((o) => o.id == model)) {
    items.add(
      listed(
        model,
        raftFormat(context, "{model} (not in this computer's config)", {
          'model': runtimeModelLabel(runtime, model),
        }),
      ),
    );
  }
  if (model.isNotEmpty && !items.any((o) => o.id == model)) {
    items.insert(
      0,
      RaftComboboxItem(
        model,
        model,
        description: raftText(
          context,
          customModelMode ? 'Custom' : 'Not in the current list',
        ),
      ),
    );
  }
  return items;
}

/// Web `RuntimeChoiceCombobox` as the legacy editor's Model control: one
/// searchable box; where the runtime takes any model id, typed text that
/// matches nothing can be used as is ("Use “x”").
class RuntimeModelCombobox extends StatelessWidget {
  const RuntimeModelCombobox({
    super.key,
    required this.runtime,
    required this.models,
    required this.live,
    required this.model,
    required this.customModelMode,
    required this.customAllowed,
    required this.enabled,
    required this.invalid,
    required this.onChanged,
  });

  final String runtime, model;
  final List<RuntimeModelInfo> models;
  final bool live, customModelMode, customAllowed, enabled, invalid;

  /// The picked or typed model id and whether it was typed ("custom").
  final void Function(String model, bool custom) onChanged;

  @override
  Widget build(BuildContext context) {
    final items = runtimeModelComboboxItems(
      context,
      runtime: runtime,
      models: models,
      live: live,
      model: model,
      customModelMode: customModelMode,
    );
    // Only the stored-but-unlisted row carries a description.
    final unlisted = items.any((o) => o.id == model && o.description != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftAgentCombobox(
          label: 'Model',
          semanticLabel: raftText(context, 'Model'),
          value: model,
          invalid: invalid,
          enabled: enabled,
          placeholder: customModelMode
              ? (runtime == 'claude' ? 'Custom model name' : 'Custom model ID')
              : 'Model',
          items: items,
          // Re-picking a custom value from its own row keeps it custom.
          onSelected: (id) =>
              onChanged(id, customModelMode && unlisted && id == model),
          customLabel: customAllowed
              ? (typed) =>
                    raftFormat(context, 'Use “{value}”', {'value': typed})
              : null,
          onCustom: customAllowed ? (typed) => onChanged(typed, true) : null,
        ),
        if (unlisted && !customModelMode)
          RaftAgentFieldNote(
            raftFormat(
              context,
              'The saved value {value} is not in the current list. It stays selected until you pick another.',
              {'value': model},
            ),
          ),
      ],
    );
  }
}
