import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'integrations_views.dart';
import 'agent_detail_view.dart' show AgentSurfaceItem, AgentBadge;

class AgentAppAccessView extends StatefulWidget {
  const AgentAppAccessView({
    super.key,
    required this.controller,
    required this.agentId,
  });
  final WorkspaceController controller;
  final String agentId;
  @override
  State<AgentAppAccessView> createState() => _AgentAppsState();
}

class _AgentAppsState extends ManagementState<AgentAppAccessView> {
  @override
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> access = [], apps = [], events = [];
  Map<String, dynamic> agent = {};
  String? nextCursor, filter;
  bool get manager =>
      w.can('manageIntegrations') ||
      (agent['creatorType'] == 'user' &&
          agent['creatorId'] == w.client.user?.id);
  String get base => '/integrations/agents/${widget.agentId}';
  @override
  void initState() {
    super.initState();
    startManagement();
  }

  @override
  void clearData() {
    access = [];
    apps = [];
    events = [];
    agent = {};
    nextCursor = null;
    filter = null;
  }

  @override
  Future<void> loadData(int request, int generation) async {
    final agentData = managementMap(
      await w.client.get('/agents/${widget.agentId}'),
    );
    if (!accepts(generation, request)) return;
    final manages =
        w.can('manageIntegrations') ||
        (agentData['creatorType'] == 'user' &&
            agentData['creatorId'] == w.client.user?.id);
    final results = await Future.wait([
      w.client.get(base),
      if (manages) w.client.get('$base/grantable-apps'),
      if (manages)
        w.client.get(
          '$base/events',
          query: {'limit': '25', if (filter != null) 'clientId': filter},
        ),
    ]);
    if (!accepts(generation, request)) return;
    agent = agentData;
    access = managementRows(results[0]);
    apps = manages ? managementRows(managementMap(results[1])['apps']) : [];
    final page = manages ? managementMap(results[2]) : <String, dynamic>{};
    events = managementRows(page['events']);
    nextCursor = page['nextCursor'];
  }

  Future<void> moreEvents() async {
    final cursor = nextCursor,
        generation = w.client.generation,
        sourceAuthority = authority;
    if (cursor == null) return;
    final page = managementMap(
      await w.client.get(
        '$base/events',
        query: {
          'limit': '25',
          'before': cursor,
          if (filter != null) 'clientId': filter,
        },
      ),
    );
    if (!accepts(generation) || sourceAuthority != authority) return;
    final ids = events.map((e) => e['id']).toSet();
    events = [
      ...events,
      ...managementRows(page['events']).where((e) => ids.add(e['id'])),
    ];
    nextCursor = page['nextCursor'];
    setState(() {});
  }

  Future<void> grant() async {
    if (apps.isEmpty) {
      throw StateError('No apps are available to grant to this agent.');
    }
    Map<String, dynamic>? selected;
    final picked = await form(
      'Choose app',
      [
        RaftFormField(
          'clientId',
          'App',
          choices: {for (final a in apps) '${a['clientId']}': '${a['name']}'},
        ),
      ],
      (v) async {
        selected = apps.firstWhere((a) => a['clientId'] == v['clientId']);
      },
      submit: 'Review permissions',
    );
    if (!picked || selected == null) return;
    final scopes = managementStrings(selected!['scopes']);
    await form(
      'Grant ${selected!['name']} access',
      [
        RaftFormField(
          'scopes',
          'Granted permissions',
          initial: scopes.join(', '),
          help: scopes
              .map((s) => '$s: ${integrationScopeLabels[s] ?? s}')
              .join('\n'),
          required: true,
          validator: (v) =>
              parseIntegrationScopes(v).any((s) => !scopes.contains(s))
              ? 'Select permissions requested by this app.'
              : null,
        ),
      ],
      (v) async {
        await w.client.post(
          '$base/grants',
          data: {
            'clientId': selected!['clientId'],
            'scopes': parseIntegrationScopes(v['scopes']!),
          },
        );
      },
      submit: 'Grant access',
      description: 'Allow this app to send the approved events or notifications to this agent.',
    );
  }

