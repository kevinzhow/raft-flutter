import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'attachment_comment_scope.dart';

/// The existing server's maximum content coordinate, not a widget dimension.
const raftHtmlCoordinateLimit = 10000000.0;

double? _number(Object? value, {bool positive = false}) =>
    value is num &&
        value.isFinite &&
        (positive ? value > 0 : value >= 0) &&
        value <= raftHtmlCoordinateLimit
    ? value.toDouble()
    : null;

/// Untrusted CSS document geometry, normalized at the renderer boundary.
class RaftHtmlGeometry {
  const RaftHtmlGeometry({
    required this.viewport,
    required this.visible,
    required this.scroll,
    required this.document,
  });
  final Size viewport, visible, document;
  final Offset scroll;
  static RaftHtmlGeometry? parse(Object? value) {
    if (value is! Map) return null;
    final vw = _number(value['viewportWidth'], positive: true),
        vh = _number(value['viewportHeight'], positive: true);
    final ww = _number(value['visibleWidth'], positive: true),
        wh = _number(value['visibleHeight'], positive: true);
    final x = _number(value['scrollX']), y = _number(value['scrollY']);
    final dw = _number(value['documentWidth'], positive: true),
        dh = _number(value['documentHeight'], positive: true);
    if (vw == null ||
        vh == null ||
        ww == null ||
        wh == null ||
        x == null ||
        y == null ||
        dw == null ||
        dh == null ||
        ww < 1 ||
        wh < 1 ||
        x > dw ||
        y > dh)
      return null;
    return RaftHtmlGeometry(
      viewport: Size(vw, vh),
      visible: Size(ww, wh),
      scroll: Offset(x, y),
      document: Size(dw, dh),
    );
  }

  Rect local(RaftHtmlRegion region, Size host, {double minimum = 0}) =>
      Rect.fromLTWH(
        (region.rect.left - scroll.dx) * host.width / visible.width,
        (region.rect.top - scroll.dy) * host.height / visible.height,
        math.max(region.rect.width, minimum) * host.width / visible.width,
        math.max(region.rect.height, minimum) * host.height / visible.height,
      );
}

/// The API's closed html-region vocabulary. Unexpected fields never cross it.
class RaftHtmlRegion {
  const RaftHtmlRegion({
    required this.rect,
    required this.viewportWidth,
    required this.document,
    this.quote,
  });
  final Rect rect;
  final double viewportWidth;
  final Size document;
  final String? quote;
  static RaftHtmlRegion? parse(Object? value) {
    if (value is! Map) return null;
    final x = _number(value['x']),
        y = _number(value['y']),
        w = _number(value['w']),
        h = _number(value['h']);
    final vw = _number(value['viewportWidth'], positive: true),
        dw = _number(value['documentWidth'], positive: true),
        dh = _number(value['documentHeight'], positive: true);
    final quote = value['quote'];
    if (x == null ||
        y == null ||
        w == null ||
        h == null ||
        vw == null ||
        dw == null ||
        dh == null ||
        quote != null && quote is! String)
      return null;
    return RaftHtmlRegion(
      rect: Rect.fromLTWH(x, y, w, h),
      viewportWidth: vw,
      document: Size(dw, dh),
      quote: quote is String && quote.trim().isNotEmpty
          ? quote.trim().substring(0, math.min(quote.trim().length, 200))
          : null,
    );
  }

  static RaftHtmlRegion? fromAnchor(RaftCommentAnchor anchor) =>
      anchor['type'] == 'html-region' ? parse(anchor['data']) : null;
  Map<String, dynamic> get data => {
    'x': rect.left.round(),
    'y': rect.top.round(),
    'w': rect.width.round(),
    'h': rect.height.round(),
    'viewportWidth': viewportWidth.round().clamp(
      1,
      raftHtmlCoordinateLimit.toInt(),
    ),
    'documentWidth': document.width.round().clamp(
      1,
      raftHtmlCoordinateLimit.toInt(),
    ),
    'documentHeight': document.height.round().clamp(
      1,
      raftHtmlCoordinateLimit.toInt(),
    ),
    'quote': ?quote,
  };
  RaftCommentAnchor get anchor => {'type': 'html-region', 'data': data};
}

class RaftHtmlRegionLocation {
  const RaftHtmlRegionLocation(this.geometry, this.region);
  final RaftHtmlGeometry geometry;
  final RaftHtmlRegion region;
}

/// Host-controlled measurement; uploaded HTML receives no callable app API.
abstract interface class RaftHtmlRegionController {
  bool get active;
  Future<RaftHtmlGeometry?> measure(Size host);
  Future<RaftHtmlRegionLocation?> capture(Rect local, Size host);
  Future<RaftHtmlRegionLocation?> jump(RaftHtmlRegion region, Size host);
  Future<RaftHtmlGeometry?> scrollBy(Offset delta, Size host);
}
