import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'timeline_row_trace.dart';

/// Last measured (width, height) of message rows, grouped by a theme/host
/// scope and keyed by message id. Feeds the timeline's total-extent estimate
/// so the scrollbar stays stable. The timeline seeds its extent index from
/// these measurements and records actual row heights incrementally.
final raftRowExtents = _RowExtentCache(4000);

class _RowExtentCache {
  _RowExtentCache(this.limit);
  final int limit;
  final _scopes = <String, Map<String, (double, double)>>{};
  final _guesses = <String, _ExtentGuess>{};
  // Revision strings belong to weak canonical metadata keys. The bounded
  // prepared cache keeps only numeric line widths and opaque tokens, neither
  // of which refers back to the metadata or retains its plaintext.
  final _stamps = Expando<_BodyStamp>();
  final _prepared = <Object, _PreparedBodyExtent>{};
  int _size = 0;
  @visibleForTesting
  int debugContentPreparations = 0;
  @visibleForTesting
  int get debugPreparedCacheSize => _prepared.length;
  @visibleForTesting
  int get debugGuessCacheSize => _guesses.length;

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
    if (metadata == null) return 96;
    final content = '${metadata['content'] ?? ''}';
    var stamp = _stamps[metadata];
    if (stamp == null) {
      _stamps[metadata] = stamp = _BodyStamp(content);
    } else if (stamp.content != content) {
      _prepared.remove(stamp.token);
      stamp
        ..content = content
        ..token = Object();
    }
    final attachments = metadata['attachments'];
    final attachmentCount = attachments is List ? attachments.length : 0;
    final reactions = metadata['reactions'];
    final hasReactions = reactions is List && reactions.isNotEmpty;
    final cached = _guesses[id];
    if (cached != null &&
        identical(cached.bodyToken, stamp.token) &&
        cached.attachmentCount == attachmentCount &&
        cached.hasReactions == hasReactions &&
        (cached.width - width).abs() < 1) {
      return cached.height;
    }
    var body = _prepared[stamp.token];
    if (body == null) {
      debugContentPreparations++;
      body = _PreparedBodyExtent(content);
      if (_prepared.length >= limit) _prepared.remove(_prepared.keys.first);
      _prepared[stamp.token] = body;
    }
    final value = body.height(width, attachmentCount, hasReactions);
    if (cached == null) {
      if (_guesses.length >= limit) _guesses.remove(_guesses.keys.first);
      _guesses[id] = _ExtentGuess(
        stamp.token,
        attachmentCount,
        hasReactions,
        width,
        value,
      );
    } else {
      // Width changes update the estimate without allocating another cache
      // entry for every retained message on every resize frame.
      cached
        ..bodyToken = stamp.token
        ..attachmentCount = attachmentCount
        ..hasReactions = hasReactions
        ..width = width
        ..height = value;
    }
    return value;
  }
}

class _BodyStamp {
  _BodyStamp(this.content);
  String content;
  Object token = Object();
}

class _ExtentGuess {
  _ExtentGuess(
    this.bodyToken,
    this.attachmentCount,
    this.hasReactions,
    this.width,
    this.height,
  );
  Object bodyToken;
  int attachmentCount;
  bool hasReactions;
  double width, height;
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
  RenderObject createRenderObject(BuildContext context) => traceTimelineRows
      ? _TracedRowExtentRecorder(scope, id)
      : _RenderRowExtentRecorder(scope, id);
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
  }
}

class _TracedRowExtentRecorder extends _RenderRowExtentRecorder {
  _TracedRowExtentRecorder(super.scope, super.id);

  @override
  void performLayout() => timelineRowTrace('layout', id, super.performLayout);

  @override
  void paint(PaintingContext context, Offset offset) =>
      timelineRowTrace('paint', id, () => super.paint(context, offset));
}

/// Rough rendered height of a message row before it is laid out. Only a
/// first guess for the total extent; measured heights replace it.
double estimateMessageExtent(Map<String, dynamic>? message, double width) {
  if (message == null) return 96;
  final attachments = message['attachments'];
  final reactions = message['reactions'];
  return _PreparedBodyExtent('${message['content'] ?? ''}').height(
    width,
    attachments is List ? attachments.length : 0,
    reactions is List && reactions.isNotEmpty,
  );
}

class _PreparedBodyExtent {
  factory _PreparedBodyExtent(String content) {
    var fixed = 44.0; // author line + row padding
    var inCode = false;
    final units = <double>[];
    for (final line in content.split('\n')) {
      if (line.trimLeft().startsWith('```')) {
        inCode = !inCode;
        fixed += 12;
      } else if (inCode) {
        fixed += 20;
      } else if (line.trim().isEmpty) {
        fixed += 8;
      } else {
        var width = 0.0;
        for (final rune in line.runes) {
          width += rune > 0x2e80 ? 14 : 7.4;
        }
        units.add(width);
      }
    }
    return _PreparedBodyExtent._(fixed, Float64List.fromList(units));
  }
  _PreparedBodyExtent._(this.fixed, this.lineWidths);
  final double fixed;
  final Float64List lineWidths;

  double height(double width, int attachments, bool reactions) {
    final textWidth = (width - 88).clamp(120.0, 2000.0);
    var result = fixed;
    for (final units in lineWidths) {
      result += (units / textWidth).ceil() * 22;
    }
    // Only the content is clipped; attachments and reactions follow it.
    return result.clamp(44.0, 44.0 + 320 + 36) +
        attachments * 140 +
        (reactions ? 32 : 0);
  }
}
