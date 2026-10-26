import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// GTK-style left:right ordering. Ignore unknown and repeated controls; an
/// invalid value falls back to a usable close/minimize/maximize group.
@immutable
class DesktopCaptionLayout {
  const DesktopCaptionLayout(this.leading, this.trailing);
  factory DesktopCaptionLayout.parse(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return standard;
    final seen = <String>{};
    List<String> group(String text) => [
      for (final name in text.split(','))
        if (const {'minimize', 'maximize', 'close'}.contains(name.trim()) &&
            seen.add(name.trim()))
          name.trim(),
    ];
    final left = group(parts.first), right = group(parts.last);
    return left.isEmpty && right.isEmpty
        ? standard
        : DesktopCaptionLayout(left, right);
  }
  static const standard = DesktopCaptionLayout([], [
    'minimize',
    'maximize',
    'close',
  ]);
  final List<String> leading, trailing;
  double inset(List<String> group, {required bool windows}) => group.isEmpty
      ? 0
      : group.length * (windows ? 46 : 37) + (windows ? 0 : 4);
}

/// Caption targets overlay the shared toolbar; the toolbar separately reserves
/// their insets. Only buttons take pointer events, leaving the empty row draggable.
class DesktopCaptionControls extends StatefulWidget {
  const DesktopCaptionControls({
    super.key,
    required this.layout,
    required this.windows,
    required this.maximized,
    required this.active,
    required this.visible,
    required this.onAction,
    required this.onRects,
  });
  final DesktopCaptionLayout layout;
  final bool windows, maximized, active, visible;
  final ValueChanged<String> onAction;
  final ValueChanged<Map<String, Object>> onRects;
  @override
  State<DesktopCaptionControls> createState() => _DesktopCaptionControlsState();
}

class _DesktopCaptionControlsState extends State<DesktopCaptionControls> {
  final _keys = {
    for (final name in ['minimize', 'maximize', 'close']) name: GlobalKey(),
  };
  bool _pending = false;
  void _report() {
    if (_pending) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!mounted) return;
      final rects = <String, Object>{};
      if (widget.visible) {
        for (final entry in _keys.entries) {
          final box = entry.value.currentContext?.findRenderObject();
          if (box is! RenderBox || !box.hasSize) continue;
          final origin = box.localToGlobal(Offset.zero);
          rects[entry.key] = {
            'x': origin.dx,
            'y': origin.dy,
            'width': box.size.width,
            'height': box.size.height,
          };
        }
      }
      widget.onRects(rects);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _report();
      if (!widget.visible) return const SizedBox.shrink();
      Widget group(List<String> names) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final name in names)
            SizedBox(
              key: _keys[name],
              width: widget.windows ? 46 : 37,
              height: 48,
              child: _CaptionButton(
                key: Key('desktop-caption-$name'),
                name: name,
                windows: widget.windows,
                maximized: widget.maximized,
                active: widget.active,
                onPressed: () => widget.onAction(
                  name == 'maximize' ? 'toggleMaximize' : name,
                ),
              ),
            ),
        ],
      );
      final pad = widget.windows ? 0.0 : 4.0;
      return Stack(
        children: [
          if (widget.layout.leading.isNotEmpty)
            Positioned(left: pad, top: 0, child: group(widget.layout.leading)),
          if (widget.layout.trailing.isNotEmpty)
            Positioned(
              right: pad,
              top: 0,
              child: group(widget.layout.trailing),
            ),
        ],
      );
    },
  );
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    super.key,
    required this.name,
    required this.windows,
    required this.maximized,
    required this.active,
    required this.onPressed,
  });
  final String name;
  final bool windows, maximized, active;
  final VoidCallback onPressed;
  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool hovered = false, focused = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final foreground = RaftTitleBarRecipe(t).foreground;
    final label = raftText(context, switch (widget.name) {
      'minimize' => 'Minimize window',
      'maximize' => widget.maximized ? 'Restore window' : 'Maximize window',
      _ => 'Close window',
    });
    // Native caption geometry and hover treatment are platform constants;
    // colours always come from the active theme, including custom packs.
    final surface = foreground.withValues(
      alpha: pressed
          ? .25
          : hovered || focused
          ? .2
          : .1,
    );
    return RaftTooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        onTap: widget.onPressed,
        excludeSemantics: true,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.basic,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (value) => setState(() => focused = value),
          onShowHoverHighlight: (value) => setState(() => hovered = value),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            onTapDown: (_) => setState(() => pressed = true),
            onTapUp: (_) => setState(() => pressed = false),
            onTapCancel: () => setState(() => pressed = false),
            child: Center(
              child: Container(
                width: widget.windows ? 46 : 24,
                height: widget.windows ? 48 : 24,
                decoration: BoxDecoration(
                  shape: widget.windows ? BoxShape.rectangle : BoxShape.circle,
                  color: widget.windows && !hovered && !focused && !pressed
                      ? null
                      : surface,
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size.square(10),
                    painter: _CaptionGlyph(
                      widget.name,
                      widget.maximized,
                      foreground.withValues(alpha: widget.active ? 1 : .55),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptionGlyph extends CustomPainter {
  const _CaptionGlyph(this.name, this.maximized, this.color);
  final String name;
  final bool maximized;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1; // ds-allow: native caption glyph stroke, not a themed component border.
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    if (name == 'minimize') {
      canvas.drawLine(
        Offset(1, size.height / 2),
        Offset(size.width - 1, size.height / 2),
        p,
      );
    } else if (name == 'close') {
      canvas.drawLine(rect.topLeft, rect.bottomRight, p);
      canvas.drawLine(rect.topRight, rect.bottomLeft, p);
    } else if (maximized) {
      canvas.drawPath(
        Path()
          ..moveTo(3, 1)
          ..lineTo(9, 1)
          ..lineTo(9, 7)
          ..lineTo(7, 7),
        p,
      );
      canvas.drawRect(const Rect.fromLTWH(1, 3, 6, 6), p);
    } else {
      canvas.drawRect(rect, p);
    }
  }

  @override
  bool shouldRepaint(_CaptionGlyph old) =>
      name != old.name || maximized != old.maximized || color != old.color;
}
