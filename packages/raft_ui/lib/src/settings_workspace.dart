// Settings > Workspace pages from the Web client (raft-source 26f77ef):
// - [RaftServerLabsSection]: SettingsPanel.tsx LabsSection (Labs tab).
// - [RaftProviderConnectionsFrame]: ProviderConnectionsSettings.tsx page
//   chrome (header, description, error, loading, empty, list frame).
// The app supplies data and callbacks; every class list is resolved here.
import 'package:flutter/material.dart';

import 'banner.dart';
import 'components.dart' show RaftButton;
import 'design_primitives.dart' show RaftSpinner, RaftTypography;
import 'feedback_inbox.dart' show RaftDashedBorderPainter, RaftUiSkeleton;
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'settings_layout.dart';
import 'switch.dart';
import 'theme.dart';

@immutable
class RaftServerLab {
  const RaftServerLab({
    required this.key,
    required this.name,
    required this.description,
    required this.checked,
    required this.editable,
    this.disabledReason = '',
    this.onChanged,
  });
  final String key, name, description;

  /// `masterEnabled && lab.enrolled`.
  final bool checked;

  /// `isServerLabEnrollmentEditable` (else the row is `opacity-60`).
  final bool editable;

  /// `getServerLabEnrollmentDisabledReasonMessageId` copy, '' when none.
  final String disabledReason;
  final ValueChanged<bool>? onChanged;
}

enum RaftServerLabsStatus { loading, unavailable, ready, failed }

/// LabsSection: `SectionHeader` (FlaskConical, Labs, lab count) over the
/// settings card holding the master "Server Labs access" switch row
/// (`border-b-2 pb-4`, owner-only note) and the `divide-y-2` lab rows
/// (`grid-cols-[minmax(0,1fr)_44px] gap-4 py-3`), or the loading skeletons,
/// the unavailable notice, or the warning banner.
class RaftServerLabsSection extends StatelessWidget {
  const RaftServerLabsSection({
    super.key,
    required this.status,
    this.masterEnabled = false,
    this.canSetMaster = false,
    this.onMasterChanged,
    this.labs = const [],
    this.error,
    this.busy = false,
  });
  final RaftServerLabsStatus status;
  final bool masterEnabled, canSetMaster, busy;
  final ValueChanged<bool>? onMasterChanged;
  final List<RaftServerLab> labs;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    // `divide-black/10` (both themes) / `border-line-muted
    // theme-brutal:border-black`.
    final divider = Colors.black.withValues(alpha: .1);
    final masterLine = t.brutal ? Colors.black : t.colors['line-muted']!;
    final note = RaftTypography.mono(
      t,
      size: 12,
      line: 16,
      color: t.brutal ? Colors.black.withValues(alpha: .45) : t.muted,
    );
    final description = RaftTypography.body(
      t,
      size: 12,
      line: 20,
      color: text.muted,
    );
    Widget warning(String message) => RaftBanner(
      status: RaftBannerRecipeStatus.warning,
      size: RaftBannerRecipeSize.sm,
      description: message,
      descriptionWeight: FontWeight.w700,
    );
    final body = switch (status) {
      RaftServerLabsStatus.loading => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftUiSkeleton(height: 40),
          SizedBox(height: 12),
          RaftUiSkeleton(height: 64),
          SizedBox(height: 12),
          RaftUiSkeleton(height: 64),
        ],
      ),
      RaftServerLabsStatus.unavailable => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: RaftIcon(
              RaftGlyph.alertTriangle,
              size: 16,
              color: t.brutal ? Colors.black.withValues(alpha: .5) : t.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  raftText(context, 'Labs settings unavailable'),
                  style: text.title,
                ),
                const SizedBox(height: 4),
                Text(
                  raftText(
                    context,
                    'This server does not expose the authoritative Labs settings API yet.',
                  ),
                  style: description,
                ),
              ],
            ),
          ),
        ],
      ),
      RaftServerLabsStatus.failed => warning(
        error ?? raftText(context, 'Failed to load Labs settings.'),
      ),
      RaftServerLabsStatus.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: masterLine, width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        raftText(context, 'Server Labs access'),
                        style: text.title,
                      ),
                      if (!canSetMaster) ...[
                        const SizedBox(height: 4),
                        Text(
                          raftText(
                            context,
                            'Only server owners can change the master gate.',
                          ),
                          style: note,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RaftSwitch(
                    key: const ValueKey('server-labs-master'),
                    value: masterEnabled,
                    size: RaftSwitchSize.md,
                    enabled: canSetMaster && !busy,
                    semanticLabel: raftText(context, 'Server Labs access'),
                    onChanged: onMasterChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (labs.isEmpty)
            Text(
              raftText(context, 'No Labs are available for this server.'),
              style: description.copyWith(
                fontStyle: FontStyle.italic,
                height: 16 / 12,
                color: t.brutal ? Colors.black.withValues(alpha: .4) : null,
              ),
            )
          else
            for (final (i, lab) in labs.indexed)
              Container(
                key: ValueKey('server-lab-${lab.key}'),
                padding: EdgeInsets.only(
                  top: i == 0 ? 0 : 12,
                  bottom: i == labs.length - 1 ? 0 : 12,
                ),
                decoration: i == 0
                    ? null
                    : BoxDecoration(
                        border: Border(
                          top: BorderSide(color: divider, width: 2),
                        ),
                      ),
                child: Opacity(
                  opacity: lab.editable ? 1 : .6,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lab.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.title,
                            ),
                            const SizedBox(height: 4),
                            Text(lab.description, style: description),
                            if (lab.disabledReason.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                raftText(context, lab.disabledReason),
                                style: note,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 44,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: RaftSwitch(
                              value: lab.checked,
                              size: RaftSwitchSize.md,
                              enabled: lab.editable && !busy,
                              semanticLabel: '${lab.name} enrollment',
                              onChanged: lab.onChanged,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (error != null) ...[const SizedBox(height: 16), warning(error!)],
        ],
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSettingsSectionHeader(
            label: 'Labs',
            glyph: RaftGlyph.flaskConical,
            count: status == RaftServerLabsStatus.ready ? labs.length : null,
          ),
          RaftSettingsCard(child: body),
        ],
      ),
    );
  }
}

