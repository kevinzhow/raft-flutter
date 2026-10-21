import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/web_error.dart';
import '../data/workspace_controller.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'management_support.dart';
import 'integrations_views.dart';

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

  /// Filter chips come from the apps seen so far in the unfiltered list.
  Map<String, String> eventApps = {};
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
    _openEvents.clear();
    _payloads.clear();
    _payloadFailures.clear();
    eventApps = {};
    agent = {};
    nextCursor = null;
    filter = null;
  }

  @override
  String get snapshotKey => 'agent-apps:${widget.agentId}';
  @override
  Map<String, Object?> captureSnapshot() => {
    'access': access,
    'apps': apps,
    'events': events,
    'eventApps': eventApps,
    'agent': agent,
    'nextCursor': nextCursor,
    'filter': filter,
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    access = fields['access'] as List<Map<String, dynamic>>;
    apps = fields['apps'] as List<Map<String, dynamic>>;
    events = fields['events'] as List<Map<String, dynamic>>;
    eventApps = fields['eventApps'] as Map<String, String>;
    agent = fields['agent'] as Map<String, dynamic>;
    nextCursor = fields['nextCursor'] as String?;
    filter = fields['filter'] as String?;
    return true;
  }

  /// Web `errorText(err, fallback)`: the server's `error` text, else this
  /// action's `agent.apps.*` / `agent.detail.*` message.
  Future<void> _web(String fallback, Future<void> Function() action) =>
      withWebError(fallback, action, where: 'agent apps');

  @override
  Future<void> loadData(int request, int generation) => _web(
    'Failed to load connected apps',
    () => _loadData(request, generation),
  );

  Future<void> _loadData(int request, int generation) async {
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
      // The events are readable by every member who can inspect the agent.
      w.client.get(
        '$base/events',
        query: {'limit': '25', if (filter != null) 'clientId': filter},
      ),
    ]);
    if (!accepts(generation, request)) return;
    agent = agentData;
    access = managementRows(results[0]);
    apps = manages ? managementRows(managementMap(results[1])['apps']) : [];
    final page = managementMap(results[manages ? 2 : 1]);
    events = managementRows(page['events']);
    _seeApps(events);
    nextCursor = page['nextCursor'];
  }

  void _seeApps(List<Map<String, dynamic>> page) {
    if (filter != null) return;
    for (final event in page) {
      final app = managementMap(event['app']);
      eventApps['${app['clientId']}'] = '${app['name']}';
    }
  }

  Future<void> moreEvents() async {
    final cursor = nextCursor,
        generation = w.client.generation,
        sourceAuthority = authority;
    if (cursor == null) return;
    late final Map<String, dynamic> page;
    await _web('Failed to load app events', () async {
      page = managementMap(
        await w.client.get(
          '$base/events',
          query: {
            'limit': '25',
            'before': cursor,
            if (filter != null) 'clientId': filter,
          },
        ),
      );
    });
    if (!accepts(generation) || sourceAuthority != authority) return;
    final ids = events.map((e) => e['id']).toSet();
    events = [
      ...events,
      ...managementRows(page['events']).where((e) => ids.add(e['id'])),
    ];
    _seeApps(managementRows(page['events']));
    nextCursor = page['nextCursor'];
    setState(() {});
  }

  Future<void> grant() async {
    if (apps.isEmpty) {
      throw const RaftUserError('No apps are available on this server.');
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
      (v) => _web('Failed to grant access', () async {
        await w.client.post(
          '$base/grants',
          data: {
            'clientId': selected!['clientId'],
            'scopes': parseIntegrationScopes(v['scopes']!),
          },
        );
      }),
      submit: 'Grant access',
      description:
          'Allow this app to send the approved events or notifications to this agent.',
    );
  }

  /// Events whose payload is open under the row (Web `AppEventRow`): the
  /// payload once read, or the failure. The row toggles; a read happens once.
  final Set<String> _openEvents = {};
  final Map<String, Object?> _payloads = {};
  final Map<String, String> _payloadFailures = {};

  Future<void> toggleEvent(Map<String, dynamic> event) async {
    final id = '${event['id']}';
    if (!_openEvents.remove(id)) {
      _openEvents.add(id);
    } else {
      setState(() {});
      return;
    }
    setState(() {});
    if (_payloads.containsKey(id)) return;
    final generation = w.client.generation, sourceAuthority = authority;
    try {
      final value = await w.client.get('$base/events/$id');
      if (!accepts(generation) || sourceAuthority != authority) return;
      _payloads[id] = managementMap(value)['payload'];
    } catch (e) {
      if (!accepts(generation) || sourceAuthority != authority) return;
      _payloadFailures[id] = userErrorText(
        e,
        fallback: 'Failed to load the event',
        where: 'agent app event',
      );
    }
    if (mounted) setState(() {});
  }

  /// The payload under an open event: app-supplied data, shown as inert JSON
  /// text, never as links or markup.
  Widget _payload(BuildContext context, String id) {
    final failure = _payloadFailures[id];
    if (failure != null) return RaftErrorBanner(failure, small: true);
    final t = RaftTokens.of(context);
    return SelectableText(
      _payloads.containsKey(id)
          ? const JsonEncoder.withIndent('  ').convert(_payloads[id])
          : raftText(context, 'Loading…'),
      key: ValueKey('app-event-payload-$id'),
      style: RaftPanelText.monoCaption(t),
    );
  }

  Widget _small(
    String label,
    VoidCallback? onPressed, {
    bool selected = false,
  }) => RaftRecipeTextButton(
    label: label,
    // `<Button size="sm" variant="outline"|"default" className="text-[11px]">`.
    variant: selected ? null : RaftButtonRecipeVariant.outline,
    text: RaftButtonText.px11,
    onPressed: onPressed,
  );

  /// AgentAppAccessTab.tsx: `flex-1 overflow-y-auto bg-layer-panel px-5
  /// py-4 space-y-6 theme-brutal:bg-white` with Applications and App events
  /// sections.
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final pending = access.where((i) => i['type'] == 'pending').toList();
    final active = access.where((i) => i['type'] != 'pending').toList();
    final empty = RaftPanelText.muted(t);
    return RaftPanelGroups(
      groups: [
        if (error != null) [RaftErrorBanner(error!, small: true, bold: true)],
        if (pending.isNotEmpty)
          [
            RaftSectionHeader(
              label: raftText(context, 'Pending requests'),
              count: pending.length,
            ),
            for (final item in pending) _accessCard(context, item),
          ],
        [
          RaftDescribedSectionHeader(
            label: raftText(context, 'Applications'),
            description: raftText(
              context,
              'Connected apps this agent can use.',
            ),
            action: loading
                ? Text(
                    raftText(context, 'Loading…'),
                    style: RaftPanelText.caption(t),
                  )
                : manager
                ? _small(
                    raftText(context, 'Grant access'),
                    busy ? null : () => run(grant),
                  )
                : null,
          ),
          if (active.isEmpty)
            Text(raftText(context, 'No connected apps'), style: empty)
          else
            for (final item in active) _accessCard(context, item),
        ],
        [
            RaftDescribedSectionHeader(
              label: raftText(context, 'App events'),
              description: raftText(
                context,
                "Events apps sent to this agent. They're kept for 30 days after they expire.",
              ),
              action: _small(
                raftText(context, loading ? 'Loading…' : 'Refresh'),
                busy || loading ? null : reload,
              ),
            ),
            if (eventApps.length > 1)
              RaftButtonWrap(
                children: [
                  _small(raftText(context, 'All apps'), () {
                    setState(() => filter = null);
                    reload();
                  }, selected: filter == null),
                  for (final app in eventApps.entries)
                    _small(app.value, () {
                      setState(() => filter = app.key);
                      reload();
                    }, selected: filter == app.key),
                ],
              ),
            if (events.isEmpty && !loading)
              Text(raftText(context, 'No app events yet'), style: empty)
            else
              for (final event in events)
                RaftAccessCard(
                  title: '${event['summary']}',
                  subtitle:
                      '${managementMap(event['app'])['name']} · ${event['kind']} · ${agentTimeFormatter(context, w).shortDateTime(event['createdAt'])}',
                  badge: _eventStatus(context, '${event['status']}'),
                  details: [
                    if (_openEvents.contains('${event['id']}'))
                      _payload(context, '${event['id']}'),
                  ],
                  onTap: () => toggleEvent(event),
                ),
            if (nextCursor != null)
              Align(
                alignment: Alignment.centerLeft,
                child: _small(
                  raftText(context, 'Load more'),
                  () => run(moreEvents, refresh: false),
                ),
              ),
          ],
      ],
    );
  }

  /// The delivery word beside an event: delivered / queued / expired.
  Widget? _eventStatus(BuildContext context, String status) {
    final label = switch (status) {
      'delivered' => 'Delivered',
      'queued' => 'Queued',
      'expired' => 'Expired',
      _ => null,
    };
    if (label == null) return null;
    return RaftRecipeBadge(
      raftText(context, label),
      variant: switch (status) {
        'delivered' => RaftBadgeRecipeVariant.success,
        'queued' => RaftBadgeRecipeVariant.warning,
        _ => RaftBadgeRecipeVariant.muted,
      },
    );
  }

  Widget _accessCard(BuildContext context, Map<String, dynamic> item) {
    final pending = item['type'] == 'pending';
    final t = RaftTokens.of(context);
    final source = switch (item['grantSource']) {
      'person' => 'Granted by a person',
      'agent_login' => 'Granted when the agent signed in',
      'app_request' => 'Granted automatically to the app',
      _ => null,
    };
    final description = item['clientDescription'];
    final manifest = item['clientAgentManifestUrl'];
    final homepage = item['clientHomepageUrl'];
    return RaftAccessCard(
      title: '${item['clientName']}',
      subtitle: agentTimeFormatter(context, w).shortDateTime(item['createdAt']),
      details: [
        if (!pending && source != null)
          Text(raftText(context, source), style: RaftPanelText.caption(t)),
        if (!pending && description is String && description.isNotEmpty)
          Text(description, style: RaftPanelText.muted(t)),
        if (!pending && manifest is String && manifest.isNotEmpty)
          Text(
            raftFormat(context, 'Agent manifest: {url}', {'url': manifest}),
            style: RaftPanelText.monoCaption(t),
          ),
      ],
      badge: RaftRecipeBadge(
        raftText(context, pending ? 'Pending' : 'Active'),
        variant: pending
            ? RaftBadgeRecipeVariant.warning
            : RaftBadgeRecipeVariant.success,
        uppercase: true,
      ),
      chips: [
        for (final scope in managementStrings(item['scopes']))
          integrationScopeLabels[scope] ?? scope,
      ],
      actions: [
        if (manager && pending) ...[
          _small(
            raftText(context, 'Approve'),
            () => run(
              () => _web('Failed to approve the request', () async {
                await w.client.post(
                  '/integrations/requests/${item['id']}/approve',
                  data: {'remember': true},
                );
              }),
            ),
            selected: true,
          ),
          _small(
            raftText(context, 'Deny'),
            () => run(
              () => _web('Failed to deny the request', () async {
                await w.client.post(
                  '/integrations/requests/${item['id']}/deny',
                );
              }),
            ),
          ),
        ] else if (manager)
          _small(
            raftText(context, 'Revoke'),
            () => run(() async {
              await confirm(
                'Revoke app access?',
                'Disconnect ${item['clientName']} from this agent.',
                () => _web('Failed to revoke app access', () async {
                  await w.client.post(
                    '/integrations/grants/${item['id']}/revoke',
                  );
                }),
                submit: 'Revoke',
                destructive: true,
              );
            }),
          ),
        if (!pending && homepage is String && homepage.isNotEmpty)
          RaftRecipeTextButton(
            label: raftText(context, 'View service'),
            variant: RaftButtonRecipeVariant.link,
            onPressed: () =>
                run(() => managementLaunch(homepage), refresh: false),
          ),
      ],
    );
  }
}
