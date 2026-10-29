// Navigation specimens (specimens.tsx: TabsVariants, SegmentedControlStates, ListRowVariants).
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support.dart';

final Map<String, RaftSpecimenBuilder> raftNavigationSpecimens = {
  'tabs.variants': _tabsVariants,
  'segmented-control.states': _segmentedControlStates,
  'list-row.variants': _listRowVariants,
};

void _noop() {}

void _noopBool(bool _) {}

void _noopString(String _) {}

const _tabs = [
  RaftTabItem(value: 'general', label: 'General'),
  RaftTabItem(value: 'members', label: 'Members'),
  RaftTabItem(value: 'activity', label: 'Activity'),
];

Widget _tabsVariants(BuildContext context, RaftTokens t) => specimenStack([
  for (final variant in RaftTabsVariant.values)
    RaftTabs<String>(
      tabs: _tabs,
      value: 'general',
      onChanged: _noopString,
      variant: variant,
      panels: const {
        'general': RaftTabsPanelText(
          'Name, topic, and description of #design-review.',
        ),
      },
    ),
]);

Widget _segmentedControlStates(BuildContext context, RaftTokens t) =>
    specimenStack([
      // SegmentedControlViewModeComposition
      Align(
        alignment: Alignment.centerLeft,
        child: RaftSegmentedControl<String>(
          label: 'Task view',
          value: 'board',
          onChanged: _noopString,
          items: const [
            RaftSegmentedOption(
              value: 'board',
              label: 'Board',
              glyph: RaftGlyph.columns3,
            ),
            RaftSegmentedOption(
              value: 'list',
              label: 'List',
              glyph: RaftGlyph.list,
            ),
          ],
        ),
      ),
      // SegmentedControlFiltersComposition
      Align(
        alignment: Alignment.centerLeft,
        child: RaftSegmentedControl<String>(
          label: 'Filter messages',
          value: 'all',
          onChanged: _noopString,
          items: const [
            RaftSegmentedOption(
              value: 'all',
              label: 'All',
              glyph: RaftGlyph.inbox,
              count: '12',
            ),
            RaftSegmentedOption(value: 'unread', label: 'Unread', count: '3'),
            RaftSegmentedOption(
              value: 'mentions',
              label: 'Mentions',
              glyph: RaftGlyph.atSign,
            ),
          ],
        ),
      ),
      // SegmentedControlDisabledComposition
      Align(
        alignment: Alignment.centerLeft,
        child: RaftSegmentedControl<String>(
          disabled: true,
          label: 'Translation mode',
          value: 'translated',
          onChanged: _noopString,
          items: const [
            RaftSegmentedOption(
              value: 'translated',
              label: 'Translated',
              glyph: RaftGlyph.languages,
            ),
            RaftSegmentedOption(value: 'original', label: 'Original'),
          ],
        ),
      ),
    ]);

Widget _listRowVariants(BuildContext context, RaftTokens t) => specimenStack([
  // ListRowConversationsComposition, "wug" open
  specimenFull(
    RaftListRowList(
      children: [
        RaftListRow(
          tone: RaftListRowTone.unread,
          selected: true,
          onPressed: _noop,
          children: [
            const RaftAvatar(
              name: 'W',
              size: 35,
              kind: RaftAvatarKind.agent,
              presence: RaftAvatarPresence(activity: RaftAvatarActivity.online),
            ),
            RaftListRowBody(
              children: [
                const RaftListRowTop(
                  children: [RaftListRowTitle('Wug'), RaftListRowMeta('10:40')],
                ),
                RaftListRowBottom(
                  children: [
                    const RaftListRowDescription('Draft is in #launch-week.'),
                    const RaftBadge(
                      label: '1',
                      variant: RaftBadgeRecipeVariant.accent,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        RaftListRow(
          tone: RaftListRowTone.unread,
          onPressed: _noop,
          children: [
            const RaftAvatar(name: 'M', size: 35, kind: RaftAvatarKind.agent),
            RaftListRowBody(
              children: [
                const RaftListRowTop(
                  children: [
                    RaftListRowTitle('Martin'),
                    RaftListRowMeta('10:31'),
                  ],
                ),
                RaftListRowBottom(
                  children: [
                    const RaftListRowDescription(
                      'Bugen claimed #25 Polish onboarding flow',
                    ),
                    RaftBadge(
                      label: '',
                      variant: RaftBadgeRecipeVariant.primary,
                      leading: RaftIcon(RaftGlyph.atSign, size: 13),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        RaftListRow(
          onPressed: _noop,
          children: [
            const RaftAvatar(name: 'MC', size: 35),
            const RaftListRowBody(
              children: [
                RaftListRowTop(
                  children: [
                    RaftListRowTitle('Mia Chen'),
                    RaftListRowMeta('Tue'),
                  ],
                ),
                RaftListRowBottom(
                  children: [
                    RaftListRowDescription('Can we try the yellow tab bar?'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ),
  // ListRowSettingsComposition with Appearance = System, merge = off
  specimenFull(
    RaftListRowGroup(
      children: [
        RaftListRow(
          variant: RaftListRowVariant.plain,
          onPressed: _noop,
          children: const [
            RaftListRowIcon(RaftGlyph.moon),
            RaftListRowBody(children: [RaftListRowTitle('Appearance')]),
            RaftListRowValue('System'),
            RaftListRowChevron(),
          ],
        ),
        RaftListRow(
          variant: RaftListRowVariant.plain,
          interactive: false,
          children: [
            const RaftListRowIcon(RaftGlyph.bell),
            const RaftListRowBody(
              children: [
                RaftListRowTitle('Agents can merge to main'),
                RaftListRowDescription(
                  'Off: a person approves every merge.',
                  wrap: true,
                ),
              ],
            ),
            RaftSwitch(
              value: false,
              onChanged: _noopBool,
              semanticLabel: 'Agents can merge to main',
            ),
          ],
        ),
      ],
    ),
  ),
  // ListRowEntriesComposition, "activity" open
  specimenFull(
    RaftListRowList(
      children: [
        RaftListRow(
          variant: RaftListRowVariant.entry,
          onPressed: _noop,
          children: const [
            RaftListRowIcon(RaftGlyph.search),
            RaftListRowBody(children: [RaftListRowTitle('Search')]),
          ],
        ),
        RaftListRow(
          variant: RaftListRowVariant.entry,
          selected: true,
          onPressed: _noop,
          children: const [
            RaftListRowIcon(RaftGlyph.activity),
            RaftListRowBody(children: [RaftListRowTitle('Activity')]),
            RaftBadge(label: '4', variant: RaftBadgeRecipeVariant.accent),
          ],
        ),
        RaftListRow(
          variant: RaftListRowVariant.entry,
          onPressed: _noop,
          children: const [
            RaftListRowIcon(RaftGlyph.bookmark),
            RaftListRowBody(children: [RaftListRowTitle('Saved')]),
            RaftListRowMeta('7'),
          ],
        ),
      ],
    ),
  ),
]);
