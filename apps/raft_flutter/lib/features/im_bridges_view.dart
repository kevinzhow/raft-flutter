import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'slack_bridge_contract.dart';

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

  @override
  void clearData() {
    projection = null;
    enabled = false;
  }

  @override
  String get snapshotKey => 'im-bridges';
  @override
  Map<String, Object?> captureSnapshot() => {
    'projection': projection,
    'enabled': enabled,
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    projection = fields['projection'] as SlackBridgeProjection?;
    enabled = fields['enabled'] as bool;
    return true;
  }

  @override
  Future<void> loadData(int request, int generation) async {
    final flags = managementMap(
      await w.client.post(
        '/feature-flags/evaluate',
        data: {
          'keys': ['slack_bridge_v0'],
          'serverId': w.server?.id,
          'platform': defaultTargetPlatform == TargetPlatform.android
              ? 'mobile'
              : 'web',
        },
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
      if (accepts(generation, request)) projection = next;
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
    setState(() => projection = next);
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

  Future<void> verifyAndEnable(String scope) async {
    final next = await update(() => w.client.post('$base/preflight'), scope);
    if (next.preflightPassed) {
      await update(() => w.client.post('$base/enable'), scope);
    }
  }

  Future<void> addPair() async {
    final scope = authority;
    final current = await update(() => w.client.get(base), scope);
    final raft = current
        .rows('raftChannels')
        .where(
          (c) => !current
              .rows('channelPairs')
              .any((p) => p['raftChannelId'] == c['id']),
        )
        .toList();
    final slack = current
        .rows('slackChannels')
        .where(
          (c) =>
              c['isMember'] == true &&
              !current
                  .rows('channelPairs')
                  .any((p) => p['slackChannelId'] == c['id']),
        )
        .toList();
    if (raft.isEmpty || slack.isEmpty) {
      throw StateError(
        'No unpaired channels are available. Invite @Raft to the Slack channel, then refresh.',
      );
    }
    await form(
      'Add channel pair',
      [
        RaftFormField(
          'raftChannelId',
          'Raft channel',
          choices: {for (final c in raft) '${c['id']}': '${c['name']}'},
        ),
        RaftFormField(
          'slackChannelId',
          'Slack channel',
          choices: {
            for (final c in slack)
              '${c['id']}': '${c['name']} (${c['privacyClass'] ?? 'unknown'})',
          },
        ),
      ],
      (v) async {
        final fresh = await update(() => w.client.get(base), scope);
        if (fresh
                .rows('channelPairs')
                .any(
                  (p) =>
                      p['raftChannelId'] == v['raftChannelId'] ||
                      p['slackChannelId'] == v['slackChannelId'],
                ) ||
            !fresh
                .rows('raftChannels')
                .any((c) => c['id'] == v['raftChannelId']) ||
            !fresh
                .rows('slackChannels')
                .any(
                  (c) =>
                      c['id'] == v['slackChannelId'] && c['isMember'] == true,
                )) {
          throw StateError(
            'Channel availability changed. Refresh and choose again.',
          );
        }
        await update(
          () => w.client.request(
            'PUT',
            '$base/channel-pairs',
            data: {
              'pairs': [
                for (final p in fresh.rows('channelPairs'))
                  {
                    'raftChannelId': p['raftChannelId'],
                    'slackChannelId': p['slackChannelId'],
                  },
                {
                  'raftChannelId': v['raftChannelId'],
                  'slackChannelId': v['slackChannelId'],
                },
              ],
            },
          ),
          scope,
        );
        await verifyAndEnable(scope);
      },
      submit: 'Save',
    );
  }

  Future<void> removePair(Map<String, dynamic> pair) async {
    final scope = authority, epoch = pair['bindingEpoch'];
    if (epoch is! int) {
      throw StateError('Refresh before removing this channel pair.');
    }
    await confirm(
      'Remove channel pair?',
      'Messages will stop bridging between these channels.',
      () async {
        final next = await update(
          () => w.client.delete(
            '$base/channel-pairs',
            data: {
              'pairs': [
                {
                  'raftChannelId': pair['raftChannelId'],
                  'slackChannelId': pair['slackChannelId'],
                  'expectedBindingEpoch': epoch,
                },
              ],
            },
          ),
          scope,
        );
        if (next
            .rows('channelPairs')
            .any(
              (p) =>
                  p['raftChannelId'] == pair['raftChannelId'] &&
                  p['slackChannelId'] == pair['slackChannelId'],
            )) {
          throw StateError(
            'Removal was not confirmed. Refresh before retrying.',
          );
        }
        if (next.rows('channelPairs').isNotEmpty) await verifyAndEnable(scope);
      },
      submit: 'Remove',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = projection;
    final manage = enabled && w.can('manageIntegrations');
    String channelName(String key, dynamic id) =>
        p?.rows(key).where((c) => c['id'] == id).firstOrNull?['name']
            as String? ??
        '$id';
    return page('IM Bridges', [
      if (!loading && !enabled)
        Text(
          raftText(
            context,
            'Slack bridging is not enabled for this workspace.',
          ),
        ),
      if (enabled && p != null) ...[
        heading('Slack'),
        if (p.snapshot['workspaceName'] != null)
          Text('${p.snapshot['workspaceName']}'),
        Text(
          '${raftText(context, 'Setup stage')}: ${raftText(context, _stageLabels[p.stage] ?? p.stage)}',
        ),
        Text(
          raftText(
            context,
            _healthLabels[p.healthReason] ??
                'The current bridge state has not been verified.',
          ),
        ),
        if (p.health['lastVerifiedAt'] != null)
          Text(
            '${raftText(context, 'Last verified')}: ${p.health['lastVerifiedAt']}',
          ),
        for (final b
            in (p.health['bindings'] as List).cast<Map<String, dynamic>>())
          if (b['recoveryAction'] != 'none')
            Text(
              raftText(
                context,
                _recoveryLabels[b['recoveryAction']] ?? 'Refresh and recheck',
              ),
            ),
        if (p.snapshot['preflight'] != null) ...[
          heading('Verification'),
          for (final c in p.snapshot['preflight']['checks'])
            Text(
              '${raftText(context, _checkLabels[c['id']] ?? c['id'])}: ${raftText(context, _checkStates[c['state']] ?? c['state'])}',
            ),
        ],
        if (manage)
          Wrap(
            children: [
              if (p.stage == 'connect')
                action(
                  'Connect Slack',
                  () => run(() async {
                    final scope = authority;
                    final next = await update(
                      () => w.client.post('$base/connect'),
                      scope,
                    );
                    if (next.stage == 'oauth') await authorize(scope);
                  }, refresh: false),
                ),
              if (p.stage == 'oauth')
                action(
                  'Authorize Slack',
                  () => run(() => authorize(authority), refresh: false),
                ),
              if (!['connect', 'oauth'].contains(p.stage)) ...[
                action('Add channel pair', () => run(addPair, refresh: false)),
                action(
                  'Verify and enable',
                  () => run(() => verifyAndEnable(authority), refresh: false),
                ),
              ],
              if (p.stage != 'connect' && p.connectionEpoch != null)
                action(
                  'Disconnect Slack',
                  () => run(() async {
                    final scope = authority, epoch = p.connectionEpoch;
                    await confirm(
                      'Disconnect Slack?',
                      'Bridging will stop. You can reconnect later.',
                      () async {
                        await update(
                          () => w.client.post(
                            '$base/disconnect',
                            data: {'expectedConnectionEpoch': epoch},
                          ),
                          scope,
                        );
                      },
                      submit: 'Disconnect',
                      destructive: true,
                    );
                  }, refresh: false),
                ),
            ],
          ),
        heading('Channel pairs'),
        for (final pair in p.rows('channelPairs'))
          ListTile(
            title: Text(channelName('raftChannels', pair['raftChannelId'])),
            subtitle: Text(
              channelName('slackChannels', pair['slackChannelId']),
            ),
            trailing: manage && pair['bindingEpoch'] != null
                ? action(
                    'Remove',
                    () => run(() => removePair(pair), refresh: false),
                  )
                : null,
          ),
        Text(
          raftText(
            context,
            'Invite @Raft to each Slack channel before pairing. Refresh after completing authorization in your browser.',
          ),
        ),
      ],
    ]);
  }
}

const _stageLabels = {
  'connect': 'Connect',
  'oauth': 'OAuth',
  'channels': 'Channels',
  'preflight': 'Preflight',
  'enable': 'Enable',
  'health': 'Health',
};
const _checkLabels = {
  'oauth': 'OAuth authorization',
  'endpoint': 'Hosted endpoint',
  'scope': 'OAuth scope',
  'audience': 'Channel audience',
};
const _checkStates = {
  'passed': 'Passed',
  'failed': 'Failed',
  'unverified': 'Not verified yet',
};
const _healthLabels = {
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
  'audience_unverified': 'The channel audience could not be read.',
  'connection_unverified': 'The hosted connection check failed.',
  'scope_unverified':
      'The installed OAuth scopes do not match the required grant.',
};
const _recoveryLabels = {
  'unarchive_slack_channel': 'Unarchive the Slack channel',
  'select_replacement_slack_channel': 'Select a replacement Slack channel',
  'reinstall_slack_app': 'Reinstall the Slack app',
  'reauthorize_slack_app': 'Reauthorize Slack',
  'migrate_slack_channel_audience': 'Repair the channel audience',
  'review_and_resume_binding': 'Review and resume the channel binding',
};
