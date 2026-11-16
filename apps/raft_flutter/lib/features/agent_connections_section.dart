// Web components/agent/AgentConnections.tsx: "Connected accounts" of a cloud
// agent. The provider runs the GitHub OAuth flow and keeps the token; this
// starts it, shows the status, switches the agent to another connector of the
// server, removes it from the agent and disconnects it. Connections are
// tenant-level connectors several agents may use: only a connector's creator
// or a server owner/admin may assign or disconnect it (`canManage`, decided by
// the server). Hidden when the provider does not support connections or the
// caller may not manage them (4xx but 429); a warning when the provider no
// longer knows the agent.
//
// The OAuth round trip goes through the system browser: "Continue to GitHub"
// asks the server for the one-time provider URL and opens it, the provider
// returns the browser to Raft's landing page, which confirms the pending
// connection for the signed-in user (as on Web). Coming back to the app reads
// the status again. The landing page owns `account_mismatch` and
// `pending_invalid`: they never reach this card.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/agent_connections.dart';
import '../data/workspace_controller.dart';
import 'agent_connection_views.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'private_route_guard.dart' show workspaceAuthority;

enum _Load { loading, hidden, error, agentMissing, ready }

enum _Failure { start, switching, detach, disconnect }

/// `ActionError`: a failed action, kept until the next action starts.
/// [sentence] is the generic provider refusal's sentence (shown as sent);
/// [details] is only ever copied. [account] and [creator] name the connection
/// the action was about; [retry] repeats it.
class _ActionError {
  const _ActionError({
    required this.kind,
    required this.code,
    required this.sentence,
    required this.account,
    required this.creator,
    required this.details,
    required this.retry,
  });
  final _Failure kind;
  final String? code, sentence, account, creator, details;
  final VoidCallback retry;
}

class AgentConnectionsSection extends StatefulWidget {
  const AgentConnectionsSection({
    super.key,
    required this.controller,
    required this.agentId,
    this.agentName,
    this.openExternal,
  });

  final WorkspaceController controller;
  final String agentId;

  /// The agent's name in the copy; read from the workspace when null.
  final String? agentName;

  /// Opens a URL in the browser; the platform launcher when null.
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

  bool _switching = false, _removing = false, _retrying = false;
  bool _awaitingReturn = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next action starts or the status reloads; the section is keyed by agent.
  _ActionError? _error;
  String? _partialDisconnect;

  // A removal that took left a copy of the credential the provider can't
  // reach: tell the person to revoke on GitHub.
  bool _revokeOnGithub = false;

  // The connector whose partial disconnect said so: its retry no longer meets
  // that copy, so the hint waits for it.
  String? _revokeAfterRetry;

  // The connector the agent uses now, read by an Undo toast that outlives
  // this section.
  String? _currentConnectorId;

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
      _currentConnectorId = null;
      _error = null;
      _partialDisconnect = null;
      _revokeOnGithub = false;
      _revokeAfterRetry = null;
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

