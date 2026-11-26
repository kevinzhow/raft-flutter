// The "External setup" block of an external agent's page (Web v1.24
// features/agent/ExternalAgentConnectionCard.tsx + useExternalAgentCredentials
// .ts, mounted at AgentProfileInfo.tsx): one status line in four states, the
// steps for how the agent connects, the credentials for whoever may issue
// them. The setup state comes from GET /agents/:id/external-status, read by
// the profile (its poll while the agent is not connected runs here); the
// credential requests live here. Secrets stay in this widget's state; they
// never reach the shared stores.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/agent_hosted_runtime.dart';
import '../data/external_agent_setup_text.dart';
import '../data/workspace_controller.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'agent_hosted_status.dart';
import 'resource_cards.dart' show resourceRelativeTime;
import 'second_factor_step_up.dart';

/// The presentation's name for the method.
extension ExternalSetupMethodUi on ExternalSetupMethod {
  RaftExternalMethod get ui => this == ExternalSetupMethod.sdk
      ? RaftExternalMethod.sdk
      : RaftExternalMethod.existingAgent;
}

ExternalSetupMethod externalSetupMethodOfUi(RaftExternalMethod method) =>
    method == RaftExternalMethod.sdk
    ? ExternalSetupMethod.sdk
    : ExternalSetupMethod.existingAgent;

class _CredentialList {
  const _CredentialList(this.rows);
  final List<Map<String, dynamic>> rows;
}

/// A credential action waiting for its confirmation.
enum _Confirm { replace, revoke }

class ExternalAgentSetup extends StatefulWidget {
  const ExternalAgentSetup({
    super.key,
    required this.controller,
    required this.agent,
    this.status,
    this.statusError,
    this.hostedRuntime,
    this.onStatus,
    this.online = false,
    this.lastSeenAt,
    this.clock,
  });
  final WorkspaceController controller;

  /// A cloud agent's provisioning summary: its status replaces the steps and
  /// credentials. [onStatus] adopts a fresher external status (a poll, a
  /// read after a credential request, the read after Retry).
  final HostedRuntimeSummary? hostedRuntime;
  final void Function(Map<String, dynamic> status)? onStatus;
  final Map<String, dynamic> agent;

  /// GET /agents/:id/external-status as the profile read it (null while in
  /// flight) and the message of a failed read.
  final Map<String, dynamic>? status;
  final String? statusError;

  /// The agent's presence (Web `useAgentDisplayState().isOnline`: its
  /// credential seen within the online window) and when it was last seen.
  final bool online;
  final String? lastSeenAt;
  final DateTime Function()? clock;

  @override
  State<ExternalAgentSetup> createState() => _ExternalAgentSetupState();
}

class _ExternalAgentSetupState extends State<ExternalAgentSetup> {
  WorkspaceController get w => widget.controller;
  String get agentId => '${widget.agent['id']}';
  String get _scope =>
      '${w.client.origin}|${w.client.generation}|${w.client.user?.id}|${w.server?.id}|$agentId';
  late String openedScope = _scope;

  Map<String, dynamic> get status => widget.status ?? const {};
  String? get setupState => status['setupState'] as String?;
  ExternalSetupMethod get method =>
      ExternalSetupMethod.of(status['externalSetupMethod']);
  ExternalConnectionState get state =>
      externalConnectionStateOf(setupState, widget.online);
  bool get connected => externalConnected(state);
  bool get hosted => widget.hostedRuntime != null;

  bool expanded = false;
  _Confirm? confirm;
  String? confirmId;
  RaftForegroundPeriodic? _poll;
  bool _polling = false;

  // ------------------------------------------------------ credentials
  // The masked list (id, label, dates; never a secret) of an earlier visit
  // shows at the first frame and revalidates in place.
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
  // ignore: raft_lints/avoid_imperative_notice_state -- listError clears when a list load succeeds; error clears when the next create or revoke starts or the account changes.
  bool listError = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next create or revoke starts, and on an account change.
  String? error;

  /// The secret of a credential made a moment ago: state only, gone with the
  /// page.
  String? secret;
  bool busy = false, requesting = false;
  int listRevision = 0;

  bool get canIssueCredentials =>
      w.can('issueAgentCredentials') ||
      (widget.agent['creatorType'] == 'user' &&
          widget.agent['creatorId'] == w.client.user?.id);

