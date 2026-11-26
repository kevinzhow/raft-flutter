import 'close_surface.dart';

const channelDetailsSurfaces = <CloseSurface>[
  CloseSurface(
    'channel-details',
    kind: SurfaceKind.panel,
    web: 'components/channel/ChannelDetailsSurface.tsx: desktop ChannelSideCard Close and Escape; phone page Back and system history',
    phone: {Affordance.back, Affordance.systemBack, Affordance.esc},
    // A medium window covers the conversation with the pane on top, so the
    // head's control there is Back (it reveals the pane underneath, or the
    // chat), not the desktop X.
    fold: {Affordance.back, Affordance.esc, Affordance.systemBack},
    desktop: {Affordance.x, Affordance.esc},
    files: ['lib/features/channel_details_host.dart'],
    status: 'approved',
    fix:
        'fold: the pane covers the conversation and its head draws Back '
        '(screen classes, Kevin 2026-11-25)',
  ),
];
