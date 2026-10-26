import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'desktop_windows_caption_surface.dart';

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
        textDirection: TextDirection.ltr,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final name in names)
            // ds-allow: native caption hit regions match the platform runner's 48px row.
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

class _CaptionButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final foreground = RaftTitleBarRecipe(RaftTokens.of(context)).foreground;
    final label = raftText(context, switch (name) {
      'minimize' => 'Minimize window',
      'maximize' => maximized ? 'Restore window' : 'Maximize window',
      _ => 'Close window',
    });
    return RaftInteractive(
      onPressed: onPressed,
      semanticLabel: label,
      tooltip: label,
      builder: (context, state) {
        // Native caption geometry is fixed; all colours follow the theme.
        final highlighted = state.hovered || state.focusVisible;
        final surface = foreground.withValues(
          alpha: state.pressed
              ? .25
              : highlighted
              ? .2
              : .1,
        );
        final glyph = foreground.withValues(alpha: active ? 1 : .55);
        if (windows) {
          return DesktopWindowsCaptionSurface(
            name: name,
            maximized: maximized,
            foreground: foreground,
            glyph: glyph,
            highlighted: highlighted,
            pressed: state.pressed,
          );
        }
        return Align(
          alignment: Alignment.centerRight,
          // Electron's Linux targets have a 36px visual allocation and a 1px
          // leading gap. Keep the 37px hit region while snapping its circle
          // and one-pixel symbols to the same physical grid at 1x.
          // ds-allow: native caption visual allocation inside its 37px hit region.
          child: SizedBox(
            width: 36, // ds-allow: measured native caption visual allocation.
            child: Center(
              child: Container(
                // ds-allow: 24px Linux native caption circle measured from Desktop 1.21.33.
                width: 24,
                // ds-allow: 24px Linux native caption circle measured from Desktop 1.21.33.
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: surface,
                ),
                child: Center(
                  child: CustomPaint(
                    // ds-allow: native caption glyph bounds are independent of component theme metrics.
                    size: const Size.square(10),
                    painter: _CaptionGlyph(name, maximized, glyph),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    final rect = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    if (name == 'minimize') {
      canvas.drawLine(
        Offset(1, size.height / 2 + .5),
        Offset(size.width - 1, size.height / 2 + .5),
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
