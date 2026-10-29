import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Opt-in frame/route phase tracing for release and profile investigations.
/// Enable with --dart-define=RAFT_ROUTE_FRAME_DIAGNOSTICS=true. Normal builds
/// install no observer, timer or extra render object. Never records identity,
/// URI, message content or private network addresses.
abstract final class RouteFrameDiagnostics {
  static const enabled = bool.fromEnvironment('RAFT_ROUTE_FRAME_DIAGNOSTICS');
  static String screen = 'startup';
  static final _pending = <Map<String, Object?>>[];
  static Timer? _flushTimer;
  static final _scopes = <String, int>{};
  static int _begin = 0;
  static int drawStarted = 0;
  static int _dropped = 0;

  static int now() => developer.Timeline.now;
  static void initialize(WidgetsBinding binding) {
    if (!enabled || _flushTimer != null) return;
    binding.addTimingsCallback((frames) {
      for (final f in frames) {
        _add({
          'kind': 'frame',
          'vsync': f.timestampInMicroseconds(ui.FramePhase.vsyncStart),
          'buildStart': f.timestampInMicroseconds(ui.FramePhase.buildStart),
          'buildUs': f.buildDuration.inMicroseconds,
          'rasterUs': f.rasterDuration.inMicroseconds,
          'rasterStart': f.timestampInMicroseconds(ui.FramePhase.rasterStart),
          'number': f.frameNumber,
        });
      }
    });
    // ignore: raft_lints/avoid_unreviewed_idle_work, raft_lints/avoid_unreleased_resource -- 3 s flush of the opt-in route frame probe; only created when the diagnostics flag is on, never in a normal run, and it lives for the whole run by design.
    _flushTimer = Timer.periodic(const Duration(seconds: 3), (_) => _flush());
  }

  static void begin() {
    if (!enabled) return;
    _begin = now();
    _scopes.clear();
  }

  static void end() {
    if (!enabled || _begin == 0) return;
    _add({
      'kind': 'ui',
      'start': _begin,
      'uiUs': now() - _begin,
      'screen': screen,
      'scopes': Map.of(_scopes),
    });
    _begin = 0;
  }

  static void scope(String name, int start) {
    if (!enabled) return;
    _scopes.update(
      name,
      (v) => v + now() - start,
      ifAbsent: () => now() - start,
    );
  }

  static void location(String next) {
    if (!enabled || screen == next) return;
    screen = next;
    _add({'kind': 'route', 'screen': next, 'start': now()});
  }

  static void _add(Map<String, Object?> row) {
    if (_pending.length < 800) {
      _pending.add(row);
    } else {
      _dropped++;
    }
  }

  static void _flush() {
    // Bounded batches, outside the measured frame cycle. Timer never requests
    // a frame and the observer disappears from a normal release build.
    if (_flushTimer == null || _pending.isEmpty) return;
    final rows = List.of(_pending);
    _pending.clear();
    final start = now();
    final dropped = _dropped;
    _dropped = 0;
    for (final row in rows) {
      debugPrintSynchronously('RAFT_ROUTE_PERF ${jsonEncode(row)}');
    }
    // Export time is observable: consumers can exclude frames overlapping a
    // flush and cannot mistake a full buffer for a complete measurement.
    debugPrintSynchronously(
      'RAFT_ROUTE_PERF ${jsonEncode({'kind': 'probeFlush', 'start': start, 'end': now(), 'records': rows.length, 'dropped': dropped})}',
    );
  }
}

final class RouteFramePipelineOwner extends PipelineOwner {
  RouteFramePipelineOwner() : super(onSemanticsUpdate: (_) {});

  @override
  void flushLayout() {
    final start = RouteFrameDiagnostics.now();
    RouteFrameDiagnostics.scope(
      'widgetBuildUs',
      RouteFrameDiagnostics.drawStarted,
    );
    super.flushLayout();
    RouteFrameDiagnostics.scope('layoutUs', start);
  }

  @override
  void flushCompositingBits() {
    final start = RouteFrameDiagnostics.now();
    super.flushCompositingBits();
    RouteFrameDiagnostics.scope('compositingUs', start);
  }

  @override
  void flushPaint() {
    final start = RouteFrameDiagnostics.now();
    super.flushPaint();
    RouteFrameDiagnostics.scope('paintUs', start);
  }

  @override
  void flushSemantics() {
    final start = RouteFrameDiagnostics.now();
    super.flushSemantics();
    RouteFrameDiagnostics.scope('semanticsUs', start);
  }
}

class RouteFrameProbe extends SingleChildRenderObjectWidget {
  const RouteFrameProbe({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RouteFrameProbe();
}

class _RouteFrameProbe extends RenderProxyBox {
  @override
  void performLayout() {
    final start = RouteFrameDiagnostics.now();
    super.performLayout();
    RouteFrameDiagnostics.scope('pageLayoutUs', start);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final start = RouteFrameDiagnostics.now();
    super.paint(context, offset);
    RouteFrameDiagnostics.scope('pagePaintUs', start);
  }
}
