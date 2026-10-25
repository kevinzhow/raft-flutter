// Records what a render tree paints, and which render object / widget paints it.
//
// Test-only support for the extreme-theme check (tool/parity-ext/extreme_diff.py). The tree is painted a second
// time into a recording canvas (flutter_test's TestRecordingPaintingContext, which also walks repaint boundaries),
// and every drawing call is stored with the render object that was painting, its bounds in the capture root's
// logical pixels, and the paint's colour / style / stroke width / corner radii. A render object is tied back to
// the widget that created it through `debugCreator`; with `--track-widget-creation` (the `flutter test` default)
// each widget knows the `file:line` of its constructor call, so a hard-coded value can be reported where it is
// written. Nothing here changes what the harness paints.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart' show RaftRecipeBox;

import 'recipe_context.dart';

/// Records the render subtree under [root] (its paint offset is zero).
///
/// Returns the JSON-ready document: `nodes` (the widget tree above the painters: type, creation file / line,
/// parent), `objects` (render objects that painted: type, path, widget node, text facts) and `ops`.
Map<String, Object?> recordPaintOps(RenderObject root) {
  final recorder = _OpRecorder();
  final canvas = _OpCanvas(recorder);
  final context = _OpContext(canvas, recorder);
  try {
    context.paintChild(root, Offset.zero);
  } catch (error, stack) {
    recorder.error =
        '$error\n${stack.toString().split('\n').take(6).join('\n')}';
  } finally {
    context.dispose();
  }
  return recorder.toJson();
}

class _Node {
  _Node(this.id, this.type, this.file, this.line, this.parent, [this.extra]);
  final Map<String, Object?>? extra;
  final int id;
  final String type;
  final String? file;
  final int? line;
  final int? parent;
}

class _Object {
  _Object(this.id, this.type, this.path, this.element, this.rect);
  final int id;
  final String type;
  final String path;
  final Element? element;
  final Rect? rect;
  bool used = false;
  final Map<String, Object?> extra = {};
}

class _OpRecorder {
  final nodes = <_Node>[];
  final _nodeOfElement = <Element, int>{};
  final objects = <_Object>[];
  final ops = <Map<String, Object?>>[];
  final unsupportedLayers = <String, int>{};
  String? error;

  _Object? current;

  int? nodeOf(Element? element) {
    if (element == null || element.debugIsDefunct) return null;
    final known = _nodeOfElement[element];
    if (known != null) return known;
    Element? parent;
    element.visitAncestorElements((a) {
      parent = a;
      return false;
    });
    final parentId = nodeOf(parent);
    final location = _locationOf(element.widget);
    final id = nodes.length;
    nodes.add(
      _Node(
        id,
        element.widget.runtimeType.toString(),
        location?.$1,
        location?.$2,
        parentId,
        element.widget is RaftRecipeBox
            ? recipeContextOf(element.widget as RaftRecipeBox)
            : null,
      ),
    );
    _nodeOfElement[element] = id;
    return id;
  }

  (String, int)? _locationOf(Widget widget) {
    try {
      final json = widget.toDiagnosticsNode().toJsonMap(
        InspectorSerializationDelegate(
          service: WidgetInspectorService.instance,
          subtreeDepth: 0,
        ),
      );
      final loc = json['creationLocation'];
      if (loc is Map && loc['file'] is String && loc['line'] is int) {
        return (loc['file'] as String, loc['line'] as int);
      }
    } catch (_) {}
    return null;
  }

  final _pathStack = <String>[];
  final _childCounter = <int>[0];

  _Object enter(RenderObject child, Offset offset, Matrix4 matrix) {
    final index = _childCounter.last++;
    _pathStack.add('${child.runtimeType}[$index]');
    _childCounter.add(0);
    final creator = child.debugCreator;
    final element = creator is DebugCreator ? creator.element : null;
    // The box of the render object in capture-root pixels (the canvas transform applied).
    final rect = child is RenderBox && child.hasSize
        ? MatrixUtils.transformRect(matrix, offset & child.size)
        : null;
    final object = _Object(
      objects.length,
      child.runtimeType.toString(),
      _pathStack.join('/'),
      element,
      rect,
    );
    _describe(child, object);
    objects.add(object);
    return object;
  }

  void leave() {
    _pathStack.removeLast();
    _childCounter.removeLast();
  }

