import 'close_surface.dart';

const _artifactDialogClose = {
  Affordance.x,
  Affordance.esc,
  Affordance.systemBack,
};

const artifactHomeSurfaces = <CloseSurface>[
  CloseSurface(
    'artifact-collection-viewer',
    kind: SurfaceKind.viewer,
    web: 'ArtifactsDashboard.tsx mounts an in-column Viewer. Back on phone, close on wide layouts, and Escape.',
    phone: {Affordance.back, Affordance.esc, Affordance.systemBack},
    fold: {Affordance.x, Affordance.esc, Affordance.systemBack},
    desktop: {Affordance.x, Affordance.esc, Affordance.systemBack},
    files: ['lib/features/artifacts/artifact_dashboard.dart'],
  ),
  CloseSurface(
    'artifact-dashboard-page',
    kind: SurfaceKind.panel,
    web: 'ArtifactsDashboard.tsx: leave with workspace navigation or browser Back.',
    phone: {Affordance.back},
    none: {
      'fold':
          'The dashboard replaces the workspace section, without an overlay.',
      'desktop': 'Select another workspace rail destination to leave.',
    },
    files: ['lib/features/artifacts/artifact_dashboard.dart'],
  ),
  CloseSurface(
    'artifact-public-page',
    kind: SurfaceKind.viewer,
    web: 'PublicArtifactPage.tsx: standalone route, browser Back.',
    phone: {Affordance.back},
    fold: {Affordance.back},
    desktop: {Affordance.back},
    files: ['lib/features/artifacts/artifact_public_page.dart'],
  ),
  CloseSurface(
    'public-artifact-menu',
    kind: SurfaceKind.popup,
    web: 'PublicArtifactAiActions.tsx: Escape and an outside press dismiss.',
    webOutside: WebOutside.closes,
    phone: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    fold: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    desktop: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    files: ['lib/features/artifacts/artifact_public_page.dart'],
  ),
  CloseSurface(
    'artifact-dashboard-filter',
    kind: SurfaceKind.popup,
    web: 'ArtifactFilterCombobox.tsx: Escape and an outside press dismiss.',
    webOutside: WebOutside.closes,
    phone: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    fold: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    desktop: {Affordance.esc, Affordance.scrim, Affordance.systemBack},
    files: ['lib/features/artifacts/artifact_dashboard_filter.dart'],
  ),
  CloseSurface(
    'artifact-manage-dialog',
    kind: SurfaceKind.dialog,
    web: 'ArtifactRenameDialog.tsx and ArtifactNarrowHome.tsx: Escape and Cancel close while idle.',
    webOutside: WebOutside.stays,
    phone: {Affordance.back, Affordance.esc, Affordance.systemBack},
    fold: {Affordance.back, Affordance.esc, Affordance.systemBack},
    desktop: {Affordance.back, Affordance.esc, Affordance.systemBack},
    files: ['lib/features/artifacts/artifact_manage_dialogs.dart'],
  ),
  CloseSurface(
    'artifact-forward-dialog',
    kind: SurfaceKind.dialog,
    web: 'ArtifactForwardDialog.tsx: Escape and Cancel close while idle.',
    webOutside: WebOutside.stays,
    phone: _artifactDialogClose,
    fold: _artifactDialogClose,
    desktop: _artifactDialogClose,
    files: ['lib/features/artifacts/artifact_forward_dialog.dart'],
  ),
];

/// The workspace Artifact viewer (WP-ART1).
const artifactSurfaces = <CloseSurface>[
  CloseSurface(
    'workspace-artifact-viewer',
    kind: SurfaceKind.viewer,
    web: 'openArtifactInPlace.ts:26-33: outside the app shell an Artifact link is followed to its own page (browser Back); ArtifactViewer.tsx Back on a phone, Esc (useArtifactSurfaceKeyDown). Inside the shell it opens in place (shell-artifact-column, the channel column, the list slot)',
    phone: {Affordance.back, Affordance.esc, Affordance.systemBack},
    fold: {Affordance.back, Affordance.esc, Affordance.systemBack},
    desktop: {Affordance.back, Affordance.esc, Affordance.systemBack},
    files: ['lib/features/artifacts/artifact_place.dart'],
    status: 'fixed',
    fix: 'a page at every width (the full-bleed window over a wide workspace is gone, #380)',
  ),
  CloseSurface(
    'artifact-delete-confirm',
    kind: SurfaceKind.dialog,
    web: 'ArtifactViewerMenu.tsx mounts ConfirmDialog. X, Escape and Cancel close while idle. The scrim stays open.',
    webOutside: WebOutside.stays,
    phone: _artifactDialogClose,
    fold: _artifactDialogClose,
    desktop: _artifactDialogClose,
    files: ['lib/features/artifacts/artifact_viewer_page.dart'],
  ),
  CloseSurface(
    'artifact-display-report',
    kind: SurfaceKind.panel,
    web: 'ArtifactSurface.tsx opens the comment list beside the Viewer or in a Drawer on phones.',
    phone: {
      Affordance.x,
      Affordance.esc,
      Affordance.scrim,
      Affordance.systemBack,
      Affordance.drag,
    },
    fold: _artifactDialogClose,
    desktop: _artifactDialogClose,
    files: ['lib/features/artifacts/artifact_viewer_page.dart'],
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
  CloseSurface(
    'artifact-review-discard',
    kind: SurfaceKind.popup,
    web: 'ArtifactReviewParts.tsx anchors the batch confirmation to Discard all. Cancel, Escape, and an outside press close it.',
    webOutside: WebOutside.closes,
    phone: {
      Affordance.back,
      Affordance.esc,
      Affordance.scrim,
      Affordance.systemBack,
    },
    fold: {
      Affordance.back,
      Affordance.esc,
      Affordance.scrim,
      Affordance.systemBack,
    },
    desktop: {
      Affordance.back,
      Affordance.esc,
      Affordance.scrim,
      Affordance.systemBack,
    },
    files: ['lib/features/artifacts/artifact_review_batch_bar.dart'],
  ),
];

/// The app shell's Artifact column (Web ShellArtifactHost).
const shellArtifactSurfaces = <CloseSurface>[
  CloseSurface(
    'shell-artifact-column',
    kind: SurfaceKind.panel,
    web: 'ShellArtifactHost.tsx:9-24 with ArtifactViewer.tsx: X (artifact-viewer-close) and Esc (useArtifactSurfaceKeyDown); the address change closes it (useArtifactShell)',
    none: {
      'phone': 'A phone opens the Artifact as a page (workspace-artifact-viewer), as Web covers the main area with Back.',
    },
    fold: {Affordance.x, Affordance.esc, Affordance.systemBack},
    desktop: {Affordance.x, Affordance.esc, Affordance.systemBack},
    files: ['lib/features/artifacts/shell_artifact_column.dart'],
  ),
];
