import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Last measured (width, height) of message rows, keyed by theme, host and
/// message id. Feeds the timeline's total-extent estimate so the scrollbar
/// stays stable; bounded so long sessions do not grow it without limit.
final raftRowExtents = _BoundedExtents(4000);

/// Width of the most recently measured row, used for estimates of rows that
/// have never been laid out.
double raftLastRowWidth = 0;

class _BoundedExtents {
  _BoundedExtents(this.limit);
  final int limit;
  final _map = <String, (double, double)>{};
  (double, double)? operator [](String key) => _map[key];
  void record(String key, double width, double height) {
    final previous = _map.remove(key);
    if (previous == null && _map.length >= limit) {
      _map.remove(_map.keys.first);
    }
    _map[key] = (width, height);
  }
}

/// Records its child's laid-out size without rebuilding anything.
class RaftRowExtentRecorder extends SingleChildRenderObjectWidget {
  const RaftRowExtentRecorder({
    super.key,
    required this.cacheKey,
    required super.child,
  });
  final String cacheKey;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRowExtentRecorder(cacheKey);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderRowExtentRecorder).cacheKey = cacheKey;
}

class _RenderRowExtentRecorder extends RenderProxyBox {
  _RenderRowExtentRecorder(this.cacheKey);
  String cacheKey;
  @override
  void performLayout() {
    super.performLayout();
    raftRowExtents.record(cacheKey, size.width, size.height);
    raftLastRowWidth = size.width;
  }
}

/// Rough rendered height of a message row before it is laid out. Only a
/// first guess for the total extent; measured heights replace it.
double estimateMessageExtent(Map<String, dynamic>? message, double width) {
  if (message == null) return 96;
  final content = '${message['content'] ?? ''}';
  // Text column: row width minus avatar gutter and paddings.
  final textWidth = (width - 88).clamp(120.0, 2000.0);
  var height = 44.0; // author line + row padding
  var inCode = false;
  for (final line in content.split('\n')) {
    if (line.trimLeft().startsWith('```')) {
      inCode = !inCode;
      height += 12;
      continue;
    }
    if (inCode) {
      height += 20;
      continue;
    }
    if (line.trim().isEmpty) {
      height += 8;
      continue;
    }
    var units = 0.0;
    for (final rune in line.runes) {
      units += rune > 0x2e80 ? 14 : 7.4; // CJK glyphs are about twice as wide
    }
    height += (units / textWidth).ceil() * 22;
  }
  // Long content is clipped by the collapsible at 320px plus its toggle.
  height = height.clamp(44.0, 44.0 + 320 + 36);
  final attachments = message['attachments'];
  if (attachments is List) height += attachments.length * 140;
  final reactions = message['reactions'];
  if (reactions is List && reactions.isNotEmpty) height += 32;
  return height;
}
