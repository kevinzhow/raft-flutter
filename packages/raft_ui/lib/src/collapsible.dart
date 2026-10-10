import 'dart:math' as math;

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
  /// Natural content height from the latest layout. Written during layout;
  /// overflow is decided in that same layout, never by a later rebuild.
  double natural = 0;
  bool expanded = false;
  final contentKey = GlobalKey();
  bool get overflow => natural > MessageContentPrimitive.collapseHeight;
  bool get collapsed => widget.enabled && overflow && !expanded;
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
    if (mounted && widget.enabled && !expanded && overflow) {
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

  // Stable tear-offs: a new closure per build would relayout the message.
  void measured(Size size) => natural = size.height;
  bool currentOverflow() => widget.enabled && overflow;
  void toggle() => setState(() => expanded = !expanded);

  @override
  Widget build(BuildContext context) {
    final label = raftText(context, expanded ? 'Collapse' : 'Show more');
    final fade = MessageContentSemantic(RaftTokens.of(context)).collapseFade;
    return _CollapsibleLayout(
      overflow: currentOverflow,
      fadeColor: widget.enabled && !expanded ? fade : null,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      content: Focus(
        onFocusChange: (focused) {
          if (focused && collapsed) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => expandHiddenFocus(),
            );
          }
        },
        child: ClipRect(
          child: Align(
            key: contentKey,
            alignment: Alignment.topLeft,
            heightFactor: 1,
            child: RaftContentMeasure(
              // Pending content is bounded on its very first layout, like
              // the original Web maxHeight rule. The child stays natural.
              maxHeight: widget.enabled && !expanded
                  ? MessageContentPrimitive.collapseHeight
                  : null,
              onLayout: measured,
              child: widget.child,
            ),
          ),
        ),
      ),
      // Built during layout, once the natural height is known, so a long
      // message shows its toggle in the frame it first appears.
      toggle: (overflow) => overflow
          ? Padding(
              padding: const EdgeInsets.only(
                top: MessageContentPrimitive.toggleGap,
              ),
              child: RaftShowMoreToggle(label: label, onPressed: toggle),
            )
          : null,
    );
  }
}

enum _CollapsibleSlot { content, toggle }

/// A start-aligned two-child column whose second child (the Show more
/// toggle) is built during layout from the first child's natural height,
/// and which paints the collapse fade over the clipped content.
class _CollapsibleLayout extends RenderObjectWidget {
  const _CollapsibleLayout({
    required this.content,
    required this.toggle,
    required this.overflow,
    required this.fadeColor,
    required this.textDirection,
  });
  final Widget content;
  final Widget? Function(bool overflow) toggle;
  final bool Function() overflow;
  final Color? fadeColor;
  final TextDirection textDirection;
  @override
  RenderObjectElement createElement() => _CollapsibleLayoutElement(this);
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCollapsibleLayout(overflow, fadeColor, textDirection);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCollapsibleLayout renderObject,
  ) {
    renderObject
      ..overflow = overflow
      ..fadeColor = fadeColor
      ..textDirection = textDirection;
  }
}

class _CollapsibleLayoutElement extends RenderObjectElement {
  _CollapsibleLayoutElement(_CollapsibleLayout super.widget);
  Element? content, toggle;
  @override
  _RenderCollapsibleLayout get renderObject =>
      super.renderObject as _RenderCollapsibleLayout;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (content != null) visitor(content!);
    if (toggle != null) visitor(toggle!);
  }

  @override
  void forgetChild(Element child) {
    if (identical(child, content)) content = null;
    if (identical(child, toggle)) toggle = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    content = updateChild(
      null,
      (widget as _CollapsibleLayout).content,
      _CollapsibleSlot.content,
    );
    renderObject.buildToggle = buildToggle;
  }

  @override
  void update(_CollapsibleLayout newWidget) {
    super.update(newWidget);
    content = updateChild(content, newWidget.content, _CollapsibleSlot.content);
    renderObject.markToggleNeedsBuild();
  }

  @override
  void unmount() {
    renderObject.buildToggle = null;
    super.unmount();
  }

  void buildToggle(bool overflow) {
    owner!.buildScope(this, () {
      toggle = updateChild(
        toggle,
        (widget as _CollapsibleLayout).toggle(overflow),
        _CollapsibleSlot.toggle,
      );
    });
  }

  @override
  void insertRenderObjectChild(RenderBox child, _CollapsibleSlot slot) =>
      renderObject.setChild(slot, child);

  @override
  void moveRenderObjectChild(
    RenderObject child,
    Object? oldSlot,
    Object? newSlot,
  ) {
    assert(false, 'Collapsible children never change slots.');
  }

  @override
  void removeRenderObjectChild(RenderBox child, _CollapsibleSlot slot) =>
      renderObject.setChild(slot, null);
}

class _RenderCollapsibleLayout extends RenderBox {
  _RenderCollapsibleLayout(
    this._overflow,
    this._fadeColor,
    this._textDirection,
  );
  RenderBox? _content, _toggle;
  void Function(bool overflow)? buildToggle;
  bool _toggleStale = true;
  bool? _builtFor;

  bool Function() _overflow;
  set overflow(bool Function() value) {
    if (value == _overflow) return;
    _overflow = value;
    markToggleNeedsBuild();
  }

