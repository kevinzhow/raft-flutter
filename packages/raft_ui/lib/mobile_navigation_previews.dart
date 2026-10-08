import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/design_primitives.dart';
import 'src/icons.dart';
import 'src/mobile_navigation.dart';

@RaftPreviews('Source mobile navigation', size: Size(390, 844))
Widget sourceMobileNavigationPreview() => const _Navigation(height: 844);
@RaftPreviews('Source mobile navigation compact', size: Size(390, 560))
Widget sourceMobileNavigationCompactPreview() => const _Navigation(height: 560);

@RaftPreviews('Source mobile navigation touch', size: Size(390, 844))
Widget sourceMobileNavigationTouchPreview() =>
    const _Navigation(height: 844, density: RaftDensity.touch);

class _Navigation extends StatefulWidget {
  const _Navigation({required this.height, this.density = RaftDensity.desktop});
  final double height;
  final RaftDensity density;
  @override
  State<_Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<_Navigation> {
  String selected = 'chat';
  int opened = 0;
  int notificationsOpened = 0;
  @override
  Widget build(BuildContext context) => RaftDensityScope(
    density: widget.density,
    child: Column(
      children: [
        RaftMobileRootHeader(
          viewportHeight: widget.height,
          leading: selected == 'chat'
              ? RaftMobileServerSelector(
                  label: 'Raft Studio',
                  attention: true,
                  viewportHeight: widget.height,
                  onPressed: () => setState(() => opened++),
                )
              : null,
          actions: [
            RaftMobileNotificationButton(
              onPressed: () => setState(() => notificationsOpened++),
            ),
          ],
          title: selected == 'chat'
              ? null
              : selected == 'tasks'
              ? 'Tasks'
              : selected == 'members'
              ? 'Members'
              : 'Settings',
        ),
        Expanded(
          child: Center(
            child: Text(
              'Server picker opened $opened times\nNotification center opened $notificationsOpened times',
            ),
          ),
        ),
        RaftMobileNav(
          viewportHeight: widget.height,
          bottomInset: 0,
          selectedId: selected,
          onSelected: (id) => setState(() => selected = id),
          items: const [
            RaftMobileNavItem(id: 'chat', label: 'Home', glyph: RaftGlyph.home),
            RaftMobileNavItem(
              id: 'tasks',
              label: 'Tasks',
              glyph: RaftGlyph.squareCheck,
            ),
            RaftMobileNavItem(
              id: 'members',
              label: 'Members',
              glyph: RaftGlyph.users,
            ),
            RaftMobileNavItem(
              id: 'settings',
              label: 'Settings',
              glyph: RaftGlyph.settings,
              attention: true,
            ),
          ],
        ),
      ],
    ),
  );
}
