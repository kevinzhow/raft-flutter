// Web MermaidDiagram fullscreen (components/mermaid/MermaidDiagram.tsx +
// mermaid.css `.r-mermaid-fullscreen`): a raft-ui Lightbox with only a close
// control over a stage that shows the whole diagram contain-fitted (it may
// magnify to the box) and zooms / pans freely.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart' show RaftInteractive;
import 'diagram_theme.dart';
import 'localization.dart';
import 'theme.dart';
import 'tooltip.dart';
import 'icons.dart';

Color _hex(String? value, Color fallback) {
  final v = value?.replaceFirst('#', '');
  if (v == null || v.length != 6) return fallback;
  final n = int.tryParse(v, radix: 16);
  return n == null ? fallback : Color(0xFF000000 | n);
}

/// The diagram document's background (the sandboxed frame fills the stage).
Color raftMermaidBackground(bool dark) => _hex(
  (dark ? DiagramPrimitive.dark : DiagramPrimitive.light)['background'],
  dark ? const Color(0xFF0A0C10) : Colors.white,
);

class RaftMermaidFullscreen extends StatefulWidget {
  const RaftMermaidFullscreen({
    super.key,
    required this.diagram,
    required this.onClose,
  });

  /// The diagram at its natural size.
  final Widget diagram;
  final VoidCallback onClose;

  @override
  State<RaftMermaidFullscreen> createState() => _RaftMermaidFullscreenState();
}

class _RaftMermaidFullscreenState extends State<RaftMermaidFullscreen> {
  final transform = TransformationController();
  // `useImageZoom` `minScale` (MERMAID_MIN_SCALE) and a generous maximum.
  static const minScale = .05, maxScale = 8.0;

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  /// Double click: zoom in around the point, or reset when already zoomed.
  void doubleTap(TapDownDetails details) {
    final scale = transform.value.getMaxScaleOnAxis();
    if (scale > 1.01) {
      transform.value = Matrix4.identity();
      return;
    }
    final p = details.localPosition;
    // Zoom 2x keeping the pressed point under the pointer.
    transform.value = Matrix4.identity()
      ..translateByDouble(p.dx, p.dy, 0, 1)
      ..scaleByDouble(2, 2, 1, 1)
      ..translateByDouble(-p.dx, -p.dy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final size = MediaQuery.sizeOf(context);
    // `.r-mermaid-fullscreen { padding: .75rem } @md { 1.5rem }`
    final pad = size.width >= 768 ? 24.0 : 12.0;
    final inset = MediaQuery.paddingOf(context);
    final background = raftMermaidBackground(t.dark);
    final label = raftText(context, 'Close Fullscreen');
    final close = _RoundClose(label: label, onPressed: widget.onClose);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        autofocus: true,
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          label: raftText(context, 'Mermaid diagram'),
          child: Stack(
            key: const Key('mermaid-fullscreen'),
            children: [
              // Backdrop: Brutal `layer-backdrop`, Elegant black/72 + blur(2px).
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: const ColoredBox(color: Color(0xB8000000)),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    pad + inset.left,
                    pad + inset.top,
                    pad + inset.right,
                    pad + inset.bottom,
                  ),
                  child: ColoredBox(
                    color: background,
                    child: GestureDetector(
                      key: const Key('mermaid-pan-zoom-viewport'),
                      behavior: HitTestBehavior.opaque,
                      onDoubleTapDown: doubleTap,
                      onDoubleTap: () {},
                      child: InteractiveViewer(
                        transformationController: transform,
                        minScale: minScale,
                        maxScale: maxScale,
                        clipBehavior: Clip.hardEdge,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
                        child: SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: widget.diagram,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // `[data-lightbox-close]`: absolute top/right 16 (+ safe area).
              Positioned(
                top: 16 + inset.top,
                right: 16 + inset.right,
                child: close,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Elegant `LightboxClose`: a 28px round control (`rounded-full p-1.5`) with a
/// 14px X.
class _RoundClose extends StatelessWidget {
  const _RoundClose({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftTooltip(
      message: label,
      excludeFromSemantics: true,
      child: RaftInteractive(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, state) => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.dark
                ? t.colors['fill-strong']
                : state.hovered
                ? t.colors['fill-muted']
                : t.panel,
            boxShadow: t.dark ? null : t.themeShadows.sm.outer,
          ),
          child: SizedBox.square(
            dimension: 28,
            child: Center(
              child: RaftIcon(
                RaftGlyph.x,
                size: 14,
                color: t.dark ? t.strong : t.colors['foreground-muted'],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
