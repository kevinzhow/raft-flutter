import 'close_surface.dart';

/// The Tasks and Files cards beside the conversation (WP-SIDE), harnessed in
/// close_side_cards_test.dart so the panel parts keep their case budget.
const sideCardSurfaces = <CloseSurface>[
  CloseSurface(
    'channel-side-card',
    kind: SurfaceKind.panel,
    web: 'ChannelSideCard.tsx: X in the head (hidden where the card covers the conversation); on a phone the channel header Back closes the open cards before the channel (ChatPanel headerMobileBack); Escape does not close Tasks or Files (no closeOnEscape)',
    phone: {Affordance.back, Affordance.systemBack},
    fold: {Affordance.x},
    desktop: {Affordance.x},
    files: ['lib/features/channel_side_card.dart'],
  ),
  CloseSurface(
    'channel-profile-column-move',
    kind: SurfaceKind.popup,
    web: 'components/layout/rowLayout.ts and RowMoveMenu: Escape and outside press',
    fold: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    desktop: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    none: {'phone': 'the profile covers the conversation'},
    files: ['lib/features/channel_side_area.dart'],
  ),
  CloseSurface(
    'channel-thread-column-move',
    kind: SurfaceKind.popup,
    web: 'components/layout/MainLayout.tsx SideThreadColumn and RowMoveMenu: Escape and outside press',
    desktop: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    none: {
      'phone': 'the thread is a page',
      'fold': 'the thread occupies the conversation region',
    },
    files: ['lib/features/channel_side_area.dart'],
  ),
];
