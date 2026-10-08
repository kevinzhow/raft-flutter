import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'channel_conversion_progress.dart';

final _observations = Expando<Map<String, ConversionObservation>>();

class ChannelConversionSection extends StatefulWidget {
  const ChannelConversionSection({
    super.key,
    required this.controller,
    required this.channelId,
  });
  final WorkspaceController controller;
  final String channelId;
  @override
  State<ChannelConversionSection> createState() => _ConversionSectionState();
}

class _ConversionSectionState
    extends ManagementState<ChannelConversionSection> {
  @override
  WorkspaceController get w => widget.controller;
  RaftChannel? get currentChannel =>
      w.channels.where((c) => c.id == widget.channelId).firstOrNull;
  bool get manager => w.can('federateChannels') && currentChannel != null;
  @override
  String get authority =>
      '${super.authority}|$authorityRevision|${widget.channelId}|$manager|${w.can('federateChannels', resource: currentChannel)}|${currentChannel?.joined}|${currentChannel?.archived}';
  String get scopeKey =>
      '${w.client.generation}|${w.client.user?.id}|${w.server?.id}|${w.server?.string('role')}|${widget.channelId}';
  Map<String, ConversionObservation> get observations =>
      _observations[w.client] ??= {};
  ConversionObservation? get pending => observations[scopeKey];
  bool enabled = false, uncertain = false;
  Map<String, dynamic> channel = {};
  List<Map<String, dynamic>> uploads = [];
  final canceledUploads = <String>{};
  bool uploadBlocked = false;
  ChannelConversionSnapshot snapshot = const ChannelConversionSnapshot(
    'idle',
    {},
    {},
  );
  Timer? poll;
  StreamSubscription<RaftEvent>? events;
  int revision = 0, authorityRevision = 0;
  BuildContext? modal;
  @override
  void initState() {
    super.initState();
    startManagement();
    events = w.client.events.listen((event) {
      if (!{
        'channel:updated',
        'channel:members-updated',
        'channel:authority-updated',
        'channel:removed',
      }.contains(event.name)) {
        return;
      }
      final data = managementMap(event.payload),
          id = data['channelId'] ?? managementMap(data['channel'])['id'];
      if (id != widget.channelId) return;
      final changed = managementMap(data['channel']);
      final old = currentChannel;
      final changesPolicy =
          old != null &&
          ['joined', 'archivedAt', 'channelCapabilities'].any(
            (key) =>
                changed.containsKey(key) &&
                jsonEncode(changed[key]) != jsonEncode(old.json[key]),
          );
      if (event.name != 'channel:updated' || changesPolicy) {
        revision++;
        authorityRevision++;
        final routeContext = modal;
        if (routeContext != null && routeContext.mounted) {
          final route = ModalRoute.of(routeContext);
          if (route != null && route.isActive) {
            Navigator.of(routeContext).removeRoute(route);
          }
        }
        refreshAuthority();
      } else {
        reload();
      }
    });
  }

  @override
  Future<V?> scopedDialog<V>(Widget Function(BuildContext) builder) async {
    try {
      return await super.scopedDialog<V>((context) {
        modal = context;
        return builder(context);
      });
    } finally {
      modal = null;
    }
  }

  @override
  void clearData() {
    enabled = false;
    channel = {};
    uploads = [];
    canceledUploads.clear();
    uploadBlocked = false;
    snapshot = const ChannelConversionSnapshot('idle', {}, {});
    uncertain = false;
    poll?.cancel();
  }

  bool same(String source) => mounted && source == authority && manager;
  Future<bool> evaluate() async {
    final result = managementMap(
      await w.client.post(
        '/feature-flags/evaluate',
        data: {
          'keys': [channelConversionFlag],
          'serverId': w.server?.id,
          'platform': 'web',
        },
      ),
    );
    return managementRows(result['evaluations'])
        .any((f) => f['key'] == channelConversionFlag && f['enabled'] == true);
  }

  @override
  Future<void> loadData(int request, int generation) async {
    if (!manager) {
      clearData();
      return;
    }
    final source = authority, sequence = revision;
    bool allowed;
    try {
      allowed = await evaluate();
    } catch (e) {
      if (same(source) && sequence == revision) clearData();
      rethrow;
    }
    if (!accepts(generation, request) ||
        sequence != revision ||
        !same(source)) {
      return;
    }
    if (!allowed) {
      clearData();
      return;
    }
    try {
      final value = managementMap(
        await w.client.get(
          pending == null && snapshot.job.isNotEmpty
              ? '/channels/conversion-jobs/${snapshot.job['id']}'
              : '/channels/${widget.channelId}',
        ),
      );
      if (!accepts(generation, request) ||
          sequence != revision ||
          !same(source)) {
        return;
      }
      final fresh = ChannelConversionSnapshot.from(value);
      final row = managementMap(value['channel']);
      final projected = row.isNotEmpty ? row : value;
      final recovers =
          projected['type'] == 'joint' || fresh.job.isNotEmpty || uploadBlocked;
      final active = recovers
          ? managementRows(
              managementMap(
                await w.client.get(
                  '/attachments/upload-sessions/${widget.channelId}/active',
                ),
              )['uploads'],
            )
          : <Map<String, dynamic>>[];
      if (!accepts(generation, request) ||
          sequence != revision ||
          !same(source)) {
        return;
      }
      if (active.length > 100 ||
          active.any(
            (u) =>
                u['uploadId'] is! String ||
                u['filename'] is! String ||
                !{'pending', 'verifying'}.contains(u['state']),
          )) {
        throw const FormatException('Unsupported active upload receipt.');
      }
      final activeIds = active.map((u) => u['uploadId']).toSet();
      canceledUploads.removeWhere((id) => !activeIds.contains(id));
      uploads = active
          .where((u) => !canceledUploads.contains(u['uploadId']))
          .toList();
      final observation = pending;
      if (observation != null && observation.settles(fresh)) {
        observations.remove(scopeKey);
      }
      channel = projected;
      snapshot = fresh;
      enabled = true;
      if (pending == null) uncertain = false;
      schedule();
    } catch (e) {
      if (same(source) && e is FormatException) clearData();
      if (same(source) &&
          e is RaftApiException &&
          [401, 403, 404].contains(e.status)) {
        clearData();
      }
      rethrow;
    }
  }

  void schedule() {
    poll?.cancel();
    if (enabled && (pending != null || snapshot.active)) {
      poll = Timer(const Duration(seconds: 1), () {
        if (mounted && !busy) {
          reload();
        } else if (mounted) {
          schedule();
        }
      });
    }
  }

  Future<void> command(String kind) async {
    final source = authority, key = scopeKey;
    if (!enabled || !same(source) || pending != null) return;
    final jobId = snapshot.job['id'];
    if (kind == 'retry' && snapshot.job['status'] != 'failed') return;
    if (kind == 'cancel' && !snapshot.canCancel) return;
    if (kind == 'start' &&
        (!w.can('federateChannels', resource: currentChannel) ||
            channel['name'] == 'all' ||
            !{'channel', 'private'}.contains(channel['type']) ||
            snapshot.active ||
            snapshot.job['status'] == 'failed')) {
      return;
    }
    final confirmed = await confirm(
      kind == 'cancel'
          ? 'Cancel conversion'
          : kind == 'retry'
          ? 'Retry conversion'
          : 'Convert to joint channel',
      kind == 'cancel'
          ? 'Cancel eligible work before audience cutover and restore the original channel. Completed conversion cannot be reversed.'
          : 'Preserve this channel history and members while preparing a shared conversation. Sending may be temporarily unavailable during conversion.',
      () async {
        if (!enabled || !same(source)) {
          throw StateError('Conversion is no longer available.');
        }
        bool allowed;
        try {
          allowed = await evaluate();
        } catch (e) {
          if (same(source)) {
            clearData();
            if (mounted) setState(() {});
            final current = modal;
            if (current != null && current.mounted) {
              final route = ModalRoute.of(current);
              if (route != null && route.isActive) {
                Navigator.of(current).removeRoute(route);
              }
            }
          }
          rethrow;
        }
        if (!same(source)) throw StateError('Channel access changed.');
        if (!allowed) {
          clearData();
          if (mounted) setState(() {});
          final current = modal;
          if (current != null && current.mounted) {
            final route = ModalRoute.of(current);
            if (route != null && route.isActive) {
              Navigator.of(current).removeRoute(route);
            }
          }
          throw StateError('Conversion is no longer available.');
        }
        final observation = ConversionObservation(
          token: conversionCommandIdentity(),
          kind: kind,
          baseline: snapshot,
          previousCommandId: snapshot.command['id'],
        );
        observations[key] = observation;
        revision++;
        poll?.cancel();
        final path = kind == 'start'
            ? '/channels/${widget.channelId}/convert-to-joint'
            : '/channels/conversion-jobs/$jobId/$kind';
        try {
          final result = managementMap(
            await w.client.post(
              path,
              data: {
                'commandId': observation.token,
                if (kind == 'start') 'observeProgress': true,
              },
            ),
          );
          if (!same(source) || observations[key] != observation) return;
          final receipt = ChannelConversionSnapshot.from(result);
          if (receipt.status == 'idle') {
            throw const FormatException('Conversion receipt was incomplete.');
          }
          if (receipt.status != 'pending') observations.remove(key);
          snapshot = receipt;
          final returned = managementMap(result['channel']);
          if (returned.isNotEmpty) channel = returned;
          uncertain = false;
        } catch (e) {
          if (!same(source) || observations[key] != observation) return;
          if (e is RaftApiException && e.details['conversionJob'] is Map) {
            snapshot = ChannelConversionSnapshot.from({
              'conversionJob': e.details['conversionJob'],
            });
            observations.remove(key);
            error = e.message;
          } else if (e is RaftApiException &&
              [400, 403, 404, 409].contains(e.status)) {
            observations.remove(key);
            error = e.message;
            uploadBlocked =
                e.details['code'] == 'channel_conversion_uploads_in_flight';
            if ([401, 403, 404].contains(e.status)) {
              clearData();
              invalidateDeniedMutation(e);
            }
          } else {
            uncertain = true;
            error = 'The conversion outcome is not confirmed. Check status before trying again.';
          }
        }
      },
      submit: kind == 'cancel'
          ? 'Cancel conversion'
          : kind == 'retry'
          ? 'Retry conversion'
          : 'Convert to joint channel',
      destructive: kind == 'cancel',
    );
    if (!confirmed || !same(source)) return;
    if (mounted) setState(() {});
    schedule();
    if (uploadBlocked && enabled) {
      final message = error;
      await reload();
      if (same(source)) setState(() => error = message);
    }
    if (enabled && pending == null && error == null) await reload();
  }

  Future<void> cancelUpload(Map<String, dynamic> upload) async {
    final source = authority;
    final saved = await confirm(
      'Cancel upload',
      'Cancel ${upload['filename']} from this channel. The unfinished attachment will not be sent.',
      () async {
        if (!enabled || !same(source)) {
          throw StateError('Channel access changed.');
        }
        revision++;
        await w.client.delete(
          '/attachments/upload-sessions/${upload['uploadId']}',
        );
        if (!same(source)) return;
        canceledUploads.add('${upload['uploadId']}');
        uploads.removeWhere((u) => u['uploadId'] == upload['uploadId']);
      },
      submit: 'Cancel upload',
      destructive: true,
    );
    if (saved && same(source)) {
      setState(() {});
      await reload();
    }
  }

  Future<void> openChannel() async {
    final row = currentChannel;
    if (row != null && manager) await w.selectChannel(row);
  }

  VoidCallback guard(Future<void> Function() action) {
    final source = authority;
    return () {
      if (same(source)) run(action, refresh: false);
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!manager || !enabled || channel['name'] == 'all') {
      return const SizedBox.shrink();
    }
    if (!{'channel', 'private'}.contains(channel['type']) &&
        snapshot.status == 'idle' &&
        pending == null) {
      return const SizedBox.shrink();
    }
    final canStart =
        w.can('federateChannels', resource: currentChannel) &&
        pending == null &&
        !snapshot.active &&
        snapshot.job['status'] != 'failed' &&
        {'channel', 'private'}.contains(channel['type']);
    return RaftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            raftText(context, 'Chat with members from other servers'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            raftText(
              context,
              'Convert to a Joint Channel, then invite people from another server. Existing messages, files, and members stay.',
            ),
          ),
          if (pending != null) ...[
            const LinearProgressIndicator(),
            Text(
              raftText(
                context,
                uncertain
                    ? 'Conversion outcome is not confirmed.'
                    : 'Waiting for server confirmation.',
              ),
            ),
            action('Check conversion status', guard(reload)),
          ],
          if (uploads.isNotEmpty) ...[
            Text(raftText(context, 'Uploads still in progress')),
            for (final upload in uploads)
              ListTile(
                title: Text('${upload['filename']}'),
                subtitle: Text(
                  '${raftText(context, upload['state'] == 'verifying' ? 'Verifying upload' : 'Upload pending')} · ${upload['sizeBytes']} B',
                ),
                trailing: action(
                  'Cancel upload',
                  guard(() => cancelUpload(upload)),
                ),
              ),
            action('Return to channel', guard(openChannel)),
          ],
          if (snapshot.job.isNotEmpty && pending == null)
            ChannelConversionProgress(
              status: '${snapshot.job['status']}',
              phase: '${snapshot.job['phase']}',
              error: snapshot.job['error'] is String
                  ? snapshot.job['error']
                  : null,
            ),
          if (snapshot.status == 'failed' &&
              snapshot.job.isEmpty &&
              snapshot.command['error'] is String)
            Text(
              snapshot.command['error'],
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Wrap(
            spacing: 8,
            children: [
              if (canStart)
                action(
                  'Convert to joint channel',
                  guard(() => command('start')),
                  icon: Icons.hub_outlined,
                ),
              if (pending == null && snapshot.job['status'] == 'failed')
                action('Retry conversion', guard(() => command('retry'))),
              if (pending == null && snapshot.canCancel)
                action('Cancel conversion', guard(() => command('cancel'))),
              if (snapshot.status == 'done')
                Text(
                  raftText(
                    context,
                    'Conversion complete. Invite another workspace from Joint channels.',
                  ),
                ),
              if (snapshot.status == 'canceled')
                Text(
                  raftText(
                    context,
                    'Conversion canceled. The original channel is available.',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    poll?.cancel();
    events?.cancel();
    super.dispose();
  }
}
