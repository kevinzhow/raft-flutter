import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/managed_mcp_apps.dart';
import '../data/cause_notice.dart';
import 'mcp_app_facts.dart';

class McpServerDraft {
  final endpoint = TextEditingController();
  final headers = <TextEditingController>[];
  McpJson? probe;
  late final _notice = CauseNotice(scope: () => _revision);
  String? get probeFailure => _notice.message;
  set probeFailure(String? message) => _notice.raise(message);
  bool probing = false, useWithoutSignIn = false;
  int _revision = 0;

  List<String> get headerNames => [
    for (final field in headers)
      if (field.text.trim().isNotEmpty) field.text.trim(),
  ];

  void reset(ManagedMcpApp? app) {
    endpoint.text = app?.endpoint ?? '';
    invalidateProbe();
    setHeaders(app?.headerNames ?? []);
  }

  void setHeaders(List<String> names) {
    for (final field in headers) {
      field.dispose();
    }
    headers
      ..clear()
      ..addAll(names.map((name) => TextEditingController(text: name)));
  }

  void invalidateProbe() {
    _revision++;
    probe = null;
    probeFailure = null;
    probing = false;
    useWithoutSignIn = false;
  }

  Future<void> validate(Future<McpJson> Function(String) probeEndpoint) async {
    invalidateProbe();
    final revision = _revision;
    probing = true;
    try {
      final result = await probeEndpoint(endpoint.text.trim());
      if (revision != _revision) return;
      probe = result;
      if (result['outcome'] == 'headers') {
        final names = (result['suggestedHeaderNames'] as List? ?? [])
            .whereType<String>()
            .toList();
        setHeaders(names.isEmpty ? ['Authorization'] : names);
      }
    } catch (error) {
      if (revision == _revision) probeFailure = mcpAppError(error);
    } finally {
      if (revision == _revision) probing = false;
    }
  }

  McpJson saveFields(ManagedMcpApp? app) {
    final names = headerNames;
    if (app != null) {
      if (app.maintained) return {};
      final headersChanged =
          app.auth == McpAuthKind.headers &&
          _normalized(names) != _normalized(app.headerNames);
      if (headersChanged && names.isEmpty) throw _headerNamesRequired;
      return {
        if (endpoint.text.trim() != app.endpoint)
          'endpointUrl': endpoint.text.trim(),
        if (headersChanged) 'requiredHeaderNames': names,
      };
    }
    final tested = probe;
    final outcome = tested?['outcome'];
    if (tested == null || !['ready', 'headers', 'oauth'].contains(outcome)) {
      throw const RaftUserError('Validate the server URL first.');
    }
    final auth = useWithoutSignIn
        ? McpAuthKind.none
        : McpAuthKind.parse(outcome);
    if (auth == McpAuthKind.headers && names.isEmpty) {
      throw _headerNamesRequired;
    }
    return {
      'source': {'kind': 'url', 'endpointUrl': tested['endpointUrl']},
      'authKind': auth.name,
      if (auth == McpAuthKind.headers) 'requiredHeaderNames': names,
    };
  }

  String _normalized(List<String> names) =>
      (names.map((name) => name.toLowerCase()).toList()..sort()).join('\n');

  void dispose() {
    invalidateProbe();
    endpoint.dispose();
    setHeaders([]);
  }
}

const _headerNamesRequired = RaftUserError(
  'Name at least one required header.',
);

class McpAppServerSection extends StatefulWidget {
  const McpAppServerSection({
    super.key,
    required this.draft,
    required this.app,
    required this.isNew,
    required this.canEdit,
    required this.busy,
    required this.onChanged,
    required this.onProbe,
    required this.onRefresh,
    required this.onBrowse,
  });

  final McpServerDraft draft;
  final ManagedMcpApp? app;

  /// Add App: the section offers the create form. Editing an App whose read
  /// failed shows nothing, as `appId ? null : <McpAppServerCreate />` does.
  final bool isNew;
  final bool canEdit, busy;
  final VoidCallback onChanged, onRefresh, onBrowse;
  final Future<McpJson> Function(String) onProbe;

  @override
  State<McpAppServerSection> createState() => _McpAppServerSectionState();
}

