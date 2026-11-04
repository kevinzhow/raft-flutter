import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'attachment_comment_scope.dart';
import 'feedback_inbox.dart' show RaftDashedBorderPainter;
import 'html_region_geometry.dart';
import 'interaction.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// Web HtmlPreviewBody's parent-owned capture and flash layer. Native document
/// evaluation stays behind [controller]; the SDK never executes document code.
class RaftHtmlRegionCommentSurface extends StatefulWidget {
  const RaftHtmlRegionCommentSurface({
    super.key,
    required this.controller,
    required this.enabled,
    required this.child,
  });
  final RaftHtmlRegionController? controller;
  final bool enabled;
  final Widget child;
  @override
  State<RaftHtmlRegionCommentSurface> createState() => _HtmlRegionState();
}

class _HtmlRegionState extends State<RaftHtmlRegionCommentSurface>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  RaftAttachmentCommentState? session;
  RaftHtmlGeometry? geometry;
  RaftHtmlRegion? flashing;
  Rect? drag;
  Offset? start;
  Size host = Size.zero;
  int binding = 0, captureRevision = 0, jumpRevision = 0, geometryRevision = 0;
  bool foreground = true, measuring = false;
  Duration sampledAt = Duration.zero;
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..addListener(tick);
  bool get current =>
      mounted &&
      foreground &&
      widget.enabled &&
      widget.controller?.active == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = RaftAttachmentCommentScope.maybeOf(context);
    if (!identical(next, session)) {
      detach();
      session = next;
    }
    bind();
    if (session?.commentMode != true) {
      start = null;
      drag = null;
      captureRevision++;
    }
  }

  @override
  void didUpdateWidget(RaftHtmlRegionCommentSurface old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller || old.enabled != widget.enabled) {
      retire();
      geometry = null;
    }
    bind();
  }

  void bind() {
    if (widget.enabled && widget.controller != null) {
      session?.jumpHandler = startJump;
      session?.asyncJumpHandler = jump;
      if (geometry == null && !measuring) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (current && geometry == null) unawaited(measure());
        });
      }
    } else {
      detach();
    }
  }

  void detach() {
    if (session?.jumpHandler == startJump) session?.jumpHandler = null;
    if (session?.asyncJumpHandler == jump) session?.asyncJumpHandler = null;
    retire();
  }

  void retire() {
    binding++;
    captureRevision++;
    jumpRevision++;
    geometryRevision++;
    start = null;
    drag = null;
    flashing = null;
    animation.stop();
    if (session?.pendingAnchor?['type'] == 'html-region')
      session?.clearAnchor(afterFrame: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (!foreground) {
      retire();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    detach();
    WidgetsBinding.instance.removeObserver(this);
    animation.dispose();
    super.dispose();
  }

  bool valid(int ticket, RaftHtmlRegionController owner) =>
      current && ticket == binding && identical(widget.controller, owner);

  Future<void> capture(Rect rect) async {
    final owner = widget.controller;
    if (!current || owner == null || session?.commentMode != true) return;
    final ticket = binding, serial = ++captureRevision, size = host;
    geometryRevision++;
    final result = await owner.capture(rect, size);
    if (!valid(ticket, owner) ||
        serial != captureRevision ||
        session?.commentMode != true ||
        size != host)
      return;
    if (result != null) {
      setState(() => geometry = result.geometry);
      session?.pushAnchor(result.region.anchor);
    }
  }

  bool startJump(RaftCommentAnchor anchor) {
    if (!current || RaftHtmlRegion.fromAnchor(anchor) == null) return false;
    unawaited(jump(anchor));
    return true;
  }

  Future<bool> jump(RaftCommentAnchor anchor) async {
    final owner = widget.controller, region = RaftHtmlRegion.fromAnchor(anchor);
    if (!current || owner == null || region == null) return false;
    final ticket = binding, serial = ++jumpRevision, size = host;
    geometryRevision++;
    final result = await owner.jump(region, size);
    if (!valid(ticket, owner) ||
        serial != jumpRevision ||
        size != host ||
        result == null ||
        !TickerMode.valuesOf(context).enabled)
      return false;
    setState(() {
      geometry = result.geometry;
      flashing = result.region;
    });
    sampledAt = Duration.zero;
    unawaited(
      animation.forward(from: 0).whenComplete(() {
        if (valid(ticket, owner) && serial == jumpRevision)
          setState(() => flashing = null);
      }),
    );
    return true;
  }

  void tick() {
    if (!mounted) return;
    setState(() {});
    final elapsed = animation.lastElapsedDuration ?? Duration.zero;
    if (flashing != null &&
        current &&
        elapsed - sampledAt >= const Duration(milliseconds: 100)) {
      sampledAt = elapsed;
      unawaited(measure());
    }
  }

  Future<void> measure() async {
    final owner = widget.controller;
    if (!current ||
        owner == null ||
        measuring ||
        !TickerMode.valuesOf(context).enabled)
      return;
    final ticket = binding, revision = geometryRevision, size = host;
    measuring = true;
    try {
      final value = await owner.measure(size);
      if (valid(ticket, owner) &&
          revision == geometryRevision &&
          size == host &&
          value != null)
        setState(() => geometry = value);
    } finally {
      measuring = false;
    }
  }

  Future<void> scroll(PointerScrollEvent event) async {
    final owner = widget.controller;
    if (!current || owner == null) return;
    final ticket = binding, revision = ++geometryRevision;
    final value = await owner.scrollBy(event.scrollDelta, host);
    if (valid(ticket, owner) && revision == geometryRevision && value != null)
      setState(() => geometry = value);
  }

  void down(PointerDownEvent event) {
    if (!current || session?.commentMode != true) return;
    captureRevision++;
    setState(() {
      start = event.localPosition;
      drag = Rect.fromPoints(start!, start!);
    });
  }

  void up(PointerUpEvent event) {
    final first = start;
    setState(() {
      start = null;
      drag = null;
    });
    if (first != null)
      unawaited(capture(Rect.fromPoints(first, event.localPosition)));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (host != size) {
        host = size;
        captureRevision++;
        geometryRevision++;
        if (flashing != null)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(measure());
          });
      }
      final pointer = RaftInteraction.of(context).pointer;
      final canCapture =
          widget.enabled && session?.commentMode == true && pointer;
      final g = geometry, region = flashing;
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (g != null && region != null)
              IgnorePointer(
                child: RaftHtmlRegionMarker(
                  rect: g.local(region, host, minimum: RaftScale.space(3.5)),
                  progress: animation.value * 1800 / 1600,
                ),
              ),
            if (canCapture)
              MouseRegion(
                cursor: SystemMouseCursors.precise,
                child: Listener(
                  key: const ValueKey('html-region-capture'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: down,
                  onPointerMove: (event) {
                    if (start != null)
                      setState(
                        () =>
                            drag = Rect.fromPoints(start!, event.localPosition),
                      );
                  },
                  onPointerUp: up,
                  onPointerCancel: (_) => setState(() {
                    start = null;
                    drag = null;
                    captureRevision++;
                  }),
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) unawaited(scroll(event));
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (drag != null)
                        IgnorePointer(
                          child: RaftHtmlRegionMarker(rect: drag!, drag: true),
                        ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: RaftScale.space(3)),
                          child: RaftHtmlRegionHint(
                            available: current && geometry != null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// The Web's capture instruction; shared recipe tokens, no fixed text height.
class RaftHtmlRegionHint extends StatelessWidget {
  const RaftHtmlRegionHint({super.key, required this.available});
  final bool available;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return IgnorePointer(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: RaftScale.space(2)),
        padding: EdgeInsets.symmetric(
          horizontal: RaftScale.space(2),
          vertical: RaftScale.space(1),
        ),
        decoration: BoxDecoration(
          color: t.colors['layer-hud'],
          borderRadius: BorderRadius.circular(
            t.size('radius.chip', fallback: RaftRadius.chip),
          ),
          boxShadow: t.themeShadows.lg.outer,
        ),
        child: RaftCssText(
          raftText(
            context,
            available
                ? 'Click or drag to comment on a region'
                : "Can't locate inside this page — comments will be unanchored",
          ),
          style: t.scale(
            t.typeSlot('caption'),
            color: t.colors['foreground-on-hud'],
          ),
        ),
      ),
    );
  }
}

/// Parent-painted content geometry. A clip limits hostile coordinates to the
/// document pane; HTML never draws outside its native view or this surface.
class RaftHtmlRegionMarker extends StatelessWidget {
  const RaftHtmlRegionMarker({
    super.key,
    required this.rect,
    this.drag = false,
    this.progress = 0,
  });
  final Rect rect;
  final bool drag;
  final double progress;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final strength = progress <= .35
        ? 1.0
        : progress >= 1
        ? 0.0
        : 1 - Curves.easeOut.transform((progress - .35) / .65);
    final base = t.ui[drag ? 'brand-soft' : 'info-soft'];
    return CustomPaint(
      key: ValueKey(drag ? 'html-region-drag' : 'html-region-flash'),
      painter: _RegionPainter(
        rect,
        base.withValues(alpha: base.a * (drag ? .5 : strength)),
        t.ui['line-seam'],
        RaftScale.space(.25),
        drag,
        RaftScale.space(.5),
      ),
    );
  }
}

class _RegionPainter extends CustomPainter {
  const _RegionPainter(
    this.rect,
    this.fill,
    this.border,
    this.width,
    this.dashed,
    this.radius,
  );
  final Rect rect;
  final Color fill, border;
  final double width, radius;
  final bool dashed;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (rect.overlaps(Offset.zero & size)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          dashed ? Radius.zero : Radius.circular(radius),
        ),
        Paint()..color = fill,
      );
      if (dashed) {
        canvas.save();
        canvas.translate(rect.left, rect.top);
        RaftDashedBorderPainter(border, width).paint(canvas, rect.size);
        canvas.restore();
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.deflate(width / 2),
            Radius.circular(radius),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..color = border,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RegionPainter old) =>
      rect != old.rect ||
      fill != old.fill ||
      border != old.border ||
      width != old.width ||
      dashed != old.dashed ||
      radius != old.radius;
}
