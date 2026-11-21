import 'dart:async';

import 'package:flutter/gestures.dart' show PointerEnterEvent, PointerExitEvent;
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/thread_outline.dart';
import '../data/workspace_controller.dart';
import 'history_paywall_view.dart';
import 'thread_outline_list.dart';
import 'thread_outline_scope.dart';

// The thread view mounts the outline viewport and the find bar together.
export 'thread_find_bar.dart' show threadFindBar;

Widget buildThreadTimelineTop(
  BuildContext context,
  WorkspaceController workspace, {
  required bool loading,
  required bool showSummary,
  required Widget? parent,
  required Widget? parentSlot,
  required int replyCount,
}) => RaftThreadTimelineTopSliver(
  parentKey: const ValueKey('thread-outline-parent'),
  showSummary: showSummary,
  parent: parent,
  parentSlot: parentSlot,
  hasMore: loading || workspace.threadHasMore,
  historyLimited: workspace.messageDomain.state.threadHistoryLimited,
  loadingOlder: loading || workspace.messageDomain.state.loadingOlder,
  loadingOlderLabel: raftText(context, 'Loading older replies...'),
  historyLimitedLabel: raftText(
    context,
    'Older replies are limited by the current plan',
  ),
  historyLimitedChild: RaftHistoryPaywallView(
    controller: workspace,
    thread: true,
    recentDivider: replyCount > 0,
  ),
  beginningLabel: raftText(context, 'Beginning of replies'),
  replyCountLabel: raftFormat(
    context,
    replyCount == 1 ? '{count} reply' : '{count} replies',
    {'count': replyCount},
  ),
);

class ThreadOutlineViewport extends StatelessWidget {
  const ThreadOutlineViewport({
    super.key,
    required this.controller,
    required this.onJump,
    required this.child,
  });

  final WorkspaceController? controller;
  final ValueChanged<String> onJump;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final w = controller;
    final outline = w == null ? null : threadOutlineFor(w);
    final parent = w?.threadIdentity?.parentMessageId;
    if (outline == null ||
        parent == null ||
        RaftInteraction.of(context).touch) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, bounds) {
        if (bounds.maxWidth < RaftThreadOutlineMetrics.railMinWidth) {
          return child;
        }
        return ListenableBuilder(
          listenable: outline,
          child: child,
          builder: (context, timeline) {
            final visible = outline.hasReplies(parent);
            return Stack(
              fit: StackFit.expand,
              children: [
                RaftThreadOutlineGutter(visible: visible, child: timeline!),
                if (visible)
                  PositionedDirectional(
                    end: RaftThreadOutlineMetrics.railRight,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ThreadOutlineRail(
                        outline: outline,
                        onJump: onJump,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ThreadOutlineRail extends StatefulWidget {
  const _ThreadOutlineRail({required this.outline, required this.onJump});
  final ThreadOutline outline;
  final ValueChanged<String> onJump;

  @override
  State<_ThreadOutlineRail> createState() => _ThreadOutlineRailState();
}

class _ThreadOutlineRailState extends State<_ThreadOutlineRail> {
  final anchor = GlobalKey();
  final popup = MenuController();
  final ticks = ScrollController();
  final railFocus = FocusNode(debugLabel: 'Thread outline rail');
  Timer? hoverTimer;
  bool keyboardOpen = false;
  bool returningFocus = false;
  (String?, int)? railPosition;

  void _opened() {
    hoverTimer?.cancel();
    if (!popup.isOpen) popup.open();
  }

  void _entered(PointerEnterEvent event) {
    hoverTimer?.cancel();
    hoverTimer = Timer(const Duration(milliseconds: 80), _opened);
  }

  void _exited(PointerExitEvent event) {
    hoverTimer?.cancel();
    if (!keyboardOpen) {
      hoverTimer = Timer(const Duration(milliseconds: 120), popup.close);
    }
  }

  void _railFocused(bool focused) {
    if (!focused || !railFocus.hasPrimaryFocus || returningFocus) return;
    setState(() => keyboardOpen = true);
    _opened();
  }

  void _dismissFromInside() {
    hoverTimer?.cancel();
    if (keyboardOpen) {
      returningFocus = true;
      railFocus.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        returningFocus = false;
      });
    }
    popup.close();
  }

  @override
  void dispose() {
    hoverTimer?.cancel();
    ticks.dispose();
    railFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.outline.items;
    final current = widget.outline.currentId;
    final index = items.indexWhere((item) => item.id == current);
    final nextPosition = (current, items.length - 1 - index);
    if (railPosition != nextPosition) {
      railPosition = nextPosition;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            railPosition != nextPosition ||
            !ticks.hasClients ||
            index < 0) {
          return;
        }
        final position = ticks.position;
        final offset =
            (nextPosition.$2 + .5) * RaftThreadOutlineMetrics.tickExtent -
            position.viewportDimension / 2;
        ticks.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
      });
    }
    final me = widget.outline.userId;
    return RaftPopoverAnchor(
      controller: popup,
      anchorKey: anchor,
      onClose: () {
        if (mounted && keyboardOpen) setState(() => keyboardOpen = false);
      },
      alignRight: true,
      centerVertically: true,
      builder: (_, _, child) => child!,
      popup: RaftDismissScope(
        onDismiss: _dismissFromInside,
        child: RaftHoverRegion(
          onEnter: _entered,
          onExit: _exited,
          child: RaftPopoverSurface(
            key: const Key('thread-outline-rail-card'),
            child: SizedBox(
              height: RaftThreadOutlineMetrics.previewHeight,
              width: RaftThreadOutlineMetrics.previewWidth,
              child: ThreadOutlineList(
                outline: widget.outline,
                compact: true,
                focusCurrent: keyboardOpen,
                onJump: (id) => widget.onJump(id),
              ),
            ),
          ),
        ),
      ),
      child: RaftHoverRegion(
        key: anchor,
        onEnter: _entered,
        onExit: _exited,
        child: Semantics(
          label: raftText(context, 'Thread timeline'),
          child: Focus(
            focusNode: railFocus,
            onFocusChange: _railFocused,
            descendantsAreTraversable: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: RaftThreadOutlineMetrics.railExtent,
                maxWidth: RaftThreadOutlineMetrics.railWidth,
              ),
              child: ListView.builder(
                controller: ticks,
                shrinkWrap: true,
                primary: false,
                reverse: true,
                itemExtent: RaftThreadOutlineMetrics.tickExtent,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[items.length - 1 - index];
                  return RaftInteractive(
                    key: ValueKey('thread-outline-tick-${item.id}'),
                    expandTouchTarget: false,
                    focusOnPointer: false,
                    semanticLabel: outlineItemText(context, item),
                    onPressed: () {
                      popup.close();
                      widget.onJump(item.id);
                    },
                    builder: (context, state) => Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ThreadOutlineTick(
                        own: item.senderId == me,
                        current:
                            item.id == current ||
                            state.focusVisible ||
                            state.hovered,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
