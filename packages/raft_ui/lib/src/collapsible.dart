import 'package:flutter/material.dart';

import 'localization.dart';

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
  @override
  Widget build(BuildContext context) {
    final overflow = height > 320;
    final collapsed = widget.enabled && overflow && !expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            heightFactor: collapsed ? 320 / height : 1,
            child: _Measured(
              onSize: (size) {
                if (mounted && (height - size.height).abs() > .5)
                  setState(() => height = size.height);
              },
              child: widget.child,
            ),
          ),
        ),
        if (widget.enabled && overflow)
          TextButton.icon(
            onPressed: () => setState(() => expanded = !expanded),
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(
              raftText(context, expanded ? 'Show less' : 'Show more'),
            ),
          ),
      ],
    );
  }
}

class _Measured extends SingleChildRenderObjectWidget {
  const _Measured({required this.onSize, required super.child});
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
