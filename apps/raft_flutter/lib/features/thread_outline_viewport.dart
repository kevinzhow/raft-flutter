import 'dart:async';

import 'package:flutter/gestures.dart' show PointerEnterEvent, PointerExitEvent;
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/thread_outline.dart';
import '../data/workspace_controller.dart';
import 'thread_outline_list.dart';
import 'thread_outline_scope.dart';

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
          builder: (context, timeline) => Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: outline.hasReplies(parent)
                    ? RaftThreadOutlineMetrics.timelineInset
                    : EdgeInsets.zero,
                child: timeline,
              ),
              if (outline.hasReplies(parent))
                PositionedDirectional(
                  end: RaftThreadOutlineMetrics.railRight,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ThreadOutlineRail(outline: outline, onJump: onJump),
                  ),
                ),
            ],
          ),
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
  final railFocus = FocusNode(debugLabel: 'Thread outline rail');
  Timer? hoverTimer;
  bool keyboardOpen = false;
  bool returningFocus = false;

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
    railFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.outline.items;
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
                            item.id == widget.outline.currentId ||
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