  Color? _fadeColor;
  set fadeColor(Color? value) {
    if (value == _fadeColor) return;
    _fadeColor = value;
    markNeedsPaint();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  void markToggleNeedsBuild() {
    _toggleStale = true;
    markNeedsLayout();
  }

  void setChild(_CollapsibleSlot slot, RenderBox? child) {
    final old = slot == _CollapsibleSlot.content ? _content : _toggle;
    if (old != null) dropChild(old);
    if (slot == _CollapsibleSlot.content) {
      _content = child;
    } else {
      _toggle = child;
    }
    if (child != null) adoptChild(child);
  }

  Iterable<RenderBox> get _children => [?_content, ?_toggle];

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final child in _children) {
      child.attach(owner);
    }
  }

  @override
  void detach() {
    super.detach();
    for (final child in _children) {
      child.detach();
    }
  }

  @override
  void redepthChildren() => _children.forEach(redepthChild);

  @override
  void visitChildren(RenderObjectVisitor visitor) => _children.forEach(visitor);

  @override
  List<DiagnosticsNode> debugDescribeChildren() => [
    if (_content != null) _content!.toDiagnosticsNode(name: 'content'),
    if (_toggle != null) _toggle!.toDiagnosticsNode(name: 'toggle'),
  ];

  // Column(crossAxisAlignment: start) semantics for both children.
  Offset _offset(RenderBox child, double top) => Offset(
    _textDirection == TextDirection.rtl ? size.width - child.size.width : 0,
    top,
  );

  @override
  void performLayout() {
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    final content = _content!..layout(childConstraints, parentUsesSize: true);
    final overflow = _overflow();
    if (_toggleStale || overflow != _builtFor) {
      _toggleStale = false;
      _builtFor = overflow;
      invokeLayoutCallback<BoxConstraints>((_) => buildToggle?.call(overflow));
    }
    final toggle = _toggle?..layout(childConstraints, parentUsesSize: true);
    var width = content.size.width, height = content.size.height;
    if (toggle != null) {
      width = math.max(width, toggle.size.width);
      height += toggle.size.height;
    }
    size = constraints.constrain(
      Size(
        width,
        constraints.hasBoundedHeight ? constraints.maxHeight : height,
      ),
    );
    (content.parentData! as BoxParentData).offset = _offset(content, 0);
    if (toggle != null) {
      (toggle.parentData! as BoxParentData).offset = _offset(
        toggle,
        content.size.height,
      );
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => _children.fold(
    0,
    (a, c) => math.max(a, c.getMinIntrinsicWidth(double.infinity)),
  );
  @override
  double computeMaxIntrinsicWidth(double height) => _children.fold(
    0,
    (a, c) => math.max(a, c.getMaxIntrinsicWidth(double.infinity)),
  );
  @override
  double computeMinIntrinsicHeight(double width) =>
      _children.fold(0, (a, c) => a + c.getMinIntrinsicHeight(width));
  @override
  double computeMaxIntrinsicHeight(double width) =>
      _children.fold(0, (a, c) => a + c.getMaxIntrinsicHeight(width));

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    for (final child in _children) {
      final distance = child.getDistanceToActualBaseline(baseline);
      if (distance != null) {
        return distance + (child.parentData! as BoxParentData).offset.dy;
      }
    }
    return null;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _children.toList().reversed) {
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData! as BoxParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final content = _content!;
    final origin = offset + (content.parentData! as BoxParentData).offset;
    context.paintChild(content, origin);
    final fade = _fadeColor;
    if (fade != null && _builtFor == true) {
      // The source fade: an inert gradient over the clipped bottom edge.
      final rect = Rect.fromLTWH(
        origin.dx,
        origin.dy +
            content.size.height -
            MessageContentPrimitive.collapseFadeHeight,
        content.size.width,
        MessageContentPrimitive.collapseFadeHeight,
      );
      context.canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [fade, fade.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }
    final toggle = _toggle;
    if (toggle != null) {
      context.paintChild(
        toggle,
        offset + (toggle.parentData! as BoxParentData).offset,
      );
    }
  }
}

class RaftContentMeasure extends SingleChildRenderObjectWidget {
  const RaftContentMeasure({
    super.key,
    this.onSize,
    this.onLayout,
    required super.child,
    this.maxHeight,
  }) : assert(maxHeight == null || maxHeight >= 0);

  /// The natural size after the frame it was laid out in.
  final ValueChanged<Size>? onSize;

  /// The natural size during layout, for an ancestor that lays out next.
  /// Must not mark anything dirty.
  final ValueChanged<Size>? onLayout;

  /// Bounds this viewport, while measuring the unconstrained natural child.
  /// Null preserves the original unbounded measurement behavior.
  final double? maxHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SizeReporter(onSize, maxHeight)..onLayout = onLayout;
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _SizeReporter renderObject,
  ) {
    renderObject
      ..onSize = onSize
      ..onLayout = onLayout
      ..maxHeight = maxHeight;
  }
}

class _SizeReporter extends RenderProxyBox {
  _SizeReporter(this._onSize, this._maxHeight);
  ValueChanged<Size>? _onSize;
  ValueChanged<Size>? onLayout;
  double? _maxHeight;
  Size? _delivered, _pending, _natural;
  int _receiptRevision = 0;

  set onSize(ValueChanged<Size>? value) {
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
    onLayout?.call(next);
    if (_onSize == null || _delivered == next || _pending == next) return;
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
      callback?.call(next);
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
