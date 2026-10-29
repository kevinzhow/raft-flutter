// Settings > Resources pages from the Web client (raft-source 26f77ef):
// - [RaftSettingsAbout]: SettingsPanel.tsx AboutSection + MobileDownloadQr.tsx.
// - [RaftReleaseNotesView]: settings/ReleaseNotesPanel.tsx body (the panel
//   header is the caller's RaftSettingsPanelHeader).
// The app supplies data and callbacks; every class list is resolved here.
import 'card.dart' show RaftCard;

import 'package:flutter/material.dart';

import 'banner.dart';
import 'components.dart' show RaftButton;
import 'design_primitives.dart'
    show RaftControlVariant, RaftSpinner, RaftTypography;
import 'icons.dart';
import 'indicators.dart';
import 'list_items.dart';
import 'localization.dart';
import 'qr_code.dart';
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart' show RaftButtonRecipeSize;
import 'recipes/card.g.dart';
import 'settings_layout.dart';
import 'text_scaling.dart' show RaftScaled;
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

/// What the Updates card says; the app derives it from its update service.
enum RaftAboutUpdateState {
  idle,
  checking,
  available,
  upToDate,
  failed,
  unsupported,

  /// The update is being downloaded and installed ([RaftAboutUpdate.progress]).
  installing,

  /// The update is installed; the app only needs to restart.
  restart,
}

/// Native-only Updates row under the Version card (the Web client updates
/// itself). [message] and [detail] are already localized; [actionLabel] and
/// [checkLabel] are catalog keys that the buttons localize.
///
/// The row is always present. [onAction] (the update itself, "Restart to
/// finish", or the release-page fallback after a failed install) exists in
/// [RaftAboutUpdateState.available], [RaftAboutUpdateState.restart],
/// [RaftAboutUpdateState.installing] (Cancel) and [RaftAboutUpdateState.failed];
/// [onCheck] is null while a check or an install runs and in
/// [RaftAboutUpdateState.unsupported], which has no check button at all.
/// [progress] (0..1) draws the progress bar of an in-place install.
@immutable
class RaftAboutUpdate {
  const RaftAboutUpdate({
    required this.state,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.checkLabel = 'Check for Updates',
    this.onCheck,
    this.progress,
    this.notes,
  });
  final RaftAboutUpdateState state;
  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String checkLabel;
  final VoidCallback? onCheck;
  final double? progress;

  /// What the offered release changes, shown above the buttons so the user
  /// can read it before updating; null hides the section.
  final RaftAboutUpdateNotes? notes;
}

enum RaftAboutUpdateNotesStatus { loading, ready, empty, failed }

/// The release notes under an available update: every release between the
/// installed one and the offered one, newest first. A failure shows [onRetry]
/// and never blocks the update button.
@immutable
class RaftAboutUpdateNotes {
  const RaftAboutUpdateNotes({
    required this.status,
    this.releases = const [],
    this.onRetry,
  });
  final RaftAboutUpdateNotesStatus status;
  final List<RaftReleaseNote> releases;
  final VoidCallback? onRetry;
}

/// AboutSection: `space-y-4` of `space-y-2` sections (SectionHeader +
/// non-interactive SurfaceListItem): Version, Mobile app, Workspace.
class RaftSettingsAbout extends StatelessWidget {
  const RaftSettingsAbout({
    super.key,
    required this.version,
    this.productName = 'Raft',
    this.mobileApp,
    this.update,
    this.workspaceName,
    this.workspaceDetail,
  });
  final String productName, version;
  final RaftAboutUpdate? update;
  final RaftAboutMobileApp? mobileApp;

  /// Workspace card (`showWorkspace`); null hides the section.
  final String? workspaceName;
  final String? workspaceDetail;

