import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/followed_threads_store.dart';
import '../data/thread_outline.dart';
import '../data/workspace_controller.dart';
import 'private_route_guard.dart';
import 'thread_outline_list.dart';
import 'thread_outline_scope.dart';

/// Notification membership for the current thread, separate from read/Done.
class ThreadActions extends StatefulWidget {
  const ThreadActions({
    super.key,
    required this.controller,
    required this.parentMessageId,
    this.menuMode = false,
    this.onSearch,
    this.onViewChannel,
    this.onOutlineJump,
    this.onFollowers,
  });
  final WorkspaceController controller;

  /// The open thread's parent message identity. The menu does not wait for
  /// the parent message body: the header is final at the first frame.
  final String parentMessageId;
  final bool menuMode;
  final VoidCallback? onSearch, onViewChannel, onFollowers;
  final ValueChanged<String>? onOutlineJump;

  @override
  State<ThreadActions> createState() => _ThreadActionsState();
}

class _ThreadActionsState extends State<ThreadActions> {
  WorkspaceController get w => widget.controller;
  FollowedThreadsStore get store => w.services.followedThreads;
  late final int generation;
  late final StreamSubscription<RaftEvent> subscription;
  // The failed write. Bound to the thread it was for (this State can be
  // reused for another parent) and to the membership it failed to change, so
  // a refresh that shows a different membership retires it. Retry or a new
  // toggle clears it.
  late final CauseNotice errorNotice = CauseNotice(
    scope: () => (widget.parentMessageId, workspaceAuthority(w)),
  );
  String? get error => errorNotice.message;
  late final String authority;
  OverlayEntry? menu;
  final menuAnchor = GlobalKey();
  final menuGroup = Object();
  ThreadOutline? outline;

