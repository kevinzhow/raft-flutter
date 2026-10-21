import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'slack_bridge_contract.dart';
import '../data/feature_flag_client_facts.dart';

class IMBridgesView extends StatefulWidget {
  const IMBridgesView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<IMBridgesView> createState() => _IMBridgesState();
}

class _IMBridgesState extends ManagementState<IMBridgesView> {
  @override
  WorkspaceController get w => widget.controller;
  SlackBridgeProjection? projection;
  bool enabled = false;
  static const base = '/slack-bridge/provisioning';
  @override
  void initState() {
    super.initState();
    startManagement();
  }

  // Wizard state (SlackBridgeSetupWizard's reducer).
  List<Map<String, String>> pairs = [];
  String raftChannelId = '', slackChannelId = '';
  bool disconnectConfirmed = false,
      editingMappings = false,
      // ignore: raft_lints/avoid_imperative_notice_state -- Wizard flag set after a partly failed confirmation batch; cleared with the other wizard state when the wizard resets and on the next attempt.
      partialFailure = false,
      inviteHelp = false,
      working = false;
  SlackBridgeProjection? mappingBaseline;

  @override
  void clearData() {
    projection = null;
    enabled = false;
    pairs = [];
    raftChannelId = slackChannelId = '';
    disconnectConfirmed = editingMappings = partialFailure = inviteHelp = false;
    mappingBaseline = null;
  }

  /// The reducer's `view` action: adopt [next] and reset the drafts.
  void adopt(SlackBridgeProjection next) {
    projection = next;
    disconnectConfirmed = false;
    editingMappings = false;
    mappingBaseline = null;
    partialFailure = false;
    pairs = [
      for (final p in next.rows('channelPairs'))
        {
          'raftChannelId': '${p['raftChannelId']}',
          'slackChannelId': '${p['slackChannelId']}',
        },
    ];
    if (next.stage == 'channels') {
      raftChannelId = next.rows('raftChannels').firstOrNull?['id'] as String? ?? '';
      slackChannelId = _firstMember(next);
    }
  }

  String _firstMember(SlackBridgeProjection p) =>
      p.rows('slackChannels').where((c) => c['isMember'] == true).firstOrNull?['id']
          as String? ??
      '';

  @override
  String get snapshotKey => 'im-bridges';
  @override
  Map<String, Object?> captureSnapshot() => {
    'projection': projection,
    'enabled': enabled,
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    final restored = fields['projection'] as SlackBridgeProjection?;
    if (restored != null) adopt(restored);
    projection = restored;
    enabled = fields['enabled'] as bool;
    return true;
  }

