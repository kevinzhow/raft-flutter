import 'close_surface.dart';

/// The Tasks and Files cards beside the conversation (WP-SIDE), harnessed in
/// close_side_cards_test.dart so the panel parts keep their case budget.
const sideCardSurfaces = <CloseSurface>[
  CloseSurface(
    'channel-side-card',
    kind: SurfaceKind.panel,
    web:
        'ChannelSideCard.tsx: X in the head (hidden where the card covers the conversation); on a phone the channel header Back closes the open cards before the channel (ChatPanel headerMobileBack); Escape does not close Tasks or Files (no closeOnEscape)',
    phone: {Affordance.back, Affordance.systemBack},
    fold: {Affordance.x},
    desktop: {Affordance.x},
    files: ['lib/features/channel_side_card.dart'],
  ),
];
