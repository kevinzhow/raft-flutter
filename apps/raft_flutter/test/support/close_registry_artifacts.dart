import 'close_surface.dart';

/// The workspace Artifact viewer (WP-ART1).
const artifactSurfaces = <CloseSurface>[
  CloseSurface(
    'workspace-artifact-viewer',
    kind: SurfaceKind.viewer,
    web: 'ArtifactViewer.tsx ViewerFrame: X (artifact-viewer-close) beside the conversation, Back when it covers the conversation on a phone; Esc (useArtifactSurfaceKeyDown). The app shows it as a page below 768 and a full-bleed window above (docs/parity.md)',
    phone: {Affordance.back, Affordance.esc, Affordance.systemBack},
    fold: {Affordance.x, Affordance.esc, Affordance.systemBack},
    desktop: {Affordance.x, Affordance.esc, Affordance.systemBack},
    files: ['lib/features/artifacts/artifact_viewer_page.dart'],
    status: 'approved',
    fix: 'page / full-bleed window instead of the side column (docs/parity.md)',
  ),
];