  Future<void> eventDetail(Map<String, dynamic> event) async {
    final generation = w.client.generation;
    final detail = managementMap(
      await w.client.get('$base/events/${event['id']}'),
    );
    if (!accepts(generation)) return;
    await scopedDialog<void>(
      (context) => AlertDialog(
        title: Text('${event['summary']}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(detail['payload']),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// AgentAppAccessTab.tsx: `flex-1 overflow-y-auto bg-layer-panel px-5
  /// py-4 space-y-6 theme-brutal:bg-white` with Applications and App events
  /// sections (SectionHeader + `mt-1 text-xs text-foreground-muted` copy).
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final muted = t.colors['foreground-muted']!;
    final description = raftCssText(
      RaftTypography.body(t, size: 12, line: 16, color: muted),
    );
    final empty = raftCssText(
      RaftTypography.body(
        t,
        size: 14,
        line: 20,
        color: raftPanelInk(t, .5, muted),
      ),
    );
    final pending = access.where((i) => i['type'] == 'pending').toList();
    final active = access.where((i) => i['type'] != 'pending').toList();
    Widget group(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
    Widget header(String label, Widget? action, String copy) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSectionHeader(label: label, action: action),
        const SizedBox(height: 4),
        Text(copy, style: description),
      ],
    );
    final groups = <Widget>[
      if (error != null)
        Text(error!, style: description.copyWith(fontWeight: FontWeight.w700)),
      if (pending.isNotEmpty)
        group([
          RaftSectionHeader(
            label: raftText(context, 'Pending requests'),
            count: pending.length,
          ),
          for (final item in pending) _accessCard(context, t, item),
        ]),
      group([
        header(
          raftText(context, 'Applications'),
          loading
              ? Text(
                  raftText(context, 'Loading…'),
                  style: description.copyWith(fontWeight: FontWeight.w700),
                )
              : manager
              ? _SmallButton(
                  label: raftText(context, 'Grant access'),
                  onPressed: busy ? null : () => run(grant),
                )
              : null,
          raftText(context, 'Connected apps this agent can use.'),
        ),
        if (active.isEmpty)
          Text(raftText(context, 'No connected apps'), style: empty)
        else
          for (final item in active) _accessCard(context, t, item),
      ]),
      if (manager)
        group([
          header(
            raftText(context, 'App events'),
            _SmallButton(
              label: raftText(context, loading ? 'Loading…' : 'Refresh'),
              onPressed: busy || loading ? null : reload,
            ),
            raftText(
              context,
              "Events apps sent to this agent. They're kept for 30 days after they expire.",
            ),
          ),
          if (apps.length > 1)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SmallButton(
                  label: raftText(context, 'All apps'),
                  selected: filter == null,
                  onPressed: () {
                    setState(() => filter = null);
                    reload();
                  },
                ),
                for (final app in apps)
                  _SmallButton(
                    label: '${app['name']}',
                    selected: filter == app['clientId'],
                    onPressed: () {
                      setState(() => filter = '${app['clientId']}');
                      reload();
                    },
                  ),
              ],
            ),
          if (events.isEmpty && !loading)
            Text(raftText(context, 'No app events yet'), style: empty)
          else
            for (final event in events)
              GestureDetector(
                onTap: () => run(() => eventDetail(event), refresh: false),
                child: AgentSurfaceItem(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event['summary']}',
                        style: RaftTypography.body(
                          t,
                          size: 14,
                          line: 20,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${managementMap(event['app'])['name']} · ${event['kind']} · ${event['status']}',
                        style: description,
                      ),
                    ],
                  ),
                ),
              ),
          if (nextCursor != null)
            Align(
              alignment: Alignment.centerLeft,
              child: _SmallButton(
                label: raftText(context, 'Load more'),
                onPressed: () => run(moreEvents, refresh: false),
              ),
            ),
        ]),
    ];
    return ColoredBox(
      color: t.brutal ? Colors.white : t.colors['layer-panel']!,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) const SizedBox(height: 24),
            groups[i],
          ],
        ],
      ),
    );
  }

  Widget _accessCard(
    BuildContext context,
    RaftTokens t,
    Map<String, dynamic> item,
  ) {
    final pending = item['type'] == 'pending';
    return AgentSurfaceItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item['clientName']}',
                  style: RaftTypography.body(
                    t,
                    size: 16,
                    line: 24,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              AgentBadge(
                raftText(context, pending ? 'Pending' : 'Active'),
                variant: pending
                    ? RaftBadgeRecipeVariant.warning
                    : RaftBadgeRecipeVariant.success,
                uppercase: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final scope in managementStrings(item['scopes']))
                AgentBadge(
                  integrationScopeLabels[scope] ?? scope,
                  appearance: RaftBadgeRecipeAppearance.outline,
                ),
            ],
          ),
          if (manager) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (pending) ...[
                  _SmallButton(
                    label: raftText(context, 'Approve'),
                    selected: true,
                    onPressed: () => run(() async {
                      await w.client.post(
                        '/integrations/requests/${item['id']}/approve',
                        data: {'remember': true},
                      );
                    }),
                  ),
                  _SmallButton(
                    label: raftText(context, 'Deny'),
                    onPressed: () => run(() async {
                      await w.client.post(
                        '/integrations/requests/${item['id']}/deny',
                      );
                    }),
                  ),
                ] else
                  _SmallButton(
                    label: raftText(context, 'Revoke'),
                    onPressed: () => run(() async {
                      await confirm(
                        'Revoke app access?',
                        'Disconnect ${item['clientName']} from this agent.',
                        () async {
                          await w.client.post(
                            '/integrations/grants/${item['id']}/revoke',
                          );
                        },
                        submit: 'Revoke',
                        destructive: true,
                      );
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// `<Button variant="outline"|"default" size="sm" className="text-[11px]">`
/// resolved from the generated buttonVariants recipe.
class _SmallButton extends StatefulWidget {
  const _SmallButton({
    required this.label,
    this.onPressed,
    this.selected = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  @override
  State<_SmallButton> createState() => _SmallButtonState();
}

class _SmallButtonState extends State<_SmallButton> {
  bool hovered = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftButtonRecipe.resolve(
      theme: raftRecipeTheme(t),
      variant: widget.selected ? null : RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.sm,
      states: RaftRecipeStates({
        if (hovered) RaftRecipeStates.hover,
        if (pressed) RaftRecipeStates.active,
        if (widget.onPressed == null) RaftRecipeStates.disabled,
        if (t.dark) RaftRecipeStates.dark,
      }),
      tokens: rt,
    ).root;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          onTap: widget.onPressed,
          child: Opacity(
            opacity: s.opacity ?? 1,
            child: Transform.translate(
              offset: s.translate ?? Offset.zero,
              child: Container(
                height: s.height,
                padding: EdgeInsets.only(
                  left: s.padding.left,
                  right: s.padding.right,
                ),
                alignment: Alignment.center,
                decoration: s.decoration(rt),
                child: Text(
                  widget.label,
                  style: raftCssText(
                    RaftTypography.body(t, size: 11, line: 16).merge(
                      s.textStyle(rt).copyWith(fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