  @override
  Future<void> loadData(int request, int generation) async {
    final flags = managementMap(
      await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: ['slack_bridge_v0'],
          serverId: w.server?.id,
        ),
      ),
    );
    if (!accepts(generation, request)) return;
    enabled = managementRows(flags['evaluations'])
        .any((f) => f['key'] == 'slack_bridge_v0' && f['enabled'] == true);
    if (!enabled) {
      projection = null;
      return;
    }
    try {
      final next = SlackBridgeProjection.parse(await w.client.get(base));
      if (accepts(generation, request)) adopt(next);
    } on RaftApiException catch (e) {
      if (e.status == 503) {
        throw StateError(
          'Slack bridging is unavailable on this server. Ask your administrator to configure the Slack bridge runtime, then refresh.',
        );
      }
      rethrow;
    }
  }

  void checkScope(String scope) {
    if (!mounted ||
        authority != scope ||
        !w.can('manageIntegrations') ||
        !enabled) {
      throw StateError(
        'The active workspace or your permission changed. Refresh before continuing.',
      );
    }
  }

  Future<SlackBridgeProjection> update(
    Future<dynamic> Function() request,
    String scope,
  ) async {
    checkScope(scope);
    final next = SlackBridgeProjection.parse(await request());
    checkScope(scope);
    setState(() => adopt(next));
    return next;
  }

  Future<void> authorize(String scope) async {
    checkScope(scope);
    final a = projection?.oauthAuthority;
    if (projection?.stage != 'oauth' || a == null) {
      throw StateError('Refresh the Slack connection before authorizing.');
    }
    final url = SlackBridgeProjection.oauthUrl(
      await w.client.post('/slack-bridge/oauth/start', data: a),
    );
    checkScope(scope);
    await launchManaged(url);
  }

  /// `beginReauthorization`: reload the snapshot, then re-run Slack OAuth from
  /// its authority. A connect / oauth stage has nothing to reauthorize, so the
  /// fresh view is adopted instead of redirecting.
  Future<void> reauthorize(String scope) async {
    checkScope(scope);
    final next = SlackBridgeProjection.parse(await w.client.get(base));
    checkScope(scope);
    final a = next.oauthAuthority;
    if (a == null || next.stage == 'connect' || next.stage == 'oauth') {
      setState(() => adopt(next));
      return;
    }
    final url = SlackBridgeProjection.oauthUrl(
      await w.client.post('/slack-bridge/oauth/start', data: a),
    );
    checkScope(scope);
    await launchManaged(url);
  }

  Future<void> verifyAndEnable(String scope) async {
    final next = await update(() => w.client.post('$base/preflight'), scope);
    if (next.preflightPassed) {
      await update(() => w.client.post('$base/enable'), scope);
    }
  }

  // ------------------------------------------------------------ actions

  Future<void> connectAndAuthorize() => run(() async {
    final scope = authority;
    final next = await update(() => w.client.post('$base/connect'), scope);
    if (next.stage == 'oauth') await authorize(scope);
  }, refresh: false);

  bool get _pairsValid {
    final raft = <String>{}, slack = <String>{};
    if (pairs.isEmpty) return false;
    for (final p in pairs) {
      if (p['raftChannelId']!.isEmpty || p['slackChannelId']!.isEmpty) return false;
      if (!raft.add(p['raftChannelId']!) || !slack.add(p['slackChannelId']!)) {
        return false;
      }
    }
    return true;
  }

  bool _isMember(SlackBridgeProjection p, String id) =>
      p.rows('slackChannels').any((c) => c['id'] == id && c['isMember'] == true);

  void addPair() {
    final p = projection;
    if (p == null || !_isMember(p, slackChannelId) || raftChannelId.isEmpty) {
      return;
    }
    final candidate = [
      ...pairs,
      {'raftChannelId': raftChannelId, 'slackChannelId': slackChannelId},
    ];
    final saved = pairs;
    pairs = candidate;
    if (!_pairsValid) pairs = saved;
    setState(() {});
  }

  Future<void> refresh() => run(() async {
    final scope = authority;
    final next = SlackBridgeProjection.parse(await w.client.get(base));
    checkScope(scope);
    setState(() {
      if (editingMappings && next.stage == 'health') {
        projection = next;
        mappingBaseline = next;
        if (!next.rows('raftChannels').any((c) => c['id'] == raftChannelId)) {
          raftChannelId = next.rows('raftChannels').firstOrNull?['id'] as String? ?? '';
        }
        if (!_isMember(next, slackChannelId)) slackChannelId = _firstMember(next);
      } else {
        adopt(next);
      }
    });
  }, refresh: false);

  Future<void> finish() => run(() async {
    final scope = authority;
    if (editingMappings && mappingBaseline != null) {
      await applyManaged(scope);
    } else {
      await update(
        () => w.client.request(
          'PUT',
          '$base/channel-pairs',
          data: {'pairs': [for (final p in pairs) {...p}]},
        ),
        scope,
      );
      await verifyAndEnable(scope);
    }
  }, refresh: false);

  /// `applyManagedSlackBridgeChannelPairs`: removals by exact binding epoch,
  /// then the additions over the last response, then verify and enable.
  Future<void> applyManaged(String scope) async {
    final baseline = mappingBaseline!;
    String key(Map<String, dynamic> p) => '${p['raftChannelId']}\u0000${p['slackChannelId']}';
    final desired = {for (final p in pairs) key(p)};
    final baselinePairs = baseline.rows('channelPairs');
    final baselineKeys = baselinePairs.map(key).toSet();
    final removed = baselinePairs.where((p) => !desired.contains(key(p))).toList();
    final additions = pairs.where((p) => !baselineKeys.contains(key(p))).toList();
    if (removed.isEmpty && additions.isEmpty) {
      setState(() => adopt(baseline));
      return;
    }
    for (final p in removed) {
      if (p['bindingEpoch'] is! int) {
        throw StateError('Refresh before removing this channel pair.');
      }
    }
    var confirmed = 0;
    var current = baseline;
    try {
      for (final p in removed) {
        final next = await update(
          () => w.client.delete(
            '$base/channel-pairs',
            data: {
              'pairs': [
                {
                  'raftChannelId': p['raftChannelId'],
                  'slackChannelId': p['slackChannelId'],
                  'expectedBindingEpoch': p['bindingEpoch'],
                },
              ],
            },
          ),
          scope,
        );
        if (next.rows('channelPairs').any((q) => key(q) == key(p))) {
          throw StateError('Removal was not confirmed. Refresh before retrying.');
        }
        current = next;
        confirmed++;
      }
      if (additions.isEmpty) return;
      final currentKeys = current.rows('channelPairs').map(key).toSet();
      final fresh = [
        for (final p in current.rows('channelPairs'))
          {'raftChannelId': p['raftChannelId'], 'slackChannelId': p['slackChannelId']},
        for (final p in pairs)
          if (!currentKeys.contains(key(p))) {...p},
      ];
      await update(
        () => w.client.request('PUT', '$base/channel-pairs', data: {'pairs': fresh}),
        scope,
      );
      await verifyAndEnable(scope);
      if (projection?.preflightPassed != true) {
        throw StateError('slack_bridge_preflight_failed');
      }
    } catch (_) {
      if (confirmed > 0) partialFailure = true;
      rethrow;
    }
  }

  Future<void> enable() => run(() async {
    final scope = authority;
    if (projection?.preflightPassed == true) {
      await update(() => w.client.post('$base/enable'), scope);
    } else {
      await verifyAndEnable(scope);
    }
  }, refresh: false);

  Future<void> verify() =>
      run(() => verifyAndEnable(authority), refresh: false);

  Future<void> disconnect() => run(() async {
    final scope = authority;
    await update(
      () => w.client.post(
        '$base/disconnect',
        data: {'expectedConnectionEpoch': projection?.connectionEpoch},
      ),
      scope,
    );
  }, refresh: false);

  void manage() {
    final p = projection;
    if (p == null) return;
    setState(() {
      editingMappings = true;
      pairs = [
        for (final c in p.rows('channelPairs'))
          {
            'raftChannelId': '${c['raftChannelId']}',
            'slackChannelId': '${c['slackChannelId']}',
          },
      ];
      slackChannelId = _firstMember(p);
      mappingBaseline = p;
    });
  }

  // ------------------------------------------------------------ projection

  /// `projectSlackBridgeHealth`: product state, reason copy and next action.
  (String state, String reason, String action) health(SlackBridgeProjection p) {
    final reason = p.healthReason;
    return switch (reason) {
      'install_missing' => ('disconnected', _reasons[reason]!, 'Connect Slack'),
      'oauth_pending' => ('unverified', _reasons[reason]!, 'Finish OAuth'),
      'reauth_required' => ('degraded', _reasons[reason]!, 'Reauthorize Slack'),
      'disconnected' => (
        'disconnected',
        p.health['install']?['state'] == 'revoked'
            ? 'The Slack install was revoked.'
            : _reasons[reason]!,
        'Reconnect Slack',
      ),
      'quarantined' => ('degraded', _reasons[reason]!, 'Ask an operator to resolve quarantine'),
      'credential_missing' => ('unverified', _reasons[reason]!, 'Verify credential persistence'),
      'credential_unverified' => ('unverified', _reasons[reason]!, 'Verify credential persistence'),
      'credential_revoked' => ('disconnected', _reasons[reason]!, 'Reauthorize Slack'),
      'binding_required' => ('unverified', _reasons[reason]!, 'Configure a channel pair'),
      'binding_quarantined' => ('degraded', _reasons[reason]!, 'Ask an operator to resolve quarantine'),
      'binding_revoked' => ('degraded', _reasons[reason]!, 'Repair the revoked binding'),
      'binding_paused' => ('degraded', _reasons[reason]!, 'Resume the paused binding'),
      'audience_mismatch' => ('degraded', _reasons[reason]!, 'Repair the channel audience'),
      'audience_unverified' => ('unverified', 'The channel audience could not be read.', 'Retry verification'),
      'connection_unverified' => ('degraded', 'The hosted connection check failed.', 'Reconnect Slack'),
      'scope_unverified' => ('degraded', _reasons[reason]!, 'Reauthorize Slack'),
      'verification_required' => ('unverified', 'The current bridge state has not been verified.', 'Retry verification'),
      'healthy' => ('connected', _reasons[reason]!, 'No action needed'),
      _ => ('unverified', 'The current bridge state has not been verified.', 'Retry verification'),
    };
  }

  String _lastVerified(String iso) {
    final t = DateTime.parse(iso).toUtc();
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[t.month - 1]} ${t.day}, ${t.year}, $hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final p = projection;
    final manage = enabled && w.can('manageIntegrations');
    // IMBridgesSettingsSection renders nothing while the flag is off.
    if (!loading && !enabled && error == null) {
      return const SizedBox.shrink();
    }
    final failedLoad = error != null && p == null;
    Widget? wizard;
    if (p != null && enabled) {
      String name(String list, String id) =>
          p.rows(list).where((c) => c['id'] == id).firstOrNull?['name'] as String? ?? id;
      String pairLabel(Map<String, dynamic> pair) => raftFormat(
        context,
        '#{raftName} ↔ #{slackName}',
        {
          'raftName': name('raftChannels', '${pair['raftChannelId']}'),
          'slackName': name('slackChannels', '${pair['slackChannelId']}'),
        },
      );
      final slack = p.rows('slackChannels');
      final stage = RaftSlackStage.values.byName(p.stage);
      final (healthState, healthReason, healthAction) = health(p);
      final bindingKeys = p.rows('channelPairs');
      final membershipIssues = [
        for (final pair in bindingKeys)
          slack.where((c) => c['id'] == pair['slackChannelId']).firstOrNull,
      ].where((c) => c == null || c['isMember'] != true).toList();
      final missing = membershipIssues.whereType<Map<String, dynamic>>().where((c) => c['isMember'] == false).toList();
      final unknown = membershipIssues.any((c) => c == null || c['isMember'] == null);
      final recovery = healthReason == _reasons['audience_mismatch'] && membershipIssues.isNotEmpty;
      final disconnectable = manage &&
          p.stage != 'connect' &&
          p.health['install']?['state'] != 'revoked' &&
          p.connectionEpoch != null;
      final checks = p.snapshot['preflight'] == null
          ? const <RaftSlackCheck>[]
          : [
              for (final id in const ['oauth', 'endpoint', 'scope', 'audience'])
                (
                  // ignore: raft_lints/avoid_render_index_assertion -- _checkLabels covers every check id the projection can emit (SlackBridgeProjection.parse fails closed).
                  label: _checkLabels[id]!,
                  state: ((p.snapshot['preflight']['checks'] as List)
                          .cast<Map<String, dynamic>>()
                          .where((c) => c['id'] == id)
                          .firstOrNull?['state'] as String?) ??
                      'unverified',
                ),
            ];
      final managedPairs = editingMappings || stage == RaftSlackStage.channels;
      wizard = RaftSlackWizardView(
        stage: editingMappings && stage == RaftSlackStage.health
            ? RaftSlackStage.channels
            : stage,
        canManage: manage,
        busy: busy,
        workspaceName: p.snapshot['workspaceName'] as String?,
        errorMessage: error == null
            ? null
            : partialFailure
            ? 'Some channel mappings were removed, but the remaining bridge changes did not finish. Reload the current mappings before retrying.'
            : 'The Slack bridge operation failed. No setup state was assumed.',
        onConnect: connectAndAuthorize,
        onAuthorize: () => run(() => authorize(authority), refresh: false),
        availableCount: slack.where((c) => c['isMember'] == true).length,
        inviteRequiredCount: slack.where((c) => c['isMember'] != true).length,
        raftOptions: [
          for (final c in p.rows('raftChannels'))
            (value: '${c['id']}', label: '#${c['name']}', enabled: true),
        ],
        raftValue: raftChannelId,
        onRaft: (v) => setState(() => raftChannelId = v),
        slackOptions: [
          for (final c in slack)
            (
              value: '${c['id']}',
              label: c['isMember'] == true
                  ? '#${c['name']}'
                  : raftFormat(context, '#{name} — invite the Raft app in Slack', {'name': c['name']}),
              enabled: c['isMember'] == true,
            ),
        ],
        slackValue: slackChannelId,
        onSlack: (v) => setState(() => slackChannelId = v),
        canAddPair: raftChannelId.isNotEmpty && slackChannelId.isNotEmpty && _isMember(p, slackChannelId),
        onAddPair: addPair,
        onRefresh: refresh,
        pairLabels: [for (final pair in managedPairs ? pairs : p.rows('channelPairs')) pairLabel(pair)],
        onRemovePair: (i) => setState(() => pairs = [...pairs]..removeAt(i)),
        pairInvalid: !(editingMappings && pairs.isEmpty
            ? true
            // ignore: raft_lints/avoid_render_index_assertion -- Channel pair rows always carry both ids (the pair editor and parse fill them).
            : _pairsValid && pairs.every((pair) => _isMember(p, pair['slackChannelId']!))),
        finishLabel: editingMappings ? 'Apply mapping changes' : 'Save mappings and enable',
        finishEnabled: (editingMappings && pairs.isEmpty
                ? true
                // ignore: raft_lints/avoid_render_index_assertion -- Channel pair rows always carry both ids (the pair editor and parse fill them).
                : _pairsValid && pairs.every((pair) => _isMember(p, pair['slackChannelId']!))) &&
            (!editingMappings || mappingBaseline != null),
        onFinish: finish,
        checks: checks,
        preflightPassed: p.preflightPassed,
        onVerify: verify,
        onEnable: enable,
        healthState: healthState,
        healthReason: healthReason,
        healthAction: healthAction,
        lastVerified: p.health['lastVerifiedAt'] == null ? null : _lastVerified('${p.health['lastVerifiedAt']}'),
        failingSurface: _surfaces['${p.health['failingSurface']}'],
        recoveryTitle: recovery
            ? (unknown ? 'Slack channel access needs attention' : 'Slack channel access was removed')
            : null,
        recoveryDescription: recovery
            ? (unknown
                  ? 'Message sync is paused because Raft could not verify access to a mapped Slack channel. Confirm that the Raft app is still in the channel, then refresh and recheck.'
                  : raftFormat(context, 'Message sync is paused for {channels}. Invite the Raft app back to the affected channel, then refresh and recheck.', {
                      'channels': missing.map((c) => '#${c['name']}').join(', '),
                    }))
            : null,
        inviteStepsOpen: inviteHelp,
        onToggleInviteSteps: () => setState(() => inviteHelp = !inviteHelp),
        onManage: manage ? this.manage : null,
        canDisconnect: disconnectable,
        disconnectConfirming: disconnectConfirmed,
        onDisconnect: () => setState(() => disconnectConfirmed = true),
        onDisconnectCancel: () => setState(() => disconnectConfirmed = false),
        onDisconnectConfirm: disconnect,
        onReauthorize: disconnectable && p.stage != 'oauth'
            ? () => run(() => reauthorize(authority), refresh: false)
            : null,
      );
    }
    return ListView(
      primary: false,
      padding: raftScrollPadding(context, RaftSettingsPanelFrame.contentInset),
      children: [
        RaftMessagingBridgesSection(
          failed: failedLoad,
          child: loading && p == null
              ? const RaftSkeleton(height: 48)
              : wizard,
        ),
      ],
    );
  }
}

