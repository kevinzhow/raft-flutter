// Web components/settings/ArchivedChannelsSection.tsx (Settings > Server): the
// archived channels the member may restore. Presentation only: the app owns
// the channel list, the capability check and the unarchive request.
import 'card.dart' show RaftCard;

import 'package:flutter/material.dart';

import 'raft_underline.dart';
import 'css_pixel_snap.dart';
import 'icons.dart';
import 'error_presentation.dart';
import 'localization.dart';
import 'notification_settings_rows.dart' show raftSettingsRowNarrowWidth;
import 'panel_layout.dart' show RaftCssText;
import 'raft/icon_tile.dart';
import 'raft/ui_tokens.dart';
import 'recipes/button_variants.g.dart';
import 'separator.dart';
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'tooltip.dart';

/// One archived channel row; [metadata] is the formatted
/// `{type} · Archived {date}` line.
class RaftArchivedChannelRow {
  const RaftArchivedChannelRow({
    required this.id,
    required this.name,
    required this.type,
    required this.metadata,
  });
  final String id, name, metadata;

  /// `channel`, `private` or `joint`.
  final String type;
}

/// `<section className="mb-6">`: SectionHeader (Archive icon, label, count),
/// an optional warning banner and `<Card className="rule-y rule-line-hairline">`
/// rows: an sm `IconTile` holding a 16px channel glyph, the underlined `#name`
/// link with its metadata line, and an outline `md` "Unarchive" button (`w-full`
/// below 512px, auto from 512px).
class RaftArchivedChannelsSection extends StatelessWidget {
  const RaftArchivedChannelsSection({
    super.key,
    required this.rows,
    required this.onOpen,
    required this.onUnarchive,
    this.busyId,
    this.error,
  });
  final List<RaftArchivedChannelRow> rows;

  /// The row whose request is in flight; every Unarchive button is disabled
  /// while one is set.
  final String? busyId;
  final String? error;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onUnarchive;

  static RaftGlyph typeGlyph(String type) => switch (type) {
    'private' => RaftGlyph.lock,
    'joint' => RaftGlyph.gitBranch,
    _ => RaftGlyph.hash,
  };

  static String typeLabel(BuildContext context, String type) =>
      raftText(context, switch (type) {
        'private' => 'Private channel',
        'joint' => 'Joint channel',
        _ => 'Public channel',
      });

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            !constraints.maxWidth.isFinite ||
            constraints.maxWidth >= raftSettingsRowNarrowWidth;
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftSettingsSectionHeader(
                label: 'Archived channels',
                glyph: RaftGlyph.archive,
                count: rows.length,
              ),
              if (error != null) ...[
                RaftErrorBanner(
                  error!,
                  key: const ValueKey('archived-channels-error'),
                  small: true,
                ),
                const SizedBox(height: 12),
              ],
              RaftCard(
                clip: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, row) in rows.indexed) ...[
                      if (index > 0) const RaftSeparator(),
                      Padding(
                        key: ValueKey('archived-channel-row-${row.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: RaftSpace.x4,
                          vertical: RaftSpace.x3,
                        ),
                        child: _row(context, t, row, wide),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    RaftTokens t,
    RaftArchivedChannelRow row,
    bool wide,
  ) {
    final label = typeLabel(context, row.type);
    final unarchive = RaftSettingsRecipeButton(
      key: ValueKey('archived-channel-unarchive-${row.id}'),
      label: busyId == row.id ? 'Unarchiving…' : 'Unarchive',
      glyph: RaftGlyph.archiveRestore,
      glyphSize: 14,
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.md,
      expand: !wide,
      semanticLabel: raftFormat(context, 'Unarchive {name}', {
        'name': row.name,
      }),
      onPressed: busyId == null ? () => onUnarchive(row.id) : null,
    );
    final info = Row(
      children: [
        RaftTooltip(
          message: label,
          child: RaftIconTile(
            glyph: typeGlyph(row.type),
            size: RaftIconTileSize.sm,
            semanticLabel: label,
            iconBuilder: (_, color) =>
                RaftIcon(typeGlyph(row.type), size: 16, color: color),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: raftFormat(context, 'Open {name}', {'name': row.name}),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onOpen(row.id),
                  child: RaftUnderlinedText(
                    raftFormat(context, '#{name}', {'name': row.name}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.scale(RaftTypeScale.subhead),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              RaftCssText(
                row.metadata,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.scale(
                  RaftTypeScale.footnote,
                  color: t.ui.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (wide) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: 12),
            // A right-aligned button sits at a fractional x; Blink snaps it.
            RaftCssPixelSnap(child: unarchive),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [info, const SizedBox(height: 12), unarchive],
    );
  }
}
