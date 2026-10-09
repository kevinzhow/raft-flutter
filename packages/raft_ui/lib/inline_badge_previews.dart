import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Source inline badge editor', size: Size(390, 320))
Widget sourceInlineBadgeEditorPreview() => const _InlineBadgePreview();

class _InlineBadgePreview extends StatefulWidget {
  const _InlineBadgePreview();
  @override
  State<_InlineBadgePreview> createState() => _InlineBadgePreviewState();
}

class _InlineBadgePreviewState extends State<_InlineBadgePreview> {
  String selected = 'todo';
  bool enabled = true;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontFamily: t.headingFont),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RaftInlineBadgeEditor(
              label: selected == 'todo' ? 'To do' : 'Done',
              selectedId: selected,
              options: const [
                RaftInlineBadgeOption(id: 'todo', label: 'To do'),
                RaftInlineBadgeOption(
                  id: 'blocked',
                  label: 'Unavailable',
                  disabled: true,
                ),
                RaftInlineBadgeOption(id: 'done', label: 'Done'),
              ],
              background: t.colors['fill-muted']!,
              foreground: t.strong,
              enabled: enabled,
              onSelect: (id) => setState(() => selected = id),
            ),
            const SizedBox(height: 24),
            RaftButton(
              label: enabled ? 'Disable editor' : 'Enable editor',
              secondary: true,
              onPressed: () => setState(() => enabled = !enabled),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tab to the badge; Enter or arrows open. Escape returns focus.',
            ),
          ],
        ),
      ),
    );
  }
}
