import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/icons.dart';
import 'src/mobile_navigation.dart';
import 'src/popover_surface.dart';
import 'src/text_scaling.dart';
import 'src/theme.dart';

const _items = [
  RaftMobileNavItem(id: 'chat', label: 'Home', glyph: RaftGlyph.home),
  RaftMobileNavItem(id: 'tasks', label: 'Tasks', glyph: RaftGlyph.squareCheck),
  RaftMobileNavItem(id: 'search', label: 'Search', glyph: RaftGlyph.search),
  RaftMobileNavItem(id: 'activity', label: 'Activity', glyph: RaftGlyph.bell),
];

Widget _avatar(String initial) => Builder(
  builder: (context) => ColoredBox(
    color: RaftTokens.of(context).accentFill,
    child: Center(
      child: Text(
        initial,
        textScaler: RaftChrome.boundedScalerOf(context),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ),
  ),
);

/// The popover's content, laid out as it is inside the open popover (the
/// real popover opens above the bar from a press on the tab).
Widget _content({required int destinations, bool attention = false}) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    RaftMobileNavServerPopoverList(
      children: [
        for (final (i, name) in [
          'Dev Workspace',
          'Partner Workspace',
          'Empty State Workspace',
        ].indexed)
          RaftMobileNavServerPopoverRow(
            leading: _avatar(name[0]),
            label: name,
            description: '/${name.split(' ').first.toLowerCase()}',
            current: i == 0,
            trailing: i == 0 ? const RaftIcon(RaftGlyph.check, size: 16) : null,
            onPressed: () {},
          ),
      ],
    ),
    const RaftMobileNavServerPopoverSeparator(),
    RaftMobileNavServerPopoverGroup(
      children: [
        RaftMobileNavServerPopoverRow(
          leading: const RaftIcon(RaftGlyph.plus),
          label: 'Switch or create server',
          onPressed: () {},
        ),
        RaftMobileNavServerPopoverRow(
          leading: const RaftIcon(RaftGlyph.userPlus),
          label: 'Invite human',
          onPressed: () {},
        ),
      ],
    ),
    const RaftMobileNavServerPopoverSeparator(),
    RaftMobileNavServerPopoverDestinations(
      semanticLabel: 'Dev Workspace',
      children: [
        for (final (i, glyph) in [
          (RaftGlyph.users, 'Members'),
          (RaftGlyph.monitor, 'Computers'),
          (RaftGlyph.settings, 'Settings'),
          (RaftGlyph.home, 'Apps'),
          (RaftGlyph.search, 'Artifacts'),
        ].take(destinations).indexed)
          RaftMobileNavServerPopoverDestination(
            glyph: glyph.$1,
            label: glyph.$2,
            attention: attention && i == 1,
            onPressed: () {},
          ),
      ],
    ),
  ],
);

Widget _frame(Widget child) => Padding(
  padding: const EdgeInsets.all(8),
  child: RaftPopoverSurface(child: child),
);

@RaftPreviews('Mobile nav server tab', size: Size(390, 140))
Widget mobileNavServerTabPreview() => Align(
  alignment: Alignment.bottomCenter,
  child: RaftMobileNav(
    items: _items,
    selectedId: 'chat',
    onSelected: (_) {},
    trailing: RaftMobileNavServerTab(
      label: 'Dev Workspace',
      attention: true,
      avatar: _avatar('D'),
      contentBuilder: (context, close) =>
          _content(destinations: 5, attention: true),
    ),
  ),
);

@RaftPreviews('Mobile nav server popover grid', size: Size(390, 520))
Widget mobileNavServerPopoverGridPreview() =>
    _frame(_content(destinations: 5, attention: true));

@RaftPreviews('Mobile nav server popover row', size: Size(390, 420))
Widget mobileNavServerPopoverRowPreview() => _frame(_content(destinations: 3));
