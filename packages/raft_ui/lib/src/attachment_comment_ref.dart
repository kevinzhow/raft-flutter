// Web `AttachmentCommentRefChip`: a comment on an attachment is a message of
// the attachment's thread; above its body a muted "re: filename · anchor" chip
// says what it is about (a link back to the attachment's message when the
// server resolved it), and the anchor's quote follows in a left-ruled block.
import 'package:flutter/material.dart';

import 'localization.dart';
import 'message_reference_chip.dart';
import 'theme.dart';
import 'tooltip.dart';

class RaftAttachmentCommentRef extends StatelessWidget {
  const RaftAttachmentCommentRef({
    super.key,
    required this.filename,
    this.anchorLabel,
    this.anchorQuote,
    this.onJump,
    this.fontSize = 14,
  });
  final String filename;

  /// `L12-14`, `Row 3`, `1:23`, ... (the server's `commentRef.anchorLabel`).
  final String? anchorLabel;
  final String? anchorQuote;

  /// Opens the attachment's message; null when the host could not be
  /// resolved (the chip is then a plain span, never a wrong jump).
  final VoidCallback? onJump;

  /// The message body's font size (the chip scales with it).
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final detail = anchorLabel == null || anchorLabel!.isEmpty
        ? filename
        : '$filename · $anchorLabel';
    final chip = RaftReferenceChip(
      label: raftFormat(context, 're: {name}', {'name': detail}),
      appearance: const RaftReferenceAppearance(
        RaftReferenceKind.attachmentComment,
      ),
      fontSize: fontSize,
    );
    final title = raftFormat(
      context,
      onJump != null
          ? 'Jump to the message with {detail}'
          : 'Comment on {detail}',
      {'detail': detail},
    );
    final quote = anchorQuote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: RaftTooltip(
            message: title,
            child: onJump == null
                ? chip
                : Semantics(
                    link: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onJump,
                      child: chip,
                    ),
                  ),
          ),
        ),
        if (quote != null && quote.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: t.colors['line-muted']!, width: 2),
              ),
            ),
            child: Text(
              quote,
              style: TextStyle(
                fontFamily: t.headingFont,
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w400,
                color: t.colors['foreground-muted'],
              ),
            ),
          ),
      ],
    );
  }
}