  void _describe(RenderObject child, _Object object) {
    InlineSpan? span;
    if (child is RenderParagraph) span = child.text;
    if (child is RenderEditable) span = child.text;
    if (span == null) return;
    TextStyle? style;
    String? text;
    void visit(InlineSpan s, TextStyle inherited) {
      final own = inherited.merge(s.style);
      if (s is TextSpan &&
          text == null &&
          (s.text?.trim().isNotEmpty ?? false)) {
        text = s.text;
        style = own;
      }
      if (s is TextSpan) {
        for (final c in s.children ?? const <InlineSpan>[]) {
          visit(c, own);
        }
      }
    }

    visit(span, const TextStyle());
    final plain = span.toPlainText(includeSemanticsLabels: false);
    object.extra['txt'] = plain.length > 60 ? plain.substring(0, 60) : plain;
    final s = style ?? (span is TextSpan ? span.style : null);
    if (s != null) {
      object.extra['fs'] = s.fontSize;
      object.extra['fam'] = s.fontFamily;
      object.extra['fw'] = s.fontWeight?.value;
      object.extra['col'] = s.color?.toARGB32();
    }
  }

  void add(Map<String, Object?> op) {
    final object = current;
    if (object == null) return;
    object.used = true;
    op['ro'] = object.id;
    ops.add(op);
  }

  Map<String, Object?> toJson() {
    // Only the render objects that painted, and the widget chain above them, are written.
    final painted = [
      for (final o in objects)
        if (o.used) o,
    ];
    final nodeOfObject = {for (final o in painted) o.id: nodeOf(o.element)};
    final keep = <int>{};
    for (final id in nodeOfObject.values) {
      for (var n = id; n != null && keep.add(n); n = nodes[n].parent) {}
    }
    return _json(painted, nodeOfObject, keep);
  }

  Map<String, Object?> _json(
    List<_Object> painted,
    Map<int, int?> nodeOfObject,
    Set<int> keep,
  ) => {
    if (error != null) 'error': error,
    'unsupportedLayers': unsupportedLayers,
    'nodes': [
      for (final n in nodes)
        if (keep.contains(n.id))
          [n.id, n.type, n.file, n.line, n.parent, ?n.extra],
    ],
    'objects': [
      for (final o in painted)
        {
          'id': o.id,
          'type': o.type,
          'path': o.path,
          'node': nodeOfObject[o.id],
          if (o.rect != null) 'rect': _rect(o.rect!),
          ...o.extra,
        },
    ],
    'ops': ops,
  };
}

List<double> _rect(Rect r) => [
  _r2(r.left),
  _r2(r.top),
  _r2(r.right),
  _r2(r.bottom),
];

double _r2(double v) {
  if (v.isNaN) return 0;
  if (v.isInfinite) return v.isNegative ? -1e6 : 1e6;
  return (v * 100).roundToDouble() / 100;
}

class _OpContext extends TestRecordingPaintingContext {
  _OpContext(this._canvas, this._recorder) : super(_canvas);
  final _OpCanvas _canvas;
  final _OpRecorder _recorder;

  @override
  void paintChild(RenderObject child, Offset offset) {
    final previous = _recorder.current;
    _recorder.current = _recorder.enter(child, offset, _canvas._matrix);
    try {
      child.paint(this, offset);
    } finally {
      _recorder.leave();
      _recorder.current = previous;
    }
  }

  final _layers = <LayerHandle<Layer>>[];

  @override
  ColorFilterLayer pushColorFilter(
    Offset offset,
    ColorFilter colorFilter,
    PaintingContextCallback painter, {
    ColorFilterLayer? oldLayer,
  }) {
    // The filter changes colours, not geometry: paint the child as is.
    painter(this, offset);
    final layer = ColorFilterLayer();
    _layers.add(LayerHandle<Layer>(layer));
    return layer;
  }

  @override
  void dispose() {
    for (final handle in _layers) {
      handle.layer = null;
    }
    _layers.clear();
    super.dispose();
  }

  @override
  OpacityLayer pushOpacity(
    Offset offset,
    int alpha,
    PaintingContextCallback painter, {
    OpacityLayer? oldLayer,
  }) {
    _canvas.nextLayerAlpha = alpha / 255;
    return super.pushOpacity(offset, alpha, painter, oldLayer: oldLayer);
  }

  @override
  void pushLayer(
    Layer childLayer,
    PaintingContextCallback painter,
    Offset offset, {
    Rect? childPaintBounds,
  }) {
    if (childLayer is FollowerLayer) {
      // Popovers and menus follow an anchor: the compositor already placed
      // the layer, so apply the transform it computed.
      final m = childLayer.getLastTransform();
      if (m != null) {
        _canvas.save();
        _canvas.transform(m.storage);
        painter(this, offset);
        _canvas.restore();
        return;
      }
    }
    final kind = childLayer.runtimeType.toString();
    if (kind != 'LeaderLayer' &&
        !kind.startsWith('AnnotatedRegionLayer') &&
        kind != 'BackdropFilterLayer' &&
        kind != 'ShaderMaskLayer' &&
        kind != 'ColorFilterLayer' &&
        kind != 'ImageFilterLayer') {
      _recorder.unsupportedLayers[kind] =
          (_recorder.unsupportedLayers[kind] ?? 0) + 1;
    }
    super.pushLayer(
      childLayer,
      painter,
      offset,
      childPaintBounds: childPaintBounds,
    );
  }
}

