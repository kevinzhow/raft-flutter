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
import 'recipes/button_variants.g.dart';
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'theme.dart';
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
/// an optional warning banner and `space-y-2` rows: a 32px type icon, the
/// underlined `#name` link with its metadata line, and a success "Unarchive"
/// button (`w-full` on a phone, `sm:w-auto` from 640px).
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
    final wide = MediaQuery.sizeOf(context).width >= 640;
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
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            RaftCard.item(
              key: ValueKey('archived-channel-row-${row.id}'),
              interactive: false,
              child: _row(context, t, row, wide),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    RaftTokens t,
    RaftArchivedChannelRow row,
    bool wide,
  ) {
    final text = RaftSettingsText(t);
    final label = typeLabel(context, row.type);
    final unarchive = RaftSettingsRecipeButton(
      key: ValueKey('archived-channel-unarchive-${row.id}'),
      label: busyId == row.id ? 'Unarchiving…' : 'Unarchive',
      glyph: RaftGlyph.archiveRestore,
      glyphSize: 14,
      variant: RaftButtonRecipeVariant.success,
      size: RaftButtonRecipeSize.sm,
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
          child: Semantics(
            label: label,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: t.semantic.fillMuted,
                border: Border.all(color: text.softEdge, width: t.border),
              ),
              child: Center(
                child: RaftIcon(typeGlyph(row.type), size: 16, color: t.muted),
              ),
            ),
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
                    style: text.title,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                row.metadata,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.description.copyWith(
                  color: text.faint.withValues(alpha: 1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (wide) {
      return Row(
        children: [
          Expanded(child: info),
          const SizedBox(width: 12),
          // A right-aligned button sits at a fractional x; Blink snaps it.
          RaftCssPixelSnap(child: unarchive),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [info, const SizedBox(height: 12), unarchive],
    );
  }
}
