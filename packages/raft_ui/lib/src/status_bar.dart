import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

// STATUS BAR STANDARD (docs/status-bar.md). One rule for every layout:
//
//   For each vertical column under the status bar, the band over that column
//   is the colour of the column's topmost visible surface (its page header if
//   it has one flush with the top, else the column background), and the
//   column's vertical dividers continue up through the band. Icon brightness
//   follows the resolved colour. A modal scrim dims the band too.
//
// A phone is one column; a foldable / tablet / desktop window is two to five
// (rail, navigation, content, thread, profile). There is no phone path and
// wide path: every header and column surface wraps itself in a
// [RaftStatusBarSource] and the host's strip resolves them at paint time. A
// transparent header publishes nothing of its own; the surface under it
// (conversation surface, panel body, sidebar frame, page body) publishes the
// colour. Do not paint the status bar from a page and do not branch on width.
// `statusbar_standard_test.dart` fails when a route breaks the rule.

/// Single source of truth for the status bar colour on every layout.
///
/// Web draws the header surface up under the safe-area top. Native hosts do the
/// same by painting a strip of [MediaQuery.paddingOf] height; instead of every
/// page guessing the header colour, each top header wraps itself in a
/// [RaftStatusBarSource] with its real background and the host's
/// [RaftStatusBarStrip] picks, at paint time, the visible source that is
/// directly under the strip. When no header is flush with the strip the
/// host's fallback (the page background beneath it) is used.
class RaftStatusBarRegistry {
  final Set<_RenderStatusBarSource> _sources = {};
  final Set<_RenderStatusBarStrip> _strips = {};

  void _changed() {
    for (final strip in _strips) {
      strip.markNeedsPaint();
    }
  }
}

/// Owns a [RaftStatusBarRegistry] for the headers below it.
class RaftStatusBarScope extends StatefulWidget {
  const RaftStatusBarScope({super.key, required this.child});

  final Widget child;

  static RaftStatusBarRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StatusBarScope>()?.registry;

  @override
  State<RaftStatusBarScope> createState() => _RaftStatusBarScopeState();
}

class _RaftStatusBarScopeState extends State<RaftStatusBarScope> {
  final registry = RaftStatusBarRegistry();

  @override
  Widget build(BuildContext context) =>
      _StatusBarScope(registry: registry, child: widget.child);
}

class _StatusBarScope extends InheritedWidget {
  const _StatusBarScope({required this.registry, required super.child});

  final RaftStatusBarRegistry registry;

  @override
  bool updateShouldNotify(_StatusBarScope old) => old.registry != registry;
}

/// Hosts the status bar strip above [child] on phones (Android / iOS, top
/// inset > 0) and owns the registry the headers below publish to.
///
/// Nested hosts collapse into the outermost one, so a self-hosting page
/// (for example `RaftAuthShell`) can sit inside an app host without painting a
/// second strip over the first. [expand] forces [child] to fill the host, like
/// a `Scaffold` body; otherwise the host shrink-wraps its child.
class RaftStatusBarHost extends StatelessWidget {
  const RaftStatusBarHost({
    super.key,
    required this.fallback,
    required this.child,
    this.expand = false,
    this.styleFor = RaftStatusBarStrip.defaultStyleFor,
  });

  /// A host for a modal that sits above the page's own host (a dialog route,
  /// an overlay over the workspace): its strip is transparent, so the page's
  /// band (dimmed by the modal's scrim) shows through wherever no header of
  /// the modal is flush with the top.
  const RaftStatusBarHost.overlay({
    super.key,
    required this.child,
    this.expand = true,
    this.styleFor = RaftStatusBarStrip.defaultStyleFor,
  }) : fallback = Colors.transparent;