class _Save {
  _Save(this.matrix, this.clip, this.alpha);
  final Matrix4 matrix;
  final Rect? clip;
  final double alpha;
}

/// A canvas that keeps the transform and the clip bounds and records each drawing call.
class _OpCanvas implements Canvas {
  _OpCanvas(this.recorder);
  final _OpRecorder recorder;

  Matrix4 _matrix = Matrix4.identity();
  Rect? _clip; // global, bounding box
  double _alpha = 1;
  double? nextLayerAlpha;
  final _stack = <_Save>[];

  @override
  void save() => _stack.add(_Save(_matrix.clone(), _clip, _alpha));

  @override
  void saveLayer(Rect? bounds, Paint paint) {
    final alpha = nextLayerAlpha ?? paint.color.a;
    nextLayerAlpha = null;
    save();
    _alpha *= alpha;
    if (bounds != null) _clipTo(bounds);
  }

  @override
  void restore() {
    if (_stack.isEmpty) return;
    final top = _stack.removeLast();
    _matrix = top.matrix;
    _clip = top.clip;
    _alpha = top.alpha;
  }

  @override
  void restoreToCount(int count) {
    while (_stack.length > count && _stack.isNotEmpty) {
      restore();
    }
  }

  @override
  int getSaveCount() => _stack.length + 1;

  @override
  void translate(double dx, double dy) =>
      _matrix.translateByDouble(dx, dy, 0, 1);

  @override
  void scale(double sx, [double? sy]) =>
      _matrix.scaleByDouble(sx, sy ?? sx, 1, 1);

  @override
  void rotate(double radians) => _matrix.rotateZ(radians);

  @override
  void skew(double sx, double sy) {
    final skew = Matrix4.identity()
      ..setEntry(0, 1, math.tan(sx))
      ..setEntry(1, 0, math.tan(sy));
    _matrix.multiply(skew);
  }

  @override
  void transform(Float64List matrix4) =>
      _matrix.multiply(Matrix4.fromFloat64List(matrix4));

  @override
  Float64List getTransform() => _matrix.storage;

  Rect _global(Rect local) => MatrixUtils.transformRect(_matrix, local);

