import 'close_surface.dart';

const _x = Affordance.x,
    _back = Affordance.back,
    _esc = Affordance.esc,
    _sys = Affordance.systemBack;

/// Task v2 in place beside a list (Web TaskContentSlot). Its own list and
/// harness file (close_task_slot_test.dart) so the viewer parts keep their
/// case budget.
const taskSlotSurfaces = <CloseSurface>[
  CloseSurface(
    'task-slot-tasks-route',
    kind: SurfaceKind.panel,
    web: 'TaskContentSlot.tsx:130-165 (opened by tasksPageOpen.ts:22-47, TasksRoute.tsx): >=768 beside the list, TaskConversationPage presentation=modal page (TaskModalBar X task-modal-close), Esc on the slot, no backdrop, focus back to the row; <768 a page in place of the list, Back pops its entry',
    phone: {_back, _sys},
    fold: {_x, _esc, _sys},
    desktop: {_x, _esc, _sys},
    files: [
      'lib/features/task_content_slot.dart',
      'lib/features/workspace_task_host.dart',
    ],
  ),
];
