import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Task modal', size: Size(390, 844))
Widget taskModalPreview() => const _TaskPreview();

@RaftPreviews('Legacy task panel', size: Size(1280, 844))
Widget legacyTaskPreview() => const _TaskPreview(legacy: true);

@RaftPreviews('Legacy docked task panel', size: Size(1280, 844))
Widget legacyDockedTaskPreview() => const _TaskPreview(
  legacy: true,
  presentation: RaftLegacyTaskPresentation.side,
);

class _TaskPreview extends StatefulWidget {
  const _TaskPreview({
    this.legacy = false,
    this.presentation = RaftLegacyTaskPresentation.modal,
  });
  final bool legacy;
  final RaftLegacyTaskPresentation presentation;
  @override
  State<_TaskPreview> createState() => _TaskPreviewState();
}

class _TaskPreviewState extends State<_TaskPreview> {
  bool closed = false;
  String status = 'todo';
  @override
  Widget build(BuildContext context) =>
      widget.legacy &&
          widget.presentation == RaftLegacyTaskPresentation.side &&
          MediaQuery.sizeOf(context).width >= 1024
      ? Stack(
          fit: StackFit.expand,
          children: [
            const Center(child: Text('Retained workspace content')),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: 380,
              child: surface(context),
            ),
          ],
        )
      : surface(context);

  Widget surface(BuildContext context) => closed
      ? Center(
          child: RaftTextButton(
            label: 'Reopen preview',
            onPressed: () => setState(() => closed = false),
          ),
        )
      : RaftTaskSurface(
          task: {
            'id': 'preview-task',
            'taskNumber': 8,
            'channelName': 'general',
            'title': 'Review the release',
            'description': 'Check the acceptance evidence before release.',
            'status': status,
            'createdByName': 'Alice',
          },
          history: const [
            {'eventType': 'created', 'actorName': 'Alice'},
          ],
          assignees: const [],
          legacy: widget.legacy,
          legacyPresentation: widget.presentation,
          loading: false,
          historyLoading: false,
          busy: false,
          canStatus: !widget.legacy,
          canAssign: false,
          canCleanupDelete: false,
          statusOptions: raftTaskStatuses,
          onClose: () => setState(() => closed = true),
          onRetry: () async {},
          onLoadAssignees: () async {},
          onUpdate: (field, value) async {
            if (field == 'status') setState(() => status = value as String);
          },
          formatTime: (_) => 'Oct 10, 2026, 09:00',
          discussionBuilder: widget.legacy
              ? null
              : (head) => ListView(
                  children: [
                    head,
                    const RaftPanelSection(
                      children: [Text('Discussion preview')],
                    ),
                  ],
                ),
        );
}
