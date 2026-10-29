// Web `useChannelSlackBridgeEditor` + `applyChannelSlackBridgeSelection`
// (components/channel/ChannelSlackBridgeField.tsx): pairing one Raft channel
// with one Slack channel from the channel's own create / edit form. The field
// exists only while the Slack bridge flag is on and the bridge is ready (stage
// `health`); a failed read hides it. The choice is applied together with the
// channel: remove the old pair by its binding epoch, then save the pairs,
// verify, and enable.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import 'slack_bridge_contract.dart';

class SlackChannelPairing extends ChangeNotifier {
  SlackChannelPairing(this.w, {this.channelId});
  final WorkspaceController w;

  /// The channel being edited; null while creating one.
  final String? channelId;

  static const flag = 'slack_bridge_v0';
  static const base = '/slack-bridge/provisioning';

  SlackBridgeProjection? snapshot;
  String selected = '';
  bool launchEnabled = false, _closed = false;
  int _ticket = 0;

  /// `launchEnabled && stage === "health"`.
  bool get available => launchEnabled && snapshot?.stage == 'health';

  Map<String, dynamic>? _pairFor(SlackBridgeProjection p) => channelId == null
      ? null
      : p
            .rows('channelPairs')
            .where((pair) => pair['raftChannelId'] == channelId)
            .firstOrNull;

  /// The Slack channel this one is paired with now ('' = none).
  String get current {
    final p = snapshot;
    return p == null ? '' : '${_pairFor(p)?['slackChannelId'] ?? ''}';
  }

  /// `isBridgeDirty`: the pick differs from the saved pairing.
  bool get dirty => available && selected != current;

  void select(String slackChannelId) {
    selected = slackChannelId;
    notifyListeners();
  }

  /// Back to the saved pairing (Cancel).
  void reset() => select(current);

  /// Reads the flag and the provisioning snapshot. A failure or a bridge that
  /// is not ready leaves the field hidden, like Web's swallowed rejection.
  ///
  /// [flagEnabled] is the bridge flag when the host evaluated it already (the
  /// settings drawer reads its flags in one request); null evaluates it here.
  Future<void> load({required bool canManage, bool? flagEnabled}) async {
    final ticket = ++_ticket, serverId = w.server?.id;
    snapshot = null;
    selected = '';
    launchEnabled = false;
    if (!canManage || serverId == null) {
      notifyListeners();
      return;
    }
    try {
      final enabled = flagEnabled ?? await _evaluate(serverId);
      if (!enabled) return _settle(ticket, null, false);
      final next = SlackBridgeProjection.parse(await w.client.get(base));
      _settle(ticket, next, true);
    } catch (_) {
      _settle(ticket, null, false);
    }
  }

  Future<bool> _evaluate(String serverId) async {
    final flags = await w.client.post(
      '/feature-flags/evaluate',
      data: featureFlagEvaluateBody(keys: [flag], serverId: serverId),
    );
    return flags is Map &&
        flags['evaluations'] is List &&
        (flags['evaluations'] as List).any(
          (f) => f is Map && f['key'] == flag && f['enabled'] == true,
        );
  }

  void _settle(int ticket, SlackBridgeProjection? next, bool enabled) {
    if (_closed || ticket != _ticket) return;
    launchEnabled = enabled;
    snapshot = next;
    selected = next == null ? '' : current;
    notifyListeners();
  }

  /// `applyChannelSlackBridgeSelection` for [channel]: nothing to do while the
  /// field is hidden or the pick equals the saved pairing. Throws when the
  /// binding cannot be removed, the preflight fails, or a request is refused;
  /// the caller says the channel was saved but the bridge was not enabled.
  Future<void> apply(String channel) async {
    if (!available) return;
    var latest = SlackBridgeProjection.parse(await w.client.get(base));
    final pair = latest
        .rows('channelPairs')
        .where((p) => p['raftChannelId'] == channel)
        .firstOrNull;
    final wanted = selected;
    if (pair?['slackChannelId'] == wanted || (pair == null && wanted.isEmpty)) {
      _adopt(latest);
      return;
    }
    if (pair != null) {
      final epoch = pair['bindingEpoch'];
      if (epoch is! int) {
        throw StateError('slack_bridge_binding_coordinates_unavailable');
      }
      latest = SlackBridgeProjection.parse(
        await w.client.delete(
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
      );
    }
    if (wanted.isNotEmpty) {
      await w.client.request(
        'PUT',
        '$base/channel-pairs',
        data: {
          'pairs': [
            for (final p in latest.rows('channelPairs'))
              {
                'raftChannelId': p['raftChannelId'],
                'slackChannelId': p['slackChannelId'],
              },
            {'raftChannelId': channel, 'slackChannelId': wanted},
          ],
        },
      );
      final preflight = SlackBridgeProjection.parse(
        await w.client.post('$base/preflight'),
      );
      if (!preflight.preflightPassed) {
        throw StateError('slack_bridge_preflight_failed');
      }
      latest = SlackBridgeProjection.parse(await w.client.post('$base/enable'));
    }
    _adopt(latest);
  }

  void _adopt(SlackBridgeProjection next) {
    if (_closed) return;
    snapshot = next;
    notifyListeners();
  }

  /// `options` of the Select: "Do not connect to Slack", then the Slack
  /// channels of the same privacy class as the channel (Web filters by
  /// `privacyClass`), each marked paired / needing the Raft app.
  List<RaftSlackChannelOption> options(BuildContext context, String privacy) {
    final p = snapshot;
    final paired = {
      for (final pair in p?.rows('channelPairs') ?? const <Map>[])
        '${pair['slackChannelId']}': '${pair['raftChannelId']}',
    };
    String text(String source, String name) =>
        raftFormat(context, source, {'name': name});
    return [
      RaftSlackChannelOption(
        value: '',
        label: raftText(context, 'Do not connect to Slack'),
      ),
      for (final c in p?.rows('slackChannels') ?? const <Map>[])
        if (c['privacyClass'] == null || c['privacyClass'] == privacy)
          () {
            final id = '${c['id']}', name = '${c['name']}';
            final occupied = paired.containsKey(id) && id != selected;
            final needsApp = c['isMember'] != true;
            return RaftSlackChannelOption(
              value: id,
              label: text(
                needsApp
                    ? '#{name} — invite the Raft app in Slack'
                    : occupied
                    ? '#{name} — already paired'
                    : '#{name}',
                name,
              ),
              enabled: !occupied && !needsApp,
            );
          }(),
    ];
  }

  @override
  void dispose() {
    _closed = true;
    ++_ticket;
    super.dispose();
  }
}

/// The Slack channel field for [pairing]; nothing while it is unavailable.
class SlackChannelPairingField extends StatelessWidget {
  const SlackChannelPairingField({
    super.key,
    required this.pairing,
    required this.privacy,
    this.enabled = true,
    this.compact = false,
  });
  final SlackChannelPairing pairing;

  /// `public` or `private`: which Slack channels can be paired.
  final String privacy;
  final bool enabled, compact;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: pairing,
    builder: (context, _) => pairing.available
        ? RaftChannelSlackField(
            options: pairing.options(context, privacy),
            value: pairing.selected,
            onChanged: pairing.select,
            enabled: enabled,
            compact: compact,
          )
        : const SizedBox.shrink(),
  );
}
