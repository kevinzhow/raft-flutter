import 'close_surface.dart';

const _mouse = {Affordance.esc, Affordance.scrim, Affordance.systemBack};
const _touch = {
  Affordance.x,
  Affordance.scrim,
  Affordance.drag,
  Affordance.systemBack,
};

const threadOutlineSurfaces = <CloseSurface>[
  CloseSurface(
    'thread-outline-list',
    kind: SurfaceKind.popup,
    web: 'features/conversation-outline/ConversationOutline.tsx:584-610 Drawer on phones, anchored Popover on desktop',
    phone: _touch,
    fold: _touch,
    desktop: _mouse,
    files: ['lib/features/thread_outline_list.dart'],
  ),
  CloseSurface(
    'thread-outline-rail',
    kind: SurfaceKind.popup,
    web: 'features/conversation-outline/ConversationOutline.tsx:360-529 rail card: mouse leave and Escape',
    desktop: _mouse,
    none: {
      'phone': 'The touch thread opens Timeline from the header menu.',
      'fold': 'The touch thread opens Timeline from the header menu.',
    },
    files: ['lib/features/thread_outline_viewport.dart'],
  ),
];
