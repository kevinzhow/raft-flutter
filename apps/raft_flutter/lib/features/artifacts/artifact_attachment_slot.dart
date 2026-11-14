// "Save as Artifact" on a document attachment, and the line under it.
//
// Source: packages/web/src/apps/artifacts/ArtifactAttachment.tsx at
// v1.24.0-source.1 (`useArtifactAttachmentMenu`, `SavedLine`, `AttemptLine`):
// a ⋯ over the card's bottom corner (Download, Save as Artifact) while it can
// be saved and Artifacts are on; after it, "Saved as Artifact <title> v1"
// (opens the viewer), or "Saving as Artifact…", or why it failed with Retry.
// The line sits under its own card here, so it never needs Web's file name
// (docs/parity.md).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import '../icu_message.dart';
import 'artifact_api.dart';
import 'artifact_attachment_saves.dart';
import 'artifact_message_card.dart' show ArtifactBadge;
import 'artifact_models.dart';
import 'artifact_session.dart';
import 'artifact_text.dart';
import 'artifact_viewer_page.dart';

class ArtifactAttachmentSlot extends StatelessWidget {
  const ArtifactAttachmentSlot({
    super.key,
    required this.controller,
    required this.attachmentId,
    required this.filename,
    required this.sizeBytes,
    required this.onDownload,
    required this.child,
  });

  final WorkspaceController controller;
  final String attachmentId;
  final String filename;
  final int sizeBytes;
  final VoidCallback onDownload;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final session = ArtifactSession.of(controller);
    return ListenableBuilder(
      listenable: Listenable.merge([session, session.attachments]),
      builder: (context, _) {
        if (!session.enabled) return child;
        final saves = session.attachments;
        final savable = canSaveAsArtifact(
          id: attachmentId,
          filename: filename,
          sizeBytes: sizeBytes,
        );
        if (!attachmentId.startsWith('optimistic-att-')) {
          saves.request([attachmentId]);
        }
        final saved = saves.savedAs(attachmentId);
        final attempt = saves.attempt(attachmentId);
        final line = _line(context, session, saved, attempt);
        // Offered while it can be saved and nothing says it was (Web:
        // `enabled && !saved && canSaveAsArtifact`).
        final menu = saved == null && savable
            ? Positioned(
                right: RaftSpace.x1_5,
                bottom: RaftSpace.x1_5,
                child: _Menu(
                  filename: filename,
                  saving: attempt?.saving == true,
                  onDownload: onDownload,
                  onSave: () => unawaited(_save(context, saves)),
                ),
              )
            : null;
        if (menu == null && line == null) return child;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (menu == null) child else Stack(children: [child, menu]),
            ?line,
          ],
        );
      },
    );
  }

  Future<void> _save(BuildContext context, AttachmentSaves saves) async {
    final result = await saves.save(attachmentId);
    if (!context.mounted) return;
    String? message;
    var tone = RaftToastRecipeTone.info;
    switch (result.outcome) {
      case ArtifactSaveOutcome.created:
        message = raftFormat(context, 'Saved as Artifact “{title}”', {
          'title': result.title,
        });
        tone = RaftToastRecipeTone.success;
      case ArtifactSaveOutcome.existing:
        message = raftFormat(context, 'Already saved as Artifact “{title}”', {
          'title': result.title,
        });
        tone = RaftToastRecipeTone.success;
      case ArtifactSaveOutcome.hidden:
        message = raftText(
          context,
          'This attachment is already saved as an Artifact you can\'t see.',
        );
      case ArtifactSaveOutcome.failed || ArtifactSaveOutcome.ignored:
        break;
    }
    if (message != null) {
      showRaftToast(context, message, tone: tone);
    }
  }

  Widget? _line(
    BuildContext context,
    ArtifactSession session,
    ArtifactAttachmentSave? saved,
    ArtifactSaveAttempt? attempt,
  ) {
    if (saved != null) {
      final card = saved.card;
      if (card != null) {
        return _LineBox(
          key: const ValueKey('artifact-attachment-saved'),
          mark: RaftIcon(
            RaftGlyph.fileText,
            size: 14,
            semanticLabel: raftText(context, 'Saved as Artifact'),
          ),
          link: card.title,
          onOpen: () => unawaited(
            openWorkspaceArtifact(
              context,
              controller,
              ArtifactLinkTarget(card.id),
              seed: card,
            ),
          ),
          trailing: ArtifactBadge(artifactVersionLabel(context, card.version)),
        );
      }
      // One this reader can't see: only that it was saved, and the id-only
      // link. Saves never list a deleted Artifact, so that draws nothing.
      final url = saved.url;
      final target = url == null
          ? null
          : artifactLinkTarget(
              url,
              (session.deployment ??
                      ArtifactDeployment.resolve(
                        controller.client.origin,
                        null,
                      ))
                  .appHosts,
            );
      if (target == null) return null;
      return _LineBox(
        key: const ValueKey('artifact-attachment-saved'),
        mark: const RaftIcon(RaftGlyph.fileText, size: 14),
        link: raftText(context, 'Saved as Artifact'),
        onOpen: () => unawaited(
          openWorkspaceArtifact(
            context,
            controller,
            ArtifactLinkTarget(target.id),
          ),
        ),
      );
    }
    if (attempt == null) return null;
    if (attempt.saving) {
      return _LineBox(
        key: const ValueKey('artifact-attachment-saving'),
        mark: const RaftSpinner(size: 14),
        text: raftText(context, 'Saving as Artifact…'),
        live: true,
      );
    }
    final reason = switch (attempt.failure!) {
      ArtifactSaveFailure.uploading =>
        'Wait for the upload to finish, then save it.',
      ArtifactSaveFailure.tooLarge =>
        'This file is too large to save as an Artifact.',
      ArtifactSaveFailure.notFound =>
        'This attachment isn\'t available any more.',
      ArtifactSaveFailure.quota => 'This month\'s uploads are used up',
      ArtifactSaveFailure.failed => 'Couldn\'t save it as an Artifact.',
    };
    return _LineBox(
      key: const ValueKey('artifact-attachment-save-failed'),
      mark: const RaftIcon(RaftGlyph.triangleAlert, size: 14),
      text: raftText(context, reason),
      live: true,
      retry: attempt.retryable
          ? () => unawaited(_save(context, session.attachments))
          : null,
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.filename,
    required this.saving,
    required this.onDownload,
    required this.onSave,
  });

  final String filename;
  final bool saving;
  final VoidCallback onDownload;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final label = raftFormat(context, 'More actions for {filename}', {
      'filename': filename,
    });
    return RaftDropdownMenu(
      key: const ValueKey('artifact-attachment-menu'),
      label: label,
      surfaceKey: const ValueKey('artifact-attachment-menu-surface'),
      kind: RaftMenuKind.dropdownMenu,
      align: RaftDropdownAlign.end,
      sideOffset: 4,
      width: 200,
      entries: [
        RaftMenuEntry(
          label: raftText(context, 'Download'),
          glyph: RaftGlyph.download,
          onPressed: onDownload,
        ),
        // While it saves, the line under the attachment says so; a second
        // click starts nothing.
        RaftMenuEntry(
          label: raftText(context, 'Save as Artifact'),
          glyph: RaftGlyph.fileText,
          onPressed: saving ? null : onSave,
        ),
      ],
      triggerBuilder: (context, focus, onPressed) => RaftButton(
        key: const ValueKey('artifact-attachment-menu-trigger'),
        glyph: RaftGlyph.ellipsisVertical,
        tooltip: label,
        semanticLabel: label,
        focusNode: focus,
        tone: RaftButtonRecipeVariant.ghost,
        size: RaftButtonRecipeSize.iconSm,
        onPressed: onPressed,
      ),
    );
  }
}

