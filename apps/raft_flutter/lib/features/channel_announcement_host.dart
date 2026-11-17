import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'activity_row_time.dart' show activityRowFormatter;
import 'artifacts/artifact_api.dart';
import 'artifacts/artifact_models.dart';
import 'artifacts/artifact_viewer_page.dart';
import 'channel_announcement_session.dart';
import 'channel_announcement_store.dart';
import 'channel_announcement_strip.dart';

RaftRecord channelAnnouncementAuthor(
  WorkspaceController w,
  ChannelAnnouncement value,
) {
  final author = RaftRecord(value.updatedBy);
  final actor = author.string('type') == 'agent'
      ? w.entityDirectory.agent(author.id)
      : author.id == w.client.user?.id
      ? w.client.user?.json
      : w.entityDirectory.member(author.id);
  final known = actor == null ? null : RaftRecord(actor);
  return RaftRecord({
    ...value.updatedBy,
    if (known != null && known.name.isNotEmpty) 'displayName': known.name,
    if (known != null) 'avatarUrl': known.json['avatarUrl'],
  });
}

Future<void> openChannelAnnouncement(
  BuildContext context,
  WorkspaceController w,
  String channelId,
  ChannelAnnouncement announcement,
) async {
  final session = ChannelAnnouncementSession.of(w);
  final epoch = session.epoch;
  await openWorkspaceArtifact(
    context,
    w,
    ArtifactLinkTarget(announcement.artifactId),
  );
  if (context.mounted && session.epoch == epoch) await session.load(channelId);
}

class ChannelAnnouncementHost extends StatefulWidget {
  const ChannelAnnouncementHost({
    super.key,
    required this.controller,
    required this.channel,
    this.onOpenSettings,
  });

  final WorkspaceController controller;
  final RaftChannel channel;
  final VoidCallback? onOpenSettings;

  @override
  State<ChannelAnnouncementHost> createState() =>
      _ChannelAnnouncementHostState();
}

class _ChannelAnnouncementHostState extends State<ChannelAnnouncementHost> {
  late ChannelAnnouncementSession session;
  RaftForegroundPeriodic? poll;
  String? requested;
  bool visible = true;

  @override
  void initState() {
    super.initState();
    session = ChannelAnnouncementSession.of(widget.controller)
      ..addListener(changed);
  }

  bool get supported =>
      const {'channel', 'private', 'joint'}.contains(widget.channel.type);
  String get requestScope => '${session.epoch}:${widget.channel.id}';

  void changed() {
    if (!mounted) return;
    sync();
    setState(() {});
  }

  void sync() {
    if (!visible || !session.enabled || !supported) {
      poll?.dispose();
      poll = null;
      requested = null;
      return;
    }
    if (requested != requestScope) {
      requested = requestScope;
      unawaited(session.load(widget.channel.id));
    }
    poll ??= RaftForegroundPeriodic(const Duration(minutes: 1), () {
      unawaited(session.load(widget.channel.id));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    visible = TickerMode.valuesOf(context).enabled;
    sync();
  }

  @override
  void didUpdateWidget(covariant ChannelAnnouncementHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      session.removeListener(changed);
      session = ChannelAnnouncementSession.of(widget.controller)
        ..addListener(changed);
      requested = null;
    }
    sync();
  }

  @override
  void dispose() {
    poll?.dispose();
    session.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!session.enabled || !supported) return const SizedBox.shrink();
    final value = session.store.forChannel(widget.channel.id);
    if (value == null) return const SizedBox.shrink();
    final canEdit =
        widget.controller.can(
          'editChannelMetadata',
          resource: widget.channel,
        ) &&
        !widget.channel.archived;
    final openSettings = canEdit ? widget.onOpenSettings : null;
    return ChannelAnnouncementStrip(
      announcement: value,
      author: channelAnnouncementAuthor(widget.controller, value),
      formatDate: activityRowFormatter(
        context,
        widget.controller.client.user?.json,
      ).compactDate,
      webOrigin: ArtifactDeployment.resolve(
        widget.controller.client.origin,
        null,
      ).webOrigin,
      onOpen: () => unawaited(
        openChannelAnnouncement(
          context,
          widget.controller,
          widget.channel.id,
          value,
        ),
      ),
      onOpenSettings: openSettings == null
          ? null
          : () {
              session.requestSettings(widget.channel.id);
              openSettings();
            },
    );
  }
}
