// Settings > Workspace pages from the Web client (raft-source 26f77ef):
// - [RaftServerLabsSection]: SettingsPanel.tsx LabsSection (Labs tab).
// - [RaftProviderConnectionsFrame]: ProviderConnectionsSettings.tsx page
//   chrome (header, description, error, loading, empty, list frame).
// The app supplies data and callbacks; every class list is resolved here.
import 'card.dart' show RaftCard;

import 'package:flutter/material.dart';

import 'raft_underline.dart';
import 'system_inset.dart';
import 'banner.dart';
import 'components.dart' show RaftButton;
import 'design_primitives.dart' show RaftSpinner;
import 'empty_state.dart';
import 'error_presentation.dart';
import 'icons.dart';
import 'list_items.dart' show RaftSectionEyebrow;
import 'notification_settings_rows.dart' show raftSettingsRowNarrowWidth;
import 'settings_controls.dart' show RaftSettingsRecipeButton;
import 'localization.dart';
import 'recipes/badge.g.dart'
    show RaftBadgeRecipeAppearance, RaftBadgeRecipeVariant;
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'separator.dart';
import 'settings_layout.dart';
import 'raft/badge.dart';
import 'raft/switch.dart';
import 'raft/ui_tokens.dart';
import 'indicators.dart' show RaftSkeleton;
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'tooltip.dart' show RaftTooltip;

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
/// settings card holding the master "Server labs access" switch row
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
    final note = t.scale(
      RaftTypeScale.monoMeta,
      mono: true,
      color: t.ui.foregroundMuted,
    );
    final description = t.scale(
      RaftTypeScale.caption,
      weight: FontWeight.w400,
      color: t.ui.foregroundMuted,
    );
    Widget warning(String message) =>
        RaftErrorBanner(message, small: true, bold: true);
    final body = switch (status) {
      RaftServerLabsStatus.loading => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSkeleton(fromRecipe: true, width: double.infinity, height: 40),
          SizedBox(height: 12),
          RaftSkeleton(fromRecipe: true, width: double.infinity, height: 64),
          SizedBox(height: 12),
          RaftSkeleton(fromRecipe: true, width: double.infinity, height: 64),
        ],
      ),
      RaftServerLabsStatus.unavailable => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: RaftIcon(RaftGlyph.alertTriangle, size: 16, color: t.muted),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            // LabsSection.tsx:154 (v1.24): `flex min-h-8 items-center`.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          raftText(context, 'Server labs access'),
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
                  RaftSwitch(
                    key: const ValueKey('server-labs-master'),
                    value: masterEnabled,
                    size: RaftSwitchSize.md,
                    enabled: canSetMaster && !busy,
                    semanticLabel: raftText(context, 'Server labs access'),
                    onChanged: onMasterChanged,
                  ),
                ],
              ),
            ),
          ),
          const RaftSeparator(),
          const SizedBox(height: 16),
          if (labs.isEmpty)
            Text(
              raftText(context, 'No Labs available for this server'),
              // `text-footnote text-foreground-hint`.
              style: t.scale(
                RaftTypeScale.footnote,
                color: t.ui.foregroundHint,
              ),
            )
          else
            for (final (i, lab) in labs.indexed) ...[
              if (i > 0) const RaftSeparator(),
              Padding(
                key: ValueKey('server-lab-${lab.key}'),
                padding: EdgeInsets.only(
                  top: i == 0 ? 0 : 12,
                  bottom: i == labs.length - 1 ? 0 : 12,
                ),
                child: Opacity(
                  opacity: lab.editable ? 1 : .6,
                  child: Row(
                    // ServerLabRow.tsx:38 (v1.24): `items-center`.
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                        // ServerLabRow.tsx:51-63: a disabled lab carries its
                        // reason as a tooltip on the switch.
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: RaftTooltip(
                            message: raftText(context, lab.disabledReason),
                            enabled: lab.disabledReason.isNotEmpty,
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
            ],
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
          RaftCard(padding: const EdgeInsets.all(RaftSpace.x5), child: body),
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
                      label: 'Add provider connection',
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
              style: text.bodyMuted.copyWith(color: t.ui.foregroundMuted),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              RaftErrorBanner(error!, small: true, bold: true),
            ],
            const SizedBox(height: 16),
            if (loading)
              const SizedBox(height: 128, child: Center(child: RaftSpinner()))
            else if (rows.isEmpty)
              RaftEmptyState(
                glyph: RaftGlyph.keyRound,
                title: raftText(context, 'No provider connections yet'),
              )
            else
              RaftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, row) in rows.indexed) ...[
                      if (i > 0) const RaftSeparator(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x4,
      children: [
        Column(
          key: const ValueKey('im-bridges-header'),
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: RaftSpace.x1,
          children: [
            RaftSectionEyebrow(raftText(context, 'Messaging')),
            Semantics(
              header: true,
              child: Text(
                raftText(context, 'Messaging bridges'),
                style: t.scale(RaftTypeScale.headline, color: t.ink),
              ),
            ),
          ],
        ),
        if (failed)
          RaftBanner(
            status: RaftBannerRecipeStatus.warning,
            size: RaftBannerRecipeSize.lg,
            glyph: RaftGlyph.alertTriangle,
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
    this.usageCalls,
    this.usageLastUsed,
    this.usageLastTool,
  });

  /// Agent scope usage (`dl`): "42 calls", the last invocation's date and the
  /// tool name; null outside the Agent MCP usage view.
  final String? usageCalls, usageLastUsed, usageLastTool;
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
    this.scrollable = false,
    this.error,
    this.onAddServer,
    this.usage = false,
  });

  /// AgentMcpTab scope="agent": the read-only "MCP usage" view (title and
  /// copy, header loading text, usage grid per card, usage empty state).
  final bool usage;
  final List<RaftMcpServerRow> servers;
  final List<RaftMcpRecommendation> recommendations;
  final bool loading;

  /// Own a bounded settings viewport and build catalog cards on demand.
  final bool scrollable;
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
    final description = t.scale(
      RaftTypeScale.caption,
      weight: FontWeight.w400,
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
      label: 'Add MCP server',
      glyph: RaftGlyph.plus,
      tone: primary
          ? RaftButtonRecipeVariant.default_
          : RaftButtonRecipeVariant.outline,
      size: primary ? RaftButtonRecipeSize.md : RaftButtonRecipeSize.sm,
      onPressed: widget.onAddServer,
    );
    final items = <WidgetBuilder>[
      if (widget.error != null)
        (_) => RaftErrorBanner(widget.error!, small: true, bold: true),
      (_) => Padding(
        padding: EdgeInsets.only(top: widget.error == null ? 0 : 24),
        child: header(
          widget.usage ? 'MCP usage' : 'MCP servers',
          widget.servers.length,
          action: widget.usage
              ? (widget.loading
                    ? Text(
                        raftText(context, 'Loading usage…'),
                        style: t.scale(
                          RaftTypeScale.caption,
                          weight: FontWeight.w700,
                          color: t.ui.foregroundMuted,
                        ),
                      )
                    : null)
              : widget.onAddServer == null
              ? null
              : addButton(),
          detail: widget.usage
              ? 'MCP servers this agent has used. Enabled server tools are available automatically.'
              : 'Configure the MCP catalog, credentials, and provider connections for this Raft Server.',
        ),
      ),
      if (widget.loading)
        (_) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            raftText(context, 'Loading MCP servers…'),
            style: t.scale(
              RaftTypeScale.monoMeta,
              mono: true,
              color: t.ui.foregroundHint,
            ),
          ),
        )
      else if (widget.servers.isEmpty)
        (_) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _McpEmptyState(
            usage: widget.usage,
            action: widget.onAddServer == null || widget.usage
                ? null
                : addButton(primary: true),
          ),
        )
      else
        for (final server in widget.servers)
          (_) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _McpServerCard(
              key: ValueKey('mcp-server-${server.id}'),
              server: server,
              toolsOpen: expanded.contains(server.id),
              onToggleTools: () => setState(() {
                if (!expanded.remove(server.id)) expanded.add(server.id);
              }),
            ),
          ),
      if (widget.recommendations.isNotEmpty) ...[
        (_) => Padding(
          padding: const EdgeInsets.only(top: 24),
          child: header(
            'Recommended',
            widget.recommendations.length,
            detail: 'Common MCP servers with connection details prefilled.',
          ),
        ),
        for (final r in widget.recommendations)
          (_) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RaftCard.item(
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
          ),
      ],
    ];
    if (widget.scrollable) {
      return ListView.builder(
        primary: false,
        padding: raftScrollPadding(
          context,
          RaftSettingsPanelFrame.contentInset,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => items[index](context),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final build in items) build(context)],
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
    Widget badge(
      String label, {
      RaftBadgeRecipeVariant variant = RaftBadgeRecipeVariant.default_,
      RaftBadgeRecipeAppearance appearance = RaftBadgeRecipeAppearance.soft,
    }) => RaftBadge(label: label, variant: variant, appearance: appearance);
    final oauth = server.oauthStatus ?? 'disconnected';
    final oauthVariant = switch (oauth) {
      'connected' => RaftBadgeRecipeVariant.success,
      'error' => RaftBadgeRecipeVariant.danger,
      _ => RaftBadgeRecipeVariant.accent,
    };
    final muted = t.scale(RaftTypeScale.callout, color: t.ui.foregroundMuted);
    final placeholder = t.ui.foregroundHint;
    return RaftCard.item(
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
                            variant: RaftBadgeRecipeVariant.muted,
                          ),
                        badge(
                          server.provider,
                          appearance: RaftBadgeRecipeAppearance.outline,
                        ),
                        if (server.authMode == 'oauth')
                          badge('OAuth $oauth', variant: oauthVariant)
                        else if (server.hasCredentials)
                          badge(
                            raftText(context, 'Credentials stored'),
                            variant: RaftBadgeRecipeVariant.accent,
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
                      style: t.scale(
                        RaftTypeScale.monoMeta,
                        mono: true,
                        color: placeholder,
                      ),
                    ),
                    if (server.usageCalls != null) ...[
                      const SizedBox(height: 12),
                      _McpUsageGrid(server: server),
                    ],
                    if (server.lastCheckError != null) ...[
                      const SizedBox(height: 12),
                      RaftErrorBanner(
                        server.lastCheckError!,
                        small: true,
                        bold: true,
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
                      RaftTooltip(
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
                  RaftUnderlinedText(
                    '${server.tools.length} ${server.tools.length == 1 ? 'tool' : 'tools'}',
                    style: t.scale(
                      RaftTypeScale.caption,
                      weight: FontWeight.w700,
                      color: t.ui.foregroundMuted,
                    ),
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
                                      style: t.scale(
                                        RaftTypeScale.callout,
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
/// `dl mt-3 grid grid-cols-3 gap-2 text-xs`: Calls / Last used / Last tool.
class _McpUsageGrid extends StatelessWidget {
  const _McpUsageGrid({required this.server});
  final RaftMcpServerRow server;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final strong = t.scale(
      RaftTypeScale.caption,
      weight: FontWeight.w700,
      color: t.ui.foreground,
    );
    final value = t.scale(
      RaftTypeScale.caption,
      weight: FontWeight.w400,
      color: t.ui.foregroundMuted,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // `grid gap-2 sm:grid-cols-3`: one column when the panel is narrow.
        final wide = constraints.maxWidth >= raftSettingsRowNarrowWidth;
        final calls = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(raftText(context, 'Calls'), style: strong),
            Text(server.usageCalls ?? '', style: value),
          ],
        );
        final lastUsed = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(raftText(context, 'Last used'), style: strong),
            Text(server.usageLastUsed ?? '', style: value),
          ],
        );
        final lastTool = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(raftText(context, 'Last tool'), style: strong),
            Text(
              server.usageLastTool ?? '',
              style: t.scale(
                RaftTypeScale.monoMeta,
                mono: true,
                color: value.color,
              ),
            ),
          ],
        );
        final cells = wide
            ? [
                Expanded(child: calls),
                Expanded(child: lastUsed),
                Expanded(child: lastTool),
              ]
            : [calls, lastUsed, lastTool];
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: cells,
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: cells,
        );
      },
    );
  }
}

class _McpEmptyState extends StatelessWidget {
  const _McpEmptyState({this.action, this.usage = false});
  final Widget? action;
  final bool usage;

  @override
  Widget build(BuildContext context) => RaftEmptyState(
    glyph: RaftGlyph.blocks,
    title: raftText(
      context,
      usage ? 'No MCP usage yet' : 'No managed MCP servers yet',
    ),
    detail: raftText(
      context,
      usage
          ? 'Enabled MCP servers are available automatically and appear here after this agent calls one.'
          : 'Add a Streamable HTTP server or start from a recommended integration.',
    ),
    action: action,
  );
}
