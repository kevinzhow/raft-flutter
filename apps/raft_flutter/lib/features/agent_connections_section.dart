// Web components/agent/AgentConnections.tsx: "Connected accounts" of a cloud
// agent. The provider runs the GitHub OAuth flow and keeps the token; this
// starts it, shows the status, switches the agent to another connector of the
// server and disconnects. Connections are tenant-level connectors several
// agents may use: only a connector's creator or a server owner/admin may
// assign or disconnect it (`canManage`, decided by the server). Hidden when
// the provider does not support connections or the caller may not manage them
// (4xx but 429); a warning when the provider no longer knows the agent.
//
// The OAuth round trip goes through the system browser: "Continue to GitHub"
// opens the one-time provider URL, the provider returns the browser to Raft's
// landing page, which confirms the pending connection for the signed-in user
// (as on Web). Coming back to the app reads the status again.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/agent_connections.dart';
import '../data/workspace_controller.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'private_route_guard.dart' show workspaceAuthority;

enum _Load { loading, hidden, error, agentMissing, ready }

enum _Failure { start, switching, disconnect }

class AgentConnectionsSection extends StatefulWidget {
  const AgentConnectionsSection({
    super.key,
    required this.controller,
    required this.agentId,
    this.openExternal,
  });

  final WorkspaceController controller;
  final String agentId;

  /// Opens the provider's URL in the browser; the platform launcher when null.
  final Future<bool> Function(Uri uri)? openExternal;

  @override
  State<AgentConnectionsSection> createState() =>
      _AgentConnectionsSectionState();
}