class _McpAppServerSectionState extends State<McpAppServerSection> {
  Future<void> validate() async {
    final pending = widget.draft.validate(widget.onProbe);
    widget.onChanged();
    await pending;
    if (mounted) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final draft = widget.draft;
    final probe = draft.probe;
    final endpointEditable =
        widget.canEdit && app?.maintained != true && !widget.busy;
    if (app == null && !widget.isNew) return const SizedBox.shrink();
    return RaftAppEditorStack(
      gap: app == null ? RaftSpace.x4 : RaftSpace.x3,
      children: [
        if (app == null)
          Align(
            alignment: Alignment.centerLeft,
            child: RaftTextLink(
              label: raftText(context, 'Browse marketplace'),
              variant: RaftTextLinkVariant.strong,
              scale: RaftTypeScale.footnote,
              onPressed: widget.onBrowse,
            ),
          ),
        _endpoint(endpointEditable),
        if (app != null && draft.endpoint.text.trim() != app.endpoint)
          const RaftAppEditorFootnote(
            'Changing the server URL signs out every connection; connections on another host also need their keys again.',
          ),
        if (draft.probeFailure case final error?) RaftConnectedAppsError(error),
        if (probe != null) _probeResult(probe),
        if (probe != null && probe['outcome'] != 'unreachable')
          ?_probeFacts(probe),
        if (probe?['outcome'] == 'oauth' && probe?['tools'] != null)
          RaftCheckboxRow(
            title: raftText(context, 'Use without signing in anyway'),
            value: draft.useWithoutSignIn,
            onChanged: (value) =>
                setState(() => draft.useWithoutSignIn = value == true),
          ),
        if (app?.auth == McpAuthKind.headers || probe?['outcome'] == 'headers')
          _headers(endpointEditable),
        if (app != null)
          McpAppFacts(
            app: app,
            canEdit: widget.canEdit,
            busy: widget.busy,
            onRefresh: widget.onRefresh,
          ),
      ],
    );
  }

  Widget _endpoint(bool editable) {
    final draft = widget.draft;
    final input = RaftRecipeInput(
      fieldKey: const ValueKey('mcp-app-endpoint'),
      controller: draft.endpoint,
      enabled: editable,
      mono: true,
      placeholder: 'https://mcp.example.com/mcp',
      onChanged: (_) {
        draft.invalidateProbe();
        widget.onChanged();
      },
      onSubmitted: widget.app == null && editable ? (_) => validate() : null,
    );
    final button = RaftButton(
      label: draft.probing ? 'Validating…' : 'Validate',
      busy: draft.probing,
      onPressed:
          editable && !draft.probing && draft.endpoint.text.trim().isNotEmpty
          ? validate
          : null,
    );
    return RaftAppEditorField(
      label: 'Server URL',
      required: widget.app == null,
      compact: true,
      child: widget.app != null
          ? input
          : raftBreakpointWidth(context) < 640
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: RaftSpace.x2,
              children: [input, button],
            )
          : Row(
              spacing: RaftSpace.x2,
              children: [
                Expanded(child: input),
                button,
              ],
            ),
    );
  }

  Widget _headers(bool editable) {
    final headers = widget.draft.headers;
    return RaftAppEditorStack(
      gap: RaftSpace.x2,
      children: [
        Text(
          raftText(context, 'Required headers'),
          style: RaftTokens.of(context)
              .scale(RaftTypeScale.footnote, weight: FontWeight.w700),
        ),
        const RaftAppEditorFootnote(
          'Names only. Every connection must provide exactly these headers; values are entered per connection and never shown again.',
        ),
        for (final (index, field) in headers.indexed)
          Row(
            key: ObjectKey(field),
            spacing: RaftSpace.x2,
            children: [
              Expanded(
                child: Semantics(
                  label: raftFormat(context, 'Header name {index}', {
                    'index': index + 1,
                  }),
                  child: RaftRecipeInput(
                    controller: field,
                    enabled: editable,
                    mono: true,
                    placeholder: 'Authorization',
                  ),
                ),
              ),
              if (editable && headers.length > 1)
                RaftButton(
                  glyph: RaftGlyph.trash2,
                  tooltip: raftFormat(context, 'Remove header {name}', {
                    'name': field.text,
                  }),
                  uiVariant: RaftButtonVariant.danger,
                  uiSize: RaftButtonSize.iconMd,
                  onPressed: () =>
                      setState(() => headers.removeAt(index).dispose()),
                ),
            ],
          ),
        if (editable && headers.length < 16)
          Align(
            alignment: Alignment.centerLeft,
            child: RaftButton(
              uiVariant: RaftButtonVariant.standard,
              glyph: RaftGlyph.plus,
              label: 'Add header',
              onPressed: () =>
                  setState(() => headers.add(TextEditingController())),
            ),
          ),
      ],
    );
  }

  /// McpProbeResultPanel.tsx: `Server: {name}` and `{ms} ms` under the
  /// outcome banner, as one muted caption row.
  Widget? _probeFacts(McpJson probe) {
    final t = RaftTokens.of(context);
    final info = mcpObject(probe['serverInfo']);
    final name = [
      ?info['name'] as String?,
      ?info['version'] as String?,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    final parts = [
      if (name.isNotEmpty)
        raftFormat(context, 'Server: {name}', {'name': name}),
      if (probe['latencyMs'] case final num ms)
        raftFormat(context, '{ms} ms', {'ms': ms}),
    ];
    if (parts.isEmpty) return null;
    return Wrap(
      spacing: RaftSpace.x3,
      runSpacing: RaftSpace.x1,
      children: [
        for (final part in parts)
          Text(
            part,
            style: t.scale(RaftTypeScale.caption, color: t.ui.foregroundMuted),
          ),
      ],
    );
  }

  Widget _probeResult(McpJson probe) {
    final tools = mcpObject(probe['tools']);
    final oauth = mcpObject(probe['oauth']);
    final (title, description) = switch (probe['outcome']) {
      'ready' => (
        raftFormat(
          context,
          (tools['count'] as num? ?? 0).toInt() == 1
              ? 'Ready · {count} tool'
              : 'Ready · {count} tools',
          {'count': tools['count'] ?? 0},
        ),
        'This server works without signing in. Its tools are available as soon as the App is added.',
      ),
      'headers' => (
        'Requires an API key',
        'Each connection supplies their values.',
      ),
      'oauth' => (
        'Requires sign-in (OAuth)',
        switch (oauth['registration']) {
          'dcr' => 'Raft registers itself with the server automatically (dynamic client registration). Sign in from Connections after you add the App.',
          'cimd' => 'Raft identifies itself with a client metadata document. Sign in from Connections after you add the App.',
          _ => 'This server needs a registered OAuth client. Add its Client ID and secret when signing in to a Connection.',
        },
      ),
      _ => (
        "Couldn't reach this server",
        'Check the URL and that the server is online, then validate again.',
      ),
    };
    return RaftBanner(
      title: raftText(context, title),
      description: raftText(context, description),
      status: probe['outcome'] == 'ready'
          ? RaftBannerRecipeStatus.success
          : RaftBannerRecipeStatus.info,
      size: RaftBannerRecipeSize.sm,
    );
  }
}

