import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// packages/shared appWhenToUse.ts: the agent-facing App hint is measured
/// after trimming, in Unicode code points.
const appWhenToUseMaxCodePoints = 160;

int countAppWhenToUseCharacters(String value) => value.trim().runes.length;

bool isAppWhenToUseTooLong(String value) =>
    countAppWhenToUseCharacters(value) > appWhenToUseMaxCodePoints;

/// AppWhenToUseField.tsx: the optional "When to use" input with a live
/// "N / 160 characters" counter and an over-limit error. Nothing caps the
/// typing; the editor refuses to save while [isAppWhenToUseTooLong].
class AppWhenToUseField extends StatelessWidget {
  const AppWhenToUseField({
    super.key,
    required this.controller,
    required this.onChanged,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final invalid = isAppWhenToUseTooLong(controller.text);
    return RaftAppEditorField(
      label: 'When to use',
      optional: true,
      hint: 'Shown to agents in their system prompt; leave empty to hide it.',
      error: invalid
          ? raftFormat(
              context,
              'Use no more than {limit} characters before saving.',
              {'limit': appWhenToUseMaxCodePoints},
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftRecipeInput(
            fieldKey: const ValueKey('connected-app-when-to-use'),
            controller: controller,
            placeholder: raftText(
              context,
              'When an agent should reach for this app, in one line',
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: RaftSpace.x1),
          Semantics(
            liveRegion: true,
            child: Text(
              raftFormat(context, '{count} / {limit} characters', {
                'count': countAppWhenToUseCharacters(controller.text),
                'limit': appWhenToUseMaxCodePoints,
              }),
              key: const ValueKey('connected-app-when-to-use-count'),
              style: RaftTypography.body(t, size: 12, line: 16, color: t.muted),
            ),
          ),
        ],
      ),
    );
  }
}
