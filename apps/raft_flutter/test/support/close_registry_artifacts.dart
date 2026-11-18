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

const artifactDiscussionSurfaces = <CloseSurface>[
  CloseSurface(
    'artifact-comments',
    kind: SurfaceKind.panel,
    web: 'ArtifactCommentsPanel.tsx: close button and Escape; bottom sheet on phones (ArtifactSurface.tsx)',
    phone: {Affordance.x, Affordance.esc, Affordance.systemBack},
    fold: {Affordance.x, Affordance.esc, Affordance.systemBack},
    desktop: {Affordance.x, Affordance.esc, Affordance.systemBack},
    files: ['lib/features/artifacts/artifact_comments_panel.dart'],
  ),
  CloseSurface(
    'artifact-comment-actions',
    kind: SurfaceKind.popup,
    web: 'ArtifactCommentsPanel.tsx: comment More opens Edit and Delete. Escape and outside press dismiss.',
    phone: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    fold: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    desktop: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    files: ['lib/features/artifacts/artifact_comments_panel.dart'],
  ),
  CloseSurface(
    'artifact-comment-delete',
    kind: SurfaceKind.dialog,
    web: 'ArtifactCommentsPanel.tsx: ConfirmDialog cancel, Escape, and outside press stays.',
    webOutside: WebOutside.stays,
    phone: {Affordance.back, Affordance.esc, Affordance.systemBack},
    fold: {Affordance.back, Affordance.esc, Affordance.systemBack},
    desktop: {Affordance.back, Affordance.esc, Affordance.systemBack},
    files: ['lib/features/artifacts/artifact_comments_panel.dart'],
  ),
];
