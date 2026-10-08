import 'package:flutter/material.dart';

import 'attachment_card.dart';
import 'design_primitives.dart';
import 'collapsible.dart';
import 'icons.dart';
import 'theme.dart';
import 'localization.dart';
import 'message_body.dart';

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
  });
  final String content, author;
  final int index;
  final DateTime? createdAt;
  final num? sequence;
  final String? sourceLabel;
  final bool thread, parent;
  final List<Map<String, dynamic>> attachments;
}

List<RaftForwardedItem> raftForwardedItems(Map<String, dynamic> metadata) {
  if (metadata['kind'] != 'forwarded-bundle' ||
      metadata['version'] != 1 ||
      metadata['forwardedItems'] is! List)
    return [];
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
        ].contains(item['provenanceState']))
      continue;
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
      !result.any((r) => r.parent))
    return result;
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
  });
  final Map<String, dynamic> metadata;
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
      bodyHeights.clear(); expanded = false; touched = false;
    }
  }
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), recipe = RaftMessageEmbedRecipe(RaftTokens.of(context));
    final items = raftForwardedItems(widget.metadata);
    if (items.isEmpty) return Text(raftText(context, 'Forwarded messages unavailable.'));
    final foldable = bodyHeights.length == items.length && bodyHeights.values.fold<double>(0, (a, b) => a + b) > recipe.collapsedHeight + 1;
    final collapsed = bodyHeights.length == items.length && !expanded && !widget.exportMode;
    final first = items.first;
    final contents = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var index = 0; index < items.length; index++)
        Padding(padding: recipe.itemInset, child: Builder(builder: (context) {
          final item = items[index];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 6, runSpacing: 2, children: [
              Text(item.author.isEmpty ? raftText(context, 'Unknown author') : item.author,
                style: recipe.author),
              if (item.createdAt != null) ...[
                Text('·', style: recipe.metadata),
                Text(widget.formatTimestamp?.call(item.createdAt!) ?? TimeOfDay.fromDateTime(item.createdAt!.toLocal()).format(context), style: recipe.metadata),
              ],
            ]),
            const SizedBox(height: 4),
            RaftContentMeasure(onSize: (size) {
              if (mounted && (bodyHeights[index] ?? -1) != size.height) {
                setState(() {
                  bodyHeights[index] = size.height;
                  if (!touched && bodyHeights.length == items.length) {
                    expanded = bodyHeights.values.fold<double>(0, (a, b) => a + b) <= recipe.collapsedHeight + 1;
                  }
                });
              }
            }, child: RaftMessageBody(content: item.content, exportMode: widget.exportMode)),
            if (item.attachments.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final attachment in item.attachments)
                widget.attachmentBuilder != null && attachment['id'] is String
                    ? widget.attachmentBuilder!(attachment)
                    : RaftAttachmentCard(onOpen: null, filename: attachment['filename'] as String, mimeType: attachment['mimeType'] as String, sizeBytes: (attachment['sizeBytes'] as num?)?.toInt(), exportMode: true),
            ])),
          ]);
        })),
    ]);
    return Padding(padding: const EdgeInsets.only(top: 4), child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: recipe.maxWidth),
      child: DecoratedBox(decoration: recipe.decoration, child: Padding(padding: recipe.inset, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: recipe.headerPadding, child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            RaftIcon(RaftGlyph.forward, size: 12, color: recipe.header.color),
            const SizedBox(width: 4), Text(raftText(context, 'Forwarded'), style: recipe.header),
            const SizedBox(width: 8), Text(raftFormat(context, items.length == 1 ? '{count} message' : '{count} messages', {'count': items.length}), style: recipe.count),
          ]),
          if (first.sourceLabel != null) Text(raftFormat(context, 'From {target}', {'target': first.sourceLabel!}), style: recipe.source),
        ])),
        if (collapsed) ClipRect(child: Stack(children: [
          ConstrainedBox(constraints: BoxConstraints(maxHeight: recipe.collapsedHeight), child: SingleChildScrollView(primary: false, physics: const NeverScrollableScrollPhysics(), child: contents)),
          Positioned(left: 0, right: 0, bottom: 0, height: 40, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [t.panel, t.panel.withValues(alpha: .8), t.panel.withValues(alpha: 0)]))))),
        ])) else contents,
        if (!widget.exportMode && foldable) Padding(padding: recipe.footerPadding, child: Align(alignment: Alignment.centerLeft, child: RaftShowMoreToggle(
          label: expanded ? raftText(context, 'Collapse') : raftFormat(context, items.length == 1 ? 'View all {count} message' : 'View all {count} messages', {'count': items.length}),
          onPressed: () => setState(() { touched = true; expanded = !expanded; }),
          icon: RaftIcon(expanded ? RaftGlyph.chevronUp : RaftGlyph.chevronRight, size: 12, color: recipe.showMore.color),
        ))),
      ]))),
    ));
  }
}