  @override
  void initState() {
    super.initState();
    generation = w.client.generation;
    authority = workspaceAuthority(w);
    // Another device may change this principal's membership of the open
    // thread; revalidate the shared list in place (no loading state).
    subscription = w.client.events.listen((event) {
      if (current) {
        if (event.name == 'connected') unawaited(outline?.load());
        outline?.note(event);
      }
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
    bindOutline();
  }

  void bindOutline() {
    final next = widget.menuMode && current ? threadOutlineFor(w) : null;
    if (identical(next, outline)) return;
    outline?.removeListener(membershipChanged);
    outline = next;
    next?.addListener(membershipChanged);
    unawaited(next?.load());
  }

  void authorityChanged() {
    if (!current) closeMenu();
    bindOutline();
    if (mounted) rebuild(() {});
  }

  void membershipChanged() {
    if (mounted) rebuild(() {});
  }

  bool get current =>
      mounted &&
      generation == w.client.generation &&
      authority == workspaceAuthority(w) &&
      widget.parentMessageId == w.messageDomain.threadParentMessageId;

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
    rebuild(errorNotice.clear);
    store.refresh();
  }

  Future<void> toggle() async {
    final wasFollowing = following;
    if (!current || busy || wasFollowing == null) return;
    final threadId =
        store.threadChannelIdFor(widget.parentMessageId) ?? w.threadChannelId;
    if (wasFollowing && threadId == null) return;
    rebuild(errorNotice.clear);
    try {
      // Optimistic in the shared store; it reverts if the write fails.
      wasFollowing
          ? await store.unfollow(
              widget.parentMessageId,
              threadChannelId: threadId,
            )
          : await store.follow(widget.parentMessageId);
    } catch (_) {
      if (current) {
        rebuild(
          () => errorNotice.raise(
            'Thread notification settings could not be changed.',
            whileTrue: () => following == wasFollowing,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    outline?.removeListener(membershipChanged);
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

  void openMenu(VoidCallback openTimeline) {
    if (!current) return;
    if (menu != null) {
      closeMenu();
      return;
    }
    final overlay = Overlay.of(context);
    menu = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: RaftAnchoredPopup(
          anchorKey: menuAnchor,
          alignRight: Directionality.of(context) == TextDirection.ltr,
          gap: 4,
          snapToPixel: true,
          child: RaftBackDismiss(
            routeContext: this.context,
            onDismiss: closeMenu,
            child: TapRegion(
              groupId: menuGroup,
              onTapOutside: (_) => closeMenu(),
              child: RaftDismissScope(
                onDismiss: closeMenu,
                takeFocus: true,
                child: RaftMenuPanel(
                  kind: RaftMenuKind.dropdownMenu,
                  onDismiss: closeMenu,
                  children: [
                    if (widget.onFollowers != null)
                      RaftMenuItem(
                        kind: RaftMenuKind.dropdownMenu,
                        label: raftText(context, 'Following agents'),
                        onPressed: () {
                          closeMenu();
                          if (current) widget.onFollowers!();
                        },
                      ),
                    if (widget.onSearch != null)
                      RaftMenuItem(
                        kind: RaftMenuKind.dropdownMenu,
                        label: raftText(context, 'Search in thread'),
                        glyph: RaftGlyph.search,
                        autofocus: true,
                        onPressed: () {
                          closeMenu();
                          if (current) widget.onSearch!();
                        },
                      ),
                    if (outline?.hasReplies(widget.parentMessageId) == true)
                      RaftMenuItem(
                        kind: RaftMenuKind.dropdownMenu,
                        key: const Key('thread-timeline-menu-item'),
                        label: raftText(context, 'Timeline'),
                        glyph: RaftGlyph.list,
                        onPressed: () {
                          closeMenu();
                          openTimeline();
                        },
                      ),
                    if (widget.onViewChannel != null)
                      RaftMenuItem(
                        kind: RaftMenuKind.dropdownMenu,
                        label: raftText(context, 'View in channel'),
                        glyph: RaftGlyph.mapPin,
                        onPressed: () {
                          closeMenu();
                          if (current) widget.onViewChannel!();
                        },
                      ),
                    if (following == true && w.threadChannelId != null)
                      RaftMenuItem(
                        kind: RaftMenuKind.dropdownMenu,
                        key: const Key('thread-mark-unread'),
                        label: raftText(context, 'Mark as unread'),
                        glyph: RaftGlyph.messageSquareDot,
                        onPressed: () {
                          final id = w.threadChannelId;
                          closeMenu();
                          if (current && id != null) {
                            unawaited(
                              w.conversationReads.markOpenThreadUnread(id),
                            );
                          }
                        },
                      ),
                    RaftMenuItem(
                      kind: RaftMenuKind.dropdownMenu,
                      key: const Key('thread-follow-menu-item'),
                      label: raftText(
                        context,
                        following == true ? 'Unfollow thread' : 'Follow thread',
                      ),
                      glyph: following == true
                          ? RaftGlyph.unfollowThread
                          : RaftGlyph.followThread,
                      onPressed: following == null || busy
                          ? null
                          : () {
                              closeMenu();
                              toggle();
                            },
                    ),
                    if (error != null || loadError != null)
                      RaftMenuItem(
                        kind: RaftMenuKind.dropdownMenu,
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
          ),
        ),
      ),
    );
    overlay.insert(menu!);
  }

  void jumpToOutlineRow(String id) {
    final identity = w.threadIdentity;
    if (!current || identity == null) return;
    final jump = widget.onOutlineJump;
    if (jump != null) {
      jump(id);
      return;
    }
    unawaited(
      w.openThreadIdentity(
        parentChannelId: identity.parentChannelId,
        parentMessageId: identity.parentMessageId,
        focusedMessageId: id,
        initialThreadChannelId: w.threadChannelId,
        navigate: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.menuMode
      ? ThreadOutlineAnchor(
          outline: outline,
          onJump: jumpToOutlineRow,
          builder: (_, openTimeline) => TapRegion(
            key: menuAnchor,
            groupId: menuGroup,
            child: RaftThreadOverflowAction(
              key: const Key('thread-options'),
              label: raftText(context, 'Thread actions'),
              desktopBar: RaftThreadHeader.usesDesktopBar(context),
              onPressed: current ? () => openMenu(openTimeline) : null,
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
                RaftButton.text(
                  onPressed: retry,
                  child: Text(raftText(context, 'Retry')),
                )
              else
                RaftButton.text(
                  key: const Key('thread-follow-toggle'),
                  onPressed: following == null || busy ? null : toggle,
                  icon: RaftIcon(
                    following == true
                        ? RaftGlyph.unfollowThread
                        : RaftGlyph.followThread,
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
