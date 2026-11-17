// Create-task dialog: the Web CreateTaskDialog
// (packages/web/src/components/task/CreateTaskDialog.tsx). One title per row,
// "Add another" appends a row, a row can be removed once there are several;
// submit creates every non-blank title in [channelId] in one request
// (`POST /tasks/channel/:id {tasks: [{title}]}`, taskStore.createTasks).
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/server_error_code.dart';
import '../data/user_error.dart';

import '../data/workspace_controller.dart';
import 'create_task_channel.dart';
import 'create_task_message_dialog.dart';
import 'message_task_actions.dart' show TaskV2ConversationsFlag;

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

/// The tasks a create answer carries (`{tasks: [...]}`).
List<Map<String, dynamic>> createdTaskRows(Object? answer) => [
  if (answer is Map && answer['tasks'] is List)
    for (final task in answer['tasks'] as List)
      if (task is Map && task['id'] is String) Map<String, dynamic>.from(task),
];

class CreateTaskDialog extends StatefulWidget {
  const CreateTaskDialog({
    super.key,
    required this.controller,
    this.channelId,
    this.defaultChannelId,
    this.onCreated,
    this.onCreatedTasks,
    this.sourceMessage,
  });
  final WorkspaceController controller;

  /// The tasks the server made (the Tasks page opens the one it made).
  final void Function(List<Map<String, dynamic>> created)? onCreatedTasks;

  /// The channel the tasks go in; null (the Tasks page) asks for one.
  final String? channelId;

  /// Without [channelId]: the channel picked at first, if it can be picked.
  final String? defaultChannelId;
  final Future<void> Function()? onCreated;
  final CreateTaskSourceMessage? sourceMessage;

  /// Task v2 without a source message: a task is a message the person sends
  /// (Web CreateTaskDialog picks CreateTaskMessageDialog).
  static Widget forChannel({
    required WorkspaceController controller,
    String? channelId,
    String? defaultChannelId,
    Future<void> Function()? onCreated,
    void Function(List<Map<String, dynamic>> created)? onCreatedTasks,
    CreateTaskSourceMessage? sourceMessage,
  }) => sourceMessage == null && TaskV2ConversationsFlag.of(controller).enabled
      ? CreateTaskMessageDialog(
          controller: controller,
          channelId: channelId,
          defaultChannelId: defaultChannelId,
          onCreated: onCreated,
          onCreatedTasks: onCreatedTasks,
        )
      : CreateTaskDialog(
          controller: controller,
          channelId: channelId,
          defaultChannelId: defaultChannelId,
          onCreated: onCreated,
          onCreatedTasks: onCreatedTasks,
          sourceMessage: sourceMessage,
        );

  static Future<void> show(
    BuildContext context, {
    required WorkspaceController controller,
    required String channelId,
    Future<void> Function()? onCreated,
    CreateTaskSourceMessage? sourceMessage,
  }) => showRaftForm<void>(
    context,
    builder: (_) => forChannel(
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

  /// The channel picked when none is fixed (Web useCreateTaskChannel).
  late String? pickedChannel = createTaskInitialChannel(
    widget.controller,
    widget.defaultChannelId,
  );

  /// "Pick a channel": said under the field until a channel is picked.
  final channelRequired = CauseNotice();

  /// Task v2: the status the tasks start in (Web useCreateTaskStatus).
  String status = 'todo';
  bool get taskV2 => TaskV2ConversationsFlag.of(widget.controller).enabled;

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
    final channelId = widget.channelId ?? pickedChannel;
    final joined =
        channelId == null ||
        widget.controller.channels.any(
          (c) => c.id == channelId && c.joined && !c.archived,
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
    if (channelId == null) {
      setState(() {
        error = null;
        channelRequired.raise(
          raftText(context, 'Pick a channel'),
          whileTrue: () => pickedChannel == null,
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
      final answer = await widget.controller.command(
        'POST',
        '/tasks/channel/$channelId',
        data: {
          'tasks': [
            for (final title in nonEmpty)
              {
                'title': title,
                if (source != null) 'sourceMessageId': source.id,
              },
          ],
          // Web createTasks: task v2 sends the create status.
          if (taskV2) 'status': status,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreatedTasks?.call(createdTaskRows(answer));
      await widget.onCreated?.call();
    } catch (e) {
      if (mounted) {
        setState(() => error = raftText(context, createTaskFailureText(e)));
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
    channelField: widget.channelId != null
        ? null
        : RaftCreateTaskChannelField(
            label: 'Channel',
            options: createTaskChannelOptions(widget.controller),
            value: pickedChannel,
            error: channelRequired.message,
            onChanged: submitting
                ? null
                : (id) => setState(() {
                    pickedChannel = id;
                    channelRequired.clear();
                  }),
          ),
    onAddRow: () => setState(() {
      titles.add(TextEditingController()..addListener(_changed));
    }),
    onRemoveRow: (i) => setState(() {
      titles.removeAt(i).dispose();
    }),
    sourceSender: widget.sourceMessage?.senderName,
    sourceText: widget.sourceMessage?.text,
    status: taskV2 ? status : null,
    onStatusChanged: (next) => setState(() => status = next),
  );
}

/// Web `createFailureMessage`: the create's refusals a person can act on, in
/// their language; any other shows the server's sentence. [asMessage]: the
/// task was written as one message (task v2), not as titles.
String createTaskFailureText(
  Object error, {
  bool asMessage = false,
}) => switch (serverErrorCode(error)) {
  'membership_required' =>
    'Join this channel to create tasks in it: a new task posts its titles here as your message.',
  'quota_read_only' =>
    "This channel is read-only on your current plan, so tasks can't be created in it.",
  'channel_archived' =>
    'This channel is archived: unarchive it to create tasks in it.',
  'channel_access_changed' =>
    'Your access to this channel just changed. Refresh and try again.',
  'task_source_message_too_long' =>
    asMessage
        ? 'This message is too long to send as a task: shorten it.'
        : 'These titles are too long to post as one message: shorten them or create fewer at once.',
  _ => userErrorText(
    error,
    fallback: 'Failed to create task',
    where: 'create task',
  ),
};
