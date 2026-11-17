import 'close_surface.dart';

const channelDetailsSurfaces = <CloseSurface>[
  CloseSurface(
    'channel-details',
    kind: SurfaceKind.panel,
    web: 'components/channel/ChannelDetailsSurface.tsx: desktop ChannelSideCard Close and Escape; phone page Back and system history',
    phone: {Affordance.back, Affordance.systemBack, Affordance.esc},
    fold: {Affordance.x, Affordance.esc},
    desktop: {Affordance.x, Affordance.esc},
    files: ['lib/features/channel_details_host.dart'],
  ),
];
