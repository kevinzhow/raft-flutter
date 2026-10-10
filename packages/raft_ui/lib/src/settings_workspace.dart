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
import 'list_items.dart' show RaftSectionEyebrow, RaftSurfaceListItem;
import 'settings_controls.dart' show RaftSettingsRecipeButton;
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

/// IMBridgesSection: the bordered intro card (`SectionEyebrow` Messaging,
/// `text-lg font-black` title, `text-xs leading-relaxed text-black/60`
/// description; Brutal `border-2 border-black bg-brutal-cream`) over the
/// provider body ([child]), `space-y-4`. [failed] renders the Raft for Slack
/// warning banner (`density="lg" withIcon`) instead.
class RaftMessagingBridgesSection extends StatelessWidget {
  const RaftMessagingBridgesSection({
    super.key,
    this.child,
    this.failed = false,
  });
  final Widget? child;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final copy = Colors.black.withValues(alpha: .6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('im-bridges-header'),
          padding: const EdgeInsets.all(16),
          decoration: RaftSettingsCard.decoration(t)
              .copyWith(color: t.brutal ? t.product.brutalCream : null),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RaftSectionEyebrow(raftText(context, 'Messaging')),
              const SizedBox(height: 4),
              Text(
                raftText(context, 'Messaging bridges'),
                style: RaftTypography.body(
                  t,
                  size: 18,
                  line: 28,
                  weight: RaftTypography.black(t),
                  color: RaftSettingsText(t).strong,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 672),
                child: Text(
                  raftText(
                    context,
                    'Manage connections between Raft and external messaging services.',
                  ),
                  style: RaftTypography.body(
                    t,
                    size: 12,
                    line: 12 * 1.625,
                    color: copy,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (failed)
          RaftBanner(
            status: RaftBannerRecipeStatus.warning,
            size: RaftBannerRecipeSize.lg,
            glyph: RaftGlyph.circleAlert,
            title: 'Raft for Slack',
            description: 'The Slack bridge operation failed. No setup state was assumed.',
          )
        else
          ?child,
      ],
    );
  }
}

/// One icon action on an MCP server row (`Button size="icon-sm"`).
@immutable
class RaftMcpAction {
  const RaftMcpAction({
    required this.glyph,
    required this.tooltip,
    this.variant = RaftButtonRecipeVariant.default_,
    this.onPressed,
  });
  final RaftGlyph glyph;
  final String tooltip;
  final RaftButtonRecipeVariant variant;

  /// Null renders the disabled button.
  final VoidCallback? onPressed;
}

@immutable
class RaftMcpTool {
  const RaftMcpTool(this.label, [this.description]);
  final String label;
  final String? description;
}

@immutable
class RaftMcpServerRow {
  const RaftMcpServerRow({
    required this.id,
    required this.name,
    required this.provider,
    required this.endpointUrl,
    this.enabled = true,
    this.authMode = 'none',
    this.oauthStatus,
    this.hasCredentials = false,
    this.description,
    this.lastCheckError,
    this.tools = const [],
    this.actions = const [],
  });
  final String id, name, provider, endpointUrl, authMode;
  final bool enabled, hasCredentials;
  final String? oauthStatus, description, lastCheckError;
  final List<RaftMcpTool> tools;
  final List<RaftMcpAction> actions;
}

@immutable
class RaftMcpRecommendation {
  const RaftMcpRecommendation({
    required this.id,
    required this.name,
    required this.description,
    this.added = false,
    this.onAdd,
  });
  final String id, name, description;
  final bool added;
  final VoidCallback? onAdd;
}

/// AgentMcpTab (scope="server"): `space-y-6` of the warning banner, the
/// "MCP servers" section (SectionHeader with count and the outline `sm` Add
/// server button, description, loading line, server cards or the Blocks
/// EmptyState) and the Recommended section.
class RaftMcpServersSection extends StatefulWidget {
  const RaftMcpServersSection({
    super.key,
    required this.servers,
    this.recommendations = const [],
    this.loading = false,
    this.error,
    this.onAddServer,
  });
  final List<RaftMcpServerRow> servers;
  final List<RaftMcpRecommendation> recommendations;
  final bool loading;
  final String? error;

  /// Null hides Add server (no manageIntegrations).
  final VoidCallback? onAddServer;

