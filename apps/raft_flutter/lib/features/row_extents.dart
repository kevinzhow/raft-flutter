import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Last measured (width, height) of message rows, grouped by a theme/host
/// scope and keyed by message id. Feeds the timeline's total-extent estimate
/// so the scrollbar stays stable. Lookups allocate nothing: the estimate runs
/// for every unbuilt row on every layout.
final raftRowExtents = _RowExtentCache(4000);

/// Width of the most recently measured row, used for estimates of rows that
/// have never been laid out.
double raftLastRowWidth = 0;

class _RowExtentCache {
  _RowExtentCache(this.limit);
  final int limit;
  final _scopes = <String, Map<String, (double, double)>>{};
  // Content-based guesses, computed once per message and width.
  final _guesses = <String, (double, double)>{};
  int _size = 0;

  Map<String, (double, double)> scope(String scope) =>
      _scopes.putIfAbsent(scope, () => <String, (double, double)>{});

  void record(String scope, String id, double width, double height) {
    final map = this.scope(scope);
    if (!map.containsKey(id)) {
      if (_size >= limit) {
        // Drop the oldest scope's oldest entry.
        final oldest = _scopes.values.firstWhere((m) => m.isNotEmpty);
        oldest.remove(oldest.keys.first);
        _size--;
      }
      _size++;
    }
    map[id] = (width, height);
  }

  double guess(String id, Map<String, dynamic>? metadata, double width) {
    final cached = _guesses[id];
    if (cached != null && (cached.$1 - width).abs() < 1) return cached.$2;
    if (_guesses.length >= limit) _guesses.remove(_guesses.keys.first);
    final value = estimateMessageExtent(metadata, width);
    _guesses[id] = (width, value);
    return value;
  }
}

/// Records its child's laid-out size without rebuilding anything.
class RaftRowExtentRecorder extends SingleChildRenderObjectWidget {
  const RaftRowExtentRecorder({
    super.key,
    required this.scope,
    required this.id,
    required super.child,
  });
  final String scope, id;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRowExtentRecorder(scope, id);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderRowExtentRecorder)
        ..scope = scope
        ..id = id;
}

/// A row whose message identity can be read from its render object.
abstract interface class RaftRowIdentity {
  String get rowId;
}

class _RenderRowExtentRecorder extends RenderProxyBox
    implements RaftRowIdentity {
  _RenderRowExtentRecorder(this.scope, this.id);
  String scope, id;
  @override
  String get rowId => id;
  @override
  void performLayout() {
    super.performLayout();
    raftRowExtents.record(scope, id, size.width, size.height);
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
