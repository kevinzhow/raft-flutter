import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/cause_notice.dart';
import 'artifact_api.dart';
import 'artifact_models.dart';
import 'artifact_sharing_api.dart';
import 'artifact_text.dart';

enum ArtifactManageAction { rename, visibility }

Future<ArtifactViewerData?> showArtifactManageDialog(
  BuildContext context, {
  required ArtifactSharingApi api,
  required ArtifactViewerData data,
  required ArtifactManageAction action,
  required bool Function() current,
  String? conversationName,
  String? serverName,
}) => showRaftDialog<ArtifactViewerData>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ArtifactManageDialog(
    api: api,
    data: data,
    action: action,
    current: current,
    conversationName: conversationName,
    serverName: serverName,
  ),
);

class ArtifactManageDialog extends StatefulWidget {
  const ArtifactManageDialog({
    super.key,
    required this.api,
    required this.data,
    required this.action,
    required this.current,
    this.conversationName,
    this.serverName,
  });

  final ArtifactSharingApi api;
  final ArtifactViewerData data;
  final ArtifactManageAction action;
  final bool Function() current;
  final String? conversationName, serverName;

  @override
  State<ArtifactManageDialog> createState() => _ArtifactManageDialogState();
}

class _ArtifactManageDialogState extends State<ArtifactManageDialog> {
  late final title = TextEditingController(text: widget.data.card.title);
  ArtifactHomeTarget? target;
  ArtifactHomeLoss? loss;
  final refusalNotice = CauseNotice();
  bool working = false;
  bool previewing = false;
  bool confirming = false;
  bool changed = false;

  ArtifactViewerData get data => widget.data;
  String get id => data.card.id;
  String get home => data.card.home.kind;
  bool get rename => widget.action == ArtifactManageAction.rename;
  bool get turningOffLink => home == 'public' && target?.kind == 'server';
  bool get unpublish => turningOffLink && !data.capabilities.narrowHome;
  bool get narrowing =>
      target?.kind == 'conversation' ||
      turningOffLink && data.capabilities.narrowHome;

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  void choose(ArtifactHomeTarget to) {
    final immediate = to.kind == 'server' && home == 'conversation';
    setState(() {
      target = to;
      loss = null;
      refusalNotice.clear();
      changed = false;
      confirming = !immediate;
    });
    if (immediate) {
      unawaited(save());
    } else if (narrowing) {
      unawaited(preview());
    }
  }

  Future<void> preview() async {
    final to = target;
    if (to == null || previewing) return;
    setState(() {
      previewing = true;
      loss = null;
      refusalNotice.clear();
    });
    try {
      final answer = await widget.api.preview(id, to);
      if (mounted && identical(to, target)) setState(() => loss = answer);
    } catch (failure) {
      if (mounted && identical(to, target)) {
        setState(() {
          refusalNotice.raise(
            artifactErrorCode(failure) == null
                ? "Couldn't check who would lose access. Try again."
                : refusal(failure),
          );
        });
      }
    } finally {
      if (mounted && identical(to, target)) setState(() => previewing = false);
    }
  }

  String refusal(Object failure) => switch (artifactErrorCode(failure)) {
    'FORBIDDEN' =>
      rename
          ? "You can't rename this Artifact."
          : "You can't change who can see this Artifact.",
    'NOT_VISIBLE' => "This Artifact isn't available any more.",
    'NAME_TAKEN' => 'An Artifact with this name already lives there. Rename one of them first.',
    'TARGET_NOT_FOUND' =>
      "You can't see that conversation any more, so it can't go back there.",
    'NOT_PUBLIC' => 'Link sharing is already off for this Artifact.',
    'NOT_ORIGINAL_HOME' || 'HOME_NOT_NARROWER' => "Who can see it changed in the meantime, so it can't be narrowed this way any more.",
    'HOME_NOT_WIDER' => 'Who can see it changed in the meantime. Check where it is now, then choose again.',
    'RATE_LIMITED' =>
      'Too many changes in a short time. Wait a moment, then try again.',
    _ =>
      rename
          ? "Couldn't rename this Artifact. Try again."
          : unpublish
          ? "Couldn't turn off link sharing. Try again."
          : "Couldn't change who can see it. Try again.",
  };

