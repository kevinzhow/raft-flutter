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
    if (mounted && widget.enabled && !expanded && height > MessageContentPrimitive.collapseHeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) => expandHiddenFocus());
    }
  }
  void expandHiddenFocus() {
    final focus = FocusManager.instance.primaryFocus?.context?.findRenderObject();
    final content = contentKey.currentContext?.findRenderObject();
    if (!mounted || expanded || focus is! RenderBox || content is! RenderBox || !focus.hasSize || !content.hasSize) return;
    // Only focus inside this message may reveal its hidden content.
    var ancestor = focus.parent;
    var owned = identical(focus, content);
    while (ancestor != null && !owned) {
      owned = identical(ancestor, content);
      ancestor = ancestor.parent;
    }
    if (!owned) return;
    final bottom = focus.localToGlobal(Offset(0, focus.size.height)).dy;
    final clippedBottom = content.localToGlobal(Offset.zero).dy + MessageContentPrimitive.collapseHeight;
    if (bottom > clippedBottom) setState(() => expanded = true);
  }
  @override
  Widget build(BuildContext context) {
    final overflow = height > MessageContentPrimitive.collapseHeight;
    final collapsed = widget.enabled && overflow && !expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(onFocusChange: (focused) {
          if (focused && collapsed) {
            WidgetsBinding.instance.addPostFrameCallback((_) => expandHiddenFocus());
          }
        }, child: ClipRect(child: Stack(children: [
          Align(
            key: contentKey,
            alignment: Alignment.topLeft,
            heightFactor: collapsed ? MessageContentPrimitive.collapseHeight / height : 1,
            child: RaftContentMeasure(
              onSize: (size) {
                if (mounted && (height - size.height).abs() > .5) {
                  setState(() => height = size.height);
                }
              },
              child: widget.child,
            ),
          ),
          if (collapsed) Positioned(left: 0, right: 0, bottom: 0,
            height: MessageContentPrimitive.collapseFadeHeight,
            child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [MessageContentSemantic(RaftTokens.of(context)).collapseFade,
                  MessageContentSemantic(RaftTokens.of(context)).collapseFade.withValues(alpha: 0)]),
            )))),
        ]))),
        if (widget.enabled && overflow)
          Padding(
            padding: const EdgeInsets.only(top: MessageContentPrimitive.toggleGap),
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
  const RaftContentMeasure({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SizeReporter(onSize);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _SizeReporter renderObject,
  ) => renderObject.onSize = onSize;
}

class _SizeReporter extends RenderProxyBox {
  _SizeReporter(this.onSize);
  ValueChanged<Size> onSize;
  Size? reported;
  @override
  void performLayout() {
    super.performLayout();
    if (reported == size) return;
    reported = size;
    final next = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(next));
  }
}

/// Canonical source ShowMoreToggle; shared controls own keyboard and focus.
class RaftShowMoreToggle extends StatelessWidget {
  const RaftShowMoreToggle({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback onPressed;
  final Widget? icon;
  @override
  Widget build(BuildContext context) => RaftControl(
    kind: RaftControlKind.textLink, shadow: true,
    visualHeight: 16, minimumTargetSize: MediaQuery.sizeOf(context).width < 768 ? 48 : 16,
    padding: EdgeInsets.zero, semanticLabel: label, onPressed: onPressed,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[icon!, const SizedBox(width: 4)],
      Text(label, style: RaftTypography.body(RaftTokens.of(context), size: MessageContentPrimitive.toggleSize, line: 16, weight: FontWeight.w900).copyWith(decoration: TextDecoration.underline)),
    ]),
  );
}
