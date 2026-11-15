// Step 1 of the Web v1.24 CreateExternalAgentDialog (features/agent/
// CreateExternalAgentDialog.tsx): Name, Description (optional) and "How will
// your agent run?" with a hint for the choice made. The dialog shell, the
// requests and step 2 (the status card and steps in external_agent_parts.dart)
// are the app's.
import 'package:flutter/material.dart';

import 'agent_create_form.dart' show RaftAgentTextInput;
import 'external_agent_parts.dart';
import 'form_controls.dart' show RaftField;
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/segmented_control.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

class RaftExternalCreateForm extends StatelessWidget {
  const RaftExternalCreateForm({
    super.key,
    required this.name,
    required this.description,
    required this.method,
    required this.onMethod,
    this.nameFocus,
    this.error,
    this.enabled = true,
    this.onChanged,
  });
  final TextEditingController name, description;
  final RaftExternalMethod method;
  final ValueChanged<RaftExternalMethod> onMethod;
  final FocusNode? nameFocus;

  /// The failure of the last Next (already localized).
  final String? error;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        if (error != null)
          Semantics(
            liveRegion: true,
            child: RaftCssText(
              error!,
              key: const ValueKey('create-external-agent-error'),
              style: t.scale(RaftTypeScale.callout, color: t.ui.danger),
            ),
          ),
        RaftField(
          label: raftText(context, 'Name'),
          child: RaftAgentTextInput(
            key: const ValueKey('create-external-agent-name'),
            controller: name,
            focusNode: nameFocus,
            enabled: enabled,
            semanticLabel: raftText(context, 'Name'),
            onChanged: (_) => onChanged?.call(),
          ),
        ),
        RaftField(
          label: raftText(context, 'Description'),
          optional: true,
          child: RaftAgentTextInput(
            key: const ValueKey('create-external-agent-description'),
            controller: description,
            multiline: true,
            enabled: enabled,
            placeholder: raftText(context, 'What is this agent for?'),
            semanticLabel: raftText(context, 'Description'),
          ),
        ),
        RaftField(
          label: raftText(context, 'How will your agent run?'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              RaftSegmentedControl<RaftExternalMethod>(
                value: method,
                label: raftText(context, 'How will your agent run?'),
                disabled: !enabled,
                onChanged: onMethod,
                items: [
                  RaftSegmentedOption(
                    value: RaftExternalMethod.existingAgent,
                    label: 'Existing agent',
                    glyph: RaftGlyph.bot,
                    itemKey: const ValueKey('create-external-agent-existing'),
                  ),
                  RaftSegmentedOption(
                    value: RaftExternalMethod.sdk,
                    label: 'Build your own',
                    glyph: RaftGlyph.code,
                    itemKey: const ValueKey('create-external-agent-sdk'),
                  ),
                ],
              ),
              RaftExternalNote(
                raftText(
                  context,
                  method == RaftExternalMethod.sdk
                      ? 'Build your own agent with the Raft SDK and bring it onto Raft.'
                      : 'Muse, Dots, Hermes and more. Give it a command-line tool to work with your agents on Raft.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
