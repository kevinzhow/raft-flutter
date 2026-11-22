import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

enum WorkspaceOfflinePresentation { indicator, compactIndicator, banner }

class WorkspaceOfflineNotice extends StatefulWidget {
  const WorkspaceOfflineNotice({
    super.key,
    required this.client,
    this.presentation = WorkspaceOfflinePresentation.indicator,
  });

  final RaftClient client;
  final WorkspaceOfflinePresentation presentation;

  @override
  State<WorkspaceOfflineNotice> createState() => _WorkspaceOfflineNoticeState();
}

class _WorkspaceOfflineNoticeState extends State<WorkspaceOfflineNotice> {
  late Stream<RaftEvent> _connection;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(WorkspaceOfflineNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) _bind();
  }

  void _bind() {
    _connection = widget.client.events.where(
      (event) =>
          event.name == 'session:degraded' ||
          event.name == 'session:recovered' ||
          event.name == 'session:ended',
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _connection,
    builder: (context, _) {
      if (!widget.client.restoredOffline) return const SizedBox.shrink();
      final reason = raftTextZh(
        context,
        'Offline — showing your last channel list. Reconnects automatically.',
        '离线：显示的是上次的频道列表，联网后自动恢复',
      );
      if (widget.presentation == WorkspaceOfflinePresentation.banner) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            RaftSpace.x3,
            RaftSpace.x2,
            RaftSpace.x3,
            0,
          ),
          child: RaftBanner(
            key: const Key('workspace-offline-reason'),
            description: reason,
            status: RaftBannerRecipeStatus.info,
            size: RaftBannerRecipeSize.sm,
            glyph: RaftGlyph.info,
          ),
        );
      }
      final compact =
          widget.presentation == WorkspaceOfflinePresentation.compactIndicator;
      return Semantics(
        container: true,
        liveRegion: true,
        label: reason,
        excludeSemantics: true,
        child: RaftBadge(
          key: const Key('workspace-offline-indicator'),
          label: compact ? raftTextZh(context, 'Offline', '离线') : reason,
          appearance: RaftBadgeRecipeAppearance.soft,
          variant: RaftBadgeRecipeVariant.muted,
          leading: const RaftStatus(presence: RaftPresence.offline),
        ),
      );
    },
  );
}
