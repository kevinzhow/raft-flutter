import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Profile tabs and card', size: Size(390, 360))
Widget profileTabsAndCardPreview() => const _ProfileTabsAndCardPreview();

class _ProfileTabsAndCardPreview extends StatefulWidget {
  const _ProfileTabsAndCardPreview();
  @override
  State<_ProfileTabsAndCardPreview> createState() =>
      _ProfileTabsAndCardPreviewState();
}

class _ProfileTabsAndCardPreviewState
    extends State<_ProfileTabsAndCardPreview> {
  String tab = 'profile';
  int saved = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      RaftPanelTabBar<String>(
        tabs: [
          const RaftPanelTab('profile', 'Profile', RaftGlyph.bot),
          RaftPanelTab.custom(
            'chat',
            'Chat',
            iconBuilder: (size, color, strokeWidth) => RaftChatIcon(
              size: size,
              color: color,
              strokeWidth: strokeWidth,
            ),
          ),
        ],
        value: tab,
        onChanged: (value) => setState(() => tab = value),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: RaftPanel(
          style: RaftPanelStyle.legacyCard,
          child: Column(
            children: [
              Text('Selected: $tab; saved: $saved'),
              RaftButton(
                label: 'Save changes',
                onPressed: () => setState(() => saved++),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