  String get _agentName {
    final given = widget.agentName;
    if (given != null && given.isNotEmpty) return given;
    final row = w.entityDirectory.agent(widget.agentId);
    for (final key in const ['displayName', 'name']) {
      final v = row?[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return raftText(context, 'Agent');
  }

  String get _githubName => raftText(context, 'GitHub');

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
        _currentConnectorId = status?.connectorId;
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

  AgentConnector? _connector(String? id) => id == null
      ? null
      : _status?.connectors.where((c) => c.id == id).firstOrNull;

  /// A failed action, by the server's code: [connectorId] is the connection it
  /// was about, when there is one.
  void _failed(
    Object e,
    _Failure kind,
    String? account,
    VoidCallback retry, [
    String? connectorId,
  ]) {
    if (!mounted) return;
    final code = connectionErrorCode(e);
    if (code == agentMissingAtProviderCode) {
      setState(() => _load = _Load.agentMissing);
      return;
    }
    final connector = _connector(connectorId);
    setState(
      () => _error = _ActionError(
        kind: kind,
        code: code,
        sentence: providerRefusalSentence(e),
        account: account ?? connector?.account,
        creator: connector?.creatorName,
        details: refusalDetails(e),
        retry: retry,
      ),
    );
    // The connection is gone: reload, and it leaves the list. Not the creator
    // or an admin: reload, so `canManage` hides what it can't do.
    if (code == connectorForbiddenCode ||
        code == connectorNotFoundCode ||
        code == connectionOwnerRequiredCode) {
      unawaited(_read());
    }
  }

  /// Starts the provider's OAuth flow and leaves for the browser (true when it
  /// opened); a failure shows why.
  Future<bool> _start(String access, AgentConnector? target) async {
    final authority = workspaceAuthority(w);
    setState(() {
      _error = null;
      _revokeOnGithub = false;
    });
    try {
      // Reconnect names the connection, so the confirm replaces its tokens in
      // place (same id); Connect new names none.
      final data = await w.command(
        'POST',
        agentConnectionPath(widget.agentId),
        data: <String, dynamic>{
          if (access == 'private') 'access': 'private',
          'connectorId': ?target?.id,
        },
      );
      if (!mounted || authority != workspaceAuthority(w)) return false;
      final start = AgentConnectionStart.parse(data);
      if (start == null) throw const FormatException('Invalid start');
      _awaitingReturn = true;
      final opened = await _open(start.url);
      if (!opened) {
        _awaitingReturn = false;
        throw const FormatException('The browser did not open');
      }
      return true;
    } catch (e) {
      if (mounted && authority == workspaceAuthority(w)) {
        _failed(e, _Failure.start, target?.account, () {
          unawaited(_restart(access, target));
        }, target?.id);
      }
      return false;
    }
  }

  Future<void> _restart(String access, AgentConnector? target) async {
    await _start(access, target);
  }

  Future<bool> _open(Uri url) async {
    try {
      return await (widget.openExternal?.call(url) ??
          launchUrl(url, mode: LaunchMode.externalApplication));
    } catch (_) {
      return false;
    }
  }

  Future<void> _assign(String connectorId) async {
    final status = _status;
    final connector = _connector(connectorId);
    // Raft re-checks on the server; the UI only never offers what would be
    // refused.
    if (status == null ||
        connector == null ||
        !connector.canAssign ||
        connectorId == (status.connectorId ?? status.attached?.id)) {
      return;
    }
    final authority = workspaceAuthority(w);
    setState(() {
      _switching = true;
      _error = null;
      _partialDisconnect = null;
      _revokeOnGithub = false;
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
        _failed(e, _Failure.switching, connector.account, () {
          unawaited(_assign(connectorId));
        }, connectorId);
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  /// Undo of "Remove from agent": points the agent at the same connector
  /// again, unless another connection was picked meanwhile. The toast outlives
  /// this section, so its outcome is reported as a toast too.
  Future<void> _reattach(
    String connectorId,
    RaftToastController? toast,
    String skipped,
    String failed,
  ) async {
    if (_currentConnectorId != null) {
      toast?.show(skipped, tone: RaftToastRecipeTone.error);
      return;
    }
    try {
      await w.command(
        'PUT',
        agentConnectionPath(widget.agentId),
        data: {'connectorId': connectorId},
      );
      if (mounted) await _read();
    } catch (_) {
      toast?.show(failed, tone: RaftToastRecipeTone.error);
    }
  }

  /// [retry]: the Retry of a removal that did not take. Its warning stays up
  /// (Retry disabled) until this one answers, instead of blinking away.
  Future<void> _detach({bool retry = false}) async {
    if (_removing) return;
    final status = _status;
    final removed = status?.current;
    final account = status?.account ?? removed?.account;
    final agent = _agentName;
    final removedText = raftFormat(context, 'Removed {account} from {agent}', {
      'account': removed?.account ?? account ?? _githubName,
      'agent': agent,
    });
    final toast = RaftToastHost.maybeOf(context);
    final skipped = raftFormat(
      context,
      'Not restored: {agent} already uses another connection.',
      {'agent': agent},
    );
    final restoreFailed = raftText(
      context,
      'Could not restore the connection. Choose it again from the list.',
    );
    final undo = raftText(context, 'Undo');
    final authority = workspaceAuthority(w);
    setState(() {
      _removing = true;
      if (!retry) _error = null;
      _partialDisconnect = null;
      _revokeOnGithub = false;
    });
    Object? removal;
    try {
      removal = await w.command('DELETE', agentConnectionPath(widget.agentId));
    } catch (e) {
      if (mounted && authority == workspaceAuthority(w)) {
        setState(() => _removing = false);
        _failed(e, _Failure.detach, account, () {
          unawaited(_detach(retry: true));
        }, removed?.id);
      }
      return;
    }
    if (!mounted || authority != workspaceAuthority(w)) return;
    setState(() {
      _error = null;
      _revokeOnGithub = saysRevokeOnGithub(removal);
    });
    await _read();
    if (mounted) setState(() => _removing = false);
    // Re-attaching needs the same right as assigning: offer Undo only when the
    // caller has it.
    if (removed != null && removed.canAssign) {
      toast?.show(
        removedText,
        actionLabel: undo,
        onAction: () =>
            unawaited(_reattach(removed.id, toast, skipped, restoreFailed)),
      );
    } else {
      toast?.show(removedText);
    }
  }

  /// The provider may disconnect a connector only partially (some agents not
  /// detached, 502 `…_disconnect_partial`): not a success; the same call
  /// again completes it.
  Future<void> _disconnectConnector(String connectorId) async {
    setState(() {
      _error = null;
      _revokeOnGithub = false;
    });
    Object? removal;
    try {
      removal = await w.command(
        'DELETE',
        agentConnectorPath(widget.agentId, connectorId),
      );
    } catch (e) {
      if (connectionErrorCode(e) != connectorDisconnectPartialCode) rethrow;
      // Said once, by the call that met the copy; shown when the disconnect
      // completes.
      if (saysRevokeOnGithub(e)) _revokeAfterRetry = connectorId;
      if (mounted) setState(() => _partialDisconnect = connectorId);
      return;
    }
    if (!mounted) return;
    final metEarlier = _revokeAfterRetry == connectorId;
    _revokeAfterRetry = null;
    setState(() {
      _partialDisconnect = null;
      _revokeOnGithub = saysRevokeOnGithub(removal) || metEarlier;
    });
    await _read();
  }

  Future<void> _runDisconnect(String connectorId, String? account) async {
    try {
      await _disconnectConnector(connectorId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _partialDisconnect = null);
      _failed(e, _Failure.disconnect, account, () {
        unawaited(_runDisconnect(connectorId, account));
      }, connectorId);
    }
  }

  Future<void> _retryDisconnect(String connectorId) async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await _runDisconnect(connectorId, _status?.current?.account);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _copyDetails(String details) async {
    final toast = RaftToastHost.maybeOf(context);
    final copied = raftText(context, 'Details copied');
    final failed = raftText(context, 'Could not copy the details');
    try {
      await Clipboard.setData(ClipboardData(text: details));
      toast?.show(copied);
    } catch (_) {
      toast?.show(failed, tone: RaftToastRecipeTone.error);
    }
  }

  // ----- dialogs ---------------------------------------------------------

  /// "Connect new account" / "Reconnect {account}": pick the repository
  /// access, then leave for GitHub. Reconnect preselects what was asked last
  /// time.
  Future<void> _openConnect(AgentConnector? target) {
    final access = ValueNotifier<String>(
      target != null && target.wantsPrivate ? 'private' : 'public',
    );
    return RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('agent-connection-connect-dialog'),
        confirmKey: const ValueKey('agent-connection-connect-continue'),
        title: target == null
            ? raftText(context, 'Connect new account')
            : raftFormat(context, 'Reconnect {account}', {
                'account': target.account ?? _githubName,
              }),
        plainMessage: true,
        maxWidth: 448,
        confirmLabel: 'Continue to GitHub',
        confirmVariant: RaftButtonRecipeVariant.primary,
        content: _ConnectContent(agent: _agentName, access: access),
        onConfirm: () async {
          await _start(access.value, target);
        },
      ),
    ).whenComplete(access.dispose);
  }

  Future<void> _confirmDetach() {
    final status = _status;
    final current = status?.current;
    final creator = current?.creatorName;
    final agent = _agentName;
    final account = status?.account ?? current?.account ?? _githubName;
    return RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('agent-connection-detach-dialog'),
        confirmKey: const ValueKey('agent-connection-detach-confirm'),
        title: raftFormat(context, 'Remove GitHub from {agent}?', {
          'agent': agent,
        }),
        message: creator != null
            ? raftFormat(
                context,
                '{agent} stops using GitHub as {account}. The connection stays available to other agents on this server, but only {creator}, who created it, or a server admin can assign it to {agent} again.',
                {'agent': agent, 'account': account, 'creator': creator},
              )
            : raftFormat(
                context,
                '{agent} stops using GitHub as {account}. The connection stays available to other agents on this server, but only its creator or a server admin can assign it to {agent} again.',
                {'agent': agent, 'account': account},
              ),
        confirmLabel: 'Remove',
        confirmVariant: RaftButtonRecipeVariant.warning,
        onConfirm: _detach,
      ),
    );
  }

  /// The connection named in the disconnect confirmation: account, creator and
  /// date as far as known.
  String _disconnectSubject(AgentConnector c) {
    final account = c.account ?? _githubName;
    final creator = c.creatorName;
    final date = c.createdAt == null
        ? null
        : agentTimeFormatter(context, w).shortDateTime(c.createdAt);
    if (creator != null && date != null) {
      return raftFormat(context, '{account} (created by {creator} on {date})', {
        'account': account,
        'creator': creator,
        'date': date,
      });
    }
    if (creator != null) {
      return raftFormat(context, '{account} (created by {creator})', {
        'account': account,
        'creator': creator,
      });
    }
    return account;
  }

  Future<void> _confirmDisconnect(AgentConnector current) {
    return RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('agent-connection-disconnect-dialog'),
        confirmKey: const ValueKey('agent-connection-disconnect-confirm'),
        title: raftText(context, 'Disconnect for all agents'),
        message: raftFormat(
          context,
          "{connection} is disconnected for every agent on this server that uses it, not only {agent}. Those agents can't use GitHub until each is switched to another connection. Using it again means connecting it again.",
          {'connection': _disconnectSubject(current), 'agent': _agentName},
        ),
        confirmLabel: 'Disconnect for all agents',
        confirmVariant: RaftButtonRecipeVariant.danger,
        onConfirm: () => _runDisconnect(current.id, current.account),
      ),
    );
  }

  // ----- build -----------------------------------------------------------

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
        body = _card(context, t, _status!);
    }
    return RaftPanelSection(
      key: const ValueKey('agent-connections'),
      gap: 8,
      children: [RaftSectionEyebrow(tr('Connected accounts')), body],
    );
  }

  /// "Created by alice · Oct 21, 15:31": what is known about who made a
  /// connection and when.
  String? _createdLine(AgentConnector c) {
    final creator = c.creatorName;
    final date = c.createdAt == null
        ? null
        : agentTimeFormatter(context, w).shortDateTime(c.createdAt);
    if (creator != null && date != null) {
      return raftFormat(context, 'Created by {creator} · {date}', {
        'creator': creator,
        'date': date,
      });
    }
    if (creator != null) {
      return raftFormat(context, 'Created by {creator}', {'creator': creator});
    }
    if (date != null) {
      return raftFormat(context, 'Created {date}', {'date': date});
    }
    return null;
  }

  /// `ConnectorOption`'s second line: what needs attention or sets it apart.
  String? _optionDescription(AgentConnector c) {
    final access = describeGithubAccess(c.scopes, c.requestedScopes);
    final state = c.oauthStatus == 'error'
        ? raftText(context, 'Needs reconnecting')
        : agentConnectionAccessSummary(context, access);
    final reason = c.canManage
        ? null
        : raftText(
            context,
            "Only the connection's creator or a server admin can assign it",
          );
    final text = [?state, ?_createdLine(c), ?reason].join(' · ');
    return text.isEmpty ? null : text;
  }

  String _errorMessage(_ActionError e) {
    String account() => e.account ?? _githubName;
    final agent = _agentName;
    return switch (e.code) {
      connectorNotFoundCode => raftFormat(
        context,
        '{account} was disconnected in the meantime, so it was removed from the list.',
        {'account': account()},
      ),
      connectorForbiddenCode =>
        e.creator != null
            ? raftFormat(
                context,
                'Only {creator}, who created {account}, or a server owner or admin can change this connection.',
                {'account': account(), 'creator': e.creator},
              )
            : raftFormat(
                context,
                'Only the creator of {account} or a server owner or admin can change this connection.',
                {'account': account()},
              ),
      // The provider's sentence, as sent (Raft's own when the provider's did
      // not read as one).
      providerRefusedCode =>
        e.sentence ??
            raftText(
              context,
              "The agent's provider refused this GitHub request. Try again; if it keeps happening, copy the details for whoever manages the agent's provider.",
            ),
      _ => switch (e.kind) {
        // A removal that did not take carries its own Retry button: no "try
        // again" in the text.
        _Failure.detach => raftFormat(
          context,
          e.code == disconnectNotClearedCode
              ? 'Could not remove the connection from {agent}.'
              : 'Could not remove the connection from {agent}. Try again.',
          {'agent': agent},
        ),
        _Failure.switching => raftText(
          context,
          'Could not switch the connection. Try again.',
        ),
        _Failure.disconnect => raftText(
          context,
          'Could not disconnect the connection. Try again.',
        ),
        _Failure.start => raftText(
          context,
          'Could not start the connection. Try again.',
        ),
      },
    };
  }

  Widget _card(BuildContext context, RaftTokens t, AgentConnectionStatus s) {
    String tr(String s) => raftText(context, s);
    final agent = _agentName;
    final connectors = s.connectors;
    final current = s.current;
    final attached = s.attached;
    final needsReconnect = s.needsReconnect;
    final state = needsReconnect
        ? AgentConnectionState.needsReconnect
        : s.connected
        ? AgentConnectionState.connected
        : AgentConnectionState.notConnected;
    final currentAccount = s.account ?? current?.account;
    // Reconnect is the existing connect flow; only the connection's creator or
    // a server owner/admin may use it.
    final canReconnect = needsReconnect && (attached?.canManage ?? true);
    // What the agent's connection can do: its connector's lists, or (an older
    // provider, no connectors) the status's own.
    final access = attached != null
        ? describeGithubAccess(attached.scopes, attached.requestedScopes)
        : describeGithubAccess(
            s.connected && s.scopes.isNotEmpty ? s.scopes : null,
            s.requestedScopes,
          );
    final createdCurrent = current == null ? null : _createdLine(current);
    final error = _error;
    final menu = AgentConnectionActionsMenu(
      agentName: agent,
      canDisconnect: current?.canManage ?? false,
      removing: _removing,
      onConnectNew: s.canConnectNew
          ? () => unawaited(_openConnect(null))
          : null,
      onDetach: _onDetachPressed,
      onDisconnect: () {
        if (current != null) unawaited(_confirmDisconnect(current));
      },
    );
    final caption = RaftPanelText.caption(t);
    final callout = RaftPanelText.profileValue(t);
    return RaftSettingsCard(
      key: ValueKey(
        'agent-connection-github-${s.connected ? 'connected' : 'not-connected'}',
      ),
      padding: RaftAgentConnectionInsets.card,
      child: RaftGapColumn(
        gap: 12,
        children: [
          RaftGapColumn(
            gap: 4,
            children: [
              RaftFlowRow(
                gapX: 8,
                gapY: 4,
                children: [
                  const RaftBrandMark(RaftBrandMarkKind.github, height: 18),
                  RaftCssText(tr('GitHub'), style: RaftPanelText.bold(t)),
                  AgentConnectionStateChip(state: state),
                ],
              ),
              RaftCssText(
                raftFormat(
                  context,
                  '{agent} works on repos, issues and pull requests as the GitHub account you choose.',
                  {'agent': agent},
                ),
                style: callout,
              ),
            ],
          ),
          if (connectors.isNotEmpty)
            RaftGapColumn(
              key: const ValueKey('agent-connection-github-connectors'),
              gap: 4,
              children: [
                RaftCssText(
                  tr('GitHub connection'),
                  style: RaftPanelText.label(t),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: RaftSpace.x1,
                  children: [
                    Expanded(
                      child: RaftSelectField<String>(
                        key: const ValueKey('agent-connection-select'),
                        label: tr('GitHub connection'),
                        placeholder: tr('Choose a connection'),
                        value: s.connectorId ?? attached?.id,
                        items: [
                          for (final c in connectors)
                            RaftSelectItem<String>(
                              value: c.id,
                              label: c.account ?? _githubName,
                              enabled: c.canAssign,
                              description: _optionDescription(c),
                            ),
                        ],
                        onChanged: _switching
                            ? null
                            : (id) {
                                if (id != null) unawaited(_assign(id));
                              },
                      ),
                    ),
                    if (s.connected) menu,
                  ],
                ),
                if (createdCurrent != null)
                  RaftCssText(
                    key: const ValueKey('agent-connection-github-status'),
                    createdCurrent,
                    style: caption,
                  ),
                if (s.connected && !needsReconnect)
                  AgentConnectionAccessLine(access: access),
              ],
            )
          else if (s.connected)
            // A connection without a tenant connector list (an older
            // provider): name the account.
            RaftGapColumn(
              gap: 4,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RaftCssText(
                        key: const ValueKey('agent-connection-github-status'),
                        raftFormat(context, 'Connected as {account}', {
                          'account': currentAccount ?? _githubName,
                        }),
                        style: callout,
                      ),
                    ),
                    menu,
                  ],
                ),
                AgentConnectionAccessLine(access: access),
              ],
            ),
          if (needsReconnect)
            RaftBanner(
              key: const ValueKey('agent-connection-github-health'),
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.triangleAlert,
              live: false,
              descriptionBuilder: (style) => AgentConnectionHealthDetail(
                style: style,
                message: raftFormat(
                  context,
                  canReconnect
                      ? '{account} needs reconnecting before {agent} can use GitHub again.'
                      : '{account} needs reconnecting before {agent} can use GitHub again. Only its creator or a server owner or admin can reconnect it.',
                  {
                    'account': attached?.account ?? s.account ?? _githubName,
                    'agent': agent,
                  },
                ),
                reason: attached?.lastCheckError ?? s.lastCheckError,
                checkedAt: attached?.lastCheckedAt ?? s.lastCheckedAt,
              ),
              actions: [
                if (canReconnect)
                  _button('Reconnect', () => unawaited(_openConnect(attached))),
              ],
            ),
          if (s.connected && !needsReconnect && access.short.isNotEmpty)
            RaftBanner(
              key: const ValueKey('agent-connection-github-scopes-short'),
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.triangleAlert,
              live: false,
              description: tr(
                'GitHub granted less access than was requested. Reconnect to ask again.',
              ),
              actions: [
                if (attached == null || attached.canManage)
                  _button('Reconnect', () => unawaited(_openConnect(attached))),
              ],
            ),
          if (error != null) _errorBanner(error),
          if (_partialDisconnect case final id?)
            RaftBanner(
              key: const ValueKey('agent-connection-disconnect-partial'),
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.triangleAlert,
              description: tr(
                'Disconnect partially completed: some agents still use this connection. Retry to finish.',
              ),
              actions: [
                _button(
                  'Retry',
                  () => unawaited(_retryDisconnect(id)),
                  disabled: _retrying,
                ),
              ],
            ),
          if (_revokeOnGithub)
            AgentConnectionRevokeHint(
              onOpen: () => unawaited(_open(githubAuthorizedAppsUrl)),
              onClose: () => setState(() => _revokeOnGithub = false),
            ),
          if (!s.connected && !canReconnect && !s.canConnectNew)
            RaftCssText(
              key: const ValueKey('agent-connection-github-owner-only'),
              tr("Only this agent's owner can connect a GitHub account to it."),
              style: callout,
            ),
          if (!s.connected && !canReconnect && s.canConnectNew)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: RaftRecipeButton(
                key: const ValueKey('agent-connection-connect'),
                label: tr('Connect new account'),
                variant: RaftButtonRecipeVariant.default_,
                size: RaftButtonRecipeSize.md,
                onPressed: () => unawaited(_openConnect(null)),
              ),
            ),
        ],
      ),
    );
  }

  void _onDetachPressed() {
    // Without the right to assign it again there is no Undo: confirm first.
    final current = _status?.current;
    if (current != null && current.canAssign) {
      unawaited(_detach());
    } else {
      unawaited(_confirmDetach());
    }
  }

  /// A banner action: the default button, or a ghost one beside it.
  Widget _button(
    String label,
    VoidCallback onPressed, {
    bool ghost = false,
    bool disabled = false,
  }) => RaftRecipeButton(
    label: raftText(context, label),
    variant: ghost
        ? RaftButtonRecipeVariant.ghost
        : RaftButtonRecipeVariant.default_,
    size: RaftButtonRecipeSize.md,
    disabled: disabled,
    onPressed: disabled ? null : onPressed,
  );

  Widget _errorBanner(_ActionError e) {
    final notCleared =
        e.kind == _Failure.detach && e.code == disconnectNotClearedCode;
    final refused = e.code == providerRefusedCode;
    return RaftBanner(
      key: const ValueKey('agent-connection-github-error'),
      status: e.code == connectorNotFoundCode
          ? RaftBannerRecipeStatus.info
          : RaftBannerRecipeStatus.warning,
      size: RaftBannerRecipeSize.sm,
      glyph: e.code == connectorNotFoundCode
          ? RaftGlyph.info
          : RaftGlyph.triangleAlert,
      description: _errorMessage(e),
      actions: [
        if (notCleared)
          // The removal did not take and the connection was kept: the same
          // removal again completes it.
          _button('Retry', e.retry, disabled: _removing)
        else if (refused) ...[
          // The attempt stops here: no automatic retry, only the person's own
          // Retry.
          _button('Retry', e.retry),
          if (e.details != null)
            _button(
              'Copy details',
              () => unawaited(_copyDetails(e.details!)),
              ghost: true,
            ),
        ],
      ],
    );
  }
}

