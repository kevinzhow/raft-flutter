import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_system_webview/raft_system_webview.dart';
import 'package:raft_ui/raft_ui.dart';

import 'attachment_html_geometry.dart';

/// Only adapts SDK values to the host protocol. The SDK owns capture state,
/// theme recipes, hint pixels and animation; the native host owns GTK events.
class LinuxAttachmentHtmlGeometryController
    extends AttachmentHtmlGeometryController
    implements RaftHtmlNativeRegionController {
  LinuxAttachmentHtmlGeometryController({
    required super.uri,
    required super.allowed,
    required this.system,
  }) : super(evaluate: system.evaluate, currentUri: system.currentUri);
  final SystemWebViewController system;

  static Offset? _pair(Object? value, {bool normalized = false}) {
    if (value is! List || value.length != 2) return null;
    final x = value[0], y = value[1];
    if (x is! num ||
        y is! num ||
        !x.isFinite ||
        !y.isFinite ||
        x.abs() > 10000000 ||
        y.abs() > 10000000 ||
        normalized && (x < 0 || x > 1 || y < 0 || y > 1)) {
      return null;
    }
    return Offset(x.toDouble(), y.toDouble());
  }

  RaftHtmlNativeRegionInput? _input(Map<Object?, Object?> event) {
    if (!active || event['type'] != 'regionInput') return null;
    final generation = event['generation'], sequence = event['sequence'];
    final position = _pair(event['position'], normalized: true);
    final viewport = _pair(event['viewport']);
    final delta = _pair(event['delta']);
    final name = event['phase'];
    RaftHtmlNativeRegionPhase? phase;
    for (final value in RaftHtmlNativeRegionPhase.values) {
      if (value.name == name) phase = value;
    }
    if (generation is! int ||
        generation <= 0 ||
        sequence is! int ||
        sequence <= 0 ||
        position == null ||
        viewport == null ||
        viewport.dx <= 0 ||
        viewport.dy <= 0 ||
        viewport.dx > 32768 ||
        viewport.dy > 32768 ||
        delta == null ||
        phase == null) {
      return null;
    }
    return RaftHtmlNativeRegionInput(
      generation: generation,
      sequence: sequence,
      phase: phase,
      position: position,
      viewport: Size(viewport.dx, viewport.dy),
      delta: delta,
    );
  }

  @override
  Stream<RaftHtmlNativeRegionInput> get nativeRegionInputs => system.events
      .map(_input)
      .where((value) => value != null)
      .cast<RaftHtmlNativeRegionInput>();

  static List<double> _rect(Rect rect) => [
    rect.left,
    rect.top,
    rect.width,
    rect.height,
  ];

  @override
  void updateNativeRegionOverlay(RaftHtmlNativeRegionOverlay frame) {
    if (system.closed) return;
    unawaited(
      system
          .updateRegionOverlay({
            'generation': frame.generation,
            'sequence': frame.sequence,
            'viewport': [frame.viewport.width, frame.viewport.height],
            'captureEnabled': frame.captureEnabled,
            'markers': [
              for (final marker in frame.markers)
                {
                  'rect': _rect(marker.rect),
                  'fillARGB': marker.fill.toARGB32(),
                  'borderARGB': marker.border.toARGB32(),
                  'strokeWidth': marker.strokeWidth,
                  'radius': marker.radius,
                  'dashed': marker.dashed,
                  'borderSegments': [
                    for (final rect in marker.borderSegments) _rect(rect),
                  ],
                  'progress': marker.progress,
                },
            ],
            'hint': frame.hint == null
                ? null
                : {
                    'png': frame.hint!.png,
                    'logicalSize': [
                      frame.hint!.logicalSize.width,
                      frame.hint!.logicalSize.height,
                    ],
                    'logicalOffset': [
                      frame.hint!.logicalOffset.dx,
                      frame.hint!.logicalOffset.dy,
                    ],
                  },
          })
          .catchError((Object _) {}),
    );
  }

  @override
  Future<RaftHtmlRegionLocation?> jump(RaftHtmlRegion region, Size host) async {
    final value = await super.jump(region, host);
    if (value != null && active) system.markSnapshotDirty();
    return value;
  }

  @override
  Future<RaftHtmlGeometry?> scrollBy(Offset delta, Size host) async {
    final value = await super.scrollBy(delta, host);
    if (value != null && active) system.markSnapshotDirty();
    return value;
  }
}
