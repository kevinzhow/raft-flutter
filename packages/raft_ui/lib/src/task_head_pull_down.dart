// Task v2 dialog on a phone (Web v1.24 TaskConversationDialog / TaskHeadPullDown):
// the head is the conversation's first row and scrolls away with it; while it
// is out of view the bar names the task's state, and selecting it pulls the
// head down again over the messages without losing the place in the
// discussion. Off a phone the head stays pinned above the conversation, at
// most 45% of the dialog (it scrolls inside itself beyond that).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'components.dart' show RaftAvatar, RaftAvatarKind;
import 'icons.dart';
import 'mounted_avatar_recipe.dart';
import 'raft/ui_tokens.dart';
import 'popover_surface.dart';
import 'space.dart';
import 'task.dart' show RaftTaskStatus;
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

/// Whether the head is on screen, with the way to re-measure it (a scroll of
/// the messages under it calls [remeasure]).
class RaftTaskHeadVisibility extends ValueNotifier<bool> {
  RaftTaskHeadVisibility() : super(true);
  VoidCallback? _measure;

  /// After the frame: a scroll notification comes before the layout it causes.
  void remeasure() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure?.call());
}

/// Web `TaskHeadInView`: the head as a timeline row, reporting whether any of
/// it is on screen. Out of view is read from the head's edge against the
/// viewport that holds it; leaving the tree reports it back in view, so the
/// bar never keeps a summary for a head that is no longer a row.
class RaftTaskHeadInView extends StatefulWidget {
  const RaftTaskHeadInView({
    super.key,
    required this.visibility,
    required this.child,
  });
  final RaftTaskHeadVisibility visibility;
  final Widget child;

  @override
  State<RaftTaskHeadInView> createState() => _RaftTaskHeadInViewState();
}

class _RaftTaskHeadInViewState extends State<RaftTaskHeadInView> {
  @override
  void initState() {
    super.initState();
    widget.visibility._measure = measure;
    schedule();
  }

  @override
  void didUpdateWidget(RaftTaskHeadInView old) {
    super.didUpdateWidget(old);
    widget.visibility._measure = measure;
    schedule();
  }

  @override
  void dispose() {
    final visibility = widget.visibility;
    visibility._measure = null;
    // Not while the tree is being torn down: the notifier may be disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        visibility.value = true;
      } catch (_) {}
    });
    super.dispose();
  }

  void schedule() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => measure());

  void measure() {
    if (!mounted) return;
    final box = context.findRenderObject();
    final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);
    if (box is! RenderBox || !box.attached || viewport is! RenderBox) return;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final top = (viewport as RenderBox).localToGlobal(Offset.zero).dy;
    widget.visibility.value = bottom > top;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The bar's summary of the task once the head has scrolled away: "Task #7",
/// its status and its assignee, with a chevron; it opens and closes the
/// head's panel (Web `task-modal-bar-summary`).
class RaftTaskBarSummary extends StatelessWidget {
  const RaftTaskBarSummary({
    super.key,
    required this.label,
    required this.status,
    required this.assignee,
    required this.open,
    required this.onToggle,
    this.assigneeIsAgent = false,
  });
  final String label, status;

  /// The assignee's name; null while unassigned.
  final String? assignee;
  final bool assigneeIsAgent, open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final name = assignee;
    return LayoutBuilder(
      builder: (context, constraints) => Semantics(
        button: true,
        expanded: open,
        child: GestureDetector(
          key: const ValueKey('task-modal-bar-summary'),
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: RaftSpace.x1_5,
            children: [
              Flexible(
                child: Text(
                  label,
                  key: const ValueKey('task-modal-bar-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.scale(
                    RaftTypeScale.subhead,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              RaftTaskStatus(
                key: const ValueKey('task-modal-bar-status'),
                status: status,
              ),
              if (name != null)
                // The avatar, named for screen readers; the name beside it
                // only where the bar has room for it whole (Web `@[22rem]`).
                Semantics(
                  label: name,
                  child: SizedBox.square(
                    dimension: RaftSpace.x4,
                    child: ExcludeSemantics(
                      child: RaftAvatar(
                        name: name,
                        kind: assigneeIsAgent
                            ? RaftAvatarKind.agent
                            : RaftAvatarKind.human,
                        mountedContext: RaftMountedAvatarContext.compactList,
                        content: RaftMountedAvatarFallback(
                          avatarContext: RaftMountedAvatarContext.compactList,
                          identity: assigneeIsAgent
                              ? RaftMountedAvatarIdentity.agent
                              : RaftMountedAvatarIdentity.human,
                        ),
                      ),
                    ),
                  ),
                ),
              if (name != null && constraints.maxWidth >= 352)
                Flexible(
                  child: Text(
                    name,
                    key: const ValueKey('task-modal-bar-assignee-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.scale(
                      RaftTypeScale.callout,
                      color: t.ui.foregroundMuted,
                    ),
                  ),
                ),
              AnimatedRotation(
                turns: open ? .5 : 0,
                duration: const Duration(milliseconds: 220),
                child: RaftIcon(
                  RaftGlyph.chevronDown,
                  size: 14,
                  color: t.ui.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hangs [panel] from the bar ([link] is the bar's target) over the
/// conversation while [open]: no scrim, the messages stay live under it.
/// A press on the messages below, starting to scroll them and Escape close it.
Widget raftTaskPullDownHost({
  required LayerLink link,
  required bool open,
  required VoidCallback onClose,
  required Widget panel,
  required Widget child,
}) => LayoutBuilder(
  builder: (context, constraints) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (open)
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          child: SizedBox(
            width: constraints.maxWidth,
            child: _PullDownPanel(
              maxHeight: MediaQuery.sizeOf(context).height * .7,
              onClose: onClose,
              child: panel,
            ),
          ),
        ),
    ],
  ),
);

/// The panel: focus moves into it when it opens (so Escape closes it, not
/// the dialog around it).
class _PullDownPanel extends StatefulWidget {
  const _PullDownPanel({
    required this.maxHeight,
    required this.onClose,
    required this.child,
  });
  final double maxHeight;
  final VoidCallback onClose;
  final Widget child;

  @override
  State<_PullDownPanel> createState() => _PullDownPanelState();
}

class _PullDownPanelState extends State<_PullDownPanel> {
  final focus = FocusNode(debugLabel: 'task head pull-down');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focus.requestFocus();
    });
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
    },
    child: Focus(
      focusNode: focus,
      child: ConstrainedBox(
        key: const ValueKey('task-head-pull-down'),
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: RaftPopoverSurface(
          child: SingleChildScrollView(child: widget.child),
        ),
      ),
    ),
  );
}

/// The messages under the pull-down: a press or a scroll start closes it.
/// The wrappers stay in the tree whether or not it is open, so opening it
/// never rebuilds (and rewinds) the messages.
Widget raftTaskPullDownDismiss({
  required bool open,
  required VoidCallback onClose,
  required Widget child,
}) => NotificationListener<ScrollStartNotification>(
  onNotification: (_) {
    if (open) onClose();
    return false;
  },
  child: Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) {
      if (open) onClose();
    },
    child: child,
  ),
);

/// Off a phone: the head pinned above the conversation, at most 45% of it.
Widget raftTaskPinnedHead({required Widget head, required Widget child}) =>
    LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          ConstrainedBox(
            key: const ValueKey('task-conversation-head'),
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .45),
            child: SingleChildScrollView(child: head),
          ),
          Expanded(child: child),
        ],
      ),
    );
