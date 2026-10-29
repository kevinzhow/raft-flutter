// raft-flutter parity EXTENSION suite builder (tool/parity-ext): the sidebar
// row context menus on the phone Home list (long press) plus the desktop
// pinned-row variant. NOT official cases; ids are
// `components.row-menus.<platform>.<surface>.<theme>`
// (tool/parity-ext/build-row-menus.py). The REAL WorkspaceView is mounted with
// the shell fixture exactly like the `components.shell.*` cases, so the cases
// reuse their host; only the interactions (a real long press) differ.
import '../parity_harness.dart';
import 'ext_shell.dart';

const _themes = ['brutal', 'elegant', 'elegant-dark'];

const _mobileSurfaces = [
  'menu.channel-muted',
  'menu.dm',
  'menu.agent-dm',
  'menu.pinned-channel',
  'menu.section',
  'menu.section-custom',
  'menu.surface',
  'menu.move-to-section',
];

final Map<String, ParityCase> extRowMenuCases = {
  for (final theme in _themes) ...{
    for (final surface in _mobileSurfaces)
      'components.row-menus.mobile.$surface.$theme': extShellMobileCase,
    'components.row-menus.desktop.menu.pinned-channel.$theme':
        extShellDesktopCase,
  },
};
