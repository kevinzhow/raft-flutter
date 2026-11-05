// Observation only: the canonical SDK is the only caller of capture/jump, and
// the real GTK host is the only source of pointer events. No QA input API.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

class HtmlRegionSystemQaObserver
    implements RaftHtmlRegionController, RaftHtmlNativeRegionController {
  HtmlRegionSystemQaObserver(this.delegate)
    : native = delegate as RaftHtmlNativeRegionController;
  final RaftHtmlRegionController delegate;
  final RaftHtmlNativeRegionController native;
  final inputs = <Map<String, Object?>>[];
  final captures = <Map<String, Object?>>[];
  final jumps = <Map<String, Object?>>[];
  final overlays = <Map<String, Object?>>[];
  Map<String, Object?>? geometry, lastHint;
  int measureCount = 0, scrollCount = 0;

  static List<double> size(Size value) => [value.width, value.height];
  static List<double> point(Offset value) => [value.dx, value.dy];
  static List<double> rect(Rect value) => [
    value.left,
    value.top,
    value.width,
    value.height,
  ];

  void _record(List<Map<String, Object?>> target, Map<String, Object?> value) {
    target.add(value);
    if (target.length > 128) target.removeAt(0);
  }

  Map<String, Object?>? _geometry(RaftHtmlGeometry? value) => value == null
      ? null
      : {
          'viewport': size(value.viewport),
          'visible': size(value.visible),
          'document': size(value.document),
          'scroll': point(value.scroll),
        };

  @override
  bool get active => delegate.active;

  @override
  Future<RaftHtmlGeometry?> measure(Size host) async {
    measureCount++;
    final result = await delegate.measure(host);
    geometry = _geometry(result);
    return result;
  }

  @override
  Future<RaftHtmlRegionLocation?> capture(Rect local, Size host) async {
    final result = await delegate.capture(local, host);
    geometry = _geometry(result?.geometry);
    _record(captures, {
      'local': rect(local),
      'host': size(host),
      'anchor': result?.region.anchor,
      'geometry': geometry,
    });
    return result;
  }

  @override
  Future<RaftHtmlRegionLocation?> jump(RaftHtmlRegion region, Size host) async {
    final result = await delegate.jump(region, host);
    geometry = _geometry(result?.geometry);
    _record(jumps, {
      'requestedAnchor': region.anchor,
      'host': size(host),
      'accepted': result != null,
      'resolvedAnchor': result?.region.anchor,
      'geometry': geometry,
    });
    return result;
  }

  @override
  Future<RaftHtmlGeometry?> scrollBy(Offset delta, Size host) async {
    scrollCount++;
    final result = await delegate.scrollBy(delta, host);
    geometry = _geometry(result);
    return result;
  }

  @override
  late final Stream<RaftHtmlNativeRegionInput> nativeRegionInputs = native
      .nativeRegionInputs
      .map((event) {
        _record(inputs, {
          'generation': event.generation,
          'sequence': event.sequence,
          'phase': event.phase.name,
          'position': point(event.position),
          'delta': point(event.delta),
          'viewport': size(event.viewport),
        });
        return event;
      });

  @override
  void updateNativeRegionOverlay(RaftHtmlNativeRegionOverlay frame) {
    final hint = frame.hint;
    if (hint != null) {
      lastHint = {
        'pngBytes': hint.png.length,
        'sha256': sha256.convert(hint.png).toString(),
        'pngBase64': base64Encode(hint.png),
        'logicalSize': size(hint.logicalSize),
        'logicalOffset': point(hint.logicalOffset),
      };
    }
    _record(overlays, {
      'generation': frame.generation,
      'sequence': frame.sequence,
      'viewport': size(frame.viewport),
      'captureEnabled': frame.captureEnabled,
      'hintBytes': hint?.png.length ?? 0,
      'markers': [
        for (final marker in frame.markers)
          {
            'rect': rect(marker.rect),
            'fillARGB': marker.fill.toARGB32(),
            'borderARGB': marker.border.toARGB32(),
            'strokeWidth': marker.strokeWidth,
            'radius': marker.radius,
            'dashed': marker.dashed,
            'progress': marker.progress,
            'borderSegments': marker.borderSegments.map(rect).toList(),
          },
      ],
    });
    native.updateNativeRegionOverlay(frame);
  }

  Map<String, Object?> snapshot() => {
    'active': active,
    'geometry': geometry,
    'measureCount': measureCount,
    'scrollCount': scrollCount,
    'inputs': List.of(inputs),
    'captures': List.of(captures),
    'jumps': List.of(jumps),
    'overlays': List.of(overlays),
    'lastHint': lastHint,
  };
}
