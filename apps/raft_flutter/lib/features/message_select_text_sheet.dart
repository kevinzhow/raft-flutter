import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web `MessageSelectTextDrawer`: "Select text" on a touch screen opens a
/// bottom sheet (at every width, as Web's Drawer is) holding the message's
/// Markdown source as selectable text. Copy and Quote take the selection, or
/// the whole message when nothing is selected.
Future<void> showMessageSelectTextSheet(
  BuildContext context, {
  required String senderName,
  required String time,
  required String markdown,
  required void Function(String text) onQuote,
}) => showRaftPresented<void>(
  context,
  policy: const RaftPresentationPolicy(
    compact: RaftSurfaceForm.sheet,
    medium: RaftSurfaceForm.sheet,
    wide: RaftSurfaceForm.sheet,
  ),
  sheetInitialSize: RaftSheetMetrics.mediumDetent,
  label: 'Select text',
  content: (context, form) => _SelectTextSheet(
    senderName: senderName,
    time: time,
    markdown: markdown,
    onQuote: onQuote,
  ),
);

class _SelectTextSheet extends StatefulWidget {
  const _SelectTextSheet({
    required this.senderName,
    required this.time,
    required this.markdown,
    required this.onQuote,
  });
  final String senderName, time, markdown;
  final void Function(String text) onQuote;

  @override
  State<_SelectTextSheet> createState() => _SelectTextSheetState();
}

class _SelectTextSheetState extends State<_SelectTextSheet> {
  // The text the reader has selected; empty means the whole message.
  String _selected = '';
  bool _copied = false;

  String get _source => _selected.trim().isEmpty ? widget.markdown : _selected;

  void _onSelection(SelectedContent? content) =>
      _selected = content?.plainText ?? '';

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _source));
    if (mounted) setState(() => _copied = true);
  }

  void _quote() {
    widget.onQuote(_source);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final media = MediaQuery.of(context);
    return KeyedSubtree(
      key: const ValueKey('message-select-text'),
      child: RaftSheet(
        headerExtent: RaftSheetMetrics.minDragTarget,
        header: Padding(
          padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    raftText(context, 'Select text'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.scale(RaftTypeScale.headline, color: t.ink),
                  ),
                ),
              ),
              RaftSheetClose(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x4),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x1,
          children: [
            Text(
              raftText(context, 'Press and hold to select text.'),
              style: t.scale(RaftTypeScale.footnote, color: t.muted),
            ),
            Text(
              '${widget.senderName} · ${widget.time}',
              style: t.scale(RaftTypeScale.footnote, color: t.muted),
            ),
            ConstrainedBox(
              // ds-allow: Web caps the text at 50dvh (MessageSelectTextDrawer), a window ratio
              constraints: BoxConstraints(maxHeight: media.size.height / 2),
              child: SingleChildScrollView(
                child: Semantics(
                  label: raftFormat(context, 'Message from {sender}', {
                    'sender': widget.senderName,
                  }),
                  child: RaftSelectionArea(
                    onSelectionChanged: _onSelection,
                    child: Text(
                      widget.markdown,
                      style: t.scale(RaftTypeScale.body, color: t.ink),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        footer: Padding(
          padding: const EdgeInsets.all(RaftSpace.x4),
          child: Row(
            spacing: RaftSpace.x2,
            children: [
              Expanded(
                child: RaftButton(
                  label: raftText(context, _copied ? 'Copied' : 'Copy'),
                  glyph: _copied ? RaftGlyph.check : RaftGlyph.copy,
                  tone: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.lg,
                  expand: true,
                  onPressed: _copy,
                ),
              ),
              Expanded(
                child: RaftButton(
                  label: raftText(context, 'Quote'),
                  glyph: RaftGlyph.textQuote,
                  tone: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.lg,
                  expand: true,
                  onPressed: _quote,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
