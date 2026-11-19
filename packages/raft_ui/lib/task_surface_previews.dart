import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Task modal', size: Size(390, 844))
Widget taskModalPreview() => const _TaskPreview();

@RaftPreviews('Mobile task page', size: Size(390, 844))
Widget taskPagePreview() => const _TaskPreview(page: true);

@RaftPreviews('Mobile task conversation details', size: Size(390, 844))
Widget taskConversationPagePreview() =>
    const _TaskPreview(page: true, conversationDetails: true);

@RaftPreviews('Task slot details', size: Size(856, 600))
Widget taskConversationSlotPreview() =>
    const _TaskPreview(inPlace: true, conversationDetails: true);

@RaftPreviews('Mobile legacy task page', size: Size(390, 844))
Widget legacyTaskPagePreview() => const _TaskPreview(legacy: true, page: true);

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
    this.page = false,
    this.inPlace = false,
    this.conversationDetails = false,
  });
  final bool legacy;
  final bool page, inPlace, conversationDetails;
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
            label: 'Reopen Preview',
            onPressed: () => setState(() => closed = false),
          ),
        )
      : RaftTaskSurface(
          page: widget.page,
          inPlace: widget.inPlace,
          conversation: widget.conversationDetails
              ? RaftTaskConversation(ref: '#general:#8', onViewInChannel: () {})
              : null,
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
