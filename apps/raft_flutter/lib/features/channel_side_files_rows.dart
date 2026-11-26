// The rows of the Files panel that the Files card beside the chat draws:
// the compact row (Web `compact` variant of ChannelFilesPanelFileRow and
// ChannelFilesArtifactRow, raft-design patterns/tasks.md "Rows in a compact
// list") and the conversation's Artifact rows in both variants.
//
// Source: packages/web/src/components/message/{ChannelFilesPanelFileRow,
// ChannelFilesArtifactRow}.tsx and components/task/compactRow.ts at
// v1.24.0-source.1.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_channel_files_store.dart';
import 'artifacts/artifact_models.dart';
import 'artifacts/artifact_text.dart';
import 'channel_side_files_artifacts.dart';
import 'source_channel_file_glyph.dart';
import 'source_channel_files_view.dart';

/// A compact row's size: its inline padding is the margin of the column it
/// sits in (20px, 16px on a phone width), at least 36px high with a mouse and
/// 44px by touch (`COMPACT_ROW_BODY`).
class CompactRowMetrics {
  CompactRowMetrics(BuildContext context)
    : inset = RaftAdaptiveWorkspace.compactOf(context) ? 16 : 20,
      touch = RaftInteraction.of(context).touch;
  final double inset;
  final bool touch;
  double get minHeight => touch ? 44 : 36;
  double get vertical => touch ? 6 : 5.5;

  /// The 20px leading block and its gap.
  static const mark = 20.0, gap = 8.0;

  /// The trailing group's room (compact time and the ⋯ box); under that and
  /// the title's 160px it wraps, whole, under the title.
  static const titleRoom = 160.0, trailingRoom = 112.0;

  bool wraps(double width) =>
      width - 2 * inset - mark - gap - titleRoom < trailingRoom;
}

/// The row's frame: hairline above (but the first), hover fill, the margin.
class CompactRowFrame extends StatefulWidget {
  const CompactRowFrame({
    super.key,
    required this.child,
    this.divider = true,
    this.onTap,
  });
  final Widget child;
  final bool divider;

  /// The rest of the row opens too, not only the main button.
  final VoidCallback? onTap;
  @override
  State<CompactRowFrame> createState() => _CompactRowFrameState();
}

class _CompactRowFrameState extends State<CompactRowFrame> {
  var hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), m = CompactRowMetrics(context);
    final body = Stack(
      children: [
        Container(
          color: hovered ? t.colors['fill-subtle'] : null,
          constraints: BoxConstraints(minHeight: m.minHeight),
          padding: EdgeInsets.symmetric(vertical: m.vertical),
          alignment: Alignment.centerLeft,
          child: widget.child,
        ),
        if (widget.divider)
          Positioned(
            top: 0,
            left: m.inset,
            right: m.inset,
            height: RaftSpace.hairline,
            child: ColoredBox(color: t.colors['line-hairline']!),
          ),
      ],
    );
    return RaftHoverRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: widget.onTap == null
          ? body
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: widget.onTap,
              child: body,
            ),
    );
  }
}

TextStyle _title(RaftTokens t) =>
    t.scale(RaftTypeScale.callout, color: t.strong);
TextStyle _meta(RaftTokens t) =>
    t.scale(RaftTypeScale.monoMeta, mono: true, color: t.ui.foregroundHint);

Widget _time(
  BuildContext context,
  String shown,
  String? full,
  TextStyle style,
) {
  final text = Text(shown, style: style, maxLines: 1);
  return full == null ? text : RaftTooltip(message: full, child: text);
}

/// One file as a compact row: the type icon (a 20px thumbnail for an image),
/// the name with its size right after it, then the compact time and the ⋯
/// menu at the right.
class ChannelFilesCompactRow extends StatelessWidget {
  const ChannelFilesCompactRow({
    super.key,
    required this.file,
    required this.width,
    required this.formattedDate,
    required this.onPreview,
    required this.onOpenSource,
    required this.onDownload,
    this.fullDate,
    this.thumbnail,
    this.divider = true,
  });
  final SourceChannelFileEntry file;
  final double width;
  final String formattedDate;