/// The saved, saving and failed lines share one height (Web: the version
/// badge's 22 px), so the turn from one to the next moves nothing under it.
class _LineBox extends StatelessWidget {
  const _LineBox({
    super.key,
    required this.mark,
    this.link,
    this.text,
    this.onOpen,
    this.trailing,
    this.retry,
    this.live = false,
  });

  final Widget mark;
  final String? link;
  final String? text;
  final VoidCallback? onOpen;
  final Widget? trailing;
  final VoidCallback? retry;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    Widget content = ConstrainedBox(
      // ds-allow: Web's line (min-h-[22px] max-w-[22.5rem]) has no raft_ui recipe
      constraints: const BoxConstraints(minHeight: 22, maxWidth: 360),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: RaftSpace.x1_5,
        children: [
          // ds-allow: the 14 px icon slot of Web's saved line (size-3.5)
          SizedBox.square(dimension: 14, child: Center(child: mark)),
          Flexible(
            child: link != null
                ? RaftTextLink(label: link!, onPressed: onOpen)
                : Text(
                    text ?? '',
                    style: RaftTypography.body(
                      t,
                      size: 12,
                      line: 16,
                      color: t.ui.foregroundMuted,
                    ),
                  ),
          ),
          ?trailing,
          if (retry != null)
            RaftTextLink(
              key: const ValueKey('artifact-attachment-save-retry'),
              label: raftText(context, 'Retry'),
              onPressed: retry,
            ),
        ],
      ),
    );
    if (live) content = Semantics(liveRegion: true, child: content);
    return Padding(
      padding: const EdgeInsets.only(top: RaftSpace.x1),
      child: content,
    );
  }
}
