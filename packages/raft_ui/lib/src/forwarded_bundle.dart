import 'package:flutter/material.dart';

import 'attachment_card.dart';
import 'collapsible.dart';
import 'design_primitives.dart' show RaftInteractive;
import 'icons.dart';
import 'theme.dart';
import 'rich_card_tokens.dart';
import 'localization.dart';
import 'message_body.dart';
import 'message_row_recipe.dart' show RaftMessageBodyMargin;
import 'tooltip.dart' show RaftTooltip;

/// Only recipient-projected fields are retained. Source pointers, capability
/// URLs and internal attachment projection IDs never become displayed text.
class RaftForwardedItem {
  const RaftForwardedItem({
    required this.content,
    required this.author,
    required this.index,
    this.createdAt,
    this.sequence,
    this.sourceLabel,
    this.thread = false,
    this.parent = false,
    this.attachments = const [],
    this.openable = false,
    this.item = const {},
  });

  /// Web `canOpenSourceLabel`: the source message is public and still has a
  /// place to open. [item] holds the ids that open it; it only ever feeds the
  /// open callback, never the display.
  final bool openable;
  final Map<String, dynamic> item;
  final String content, author;
  final int index;
  final DateTime? createdAt;
  final num? sequence;
  final String? sourceLabel;
  final bool thread, parent;
  final List<Map<String, dynamic>> attachments;
}

/// Web `canOpenSourceLabel` (ForwardedBundleCard.tsx).
bool _canOpenSource(Map item) {
  if (item['provenanceState'] == 'original_unavailable') return false;
  final id = item['sourceMessageId'];
  if (id is! String || id.isEmpty) return false;
  final target = item['sourceTargetSnapshot'];
  if (target is! Map ||
      target['type'] == 'dm' ||
      target['labelVisibility'] != 'public') {
    return false;
  }
  bool has(String key) =>
      item[key] is String && (item[key] as String).isNotEmpty;
  if (target['type'] == 'thread') {
    return has('sourceThreadId') && has('parentChannelId');
  }
  return has('sourceTargetId');
}

List<RaftForwardedItem> raftForwardedItems(Map<String, dynamic> metadata) {
  if (metadata['kind'] != 'forwarded-bundle' ||
      metadata['version'] != 1 ||
      metadata['forwardedItems'] is! List) {
    return [];
  }
  final raw = metadata['forwardedItems'] as List;
  if (raw.isEmpty || raw.length > 20) return [];
  final result = <RaftForwardedItem>[];
  for (var position = 0; position < raw.length; position++) {
    final item = raw[position];
    if (item is! Map ||
        item['contentSnapshot'] is! String ||
        ![
          'available',
          'original_unavailable',
        ].contains(item['provenanceState'])) {
      continue;
    }
    final target = item['sourceTargetSnapshot'];
    final author = item['sourceAuthorSnapshot'];
    var name = '';
    if (author is Map && ['user', 'agent'].contains(author['type'])) {
      if (author['uniqueName'] is String &&
          (author['uniqueName'] as String).isNotEmpty) {
        name = '@${author['uniqueName']}';
      } else if (author['name'] is String) {
        name = author['name'] as String;
      }
    }
    final attachments = <Map<String, dynamic>>[];
    if (item['attachmentPolicy'] == 'projected' &&
        item['attachmentSnapshots'] is List) {
      for (final attachment in item['attachmentSnapshots'] as List) {
        if (attachment is! Map || attachment['filename'] is! String) continue;
        attachments.add({
          if (attachment['id'] is String &&
              (attachment['id'] as String).isNotEmpty)
            'id': attachment['id'],
          'filename': attachment['filename'],
          'mimeType': attachment['mimeType'] is String
              ? attachment['mimeType']
              : 'application/octet-stream',
          if (attachment['sizeBytes'] is num)
            'sizeBytes': attachment['sizeBytes'],
          if (attachment['width'] is num) 'width': attachment['width'],
          if (attachment['height'] is num) 'height': attachment['height'],
        });
      }
    }
    final thread = target is Map && target['type'] == 'thread';
    final label =
        target is Map &&
            item['provenanceState'] == 'available' &&
            target['labelVisibility'] == 'public' &&
            ['channel', 'thread'].contains(target['type']) &&
            target['label'] is String &&
            (target['label'] as String).trim().isNotEmpty
        ? target['label'] as String
        : null;
    result.add(
      RaftForwardedItem(
        content: item['contentSnapshot'] as String,
        author: name,
        index: item['index'] is int ? item['index'] as int : position,
        createdAt: item['sourceCreatedAt'] is String
            ? DateTime.tryParse(item['sourceCreatedAt'])
            : null,
        sequence: item['sourceMessageSeq'] is num
            ? item['sourceMessageSeq'] as num
            : null,
        sourceLabel: label,
        thread: thread,
        parent: item['sourceIsThreadParent'] == true,
        attachments: attachments,
        openable: _canOpenSource(item),
        item: {
          // Only what opening the source needs: no attachment pointers.
          for (final key in const [
            'sourceMessageId',
            'sourceTargetId',
            'sourceThreadId',
            'parentChannelId',
          ])
            if (item[key] is String) key: item[key],
          if (target is Map) 'sourceTargetSnapshot': {'type': target['type']},
        },
      ),
    );
  }
  int compare(RaftForwardedItem a, RaftForwardedItem b) {
    if (a.createdAt != null || b.createdAt != null) {
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      final order = a.createdAt!.compareTo(b.createdAt!);
      if (order != 0) return order;
    }
    if (a.sequence != null && b.sequence != null) {
      final order = a.sequence!.compareTo(b.sequence!);
      if (order != 0) return order;
    }
    return a.index.compareTo(b.index);
  }

  final isThread = result.any((r) => r.thread);
  if (isThread &&
      !raw.every((r) => r is Map && r['sourceIsThreadParent'] is bool) &&
      !result.any((r) => r.parent)) {
    return result;
  }
  result.sort(
    (a, b) => isThread && a.parent != b.parent
        ? a.parent
              ? -1
              : 1
        : compare(a, b),
  );
  return result;
}