/// ProviderConnectionsSettings: `mx-auto max-w-3xl space-y-4` — the
/// SectionHeader (KeyRound, Provider connections) with the `sm` Add
/// connection button, the muted description, the load/action error strip,
/// then the spinner, the dashed empty box, or the bordered list of [rows].
class RaftProviderConnectionsFrame extends StatelessWidget {
  const RaftProviderConnectionsFrame({
    super.key,
    required this.rows,
    this.loading = false,
    this.error,
    this.onAdd,
    this.canAdd = true,
  });
  final List<Widget> rows;
  final bool loading;
  final String? error;

  /// Null hides the button (no `manageExternalAuth`).
  final VoidCallback? onAdd;

  /// `disabled={providerOptions.length === 0}`.
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final muted = t.brutal ? Colors.black.withValues(alpha: .6) : t.muted;
    final edge = t.brutal ? Colors.black : t.colors['line-muted']!;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 768),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftSettingsSectionHeader(
              label: 'Provider connections',
              glyph: RaftGlyph.keyRound,
              bottom: 0,
              action: onAdd == null
                  ? null
                  : RaftButton(
                      key: const ValueKey('provider-connections-add'),
                      label: 'Add connection',
                      glyph: RaftGlyph.plus,
                      tone: RaftButtonRecipeVariant.default_,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: canAdd ? onAdd : null,
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              raftText(
                context,
                'Store a provider credential once, then reuse the connection when creating or editing Agents. Credentials are encrypted and never shown again.',
              ),
              style: text.bodyMuted.copyWith(color: muted),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  // `bg-red-50 text-red-800` (Tailwind palette).
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: edge, width: 2),
                ),
                child: Text(
                  error!,
                  style: RaftTypography.body(
                    t,
                    size: 14,
                    line: 20,
                    weight: FontWeight.w500,
                    color: const Color(0xFF9F0712),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (loading)
              const SizedBox(height: 128, child: Center(child: RaftSpinner()))
            else if (rows.isEmpty)
              CustomPaint(
                // `border-2 border-dashed border-line-muted
                // theme-brutal:border-black/25`.
                foregroundPainter: RaftDashedBorderPainter(
                  t.brutal
                      ? Colors.black.withValues(alpha: .25)
                      : t.colors['line-muted']!,
                  2,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    // The 2px border sits outside `px-5 py-10`.
                    horizontal: 22,
                    vertical: 42,
                  ),
                  child: Text(
                    raftText(context, 'No provider connections yet.'),
                    textAlign: TextAlign.center,
                    style: text.bodyMuted.copyWith(
                      color: t.brutal
                          ? Colors.black.withValues(alpha: .55)
                          : t.muted,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: t.brutal ? Colors.white : t.panel,
                  border: Border.all(color: edge, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, row) in rows.indexed) ...[
                      if (i > 0) Container(height: 2, color: edge),
                      row,
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
