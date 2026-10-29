// The "External setup" block of an external agent's profile (Web
// components/agent/AgentDetailPanel.tsx + ExternalAgentToken.tsx): the setup
// state read from GET /agents/:id/external-status, the token manager over
// /agents/:id/credentials and the Hermes / Claude Code / Other agents steps.
// Secrets stay in this widget's state; they never reach the shared stores.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_hosted_runtime.dart';
import '../data/workspace_controller.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'agent_hosted_status.dart';

/// `externalProfileSlug`.
String externalProfileSlug(String name, String id) {
  final slug = name
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? id.substring(0, id.length < 8 ? id.length : 8) : slug;
}

class _CredentialList {
  const _CredentialList(this.rows);
  final List<Map<String, dynamic>> rows;
}

class ExternalAgentSetup extends StatefulWidget {
  const ExternalAgentSetup({
    super.key,
    required this.controller,
    required this.agent,
    this.setupState,
    this.credentialLastUsedAt,
    this.statusError,
    this.hostedRuntime,
    this.onStatus,
  });
  final WorkspaceController controller;

  /// A cloud agent's provisioning summary: its status replaces the token
  /// manager and the setup steps. [onStatus] adopts a fresher external status
  /// (a poll while the provider works, the read after Retry).
  final HostedRuntimeSummary? hostedRuntime;
  final void Function(Map<String, dynamic> status)? onStatus;
  final Map<String, dynamic> agent;

  /// GET /agents/:id/external-status as the profile read it (null while in
  /// flight): the setup state, when the credential was last used, and the
  /// message of a failed read.
  final String? setupState, credentialLastUsedAt, statusError;
  @override
  State<ExternalAgentSetup> createState() => _ExternalAgentSetupState();
}

class _ExternalAgentSetupState extends State<ExternalAgentSetup> {
  WorkspaceController get w => widget.controller;
  String get agentId => '${widget.agent['id']}';
  String get _scope =>
      '${w.client.origin}|${w.client.generation}|${w.client.user?.id}|${w.server?.id}|$agentId';
  late String openedScope = _scope;

  RaftExternalSetupTab tab = RaftExternalSetupTab.hermes;
  String? copiedTarget;
  Timer? copiedTimer;

  // ------------------------------------------------------ token manager
  String token = '';
  String tokenId = '';
  // The masked list (id, label, masked tail, dates; never a secret) of an
  // earlier visit shows at the first frame and revalidates in place.
  String get _credentialsKey => 'external-credentials/$agentId';
  late List<Map<String, dynamic>>? _cachedCredentials = _readCredentials();
  List<Map<String, dynamic>>? _readCredentials() {
    final cached = w.agentTabCache.peek(_credentialsKey);
    return cached is _CredentialList ? cached.rows : null;
  }

  late List<Map<String, dynamic>> credentials = _cachedCredentials ?? const [];
  late bool loading = _cachedCredentials == null;

  /// A list was accepted (or restored) for this agent.
  late bool hasList = _cachedCredentials != null;
  // ignore: raft_lints/avoid_imperative_notice_state -- listError clears when a list load succeeds or Refresh runs; revokeError clears when a revoke prompt opens, Refresh runs, the next revoke starts or the account changes.
  bool listError = false, revokeError = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- error clears when the next generate starts or the account changes; copied clears with the token (revoke or account change).
  bool pending = false, error = false, copied = false;
  String? confirmId, revokingId;
  bool requesting = false;
  int listRevision = 0;

  @override
  void initState() {
    super.initState();
    w.addListener(scopeChanged);
    // A cloud agent has no token manager.
    if (widget.hostedRuntime == null) unawaited(loadCredentials());
  }

  @override
  void dispose() {
    w.removeListener(scopeChanged);
    copiedTimer?.cancel();
    super.dispose();
  }

  bool get live => mounted && openedScope == _scope;

  void scopeChanged() {
    if (openedScope == _scope) return;
    openedScope = _scope;
    token = tokenId = '';
    copied = false;
    // Failures and a pending revoke prompt belong to the previous account's
    // credentials.
    error = revokeError = false;
    confirmId = revokingId = null;
    _cachedCredentials = _readCredentials();
    credentials = _cachedCredentials ?? const [];
    loading = _cachedCredentials == null;
    hasList = _cachedCredentials != null;
    listRevision++;
    if (widget.hostedRuntime == null) unawaited(loadCredentials());
    if (mounted) setState(() {});
  }

  Future<void> loadCredentials() async {
    final id = agentId;
    final opened = openedScope;
    final revision = ++listRevision;
    try {
      final data = await w.client.get(
        '/agents/${Uri.encodeComponent(id)}/credentials',
      );
      if (!live || opened != openedScope || revision != listRevision) return;
      if (data is! Map ||
          data['agentId'] != id ||
          data['credentials'] is! List) {
        throw const FormatException('Invalid credential list');
      }
      final accepted = [
        for (final c in data['credentials'] as List)
          if (c is Map) Map<String, dynamic>.from(c),
      ];
      w.agentTabCache.put(_credentialsKey, _CredentialList(accepted));
      hasList = true;
      setState(() {
        credentials = accepted;
        loading = false;
        listError = false;
      });
    } catch (_) {
      if (!live || opened != openedScope || revision != listRevision) return;
      setState(() {
        // A failed revalidation keeps the list already shown.
        if (!hasList) credentials = const [];
        loading = false;
        listError = !hasList;
      });
    }
  }

