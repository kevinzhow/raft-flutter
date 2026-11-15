// Create an external agent in one dialog (Web v1.24 features/agent/
// CreateExternalAgentDialog.tsx). Step 1: name, description and how it will
// run (an existing agent through the Raft CLI, or a program of your own with
// the SDK). Next makes the agent and its one agent credential; step 2 shows
// how to connect it while it waits for the first sign-in. Both ways use the
// same credential; switching only changes the instructions. Cancel before it
// connects discards the agent and its credential.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/external_agent_setup_text.dart';
import '../data/raft_location.dart' show RaftProfileKind;
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'agent_archive_requests.dart' show archiveAgent;
import '../data/agent_archive.dart' show AgentArchiveWorkspaceChoice;
import 'external_agent_setup.dart'
    show ExternalAgentStepsView, ExternalSetupMethodUi, externalSetupMethodOfUi;
import 'private_route_guard.dart' show workspaceAuthority;
import 'second_factor_step_up.dart';

/// Opens the create external agent dialog. [onCreated] runs when the list of
/// agents changed (the agent was made, or discarded again); [onOpenAgent]
/// opens the agent's page (Done), by default its profile.
Future<void> showCreateExternalAgentDialog(
  BuildContext context,
  WorkspaceController w, {
  Future<void> Function()? onCreated,
  void Function(String agentId)? onOpenAgent,
  bool Function()? authorized,
  math.Random? random,
}) async {
  final authority = workspaceAuthority(w);
  bool valid() =>
      context.mounted &&
      authority == workspaceAuthority(w) &&
      w.can('createAgents') &&
      (authorized?.call() ?? true);
  if (!valid()) return;
  await showRaftForm<void>(
    context,
    // Web `DialogCard`: no scrim close, and no "Discard your changes?" ask
    // (leaving a made agent has its own confirmation).
    dismissible: false,
    guardUnsaved: false,
    builder: (_) => CreateExternalAgentDialog(
      controller: w,
      authorized: valid,
      onCreated: onCreated,
      onOpenAgent:
          onOpenAgent ?? (id) => w.openProfile(RaftProfileKind.agent, id),
      random: random,
    ),
  );
}

/// The two things the dialog keeps of the agent it made.
typedef _Created = ({String id, String name});

class CreateExternalAgentDialog extends StatefulWidget {
  const CreateExternalAgentDialog({
    super.key,
    required this.controller,
    required this.authorized,
    this.onCreated,
    this.onOpenAgent,
    this.random,
  });
  final WorkspaceController controller;

  /// Whether the account, workspace and permission this opened under still
  /// hold.
  final bool Function() authorized;
  final Future<void> Function()? onCreated;
  final void Function(String agentId)? onOpenAgent;
  final math.Random? random;

  @override
  State<CreateExternalAgentDialog> createState() =>
      _CreateExternalAgentDialogState();
}

class _CreateExternalAgentDialogState extends State<CreateExternalAgentDialog> {
  WorkspaceController get w => widget.controller;
  final name = TextEditingController(), description = TextEditingController();
  final nameFocus = FocusNode();
  ExternalSetupMethod method = ExternalSetupMethod.existingAgent;
  _Created? created;
  String? credential;
  bool connected = false, busy = false, retired = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next Next starts or the agent is discarded; the dialog state is dropped when it closes.
  String? error;
  RaftForegroundPeriodic? _poll;
  bool _polling = false, _discarded = false;
  late final Object _openedAuthority = workspaceAuthority(w);

  bool get current =>
      mounted &&
      !retired &&
      widget.authorized() &&
      _openedAuthority == workspaceAuthority(w);

  @override
  void initState() {
    super.initState();
    w.addListener(_workspaceChanged);
    // The keyboard comes up by itself only where there is no touch screen to
    // cover it (RaftInteraction, never the width).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !RaftInteraction.of(context).touch) {
        nameFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    w.removeListener(_workspaceChanged);
    _poll?.dispose();
    name.dispose();
    description.dispose();
    nameFocus.dispose();
    super.dispose();
  }

  void _workspaceChanged() {
    if (retired ||
        widget.authorized() && _openedAuthority == workspaceAuthority(w)) {
      return;
    }
    // The account or workspace changed: the agent (if any) belongs to the
    // previous one, and this dialog's requests would reach the new one.
    retired = true;
    _poll?.dispose();
    _poll = null;
    final route = ModalRoute.of(context);
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
  }

  // ------------------------------------------------------------ step 2 poll