/// The body of the connect dialog (`ConnectAccountDialog`): the lead, the
/// repository access choice and the note on where the token stays.
class _ConnectContent extends StatelessWidget {
  const _ConnectContent({required this.agent, required this.access});
  final String agent;
  final ValueNotifier<String> access;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x3,
      children: [
        RaftCssText(
          raftFormat(
            context,
            'After you approve on GitHub, {agent} switches to the new connection.',
            {'agent': agent},
          ),
          style: RaftPanelText.profileValue(t),
        ),
        ValueListenableBuilder<String>(
          valueListenable: access,
          builder: (context, value, _) => RaftRadioGroup<String>(
            value: value,
            semanticLabel: tr('Repository access'),
            onChanged: (v) => access.value = v,
            spacing: 0,
            children: [
              AgentConnectionAccessOption(
                value: 'public',
                title: tr('Public repos only'),
                description: tr(
                  'Read and write the public repos you can access. GitHub scope:',
                ),
                scope: 'public_repo',
              ),
              AgentConnectionAccessOption(
                value: 'private',
                title: tr('Public and private repos'),
                description: tr(
                  'Also the private repos you can access. GitHub scope:',
                ),
                scope: 'repo',
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: RaftSpace.x1_5,
          children: [
            Padding(
              padding: RaftAgentConnectionInsets.firstLine,
              child: RaftIcon(
                RaftGlyph.info,
                size: 14,
                color: t.colors['foreground-hint'],
              ),
            ),
            Expanded(
              child: RaftCssText(
                tr(
                  "The token stays with the agent's cloud provider, never with Raft. The GitHub link works for 10 minutes.",
                ),
                style: RaftPanelText.caption(t)
                    .copyWith(color: t.colors['foreground-hint']),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