  Future<void> generate() async {
    if (requesting) return;
    requesting = true;
    final id = agentId;
    final opened = openedScope;
    setState(() {
      pending = true;
      error = false;
    });
    try {
      final data = await w.client.post(
        '/agents/${Uri.encodeComponent(id)}/credentials',
        data: <String, dynamic>{},
      );
      if (!live || opened != openedScope) return;
      if (data is! Map ||
          data['agentId'] != id ||
          data['credentialId'] is! String ||
          (data['credentialId'] as String).isEmpty ||
          data['apiKey'] is! String ||
          !(data['apiKey'] as String).startsWith('sk_agent_')) {
        throw const FormatException('Invalid credential response');
      }
      setState(() {
        token = data['apiKey'] as String;
        tokenId = data['credentialId'] as String;
        loading = credentials.isEmpty;
        listError = false;
      });
      unawaited(loadCredentials());
    } catch (_) {
      // Neither error payloads nor successful responses are logged.
      if (live && opened == openedScope) setState(() => error = true);
    } finally {
      requesting = false;
      if (live) setState(() => pending = false);
    }
  }

  Future<void> revoke(String credentialId) async {
    if (requesting) return;
    requesting = true;
    final opened = openedScope;
    setState(() {
      revokingId = credentialId;
      revokeError = false;
    });
    try {
      await w.client.request(
        'DELETE',
        '/agents/${Uri.encodeComponent(agentId)}/credentials/${Uri.encodeComponent(credentialId)}',
      );
      if (!live || opened != openedScope) return;
      setState(() {
        credentials = [
          for (final c in credentials)
            c['id'] == credentialId
                ? {...c, 'revokedAt': DateTime.now().toUtc().toIso8601String()}
                : c,
        ];
        w.agentTabCache.put(_credentialsKey, _CredentialList(credentials));
        if (tokenId == credentialId) {
          token = tokenId = '';
          copied = false;
        }
        confirmId = null;
      });
    } catch (_) {
      // An ambiguous failure is not a successful revocation.
      if (live && opened == openedScope) setState(() => revokeError = true);
    } finally {
      requesting = false;
      if (live) setState(() => revokingId = null);
    }
  }

  Future<void> copyToken() async {
    try {
      await Clipboard.setData(ClipboardData(text: token));
      if (mounted) setState(() => copied = true);
    } catch (_) {
      if (mounted) setState(() => copied = false);
    }
  }

