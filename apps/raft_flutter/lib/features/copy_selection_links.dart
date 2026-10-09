import 'package:flutter/services.dart';

import '../data/workspace_controller.dart';
import '../platform/content_coordinator.dart';
import '../platform/content_links.dart';
import '../platform/content_target.dart';
import 'message_selection.dart';
import 'private_route_guard.dart';

/// Resolve the current selected parent/reply routes, authorize every target,
/// then perform one clipboard write. Partial batches never reach the clipboard.
Future<bool> copySelectedMessageLinks(
  WorkspaceController w,
  MessageSelection selection,
  bool Function() mounted, {
  Future<void> Function(String)? write,
}) async {
  final rows = selection.selected;
  final channel = w.channel;
  if (!mounted() ||
      !selection.active ||
      rows.isEmpty ||
      channel == null ||
      w.server == null ||
      w.client.user == null ||
      w.client.serverId != w.server!.id ||
      !w.can('viewChannel', resource: channel)) {
    return false;
  }
  final authority = workspaceAuthority(w), revision = selection.revision;
  final snapshots = rows
      .map((r) => (r.message.id, selectedMessageFingerprint(r.message)))
      .toList();
  bool current() {
    if (!mounted() ||
        !selection.active ||
        revision != selection.revision ||
        authority != workspaceAuthority(w) ||
        !w.can('viewChannel', resource: w.channel)) {
      return false;
    }
    final selected = selection.selected;
    return selected.length == snapshots.length &&
        Iterable<int>.generate(selected.length).every(
          (i) =>
              selected[i].message.id == snapshots[i].$1 &&
              selectedMessageFingerprint(selected[i].message) ==
                  snapshots[i].$2,
        );
  }

  final urls = <String>[];
  for (final row in rows) {
    if (!current()) return false;
    final parent = row.parentId == null
        ? null
        : selection.available
              .where((r) => r.message.id == row.parentId && r.parentId == null)
              .firstOrNull
              ?.message;
    if (row.parentId != null && parent == null) return false;
    final server = await NativeContentCoordinator.authorize(
      w,
      ContentTarget(
        serverId: w.server!.id,
        channelId: channel.id,
        messageId: row.message.id,
        parentMessageId: row.parentId,
        threadId:
            parent?.threadId ??
            (selection.thread && row.parentId != null
                ? w.threadChannelId
                : null),
      ),
      current,
    );
    if (!current() || server.string('slug').isEmpty) return false;
    urls.add(
      ContentLinks.messageUrl(
        origin: ContentLinks.originFor(w.client.origin),
        slug: server.string('slug'),
        channelId: channel.id,
        messageId: row.message.id,
        kind: channel.type,
        parentMessageId: row.parentId,
      ).toString(),
    );
  }
  if (!current()) return false;
  await (write ?? (text) => Clipboard.setData(ClipboardData(text: text)))(
    urls.join('\n'),
  );
  return current();
}
