import 'close_surface.dart';

const draftsSurfaces = <CloseSurface>[
  CloseSurface(
    'drafts-page',
    kind: SurfaceKind.page,
    web: 'DraftsPanel.tsx: mobile Back; desktop uses sidebar and history',
    phone: {Affordance.back, Affordance.systemBack},
    none: {
      'fold': 'this is a root section; leave through navigation or history',
      'desktop': 'this is a root section; leave through navigation or history',
    },
    files: ['lib/features/desktop_drafts_page.dart'],
  ),
];