  void _clipTo(Rect local) {
    final g = _global(local);
    _clip = _clip == null ? g : _clip!.intersect(g);
  }

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {
    if (clipOp == ui.ClipOp.intersect) _clipTo(rect);
  }

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) {
    _clipTo(rrect.outerRect);
    recorder.add({
      'k': 'clipRRect',
      'b': _rect(_global(rrect.outerRect)),
      'r': _radii(rrect),
    });
  }

  @override
  void clipRSuperellipse(
    RSuperellipse rsuperellipse, {
    bool doAntiAlias = true,
  }) => _clipTo(rsuperellipse.outerRect);

  @override
  void clipPath(Path path, {bool doAntiAlias = true}) =>
      _clipTo(path.getBounds());

  @override
  Rect getLocalClipBounds() => _clip ?? const Rect.fromLTWH(0, 0, 1e5, 1e5);

  @override
  Rect getDestinationClipBounds() =>
      _clip ?? const Rect.fromLTWH(0, 0, 1e5, 1e5);

  // ---- recording -----------------------------------------------------------------------------------------------

  /// Visible bounds of [local] (this canvas' transform and clip applied), or null when nothing shows.
  List<double>? _visible(Rect local) {
    var g = _global(local);
    if (_clip != null) g = g.intersect(_clip!);
    if (g.width < 0 ||
        g.height < 0 ||
        (g.isEmpty && g.width <= 0 && g.height <= 0)) {
      return null;
    }
    return _rect(g);
  }

  void _draw(
    String kind,
    Rect local,
    Paint? paint, [
    Map<String, Object?>? extra,
  ]) => _record(kind, _visible(local), paint, extra);

  void _drawGlobal(String kind, Rect? global, Paint? paint) {
    if (global == null) return;
    final g = _clip == null ? global : global.intersect(_clip!);
    if (g.width < 0 || g.height < 0) return;
    _record(kind, _rect(g), paint, null);
  }

  void _record(
    String kind,
    List<double>? b,
    Paint? paint,
    Map<String, Object?>? extra,
  ) {
    if (b == null) return;
    final op = <String, Object?>{'k': kind, 'b': b};
    if (_alpha < 0.999) op['ba'] = _r2(_alpha);
    // A rotated canvas: the debug overflow indicator's label (tool/parity-ext/extreme_diff.py drops those ops).
    if (_matrix.storage[1].abs() > 1e-6 || _matrix.storage[4].abs() > 1e-6) {
      op['rot'] = 1;
    }
    if (paint != null) {
      op['c'] = paint.color.toARGB32();
      if (paint.style == PaintingStyle.stroke) {
        op['st'] = 1;
        op['sw'] = _r2(paint.strokeWidth);
      }
      final flags =
          (paint.shader != null ? 1 : 0) |
          (paint.maskFilter != null ? 2 : 0) |
          (paint.colorFilter != null ? 4 : 0) |
          (paint.imageFilter != null ? 8 : 0);
      if (flags != 0) op['fl'] = flags;
      if (paint.blendMode != BlendMode.srcOver) op['bm'] = paint.blendMode.name;
    }
    if (extra != null) op.addAll(extra);
    recorder.add(op);
  }

  List<double> _radii(RRect r) => [
    _r2(r.tlRadiusX),
    _r2(r.tlRadiusY),
    _r2(r.trRadiusX),
    _r2(r.trRadiusY),
    _r2(r.brRadiusX),
    _r2(r.brRadiusY),
    _r2(r.blRadiusX),
    _r2(r.blRadiusY),
  ];

  @override
  void drawColor(Color color, BlendMode blendMode) => _drawGlobal(
    'color',
    _clip ?? recorder.current?.rect,
    Paint()..color = color,
  );

  @override
  void drawPaint(Paint paint) =>
      _drawGlobal('paint', _clip ?? recorder.current?.rect, paint);

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => _draw(
    'line',
    Rect.fromPoints(p1, p2).inflate(paint.strokeWidth / 2),
    paint,
  );

  @override
  void drawRect(Rect rect, Paint paint) => _draw('rect', rect, paint);

  @override
  void drawRRect(RRect rrect, Paint paint) =>
      _draw('rrect', rrect.outerRect, paint, {'r': _radii(rrect)});

  @override
  void drawRSuperellipse(RSuperellipse rsuperellipse, Paint paint) =>
      _draw('rrect', rsuperellipse.outerRect, paint);

  @override
  void drawDRRect(RRect outer, RRect inner, Paint paint) =>
      _draw('drrect', outer.outerRect, paint, {
        'r': _radii(outer),
        'ins': [
          _r2(inner.left - outer.left),
          _r2(inner.top - outer.top),
          _r2(outer.right - inner.right),
          _r2(outer.bottom - inner.bottom),
        ],
      });

  @override
  void drawOval(Rect rect, Paint paint) => _draw('oval', rect, paint);

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      _draw('circle', Rect.fromCircle(center: c, radius: radius), paint);

  @override
  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) => _draw('arc', rect, paint);

  @override
  void drawPath(Path path, Paint paint) =>
      _draw('path', path.getBounds(), paint);

  @override
  void drawImage(ui.Image image, Offset offset, Paint paint) => _draw(
    'image',
    offset & Size(image.width.toDouble(), image.height.toDouble()),
    paint,
  );

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) =>
      _draw('image', dst, paint);

  @override
  void drawImageNine(ui.Image image, Rect center, Rect dst, Paint paint) =>
      _draw('image', dst, paint);

  @override
  // A picture has no bounds of its own: use the painting render object's box.
  void drawPicture(ui.Picture picture) =>
      _drawGlobal('picture', recorder.current?.rect, null);

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) =>
      _draw('text', offset & Size(paragraph.width, paragraph.height), null);

  @override
  void drawPoints(ui.PointMode pointMode, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    var rect = Rect.fromPoints(points.first, points.first);
    for (final p in points) {
      rect = rect.expandToInclude(Rect.fromPoints(p, p));
    }
    _draw('points', rect.inflate(paint.strokeWidth / 2), paint);
  }

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) {
    if (points.length < 2) return;
    drawPoints(pointMode, [
      for (var i = 0; i + 1 < points.length; i += 2)
        Offset(points[i], points[i + 1]),
    ], paint);
  }

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      _drawGlobal('vertices', recorder.current?.rect, paint);

  @override
  void drawAtlas(
    ui.Image atlas,
    List<ui.RSTransform> transforms,
    List<Rect> rects,
    List<Color>? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) => _drawGlobal('atlas', recorder.current?.rect, paint);

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) => _drawGlobal('atlas', recorder.current?.rect, paint);

  @override
  void drawShadow(
    Path path,
    Color color,
    double elevation,
    bool transparentOccluder,
  ) => _draw(
    'shadow',
    path.getBounds().inflate(elevation * 2),
    Paint()..color = color,
    {'el': _r2(elevation)},
  );

  @override
  void noSuchMethod(Invocation invocation) {}
}
