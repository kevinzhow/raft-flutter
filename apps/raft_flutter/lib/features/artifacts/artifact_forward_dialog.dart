import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/cause_notice.dart';
import '../../data/workspace_controller.dart';
import '../forward_composer_page.dart'
    show forwardRecentTargets, forwardTargetIcon, forwardTargetPickerLabel;
import 'artifact_api.dart';
import 'artifact_models.dart';
import 'artifact_sharing_api.dart';

Future<({String messageId, ArtifactHome? home})?> showArtifactForwardDialog(
  BuildContext context, {
  required WorkspaceController workspace,
  required ArtifactCard card,
  required bool Function() current,
}) => showRaftDialog<({String messageId, ArtifactHome? home})>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      ArtifactForwardDialog(workspace: workspace, card: card, current: current),
);

class ArtifactForwardDialog extends StatefulWidget {
  const ArtifactForwardDialog({
    super.key,
    required this.workspace,
    required this.card,
    required this.current,
  });

  final WorkspaceController workspace;
  final ArtifactCard card;
  final bool Function() current;

  @override
  State<ArtifactForwardDialog> createState() => _ArtifactForwardDialogState();
}

class _ArtifactForwardDialogState extends State<ArtifactForwardDialog> {
  late final api = ArtifactSharingApi(widget.workspace.client);
  final note = TextEditingController();
  final search = TextEditingController();
  final searchFocus = FocusNode();
  final audiences = <String, ArtifactShareAudience>{};
  RaftChannel? destination;
  String choice = 'send';
  late final sendNotice = CauseNotice(scope: () => destination?.id);
  late final audienceNotice = CauseNotice(scope: () => destination?.id);
  ({String destination, String? note, String choice, String key})? attempt;
  bool loading = false, sending = false, gone = false;
  int reads = 0;