  final Color fallback;
  final Widget child;
  final bool expand;
  final SystemUiOverlayStyle Function(Color color) styleFor;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (!_supported ||
        top <= 0 ||
        RaftStatusBarScope.maybeOf(context) != null) {
      return child;
    }
    return RaftStatusBarScope(
      child: Stack(
        fit: expand ? StackFit.expand : StackFit.passthrough,
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top,
            child: RaftStatusBarStrip(fallback: fallback, styleFor: styleFor),
          ),
        ],
      ),
    );
  }
}

/// A [DialogRoute] for a full-bleed modal (a lightbox or preview whose header
/// runs edge to edge): the route is above the page's [RaftStatusBarHost], so it
/// hosts its own strip. The strip is transparent, so the barrier still dims
/// the page's band, and a header flush with the top publishes over it like
/// anywhere else (`docs/status-bar.md`). The content keeps the top safe area
/// only: the bottom system inset reaches the content, which paints its own
/// background to the screen bottom (a surface above the system bar must not
/// leave a strip of the dimmed page showing under it) and pads what must stay
/// reachable by `raftBottomInset`.
class RaftFullBleedDialogRoute<T> extends DialogRoute<T> {
  RaftFullBleedDialogRoute({
    required super.context,
    required WidgetBuilder builder,
    super.settings,
  }) : super(
         useSafeArea: false,
         builder: (context) => RaftStatusBarHost.overlay(
           child: SafeArea(bottom: false, child: builder(context)),
         ),
       );
}

/// Publishes [color] as the status bar colour while this widget is a visible
/// top header (flush with the host's strip). Wrap the widget that actually
/// paints the header background; it adds no layout or paint of its own.
///
/// Wide layouts publish whole columns (rail, sidebar, thread panel) the same
/// way, so each column's background continues up under the status bar. A
/// column's vertical divider is passed as [border] (only its left and right
/// sides are read) so the strip continues it to the top edge too.
class RaftStatusBarSource extends SingleChildRenderObjectWidget {
  const RaftStatusBarSource({
    super.key,
    required this.color,
    this.border,
    this.overlay = false,
    required Widget super.child,
  });

  final Color color;

  /// A modal scrim: composited over every column and header (whatever their
  /// depth), so a dimmed window dims the status bar band like the rest.
  final bool overlay;

  /// Vertical dividers drawn inside this widget's box (left / right sides),
  /// composited over [color]; pass an opaque colour for a divider whose
  /// backdrop is not [color].
  final Border? border;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderStatusBarSource(
        color,
        border,
        overlay,
        RaftStatusBarScope.maybeOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderStatusBarSource renderObject,
  ) => renderObject
    ..color = color
    ..border = border
    ..overlay = overlay
    ..registry = RaftStatusBarScope.maybeOf(context);
}

class _RenderStatusBarSource extends RenderProxyBox {
  _RenderStatusBarSource(
    this._color,
    this._border,
    this._overlay,
    this._registry,
  );

  Color _color;
  Border? _border;
  bool _overlay;
  RaftStatusBarRegistry? _registry;

  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    _registry?._changed();
  }

  Border? get border => _border;
  set border(Border? value) {
    if (value == _border) return;
    _border = value;
    _registry?._changed();
  }

  bool get overlay => _overlay;
  set overlay(bool value) {
    if (value == _overlay) return;
    _overlay = value;
    _registry?._changed();
  }

  set registry(RaftStatusBarRegistry? value) {
    if (identical(value, _registry)) return;
    if (attached) _registry?._sources.remove(this);
    _registry = value;
    if (attached) _registry?._sources.add(this);
    _registry?._changed();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry?._sources.add(this);
    _registry?._changed();
  }

  @override
  void detach() {
    _registry?._sources.remove(this);
    _registry?._changed();
    super.detach();
  }

  @override
  void performLayout() {
    final before = hasSize ? size : null;
    super.performLayout();
    if (before != size) _registry?._changed();
  }
}

