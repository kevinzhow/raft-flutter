import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'popover_anchor.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'popover_surface.dart';

/// RackRowAction's Popover (raft-ui Popover, `side="bottom" align="end"`,
/// `w-[420px] max-w-[calc(100vw-2rem)] p-4`): a trigger and a surface under
/// it. Esc and a press outside close it and focus returns to the trigger.
class RaftRackRowPopover extends StatefulWidget {
  const RaftRackRowPopover({
    super.key,
    required this.popoverKey,
    required this.trigger,
    required this.noteBuilder,
    required this.child,
  });

  /// The `text-footnote text-foreground-muted` paragraph above the content,
  /// drawn with the style given.
  final Widget Function(BuildContext context, TextStyle style) noteBuilder;

  /// Identifies the open surface (the Web `data-testid`).
  final Key popoverKey;

  /// Builds the trigger; [toggle] opens or closes the popover and [focusNode]
  /// belongs to the trigger's focusable.
  final Widget Function(
    BuildContext context,
    FocusNode focusNode,
    VoidCallback toggle,
  )
  trigger;
  final Widget child;

  @override
  State<RaftRackRowPopover> createState() => _RaftRackRowPopoverState();
}

class _RaftRackRowPopoverState extends State<RaftRackRowPopover> {
  final controller = MenuController();
  final anchorKey = GlobalKey();
  final focus = FocusNode(debugLabel: 'rack row popover trigger');

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(420.0, MediaQuery.sizeOf(context).width - 32);
    final t = RaftTokens.of(context);
    final muted = t.colors['foreground-muted']!;
    return RaftPopoverAnchor(
      controller: controller,
      anchorKey: anchorKey,
      childFocusNode: focus,
      gap: 8,
      collisionPadding: 8,
      alignRight: true,
      builder: (context, menu, _) => KeyedSubtree(
        key: anchorKey,
        child: widget.trigger(
          context,
          focus,
          () => menu.isOpen ? menu.close() : menu.open(),
        ),
      ),
      popup: SizedBox(
        key: widget.popoverKey,
        width: width,
        child: RaftPopoverSurface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Builder(
                  builder: (context) => widget.noteBuilder(
                    context,
                    t.scale(RaftTypeScale.footnote, color: muted),
                  ),
                ),
                const SizedBox(height: 8),
                widget.child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// RackRowAction's `flex items-center gap-2`: an icon button before the
/// action. The 184px action column can be narrower than both, so the pair
/// shrinks to fit rather than overflow (Web lets it spill into the column
/// beside it).
class RaftRackActionPair extends StatelessWidget {
  const RaftRackActionPair({
    super.key,
    required this.leading,
    required this.action,
  });
  final Widget leading, action;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerEnd,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [leading, action],
    ),
  );
}