  /// Step 2 asks until the agent signs in (any of its credentials used).
  void _syncPoll() {
    if (created != null && !connected && current) {
      if (_poll == null) {
        _poll = RaftForegroundPeriodic(
          externalStatusPollInterval,
          () => unawaited(_tick()),
        );
        unawaited(_tick());
      }
    } else {
      _poll?.dispose();
      _poll = null;
    }
  }

  Future<void> _tick() async {
    final agent = created;
    if (agent == null || _polling) return;
    _polling = true;
    try {
      final status = await w.client.get(
        '/agents/${Uri.encodeComponent(agent.id)}/external-status',
      );
      if (!current || created?.id != agent.id) return;
      if (status is Map && status['setupState'] == 'connected') {
        setState(() => connected = true);
        _syncPoll();
      }
    } catch (_) {
      // A missed poll is retried on the next tick.
    } finally {
      _polling = false;
    }
  }

  // ------------------------------------------------------------ requests

  Future<void> _saveMethod(String agentId, ExternalSetupMethod next) =>
      w.client.request(
        'PUT',
        '/agents/${Uri.encodeComponent(agentId)}/external-setup-method',
        data: {'method': next.wire},
      );

  Future<void> _reload() async {
    try {
      await widget.onCreated?.call();
    } catch (_) {}
  }

