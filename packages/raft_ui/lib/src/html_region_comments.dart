import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'attachment_comment_scope.dart';
import 'html_region_hint_raster.dart';
import 'html_region_marker.dart';
import 'html_region_native_binding.dart';
import 'html_region_native_types.dart';
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
  late final native = RaftHtmlNativeRegionBinding(nativeInput, () {
    captureRevision++;
    geometryRevision++;
    start = null;
    drag = null;
  });
  final paneKey = GlobalKey(), hintKey = GlobalKey();
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
    native.bind(widget.enabled ? widget.controller : null);
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
    native.invalidate();
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
    } else if (widget.controller is RaftHtmlNativeRegionController && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    detach();
    WidgetsBinding.instance.removeObserver(this);
    animation.dispose();
    native.dispose();
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

  Future<void> scroll(PointerScrollEvent event) => scrollAt(event.scrollDelta);

  Future<void> scrollAt(Offset delta) async {
    final owner = widget.controller;
    if (!current || owner == null) return;
    final ticket = binding, revision = ++geometryRevision;
    final value = await owner.scrollBy(delta, host);
    if (valid(ticket, owner) && revision == geometryRevision && value != null)
      setState(() => geometry = value);
  }

  void down(PointerDownEvent event) => downAt(event.localPosition);

  void downAt(Offset position) {
    if (!current || session?.commentMode != true) return;
    captureRevision++;
    setState(() {
      start = position;
      drag = Rect.fromPoints(start!, start!);
    });
  }

  void up(PointerUpEvent event) => upAt(event.localPosition);

  void upAt(Offset position) {
    final first = start;
    setState(() {
      start = null;
      drag = null;
    });
    if (first != null) unawaited(capture(Rect.fromPoints(first, position)));
  }

  void cancelDrag() => setState(() {
    start = null;
    drag = null;
    captureRevision++;
  });

  void nativeInput(RaftHtmlNativeRegionInput event) {
    if (!current ||
        session?.commentMode != true ||
        !RaftInteraction.of(context).pointer ||
        !TickerMode.valuesOf(context).enabled)
      return;
    final position = Offset(
      event.position.dx * host.width,
      event.position.dy * host.height,
    );
    switch (event.phase) {
      case RaftHtmlNativeRegionPhase.down:
        downAt(position);
      case RaftHtmlNativeRegionPhase.move:
        if (start != null)
          setState(() => drag = Rect.fromPoints(start!, position));
      case RaftHtmlNativeRegionPhase.up:
        upAt(position);
      case RaftHtmlNativeRegionPhase.cancel:
        cancelDrag();
      case RaftHtmlNativeRegionPhase.scroll:
        unawaited(
          scrollAt(
            Offset(event.delta.dx * host.width, event.delta.dy * host.height),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (host != size) {
        if (widget.controller is RaftHtmlNativeRegionController) {
          start = null;
          drag = null;
          native.invalidate();
        }
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
      final nativeLayer = widget.controller is RaftHtmlNativeRegionController;
      final usableHost =
          host.width > 0 &&
          host.height > 0 &&
          host.width.isFinite &&
          host.height.isFinite;
      if (nativeLayer) {
        native.update(
          viewport: host,
          captureEnabled:
              canCapture &&
              current &&
              usableHost &&
              TickerMode.valuesOf(context).enabled,
          markers: [
            if (usableHost && g != null && region != null)
              RaftHtmlRegionMarkerRecipe.resolve(
                context,
                g.local(region, host, minimum: RaftScale.space(3.5)),
                progress: animation.value * 1800 / 1600,
              ).normalized(host),
            if (usableHost && canCapture && drag != null)
              RaftHtmlRegionMarkerRecipe.resolve(
                context,
                drag!,
                drag: true,
              ).normalized(host),
          ],
          paneKey: paneKey,
          hintKey: hintKey,
          hintSignature: (
            Theme.of(context),
            Localizations.maybeLocaleOf(context),
            MediaQuery.textScalerOf(context),
            View.of(context).devicePixelRatio,
            Directionality.of(context),
            host,
            current,
            geometry != null,
          ),
        );
      }
      return ClipRect(
        key: paneKey,
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
                  onPointerDown: nativeLayer ? null : down,
                  onPointerMove: nativeLayer
                      ? null
                      : (event) {
                          if (start != null)
                            setState(
                              () => drag = Rect.fromPoints(
                                start!,
                                event.localPosition,
                              ),
                            );
                        },
                  onPointerUp: nativeLayer ? null : up,
                  onPointerCancel: nativeLayer ? null : (_) => cancelDrag(),
                  onPointerSignal: nativeLayer
                      ? null
                      : (event) {
                          if (event is PointerScrollEvent)
                            unawaited(scroll(event));
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
                          child: nativeLayer
                              ? RaftHtmlHintRasterBoundary(
                                  key: hintKey,
                                  shadows: RaftTokens.of(context)
                                      .themeShadows
                                      .lg
                                      .outer,
                                  child: RaftHtmlRegionHint(
                                    available: current && geometry != null,
                                  ),
                                )
                              : RaftHtmlRegionHint(
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
    return CustomPaint(
      key: ValueKey(drag ? 'html-region-drag' : 'html-region-flash'),
      painter: RaftHtmlRegionMarkerPainter(
        RaftHtmlRegionMarkerRecipe.resolve(
          context,
          rect,
          drag: drag,
          progress: progress,
        ),
      ),
    );
  }
}
