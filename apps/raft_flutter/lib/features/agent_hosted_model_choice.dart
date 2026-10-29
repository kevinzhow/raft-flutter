// Web components/agent/HostedModelChoice.tsx: the first pick for a new cloud
// agent (create form, migration start dialog) and for a retry after the
// provider refused the picked model: the provider's offered models with
// "Default ({label})" first, read-only while an administrator decides
// (`locked`), a spinner while the list loads and a warning with Try Again when
// it could not be read. `null` is the provider's default.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_hosted_runtime.dart';
import 'agent_hosted_provider.dart';

/// Item id of "follow the provider's default" in the list.
const hostedChoiceDefaultId = '__hosted_default__';

/// "Default ({label})", else "Provider default" (Web `emptyOption`).
String hostedDefaultChoiceLabel(BuildContext context, HostedModelsList? view) {
  final label = view?.defaultLabel;
  return label != null && label.isNotEmpty
      ? raftFormat(context, 'Default ({label})', {'label': label})
      : raftText(context, 'Provider default');
}

class HostedModelChoice extends StatelessWidget {
  const HostedModelChoice({
    super.key,
    required this.loader,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final HostedModelsLoader loader;

  /// The picked model id, null for the provider's default.
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: loader,
    builder: (context, _) {
      final t = RaftTokens.of(context);
      final view = loader.view;
      switch (loader.status) {
        case HostedModelsStatus.loading:
          return Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              label: raftText(context, 'Loading...'),
              child: const RaftSpinner(),
            ),
          );
        case HostedModelsStatus.error:
          return RaftAgentInlineText(
            raftText(
              context,
              "Couldn't load the models, so the agent starts on the provider's default. You can change its model later in its profile.",
            ),
            action: raftText(context, 'Try Again'),
            onAction: loader.reload,
            style: RaftPanelText.warningCaption(t),
            key: const ValueKey('hosted-model-choice-error'),
          );
        case HostedModelsStatus.ready:
          break;
      }
      if (view == null) return const SizedBox.shrink();
      if (view.locked) {
        return RaftGapColumn(
          key: const ValueKey('hosted-model-choice-locked'),
          gap: 4,
          children: [
            RaftCssText(
              view.defaultLabel ?? view.defaultModel ?? '',
              style: RaftPanelText.mono(t),
            ),
            RaftCssText(
              raftText(
                context,
                "An administrator has set this agent's model, so it can't be changed here.",
              ),
              style: RaftPanelText.caption(t),
            ),
          ],
        );
      }
      return RaftAgentCombobox(
        key: const ValueKey('hosted-model-choice'),
        label: 'Model',
        semanticLabel: raftText(context, 'Model'),
        placeholder: raftText(context, 'Model'),
        value: value ?? hostedChoiceDefaultId,
        enabled: enabled,
        items: [
          RaftComboboxItem(
            hostedChoiceDefaultId,
            hostedDefaultChoiceLabel(context, view),
          ),
          for (final m in view.models)
            RaftComboboxItem(
              m.id,
              m.label,
              hint: m.label == m.id ? null : m.id,
              keywords: m.id,
            ),
        ],
        onSelected: (id) => onChanged(id == hostedChoiceDefaultId ? null : id),
      );
    },
  );
}