  Future<void> next() async {
    if (name.text.trim().isEmpty || busy) return;
    final chosen = method;
    setState(() {
      busy = true;
      error = null;
    });
    _Created? agent;
    try {
      final random = widget.random ?? math.Random();
      final made = await w.command(
        'POST',
        '/agents',
        data: {
          'name': name.text.trim(),
          if (description.text.trim().isNotEmpty)
            'description': description.text.trim(),
          'avatarUrl':
              'pixel:${raftAgentAvatarChoices[random.nextInt(raftAgentAvatarChoices.length)]}',
          'external': true,
        },
      );
      if (made is! Map || made['id'] is! String) {
        throw const FormatException('Invalid agent response');
      }
      // The account changed while the request ran: nothing more is sent
      // from this dialog (its requests would reach the new account).
      if (!current) return;
      final fresh = (
        id: made['id'] as String,
        name: '${made['name'] ?? name.text.trim()}',
      );
      agent = fresh;
      await _saveMethod(fresh.id, chosen);
      if (!mounted) return;
      // Two-step verification on: "Verify it's you" first, then the same
      // request once more.
      final data = await withSecondFactorStepUp(
        context,
        w.client,
        () => w.client.post(
          '/agents/${Uri.encodeComponent(fresh.id)}/credentials',
          data: <String, dynamic>{'name': pageCredentialName},
        ),
        reason: StepUpReason.agentKey,
      );
      if (data is! Map ||
          data['apiKey'] is! String ||
          !(data['apiKey'] as String).startsWith('sk_agent_')) {
        throw const FormatException('Invalid credential response');
      }
      if (!current) return;
      setState(() {
        created = fresh;
        credential = data['apiKey'] as String;
      });
      _syncPoll();
      unawaited(_reload());
    } catch (e) {
      // Nothing is left behind: an agent made before the failure is
      // discarded again (Cancel leaves nothing).
      final made = agent;
      if (made != null) {
        try {
          await archiveAgent(w, made.id, AgentArchiveWorkspaceChoice.keep);
        } catch (_) {}
        unawaited(_reload());
      }
      if (mounted && !isSecondFactorStepUpCancelled(e)) {
        setState(
          () => error = userErrorText(
            e,
            fallback: "Raft couldn't create the agent. Try again.",
            where: 'create external agent',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void switchMethod() {
    final agent = created;
    if (agent == null) return;
    final target = method.other;
    setState(() => method = target);
    // The same credential works both ways: only the instructions and the
    // remembered method change.
    unawaited(
      _saveMethod(agent.id, target).then<void>((_) {}, onError: (_) {}),
    );
  }

  void finish() {
    final agent = created;
    if (agent != null) {
      try {
        widget.onOpenAgent?.call(agent.id);
      } catch (_) {
        // stay where the person is
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  void handleClose() {
    if (busy) return;
    // Once made, closing before it connects asks first; connected, closing
    // is Done.
    if (created != null && !connected) {
      unawaited(askDiscard());
    } else if (created != null) {
      finish();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> askDiscard() async {
    final agent = created;
    if (agent == null) return;
    final answered = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: raftFormat(context, 'Discard {name}?', {'name': agent.name}),
        message: 'The agent and its credential are deleted. Nothing is kept.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep setting up',
        confirmKey: const ValueKey('create-external-agent-discard-confirm'),
        surfaceKey: const ValueKey('create-external-agent-discard'),
        onConfirm: () => discard(agent),
      ),
      overModal: true,
    );
    // The confirmation closed on top of this dialog; a discard that went
    // through closes this one too.
    if (answered == true && _discarded && mounted) Navigator.of(context).pop();
  }

  Future<void> discard(_Created agent) async {
    if (_discarded) return;
    _discarded = true;
    try {
      await archiveAgent(w, agent.id, AgentArchiveWorkspaceChoice.keep);
    } catch (_) {
      // Back to the setup with the failure said there, as Web does.
      _discarded = false;
      if (mounted) {
        setState(
          () => error = raftText(
            context,
            "Raft couldn't discard the agent. Try again, or delete it from its page.",
          ),
        );
      }
      return;
    }
    unawaited(_reload());
    _poll?.dispose();
    _poll = null;
  }

  // ------------------------------------------------------------ build

  Future<void> _openSdkGuide() => launchUrl(
    Uri.parse(raftSdkDocsUrl),
    mode: LaunchMode.externalApplication,
  );

  Widget _footer(BuildContext context) {
    final agent = created;
    if (agent == null) {
      return ListenableBuilder(
        listenable: name,
        builder: (context, _) => RaftAgentDialogFooter(
          children: [
            RaftAgentDialogButton(
              key: const ValueKey('create-external-agent-cancel-form'),
              label: 'Cancel',
              onPressed: busy ? null : () => Navigator.of(context).pop(),
            ),
            RaftAgentDialogButton(
              key: const ValueKey('create-external-agent-next'),
              label: 'Next',
              primary: true,
              busy: busy,
              onPressed: name.text.trim().isEmpty || busy
                  ? null
                  : () => unawaited(next()),
            ),
          ],
        ),
      );
    }
    return RaftExternalSetupFooter(
      note: connected ? null : 'You can finish connecting later.',
      children: [
        if (!connected)
          RaftAgentDialogButton(
            key: const ValueKey('create-external-agent-cancel'),
            label: 'Cancel',
            onPressed: () => unawaited(askDiscard()),
          ),
        RaftAgentDialogButton(
          key: const ValueKey('create-external-agent-done'),
          label: 'Done',
          primary: connected,
          onPressed: finish,
        ),
      ],
    );
  }

  Widget _setup(BuildContext context, _Created agent) {
    String tr(String s) => raftFormat(context, s, {'name': agent.name});
    const prefix = 'create-external-agent';
    return RaftExternalSetupBody(
      error: error,
      // Waiting needs someone to act: orange, as every "needs action" state.
      status: RaftExternalStatusCard(
        key: ValueKey('$prefix-status-${connected ? 'online' : 'waiting'}'),
        light: connected
            ? RaftExternalLight.online
            : RaftExternalLight.attention,
        title: tr(
          connected ? '{name} is online' : 'Waiting for {name} to connect…',
        ),
        hint: tr(
          connected
              ? '{name} signed in to Raft. You can close this.'
              : 'This updates by itself when {name} signs in.',
        ),
      ),
      switchLabel: connected
          ? null
          : method == ExternalSetupMethod.sdk
          ? 'Use an existing agent instead'
          : 'Build it with the SDK instead',
      onSwitch: switchMethod,
      steps: connected
          ? null
          : ExternalAgentStepsView(
              keyPrefix: prefix,
              method: method,
              name: agent.name,
              agentId: agent.id,
              agentName: agent.name,
              serverUrl: w.client.origin,
              onOpenSdkGuide: () => unawaited(_openSdkGuide()),
              credentialStep: RaftExternalCredentialStep(
                name: agent.name,
                secret: credential,
                secretKey: const ValueKey('create-external-agent-credential'),
                sdk: method == ExternalSetupMethod.sdk,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agent = created;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) handleClose();
      },
      child: RaftDialog.agent(
        key: ValueKey(
          agent == null
              ? 'create-external-agent-dialog'
              : 'create-external-agent-setup',
        ),
        title: agent == null
            ? 'Create external agent'
            : raftFormat(context, 'Set up {name}', {'name': agent.name}),
        onClose: handleClose,
        maxWidth: agent == null ? null : 672,
        footerGap: 16,
        footer: _footer(context),
        children: [
          if (agent == null)
            RaftExternalCreateForm(
              name: name,
              description: description,
              method: method.ui,
              nameFocus: nameFocus,
              error: error,
              enabled: !busy,
              onMethod: (value) =>
                  setState(() => method = externalSetupMethodOfUi(value)),
            )
          else
            _setup(context, agent),
        ],
      ),
    );
  }
}
