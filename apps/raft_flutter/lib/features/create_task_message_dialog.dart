// Web v1.24 CreateTaskMessageDialog (components/task/CreateTaskMessageDialog
// .tsx, createTaskForm.ts): task v2's New task without a source message.
// Creating a task is sending a message: its first line is the task's title,
// the rest its description. The server posts it as the person's own message
// and creates the task from it (routes/tasks.ts postCreatorSourceMessage).
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/server_error_code.dart';
import '../data/workspace_controller.dart';
import 'create_task_channel.dart';
import 'create_task_dialog.dart' show createTaskFailureText, createdTaskRows;

/// Web `taskFromMessage`: the first line is the title, the rest (trimmed) the
/// description; null with no title yet.
({String title, String? description})? taskFromMessage(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final newline = trimmed.indexOf('\n');
  if (newline < 0) return (title: trimmed, description: null);
  final title = trimmed.substring(0, newline).trim();
  final description = trimmed.substring(newline + 1).trim();
  return (title: title, description: description.isEmpty ? null : description);
}

/// A random v4 UUID (`crypto.randomUUID`), the message's idempotency key.
String _randomUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
  return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10).join()}';
}

class CreateTaskMessageDialog extends StatefulWidget {
  const CreateTaskMessageDialog({
    super.key,
    required this.controller,
    this.channelId,
    this.defaultChannelId,
    this.onCreated,
    this.onCreatedTasks,
  });
  final WorkspaceController controller;

  /// The channel the message goes in; null (the Tasks page) asks for one.
  final String? channelId;
  final String? defaultChannelId;
  final Future<void> Function()? onCreated;

  /// The tasks the server made (the Tasks page opens the one it made).
  final void Function(List<Map<String, dynamic>> created)? onCreatedTasks;

  @override
  State<CreateTaskMessageDialog> createState() =>
      _CreateTaskMessageDialogState();
}

class _CreateTaskMessageDialogState extends State<CreateTaskMessageDialog> {
  final text = TextEditingController();
  String status = 'todo';
  bool submitting = false;
  late String? pickedChannel = createTaskInitialChannel(
    widget.controller,
    widget.defaultChannelId,
  );

  /// "Pick a channel": said under the field until a channel is picked.
  final channelRequired = CauseNotice();

  /// A failed send (the server's refusal, in the person's language where
  /// Raft has it); the next send clears it.
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next send starts; the dialog state is dropped when it closes.
  String? error;

  /// One key per message, so a retry after a failure reuses the message the
  /// server already posted instead of posting it again. A key belongs to one
  /// text in one channel: changing either takes a new one (the server refuses
  /// a reused key with other text, `source_random_id_reused`).
  ({String text, String id}) sourceKey = (text: '', id: _randomUuid());

  @override
  void initState() {
    super.initState();
    text.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  String? get channelLabel {
    if (widget.channelId == null) return null;
    final w = widget.controller;
    final channel = [
      ...w.channels,
      ...w.dms,
    ].where((c) => c.id == widget.channelId).firstOrNull;
    if (channel == null) return null;
    if (channel.type == 'dm') {
      final peer = channel.json['peerName'] ?? channel.name;
      return '@$peer';
    }
    return '#${channel.name}';
  }

  Future<void> submit() async {
    final draft = taskFromMessage(text.text);
    if (submitting || draft == null) return;
    final w = widget.controller;
    final channelId = widget.channelId ?? pickedChannel;
    if (channelId == null) {
      setState(
        () => channelRequired.raise(
          raftText(context, 'Pick a channel'),
          whileTrue: () => pickedChannel == null,
        ),
      );
      return;
    }
    if (!raftCanWriteTaskChannel(
      w.server?.string('role'),
      w.channelById(channelId),
    )) {
      setState(
        () => error = raftText(
          context,
          'Your access to this channel just changed. Refresh and try again.',
        ),
      );
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    final keyText = jsonEncode([channelId, draft.title, draft.description]);
    final key = sourceKey.text == keyText || sourceKey.text.isEmpty
        ? sourceKey.id
        : _randomUuid();
    sourceKey = (text: keyText, id: key);
    Future<dynamic> send(String randomId) => w.command(
      'POST',
      '/tasks/channel/$channelId',
      data: {
        'tasks': [
          {'title': draft.title, 'description': ?draft.description},
        ],
        'status': status,
        'sourceRandomId': randomId,
      },
    );
    try {
      dynamic answer;
      try {
        answer = await send(key);
      } catch (e) {
        // That key went with other text (a race with an earlier send): once
        // more with a new one.
        if (serverErrorCode(e) != 'source_random_id_reused') rethrow;
        final fresh = _randomUuid();
        sourceKey = (text: keyText, id: fresh);
        answer = await send(fresh);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreatedTasks?.call(createdTaskRows(answer));
      await widget.onCreated?.call();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = raftText(
            context,
            createTaskFailureText(e, asMessage: true),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => RaftCreateTaskMessageDialogView(
    text: text,
    status: status,
    onStatusChanged: (next) => setState(() => status = next),
    onClose: () => Navigator.of(context).maybePop(),
    onSubmit: submit,
    canSubmit: taskFromMessage(text.text) != null,
    channelLabel: channelLabel,
    channelField: widget.channelId != null
        ? null
        : RaftCreateTaskChannelField(
            label: 'Post in',
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
    error: error,
    submitting: submitting,
  );
}