  Future<void> save() async {
    if (working || (narrowing && loss == null)) return;
    if (!widget.current()) {
      setState(
        () => refusalNotice.raise("This Artifact isn't available any more."),
      );
      return;
    }
    final name = title.text.trim().replaceAll(RegExp(r'[\r\n]+'), ' ');
    if (rename && (name.isEmpty || name == data.card.title)) return;
    final to = target;
    if (!rename && to == null) return;
    setState(() {
      working = true;
      refusalNotice.clear();
    });
    try {
      final result = rename
          ? await widget.api.rename(id, name)
          : unpublish
          ? await widget.api.unpublish(id)
          : await widget.api.move(id, to!, loss: loss);
      if (!mounted) return;
      setState(() => working = false);
      Navigator.of(context).pop(result);
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        working = false;
        refusalNotice.raise(refusal(failure));
      });
      if (narrowing && artifactErrorCode(failure) == 'LOSS_CHANGED') {
        setState(() => changed = true);
        await preview();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String text(String value) => raftText(context, value);
    final label = rename
        ? 'Rename Artifact'
        : turningOffLink
        ? 'Turn off link sharing?'
        : narrowing
        ? 'Move to a conversation'
        : 'Who can see it';
    return PopScope(
      canPop: !working,
      child: RaftDialog(
        contentKey: const Key('artifact-manage-dialog'),
        title: Text(text(label)),
        closeEnabled: !working,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rename)
              RaftDialogTextInput(
                controller: title,
                placeholder: 'Artifact title',
                autofocus: RaftInteraction.of(context).pointer,
                onSubmitted: (_) => unawaited(save()),
                enabled: !working,
              )
            else if (!confirming) ...[
              Text(
                artifactScopeLabel(
                  context,
                  data.card.home,
                  serverName: widget.serverName,
                ),
              ),
              if (home == 'conversation' && data.capabilities.changeHome ||
                  home == 'public' &&
                      (data.capabilities.narrowHome ||
                          data.capabilities.unpublish))
                option(
                  context,
                  'Everyone in this server',
                  const ArtifactHomeTarget.server(),
                ),
              if (data.capabilities.changeHome && home != 'public')
                option(
                  context,
                  'Anyone with the link',
                  const ArtifactHomeTarget.public(),
                ),
              if (data.capabilities.narrowHome &&
                  data.originalConversationId != null)
                option(
                  context,
                  widget.conversationName ?? 'A conversation',
                  ArtifactHomeTarget.conversation(data.originalConversationId!),
                ),
            ] else ...[
              if (unpublish || loss?.leavesPublic == true)
                Text(
                  text(
                    "People outside this server and visitors who aren't signed in can't open the link any more.",
                  ),
                ),
              if (target?.kind == 'public')
                Text(
                  text(
                    "Anyone with the link can view it, and it won't show up in search engines.",
                  ),
                ),
              if (previewing) Text(text('Checking who would lose access…')),
              if (changed)
                Text(
                  text(
                    'The number changed since you looked. Check the new one, then confirm again.',
                  ),
                ),
              if (loss case final impact?
                  when impact.people + impact.agents > 0)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    raftFormat(
                      context,
                      '{people} people and {agents} agents will lose access.',
                      {
                        'people': '${impact.people}',
                        'agents': '${impact.agents}',
                      },
                    ),
                  ),
                ),
              if (narrowing && refusalNotice.isActive && loss == null)
                RaftButton(label: text('Try again'), onPressed: preview),
            ],
            if (refusalNotice.message case final message?)
              Semantics(liveRegion: true, child: Text(text(message))),
          ],
        ),
        actions: [
          RaftButton(
            label: text('Cancel'),
            secondary: true,
            onPressed: working ? null : () => Navigator.of(context).pop(),
          ),
          if (rename || confirming)
            RaftButton(
              label: text(
                rename
                    ? 'Save'
                    : turningOffLink
                    ? 'Turn off link sharing'
                    : narrowing
                    ? 'Move to conversation'
                    : 'Confirm',
              ),
              onPressed: working || previewing || narrowing && loss == null
                  ? null
                  : save,
            ),
        ],
      ),
    );
  }

  Widget option(BuildContext context, String label, ArtifactHomeTarget to) =>
      RaftListRow(
        onPressed: working ? null : () => choose(to),
        children: [Expanded(child: RaftListRowTitle(raftText(context, label)))],
      );
}
