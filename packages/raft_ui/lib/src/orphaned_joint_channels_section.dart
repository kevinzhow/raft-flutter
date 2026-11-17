// Web components/settings/OrphanedJointChannelsSection.tsx (Settings > Server):
// the joint channels this server holds that nobody here is in, each with a
// Disconnect button. Presentation only: the app owns the list, the capability
// check and the disconnect request.
import 'package:flutter/material.dart';

import 'error_presentation.dart';
import 'icons.dart';
import 'localization.dart';
import 'raft/icon_tile.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'settings_controls.dart' show RaftSettingsRecipeButton;
import 'settings_layout.dart';
import 'theme.dart';

/// One orphaned joint channel; [metadata] and [disconnectLabel] are formatted
/// by the app (`Connected with {servers} · …`, `Disconnect {name}`).
class RaftOrphanedJointChannelRow {
  const RaftOrphanedJointChannelRow({
    required this.id,
    required this.name,
    required this.metadata,
    required this.disconnectLabel,
  });
  final String id, name, metadata, disconnectLabel;
}

/// `<section className="mb-6">`: SectionHeader (GitBranch icon, label, count),
/// the footnote description, an optional warning banner and a Card of
/// hairline-ruled rows (`px-4 py-3`, `sm:min-h-11`): the `#name` and metadata,
/// and an outline Disconnect button (`w-full` on a phone, `sm:w-auto` from
/// 640px).
class RaftOrphanedJointChannelsSection extends StatelessWidget {
  const RaftOrphanedJointChannelsSection({
    super.key,
    required this.rows,
    required this.description,
    required this.onDisconnect,
    this.disabled = false,
    this.error,
  });
  final List<RaftOrphanedJointChannelRow> rows;

  /// `settings.orphanedJointChannels.description`, formatted with the server.
  final String description;
  final ValueChanged<String> onDisconnect;

  /// `disabled={confirming !== null}`: every button, while the confirmation is
  /// open.
  final bool disabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final hairline = t.colors['line-hairline'] ?? t.colors['line-muted']!;
    return Padding(
      padding: const EdgeInsets.only(bottom: RaftSpace.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSettingsSectionHeader(
            label: 'External channels nobody here is in',
            glyph: RaftGlyph.gitBranch,
            count: rows.length,
            bottom: RaftSpace.x1,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: RaftSpace.x3),
            child: Text(
              description,
              style: text.description.copyWith(color: t.muted),
            ),
          ),
          if (error != null) ...[
            RaftErrorBanner(
              error!,
              key: const ValueKey('orphaned-joint-channels-error'),
              small: true,
            ),
            const SizedBox(height: RaftSpace.x3),
          ],
          RaftSettingsCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, row) in rows.indexed)
                  Container(
                    key: ValueKey('orphaned-joint-channel-row-${row.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: RaftSpace.x4,
                      vertical: RaftSpace.x3,
                    ),
                    decoration: index == 0
                        ? null
                        : BoxDecoration(
                            border: Border(top: BorderSide(color: hairline)),
                          ),
                    constraints: BoxConstraints(minHeight: wide ? 44 : 0),
                    child: _row(context, t, text, row, wide),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    RaftTokens t,
    RaftSettingsText text,
    RaftOrphanedJointChannelRow row,
    bool wide,
  ) {
    final info = Row(
      children: [
        const RaftIconTile(
          glyph: RaftGlyph.gitBranch,
          size: RaftIconTileSize.sm,
        ),
        const SizedBox(width: RaftSpace.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                raftFormat(context, '#{name}', {'name': row.name}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.title,
              ),
              const SizedBox(height: RaftSpace.half),
              Text(
                row.metadata,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.description.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
      ],
    );
    final disconnect = RaftSettingsRecipeButton(
      key: ValueKey('orphaned-joint-channel-disconnect-${row.id}'),
      label: 'Disconnect',
      glyph: RaftGlyph.unplug,
      glyphSize: 14,
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.md,
      expand: !wide,
      semanticLabel: row.disconnectLabel,
      onPressed: disabled ? null : () => onDisconnect(row.id),
    );
    if (wide) {
      return Row(
        children: [
          Expanded(child: info),
          const SizedBox(width: RaftSpace.x3),
          disconnect,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        info,
        const SizedBox(height: RaftSpace.x3),
        disconnect,
      ],
    );
  }
}
