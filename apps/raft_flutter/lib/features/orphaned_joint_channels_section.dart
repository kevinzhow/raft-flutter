import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart' show RaftApiException;
import 'package:raft_ui/raft_ui.dart';

import '../data/feature_flag_client_facts.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'agent_activity_summaries.dart' show joinConjunction;
import 'management_support.dart'
    show
        cachedServerFlag,
        managementMap,
        managementRows,
        pageIdentity,
        rememberServerFlag;

/// OrphanedJointChannelsSection.tsx (Settings > Server, after the archived
/// channels): the joint channels this server holds that nobody here is in.
/// Shown to members who may `federateChannels` and only while one exists.
/// GET /channels/joint-connections once on open (a failed read lists nothing),
/// then Disconnect per row: confirm, POST /channels/:id/disconnect, the row
/// leaves the list and a success toast names the server and the channel. With
/// `external_channels_v1` on, the host copy cannot be disconnected
/// (`host_cannot_disconnect`), so host rows are not listed.
class OrphanedJointChannelsSection extends StatefulWidget {
  const OrphanedJointChannelsSection({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  State<OrphanedJointChannelsSection> createState() =>
      _OrphanedJointChannelsSectionState();
}

class _OrphanedJointChannelsSectionState
    extends State<OrphanedJointChannelsSection> {
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>>? connections;
  late bool hostCannotDisconnect =
      cachedServerFlag(w, RaftFeatureFlags.externalChannels) ?? false;
  bool confirming = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears when the next disconnect starts (Web setError('') in handleDisconnect); the section is remounted on server change.
  String? error;

  bool get canFederate => w.can('federateChannels');

  @override
  void initState() {
    super.initState();
    if (canFederate) {
      unawaited(_load());
      unawaited(_evaluateFlag());
    }
  }

  Future<void> _load() async {
    final identity = pageIdentity(w);
    List<Map<String, dynamic>> rows;
    try {
      final data = managementMap(await w.query('/channels/joint-connections'));
      rows = managementRows(data['connections']);
    } catch (_) {
      // Best-effort discovery surface: without the list there is nothing to
      // act on.
      rows = const [];
    }
    if (mounted && identity == pageIdentity(w)) {
      setState(() => connections = rows);
    }
  }

  Future<void> _evaluateFlag() async {
    final identity = pageIdentity(w);
    try {
      final result = managementMap(
        await w.client.post(
          '/feature-flags/evaluate',
          data: featureFlagEvaluateBody(
            keys: const [RaftFeatureFlags.externalChannels],
            serverId: w.server?.id,
          ),
        ),
      );
      final on = managementRows(result['evaluations']).any(
        (f) =>
            f['key'] == RaftFeatureFlags.externalChannels &&
            f['enabled'] == true,
      );
      rememberServerFlag(w, RaftFeatureFlags.externalChannels, on, identity);
      if (mounted &&
          identity == pageIdentity(w) &&
          on != hostCannotDisconnect) {
        setState(() => hostCannotDisconnect = on);
      }
    } catch (_) {
      // An unresolved flag keeps the last known value.
    }
  }

  /// `connection.memberCount === 0`, host copies out while external channels
  /// are on, by name.
  List<Map<String, dynamic>> get orphaned =>
      [
        for (final c in connections ?? const <Map<String, dynamic>>[])
          if (c['memberCount'] == 0 &&
              !(hostCannotDisconnect && c['role'] == 'host'))
            c,
      ]..sort(
        (a, b) => '${a['name']}'.toLowerCase().compareTo(
          '${b['name']}'.toLowerCase(),
        ),
      );

  Future<void> _disconnect(Map<String, dynamic> connection) async {
    final id = '${connection['channelId']}';
    final name = '${connection['name']}';
    final identity = pageIdentity(w);
    setState(() => confirming = true);
    try {
      await RaftConfirmDialog.show(
        context,
        RaftConfirmDialog(
          title: 'Disconnect joint channel',
          message: raftFormat(
            context,
            'Your members and agents will leave #{name}, and it will be removed from this server. The other servers keep the channel and its history.',
            {'name': name},
          ),
          confirmLabel: 'Disconnect',
          confirmKey: const Key('orphaned-joint-channel-confirm-button'),
          loadingLabel: 'Disconnecting…',
          onConfirm: () async {
            if (mounted) setState(() => error = null);
            try {
              await w.command('POST', '/channels/$id/disconnect');
              await w.refreshChannels();
              if (!mounted || identity != pageIdentity(w)) return;
              setState(
                () => connections = [
                  for (final c in connections ?? const <Map<String, dynamic>>[])
                    if ('${c['channelId']}' != id) c,
                ],
              );
              showRaftToast(
                context,
                raftFormat(context, '{server} disconnected from #{channel}', {
                  'server': w.server?.name ?? '',
                  'channel': name,
                }),
                tone: RaftToastRecipeTone.success,
              );
            } catch (e) {
              if (mounted) {
                setState(() => error = _disconnectError(e, name));
              }
            }
          },
        ),
      );
    } finally {
      if (mounted) setState(() => confirming = false);
    }
  }

  /// `jointDisconnectGuestRefusalMessage`, else the server's text, else the
  /// section's own fallback.
  String _disconnectError(Object e, String name) {
    if (e is RaftApiException && e.details['code'] == 'guests_present') {
      return raftFormat(
        context,
        "{channel} has guests, so this server can't disconnect from it. Remove the guests first, or archive the channel.",
        {'channel': '#$name'},
      );
    }
    return raftText(
      context,
      userErrorText(
        e,
        fallback: "Couldn't disconnect the channel. Try again.",
        where: 'orphaned joint channels',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!canFederate) return const SizedBox.shrink();
    final rows = orphaned;
    if (rows.isEmpty) return const SizedBox.shrink();
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final serverId = w.server?.id;
    return RaftOrphanedJointChannelsSection(
      key: const ValueKey('orphaned-joint-channels-section'),
      description: raftFormat(
        context,
        'Everyone from {server} has left these channels. Disconnect them to free their slots. The other servers keep the conversation.',
        {'server': w.server?.name ?? ''},
      ),
      error: error,
      disabled: confirming,
      rows: [
        for (final c in rows)
          () {
            final others = [
              for (final s in managementRows(c['servers']))
                if (s['serverId'] != serverId) '${s['name']}',
            ];
            return RaftOrphanedJointChannelRow(
              id: '${c['channelId']}',
              name: '${c['name']}',
              metadata: others.isEmpty
                  ? raftText(context, 'Nobody from this server is in it')
                  : raftFormat(
                      context,
                      'Connected with {servers} · nobody from this server is in it',
                      {'servers': joinConjunction(others, chinese: chinese)},
                    ),
              disconnectLabel: raftFormat(context, 'Disconnect {name}', {
                'name': '${c['name']}',
              }),
            );
          }(),
      ],
      onDisconnect: (id) {
        final c = rows.where((c) => '${c['channelId']}' == id).firstOrNull;
        if (c != null) unawaited(_disconnect(c));
      },
    );
  }
}
