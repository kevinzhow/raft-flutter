import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/followed_threads_store.dart';
import '../data/workspace_controller.dart';
import 'private_route_guard.dart';

/// Notification membership for the current thread, separate from read/Done.
class ThreadActions extends StatefulWidget {
  const ThreadActions({
    super.key,
    required this.controller,
    required this.parentMessageId,
    this.menuMode = false,
    this.onSearch,
    this.onViewChannel,
  });
  final WorkspaceController controller;
  /// The open thread's parent message identity. The menu does not wait for
  /// the parent message body: the header is final at the first frame.
  final String parentMessageId;
  final bool menuMode;
  final VoidCallback? onSearch, onViewChannel;
  @override
  State<ThreadActions> createState() => _ThreadActionsState();
}

class _ThreadActionsState extends State<ThreadActions> {
  WorkspaceController get w => widget.controller;
  FollowedThreadsStore get store => w.followedThreads;
  late final int generation;
  late final StreamSubscription<RaftEvent> subscription;
  String? error;
  late final String authority;
  OverlayEntry? menu;
  final menuGroup = Object();

  @override
  void initState() {
    super.initState();
    generation = w.client.generation;
    authority = workspaceAuthority(w);
    // Another device may change this principal's membership of the open
    // thread; revalidate the shared list in place (no loading state).
    subscription = w.client.events.listen((event) {
      final payload = event.payload;
      if (event.name == 'thread:followers-updated' &&
          payload is Map &&
          payload['threadChannelId'] == w.threadChannelId &&
          current &&
          !busy) {
        store.refresh();
      }
    });
    w.addListener(authorityChanged);
    store.addListener(membershipChanged);
    // Normally started at server selection; a no-op once settled.
    store.ensure();
  }

  void authorityChanged() {
    if (!current) closeMenu();
    if (mounted) rebuild(() {});
  }

  void membershipChanged() {
    if (mounted) rebuild(() {});
  }

  bool get current =>
      mounted &&
      generation == w.client.generation &&
      authority == workspaceAuthority(w) &&
      widget.parentMessageId == w.threadParentMessageId;

  /// Membership from the server-scoped followed list; null before its first
  /// accepted read for this identity.
  bool? get following =>
      store.loaded ? store.isFollowing(widget.parentMessageId) : null;
  bool get busy => store.isPending(widget.parentMessageId);

  /// Shown only when the list never loaded for this identity.
  String? get loadError => store.loaded || store.error == null
      ? null
      : 'Thread notification settings could not be loaded.';

  // OverlayEntry lives outside this State's subtree. Async membership and
  // busy changes must rebuild both the trigger and an already open menu.
  void rebuild(VoidCallback change) {
    setState(change);
    menu?.markNeedsBuild();
  }

  void retry() {
    rebuild(() => error = null);
    store.refresh();
  }

  Future<void> toggle() async {
    final wasFollowing = following;
    if (!current || busy || wasFollowing == null) return;
    final threadId =
        store.threadChannelIdFor(widget.parentMessageId) ?? w.threadChannelId;
    if (wasFollowing && threadId == null) return;
    rebuild(() => error = null);
    try {
      // Optimistic in the shared store; it reverts if the write fails.
      wasFollowing
          ? await store.unfollow(widget.parentMessageId, threadChannelId: threadId)
          : await store.follow(widget.parentMessageId);
    } catch (_) {
      if (current) {
        rebuild(
          () => error = 'Thread notification settings could not be changed.',
        );
      }
    }
  }

  @override
  void dispose() {
    w.removeListener(authorityChanged);
    store.removeListener(membershipChanged);
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
          groupId: menuGroup,
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
                  glyph: RaftGlyph.mapPin,
                  onPressed: () {
                    closeMenu();
                    if (current) widget.onViewChannel!();
                  },
                ),
              RaftMenuItem(
                key: const Key('thread-follow-menu-item'),
                label: raftText(
                  context,
                  following == true ? 'Unfollow thread' : 'Follow thread',
                ),
                glyph: following == true
                    ? RaftGlyph.messageCircleOff
                    : RaftGlyph.messageCirclePlus,
                onPressed: following == null || busy
                    ? null
                    : () {
                        closeMenu();
                        toggle();
                      },
              ),
              if (error != null || loadError != null)
                RaftMenuItem(
                  label: raftText(context, 'Retry'),
                  glyph: RaftGlyph.refreshCw,
                  onPressed: () {
                    closeMenu();
                    retry();
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
          builder: (anchor) => TapRegion(
            groupId: menuGroup,
            child: RaftThreadOverflowAction(
              key: const Key('thread-options'),
              label: raftText(context, 'Thread options'),
              onPressed: current ? () => openMenu(anchor) : null,
            ),
          ),
        )
      : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: (error ?? loadError) == null
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
                        child: Text(raftText(context, (error ?? loadError)!)),
                      ),
              ),
              if (loadError != null && following == null)
                TextButton(
                  onPressed: retry,
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
