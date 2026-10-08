import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// Notification membership for the current thread, separate from read/Done.
class ThreadActions extends StatefulWidget {
  const ThreadActions({
    super.key,
    required this.controller,
    required this.parent,
  });
  final WorkspaceController controller;
  final RaftMessage parent;
  @override
  State<ThreadActions> createState() => _ThreadActionsState();
}

class _ThreadActionsState extends State<ThreadActions> {
  WorkspaceController get w => widget.controller;
  late final int generation;
  late final StreamSubscription<RaftEvent> subscription;
  bool? following;
  bool busy = false;
  int ticket = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    generation = w.client.generation;
    subscription = w.client.events.listen((event) {
      if (event.name == 'connected' ||
          event.name == 'thread:followers-updated') {
        if (!busy) load();
      }
    });
    load();
  }

  bool get current =>
      mounted &&
      generation == w.client.generation &&
      widget.parent.id == w.threadParent?.id;

  Future<void> load() async {
    final request = ++ticket;
    try {
      final response = await w.query('/channels/threads/followed');
      if (!current || request != ticket) return;
      setState(() {
        following = (response['threads'] as List).any(
          (row) => row['parentMessageId'] == widget.parent.id,
        );
        error = null;
      });
    } catch (_) {
      if (current && request == ticket) {
        setState(
          () => error = 'Thread notification settings could not be loaded.',
        );
      }
    }
  }

  Future<void> toggle() async {
    if (!current || busy || following == null) return;
    final wasFollowing = following!;
    final threadId = w.threadChannelId;
    if (wasFollowing && threadId == null) return;
    ++ticket;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await w.command(
        'POST',
        '/channels/threads/${wasFollowing ? 'unfollow' : 'follow'}',
        data: wasFollowing
            ? {'threadChannelId': threadId}
            : {'parentMessageId': widget.parent.id},
      );
      if (!current) return;
      // The write acknowledgement is authoritative; an asynchronous Activity
      // projection may still return the old follow membership immediately.
      setState(() => following = !wasFollowing);
    } catch (_) {
      if (current) {
        setState(
          () => error = 'Thread notification settings could not be changed.',
        );
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: error == null
              ? Text(
                  raftText(
                    context,
                    following == true
                        ? 'Following thread'
                        : following == false
                        ? 'Thread notifications off'
                        : 'Loading thread settings…',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Semantics(
                  liveRegion: true,
                  child: Text(raftText(context, error!)),
                ),
        ),
        if (error != null && following == null)
          TextButton(onPressed: load, child: Text(raftText(context, 'Retry')))
        else
          TextButton.icon(
            key: const Key('thread-follow-toggle'),
            onPressed: following == null || busy ? null : toggle,
            icon: Icon(
              following == true
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_active_outlined,
              size: 18,
            ),
            label: Text(
              raftText(
                context,
                following == true ? 'Unfollow thread' : 'Follow thread',
              ),
            ),
          ),
      ],
    ),
  );
}