  @override
  State<RaftMcpServersSection> createState() => _RaftMcpServersSectionState();
}

class _RaftMcpServersSectionState extends State<RaftMcpServersSection> {
  final expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final description = RaftTypography.body(
      t,
      size: 12,
      line: 16,
      color: text.muted,
    );
    Widget header(String label, int count, {Widget? action, String? detail}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftSettingsSectionHeader(
              label: label,
              count: count,
              bottom: 0,
              action: action,
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(raftText(context, detail), style: description),
            ],
          ],
        );
    Widget addButton({bool primary = false}) => RaftButton(
      key: ValueKey(primary ? 'mcp-empty-add' : 'mcp-add-server'),
      label: 'Add server',
      glyph: RaftGlyph.plus,
      tone: primary
          ? RaftButtonRecipeVariant.default_
          : RaftButtonRecipeVariant.outline,
      size: primary ? RaftButtonRecipeSize.md : RaftButtonRecipeSize.sm,
      onPressed: widget.onAddServer,
    );
    final children = <Widget>[
      if (widget.error != null)
        RaftBanner(
          status: RaftBannerRecipeStatus.warning,
          size: RaftBannerRecipeSize.sm,
          description: widget.error!,
          descriptionWeight: FontWeight.w700,
        ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(
            'MCP servers',
            widget.servers.length,
            action: widget.onAddServer == null ? null : addButton(),
            detail: 'Configure the MCP catalog, credentials, and provider connections for this Raft Server.',
          ),
          const SizedBox(height: 12),
          if (widget.loading)
            Text(
              raftText(context, 'Loading MCP servers…'),
              style: RaftTypography.mono(
                t,
                size: 12,
                line: 16,
                color: t.brutal
                    ? Colors.black.withValues(alpha: .4)
                    : t.colors['foreground-placeholder'],
              ),
            )
          else if (widget.servers.isEmpty)
            _McpEmptyState(
              action: widget.onAddServer == null
                  ? null
                  : addButton(primary: true),
            )
          else
            for (final (i, server) in widget.servers.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              _McpServerCard(
                key: ValueKey('mcp-server-${server.id}'),
                server: server,
                toolsOpen: expanded.contains(server.id),
                onToggleTools: () => setState(() {
                  if (!expanded.remove(server.id)) expanded.add(server.id);
                }),
              ),
            ],
        ],
      ),
      if (widget.recommendations.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(
              'Recommended',
              widget.recommendations.length,
              detail: 'Common MCP servers with connection details prefilled.',
            ),
            const SizedBox(height: 12),
            for (final (i, r) in widget.recommendations.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              RaftSurfaceListItem(
                key: ValueKey('mcp-recommendation-${r.id}'),
                interactive: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name, style: text.title),
                          const SizedBox(height: 4),
                          Text(r.description, style: text.bodyMuted),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    RaftButton(
                      label: r.added ? 'Added' : 'Add',
                      glyph: r.added ? RaftGlyph.check : RaftGlyph.plus,
                      tone: RaftButtonRecipeVariant.outline,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: r.added ? null : r.onAdd,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 24),
          child,
        ],
      ],
    );
  }
}

