import 'close_surface.dart';

const _esc = Affordance.esc,
    _scrim = Affordance.scrim,
    _sys = Affordance.systemBack;

/// The Tasks page board's own layers. Its own list and harness file
/// (close_tasks_board_test.dart) so the popup parts keep their case budget.
const tasksBoardSurfaces = <CloseSurface>[
  CloseSurface(
    'tasks-board-backlog-reason',
    kind: SurfaceKind.popup,
    web: 'task/tasksPage/TasksBoardView.tsx + task/TaskBacklogReasonPopover.tsx Popover (Base UI): a card dropped on Backlog, the popover anchored at the Backlog column heading; Esc, outside press, Cancel; busy while the write runs',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: ['lib/features/tasks_page/tasks_board_view.dart'],
  ),
];