  @override
  void initState() {
    super.initState();
    w.addListener(scopeChanged);
    // A cloud agent has no credentials of its own to manage.
    if (!hosted && canIssueCredentials) unawaited(loadCredentials());
    _syncPoll();
  }

  @override
  void didUpdateWidget(ExternalAgentSetup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPoll();
  }

  @override
  void dispose() {
    w.removeListener(scopeChanged);
    _poll?.dispose();
    super.dispose();
  }

  bool get live => mounted && openedScope == _scope;

  void scopeChanged() {
    if (openedScope == _scope) return;
    openedScope = _scope;
    secret = null;
    // Failures and a pending confirmation belong to the previous account.
    error = null;
    confirm = confirmId = null;
    _cachedCredentials = _readCredentials();
    credentials = _cachedCredentials ?? const [];
    loading = _cachedCredentials == null;
    hasList = _cachedCredentials != null;
    listRevision++;
    if (!hosted && canIssueCredentials) unawaited(loadCredentials());
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------- poll

  /// Until it signs in, the line updates by itself (the create dialog's
  /// promise, kept here); only while the app is in the foreground.
  void _syncPoll() {
    if (!hosted && !connected && widget.status != null) {
      _poll ??= RaftForegroundPeriodic(
        externalStatusPollInterval,
        () => unawaited(refreshStatus()),
      );
    } else {
      _poll?.dispose();
      _poll = null;
    }
  }

  Future<void> refreshStatus() async {
    if (_polling) return;
    _polling = true;
    final opened = openedScope;
    try {
      final next = await w.client.get(
        '/agents/${Uri.encodeComponent(agentId)}/external-status',
      );
      if (!live || opened != openedScope) return;
      if (next is Map) widget.onStatus?.call(Map<String, dynamic>.from(next));
    } catch (_) {
      // The next tick asks again.
    } finally {
      _polling = false;
    }
  }

  // ------------------------------------------------------ credentials

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

  List<Map<String, dynamic>> get active => [
    for (final c in credentials)
      if (c['revokedAt'] == null) c,
  ];

  Map<String, dynamic>? get pageCredential =>
      active.where((c) => c['name'] == pageCredentialName).firstOrNull;

  /// A new credential made on this page; it replaces the page's earlier one,
  /// never a CLI login's. True when one was made.
  Future<bool> create(String? replacesCredentialId) async {
    if (requesting) return false;
    requesting = true;
    final id = agentId;
    final opened = openedScope;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Two-step verification on: "Verify it's you" first (Web
      // useExternalAgentCredentials, reason agentKey).
      final data = await withSecondFactorStepUp(
        context,
        w.client,
        () => w.client.post(
          '/agents/${Uri.encodeComponent(id)}/credentials',
          data: <String, dynamic>{
            'name': pageCredentialName,
            'replacesCredentialId': ?replacesCredentialId,
          },
        ),
        reason: StepUpReason.agentKey,
      );
      if (!live || opened != openedScope) return false;
      if (data is! Map ||
          data['agentId'] != id ||
          data['apiKey'] is! String ||
          !(data['apiKey'] as String).startsWith('sk_agent_')) {
        throw const FormatException('Invalid credential response');
      }
      setState(() {
        secret = data['apiKey'] as String;
        // The list re-reads in place; the rows already shown stay.
        listError = false;
      });
      unawaited(loadCredentials());
      return true;
    } on SecondFactorStepUpCancelled {
      // Closed "Verify it's you": nothing was created, nothing to say.
      return false;
    } catch (_) {
      // Neither error payloads nor successful responses are logged.
      if (live && opened == openedScope) setState(() => error = 'create');
      return false;
    } finally {
      requesting = false;
      if (live) setState(() => busy = false);
    }
  }

  Future<bool> revoke(String credentialId) async {
    if (requesting) return false;
    requesting = true;
    final opened = openedScope;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await w.client.request(
        'DELETE',
        '/agents/${Uri.encodeComponent(agentId)}/credentials/${Uri.encodeComponent(credentialId)}',
      );
      if (!live || opened != openedScope) return false;
      setState(() {
        credentials = [
          for (final c in credentials)
            c['id'] == credentialId
                ? {...c, 'revokedAt': DateTime.now().toUtc().toIso8601String()}
                : c,
        ];
        w.agentTabCache.put(_credentialsKey, _CredentialList(credentials));
      });
      return true;
    } catch (_) {
      // An ambiguous failure is not a revocation: the row stays.
      if (live && opened == openedScope) setState(() => error = 'revoke');
      return false;
    } finally {
      requesting = false;
      if (live) setState(() => busy = false);
    }
  }

