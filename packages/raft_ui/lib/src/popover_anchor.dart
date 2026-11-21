import 'package:flutter/widgets.dart';

import 'anchored_popup.dart';
import 'dismiss_scope.dart';

/// Caller-controlled popover lifetime with the shared Raft popup placement.
///
/// The caller retains its controller, focus node, trigger, popup contents and
/// activation authority. This adapter paints nothing and adds no menu items or
/// selection semantics. The popup's own component owns its keyboard traversal.
class RaftPopoverAnchor extends StatefulWidget {
  const RaftPopoverAnchor({
    super.key,
    required this.controller,
    required this.anchorKey,
    required this.builder,
    required this.popup,
    this.childFocusNode,
    this.onOpen,
    this.onClose,
    this.child,
    this.gap = 4,
    this.collisionPadding = 5,
    this.alignRight = false,
    this.centerVertically = false,
    this.flipVertically = true,
    this.scrollChild = true,
  });

  final MenuController controller;
  final GlobalKey anchorKey;
  final RawMenuAnchorChildBuilder builder;
  final Widget popup;
  final FocusNode? childFocusNode;
  final VoidCallback? onOpen, onClose;
  final Widget? child;
  final double gap, collisionPadding;

  /// Web `align="end"`: the popup's right edge on the trigger's.
  final bool alignRight;
  final bool centerVertically;
  final bool flipVertically;
  final bool scrollChild;

  @override
  State<RaftPopoverAnchor> createState() => _RaftPopoverAnchorState();
}

class _RaftPopoverAnchorState extends State<RaftPopoverAnchor> {
  // Observes descendant ownership; never becomes a focus target itself.
  final _popupFocus = FocusNode(canRequestFocus: false, skipTraversal: true);

  @override
  void dispose() {
    _popupFocus.dispose();
    super.dispose();
  }

  void _closed() {
    final heldFocus = _popupFocus.hasFocus;
    widget.onClose?.call();
    if (!heldFocus) return;
    final trigger = widget.childFocusNode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = FocusManager.instance.primaryFocus;
      final lostOwner =
          current == null ||
          current == FocusManager.instance.rootScope ||
          current.context?.mounted != true;
      // A destination that claimed focus while dismissing the popup wins.
      if (lostOwner &&
          trigger?.context?.mounted == true &&
          trigger!.canRequestFocus) {
        trigger.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) => RawMenuAnchor(
    controller: widget.controller,
    childFocusNode: widget.childFocusNode,
    onOpen: widget.onOpen,
    onClose: _closed,
    builder: widget.builder,
    child: widget.child,
    overlayBuilder: (context, info) => Positioned.fill(
      // The system back gesture closes the popover, not the page under it.
      child: RaftBackDismiss(
        onDismiss: widget.controller.close,
        child: RaftAnchoredPopup(
          anchorKey: widget.anchorKey,
          anchorRect: info.anchorRect,
          gap: widget.gap,
          collisionPadding: widget.collisionPadding,
          alignRight: widget.alignRight,
          centerVertically: widget.centerVertically,
          flipVertically: widget.flipVertically,
          scrollChild: widget.scrollChild,
          snapToPixel: true,
          child: TapRegion(
            groupId: info.tapRegionGroupId,
            onTapOutside: (_) => widget.controller.close(),
            child: Focus(
              focusNode: _popupFocus,
              includeSemantics: false,
              child: widget.popup,
            ),
          ),
        ),
      ),
    ),
  );
}