  Widget _updateCard(RaftSettingsText text) {
    final update = this.update!;
    final leading = switch (update.state) {
      RaftAboutUpdateState.available => const RaftAttentionDot(danger: true),
      RaftAboutUpdateState.checking ||
      RaftAboutUpdateState.installing => const RaftSpinner(),
      _ => null,
    };
    final detail = update.detail;
    return RaftCard.item(
      key: const ValueKey('settings-about-update'),
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 8)],
              Expanded(child: Text(update.message, style: text.title)),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail, style: text.description),
          ],
          if (update.notes != null) ...[
            const SizedBox(height: 12),
            _UpdateNotes(update.notes!),
          ],
          if (update.progress != null) ...[
            const SizedBox(height: 8),
            RaftProgressBar(
              key: const ValueKey('settings-about-update-progress'),
              value: update.progress! * 100,
              size: RaftProgressRecipeSize.sm,
            ),
          ],
          if (update.state != RaftAboutUpdateState.unsupported) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (update.onAction != null)
                  RaftButton(
                    key: const ValueKey('settings-about-update-action'),
                    label: update.actionLabel ?? '',
                    variant: RaftControlVariant.outline,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: update.onAction,
                  ),
                if (update.state != RaftAboutUpdateState.unsupported)
                  RaftButton(
                    key: const ValueKey('settings-about-update-check'),
                    label: update.checkLabel,
                    variant: update.onAction != null
                        ? RaftControlVariant.ghost
                        : RaftControlVariant.outline,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: update.onCheck,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

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
    Widget card(String title, String detail) => RaftCard.item(
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
          update == null
              ? card(productName, version)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    card(productName, version),
                    const SizedBox(height: 8),
                    _updateCard(text),
                  ],
                ),
        ),
        if (app != null) ...[
          const SizedBox(height: 16),
          section(
            'mobile-app',
            'Mobile app',
            RaftGlyph.smartphone,
            RaftCard.item(
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
            // settings.about.workspaceSectionLabel: 工作空间, not the agent
            // file workspace's 工作区.
            raftTextZh(context, 'Workspace', '工作空间'),
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
        RaftScaled.lineBox(
          context,
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
    this.isNew = false,
    this.retracted = false,
    this.entries = const [],
  });
  final String id, date;
  final String? version;

  /// [current] is the installed release; [isNew] a release newer than the
  /// installed one (not installed yet).
  final bool current, isNew, retracted;
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
    this.onRefreshRetry,
  });
  final RaftReleaseNotesStatus status;
  final List<RaftReleaseNote> releases;
  final VoidCallback? onRetry;

  /// Set when a refresh failed while [releases] are shown: a quiet one-line
  /// "couldn't refresh" with a retry above the list, instead of the banner.
  final VoidCallback? onRefreshRetry;

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
            // ReleaseNotesPanel: `<Banner intent="warning" withIcon>`.
            status: RaftBannerRecipeStatus.warning,
            glyph: RaftGlyph.alertTriangle,
            description: 'Release notes are unavailable right now.',
            action: RaftButton(
              key: const ValueKey('release-notes-retry'),
              label: 'Try Again',
              variant: RaftControlVariant.outline,
              size: RaftButtonRecipeSize.sm,
              onPressed: onRetry,
            ),
          ),
          RaftReleaseNotesStatus.ready => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onRefreshRetry != null) ...[
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        raftText(context, "Couldn't refresh release notes."),
                        style: text.bodyMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RaftButton(
                      key: const ValueKey('release-notes-refresh-retry'),
                      label: 'Try Again',
                      variant: RaftControlVariant.ghost,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: onRefreshRetry,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
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
/// Retracted badges, then each non-empty category as a soft badge
/// over a `list-disc` list (emphasised entries bold and strong).
class RaftReleaseNoteCard extends StatelessWidget {
  const RaftReleaseNoteCard({super.key, required this.release});
  final RaftReleaseNote release;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final root = RaftCardRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: rt,
    ).root.withCssUsedBorderWidths();
    final label = release.version == null
        ? release.date
        : '${release.version} (${release.date})';
    return RaftRecipeBox(
      style: root,
      tokens: rt,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      applyText: false,
      decorationOverride: release.current
          ? (d) => d.copyWith(color: t.colors['primary-soft'])
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
              if (release.isNew)
                RaftBadge(
                  label: raftText(context, 'New version'),
                  variant: RaftBadgeRecipeVariant.information,
                ),
              if (release.retracted)
                RaftBadge(label: raftText(context, 'Retracted')),
            ],
          ),
          const SizedBox(height: 16),
          RaftReleaseNoteEntryGroups(release: release),
        ],
      ),
    );
  }
}