class _AgentConnectionsSectionState extends State<AgentConnectionsSection>
    with WidgetsBindingObserver {
  WorkspaceController get w => widget.controller;
  _Load _load = _Load.loading;
  AgentConnectionStatus? _status;
  int _generation = 0;

  // The start of a connection: pending review, then the browser round trip.
  bool _includePrivate = false, _starting = false, _switching = false;
  bool _retrying = false, _awaitingReturn = false;
  AgentConnectionStart? _pending;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next action starts or the status reloads; the section is keyed by agent.
  ({_Failure kind, String? reason})? _error;
  String? _partialDisconnect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_read());
  }

  @override
  void didUpdateWidget(AgentConnectionsSection old) {
    super.didUpdateWidget(old);
    if (old.agentId != widget.agentId) {
      _generation++;
      _load = _Load.loading;
      _status = null;
      _pending = null;
      _error = null;
      _partialDisconnect = null;
      _awaitingReturn = false;
      unawaited(_read());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    super.dispose();
  }

  /// Back from the browser: the connection may have been confirmed there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingReturn) {
      _awaitingReturn = false;
      unawaited(_read());
    }
  }

  Future<void> _read() async {
    final run = ++_generation;
    final authority = workspaceAuthority(w);
    bool stale() =>
        !mounted || run != _generation || authority != workspaceAuthority(w);
    try {
      final data = await w.client.get(agentConnectionPath(widget.agentId));
      if (stale()) return;
      final status = AgentConnectionStatus.parse(data);
      setState(() {
        _status = status;
        _load = status == null ? _Load.hidden : _Load.ready;
      });
    } on RaftApiException catch (e) {
      if (stale() || e.staleScope) return;
      // The provider no longer knows the agent: say so instead of hiding.
      if (connectionErrorCode(e) == agentMissingAtProviderCode) {
        setState(() => _load = _Load.agentMissing);
        return;
      }
      // 403/404/409 (not allowed, not provider-backed, not provisioned yet,
      // disabled) hide the section.
      final s = e.status;
      setState(
        () => _load = s != null && s < 500 && s != 429
            ? _Load.hidden
            : _Load.error,
      );
    } catch (_) {
      if (stale()) return;
      setState(() => _load = _Load.error);
    }
  }

  void _failed(Object e, _Failure kind) {
    if (!mounted) return;
    if (connectionErrorCode(e) == agentMissingAtProviderCode) {
      setState(() => _load = _Load.agentMissing);
      return;
    }
    setState(() => _error = (kind: kind, reason: providerRefusalReason(e)));
  }

  Future<void> _start() async {
    if (_starting) return;
    final authority = workspaceAuthority(w);
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final data = await w.command(
        'POST',
        agentConnectionPath(widget.agentId),
        data: _includePrivate ? {'access': 'private'} : <String, dynamic>{},
      );
      if (!mounted || authority != workspaceAuthority(w)) return;
      final start = AgentConnectionStart.parse(data);
      if (start == null) throw const FormatException('Invalid start');
      setState(() => _pending = start);
    } catch (e) {
      if (mounted && authority == workspaceAuthority(w)) {
        _failed(e, _Failure.start);
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _continue() async {
    final pending = _pending;
    if (pending == null) return;
    _awaitingReturn = true;
    try {
      final opened =
          await (widget.openExternal?.call(pending.url) ??
              launchUrl(pending.url, mode: LaunchMode.externalApplication));
      if (!opened) _awaitingReturn = false;
    } catch (_) {
      _awaitingReturn = false;
    }
    // The link is single-use: the review is over once the browser has it.
    if (mounted) setState(() => _pending = null);
  }

  Future<void> _assign(String connectorId) async {
    final status = _status;
    final connector = status?.connectors
        .where((c) => c.id == connectorId)
        .firstOrNull;
    // Raft re-checks on the server; the UI only never offers what would be
    // refused.
    if (status == null ||
        connector == null ||
        !connector.canManage ||
        connectorId == status.connectorId) {
      return;
    }
    final authority = workspaceAuthority(w);
    setState(() {
      _switching = true;
      _error = null;
    });
    try {
      await w.command(
        'PUT',
        agentConnectionPath(widget.agentId),
        data: {'connectorId': connectorId},
      );
      if (mounted && authority == workspaceAuthority(w)) await _read();
    } catch (e) {
      if (mounted && authority == workspaceAuthority(w)) {
        _failed(e, _Failure.switching);
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _detach() async {
    await w.command('DELETE', agentConnectionPath(widget.agentId));
    if (mounted) await _read();
  }

  /// The provider may disconnect a connector only partially (some agents not
  /// detached, 502 `…_disconnect_partial`): not a success; the same call
  /// again completes it.
  Future<void> _disconnect(String connectorId) async {
    setState(() => _error = null);
    try {
      await w.command(
        'DELETE',
        agentConnectorPath(widget.agentId, connectorId),
      );
    } catch (e) {
      if (connectionErrorCode(e) != connectorDisconnectPartialCode) rethrow;
      if (mounted) setState(() => _partialDisconnect = connectorId);
      return;
    }
    if (!mounted) return;
    setState(() => _partialDisconnect = null);
    await _read();
  }

  Future<void> _retryDisconnect(String connectorId) async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await _disconnect(connectorId);
    } catch (e) {
      if (mounted) {
        setState(() => _partialDisconnect = null);
        _failed(e, _Failure.disconnect);
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _confirmDetach(AgentConnectionStatus status) =>
      RaftConfirmDialog.show(
        context,
        RaftConfirmDialog(
          surfaceKey: const ValueKey('agent-connection-detach-dialog'),
          confirmKey: const ValueKey('agent-connection-detach-confirm'),
          title: 'Remove GitHub from this agent?',
          message: raftFormat(
            context,
            'This agent stops using GitHub as {account}. The connection stays available to other agents on this server.',
            {'account': status.account ?? 'GitHub'},
          ),
          confirmLabel: 'Remove from this agent',
          confirmVariant: RaftButtonRecipeVariant.warning,
          onConfirm: _detach,
        ),
      );

  Future<void> _confirmDisconnect(AgentConnector current) =>
      RaftConfirmDialog.show(
        context,
        RaftConfirmDialog(
          surfaceKey: const ValueKey('agent-connection-disconnect-dialog'),
          confirmKey: const ValueKey('agent-connection-disconnect-confirm'),
          title: 'Disconnect this GitHub connection?',
          message: raftFormat(
            context,
            '{account} is disconnected for every agent on this server that uses it, not only this one. Those agents lose GitHub access until they are switched to another connection.',
            {'account': current.account ?? 'GitHub'},
          ),
          confirmLabel: 'Disconnect this connection',
          confirmVariant: RaftButtonRecipeVariant.danger,
          onConfirm: () => _disconnect(current.id),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_load == _Load.hidden || _load == _Load.loading) {
      return const SizedBox.shrink();
    }
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final warning = RaftPanelText.warningCaption(t);
    final Widget body;
    switch (_load) {
      case _Load.error:
        body = RaftCssText(tr('Could not load connections.'), style: warning);
      case _Load.agentMissing:
        body = RaftCssText(
          key: const ValueKey('agent-connections-agent-missing'),
          tr(
            'This cloud agent no longer exists in the cloud. Connections are unavailable; recreate the agent.',
          ),
          style: warning,
        );
      default:
        body = _row(context, t, _status!);
    }
    return RaftPanelSection(
      key: const ValueKey('agent-connections'),
      gap: 8,
      children: [RaftSectionEyebrow(tr('Connected accounts')), body],
    );
  }

  Widget _row(
    BuildContext context,
    RaftTokens t,
    AgentConnectionStatus status,
  ) {
    String tr(String s) => raftText(context, s);
    String fmt(String s, Map<String, Object?> v) => raftFormat(context, s, v);
    final current = status.current;
    final creator = current?.creatorName;
    final strong = RaftPanelText.bold(t);
    final body = RaftPanelText.profileValue(t);
    final mono = RaftPanelText.monoCaption(t);
    final warning = RaftPanelText.warningCaption(t);
    final connectors = status.connectors;
    final requestedScope = _includePrivate ? 'repo' : 'public_repo';
    String connectorLabel(AgentConnector c) {
      final account = c.account ?? 'GitHub';
      return c.creatorName == null
          ? account
          : fmt('{account} · created by @{creator}', {
              'account': account,
              'creator': c.creatorName,
            });
    }

    final error = _error;
    final errorText = error == null
        ? null
        : error.reason != null
        ? fmt('The provider refused: {reason}', {'reason': error.reason})
        : tr(switch (error.kind) {
            _Failure.switching => 'Could not switch the connection. Try again.',
            _Failure.disconnect =>
              'Could not disconnect the connection. Try again.',
            _Failure.start => 'Could not start the connection. Try again.',
          });
    return RaftSettingsCard(
      key: ValueKey(
        'agent-connection-github-${status.connected ? 'connected' : 'not-connected'}',
      ),
      child: RaftGapColumn(
        gap: 12,
        children: [
          RaftGapColumn(
            gap: 2,
            children: [
              RaftCssText(tr('GitHub'), style: strong),
              if (status.connected)
                RaftFlowRow(
                  key: const ValueKey('agent-connection-github-status'),
                  gapX: 8,
                  gapY: 0,
                  children: [
                    if (creator != null)
                      RaftCssText(
                        fmt("Uses @{creator}'s GitHub ({account})", {
                          'creator': creator,
                          'account': status.account ?? current?.account ?? '?',
                        }),
                        style: body,
                      )
                    else ...[
                      RaftCssText(
                        fmt('Connected as {account}', {
                          'account': status.account ?? '?',
                        }),
                        style: body,
                      ),
                      if (status.connectedByName != null)
                        RaftCssText(
                          fmt('by @{name}', {'name': status.connectedByName}),
                          style: body,
                        ),
                    ],
                    if (status.connectedAt != null)
                      RaftCssText(
                        agentTimeFormatter(
                          context,
                          w,
                        ).shortDateTime(status.connectedAt),
                        style: mono,
                      ),
                  ],
                )
              else
                RaftCssText(tr('Not connected'), style: body),
              if (status.connected && status.scopes.isNotEmpty)
                RaftCssText(
                  fmt('Scopes: {scopes}', {'scopes': status.scopes.join(', ')}),
                  style: mono,
                ),
            ],
          ),
          if (connectors.isNotEmpty)
            RaftGapColumn(
              key: const ValueKey('agent-connection-github-connectors'),
              gap: 4,
              children: [
                RaftCssText(
                  tr('Use GitHub connection'),
                  style: RaftPanelText.label(t),
                ),
                RaftAgentCombobox(
                  key: const ValueKey('agent-connection-select'),
                  label: 'Use GitHub connection',
                  semanticLabel: tr('Use GitHub connection'),
                  placeholder: tr('Choose a connection'),
                  enabled: !_switching,
                  value: status.connectorId ?? '',
                  items: [
                    for (final c in connectors)
                      RaftComboboxItem(
                        c.id,
                        connectorLabel(c),
                        enabled: c.canManage,
                        description: c.canManage
                            ? null
                            : tr(
                                "Only the connection's creator or a server admin can assign it",
                              ),
                      ),
                  ],
                  onSelected: (id) => unawaited(_assign(id)),
                ),
              ],
            ),
          if (_pending == null)
            RaftFlowRow(
              children: [
                RaftRecipeButton(
                  key: const ValueKey('agent-connection-connect'),
                  label: tr(
                    connectors.isNotEmpty || status.connected
                        ? 'Connect a new GitHub account'
                        : 'Connect',
                  ),
                  tooltip: fmt(
                    "Opens GitHub to grant this agent access ({scopes}). The token stays with the agent's provider.",
                    {'scopes': requestedScope},
                  ),
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  disabled: _starting,
                  onPressed: _starting ? null : () => unawaited(_start()),
                ),
                if (status.connected)
                  RaftRecipeButton(
                    key: const ValueKey('agent-connection-detach'),
                    label: tr('Remove from this agent'),
                    variant: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: () => unawaited(_confirmDetach(status)),
                  ),
                if (status.connected && current?.canManage == true)
                  RaftRecipeButton(
                    key: const ValueKey('agent-connection-disconnect'),
                    label: tr('Disconnect this connection'),
                    variant: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: () => unawaited(_confirmDisconnect(current!)),
                  ),
              ],
            ),
          if (_pending == null)
            RaftFlowRow(
              gapX: 8,
              gapY: 0,
              children: [
                RaftCheckbox(
                  key: const ValueKey('agent-connection-private'),
                  value: _includePrivate,
                  semanticLabel: tr('Include private repositories'),
                  onChanged: (v) => setState(() => _includePrivate = v),
                ),
                RaftCssText(
                  tr('Include private repositories'),
                  style: RaftPanelText.value(t),
                ),
              ],
            ),
          if (_pending case final pending?)
            RaftGapColumn(
              key: const ValueKey('agent-connection-github-pending'),
              gap: 8,
              children: [
                RaftCssText(
                  fmt(
                    'GitHub will ask you to grant: {scopes}. The link is single-use and expires in 10 minutes.',
                    {
                      'scopes': pending.scopes.isEmpty
                          ? requestedScope
                          : pending.scopes.join(', '),
                    },
                  ),
                  style: body,
                ),
                RaftFlowRow(
                  children: [
                    RaftRecipeButton(
                      key: const ValueKey('agent-connection-continue'),
                      label: tr('Continue to GitHub'),
                      variant: RaftButtonRecipeVariant.primary,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: () => unawaited(_continue()),
                    ),
                    RaftRecipeButton(
                      key: const ValueKey('agent-connection-cancel'),
                      label: tr('Cancel'),
                      variant: RaftButtonRecipeVariant.ghost,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: () => setState(() => _pending = null),
                    ),
                  ],
                ),
              ],
            ),
          if (errorText != null)
            RaftCssText(
              key: const ValueKey('agent-connection-github-error'),
              errorText,
              style: warning,
            ),
          if (_partialDisconnect case final id?)
            RaftFlowRow(
              key: const ValueKey('agent-connection-disconnect-partial'),
              children: [
                RaftCssText(
                  tr(
                    'Disconnect partially completed: some agents still use this connection. Retry to finish.',
                  ),
                  style: warning,
                ),
                RaftRecipeButton(
                  key: const ValueKey('agent-connection-retry'),
                  label: tr('Retry'),
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  disabled: _retrying,
                  onPressed: _retrying
                      ? null
                      : () => unawaited(_retryDisconnect(id)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
