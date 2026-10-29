import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;

/// ArchivedChannelsSection.tsx: the Server settings list of archived channels
/// (public, private and joint) with Unarchive. Rendered only for members who
/// may archive channels, once the channel list has loaded and while at least
/// one channel is archived. The newest archive comes first.
class ArchivedChannelsSection extends StatefulWidget {
  const ArchivedChannelsSection({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  State<ArchivedChannelsSection> createState() =>
      _ArchivedChannelsSectionState();
}

class _ArchivedChannelsSectionState extends State<ArchivedChannelsSection> {
  WorkspaceController get w => widget.controller;
  String? busyId;

  /// The unarchive failure of one channel: it describes that row, so it ends
  /// when the channel is no longer listed as archived (restored elsewhere,
  /// another server, or no archived channel left).
  final _failure = CauseNotice();
  String? get error => _failure.message;

  /// `isArchivedChannel`: archived and a channel, private channel or joint
  /// channel (direct messages never list).
  static bool _archived(RaftChannel c) =>
      c.archived && const {'channel', 'private', 'joint'}.contains(c.type);

  List<RaftChannel> get archived =>
      [...w.channels.where(_archived)]..sort((a, b) {
        final byDate = b.string('archivedAt').compareTo(a.string('archivedAt'));
        return byDate != 0 ? byDate : a.name.compareTo(b.name);
      });

  @override
  void didUpdateWidget(covariant ArchivedChannelsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      busyId = null;
      _failure.clear();
    }
  }

  Future<void> unarchive(RaftChannel channel) async {
    if (busyId != null) return;
    final serverId = w.server?.id, generation = w.client.generation;
    bool current() =>
        mounted &&
        serverId == w.server?.id &&
        generation == w.client.generation;
    setState(() {
      _failure.clear();
      busyId = channel.id;
    });
    try {
      await w.command('POST', '/channels/${channel.id}/unarchive');
      if (!current()) return;
      await w.refreshChannels();
    } catch (e) {
      if (current()) {
        setState(() {
          _failure.raise(
            raftText(
              context,
              userErrorText(
                e,
                fallback: 'Failed to unarchive channel',
                where: 'archived channels',
              ),
            ),
            whileTrue: () => archived.any((c) => c.id == channel.id),
          );
        });
      }
    } finally {
      if (current()) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: w,
    builder: (context, _) {
      if (!w.can('archiveChannels') || w.loading) {
        return const SizedBox.shrink();
      }
      final channels = archived;
      if (channels.isEmpty) return const SizedBox.shrink();
      final formatter = agentTimeFormatter(context, w);
      return RaftArchivedChannelsSection(
        rows: [
          for (final c in channels)
            RaftArchivedChannelRow(
              id: c.id,
              name: c.name,
              type: c.type,
              metadata: raftFormat(context, '{type} · Archived {date}', {
                'type': RaftArchivedChannelsSection.typeLabel(context, c.type),
                'date': formatter.mediumDateTime(c.json['archivedAt']),
              }),
            ),
        ],
        busyId: busyId,
        error: error,
        onOpen: (id) {
          final channel = channels.where((c) => c.id == id).firstOrNull;
          if (channel != null) unawaited(w.selectChannel(channel));
        },
        onUnarchive: (id) {
          final channel = channels.where((c) => c.id == id).firstOrNull;
          if (channel != null) unawaited(unarchive(channel));
        },
      );
    },
  );
}