  // ---------------------------------------------------------- actions

  void switchMethod() {
    final next = method.other;
    final before = Map<String, dynamic>.from(status);
    // The same credential works both ways: only the instructions and the
    // remembered method change; a failed save puts the old method back.
    widget.onStatus?.call({...status, 'externalSetupMethod': next.wire});
    final opened = openedScope;
    unawaited(
      w.client
          .request(
            'PUT',
            '/agents/${Uri.encodeComponent(agentId)}/external-setup-method',
            data: {'method': next.wire},
          )
          .then<void>(
            (_) {},
            onError: (Object _) {
              if (live && opened == openedScope) widget.onStatus?.call(before);
            },
          ),
    );
  }

  Future<void> afterCredentialChange() async {
    // Create and revoke change what the status says (connected, disconnected).
    await refreshStatus();
  }

  Future<void> onCreate() async {
    // Which credential a new one replaces is known only once the list is in.
    if (loading) return;
    // A new page credential replaces the page's earlier one, so it asks
    // first; a first one doesn't.
    final page = pageCredential;
    if (page != null) {
      await ask(_Confirm.replace, '${page['id']}');
    } else if (await create(null)) {
      await afterCredentialChange();
    }
  }

  Future<void> ask(_Confirm kind, String credentialId) async {
    final name = agentName;
    final replace = kind == _Confirm.replace;
    setState(() {
      confirm = kind;
      confirmId = credentialId;
    });
    final confirmed = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: replace ? 'Create a new credential?' : 'Revoke this credential?',
        message: raftFormat(
          context,
          replace
              ? "The credential created on this page stops working. Whatever signed in as {name} with it disconnects until you give it the new one."
              : "Whatever signed in as {name} with it stops working right away. This can't be undone.",
          {'name': name},
        ),
        confirmLabel: replace ? 'Create new credential' : 'Revoke',
        confirmVariant: replace
            ? RaftButtonRecipeVariant.warning
            : RaftButtonRecipeVariant.danger,
        confirmKey: ValueKey(
          replace
              ? 'external-agent-replace-confirm'
              : 'external-agent-revoke-confirm',
        ),
        surfaceKey: ValueKey(
          replace ? 'external-agent-replace' : 'external-agent-revoke',
        ),
        onConfirm: () async {
          if (replace) {
            await create(credentialId);
          } else {
            await revoke(credentialId);
          }
        },
      ),
    );
    if (mounted) {
      setState(() {
        confirm = null;
        confirmId = null;
      });
    }
    if (confirmed == true && live) await afterCredentialChange();
  }

  Future<void> openSdkGuide() => launchUrl(
    Uri.parse(raftSdkDocsUrl),
    mode: LaunchMode.externalApplication,
  );

  // ------------------------------------------------------------ build

  String get agentName {
    final display = widget.agent['displayName'];
    return display is String && display.isNotEmpty
        ? display
        : '${widget.agent['name'] ?? ''}';
  }

  String relative(BuildContext context, Object? iso) => iso is String
      ? resourceRelativeTime(
          iso,
          now: (widget.clock ?? DateTime.now)(),
          locale: Localizations.localeOf(context).toLanguageTag(),
        )
      : '';

  /// `formatDate(.., { dateStyle: "medium", timeStyle: "short" })`.
  String dateTime(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final wall = agentTimeFormatter(context, w).wallTime(date);
    return '${DateFormat.yMMMd(locale).format(wall)}, ${DateFormat.jm(locale).format(wall)}';
  }

  String date(BuildContext context, Object? raw) {
    final value = raw is String ? DateTime.tryParse(raw) : null;
    if (value == null) return '';
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale)
        .format(agentTimeFormatter(context, w).wallTime(value));
  }

  Widget statusCard(BuildContext context) {
    String tr(String s, [Map<String, Object?> v = const {}]) =>
        raftFormat(context, s, v);
    final name = agentName;
    final lastActivity = status['lastActivityAt'];
    final lastUsed = status['credentialLastUsedAt'];
    final lastActive = relative(context, lastActivity ?? lastUsed);
    final seenAt = widget.lastSeenAt ?? lastActivity ?? lastUsed;
    final lastSeen = relative(context, seenAt);
    final (RaftExternalLight, String, String, String?) line = switch (state) {
      ExternalConnectionState.online => (
        RaftExternalLight.online,
        tr('Online'),
        lastActive.isNotEmpty
            ? tr('Active {time}', {'time': lastActive})
            : tr('Signed in to Raft.'),
        null,
      ),
      ExternalConnectionState.offline => (
        RaftExternalLight.offline,
        lastSeen.isNotEmpty
            ? tr('Offline · last seen {time}', {'time': lastSeen})
            : tr('Offline'),
        tr("Still connected. Messages wait until it's back."),
        seenAt is String && DateTime.tryParse(seenAt) != null
            ? dateTime(context, DateTime.parse(seenAt))
            : null,
      ),
      ExternalConnectionState.disconnected => (
        RaftExternalLight.attention,
        tr('{name} is disconnected', {'name': name}),
        tr(
          'Its credentials were revoked. Create a new one and give it to {name} to reconnect.',
          {'name': name},
        ),
        null,
      ),
      ExternalConnectionState.notSignedIn => (
        RaftExternalLight.attention,
        tr('Waiting for {name} to connect…', {'name': name}),
        setupState == 'credential_minted'
            ? tr('This updates by itself when {name} signs in.', {'name': name})
            : tr(
                'It has no agent credential yet. Create one below and give it to {name}.',
                {'name': name},
              ),
        null,
      ),
    };
    final (light, title, hint, tooltip) = line;
    return RaftExternalStatusCard(
      key: ValueKey('external-agent-status-${state.name}'),
      light: light,
      title: title,
      hint: hint,
      titleTooltip: tooltip,
      titleKey: const ValueKey('external-agent-status-title'),
      toggleLabel: connected ? 'How it connects' : null,
      toggleKey: const ValueKey('external-agent-how-it-connects'),
      expanded: expanded,
      onToggle: () => setState(() => expanded = !expanded),
    );
  }

  Widget? credentialStep(BuildContext context) {
    final name = agentName;
    if (!canIssueCredentials && !connected) {
      // Someone who manages the agent but can't issue credentials is told who
      // can: its creator when a person made it, else the server's owners and
      // admins.
      final creator = widget.agent['creator'];
      final creatorName = creator is Map && creator['type'] == 'human'
          ? ('${creator['displayName'] ?? ''}'.isNotEmpty
                ? '${creator['displayName']}'
                : '${creator['name'] ?? ''}')
          : null;
      return KeyedSubtree(
        key: const ValueKey('external-agent-ask-credential'),
        child: RaftExternalNote(
          creatorName != null && creatorName.isNotEmpty
              ? raftFormat(context, 'Ask {name} for a credential.', {
                  'name': creatorName,
                })
              : raftText(
                  context,
                  'Ask a server owner or admin for a credential.',
                ),
        ),
      );
    }
    if (!canIssueCredentials || connected) return null;
    return RaftExternalCredentialStep(
      name: name,
      secret: secret,
      sdk: method == ExternalSetupMethod.sdk,
      createLabel: pageCredential != null
          ? 'Create new credential'
          : 'Create credential',
      showShownBefore: pageCredential != null,
      busy: busy,
      loading: loading,
      createError: error == 'create',
      onCreate: () => unawaited(onCreate()),
    );
  }

  List<RaftExternalCredentialRow> credentialRows(BuildContext context) => [
    for (final c in active)
      () {
        final kind = credentialTitleKind(c['name']);
        final title = switch (kind) {
          CredentialTitleKind.page => raftText(context, 'Created on this page'),
          CredentialTitleKind.named => '${c['name']}',
          CredentialTitleKind.unnamed => raftText(context, 'Agent credential'),
        };
        final created = date(context, c['createdAt']);
        final used = c['lastUsedAt'] is String
            ? raftFormat(context, 'Created {date} · last used {time}', {
                'date': created,
                'time': relative(context, c['lastUsedAt']),
              })
            : raftFormat(context, 'Created {date} · not used yet', {
                'date': created,
              });
        return RaftExternalCredentialRow(
          id: '${c['id']}',
          title: title,
          subtitle: used,
          canReplace: kind == CredentialTitleKind.page,
        );
      }(),
  ];

  @override
  Widget build(BuildContext context) {
    final summary = widget.hostedRuntime;
    final statusError = widget.statusError == null
        ? null
        : RaftExternalNote(
            raftText(context, widget.statusError!),
            small: true,
            topGap: 8,
          );
    if (summary == null && widget.status == null && statusError == null) {
      return const SizedBox.shrink();
    }
    return RaftPanelSection(
      gap: 0,
      children: [
        if (summary != null)
          RaftExternalHostedSection(
            connected: setupState == 'connected',
            child: AgentHostedRuntimeStatus(
              key: ValueKey('hosted-status-$agentId'),
              controller: w,
              agentId: agentId,
              summary: summary,
              onStatus: widget.onStatus ?? (_) {},
            ),
          )
        else if (widget.status != null)
          _connectionSection(context),
        ?statusError,
      ],
    );
  }

  Widget _connectionSection(BuildContext context) {
    final name = agentName;
    return RaftExternalConnectionSection(
      method: method.ui,
      status: statusCard(context),
      // Switching how it connects is offered only while it isn't
      // connected.
      switchLabel: connected
          ? null
          : method == ExternalSetupMethod.sdk
          ? 'Use an existing agent instead'
          : 'Build it with the SDK instead',
      onSwitch: switchMethod,
      steps: !connected || expanded
          ? ExternalAgentStepsView(
              method: method,
              name: name,
              agentId: agentId,
              agentName: '${widget.agent['name'] ?? ''}',
              serverUrl: w.client.origin,
              credentialStep: credentialStep(context),
              onOpenSdkGuide: () => unawaited(openSdkGuide()),
            )
          : null,
      below: [
        if (canIssueCredentials) ...[
          RaftExternalCredentialList(
            credentials: credentialRows(context),
            loading: loading,
            listError: listError,
            disabled: busy,
            onReplace: (id) => unawaited(ask(_Confirm.replace, id)),
            onRevoke: (id) => unawaited(ask(_Confirm.revoke, id)),
          ),
          if (error == 'revoke')
            Semantics(
              liveRegion: true,
              child: RaftExternalWarning(
                "Raft couldn't revoke the credential. Try again.",
                key: const ValueKey('external-agent-revoke-error'),
              ),
            ),
          if (error == 'create' && connected)
            Semantics(
              liveRegion: true,
              child: RaftExternalWarning(
                "Raft couldn't create a credential. Try again.",
                key: const ValueKey('external-agent-create-error'),
              ),
            ),
          if (secret != null && connected)
            RaftExternalCredentialStep(
              name: name,
              secret: secret,
              showHint: false,
            ),
        ],
      ],
    );
  }
}

