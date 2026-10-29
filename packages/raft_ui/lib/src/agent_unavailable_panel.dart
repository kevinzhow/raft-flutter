// Web `agent/AgentUnavailablePanel.tsx`: a PanelHeader ("Agent unavailable", Bot
// icon tile, mobile back) over a centred EmptyState with a 36px TriangleAlert.
import 'package:flutter/material.dart';

import 'computer_surfaces.dart' show RaftPanelHeaderIconTile;
import 'icons.dart';
import 'localization.dart';
import 'agent_profile.dart' show RaftPanelTextScope;
import 'panel_layout.dart';
import 'product_empty_state.dart';
import 'theme.dart';

class RaftAgentUnavailablePanel extends StatelessWidget {
  const RaftAgentUnavailablePanel({super.key, this.onBack, this.onClose});

  /// `useMobileBack`: the chevron renders below `md` only.
  final VoidCallback? onBack;

  /// Desktop close action (`hidden md:flex` CloseButton), when the host passes one.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 768;
    return RaftPanelTextScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftPanelHeaderBar(
            key: const ValueKey('agent-unavailable-header'),
            title: raftText(context, 'Agent unavailable'),
            onBack: wide ? null : onBack,
            backKey: const ValueKey('agent-mobile-back'),
            backTooltip: raftText(context, 'Back'),
            // `iconBg="bg-fill-muted theme-brutal:bg-gray-200"`
            iconSlot: RaftPanelHeaderIconTile(
              glyph: RaftGlyph.bot,
              background: t.colors['fill-muted']!,
            ),
            actions: [
              if (onClose != null && wide)
                RaftPanelIconButton(
                  glyph: RaftGlyph.x,
                  tooltip: raftText(context, 'Close'),
                  onPressed: onClose,
                ),
            ],
          ),
          Expanded(
            child: RaftProductEmptyState(
              key: const ValueKey('agent-unavailable-panel'),
              title: raftText(context, 'Agent unavailable'),
              description: raftText(
                context,
                'This agent has been terminated or is no longer available in this server.',
              ),
              icon: (context, size, color) =>
                  RaftIcon(RaftGlyph.triangleAlert, size: 36, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
