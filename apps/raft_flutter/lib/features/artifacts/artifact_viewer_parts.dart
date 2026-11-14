// The viewer's small parts: its loading splash, the "can't show it" states
// and the version notices above the content.
//
// Source: packages/web/src/apps/artifacts/{ArtifactFrameState,
// ArtifactLoadingSplash,ArtifactVersionHistory (ArtifactPinnedVersionNotice,
// ArtifactNewVersionNotice),ArtifactViewer}.tsx at v1.24.0-source.1.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'artifact_frame_view.dart';
import 'artifact_models.dart';
import 'artifact_text.dart';

/// A state in place of the content (Web `FrameState`: an EmptyState).
class ArtifactViewerState extends StatelessWidget {
  const ArtifactViewerState({
    super.key,
    required this.title,
    this.detail = '',
    this.glyph = RaftGlyph.fileText,
    this.actionLabel,
    this.actionGlyph,
    this.onAction,
    this.actionKey,
  });

  final String title, detail;
  final RaftGlyph glyph;
  final String? actionLabel;
  final RaftGlyph? actionGlyph;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(RaftSpace.x6),
      child: RaftEmptyState(
        glyph: glyph,
        title: title,
        detail: detail,
        action: actionLabel == null
            ? null
            : RaftButton(
                key: actionKey,
                label: actionLabel!,
                glyph: actionGlyph,
                tone: RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.md,
                onPressed: onAction,
              ),
      ),
    ),
  );
}

/// What a frame that didn't load shows, with Web's words and actions
/// (ArtifactFrame's fallback and error states).
Widget artifactFrameStateView(
  BuildContext context,
  ArtifactFrameController frame, {
  required VoidCallback onRetry,
  required VoidCallback onOpenInBrowser,
  VoidCallback? onDownload,
}) {
  String tr(String s) => raftText(context, s);
  ArtifactViewerState retry(String title, {String detail = ''}) =>
      ArtifactViewerState(
        key: const ValueKey('artifact-frame-state'),
        title: title,
        detail: detail,
        glyph: RaftGlyph.alertCircle,
        actionLabel: tr('Try again'),
        actionGlyph: RaftGlyph.refreshCw,
        actionKey: const ValueKey('artifact-frame-retry'),
        onAction: onRetry,
      );
  if (frame.status == ArtifactFrameStatus.fallback) {
    return switch (frame.fallback) {
      ArtifactFrameFallback.needsTab => ArtifactViewerState(
        key: const ValueKey('artifact-frame-needs-tab'),
        title: tr('Open this Artifact in a new tab'),
        detail: tr('Your browser won\'t show it inside this page.'),
        glyph: RaftGlyph.arrowUpRight,
        actionLabel: tr('Open in browser'),
        actionGlyph: RaftGlyph.arrowUpRight,
        actionKey: const ValueKey('artifact-frame-open-tab'),
        onAction: onOpenInBrowser,
      ),
      ArtifactFrameFallback.denied => ArtifactViewerState(
        key: const ValueKey('artifact-frame-denied'),
        title: tr('You can\'t open this anymore'),
        detail: tr('You no longer have access to it.'),
        glyph: RaftGlyph.shield,
      ),
      ArtifactFrameFallback.expired => retry(tr('This view has expired')),
      _ => retry(tr('This Artifact didn\'t load')),
    };
  }
  return switch (frame.errorCode) {
    'NOT_VISIBLE' => ArtifactViewerState(
      key: const ValueKey('artifact-viewer-unavailable'),
      title: tr('Can\'t open this Artifact'),
      detail: tr('It doesn\'t exist, or you don\'t have access to it.'),
    ),
    'VERSION_NOT_FOUND' => ArtifactViewerState(
      key: const ValueKey('artifact-frame-version-gone'),
      title: tr('This version isn\'t available'),
    ),
    'NOT_FRAMED' => ArtifactViewerState(
      key: const ValueKey('artifact-viewer-no-preview'),
      title: tr('This file can\'t be previewed here yet.'),
      actionLabel: onDownload == null ? null : tr('Download'),
      actionGlyph: RaftGlyph.download,
      onAction: onDownload,
    ),
    'RATE_LIMITED' => retry(
      tr('Too many Artifacts opened at once'),
      detail: tr('Try again later.'),
    ),
    'CONTENT_UNAVAILABLE' => retry(
      tr('The preview isn\'t available right now'),
      detail: tr('Try again later.'),
    ),
    _ => retry(tr('This Artifact didn\'t load')),
  };
}

/// The loading cover over a page that hasn't shown yet (Web
/// `ArtifactLoadingSplash`: "Getting the page", then "Starting the page").
/// Web draws an animated pixel icon; the app shows the kind's icon still.
class ArtifactLoadingSplash extends StatelessWidget {
  const ArtifactLoadingSplash({
    super.key,
    required this.kind,
    required this.starting,
  });

