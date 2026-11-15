import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

/// Select with group headings, descriptions, an inline badge and the trailing
/// non-value action row (the runtime picker shape).
@RaftPreviews(
  'Select · groups, description and action row',
  size: Size(420, 560),
)
Widget selectGroupPreview() => const _SelectGroupPreview();

class _SelectGroupPreview extends StatefulWidget {
  const _SelectGroupPreview();

  @override
  State<_SelectGroupPreview> createState() => _SelectGroupPreviewState();
}

class _SelectGroupPreviewState extends State<_SelectGroupPreview> {
  String value = 'claude';
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftAgentSelect<String>(
            value: value,
            semanticLabel: 'Runtime',
            options: [
              const RaftAgentSelectOption(
                'claude',
                'Claude Code',
                group: 'Ready on this computer',
                description: 'Anthropic coding agent',
              ),
              const RaftAgentSelectOption(
                'qoder',
                'Qoder',
                group: 'Ready on this computer',
                badge: 'Experimental',
              ),
              const RaftAgentSelectOption(
                'codex',
                'Codex CLI',
                enabled: false,
                group: 'Needs a Raft Computer update',
                suffix: ' · Update required',
                suffixInList: false,
              ),
              if (showAll)
                const RaftAgentSelectOption(
                  'grok',
                  'Grok Build',
                  enabled: false,
                  group: 'Not installed on this computer',
                  suffix: ' (not installed)',
                  suffixInList: false,
                ),
              RaftAgentSelectOption.action(
                '__show_all__',
                showAll ? 'Show installed only' : 'Show all supported',
                onAction: () => setState(() => showAll = !showAll),
              ),
            ],
            onChanged: (next) => setState(() => value = next),
          ),
        ],
      ),
    );
  }
}