  /// Shown on hover over the compact time.
  final String? fullDate;
  final VoidCallback onPreview, onOpenSource, onDownload;
  final Widget? thumbnail;
  final bool divider;

  Widget _mark(RaftTokens t) {
    final image = file.mimeType.toLowerCase().startsWith('image/');
    return SizedBox.square(
      dimension: CompactRowMetrics.mark,
      child: image && thumbnail != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(RaftSpace.x1),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(RaftSpace.x1),
                  border: Border.all(color: t.colors['line-hairline']!),
                ),
                child: thumbnail,
              ),
            )
          : Center(
              child: ChannelFileGlyph(
                channelFileType(file),
                size: 16,
                color: t.colors['foreground-hint'],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), m = CompactRowMetrics(context);
    final name = RaftTooltip(
      message: file.filename,
      child: Text(
        file.filename,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _title(t),
      ),
    );
    final title = Row(
      children: [
        _mark(t),
        const SizedBox(width: CompactRowMetrics.gap),
        Flexible(child: name),
        const SizedBox(width: RaftSpace.x1_5),
        Text(sourceChannelFileSize(file.sizeBytes), style: _meta(t)),
      ],
    );
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _time(context, formattedDate, fullDate, _meta(t)),
        const SizedBox(width: CompactRowMetrics.gap),
        // The last icon box ends on the row's margin, its hit area hanging
        // outward (raft-design foundations/alignment.md).
        ChannelFileOverflowMenu(
          compact: true,
          file: file,
          onOpenSource: onOpenSource,
          onDownload: onDownload,
        ),
      ],
    );
    final wrapped = m.wraps(width);
    final main = ChannelFileOpen(
      key: ValueKey('channel-file-preview-${file.id}'),
      label: raftText(context, 'Preview file'),
      onPressed: onPreview,
      minHeight: 0,
      child: title,
    );
    return CompactRowFrame(
      divider: divider,
      onTap: onPreview,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: m.inset,
          end: m.inset - RaftSpace.x2,
        ),
        child: wrapped
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  main,
                  Align(alignment: Alignment.centerRight, child: trailing),
                ],
              )
            : Row(
                children: [
                  Expanded(child: main),
                  trailing,
                ],
              ),
      ),
    );
  }
}

String _version(BuildContext context, ArtifactCard card) =>
    raftFormat(context, 'v{version}', {'version': '${card.latestVersion}'});

/// One of the conversation's Artifacts among its files: the kind's icon, the
/// title, the version and when it was last updated. The whole row opens the
/// viewer.
class ConversationArtifactRow extends StatefulWidget {
  const ConversationArtifactRow({
    super.key,
    required this.card,
    required this.compact,
    required this.formattedDate,
    required this.onOpen,
    this.fullDate,
    this.divider = true,
  });
  final ArtifactCard card;
  final bool compact, divider;
  final String formattedDate;
  final String? fullDate;
  final VoidCallback onOpen;
  @override
  State<ConversationArtifactRow> createState() => _ArtifactRowState();
}

class _ArtifactRowState extends State<ConversationArtifactRow> {
  var hovered = false;

  // Read as "Artifact <title>, v<n>": the row says what it is among the
  // files; the visible parts are not read twice.
  String _label(BuildContext context) => raftFormat(
    context,
    'Artifact {title}, v{version}',
    {'title': widget.card.title, 'version': '${widget.card.latestVersion}'},
  );

  @override
  Widget build(BuildContext context) =>
      widget.compact ? _compact(context) : _card(context);