  final ArtifactKind? kind;
  final bool starting;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = raftText(
      context,
      starting ? 'Starting the page' : 'Getting the page',
    );
    return Semantics(
      liveRegion: true,
      label: label,
      child: ColoredBox(
        key: ValueKey(
          starting ? 'artifact-splash-starting' : 'artifact-splash-getting',
        ),
        color: t.panel,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: RaftSpace.x3,
            children: [
              RaftIcon(
                kind == null ? RaftGlyph.fileText : artifactKindGlyph(kind!),
                size: 28,
                color: t.ui.foregroundHint,
              ),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: RaftTypography.body(
                    t,
                    size: 13,
                    line: 18,
                  ).copyWith(color: t.ui.foregroundMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Viewing v2 · Back to latest", or a version that failed to load (Web
/// `ArtifactPinnedVersionNotice`).
class ArtifactVersionNotice extends StatelessWidget {
  const ArtifactVersionNotice({
    super.key,
    required this.card,
    this.failedVersion,
    this.failedLatest = false,
    required this.onBackToLatest,
    required this.onRetry,
  });

  final ArtifactCard card;
  final int? failedVersion;
  final bool failedLatest;
  final VoidCallback onBackToLatest, onRetry;

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final back = RaftButton(
      key: const ValueKey('artifact-viewer-back-to-latest'),
      label: tr('Back to latest'),
      tone: RaftButtonRecipeVariant.ghost,
      size: RaftButtonRecipeSize.sm,
      onPressed: onBackToLatest,
    );
    if (failedLatest || failedVersion != null) {
      return RaftBanner(
        key: const ValueKey('artifact-viewer-version-failed'),
        status: RaftBannerRecipeStatus.warning,
        description: failedLatest
            ? tr(
                'Couldn\'t load the latest version. Still showing the version before it.',
              )
            : raftFormat(
                context,
                'Couldn\'t load v{version}. Still showing the version before it.',
                {'version': failedVersion},
              ),
        action: Wrap(
          spacing: RaftSpace.x2,
          children: [
            RaftButton(
              key: const ValueKey('artifact-viewer-version-retry'),
              label: tr('Try again'),
              tone: RaftButtonRecipeVariant.ghost,
              size: RaftButtonRecipeSize.sm,
              onPressed: onRetry,
            ),
            if (!failedLatest) back,
          ],
        ),
      );
    }
    if (!card.pinned) return const SizedBox.shrink();
    return RaftBanner(
      key: const ValueKey('artifact-viewer-pinned'),
      status: RaftBannerRecipeStatus.default_,
      glyph: RaftGlyph.clock,
      description: raftFormat(context, 'Viewing v{version}', {
        'version': card.version,
      }),
      action: back,
    );
  }
}

/// "Developer published v3" with View latest (Web `ArtifactNewVersionNotice`).
class ArtifactNewVersionNotice extends StatelessWidget {
  const ArtifactNewVersionNotice({
    super.key,
    required this.version,
    this.publisher,
    required this.onViewLatest,
  });

  final int version;
  final String? publisher;
  final VoidCallback onViewLatest;

  @override
  Widget build(BuildContext context) => RaftBanner(
    key: const ValueKey('artifact-new-version'),
    status: RaftBannerRecipeStatus.info,
    glyph: RaftGlyph.arrowUp,
    description: publisher == null
        ? raftFormat(context, 'v{version} is available', {'version': version})
        : raftFormat(context, '{name} published v{version}', {
            'name': publisher,
            'version': version,
          }),
    action: RaftButton(
      key: const ValueKey('artifact-new-version-view'),
      label: raftText(context, 'View latest'),
      tone: RaftButtonRecipeVariant.ghost,
      size: RaftButtonRecipeSize.sm,
      onPressed: onViewLatest,
    ),
  );
}

/// The version tag in the header: "v3", a button that opens the version list
/// when there is more than one version (Web `ArtifactVersionTag`).
class ArtifactVersionTag extends StatelessWidget {
  const ArtifactVersionTag({super.key, required this.data, this.onOpen});

  final ArtifactViewerData data;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final card = data.card;
    final label = artifactVersionLabel(context, card.version);
    final open = data.versions.length > 1 && !card.fromAnotherServer
        ? onOpen
        : null;
    return RaftButton(
      key: const ValueKey('artifact-version-badge'),
      label: label,
      semanticLabel: open == null
          ? label
          : raftFormat(context, 'v{version}, switch version', {
              'version': card.version,
            }),
      tone: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.sm,
      onPressed: open,
      inertWhenDisabled: false,
    );
  }
}
