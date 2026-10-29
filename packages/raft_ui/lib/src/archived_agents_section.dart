// Web components/settings/ArchivedAgentsSection.tsx (Settings > Server): the
// archived agents of this server. Presentation only: the app owns the list, the
// metadata copy and the navigation.
import 'card.dart' show RaftCard;

import 'package:flutter/material.dart';

import 'agent_profile.dart' show RaftAvatarSlot, RaftAvatarSlotContext;
import 'css_pixel_snap.dart';
import 'icons.dart';
import 'localization.dart';
import 'raft_underline.dart';
import 'recipes/button_variants.g.dart';
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'theme.dart';

/// One archived agent; [metadata] is the formatted
/// `Archived {date} · {workspace}` line.
class RaftArchivedAgentRow {
  const RaftArchivedAgentRow({
    required this.id,
    required this.name,
    required this.metadata,
    this.avatarUrl,
    this.canViewWorkspace = false,
  });
  final String id, name, metadata;
  final String? avatarUrl;

  /// `workspaceState === "on_computer"`: the View workspace button shows.
  final bool canViewWorkspace;
}

/// `<section className="mb-6">`: SectionHeader (Archive icon, label, count) and
/// one row per agent: a grayscale avatar, the underlined name that opens the
/// read-only profile, the metadata line, and an outline "View workspace"
/// button (full width on a phone, `sm:w-auto` from 640px).
class RaftArchivedAgentsSection extends StatelessWidget {
  const RaftArchivedAgentsSection({
    super.key,
    required this.rows,
    required this.onOpen,
    required this.onViewWorkspace,
  });
  final List<RaftArchivedAgentRow> rows;
  final ValueChanged<String> onOpen, onViewWorkspace;

  /// `grayscale opacity-60` of the avatar.
  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 640;
    return Padding(
      key: const ValueKey('archived-agents-section'),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSettingsSectionHeader(
            label: 'Archived agents',
            glyph: RaftGlyph.archive,
            count: rows.length,
          ),
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            RaftCard.item(
              key: ValueKey('archived-agent-row-${row.id}'),
              interactive: false,
              child: _row(context, row, wide),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, RaftArchivedAgentRow row, bool wide) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final view = RaftSettingsRecipeButton(
      key: ValueKey('archived-agent-workspace-${row.id}'),
      label: 'View workspace',
      size: RaftButtonRecipeSize.sm,
      expand: !wide,
      semanticLabel: raftFormat(context, 'View the workspace of {name}', {
        'name': row.name,
      }),
      onPressed: () => onViewWorkspace(row.id),
    );
    final info = Row(
      children: [
        Opacity(
          opacity: .6,
          child: ColorFiltered(
            colorFilter: _grayscale,
            child: RaftAvatarSlot(
              name: row.name,
              avatarUrl: row.avatarUrl,
              slot: RaftAvatarSlotContext.surfaceList,
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
                  key: ValueKey('archived-agent-open-${row.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onOpen(row.id),
                  child: RaftUnderlinedText(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.title.copyWith(color: t.muted),
                  ),
                ),
              ),
              const SizedBox(height: 2),
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
    if (!row.canViewWorkspace) return info;
    if (wide) {
      return Row(
        children: [
          Expanded(child: info),
          const SizedBox(width: 12),
          RaftCssPixelSnap(child: view),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [info, const SizedBox(height: 12), view],
    );
  }
}