/// The categories of one release (each non-empty one as a soft
/// badge over a `list-disc` list, emphasised entries bold and strong): the body
/// of [RaftReleaseNoteCard], also used under an available update.
class RaftReleaseNoteEntryGroups extends StatelessWidget {
  const RaftReleaseNoteEntryGroups({super.key, required this.release});
  final RaftReleaseNote release;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    // `text-sm`; emphasis `font-bold text-foreground-strong
    // theme-brutal:text-black`, else `text-foreground-muted
    // theme-brutal:text-black/80`.
    TextStyle entryStyle(bool emphasis) => RaftTypography.body(
      t,
      size: 14,
      line: 20,
      weight: emphasis ? FontWeight.w700 : FontWeight.w400,
      color: emphasis ? text.strong : t.muted,
    );
    final marker = t.muted;
    final groups = [
      for (final kind in RaftReleaseNoteKind.values)
        if (release.entries.any((e) => e.kind == kind))
          (kind, release.entries.where((e) => e.kind == kind).toList()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (kind, entries)) in groups.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          // The badge is inline-flex in a block div: it sits on the div's
          // strut line (16px / 1.5), baseline aligned.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('\u200B', style: RaftTypography.body(t, size: 16, line: 24)),
              RaftBadge(
                label: raftText(context, kind.label),
                appearance: RaftBadgeRecipeAppearance.soft,
                variant: kind.badge,
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
    );
  }
}

/// The notes section of the Updates card: the offered (newest) release in
/// full, the older skipped releases behind one toggle row.
class _UpdateNotes extends StatefulWidget {
  const _UpdateNotes(this.notes);
  final RaftAboutUpdateNotes notes;

  @override
  State<_UpdateNotes> createState() => _UpdateNotesState();
}

class _UpdateNotesState extends State<_UpdateNotes> {
  bool expanded = false;

  Widget _release(RaftReleaseNote release, RaftSettingsText text) =>
      KeyedSubtree(
        key: ValueKey('update-notes-${release.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              release.version == null
                  ? release.date
                  : '${release.version} (${release.date})',
              style: text.title,
            ),
            const SizedBox(height: 6),
            RaftReleaseNoteEntryGroups(release: release),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final notes = widget.notes;
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final older = notes.releases.skip(1).toList();
    return Column(
      key: const ValueKey('settings-about-update-notes'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSectionEyebrow(raftText(context, "What's new in this update")),
        const SizedBox(height: 8),
        switch (notes.status) {
          RaftAboutUpdateNotesStatus.loading => Text(
            raftText(context, "Loading what's new…"),
            style: text.description,
          ),
          RaftAboutUpdateNotesStatus.empty => Text(
            raftText(context, 'No release notes for this update.'),
            style: text.description,
          ),
          RaftAboutUpdateNotesStatus.failed => Row(
            children: [
              Flexible(
                child: Text(
                  raftText(context, "Couldn't load what's new."),
                  style: text.description,
                ),
              ),
              const SizedBox(width: 8),
              RaftButton(
                key: const ValueKey('settings-about-update-notes-retry'),
                label: 'Try Again',
                variant: RaftControlVariant.ghost,
                size: RaftButtonRecipeSize.sm,
                onPressed: notes.onRetry,
              ),
            ],
          ),
          RaftAboutUpdateNotesStatus.ready => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _release(notes.releases.first, text),
              if (older.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: RaftButton(
                    key: const ValueKey('settings-about-update-notes-toggle'),
                    label: expanded
                        ? 'Show Fewer'
                        : older.length == 1
                        ? '1 More Update'
                        : raftFormat(context, '{count} More Updates', {
                            'count': older.length,
                          }),
                    variant: RaftControlVariant.ghost,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: () => setState(() => expanded = !expanded),
                  ),
                ),
                if (expanded)
                  for (final release in older) ...[
                    const SizedBox(height: 12),
                    _release(release, text),
                  ],
              ],
            ],
          ),
        },
      ],
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
