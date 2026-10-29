import 'close_surface.dart';

const _back = Affordance.back,
    _esc = Affordance.esc,
    _sys = Affordance.systemBack;

/// Full-page overlays of the community entry.
const communitySurfaces = <CloseSurface>[
  CloseSurface(
    'chinese-community-page',
    kind: SurfaceKind.page,
    web: 'pages/ChineseCommunityPage.tsx (/community/chinese): a route page, left with the browser Back',
    phone: {_back, _sys},
    fold: {_back, _esc, _sys},
    desktop: {_back, _esc, _sys},
    files: ['lib/features/chinese_community.dart'],
    status: 'no-web',
    fix: 'a native page needs its own Back (the browser has one)',
  ),
];