class _McpServerCard extends StatelessWidget {
  const _McpServerCard({
    super.key,
    required this.server,
    required this.toolsOpen,
    required this.onToggleTools,
  });
  final RaftMcpServerRow server;
  final bool toolsOpen;
  final VoidCallback onToggleTools;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final line = t.brutal ? Colors.black : t.colors['line-muted']!;
    // `border px-1.5 py-0.5 text-[10px] font-bold uppercase`.
    Widget badge(String label, Color fill, {Color? color}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: line),
      ),
      child: Text(
        label.toUpperCase(),
        style: RaftTypography.body(
          t,
          size: 10,
          line: 15,
          weight: FontWeight.w700,
          color: color ?? text.strong,
        ),
      ),
    );
    final oauth = server.oauthStatus ?? 'disconnected';
    final (oauthFill, oauthInk) = switch (oauth) {
      'connected' =>
        t.brutal
            ? (t.product.brutalLime, Colors.black)
            : (t.colors['success-soft']!, t.colors['success-strong']!),
      'error' =>
        t.brutal
            ? (t.product.brutalRed.withValues(alpha: .3), Colors.black)
            : (t.colors['danger-soft']!, t.colors['danger-strong']!),
      _ =>
        t.brutal
            ? (t.product.brutalLavender.withValues(alpha: .4), Colors.black)
            : (t.colors['accent-soft']!, t.colors['accent-strong']!),
    };
    final muted = RaftTypography.body(
      t,
      size: 14,
      line: 20,
      color: t.brutal ? Colors.black.withValues(alpha: .7) : t.muted,
    );
    final placeholder = t.brutal
        ? Colors.black.withValues(alpha: .5)
        : t.colors['foreground-placeholder']!;
    return RaftSurfaceListItem(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(server.name, style: text.title),
                        if (!server.enabled)
                          badge(
                            raftText(context, 'Disabled'),
                            t.brutal
                                ? const Color(0xFFE5E7EB)
                                : t.colors['fill-muted']!,
                          ),
                        badge(server.provider, text.panel),
                        if (server.authMode == 'oauth')
                          badge('OAuth $oauth', oauthFill, color: oauthInk)
                        else if (server.hasCredentials)
                          badge(
                            raftText(context, 'Credentials stored'),
                            t.brutal
                                ? t.product.brutalLavender.withValues(alpha: .4)
                                : t.colors['accent-soft']!,
                            color: t.brutal
                                ? Colors.black
                                : t.colors['accent-strong'],
                          ),
                      ],
                    ),
                    if (server.description != null &&
                        server.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(server.description!, style: muted),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      server.endpointUrl,
                      style: RaftTypography.mono(
                        t,
                        size: 12,
                        line: 16,
                        color: placeholder,
                      ),
                    ),
                    if (server.lastCheckError != null) ...[
                      const SizedBox(height: 12),
                      RaftBanner(
                        status: RaftBannerRecipeStatus.warning,
                        size: RaftBannerRecipeSize.sm,
                        description: server.lastCheckError!,
                        descriptionWeight: FontWeight.w700,
                      ),
                    ],
                  ],
                ),
              ),
              if (server.actions.isNotEmpty) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    for (final action in server.actions)
                      Tooltip(
                        message: raftText(context, action.tooltip),
                        child: Semantics(
                          label: raftText(context, action.tooltip),
                          child: RaftSettingsRecipeButton(
                            label: '',
                            glyph: action.glyph,
                            glyphSize: 14,
                            variant: action.variant,
                            size: RaftButtonRecipeSize.iconSm,
                            onPressed: action.onPressed,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              key: ValueKey('mcp-tools-toggle-${server.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onToggleTools,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  RaftIcon(
                    toolsOpen ? RaftGlyph.chevronUp : RaftGlyph.chevronDown,
                    size: 13,
                    color: text.muted,
                  ),
                  Text(
                    '${server.tools.length} ${server.tools.length == 1 ? 'tool' : 'tools'}',
                    style: RaftTypography.body(
                      t,
                      size: 12,
                      line: 16,
                      weight: FontWeight.w700,
                      color: t.brutal
                          ? Colors.black.withValues(alpha: .7)
                          : t.muted,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
          ),
          if (toolsOpen) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: t.colors['fill-muted']!.withValues(alpha: .4),
                border: Border.symmetric(
                  horizontal: BorderSide(color: t.colors['line-muted']!),
                ),
              ),
              child: server.tools.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      child: Text(
                        raftText(
                          context,
                          'Test this server to discover tools.',
                        ),
                        style: text.description,
                      ),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        children: [
                          for (final tool in server.tools)
                            FractionallySizedBox(
                              widthFactor: .5,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 64,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: t.colors['line-muted']!,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tool.label,
                                      style: RaftTypography.body(
                                        t,
                                        size: 14,
                                        line: 20,
                                        weight: FontWeight.w700,
                                        color: text.strong,
                                      ),
                                    ),
                                    if (tool.description != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        tool.description!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.description,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// raft-ui EmptyState with the Blocks icon (36px; elegant `size-4.5` inside
/// the `rounded-md bg-fill-muted p-2` tile), title, description and action.
class _McpEmptyState extends StatelessWidget {
  const _McpEmptyState({this.action});
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          if (t.brutal)
            RaftIcon(RaftGlyph.blocks, size: 36, color: t.muted)
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.dark
                    ? t.colors['layer-inset']
                    : t.colors['fill-muted'],
                borderRadius: BorderRadius.circular(6),
              ),
              child: RaftIcon(
                RaftGlyph.blocks,
                size: 18,
                color: t.colors['foreground-placeholder'],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            raftText(context, 'No managed MCP servers yet'),
            textAlign: TextAlign.center,
            style: t.brutal
                ? RaftTypography.heading(
                    t,
                    size: 18,
                    line: 28,
                    weight: FontWeight.w600,
                  ).copyWith(color: t.strong.withValues(alpha: .6))
                : RaftTypography.heading(
                    t,
                    size: 14,
                    line: 20,
                    weight: FontWeight.w500,
                  ).copyWith(color: t.dark ? t.muted : t.colors['foreground']),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              raftText(
                context,
                'Add a Streamable HTTP server or start from a recommended integration.',
              ),
              textAlign: TextAlign.center,
              style: text.bodyMuted.copyWith(
                height: 1.625,
                color: t.brutal ? t.strong.withValues(alpha: .6) : null,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
