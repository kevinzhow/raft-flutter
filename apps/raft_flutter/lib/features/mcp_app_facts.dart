import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/managed_mcp_apps.dart';

class McpAppFacts extends StatefulWidget {
  const McpAppFacts({
    super.key,
    required this.app,
    required this.canEdit,
    required this.busy,
    required this.onRefresh,
  });

  final ManagedMcpApp app;
  final bool canEdit, busy;
  final VoidCallback onRefresh;

  @override
  State<McpAppFacts> createState() => _McpAppFactsState();
}

class _McpAppFactsState extends State<McpAppFacts> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final t = RaftTokens.of(context);
    final tools = mcpRows(app.server['tools']);
    final health = mcpObject(app.server['health']);
    final healthLabel = switch (health['status']) {
      'reachable' => 'Reachable',
      'unreachable' => 'Unreachable',
      _ => 'Not checked yet',
    };
    RaftDescriptionEntry entry(String label, Widget child) =>
        RaftDescriptionEntry(
          raftText(context, label),
          '',
          termChild: Text(
            raftText(context, label),
            style: t.scale(
              RaftTypeScale.footnote,
              weight: FontWeight.w700,
              color: t.ui.foregroundMuted,
            ),
          ),
          detailsChild: child,
        );
    return RaftDescriptionList(
      rowGap: RaftSpace.x3,
      entries: [
        entry('Transport', Text(raftText(context, 'Streamable HTTP'))),
        entry(
          'Sign-in',
          Wrap(
            spacing: RaftSpace.x2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RaftBadge(
                label: raftText(context, app.auth.label),
                appearance: RaftBadgeRecipeAppearance.outline,
              ),
              if (app.headerNames.isNotEmpty)
                Text(
                  app.headerNames.join(', '),
                  style: t.scale(RaftTypeScale.monoMeta, mono: true),
                ),
            ],
          ),
        ),
        entry(
          'Health',
          Wrap(
            spacing: RaftSpace.x2,
            children: [
              Text(
                raftText(context, healthLabel),
                style: t.scale(RaftTypeScale.callout, weight: FontWeight.w700),
              ),
              if (health['latencyMs'] case final num ms)
                Text(
                  raftFormat(context, '{ms} ms', {'ms': ms}),
                  style: t.scale(RaftTypeScale.callout, color: t.muted),
                ),
            ],
          ),
        ),
        entry('Tools', _tools(app, tools)),
      ],
    );
  }

  /// McpAppServerSection.tsx: the tool count and Refresh tools on one row
  /// (`justify-between`), the tool badges on the row under it
  /// (`McpAppToolList`, 8 before "Show all").
  Widget _tools(ManagedMcpApp app, List<McpJson> tools) {
    final count = (app.server['toolCount'] as num? ?? tools.length).toInt();
    final collapsible = tools.length > _toolPreviewCount;
    final shown = collapsible && !expanded
        ? tools.take(_toolPreviewCount)
        : tools;
    // The count row and the tool list are two inline spans in one `dd`, so
    // they flow on the same line while they fit.
    return Wrap(
      spacing: RaftSpace.x2,
      runSpacing: RaftSpace.x1_5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          raftFormat(context, count == 1 ? '{count} tool' : '{count} tools', {
            'count': count,
          }),
        ),
        if (widget.canEdit)
          RaftButton(
            label: 'Refresh tools',
            glyph: RaftGlyph.refreshCw,
            uiVariant: RaftButtonVariant.standard,
            onPressed: widget.busy ? null : widget.onRefresh,
          ),
        for (final tool in shown)
          RaftBadge(
            label: '${tool['title'] ?? tool['name']}',
            appearance: RaftBadgeRecipeAppearance.outline,
          ),
        if (collapsible)
          RaftButton(
            uiVariant: RaftButtonVariant.ghost,
            label: expanded
                ? 'Show fewer'
                : raftFormat(context, 'Show all {count}', {
                    'count': tools.length,
                  }),
            onPressed: () => setState(() => expanded = !expanded),
          ),
      ],
    );
  }
}

/// MCP_APP_TOOL_PREVIEW_COUNT: how many tools show before "Show all".
const _toolPreviewCount = 8;