  Future<void> copyText(String text, String target) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => copiedTarget = target);
    copiedTimer?.cancel();
    copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => copiedTarget = null);
    });
  }

  // ---------------------------------------------------------- commands

  bool get canIssueCredentials =>
      w.can('issueAgentCredentials') ||
      (widget.agent['creatorType'] == 'user' &&
          widget.agent['creatorId'] == w.client.user?.id);

  /// The setup steps of [tab] (Hermes / Claude Code) and the Other agents
  /// instruction, as the Web profile builds them.
  ({List<RaftExternalSetupStep>? steps, String other}) commands(
    BuildContext context,
  ) {
    String tr(String s) => raftText(context, s);
    final a = widget.agent;
    final slug = externalProfileSlug('${a['name'] ?? ''}', agentId);
    final login =
        'raft agent login --server ${w.client.origin} --agent $agentId --profile-slug $slug';
    const install = 'npm i -g @botiverse/raft@latest';
    final tokenLogin = tr(
      'Paste the agent token at the hidden login prompt, or pipe it from your secret store to stdin. Login verifies and saves it without browser approval. Never include the token in command arguments or shared instructions.',
    );
    final prompt = tr(
      'You are connected to Raft, a shared workspace for humans and agents. Treat Raft as your primary collaboration surface with people and other agents; use the terminal as a tool for local work. If you need the operating guide, run raft manual get raft-cli-overview.',
    );
    final claudeStart = [
      'RAFT_EXPECTED_AGENT_ID=$agentId RAFT_PROFILE=$slug claude \\',
      "  --append-system-prompt '$prompt' \\",
      '  --dangerously-load-development-channels plugin:raft-channel@raft',
    ].join('\n');
    final claude = [
      RaftExternalSetupStep(
        title: tr(
          'Install or upgrade Raft CLI and the Claude Code channel plugin',
        ),
        command: [
          install,
          'claude plugin marketplace add botiverse/raft-external-agents',
          'claude plugin marketplace update raft',
          'claude plugin install raft-channel@raft',
          'claude plugin update raft-channel@raft',
        ].join(' && '),
      ),
      RaftExternalSetupStep(
        title: tr('Log in this agent profile'),
        command: login,
        description: tokenLogin,
      ),
      RaftExternalSetupStep(
        title: tr('Start Claude Code with the Raft channel'),
        command: claudeStart,
      ),
    ];
    final hermes = [
      RaftExternalSetupStep(
        title: tr('Install or upgrade Raft CLI'),
        command: install,
        description: tr(
          'Install Hermes separately from Raft; current Hermes builds include the Raft adapter used by gateway setup.',
        ),
      ),
      RaftExternalSetupStep(
        title: tr('Log in this agent profile'),
        command: login,
        description: tokenLogin,
      ),
      RaftExternalSetupStep(
        title: tr('Configure your Hermes gateway'),
        command: 'RAFT_EXPECTED_AGENT_ID=$agentId hermes gateway setup',
        description: raftFormat(
          context,
          'Select Raft, enter profile slug {slug}, and keep RAFT_EXPECTED_AGENT_ID={agentId} in the gateway environment when you restart or reload it. The bridge sends nothing if the profile resolves to another Agent.',
          {'slug': slug, 'agentId': agentId},
        ),
      ),
    ];
    final other = [
      tr('Run these commands on the computer that will run this agent.'),
      '',
      install,
      login,
      '',
      tokenLogin,
      '',
      raftFormat(
        context,
        'Run RAFT_PROFILE={slug} raft manual get raft-cli-overview to review the operating guide after setup.',
        {'slug': slug},
      ),
    ].join('\n');
    return (
      steps: switch (tab) {
        RaftExternalSetupTab.claudeCode => claude,
        RaftExternalSetupTab.hermes => hermes,
        RaftExternalSetupTab.otherAgents => null,
      },
      other: other,
    );
  }

  String credentialDate(BuildContext context, Object? raw) {
    final date = raw is String ? DateTime.tryParse(raw) : null;
    if (date == null) return '';
    // `formatDate(.., { dateStyle: "medium", timeStyle: "short" })`.
    final locale = Localizations.localeOf(context).toLanguageTag();
    final wall = agentTimeFormatter(context, w).wallTime(date);
    return '${DateFormat.yMMMd(locale).format(wall)}, ${DateFormat.jm(locale).format(wall)}';
  }

  @override
  Widget build(BuildContext context) {
    final built = commands(context);
    final formatter = agentTimeFormatter(context, w);
    return RaftExternalSetupSection(
      setupState: widget.setupState,
      lastUsed: widget.credentialLastUsedAt == null
          ? null
          : raftFormat(context, 'Last used {time}', {
              'time': formatter.shortDateTime(widget.credentialLastUsedAt),
            }),
      statusError: widget.statusError,
      hosted: switch (widget.hostedRuntime) {
        final summary? => AgentHostedRuntimeStatus(
          key: ValueKey('hosted-status-$agentId'),
          controller: w,
          agentId: agentId,
          summary: summary,
          onStatus: widget.onStatus ?? (_) {},
        ),
        null => null,
      },
      tab: tab,
      onTab: (value) => setState(() {
        tab = value;
        copiedTarget = null;
      }),
      steps: built.steps,
      otherInstruction: built.other,
      copiedTarget: copiedTarget,
      onCopy: (text, target) => unawaited(copyText(text, target)),
      tokenManager: canIssueCredentials
          ? RaftExternalAgentToken(
              state: RaftExternalTokenState(
                token: token,
                credentials: [
                  for (final c in credentials)
                    RaftExternalCredential(
                      id: '${c['id']}',
                      label: (c['name'] is String && '${c['name']}'.isNotEmpty)
                          ? '${c['name']}'
                          : 'Agent token',
                      masked:
                          c['maskedToken'] is String &&
                              '${c['maskedToken']}'.isNotEmpty
                          ? '${c['maskedToken']}'
                          : '${c['id']}'.substring(
                              0,
                              '${c['id']}'.length < 8 ? '${c['id']}'.length : 8,
                            ),
                      created: raftFormat(context, 'Created {date}', {
                        'date': credentialDate(context, c['createdAt']),
                      }),
                      revoked: c['revokedAt'] != null,
                    ),
                ],
                loading: loading,
                listError: listError,
                confirmId: confirmId,
                revokingId: revokingId,
                revokeError: revokeError,
                pending: pending,
                error: error,
                copied: copied,
              ),
              actions: RaftExternalTokenActions(
                onGenerate: () => unawaited(generate()),
                onCopy: () => unawaited(copyToken()),
                onRefresh: () {
                  setState(() {
                    confirmId = null;
                    revokeError = false;
                    loading = true;
                    listError = false;
                  });
                  unawaited(loadCredentials());
                },
                onRevoke: (id) => setState(() {
                  confirmId = id;
                  revokeError = false;
                }),
                onConfirmRevoke: (id) => unawaited(revoke(id)),
                onCancelRevoke: () => setState(() => confirmId = null),
              ),
            )
          : null,
    );
  }
}