/// McpAppAgentsSection.tsx: how this App's Agents use it, as three read-only
/// option cards (`grid sm:grid-cols-3`) with the count above its label, then
/// the default hint, any warnings, and where these are changed.
class McpAppAgentSummary extends StatelessWidget {
  const McpAppAgentSummary(this.summary, {super.key, required this.auth});

  final McpJson summary;
  final McpAuthKind auth;

  int _count(String key) => (summary[key] as num? ?? 0).toInt();

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final noConnection = _count('noConnection');
    final actionNeeded = _count('actionNeeded');
    Widget warning(String text) => Text(
      text,
      style: t.scale(
        RaftTypeScale.caption,
        weight: FontWeight.w700,
        color: t.colors['warning'] ?? t.ui.foregroundMuted,
      ),
    );
    Widget caption(String text) => Text(
      raftText(context, text),
      style: t.scale(RaftTypeScale.caption, color: t.ui.foregroundMuted),
    );
    final cells = [
      (
        _count('usingDefault'),
        'Agent follows the server default',
        'Agents follow the server default',
      ),
      (
        _count('pinned'),
        'Agent is pinned to a connection',
        'Agents are pinned to a connection',
      ),
      (
        _count('off'),
        "Agent doesn't have this App (not granted or revoked)",
        "Agents don't have this App (not granted or revoked)",
      ),
    ];
    final wide = raftBreakpointWidth(context) >= 640;
    final cards = [
      for (final (count, one, other) in cells)
        RaftCard(
          variant: RaftCardRecipeVariant.option,
          child: RaftCardSectionHeader(
            title: RaftCardTitle(
              Text(
                '$count',
                style: t.scale(
                  RaftTypeScale.headline,
                  weight: FontWeight.w900,
                  mono: true,
                ),
              ),
            ),
            description: RaftCardDescription(
              Text(raftText(context, count == 1 ? one : other)),
            ),
          ),
        ),
    ];
    return RaftAppEditorStack(
      gap: RaftSpace.x3,
      children: [
        if (wide)
          // `grid sm:grid-cols-3`: equal columns of equal height.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: RaftSpace.x2,
              children: [for (final card in cards) Expanded(child: card)],
            ),
          )
        else
          RaftAppEditorStack(gap: RaftSpace.x2, children: cards),
        if (auth != McpAuthKind.none)
          caption(
            'Agents following the server default move with it. Specific connections and agents with App access turned off stay unchanged.',
          ),
        if (noConnection > 0)
          warning(
            raftFormat(
              context,
              noConnection == 1
                  ? "{count} Agent has no connection selected (its connection was deleted or can't be used). Choose one on that Agent."
                  : "{count} Agents have no connection selected (their connection was deleted or can't be used). Choose one on each Agent.",
              {'count': noConnection},
            ),
          ),
        if (actionNeeded > 0)
          warning(
            raftFormat(
              context,
              actionNeeded == 1
                  ? '{count} Agent is waiting for someone to connect this App.'
                  : '{count} Agents are waiting for someone to connect this App.',
              {'count': actionNeeded},
            ),
          ),
        caption("Change these on each Agent's Apps tab."),
      ],
    );
  }
}
