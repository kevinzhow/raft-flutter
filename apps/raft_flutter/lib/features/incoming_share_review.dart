import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/native_sharing.dart';
import '../platform/content_coordinator.dart';
import '../platform/content_target.dart';
import '../platform/content_links.dart';

bool unsafeSharedText(String text) {
  if (RegExp(r'raft://oauth(?:/|\?|$)', caseSensitive: false).hasMatch(text)) {
    return true;
  }
  for (final match in RegExp(r'https?://[^\s]+').allMatches(text)) {
    final uri = Uri.tryParse(match.group(0)!);
    if (uri == null || uri.userInfo.isNotEmpty) return true;
    if (uri.queryParameters.keys.any(
      (key) => RegExp(
        r'^(token|access_token|refresh_token|signature|x-amz-.+|oauth_code)$',
        caseSensitive: false,
      ).hasMatch(key),
    )) {
      return true;
    }
  }
  return false;
}

/// The receiving intent cannot choose an account, server or send destination.
/// The user reviews the current conversation, then stages normal drafts/files.
Future<void> reviewIncomingShare(
  BuildContext context,
  WorkspaceController w,
  IncomingShare share,
  NativeSharing sharing,
) async {
  final channel = w.channel,
      principal = w.client.user?.id,
      server = w.client.serverId,
      generation = w.client.generation;
  if (channel == null ||
      !channel.joined ||
      principal == null ||
      server == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            raftText(
              context,
              'Select a joined conversation before adding shared content.',
            ),
          ),
        ),
      );
    }
    return;
  }
  bool valid() =>
      context.mounted &&
      principal == w.client.user?.id &&
      server == w.client.serverId &&
      generation == w.client.generation &&
      w.channel?.id == channel.id &&
      w.channel?.joined == true;
  DialogRoute<bool>? route;
  void changed() {
    if (!valid() && route?.isActive == true) {
      route!.navigator?.removeRoute(route);
    }
  }

  try {
    if (share.text != null && unsafeSharedText(share.text!)) {
      throw const RaftApiException(
        'Shared sign-in or signed-resource links cannot be added as messages.',
      );
    }
    final target = share.files.isEmpty && share.text != null
        ? ContentTarget.parse(
            Uri.tryParse(share.text!.trim()) ?? Uri(),
            origin: ContentLinks.originFor(w.client.origin),
          )
        : null;
    Future<void> authority() async {
      final servers = await w.client.servers();
      if (!valid() || !servers.any((s) => s.id == server)) {
        throw const RaftApiException('The conversation changed.');
      }
      final access = await w.query('/channels/${channel.id}');
      if (!valid() ||
          access is! Map ||
          access['id'] != channel.id ||
          access['serverId'] != server) {
        throw const RaftApiException('The conversation changed.');
      }
    }

    await authority();
    if (!context.mounted || !valid()) return;
    route = DialogRoute<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          raftText(
            dialog,
            target != null ? 'Open shared message' : 'Add shared content',
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${w.server?.name} · ${channel.name}'),
              if (share.text != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    share.text!.length > 1000
                        ? '${share.text!.substring(0, 1000)}…'
                        : share.text!,
                  ),
                ),
              for (final file in share.files) Text(file.filename),
              if (share.files.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    raftText(
                      context,
                      'Files are added to the composer. Review them before sending.',
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(raftText(dialog, 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(
              raftText(
                dialog,
                target != null ? 'Open message' : 'Add to conversation',
              ),
            ),
          ),
        ],
      ),
    );
    w.addListener(changed);
    if (!context.mounted) return;
    final accepted = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(route);
    if (accepted != true || !valid()) return;
    await authority();
    if (!valid()) return;
    if (target != null) {
      await NativeContentCoordinator.authorize(w, target, valid);
      if (valid()) {
        await w.jumpToMessage(
          target.channelId,
          target.messageId ?? target.parentMessageId,
        );
        if (valid() &&
            target.messageId == null &&
            target.parentMessageId != null) {
          final parent = w.messages
              .where((m) => m.id == target.parentMessageId)
              .firstOrNull;
          if (parent != null) await w.openThread(parent);
        }
      }
      return;
    }
    if (share.files.length + w.uploads().length > 10) {
      throw const RaftApiException('Attach up to 10 files per message.');
    }
    for (final file in share.files) {
      if (!valid()) return;
      final bytes = await sharing.readIncoming(file, authorized: valid);
      if (!valid()) return;
      await w.attachUpload(file.filename, bytes);
    }
    if (share.text != null && share.text!.isNotEmpty && valid()) {
      final previous = w.drafts[w.draftScope()] ?? '';
      w.updateDraftFromShare(
        previous.isEmpty ? share.text! : '$previous\n${share.text!}',
      );
    }
  } catch (_) {
    if (context.mounted && valid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            raftText(context, 'The shared content could not be added.'),
          ),
        ),
      );
    }
  } finally {
    w.removeListener(changed);
  }
}
