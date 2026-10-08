import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart';

/// Notification membership for the current thread, separate from read/Done.
class ThreadActions extends StatefulWidget {
  const ThreadActions({
    super.key,
    required this.controller,
    required this.parent,
    this.menuMode = false,
    this.onSearch,
    this.onViewChannel,
  });
  final WorkspaceController controller;
  final RaftMessage parent;
  final bool menuMode;
  final VoidCallback? onSearch, onViewChannel;
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
  late final String authority;
  OverlayEntry? menu;

  @override
  void initState() {
    super.initState();
    generation = w.client.generation;
    authority = workspaceAuthority(w);
    subscription = w.client.events.listen((event) {
      if (event.name == 'connected' ||
          event.name == 'thread:followers-updated') {
        if (!busy) load();
      }
    });
    w.addListener(authorityChanged);
    load();
  }

  void authorityChanged() {
    if (!current) closeMenu();
    if (mounted) setState(() {});
  }

  bool get current =>
      mounted &&
      generation == w.client.generation &&
      authority == workspaceAuthority(w) &&
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
    w.removeListener(authorityChanged);
    closeMenu();
    subscription.cancel();
    super.dispose();
  }

  void closeMenu() {
    menu?.remove();
    menu?.dispose();
    menu = null;
  }

  void openMenu(BuildContext anchor) {
    if (!current) return;
    if (menu != null) {
      closeMenu();
      return;
    }
    final box = anchor.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    final rect =
        box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
    menu = OverlayEntry(
      builder: (context) => Positioned(
        left: (rect.right - 192).clamp(
          8.0,
          (overlayBox.size.width - 200).clamp(8.0, double.infinity),
        ),
        top: rect.bottom + 4,
        child: TapRegion(
          onTapOutside: (_) => closeMenu(),
          child: RaftMenuPanel(
            onDismiss: closeMenu,
            children: [
              if (widget.onSearch != null)
                RaftMenuItem(
                  label: raftText(context, 'Search messages'),
                  glyph: RaftGlyph.search,
                  autofocus: true,
                  onPressed: () {
                    closeMenu();
                    if (current) widget.onSearch!();
                  },
                ),
              if (widget.onViewChannel != null)
                RaftMenuItem(
                  label: raftText(context, 'View in channel'),
                  glyph: RaftGlyph.hash,
                  onPressed: () {
                    closeMenu();
                    if (current) widget.onViewChannel!();
                  },
                ),
              RaftMenuItem(
                label: raftText(
                  context,
                  following == true ? 'Unfollow thread' : 'Follow thread',
                ),
                glyph: RaftGlyph.bell,
                onPressed: following == null || busy
                    ? null
                    : () {
                        closeMenu();
                        toggle();
                      },
              ),
              if (error != null)
                RaftMenuItem(
                  label: raftText(context, 'Retry'),
                  glyph: RaftGlyph.refreshCw,
                  onPressed: () {
                    closeMenu();
                    load();
                  },
                ),
            ],
          ),
        ),
      ),
    );
    overlay.insert(menu!);
  }

  @override
  Widget build(BuildContext context) => widget.menuMode
      ? Builder(
          builder: (anchor) => RaftThreadOverflowAction(
            key: const Key('thread-options'),
            label: raftText(context, 'Thread options'),
            onPressed: current ? () => openMenu(anchor) : null,
          ),
        )
      : Padding(
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
                TextButton(
                  onPressed: load,
                  child: Text(raftText(context, 'Retry')),
                )
              else
                TextButton.icon(
                  key: const Key('thread-follow-toggle'),
                  onPressed: following == null || busy ? null : toggle,
                  // Web ThreadOverflowMenu.tsx:110 MessageCircleOff/MessageCirclePlus.
                  icon: RaftIcon(
                    following == true
                        ? RaftGlyph.messageCircleOff
                        : RaftGlyph.messageCirclePlus,
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
