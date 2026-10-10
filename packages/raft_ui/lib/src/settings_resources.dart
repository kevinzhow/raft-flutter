// Settings > Resources pages from the Web client (raft-source 26f77ef):
// - [RaftSettingsAbout]: SettingsPanel.tsx AboutSection + MobileDownloadQr.tsx.
// - [RaftReleaseNotesView]: settings/ReleaseNotesPanel.tsx body (the panel
//   header is the caller's RaftSettingsPanelHeader).
// The app supplies data and callbacks; every class list is resolved here.
import 'package:flutter/material.dart';

import 'banner.dart';
import 'components.dart' show RaftButton;
import 'design_primitives.dart' show RaftControlVariant, RaftTypography;
import 'icons.dart';
import 'indicators.dart';
import 'list_items.dart';
import 'localization.dart';
import 'qr_code.dart';
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart' show RaftButtonRecipeSize;
import 'recipes/card.g.dart';
import 'settings_layout.dart';
import 'theme.dart';

/// MobileDownloadQr.tsx + the AboutSection mobile-app buttons.
@immutable
class RaftAboutMobileApp {
  const RaftAboutMobileApp({
    required this.onAndroid,
    required this.onIos,
    this.qrUrl,
  });
  final VoidCallback onAndroid, onIos;

  /// The web-origin `/download` chooser the QR encodes; null hides the QR
  /// (Web: `hidden sm:block`, and a failed encoder chunk renders nothing).
  final String? qrUrl;
}

/// AboutSection: `space-y-4` of `space-y-2` sections (SectionHeader +
/// non-interactive SurfaceListItem): Version, Mobile app, Workspace.
class RaftSettingsAbout extends StatelessWidget {
  const RaftSettingsAbout({
    super.key,
    required this.version,
    this.productName = 'Raft',
    this.mobileApp,
    this.workspaceName,
    this.workspaceDetail,
  });
  final String productName, version;
  final RaftAboutMobileApp? mobileApp;

  /// Workspace card (`showWorkspace`); null hides the section.
  final String? workspaceName;
  final String? workspaceDetail;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    Widget section(String key, String label, RaftGlyph glyph, Widget body) =>
        Column(
          key: ValueKey('settings-about-$key'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftSettingsSectionHeader(label: label, glyph: glyph, bottom: 8),
            body,
          ],
        );
    // SurfaceListItem `space-y-1`: bold title over the muted text-xs detail.
    Widget card(String title, String detail) => RaftSurfaceListItem(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(raftText(context, title), style: text.title),
          const SizedBox(height: 4),
          Text(raftText(context, detail), style: text.description),
        ],
      ),
    );
    final app = mobileApp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          'version',
          'Version',
          RaftGlyph.tag,
          card(productName, version),
        ),
        if (app != null) ...[
          const SizedBox(height: 16),
          section(
            'mobile-app',
            'Mobile app',
            RaftGlyph.smartphone,
            RaftSurfaceListItem(
              interactive: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    raftText(context, 'Get the Raft mobile app.'),
                    style: text.description,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      RaftButton(
                        key: const ValueKey('mobile-download-android'),
                        label: 'Download for Android',
                        variant: RaftControlVariant.outline,
                        size: RaftButtonRecipeSize.sm,
                        onPressed: app.onAndroid,
                      ),
                      RaftButton(
                        key: const ValueKey('mobile-download-ios'),
                        label: 'Get the iOS beta',
                        variant: RaftControlVariant.outline,
                        size: RaftButtonRecipeSize.sm,
                        onPressed: app.onIos,
                      ),
                    ],
                  ),
                  if (app.qrUrl != null) ...[
                    const SizedBox(height: 12),
                    RaftMobileDownloadQr(url: app.qrUrl!),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (workspaceName != null) ...[
          const SizedBox(height: 16),
          section(
            'workspace',
            'Workspace',
            RaftGlyph.building2,
            card(workspaceName!, workspaceDetail ?? ''),
          ),
        ],
      ],
    );
  }
}

