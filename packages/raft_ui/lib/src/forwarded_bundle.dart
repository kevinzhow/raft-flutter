import 'package:flutter/material.dart';

import 'attachment_card.dart';
import 'components.dart';
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
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final items = raftForwardedItems(widget.metadata);
    if (items.isEmpty)
      return Text(raftText(context, 'Forwarded messages unavailable.'));
    final first = items.first;
    final rows = (expanded || widget.exportMode ? items : items.take(2))
        .toList();
    final contents = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in rows)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  [
                    item.author.isEmpty
                        ? raftText(context, 'Unknown author')
                        : item.author,
                    if (item.createdAt != null)
                      widget.formatTimestamp?.call(item.createdAt!) ??
                          TimeOfDay.fromDateTime(item.createdAt!.toLocal())
                              .format(context),
                  ].join(' · '),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                RaftMessageBody(
                  content: item.content,
                  exportMode: widget.exportMode,
                ),
                for (final attachment in item.attachments)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child:
                        widget.attachmentBuilder != null &&
                            attachment['id'] is String
                        ? widget.attachmentBuilder!(attachment)
                        : RaftAttachmentCard(
                            onOpen: null,
                            filename: attachment['filename'] as String,
                            mimeType: attachment['mimeType'] as String,
                            sizeBytes: (attachment['sizeBytes'] as num?)
                                ?.toInt(),
                            exportMode: true,
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
    return RaftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.forward, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  raftFormat(
                    context,
                    items.length == 1
                        ? 'Forwarded · {count} message'
                        : 'Forwarded · {count} messages',
                    {'count': items.length},
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (first.sourceLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                raftFormat(context, 'From {target}', {
                  'target': first.sourceLabel!,
                }),
              ),
            ),
          if (expanded || widget.exportMode)
            contents
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                child: contents,
              ),
            ),
          if (!widget.exportMode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () => setState(() => expanded = !expanded),
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(
                  expanded
                      ? raftText(context, 'Collapse forwarded messages')
                      : raftFormat(
                          context,
                          items.length == 1
                              ? 'View all {count} message'
                              : 'View all {count} messages',
                          {'count': items.length},
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