  Widget _compact(BuildContext context) {
    final t = RaftTokens.of(context), m = CompactRowMetrics(context);
    final card = widget.card;
    return CompactRowFrame(
      divider: widget.divider,
      child: ChannelFileOpen(
        label: _label(context),
        onPressed: widget.onOpen,
        minHeight: 0,
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: m.inset, end: m.inset),
          child: Row(
            children: [
              SizedBox.square(
                dimension: CompactRowMetrics.mark,
                child: Center(
                  child: RaftIcon(
                    artifactKindGlyph(card.kind),
                    size: 16,
                    color: t.colors['foreground-hint'],
                  ),
                ),
              ),
              const SizedBox(width: CompactRowMetrics.gap),
              Flexible(
                child: RaftTooltip(
                  message: card.title,
                  child: Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _title(t),
                  ),
                ),
              ),
              const SizedBox(width: RaftSpace.x1_5),
              Text(_version(context, card), style: _meta(t)),
              const Spacer(),
              const SizedBox(width: CompactRowMetrics.gap),
              _time(context, widget.formattedDate, widget.fullDate, _meta(t)),
              // The file rows' action slot (their ⋯), kept empty: the time
              // stands where theirs does.
              const SizedBox(width: RaftSpace.x6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final t = RaftTokens.of(context), recipe = SourceChannelFilesRecipe(t);
    final card = widget.card;
    final controlRadius = t.size('radius.control', fallback: 8);
    return RaftCard.item(
      interactive: true,
      padding: recipe.rowInset,
      child: ChannelFileOpen(
        label: _label(context),
        onPressed: widget.onOpen,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: recipe.thumbnailSize,
              height: recipe.thumbnailSize,
              decoration: BoxDecoration(
                color: t.ui.fillMuted,
                borderRadius: BorderRadius.circular(controlRadius),
                border: Border.all(color: t.ui.lineHairline),
              ),
              child: Center(
                child: RaftIcon(artifactKindGlyph(card.kind), size: 18),
              ),
            ),
            SizedBox(width: recipe.bodyGap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: recipe.filename,
                  ),
                  SizedBox(height: recipe.textGap),
                  Wrap(
                    spacing: RaftSpace.x2,
                    runSpacing: RaftSpace.x1,
                    children: [
                      Text(_version(context, card), style: recipe.metadata),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RaftIcon(
                            RaftGlyph.clock3,
                            size: 12,
                            color: recipe.metadata.color,
                          ),
                          const SizedBox(width: RaftSpace.x1),
                          Flexible(
                            child: _time(
                              context,
                              widget.formattedDate,
                              widget.fullDate,
                              recipe.metadata,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ConversationArtifactsNoteKind { loading, failed, more }

/// Loading, error with Try again, or Show more, in the list's own width.
class ConversationArtifactsNote extends StatelessWidget {
  const ConversationArtifactsNote({
    super.key,
    required this.kind,
    this.onPressed,
    this.more = ConversationArtifactsMore.idle,
  });
  final ConversationArtifactsNoteKind kind;

  /// Try again, or Show more.
  final VoidCallback? onPressed;
  final ConversationArtifactsMore more;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final danger = t.scale(RaftTypeScale.callout, color: t.colors['danger']);
    final loading = Text(
      raftText(context, 'Loading Artifacts…'),
      style: t.scale(RaftTypeScale.callout, mono: true),
    );
    RaftButton button(String label) => RaftButton(
      label: raftText(context, label),
      variant: RaftControlVariant.outline,
      size: RaftButtonRecipeSize.sm,
      onPressed: onPressed,
    );
    return switch (kind) {
      ConversationArtifactsNoteKind.loading => Padding(
        key: const ValueKey('conversation-artifacts-loading'),
        padding: const EdgeInsets.all(RaftSpace.x3),
        child: loading,
      ),
      ConversationArtifactsNoteKind.failed => Padding(
        key: const ValueKey('conversation-artifacts-error'),
        padding: const EdgeInsets.all(RaftSpace.x3),
        child: Wrap(
          spacing: RaftSpace.x2,
          runSpacing: RaftSpace.x2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              raftText(context, "Couldn't load this conversation's Artifacts."),
              style: danger,
            ),
            button('Try again'),
          ],
        ),
      ),
      ConversationArtifactsNoteKind.more => Padding(
        key: const ValueKey('conversation-artifacts-more'),
        padding: const EdgeInsets.all(RaftSpace.x2),
        child: Center(
          child: Wrap(
            spacing: RaftSpace.x2,
            runSpacing: RaftSpace.x2,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (more == ConversationArtifactsMore.failed)
                Text(
                  raftText(context, "Couldn't load more Artifacts."),
                  style: danger,
                ),
              if (more == ConversationArtifactsMore.loading)
                loading
              else
                button('Show more Artifacts'),
            ],
          ),
        ),
      ),
    };
  }
}
