// The profile's inline navigation targets (Web AgentDetailPanel Info rows): the
// Computer name and the creator are buttons that underline on hover.
import 'package:flutter/material.dart';

import 'hover_region.dart';

/// A text-like button: the [child] underlines while the pointer is over it or
/// it has keyboard focus (`hover:underline`), taps and Enter / Space run
/// [onPressed], and it reads as a button to assistive technology.
class RaftProfileLink extends StatefulWidget {
  const RaftProfileLink({
    super.key,
    required this.child,
    required this.onPressed,
    this.semanticLabel,
  });
  final Widget child;
  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  State<RaftProfileLink> createState() => _RaftProfileLinkState();
}

class _RaftProfileLinkState extends State<RaftProfileLink> {
  bool hovered = false, focused = false;

  @override
  Widget build(BuildContext context) {
    final underline = hovered || focused;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: RaftHoverRegion(
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: DefaultTextStyle.merge(
              style: TextStyle(
                decoration: underline
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
