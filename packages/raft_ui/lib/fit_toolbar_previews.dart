import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

Widget _rack(double width) => SizedBox(
  width: width,
  child: RaftFitToolbar(
    wrap: true,
    semanticLabel: 'Computers',
    children: [
      const RaftFitSearch(
        hintText: 'Search computers',
        semanticLabel: 'Search computers',
        clearLabel: 'Clear search',
        collapseOrder: 70,
      ),
      RaftFitGroup(
        scroll: true,
        wrapOrder: 30,
        end: RaftButton(
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.md,
          label: 'Clear all',
          onPressed: () {},
        ),
        items: [
          RaftFitPicker(
            label: 'Status',
            glyph: RaftGlyph.circle,
            labelOrder: 20,
            menuEntries: const [RaftMenuEntry(label: 'Online')],
          ),
          RaftFitPicker(
            label: 'Runtime',
            glyph: RaftGlyph.server,
            value: '2',
            labelOrder: 20,
            menuEntries: const [RaftMenuEntry(label: 'Claude')],
          ),
        ],
      ),
      RaftFitGroup(
        firstLine: true,
        moreOrder: 60,
        moreItem: const [
          RaftMenuEntry(label: 'Group by status'),
          RaftMenuEntry(label: 'Sort by name'),
        ],
        items: [
          RaftFitPicker(
            label: 'Group',
            glyph: RaftGlyph.listFilter,
            labelOrder: 10,
            menuEntries: const [RaftMenuEntry(label: 'None')],
          ),
          RaftFitPicker(
            label: 'Sort',
            glyph: RaftGlyph.arrowUpDown,
            labelOrder: 10,
            menuEntries: const [RaftMenuEntry(label: 'Name')],
          ),
        ],
      ),
      RaftFitGroup(
        firstLine: true,
        items: [
          const RaftFitMore(),
          RaftFitButton(
            label: 'Add computer',
            glyph: RaftGlyph.plus,
            plusOrder: 40,
            variant: RaftButtonVariant.primary,
            onPressed: () {},
          ),
        ],
      ),
    ],
  ),
);

@RaftPreviews('Fit toolbar, rack, wide', size: Size(1200, 120))
Widget fitToolbarWidePreview() => _rack(1180);

@RaftPreviews(
  'Fit toolbar, rack, medium (labels gone, filters wrapped)',
  size: Size(560, 120),
)
Widget fitToolbarMediumPreview() => _rack(540);

@RaftPreviews('Fit toolbar, rack, narrow (+ and More)', size: Size(300, 120))
Widget fitToolbarNarrowPreview() => _rack(280);

@RaftPreviews('Fit toolbar, rack, search collapsed', size: Size(200, 120))
Widget fitToolbarCollapsedPreview() => _rack(190);

@RaftPreviews('Fit toolbar, primary split action', size: Size(430, 132))
Widget fitToolbarSplitButtonPreview() => RaftFitToolbar(
  semanticLabel: 'Members',
  children: [
    const RaftFitSearch(
      semanticLabel: 'Search members',
      hintText: 'Search members',
      collapseOrder: 70,
    ),
    RaftFitGroup(
      items: [
        RaftFitSplitButton(
          label: 'Create agent',
          menuLabel: 'More ways to add an agent',
          glyph: RaftGlyph.bot,
          plusOrder: 40,
          onPressed: () {},
          entries: [
            RaftMenuEntry(label: 'Connect an external agent', onPressed: () {}),
          ],
        ),
      ],
    ),
  ],
);

@RaftPreviews('Fit toolbar, typed Select', size: Size(340, 260))
Widget fitToolbarSelectPreview() {
  var selection = 'all';
  return StatefulBuilder(
    builder: (context, setState) => RaftFitToolbar(
      semanticLabel: 'Apps',
      children: [
        RaftFitGroup(
          items: [
            RaftFitSelect<String>(
              label: selection == 'all' ? 'All categories' : 'Communication',
              selection: selection,
              applied: selection != 'all',
              glyph: RaftGlyph.layoutList,
              items: const [
                RaftSelectItem(value: 'all', label: 'All categories'),
                RaftSelectItem(value: 'communication', label: 'Communication'),
              ],
              onChanged: (value) => setState(() => selection = value),
            ),
          ],
        ),
      ],
    ),
  );
}
