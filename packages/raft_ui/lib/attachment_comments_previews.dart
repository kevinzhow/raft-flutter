import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Attachment comments', size: Size(390, 420))
Widget attachmentCommentsPreview() => const _CommentsPreview();

class _CommentsPreview extends StatefulWidget {
  const _CommentsPreview();
  @override
  State<_CommentsPreview> createState() => _CommentsPreviewState();
}

class _CommentsPreviewState extends State<_CommentsPreview> {
  bool anchored = true, blocked = false;
  String result = 'Ready';
  @override
  Widget build(BuildContext context) {
    final column = Column(
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RaftButton.text(
              onPressed: () => setState(() => blocked = !blocked),
              child: const Text('Toggle Read-only'),
            ),
            Text(result),
          ],
        ),
        _Fill(
          child: RaftAttachmentCommentsPanel(
            filename: 'public-notes.txt',
            comments: [
              RaftAttachmentCommentView(
                id: 'public-comment',
                senderName: 'Public reviewer',
                content:
                    'Keep the source reference and this explanation together.',
                timestamp: '10:30',
                anchorLabel: 'L2–4',
                onJump: () => setState(() => result = 'Jump to L2–4'),
                avatar: const RaftAvatar(name: 'Public reviewer', size: 20),
              ),
            ],
            blockedMessage: blocked ? 'Channel archived' : null,
            composer: RaftComposer(
              variant: RaftComposerVariant.compact,
              hint: 'Comment on public-notes.txt…',
              accessoryRow: anchored
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: RaftCommentAnchorChip(
                        label: 'L2–4',
                        removeLabel: 'Remove Anchor',
                        onRemove: () => setState(() => anchored = false),
                      ),
                    )
                  : null,
              onSend: (value) async {
                setState(() {
                  result = 'Comment submitted';
                  anchored = false;
                });
                return true;
              },
            ),
          ),
        ),
      ],
    );
    // Larger text needs a taller panel than the 420px preview viewport.
    if (!RaftScaled.grows(context)) return column;
    return SingleChildScrollView(child: column);
  }
}

/// The panel fills the preview below the toolbar (it scrolls its own list); at
/// larger text sizes it keeps the height the text needs.
class _Fill extends StatelessWidget {
  const _Fill({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => RaftScaled.grows(context)
      ? SizedBox(height: RaftScaled.extent(context, 360), child: child)
      : Expanded(child: child);
}