/// Paints the status bar region with the colour of the header under it and
/// annotates it with an icon brightness that contrasts with that colour.
/// Sits above the page in a [Stack]; it must be a descendant of the
/// [RaftStatusBarScope] its headers register with.
class RaftStatusBarStrip extends LeafRenderObjectWidget {
  const RaftStatusBarStrip({
    super.key,
    required this.fallback,
    this.styleFor = defaultStyleFor,
  });

  /// Colour of the page directly under the strip when no header is flush.
  final Color fallback;

  /// Maps the resolved strip colour to the system overlay style.
  final SystemUiOverlayStyle Function(Color color) styleFor;

  static SystemUiOverlayStyle defaultStyleFor(Color color) {
    final dark = color.computeLuminance() < .5;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemStatusBarContrastEnforced: false,
    );
  }

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderStatusBarStrip(
        fallback,
        styleFor,
        RaftStatusBarScope.maybeOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderStatusBarStrip renderObject,
  ) => renderObject
    ..update(fallback, styleFor)
    ..registry = RaftStatusBarScope.maybeOf(context);
}

class _RenderStatusBarStrip extends RenderBox {
  _RenderStatusBarStrip(this._fallback, this._styleFor, this._registry);

  Color _fallback;
  SystemUiOverlayStyle Function(Color) _styleFor;
  RaftStatusBarRegistry? _registry;

  void update(Color fallback, SystemUiOverlayStyle Function(Color) styleFor) {
    if (fallback == _fallback && styleFor == _styleFor) return;
    _fallback = fallback;
    _styleFor = styleFor;
    markNeedsPaint();
  }

  set registry(RaftStatusBarRegistry? value) {
    if (identical(value, _registry)) return;
    if (attached) _registry?._strips.remove(this);
    _registry = value;
    if (attached) _registry?._strips.add(this);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry?._strips.add(this);
  }

