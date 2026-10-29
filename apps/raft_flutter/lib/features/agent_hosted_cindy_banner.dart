// Web components/agent/HostedCindyFailedBanner.tsx: in a hosted Cindy's DM,
// once she could not start (the server's 3-minute timeout and its one
// automatic retry are both behind her), say so and offer the computer path.
// The button opens the onboarding Create Cindy dialog, which connects a
// computer first when there is none; its create converts her in place into a
// computer Cindy. `GET /agents/:id/hosted-runtime` carries `onboardingSetup`
// (`usable` | `failed` | null); the server flips it to `failed` after its
// timeout, so the state is read again every minute.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'managed_agent_launcher.dart';
import 'private_route_guard.dart' show workspaceAuthority;

const hostedCindyRecheck = Duration(seconds: 60);

String hostedRuntimeStatePath(String agentId) =>
    '/agents/${Uri.encodeComponent(agentId)}/hosted-runtime';

/// The server's onboarding agent that is an external agent without a
/// computer: Cindy running in the cloud.
bool isHostedCindyCandidate(
  WorkspaceController w,
  Map<String, dynamic>? agent,
) =>
    agent != null &&
    agent['id'] is String &&
    w.server?.string('onboardingAgentId') == agent['id'] &&
    agent['external'] == true &&
    agent['machineId'] is! String;

class HostedCindyFailedBanner extends StatefulWidget {
  const HostedCindyFailedBanner({
    super.key,
    required this.controller,
    required this.agent,
  });

  final WorkspaceController controller;
  final Map<String, dynamic> agent;

  @override
  State<HostedCindyFailedBanner> createState() =>
      _HostedCindyFailedBannerState();
}

class _HostedCindyFailedBannerState extends State<HostedCindyFailedBanner> {
  WorkspaceController get w => widget.controller;
  RaftForegroundPeriodic? _poll;
  bool _failed = false, _dialogOpen = false, _disposed = false;
  int _request = 0;

  String get _id => '${widget.agent['id']}';

  @override
  void initState() {
    super.initState();
    _poll = RaftForegroundPeriodic(
      hostedCindyRecheck,
      () => unawaited(_recheck()),
    );
    unawaited(_recheck());
  }

  @override
  void didUpdateWidget(HostedCindyFailedBanner old) {
    super.didUpdateWidget(old);
    if (old.agent['id'] != widget.agent['id']) {
      _failed = false;
      unawaited(_recheck());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.dispose();
    super.dispose();
  }

  Future<void> _recheck() async {
    final request = ++_request;
    final authority = workspaceAuthority(w);
    final id = _id;
    bool failed;
    try {
      final data = await w.client.get(hostedRuntimeStatePath(id));
      failed = data is Map && data['onboardingSetup'] == 'failed';
    } catch (_) {
      // Not a manager of this agent, or the status is unavailable: no banner.
      failed = false;
    }
    if (_disposed ||
        request != _request ||
        id != _id ||
        authority != workspaceAuthority(w)) {
      return;
    }
    if (failed != _failed) setState(() => _failed = failed);
  }

  Future<void> _connectComputer() async {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    try {
      await showManagedAgentForm(
        context,
        w,
        onboarding: true,
        onConnectComputer: () => w.setSection('computers'),
      );
    } finally {
      if (mounted) {
        setState(() => _dialogOpen = false);
        // The create converted her in place: read the agents and the state.
        w.services.entityDirectory.reloadAgents();
        unawaited(_recheck());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_failed || !isHostedCindyCandidate(w, widget.agent)) {
      return const SizedBox.shrink();
    }
    final name = '${widget.agent['displayName'] ?? widget.agent['name'] ?? ''}';
    return RaftBanner(
      key: const ValueKey('hosted-cindy-failed-banner'),
      glyph: RaftGlyph.triangleAlert,
      description: raftFormat(
        context,
        "{name} couldn't start in the cloud. Connect a computer to run her there instead.",
        {'name': name},
      ),
      action: RaftRecipeButton(
        key: const ValueKey('hosted-cindy-connect-computer'),
        label: raftText(context, 'Connect a computer'),
        size: RaftButtonRecipeSize.sm,
        onPressed: _dialogOpen ? null : () => unawaited(_connectComputer()),
      ),
    );
  }
}