  @override
  void dispose() {
    searchFocus.dispose();
    search.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> pick(RaftChannel channel, {bool refresh = false}) async {
    final read = ++reads;
    setState(() {
      if (destination?.id != channel.id) {
        choice = 'send';
        sendNotice.clear();
      }
      destination = channel;
      audienceNotice.clear();
      gone = false;
      loading = refresh || !audiences.containsKey(channel.id);
    });
    if (!loading) return;
    try {
      final audience = await api.audience(widget.card.id, channel.id);
      if (!mounted || read != reads) return;
      setState(() {
        audiences[channel.id] = audience;
        if (!audience.widenTo.contains(choice)) choice = 'send';
      });
    } catch (failure) {
      if (!mounted || read != reads) return;
      setState(() {
        audiences.remove(channel.id);
        choice = 'send';
        gone = artifactErrorCode(failure) == 'TARGET_NOT_FOUND';
        audienceNotice.raise(
          gone
              ? "You can't send to this conversation any more. Choose another conversation."
              : "Couldn't check who can see it. Try again, or choose another conversation.",
        );
      });
    } finally {
      if (mounted && read == reads) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final target = destination;
    if (target == null || loading || sending || gone) return;
    if (!widget.current()) {
      setState(
        () => sendNotice.raise("This Artifact isn't available any more."),
      );
      return;
    }
    final trimmed = note.text.trim();
    final message = trimmed.isEmpty ? null : trimmed;
    if (trimmed.runes.length > 1000) {
      setState(() => sendNotice.raise('Keep the note to 1,000 characters.'));
      return;
    }
    final last = attempt;
    final key =
        last != null &&
            last.destination == target.id &&
            last.note == message &&
            last.choice == choice
        ? last.key
        : widget.workspace.client.newRandomId();
    attempt = (destination: target.id, note: message, choice: choice, key: key);
    setState(() {
      sending = true;
      sendNotice.clear();
    });
    try {
      final result = await api.share(
        widget.card.id,
        conversation: target.id,
        note: message,
        widenTo: choice == 'send' ? null : choice,
        clientKey: key,
      );
      if (!mounted) return;
      setState(() => sending = false);
      Navigator.of(context).pop(result);
    } catch (failure) {
      if (!mounted) return;
      final code = artifactErrorCode(failure);
      setState(() {
        sending = false;
        gone = code == 'TARGET_NOT_FOUND';
        sendNotice.raise(switch (code) {
          'FORBIDDEN' => "You can no longer change who can see it. Send it as it is, or cancel.",
          'NAME_TAKEN' => 'An Artifact with this name already lives there, so nothing was moved or sent. Send it as it is, or cancel.',
          'TARGET_NOT_FOUND' => "You can't send to this conversation any more. Choose another conversation.",
          'NOT_VISIBLE' => "This Artifact isn't available any more.",
          _ => "Couldn't send it. Try again.",
        });
      });
      if (code == 'FORBIDDEN' || code == 'NAME_TAKEN') {
        await pick(target, refresh: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String text(String value) => raftText(context, value);
    final target = destination;
    final audience = audiences[target?.id];
    final query = search.text.trim().toLowerCase();
    final choices = [
      for (final row in forwardRecentTargets(
        widget.workspace.channels,
        widget.workspace.dms,
      ))
        if (row.canPost &&
            forwardTargetPickerLabel(row).toLowerCase().contains(query))
          row,
    ];
    return PopScope(
      canPop: !sending,
      child: RaftDialog(
        contentKey: const Key('artifact-forward-dialog'),
        title: Text(text('Send to conversation')),
        closeEnabled: !sending,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftSearchInput(
              controller: search,
              focusNode: searchFocus,
              hint: text('Search channels and DMs'),
              clearLabel: text('Clear search'),
              onClear: () => setState(search.clear),
              onChanged: (_) => setState(() {}),
            ),
            for (final row in choices)
              RaftForwardTargetRow(
                selected: row.id == target?.id,
                checkbox: false,
                label: forwardTargetPickerLabel(row),
                icon: forwardTargetIcon(
                  widget.workspace.client.origin,
                  type: row.type,
                  name: forwardTargetPickerLabel(row),
                ),
                onTap: sending ? null : () => unawaited(pick(row)),
              ),
            if (choices.isEmpty)
              Text(text('No destinations match your search')),
            if (target != null) ...[
              RaftDialogTextInput(
                controller: note,
                placeholder: 'Add a note',
                multiline: true,
                enabled: !sending,
              ),
              if (loading) Text(text('Checking who can see it…')),
              if (audienceNotice.message case final message?)
                Text(text(message)),
              if (audienceNotice.isActive && !gone)
                RaftButton(
                  label: text('Try again'),
                  onPressed: () => unawaited(pick(target, refresh: true)),
                ),
              if (audience case final visible? when visible.cannotSee > 0) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    raftFormat(
                      context,
                      "{count} people in {target} can't see this Artifact",
                      {
                        'count':
                            '${visible.cannotSee}${visible.capped ? '+' : ''}',
                        'target': forwardTargetPickerLabel(target),
                      },
                    ),
                  ),
                ),
                RaftSelectField<String>(
                  label: text('How to send it'),
                  value: choice,
                  items: [
                    RaftSelectItem(value: 'send', label: text('Send anyway')),
                    if (visible.widenTo.contains('server'))
                      RaftSelectItem(
                        value: 'server',
                        label: text('Make visible to everyone in this server'),
                      ),
                    if (visible.widenTo.contains('public'))
                      RaftSelectItem(
                        value: 'public',
                        label: text('Let anyone with the link open it'),
                      ),
                  ],
                  onChanged: sending
                      ? null
                      : (value) {
                          if (value != null) setState(() => choice = value);
                        },
                ),
              ],
            ],
            if (sendNotice.message case final message?)
              Semantics(liveRegion: true, child: Text(text(message))),
          ],
        ),
        actions: [
          RaftButton(
            label: text('Cancel'),
            secondary: true,
            onPressed: sending ? null : () => Navigator.of(context).pop(),
          ),
          RaftButton(
            label: text('Send'),
            onPressed: target == null || sending || loading || gone
                ? null
                : send,
          ),
        ],
      ),
    );
  }
}