  @override
  void detach() {
    _registry?._strips.remove(this);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.biggest.isFinite ? constraints.biggest : constraints.smallest;

  @override
  bool hitTestSelf(Offset position) => false;

  static bool _hidden(RenderObject box) {
    for (RenderObject? p = box.parent; p != null; p = p.parent) {
      if (p is RenderOffstage && p.offstage) return true;
    }
    return false;
  }

  /// Visible sources whose box is flush under the strip (starts at or above
  /// its bottom edge and extends below it), with their horizontal extent,
  /// outermost first so inner headers paint over outer ones.
  List<({_RenderStatusBarSource source, double left, double right})> _flush() {
    final found =
        <({_RenderStatusBarSource source, double left, double right})>[];
    for (final source in _registry?._sources ?? const {}) {
      if (!source.attached || !source.hasSize || _hidden(source)) continue;
      final Offset topLeft;
      try {
        topLeft = source.localToGlobal(Offset.zero, ancestor: this);
      } catch (_) {
        continue;
      }
      final bottom = topLeft.dy + source.size.height;
      final left = topLeft.dx, right = topLeft.dx + source.size.width;
      if (topLeft.dy > size.height + 1 ||
          bottom <= size.height ||
          right <= 0 ||
          left >= size.width) {
        continue;
      }
      found.add((source: source, left: left, right: right));
    }
    // Columns and headers in paint order (a parent before its descendants, an
    // earlier sibling before a later one), so a column an opaque later one
    // covers (a profile panel folded over the conversation, whose header stays
    // mounted and flush with the top) loses to the surface that is really on
    // top; scrims last, over all of them. Render depth is not paint order: a
    // deeper header of an earlier sibling would wrongly win.
    found.sort((a, b) {
      if (a.source.overlay != b.source.overlay) {
        return a.source.overlay ? 1 : -1;
      }
      return _paintOrder(a.source, b.source);
    });
    return found;
  }

  /// Negative when [a] paints before [b]: the order of their ancestor chains,
  /// compared at the first ancestor whose children differ (child order is
  /// paint order for stacks, rows, and single-child wrappers alike).
  static int _paintOrder(RenderObject a, RenderObject b) {
    if (identical(a, b)) return 0;
    List<RenderObject> chain(RenderObject node) {
      final out = <RenderObject>[];
      for (RenderObject? n = node; n != null; n = n.parent) {
        out.add(n);
      }
      return out.reversed.toList();
    }

    final ca = chain(a), cb = chain(b);
    var i = 0;
    while (i < ca.length && i < cb.length && identical(ca[i], cb[i])) {
      i++;
    }
    // One contains the other: the ancestor paints first.
    if (i == ca.length) return -1;
    if (i == cb.length) return 1;
    var indexA = -1, indexB = -1, index = 0;
    ca[i - 1].visitChildren((child) {
      if (identical(child, ca[i])) indexA = index;
      if (identical(child, cb[i])) indexB = index;
      index++;
    });
    return indexA.compareTo(indexB);
  }

  /// Colour at the strip's centre (the pixel the system samples for icon
  /// contrast): the fallback with every flush source that contains the centre
  /// composited over it, outermost first, and whether one was found.
  ({Color color, bool fromSource}) resolution() {
    var color = _fallback;
    var found = false;
    for (final f in _flush()) {
      if (f.left <= size.width / 2 && f.right >= size.width / 2) {
        color = Color.alphaBlend(f.source.color, color);
        found = true;
      }
    }
    return (color: color, fromSource: found);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    final canvas = context.canvas;
    canvas.drawRect(offset & size, Paint()..color = _fallback);
    // Side-by-side columns (a public server's sidebar and thread column) each
    // draw their own header under the inset, so each paints its own extent.
    final flush = _flush();
    for (var i = 0; i < flush.length; i++) {
      final f = flush[i];
      // A source an opaque, later one fully covers (a header as wide as its
      // column) is invisible: skip it, so its antialiased edge pixels do not
      // composite under the header's.
      if (f.source.border == null &&
          flush
              .skip(i + 1)
              .any(
                (g) =>
                    g.source.color.a == 1 &&
                    !g.source.overlay &&
                    g.left <= f.left &&
                    g.right >= f.right,
              )) {
        continue;
      }
      final rect = Rect.fromLTRB(
        offset.dx + f.left.clamp(0, size.width),
        offset.dy,
        offset.dx + f.right.clamp(0, size.width),
        offset.dy + size.height,
      );
      // Composited over what the outer columns / the fallback already drew, so
      // a transparent header (its column paints the surface) keeps the column
      // colour instead of resetting it to the fallback.
      canvas.drawRect(rect, Paint()..color = f.source.color);
      // The column's vertical dividers continue up under the status bar.
      final border = f.source.border;
      if (border != null) {
        if (border.left.width > 0) {
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, border.left.width, rect.height),
            Paint()..color = border.left.color,
          );
        }
        if (border.right.width > 0) {
          canvas.drawRect(
            Rect.fromLTRB(
              rect.right - border.right.width,
              rect.top,
              rect.right,
              rect.bottom,
            ),
            Paint()..color = border.right.color,
          );
        }
      }
    }
    final resolved = resolution().color;
    // A translucent strip (a modal host: a transparent fallback with at most a
    // scrim or an overlay header on it) leaves the status bar icon style to
    // the page under it.
    if (resolved.a < 1) return;
    context.pushLayer(
      AnnotatedRegionLayer<SystemUiOverlayStyle>(
        _styleFor(resolved),
        size: size,
        offset: offset,
      ),
      (context, offset) {},
      offset,
    );
  }
}

/// Test hook: what a [RaftStatusBarStrip] currently resolves.
@visibleForTesting
({Color color, bool fromSource}) raftStatusBarResolution(RenderObject strip) =>
    (strip as _RenderStatusBarStrip).resolution();

/// Test hook: the colour a [RaftStatusBarStrip] currently resolves.
@visibleForTesting
Color raftStatusBarResolvedColor(RenderObject strip) =>
    raftStatusBarResolution(strip).color;
