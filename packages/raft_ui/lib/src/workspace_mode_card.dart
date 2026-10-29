import 'package:flutter/material.dart';

import 'raft/checkbox.dart' show RaftCheckbox;
import 'localization.dart';
import 'theme.dart';

/// SettingsPanel.tsx WorkspaceModeSettingsCard (7844–7875). Availability is
/// app-owned: the host must only mount this card when the actual mode exists.
class RaftWorkspaceModeCard extends StatelessWidget {
  const RaftWorkspaceModeCard({
    super.key,
    required this.enabled,
    this.onChanged,
  });
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final inherited = DefaultTextStyle.of(context).style;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        key: const ValueKey('workspace-mode-card'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.colors['layer-canvas-muted'],
          border: Border.all(color: t.colors['line-muted']!, width: 1),
          boxShadow: t.themeShadows.sm.outer.reversed.toList(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    raftText(context, 'Server mode'),
                    style: inherited.copyWith(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    raftText(
                      context,
                      'Use the Activity Bar, Sidebar, and draggable editor groups.',
                    ),
                    style: inherited.copyWith(
                      fontSize: 12,
                      height: 20 / 12,
                      color: t.colors['foreground-muted'],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            RaftCheckbox(
              value: enabled,
              onChanged: onChanged,
              semanticLabel: raftText(context, 'Server mode'),
            ),
          ],
        ),
      ),
    );
  }
}
