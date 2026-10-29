import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Keeps the native editing value while the Android composer paints its IME
/// indicator from whole-line geometry, independent of fallback font metrics.
class RaftComposerEditingController extends TextEditingController {
  RaftComposerEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => super.buildTextSpan(
    context: context,
    style: style,
    withComposing:
        withComposing && Theme.of(context).platform != TargetPlatform.android,
  );
}

/// Adds the composing indicator to the composer's single native TextField.
/// It shares RenderEditable's layout, scroll offset, viewport and repaint
/// lifecycle; it neither creates another paragraph nor changes selection.
class RaftComposerComposingText extends StatelessWidget {
  const RaftComposerComposingText({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.color,
    required this.enabled,
    required this.child,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.android
      ? _ComposingTextBoundary(
          controller: controller,
          focusNode: focusNode,
          color: color,
          enabled: enabled,
          child: child,
        )
      : child;
}

class _ComposingTextBoundary extends SingleChildRenderObjectWidget {
  const _ComposingTextBoundary({
    required this.controller,
    required this.focusNode,
    required this.color,
    required this.enabled,
    required super.child,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderComposerComposingText(controller, focusNode, color, enabled);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderComposerComposingText renderObject,
  ) {
    renderObject.indicator
      ..controller = controller
      ..focusNode = focusNode
      ..color = color
      ..enabled = enabled;
  }
}

class _RenderComposerComposingText extends RenderProxyBox {
  _RenderComposerComposingText(
    TextEditingController controller,
    FocusNode focusNode,
    Color color,
    bool enabled,
  ) : indicator = _ComposingIndicator(controller, focusNode, color, enabled);

  final _ComposingIndicator indicator;
  RenderEditable? editable;

  RenderEditable? findEditable(RenderObject object) {
    if (object is RenderEditable) return object;
    RenderEditable? found;
    object.visitChildren((child) => found ??= findEditable(child));
    return found;
  }

  void bindEditable() {
    final next = child == null ? null : findEditable(child!);
    if (next == editable) return;
    unbindEditable();
    editable = next;
    // TextField does not supply a custom foreground painter. Built-in caret
    // painting remains owned by RenderEditable and is composed with this one.
    assert(next?.foregroundPainter == null);
    next?.foregroundPainter = indicator;
  }

  void unbindEditable() {
    final previous = editable;
    if (previous != null &&
        previous.attached &&
        previous.foregroundPainter == indicator) {
      previous.foregroundPainter = null;
    }
    editable = null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    bindEditable();
  }

  @override
  void detach() {
    unbindEditable();
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    bindEditable();
  }

  @override
  void dispose() {
    unbindEditable();
    indicator.dispose();
    super.dispose();
  }
}

class _ComposingIndicator extends RenderEditablePainter {
  _ComposingIndicator(
    this._controller,
    this._focusNode,
    this._color,
    this._enabled,
  ) {
    _controller.addListener(notifyListeners);
    _focusNode.addListener(notifyListeners);
  }

  TextEditingController _controller;
  FocusNode _focusNode;
  Color _color;
  bool _enabled;

  set controller(TextEditingController next) {
    if (next == _controller) return;
    _controller.removeListener(notifyListeners);
    _controller = next;
    next.addListener(notifyListeners);
    notifyListeners();
  }

  set focusNode(FocusNode next) {
    if (next == _focusNode) return;
    _focusNode.removeListener(notifyListeners);
    _focusNode = next;
    next.addListener(notifyListeners);
    notifyListeners();
  }

  set color(Color next) {
    if (next == _color) return;
    _color = next;
    notifyListeners();
  }

  set enabled(bool next) {
    if (next == _enabled) return;
    _enabled = next;
    notifyListeners();
  }

  @override
  bool shouldRepaint(RenderEditablePainter? oldDelegate) => oldDelegate != this;

  @override
  void paint(Canvas canvas, Size size, RenderEditable renderEditable) {
    final value = _controller.value;
    final range = value.composing;
    if (!_enabled ||
        !renderEditable.hasFocus ||
        renderEditable.readOnly ||
        !value.isComposingRangeValid ||
        range.isCollapsed) {
      return;
    }

    final paint = Paint()..color = _color;
    const thickness = 1.0;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    var start = range.start;
    while (start < range.end) {
      // Framework line ranges exclude hard newline characters. Consume those
      // only, keeping every other offset in the IME's original UTF-16 units.
      final codeUnit = value.text.codeUnitAt(start);
      if (codeUnit == 10 || codeUnit == 13) {
        start++;
        continue;
      }
      final line = renderEditable.getLineAtOffset(TextPosition(offset: start));
      final end = math.min(line.end, range.end);
      if (end <= start) break;
      final lineBoxes = renderEditable.getBoxesForSelection(line);
      if (lineBoxes.isNotEmpty) {
        final top = lineBoxes.map((box) => box.top).reduce(math.min);
        final bottom = lineBoxes.map((box) => box.bottom).reduce(math.max);
        if (top >= size.height) break;
        if (bottom > 0) {
          final boxes = renderEditable.getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: end),
          );
          // All font/bidi runs on this visual line use one line box bottom.
          // The stroke stays inside that box, including the final editor line.
          for (final box in boxes) {
            if (box.right > box.left) {
              canvas.drawRect(
                Rect.fromLTRB(box.left, bottom - thickness, box.right, bottom),
                paint,
              );
            }
          }
        }
      }
      start = end;
    }
    canvas.restore();
  }

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    _focusNode.removeListener(notifyListeners);
    super.dispose();
  }
}
