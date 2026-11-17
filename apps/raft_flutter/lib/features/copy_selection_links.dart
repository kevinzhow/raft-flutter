import 'package:flutter/services.dart';

import '../data/workspace_controller.dart';
import '../platform/content_links.dart';
import 'message_selection.dart';

/// Web v1.24 `copySelectedLinks` (ChatPanel / useThreadSelectionActions):
/// build every selected row's permalink locally, in selection order, and write
/// the clipboard once. Returns how many links were copied, or 0 when there is
/// nothing to copy. A clipboard failure throws to the caller.
Future<int> copySelectedMessageLinks(
  WorkspaceController w,
  MessageSelection selection, {
  Future<void> Function(String)? write,
}) async {
  final rows = selection.selected;
  final channel = w.channel;
  final slug = w.server?.string('slug') ?? '';
  if (!selection.active || rows.isEmpty || channel == null || slug.isEmpty) {
    return 0;
  }
  final origin = ContentLinks.originFor(w.client.origin);
  final links = [
    for (final row in rows)
      ContentLinks.messageUrl(
        origin: origin,
        slug: slug,
        channelId: channel.id,
        messageId: row.message.id,
        kind: channel.type,
        parentMessageId: row.parentId,
      ).toString(),
  ];
  await (write ?? (text) => Clipboard.setData(ClipboardData(text: text)))(
    links.join('\n'),
  );
  return links.length;
}