/// The steps of how an external agent connects, with the prompt and the
/// starter code built for this agent and server (the page and the create
/// dialog show the same).
class ExternalAgentStepsView extends StatelessWidget {
  const ExternalAgentStepsView({
    super.key,
    this.keyPrefix = 'external-agent',
    required this.method,
    required this.name,
    required this.agentId,
    required this.agentName,
    required this.serverUrl,
    required this.onOpenSdkGuide,
    this.credentialStep,
  });
  final ExternalSetupMethod method;

  /// The name shown in copy; [agentName] is the handle the CLI profile slug
  /// is made from.
  final String name, agentId, agentName, serverUrl;
  final Widget? credentialStep;
  final VoidCallback onOpenSdkGuide;

  /// Prefix of the keys of the steps' parts.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => RaftExternalSetupSteps(
    keyPrefix: keyPrefix,
    method: method.ui,
    name: name,
    promptText: existingAgentPrompt(
      // Web `existingAgentPrompt(agent)`: the agent's `name`.
      name: agentName,
      id: agentId,
      serverUrl: serverUrl,
      tr: (source, [values = const {}]) => raftFormat(context, source, values),
    ),
    installCommand: sdkInstallCommand,
    starterCode: sdkStarterCode(serverUrl),
    credentialStep: credentialStep,
    onOpenSdkGuide: onOpenSdkGuide,
  );
}
