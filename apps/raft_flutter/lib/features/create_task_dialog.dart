// Create-task dialog: the Web CreateTaskDialog
// (packages/web/src/components/task/CreateTaskDialog.tsx). One title per row,
// "Add Another" appends a row, a row can be removed once there are several;
// submit creates every non-blank title in [channelId] in one request
// (`POST /tasks/channel/:id {tasks: [{title}]}`, taskStore.createTasks).
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/user_error.dart';

import '../data/workspace_controller.dart';

/// Task v2 "Create task from message" (Web CreateTaskSourceMessage): the
/// tasks hang under this message (`sourceMessageId`).
typedef CreateTaskSourceMessage = ({String id, String senderName, String text});

/// Web `titleFromMessage`: the message on one line, at most 200 characters.
String taskTitleFromMessage(String text) {
  const max = 200;
  final single = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return single.length <= max
      ? single
      : '${single.substring(0, max - 1).trimRight()}…';
}

class CreateTaskDialog extends StatefulWidget {
  const CreateTaskDialog({
    super.key,
    required this.controller,
    required this.channelId,
    this.onCreated,
    this.sourceMessage,
  });
  final WorkspaceController controller;
  final String channelId;
  final Future<void> Function()? onCreated;
  final CreateTaskSourceMessage? sourceMessage;

  static Future<void> show(
    BuildContext context, {
    required WorkspaceController controller,
    required String channelId,
    Future<void> Function()? onCreated,
    CreateTaskSourceMessage? sourceMessage,
  }) => showRaftForm<void>(
    context,
    builder: (_) => CreateTaskDialog(
      controller: controller,
      channelId: channelId,
      onCreated: onCreated,
      sourceMessage: sourceMessage,
    ),
  );

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  late final titles = <TextEditingController>[
    TextEditingController(
      text: widget.sourceMessage == null
          ? ''
          : taskTitleFromMessage(widget.sourceMessage!.text),
    ),
  ];
  bool submitting = false;

  /// A failed submit (server text or lost channel access); the next submit
  /// clears it.
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next submit starts; the dialog state is dropped when it closes.
  String? error;

  /// "A title is required" holds only while every title is still empty.
  final titleRequired = CauseNotice();

  @override
  void initState() {
    super.initState();
    titles.first.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final c in titles) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (submitting) return;
    // The channel must still be joinable by this account; a retained submit
    // of a closed form fails instead of writing.
    final joined = widget.controller.channels.any(
      (c) => c.id == widget.channelId && c.joined && !c.archived,
    );
    if (!mounted || !joined) {
      const message = 'Channel access changed. Reopen this form.';
      if (mounted) {
        setState(() => error = raftText(context, message));
        return;
      }
      throw const RaftApiException(message);
    }
    final nonEmpty = [
      for (final c in titles)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    if (nonEmpty.isEmpty) {
      setState(() {
        error = null;
        titleRequired.raise(
          raftText(context, 'At least one task title is required'),
          whileTrue: () => !titles.any((c) => c.text.trim().isNotEmpty),
        );
      });
      return;
    }
    setState(() {
      submitting = true;
      error = null;
      titleRequired.clear();
    });
    final source = widget.sourceMessage;
    try {
      await widget.controller.command(
        'POST',
        '/tasks/channel/${widget.channelId}',
        data: {
          'tasks': [
            for (final title in nonEmpty)
              {
                'title': title,
                if (source != null) 'sourceMessageId': source.id,
              },
          ],
          // Web createTasks: task v2 sends the create status (the dialog's
          // default, Todo).
          if (source != null) 'status': 'todo',
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onCreated?.call();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = raftText(
            context,
            userErrorText(
              e,
              fallback: 'Failed to create task',
              where: 'create task',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => RaftCreateTaskDialogView(
    titles: titles,
    filledCount: titles.where((c) => c.text.trim().isNotEmpty).length,
    submitting: submitting,
    error: error ?? titleRequired.message,
    onClose: () => Navigator.of(context).maybePop(),
    onSubmit: submit,
    onAddRow: () => setState(() {
      titles.add(TextEditingController()..addListener(_changed));
    }),
    onRemoveRow: (i) => setState(() {
      titles.removeAt(i).dispose();
    }),
    sourceSender: widget.sourceMessage?.senderName,
    sourceText: widget.sourceMessage?.text,
  );
}
