import 'package:flutter/material.dart';

import 'adaptive_workspace.dart' show RaftPanelResizeHandle;

/// Two columns side by side with a drag handle on the edge between them: the
/// [start] column is [width] wide, between [minWidth] and [maxWidth], and the
/// [end] column takes the rest (Web `useResizablePanel` with `direction:
/// "right"`, e.g. the agent workspace's file tree). The live width is kept
/// here while the person drags; the host stores it when the drag ends
/// ([onWidthChanged]), and a changed [width] from the host replaces it.
class RaftSplitPane extends StatefulWidget {
  const RaftSplitPane({
    super.key,
    required this.start,
    required this.end,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.resizeLabel,
    this.onWidthChanged,
  });
  final Widget start, end;
  final double width, minWidth, maxWidth;
  final String resizeLabel;
  final ValueChanged<double>? onWidthChanged;

  @override
  State<RaftSplitPane> createState() => _RaftSplitPaneState();
}

class _RaftSplitPaneState extends State<RaftSplitPane> {
  late double width = clamp(widget.width);

  double clamp(double value) => value.clamp(widget.minWidth, widget.maxWidth);

  @override
  void didUpdateWidget(RaftSplitPane old) {
    super.didUpdateWidget(old);
    if (old.width != widget.width) width = clamp(widget.width);
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const Key('split-pane-start'),
            width: width,
            child: widget.start,
          ),
          Expanded(child: widget.end),
        ],
      ),
      // The strip straddles the dividing line and takes no layout width.
      Positioned(
        left: width - RaftPanelResizeHandle.hitExtent / 2,
        top: 0,
        bottom: 0,
        width: RaftPanelResizeHandle.hitExtent,
        child: RaftPanelResizeHandle(
          key: const Key('split-pane-resize-handle'),
          label: widget.resizeLabel,
          value: width,
          onChanged: (value) => setState(() => width = clamp(value)),
          onChangeEnd: () => widget.onWidthChanged?.call(width),
        ),
      ),
    ],
  );
}
