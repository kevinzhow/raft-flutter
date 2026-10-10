import 'package:flutter/material.dart';

import 'localization.dart';
import 'design_primitives.dart';
import 'message_content_tokens.dart';
import 'theme.dart';

import 'package:flutter/rendering.dart';

/// Measures rendered content, including images and Markdown, against the
/// reference Web's 320 logical pixel limit. Width changes are remeasured.
class RaftCollapsible extends StatefulWidget {
  const RaftCollapsible({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<RaftCollapsible> createState() => _RaftCollapsibleState();
}

class _RaftCollapsibleState extends State<RaftCollapsible> {
  double height = 0;
  bool expanded = false;
  final contentKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(focusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(focusChanged);
    super.dispose();
  }

  void focusChanged() {
    if (mounted &&
        widget.enabled &&
        !expanded &&
        height > MessageContentPrimitive.collapseHeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) => expandHiddenFocus());
    }
  }

  void expandHiddenFocus() {
    final focus = FocusManager.instance.primaryFocus?.context
        ?.findRenderObject();
    final content = contentKey.currentContext?.findRenderObject();
    if (!mounted ||
        expanded ||
        focus is! RenderBox ||
        content is! RenderBox ||
        !focus.hasSize ||
        !content.hasSize)
      return;
    // Only focus inside this message may reveal its hidden content.
    var ancestor = focus.parent;
    var owned = identical(focus, content);
    while (ancestor != null && !owned) {
      owned = identical(ancestor, content);
      ancestor = ancestor.parent;
    }
    if (!owned) return;
    final bottom = focus.localToGlobal(Offset(0, focus.size.height)).dy;
    final clippedBottom =
        content.localToGlobal(Offset.zero).dy +
        MessageContentPrimitive.collapseHeight;
    if (bottom > clippedBottom) setState(() => expanded = true);
  }

  void sizeChanged(Size size) {
    if (mounted && (height - size.height).abs() > .5) {
      setState(() => height = size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overflow = height > MessageContentPrimitive.collapseHeight;
    final collapsed = widget.enabled && overflow && !expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onFocusChange: (focused) {
            if (focused && collapsed) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => expandHiddenFocus(),
              );
            }
          },
          child: ClipRect(
            child: Stack(
              children: [
                Align(
                  key: contentKey,
                  alignment: Alignment.topLeft,
                  heightFactor: 1,
                  child: RaftContentMeasure(
                    // Pending content is bounded on its very first layout, like
                    // the original Web maxHeight rule. The child stays natural.
                    maxHeight: widget.enabled && !expanded
                        ? MessageContentPrimitive.collapseHeight
                        : null,
                    // A stable tear-off: a new closure per build would make
                    // the reporter relayout the whole message on every rebuild.
                    onSize: sizeChanged,
                    child: widget.child,
                  ),
                ),
                if (collapsed)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: MessageContentPrimitive.collapseFadeHeight,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              MessageContentSemantic(RaftTokens.of(context))
                                  .collapseFade,
                              MessageContentSemantic(RaftTokens.of(context))
                                  .collapseFade
                                  .withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.enabled && overflow)
          Padding(
            padding: const EdgeInsets.only(
              top: MessageContentPrimitive.toggleGap,
            ),
            child: RaftShowMoreToggle(
              label: raftText(context, expanded ? 'Collapse' : 'Show more'),
              onPressed: () => setState(() => expanded = !expanded),
            ),
          ),
      ],
    );
  }
}

class RaftContentMeasure extends SingleChildRenderObjectWidget {
  const RaftContentMeasure({
    super.key,
    required this.onSize,
    required super.child,
    this.maxHeight,
  }) : assert(maxHeight == null || maxHeight >= 0);
  final ValueChanged<Size> onSize;

  /// Bounds this viewport, while measuring the unconstrained natural child.
  /// Null preserves the original unbounded measurement behavior.
  final double? maxHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SizeReporter(onSize, maxHeight);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _SizeReporter renderObject,
  ) {
    renderObject
      ..onSize = onSize
      ..maxHeight = maxHeight;
  }
}

class _SizeReporter extends RenderProxyBox {
  _SizeReporter(this._onSize, this._maxHeight);
  ValueChanged<Size> _onSize;
  double? _maxHeight;
  Size? _delivered, _pending, _natural;
  int _receiptRevision = 0;

  set onSize(ValueChanged<Size> value) {
    if (value == _onSize) return;
    _onSize = value;
    _receiptRevision++;
    _pending = null;
    markNeedsLayout();
  }

  set maxHeight(double? value) {
    if (value == _maxHeight) return;
    _maxHeight = value;
    markNeedsLayout();
  }

  BoxConstraints get _childConstraints => _maxHeight == null
      ? constraints
      : constraints.copyWith(minHeight: 0, maxHeight: double.infinity);
  Size _viewportSize(Size natural, BoxConstraints parent) {
    final limit = _maxHeight;
    return parent.constrain(
      Size(
        natural.width,
        limit == null || natural.height <= limit ? natural.height : limit,
      ),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childConstraints = _maxHeight == null
        ? constraints
        : constraints.copyWith(minHeight: 0, maxHeight: double.infinity);
    return _viewportSize(
      child?.getDryLayout(childConstraints) ?? Size.zero,
      constraints,
    );
  }

  @override
  void performLayout() {
    child?.layout(_childConstraints, parentUsesSize: true);
    final next = child?.size ?? Size.zero;
    // A pending B receipt is obsolete if another layout returns to A before
    // post-frame delivery. Clear it even when A was already delivered, so a
    // later B can enqueue a fresh receipt rather than be starved forever.
    if (_pending != null && _pending != next) {
      _pending = null;
      _receiptRevision++;
    }
    _natural = next;
    size = _viewportSize(next, constraints);
    if (_delivered == next || _pending == next) return;
    _pending = next;
    final revision = _receiptRevision;
    final callback = _onSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A recycled/disposed row or newer child/width receipt cannot publish
      // an obsolete height into the current callback/state.
      if (!attached ||
          revision != _receiptRevision ||
          _pending != next ||
          _natural != next)
        return;
      _pending = null;
      _delivered = next;
      callback(next);
    });
  }

  @override
  void detach() {
    _receiptRevision++;
    _pending = null;
    // Reattachment must deliver even if its first size equals the old size.
    _delivered = null;
    super.detach();
  }
}

/// Canonical source ShowMoreToggle; shared controls own keyboard and focus.
class RaftShowMoreToggle extends StatefulWidget {
  const RaftShowMoreToggle({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style,
    this.visualHeight = 16,
  });
  final String label;
  final VoidCallback onPressed;
  final Widget? icon;
  final TextStyle? style;
  final double visualHeight;
  @override
  State<RaftShowMoreToggle> createState() => _RaftShowMoreToggleState();
}

class _RaftShowMoreToggleState extends State<RaftShowMoreToggle> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final style = widget.style ?? MessageContentRecipe(tokens).toggle;
    final color = hovered
        ? MessageContentSemantic(tokens).toggleHover
        : style.color;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: RaftControl(
        kind: RaftControlKind.textLink,
        shadow: true,
        visualHeight: widget.visualHeight,
        // Web ShowMoreToggle is the bare 11px text on touch too: no
        // touch-target expansion that would push the content below it.
        minimumTargetSize: widget.visualHeight,
        padding: EdgeInsets.zero,
        semanticLabel: widget.label,
        onPressed: widget.onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              widget.icon!,
              const SizedBox(width: 4),
            ],
            Text(
              widget.label,
              style: style.copyWith(color: color, decorationColor: color),
            ),
          ],
        ),
      ),
    );
  }
}