const _checkLabels = {
  'oauth': 'OAuth grant',
  'endpoint': 'Hosted endpoint',
  'scope': 'Granted scopes',
  'audience': 'Channel audience',
};
const _surfaces = {
  'install': 'Install',
  'credential': 'Credential',
  'binding': 'Channel binding',
  'audience': 'Channel audience',
  'connection': 'Connection',
  'scope': 'OAuth scope',
};
const _reasons = {
  'healthy': 'The install, credential, bindings, and audience are verified.',
  'install_missing': 'No Slack install exists for this server.',
  'oauth_pending': 'Slack authorization has not completed.',
  'reauth_required': 'The install needs a new Slack authorization.',
  'disconnected': 'The Slack install is disconnected.',
  'quarantined': 'The install is quarantined and needs operator review.',
  'credential_missing': 'No active bridge credential is available.',
  'credential_unverified': 'Credential persistence could not be confirmed.',
  'credential_revoked': 'The bridge credential was revoked.',
  'binding_required': 'At least one channel pair is required.',
  'binding_paused': 'A channel binding is paused.',
  'binding_revoked': 'A channel binding was revoked.',
  'binding_quarantined': 'A channel binding is quarantined.',
  'audience_mismatch': 'The Raft app is not in a mapped Slack channel, or the verified channel audience does not match the binding.',
  'scope_unverified': 'The installed OAuth scopes do not match the required grant.',
};