/// MobileDownloadQr.tsx: a one-line caption (`mb-1 whitespace-nowrap
/// text-[11px] leading-tight text-foreground-muted theme-brutal:text-black/50`)
/// over the code (`h-28 w-28 border-2 border-black bg-white text-black p-1`,
/// crisp-edged modules, theme independent).
class RaftMobileDownloadQr extends StatelessWidget {
  const RaftMobileDownloadQr({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final matrix = RaftQrMatrix.encode(url);
    return Column(
      key: const ValueKey('mobile-download-qr'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 11 * 1.25,
          child: Text(
            raftText(context, 'Or, Scan with your phone'),
            maxLines: 1,
            softWrap: false,
            style: RaftTypography.body(
              t,
              size: 11,
              line: 11 * 1.25,
              color: RaftSettingsText(t).faint,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: CustomPaint(painter: RaftQrCodePainter(matrix, Colors.black)),
        ),
      ],
    );
  }
}

/// ReleaseNotesPanel RELEASE_TYPE_CONFIG, in RELEASE_CATEGORY_ORDER.
enum RaftReleaseNoteKind {
  feature('New', RaftBadgeRecipeVariant.information),
  improvement('Improved', RaftBadgeRecipeVariant.success),
  fix('Fix', RaftBadgeRecipeVariant.warning),
  breaking('Breaking', RaftBadgeRecipeVariant.accent),
  deprecated('Deprecated', RaftBadgeRecipeVariant.muted);

  const RaftReleaseNoteKind(this.label, this.badge);
  final String label;
  final RaftBadgeRecipeVariant badge;
}

@immutable
class RaftReleaseNoteEntry {
  const RaftReleaseNoteEntry(this.kind, this.text, {this.emphasis = false});
  final RaftReleaseNoteKind kind;
  final String text;
  final bool emphasis;
}

@immutable
class RaftReleaseNote {
  const RaftReleaseNote({
    required this.id,
    required this.date,
    this.version,
    this.current = false,
    this.retracted = false,
    this.entries = const [],
  });
  final String id, date;
  final String? version;
  final bool current, retracted;
  final List<RaftReleaseNoteEntry> entries;
}

enum RaftReleaseNotesStatus { loading, error, ready }

/// ReleaseNotesPanel content (`px-5 py-4` is the caller's scroll inset): the
/// "What's New" eyebrow, then the loading line, the destructive banner with
/// "Try again", or one card per release.
class RaftReleaseNotesView extends StatelessWidget {
  const RaftReleaseNotesView({
    super.key,
    required this.status,
    this.releases = const [],
    this.onRetry,
  });
  final RaftReleaseNotesStatus status;
  final List<RaftReleaseNote> releases;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `mb-4 flex items-center gap-2`: FileText 16 + SectionEyebrow.
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              RaftIcon(RaftGlyph.fileText, size: 16, color: text.muted),
              const SizedBox(width: 8),
              Flexible(
                child: RaftSectionEyebrow(raftText(context, "What's New")),
              ),
            ],
          ),
        ),
        switch (status) {
          RaftReleaseNotesStatus.loading => Text(
            raftText(context, 'Loading release notes…'),
            style: text.bodyMuted,
          ),
          RaftReleaseNotesStatus.error => RaftBanner(
            status: RaftBannerRecipeStatus.destructive,
            glyph: RaftGlyph.alertTriangle,
            description: 'Release notes are unavailable right now.',
            action: RaftButton(
              key: const ValueKey('release-notes-retry'),
              label: 'Try again',
              variant: RaftControlVariant.outline,
              size: RaftButtonRecipeSize.sm,
              onPressed: onRetry,
            ),
          ),
          RaftReleaseNotesStatus.ready => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, release) in releases.indexed) ...[
                if (i > 0) const SizedBox(height: 16),
                RaftReleaseNoteCard(
                  key: ValueKey('release-entry-${release.id}'),
                  release: release,
                ),
              ],
            ],
          ),
        },
      ],
    );
  }
}

/// One `release-entry` Card (`p-4`; the current release `bg-primary-soft
/// theme-brutal:bg-soft-signal/35`): the version/date, Current and
/// Retracted badges, then each non-empty category as a soft uppercase badge
/// over a `list-disc` list (emphasised entries bold and strong).
class RaftReleaseNoteCard extends StatelessWidget {
  const RaftReleaseNoteCard({super.key, required this.release});
  final RaftReleaseNote release;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final text = RaftSettingsText(t);
    final root = RaftCardRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    ).root.withCssUsedBorderWidths();
    final label = release.version == null
        ? release.date
        : '${release.version} (${release.date})';
    // `text-sm`; emphasis `font-bold text-foreground-strong
    // theme-brutal:text-black`, else `text-foreground-muted
    // theme-brutal:text-black/80`.
    TextStyle entryStyle(bool emphasis) => RaftTypography.body(
      t,
      size: 14,
      line: 20,
      weight: emphasis ? FontWeight.w700 : FontWeight.w400,
      color: emphasis
          ? text.strong
          : t.brutal
          ? Colors.black.withValues(alpha: .8)
          : t.muted,
    );
    final marker = t.brutal ? Colors.black.withValues(alpha: .7) : t.muted;
    final groups = [
      for (final kind in RaftReleaseNoteKind.values)
        if (release.entries.any((e) => e.kind == kind))
          (kind, release.entries.where((e) => e.kind == kind).toList()),
    ];
    return RaftRecipeBox(
      style: root,
      tokens: rt,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      applyText: false,
      decorationOverride: release.current
          ? (d) => d.copyWith(
              color: t.brutal
                  ? t.product.softSignal.withValues(alpha: .35)
                  : t.colors['primary-soft'],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RaftBadge(label: label, variant: RaftBadgeRecipeVariant.primary),
              if (release.current)
                RaftBadge(
                  label: raftText(context, 'Current'),
                  variant: RaftBadgeRecipeVariant.success,
                ),
              if (release.retracted)
                RaftBadge(label: raftText(context, 'Retracted')),
            ],
          ),
          const SizedBox(height: 16),
          for (final (i, (kind, entries)) in groups.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            // The badge is inline-flex in a block div: it sits on the div's
            // strut line (16px / 1.5), baseline aligned.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '\u200B',
                  style: RaftTypography.body(t, size: 16, line: 24),
                ),
                RaftBadge(
                  label: raftText(context, kind.label),
                  appearance: RaftBadgeRecipeAppearance.soft,
                  variant: kind.badge,
                  uppercase: true,
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final (j, entry) in entries.indexed) ...[
              if (j > 0) const SizedBox(height: 6),
              _DiscItem(
                marker: marker,
                child: Text(entry.text, style: entryStyle(entry.emphasis)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// `list-disc pl-5` item: Chromium's outside disc marker (a ~5px dot whose
/// right edge sits ~10px before the text, centred on the first line).
class _DiscItem extends StatelessWidget {
  const _DiscItem({required this.marker, required this.child});
  final Color marker;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 20,
        height: 20,
        child: Align(
          alignment: const Alignment(-0.4, 0),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: marker, shape: BoxShape.circle),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}