/// A recipient-owned forwarded snapshot never resolves references against the
/// destination workspace. Its attachments use destination projection IDs only.
class RaftForwardedBundle extends StatefulWidget {
  const RaftForwardedBundle({
    super.key,
    required this.metadata,
    this.attachmentBuilder,
    this.formatTimestamp,
    this.exportMode = false,
    this.headerLine,
    this.onOpenSource,
  });
  final Map<String, dynamic> metadata;

  /// Web `onOpenSource`: the source label of the first item opens the message
  /// it was forwarded from. Receives [RaftForwardedItem.item].
  final void Function(Map<String, dynamic> item)? onOpenSource;

  /// Line box of the header's count and source text. Null keeps the in-feed
  /// 20px (the message row's leading); the note page mounts the card outside a
  /// message, where the Web header inherits the root `leading-normal` (11px
  /// x 1.5 = 16.5px).
  final double? headerLine;
  final Widget Function(Map<String, dynamic>)? attachmentBuilder;
  final String Function(DateTime)? formatTimestamp;
  final bool exportMode;
  @override
  State<RaftForwardedBundle> createState() => _RaftForwardedBundleState();
}

class _RaftForwardedBundleState extends State<RaftForwardedBundle> {
  bool expanded = false, touched = false;
  final bodyHeights = <int, double>{};
  @override
  void didUpdateWidget(RaftForwardedBundle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata != widget.metadata) {
      bodyHeights.clear();
      expanded = false;
      touched = false;
    }
  }

  // The CSS line box is a minimum: a taller line (larger text, the Android
  // Chinese control line) grows the row instead of clipping the text.
  static Widget metaLine(TextStyle style, String text) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: style.fontSize! * style.height!),
    child: Text(text, style: style),
  );

  /// The "from #channel" text; a button that opens the source message when it
  /// can (Web `MessageForwardedBundleSource` inside an `AttachmentTooltip`).
  Widget _source(
    BuildContext context,
    RaftForwardedItem first,
    ForwardedSnapshotRecipe recipe,
  ) {
    final style = widget.headerLine == null
        ? recipe.source
        : recipe.source.copyWith(height: widget.headerLine! / 11);
    final label = raftFormat(
      context,
      first.thread && !first.sourceLabel!.endsWith(' · thread')
          ? 'from {target} · thread'
          : 'from {target}',
      {'target': first.sourceLabel!},
    );
    Text text(TextStyle style) => Text(
      label,
      style: style,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final open = widget.onOpenSource;
    if (open == null || !first.openable || widget.exportMode) {
      return text(style);
    }
    final hint = raftText(context, 'Open source message');
    return RaftTooltip(
      message: hint,
      child: RaftInteractive(
        key: const Key('forwarded-bundle-source'),
        onPressed: () => open(first.item),
        semanticLabel: hint,
        builder: (_, state) => text(
          state.hovered
              ? style.copyWith(decoration: TextDecoration.underline)
              : style,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = ForwardedSnapshotRecipe(
      RaftTokens.of(context),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final items = raftForwardedItems(widget.metadata);
    if (items.isEmpty) {
      return Text(raftText(context, 'Forwarded messages unavailable.'));
    }
    final foldable =
        bodyHeights.length == items.length &&
        bodyHeights.values.fold<double>(0, (a, b) => a + b) >
            recipe.collapsedHeight + 1;
    final collapsed =
        bodyHeights.length == items.length && !expanded && !widget.exportMode;
    final first = items.first;
    final contents = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: recipe.itemInset,
            child: Builder(
              builder: (context) {
                final item = items[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        // A Text rounds a fractional line (15.71px) up; the
                        // box keeps Web's exact height.
                        metaLine(
                          recipe.author,
                          item.author.isEmpty
                              ? raftText(context, 'Unknown author')
                              : item.author,
                        ),
                        if (item.createdAt != null) ...[
                          metaLine(recipe.metadata, '·'),
                          metaLine(
                            recipe.metadata,
                            widget.formatTimestamp?.call(item.createdAt!) ??
                                TimeOfDay.fromDateTime(
                                  item.createdAt!.toLocal(),
                                ).format(context),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    RaftContentMeasure(
                      onSize: (size) {
                        if (mounted &&
                            (bodyHeights[index] ?? -1) != size.height) {
                          setState(() {
                            bodyHeights[index] = size.height;
                            if (!touched &&
                                bodyHeights.length == items.length) {
                              expanded =
                                  bodyHeights.values.fold<double>(
                                    0,
                                    (a, b) => a + b,
                                  ) <=
                                  recipe.collapsedHeight + 1;
                            }
                          });
                        }
                      },
                      child: RaftMessageBody(
                        content: item.content,
                        foregroundColor: recipe.semantic.prose,
                        exportMode: widget.exportMode,
                      ),
                    ),
                    if (item.attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final attachment in item.attachments)
                              widget.attachmentBuilder != null &&
                                      attachment['id'] is String
                                  ? widget.attachmentBuilder!(attachment)
                                  : RaftAttachmentCard(
                                      onOpen: null,
                                      filename:
                                          attachment['filename'] as String,
                                      mimeType:
                                          attachment['mimeType'] as String,
                                      sizeBytes:
                                          (attachment['sizeBytes'] as num?)
                                              ?.toInt(),
                                      exportMode: true,
                                    ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final body = DecoratedBox(
      decoration: recipe.contentDecoration,
      child: collapsed
          ? ClipRRect(
              borderRadius: BorderRadius.circular(
                RichCardPrimitive.contentRadius,
              ),
              child: Stack(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: recipe.collapsedHeight,
                    ),
                    child: SingleChildScrollView(
                      primary: false,
                      physics: const NeverScrollableScrollPhysics(),
                      child: contents,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 40,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              recipe.semantic.content,
                              recipe.semantic.content.withValues(alpha: .8),
                              recipe.semantic.content.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : contents,
    );
    return Padding(
      // `mt-1` collapses with the message body's own margin.
      padding: EdgeInsets.only(top: RaftMessageBodyMargin.collapse(context, 4)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: recipe.maxWidth),
        child: Container(
          decoration: recipe.decoration,
          padding: recipe.inset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: recipe.headerDecoration,
                padding: recipe.headerInset(viewportWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RaftIcon(
                            RaftGlyph.forward,
                            size: 12,
                            color: recipe.header.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            raftText(context, 'Forwarded'),
                            style: recipe.header,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              // message.forward.bundleCount: `one {message}`
                              // (no number), `other {# messages}`.
                              items.length == 1
                                  ? raftText(context, 'message')
                                  : raftFormat(context, '{count} messages', {
                                      'count': items.length,
                                    }),
                              style: widget.headerLine == null
                                  ? recipe.count
                                  : recipe.count.copyWith(
                                      height: widget.headerLine! / 11,
                                    ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (first.sourceLabel != null) ...[
                      const SizedBox(width: 8),
                      Flexible(child: _source(context, first, recipe)),
                    ],
                  ],
                ),
              ),
              body,
              if (!widget.exportMode && foldable)
                Container(
                  decoration: recipe.footerDecoration,
                  padding: recipe.footerInset(viewportWidth),
                  // The footer is a block whose 24px line box holds the
                  // inline-flex 11px button.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: RaftShowMoreToggle(
                        label: expanded
                            ? raftText(context, 'Collapse')
                            : raftFormat(
                                context,
                                items.length == 1
                                    ? 'View All {count} Message'
                                    : 'View All {count} Messages',
                                {'count': items.length},
                              ),
                        onPressed: () => setState(() {
                          touched = true;
                          expanded = !expanded;
                        }),
                        style: recipe.showMore,
                        underline: recipe.showMoreUnderlined,
                        visualHeight: 20,
                        icon: RaftIcon(
                          expanded
                              ? RaftGlyph.chevronUp
                              : RaftGlyph.chevronRight,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
