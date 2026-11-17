import 'close_surface.dart';

const _esc = Affordance.esc,
    _scrim = Affordance.scrim,
    _sys = Affordance.systemBack,
    _x = Affordance.x;

const _atNarrow = 'the toolbar gives it up to More at this width';

/// The Tasks page's popovers, menus and dialogs (task v2, Web TasksPage). Its
/// own list and harness file (close_tasks_page_test.dart) so the popup parts
/// keep their case budget.
const tasksPageSurfaces = <CloseSurface>[
  CloseSurface(
    'tasks-page-filter-popover',
    kind: SurfaceKind.popup,
    web:
        'tasksPage/TasksPageToolbar.tsx Popover + ui/SelectionPopover.tsx (Channel, Status, Creator, Assignee): Esc, outside press',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: [
      'lib/features/tasks_page/tasks_page_toolbar.dart',
      'lib/features/task_selection_filter.dart',
    ],
  ),
  CloseSurface(
    'tasks-page-sort-menu',
    kind: SurfaceKind.popup,
    web:
        'tasksPage/TasksPageToolbar.tsx SortPicker (Select): Esc, outside press',
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    none: {'phone': _atNarrow},
    files: ['lib/features/tasks_page/tasks_page_toolbar.dart'],
  ),
  CloseSurface(
    'tasks-page-more-menu',
    kind: SurfaceKind.popup,
    web:
        'ui/ListToolbarParts.tsx ListToolbarMore (DropdownMenu): Esc, outside press',
    phone: {_esc, _scrim, _sys},
    none: {
      'fold': 'the sort and the view fit the line, More is hidden',
      'desktop': 'the sort and the view fit the line, More is hidden',
    },
    files: ['lib/features/tasks_page/tasks_page_toolbar.dart'],
  ),
  CloseSurface(
    'tasks-page-scope-select',
    kind: SurfaceKind.popup,
    web: 'ui/ListToolbarParts.tsx ListScopeSelect (Select): Esc, outside press',
    phone: {_esc, _scrim, _sys},
    none: {
      'fold': 'the scope is a segmented control at this width',
      'desktop': 'the scope is a segmented control at this width',
    },
    files: ['lib/features/tasks_page/tasks_page_toolbar.dart'],
  ),
  CloseSurface(
    'tasks-batch-status-menu',
    kind: SurfaceKind.popup,
    web:
        'tasksPage/TasksSelectionBar.tsx Status DropdownMenu (opens upward): Esc, outside press',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: [
      'lib/features/tasks_page/tasks_selection_bar.dart',
      '../../packages/raft_ui/lib/src/selection_bar.dart',
    ],
  ),
  CloseSurface(
    'tasks-batch-assignee-picker',
    kind: SurfaceKind.popup,
    web:
        'tasksPage/TasksSelectionBar.tsx Assignee Popover + SelectionPopover (searchable, opens upward): Esc, outside press',
    phone: {_esc, _scrim, _sys},
    fold: {_esc, _scrim, _sys},
    desktop: {_esc, _scrim, _sys},
    files: [
      'lib/features/tasks_page/tasks_selection_bar.dart',
      '../../packages/raft_ui/lib/src/selection_bar.dart',
    ],
  ),
  CloseSurface(
    'tasks-batch-delete-confirm',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web:
        'task/TaskDeleteConfirmDialog.tsx (batch Delete of tasksPage/TasksSelectionBar.tsx): X + Esc, no scrim close, gated while deleting',
    phone: {_x, _esc, _sys},
    fold: {_x, _esc, _sys},
    desktop: {_x, _esc, _sys},
    files: [
      'lib/features/tasks_page/tasks_selection_bar.dart',
      '../../packages/raft_ui/lib/src/task_v2_dialogs.dart',
    ],
  ),
  CloseSurface(
    'tasks-page-new-task',
    kind: SurfaceKind.dialog,
    webOutside: WebOutside.stays,
    web:
        'task/DeferredCreateTaskDialog (CreateTaskMessageDialog) opened by TasksPageToolbar New task: X + Esc, no backdrop close',
    phone: {_x, _esc, _scrim, _sys, Affordance.drag},
    fold: {_x, _esc, _scrim, _sys},
    desktop: {_x, _esc, _sys},
    status: 'approved',
    fix:
        'a sheet on a phone, as every form: its scrim press and drag down close it',
    files: [
      'lib/features/tasks_page/tasks_page.dart',
      'lib/features/create_task_message_dialog.dart',
    ],
  ),
];
