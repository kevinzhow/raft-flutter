import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Collapsible section header', size: Size(420, 520))
Widget collapsibleSectionPreview() => const _CollapsibleSectionPreview();

/// A long section (an agent's skills) collapsed to its header row, next to the
/// section below it. Tapping the header opens and closes the list.
class _CollapsibleSectionPreview extends StatefulWidget {
  const _CollapsibleSectionPreview();
  @override
  State<_CollapsibleSectionPreview> createState() =>
      _CollapsibleSectionPreviewState();
}

class _CollapsibleSectionPreviewState
    extends State<_CollapsibleSectionPreview> {
  bool open = false;
  static const skills = [
    ('deploy', 'Deploy', 'Ship the current branch to the staging server', true),
    (
      'visual-testing',
      'visual-testing',
      'Cross-platform fixture ownership',
      false,
    ),
    ('feature-map', 'feature-map', 'React and Flutter parity maps', false),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftPanelSection(
          topBorder: false,
          gap: 16,
          children: [
            RaftCollapsibleSectionHeader(
              label: 'Skills',
              count: skills.length,
              expanded: open,
              onExpandedChanged: (value) => setState(() => open = value),
              gap: 16,
              children: [
                for (final (name, title, description, invocable) in skills)
                  RaftCard.item(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(title)),
                            if (invocable) ...[
                              const SizedBox(width: 8),
                              RaftRecipeBadge(
                                '/$name',
                                variant: RaftBadgeRecipeVariant.success,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(description),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        RaftPanelSection(
          children: [
            const RaftSectionHeader(label: 'Actions', count: 2),
            RaftButton(
              label: 'Restart / Reset',
              onPressed: () {},
              tone: RaftButtonRecipeVariant.outline,
            ),
          ],
        ),
      ],
    ),
  );
}
