import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Failure category detected on an interactive control.
enum HitTestIssueKind {
  /// The control's own RenderBox is absent from [HitTestResult] at a probe
  /// point (occluded by a sibling, overlay, scrollbar, or outside Stack bounds).
  occluded,

  /// A non-descendant RenderObject appears in front of the control in
  /// [HitTestResult.path], intercepting pointer events before the control.
  frontBlocker,

  /// Hovering onto the control with a real mouse caused it to unmount, become
  /// un-hittable, or get occluded after hover animations/overlays settled.
  hoverUnstable,
}

/// One visible interactive control discovered in the mounted widget tree.
@immutable
class DiscoveredControl {
  const DiscoveredControl({
    required this.element,
    required this.renderBox,
    required this.bounds,
    required this.visibleBounds,
    required this.label,
    required this.kind,
    this.keyDescription,
  });

  final Element element;
  final RenderBox renderBox;
  final Rect bounds;
  final Rect visibleBounds;
  final String label;
  final String kind;
  final String? keyDescription;

  String get summary {
    final parts = <String>[
      kind,
      if (keyDescription != null) keyDescription!,
      if (label.isNotEmpty) '"$label"',
    ];
    return '${parts.join(' ')} @ ${_fmtRect(visibleBounds)}';
  }
}

/// One hit-test, occlusion, or hover-stability defect found by [auditHitTests].
@immutable
class HitTestFinding {
  const HitTestFinding({
    required this.surface,
    required this.control,
    required this.kind,
    required this.probeName,
    required this.point,
    required this.occluder,
    required this.detail,
  });

  final String surface;
  final String control;
  final HitTestIssueKind kind;
  final String probeName;
  final Offset point;
  final String occluder;
  final String detail;

  @override
  String toString() =>
      '[$surface] ${kind.name} on $control ($probeName @ ${_fmtOffset(point)}): '
      '$detail [top=$occluder]';
}

/// Aggregate result of [auditHitTests].
@immutable
class HitTestAuditReport {
  const HitTestAuditReport({
    required this.surface,
    required this.probedControls,
    required this.skippedControls,
    required this.findings,
  });

  final String surface;
  final int probedControls;
  final int skippedControls;
  final List<HitTestFinding> findings;

  bool get ok => findings.isEmpty;

  String formatFailure() {
    final buffer = StringBuffer()
      ..writeln(
        'Hit-test audit failed on "$surface": '
        '${findings.length} finding(s) across $probedControls probed control(s) '
        '($skippedControls skipped):',
      );
    for (final f in findings) {
      buffer.writeln('  - $f');
    }
    return buffer.toString();
  }
}

/// Options controlling [auditHitTests].
class HitTestAuditOptions {
  const HitTestAuditOptions({
    this.root,
    this.mouse,
    this.probeHoverStability = true,
    this.hoverSettleDuration = const Duration(milliseconds: 250),
    this.probeEdges = true,
    this.minVisibleExtent = 8.0,
    this.edgeInset = 2.0,
    this.ignoreControl,
    this.ignoreProbe,
  });

  /// Restrict discovery to descendants of [root]. When null, discovers controls
  /// across the active topmost route/overlay of the app.
  final Finder? root;

  /// Optional existing mouse gesture to reuse during hover-stability probing
  /// (when the caller already holds a pointer open to keep a hover toolbar or
  /// popover mounted).
  final TestGesture? mouse;

  /// Move a real mouse pointer onto each control (center + trailing edge) and
  /// verify it remains mounted and hit-testable after [hoverSettleDuration].
  final bool probeHoverStability;

  /// Time to pump after moving the mouse onto a control during hover stability
  /// checks (long enough for proximity scrollbars / hover transitions to react).
  final Duration hoverSettleDuration;

  /// When true, probes center + 4 inner quadrants + 4 inner edges (9 points).
  /// When false, probes center + 4 inner quadrants (5 points).
  final bool probeEdges;

  /// Controls whose visible width or height is smaller than this are treated as
  /// scrolled offscreen and skipped.
  final double minVisibleExtent;

  /// Distance inward from each edge for edge probe points.
  final double edgeInset;

  /// Optional predicate to skip specific controls.
  final bool Function(DiscoveredControl control)? ignoreControl;

  /// Optional predicate to skip specific (control, probeName) pairs (e.g., an
  /// intentional Web-parity partial overlap at one edge).
  final bool Function(DiscoveredControl control, String probeName)? ignoreProbe;
}

String _fmtOffset(Offset o) =>
    '(${o.dx.toStringAsFixed(1)}, ${o.dy.toStringAsFixed(1)})';

String _fmtRect(Rect r) =>
    'LTRB(${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, '
    '${r.right.toStringAsFixed(1)}, ${r.bottom.toStringAsFixed(1)})';

List<RenderObject> hitTestPathAt(WidgetTester tester, Offset position) {
  final result = HitTestResult();
  tester.binding.hitTestInView(result, position, tester.view.viewId);
  return [
    for (final entry in result.path)
      if (entry.target is RenderObject) entry.target as RenderObject,
  ];
}

bool _isDescendantOrSelf(RenderObject candidate, RenderObject ancestor) {
  for (RenderObject? cur = candidate; cur != null; cur = cur.parent) {
    if (identical(cur, ancestor)) return true;
  }
  return false;
}

String describeHitRenderObject(RenderObject? target) {
  if (target == null) return '<empty>';
  final creator = target.debugCreator?.toString() ?? '';
  final trimmed = creator.length > 140
      ? '${creator.substring(0, 140)}...'
      : creator;
  return '${target.runtimeType}($trimmed)';
}

Rect _visibleBoundsInViewports(RenderBox box, Rect screenRect) {
  var visible = (box.localToGlobal(Offset.zero) & box.size).intersect(
    screenRect,
  );
  if (visible.isEmpty) return Rect.zero;
  RenderObject? ancestor = box.parent;
  while (ancestor != null) {
    if (ancestor is RenderAbstractViewport && ancestor is RenderBox) {
      final vpBox = ancestor as RenderBox;
      final vpRect = vpBox.localToGlobal(Offset.zero) & vpBox.size;
      visible = visible.intersect(vpRect);
      if (visible.isEmpty) return Rect.zero;
    }
    ancestor = ancestor.parent;
  }
  return visible;
}

bool _isDisabledInSubtree(Element element) {
  final w = element.widget;
  if (w is Offstage && w.offstage) return true;
  if (w is IgnorePointer && w.ignoring) return true;
  if (w is AbsorbPointer && w.absorbing) return true;
  if (w is TickerMode && !w.enabled) return true;
  if (w is Visibility && !w.visible) return true;
  return false;
}

String _extractLabel(Element root) {
  final w = root.widget;
  if (w is RaftInteractive) {
    if (w.semanticLabel != null && w.semanticLabel!.isNotEmpty) {
      return w.semanticLabel!;
    }
    if (w.tooltip != null && w.tooltip!.isNotEmpty) return w.tooltip!;
  }
  if (w is IconButton && w.tooltip != null && w.tooltip!.isNotEmpty) {
    return w.tooltip!;
  }
  if (w is PopupMenuButton && w.tooltip != null && w.tooltip!.isNotEmpty) {
    return w.tooltip!;
  }
  String? found;
  void walk(Element el) {
    if (found != null) return;
    final widget = el.widget;
    if (widget is Text) {
      final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      if (text.trim().isNotEmpty) {
        found = text.trim();
        return;
      }
    } else if (widget is RaftTooltip && widget.message.isNotEmpty) {
      found = widget.message;
      return;
    } else if (widget is Tooltip &&
        widget.message != null &&
        widget.message!.isNotEmpty) {
      found = widget.message;
      return;
    } else if (widget is Semantics &&
        widget.properties.label != null &&
        widget.properties.label!.isNotEmpty) {
      found = widget.properties.label;
      return;
    }
    el.visitChildren(walk);
  }

  walk(root);
  final raw = found ?? '';
  return raw.length > 48 ? '${raw.substring(0, 48)}...' : raw;
}

String? _nearestKeyDescription(Element element) {
  String? describe(Key? key) => key?.toString();
  if (element.widget.key != null) return describe(element.widget.key);
  String? found;
  var depth = 0;
  element.visitAncestorElements((ancestor) {
    depth++;
    if (depth > 4) return false;
    final w = ancestor.widget;
    if (w.key != null &&
        (w is RaftButton ||
            w is RaftIconButton ||
            w is RaftControl ||
            w is RaftMessageToolbarAction ||
            w is RaftInteractive ||
            w is RaftTooltip ||
            w is PopupMenuButton ||
            w is TextField)) {
      found = describe(w.key);
      return false;
    }
    return true;
  });
  return found;
}

bool _hasInteractiveDescendant(Element element) {
  var found = false;
  void walk(Element child) {
    if (found || _isDisabledInSubtree(child)) return;
    final w = child.widget;
    if (w is RaftInteractive ||
        w is ButtonStyleButton ||
        w is IconButton ||
        w is PopupMenuButton ||
        w is InkResponse ||
        w is EditableText) {
      found = true;
      return;
    }
    child.visitChildren(walk);
  }

  element.visitChildren(walk);
  return found;
}

bool _isDirectSelectionRegionDetector(Element element) {
  var inside = false;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is SelectionArea ||
        ancestor.widget is SelectableRegion) {
      inside = true;
      return false;
    }
    if (ancestor.widget is SelectionContainer) return false;
    return true;
  });
  return inside;
}

bool _isCoveredByModalBarrier(WidgetTester tester, Offset point) {
  final path = hitTestPathAt(tester, point);
  if (path.isEmpty) return false;
  final creator = path.first.debugCreator?.toString() ?? '';
  return creator.contains('ModalBarrier') || creator.contains('_ModalBarrier');
}

/// Discovers all visible interactive controls in the rendered tree under
/// [options.root] (or the full app root).
(List<DiscoveredControl> active, int skipped) discoverInteractiveControls(
  WidgetTester tester, {
  HitTestAuditOptions options = const HitTestAuditOptions(),
}) {
  final viewSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final screenRect = Offset.zero & viewSize;
  final rootElement = options.root != null
      ? tester.element(options.root!)
      : tester.binding.rootElement!;

  final controls = <DiscoveredControl>[];
  final seenBoxes = <RenderBox>{};
  var skipped = 0;

  final hasModalBarrier = find.byType(ModalBarrier).evaluate().any((e) {
    final box = e.renderObject;
    return box is RenderBox && box.attached && box.hasSize && !box.size.isEmpty;
  });

  void record(Element el, String kind) {
    final ro = el.renderObject;
    if (ro is! RenderBox || !ro.attached || !ro.hasSize || ro.size.isEmpty) {
      skipped++;
      return;
    }
    if (!seenBoxes.add(ro)) return;
    final bounds = ro.localToGlobal(Offset.zero) & ro.size;
    final visible = _visibleBoundsInViewports(ro, screenRect);
    if (visible.width < options.minVisibleExtent ||
        visible.height < options.minVisibleExtent) {
      skipped++;
      return;
    }
    if (hasModalBarrier && _isCoveredByModalBarrier(tester, visible.center)) {
      skipped++;
      return;
    }
    final control = DiscoveredControl(
      element: el,
      renderBox: ro,
      bounds: bounds,
      visibleBounds: visible,
      label: _extractLabel(el),
      kind: kind,
      keyDescription: _nearestKeyDescription(el),
    );
    if (options.ignoreControl?.call(control) == true) {
      skipped++;
      return;
    }
    controls.add(control);
  }

  void walk(Element el) {
    if (_isDisabledInSubtree(el)) return;
    final w = el.widget;

    if (w is RaftInteractive) {
      if (w.onPressed != null && !w.busy) {
        record(el, 'RaftInteractive');
      }
      return;
    }
    if (w is ButtonStyleButton) {
      if (w.enabled) record(el, w.runtimeType.toString());
      return;
    }
    if (w is IconButton) {
      if (w.onPressed != null) record(el, 'IconButton');
      return;
    }
    if (w is PopupMenuButton) {
      if (w.enabled) record(el, 'PopupMenuButton');
      return;
    }
    if (w is InkResponse) {
      if (w.onTap != null || w.onDoubleTap != null || w.onLongPress != null) {
        if (!_hasInteractiveDescendant(el)) {
          record(el, w.runtimeType.toString());
          return;
        }
      }
    }
    if (w is EditableText) {
      if (!w.readOnly) {
        record(el, 'EditableText');
        return;
      }
    }
    if (w is GestureDetector) {
      final handlesTap =
          w.onTap != null || w.onTapUp != null || w.onTapDown != null;
      if (handlesTap &&
          w.behavior != HitTestBehavior.translucent &&
          !_hasInteractiveDescendant(el) &&
          !_isDirectSelectionRegionDetector(el)) {
        final ro = el.renderObject;
        if (ro is RenderBox &&
            ro.attached &&
            ro.hasSize &&
            (ro.size.width * ro.size.height) <
                (viewSize.width * viewSize.height * 0.6)) {
          record(el, 'GestureDetector');
          return;
        }
      }
    }

    el.visitChildren(walk);
  }

  walk(rootElement);
  return (controls, skipped);
}

Map<String, Offset> _probePointsFor(
  Rect rect, {
  required bool includeEdges,
  required double edgeInset,
}) {
  final dx = rect.width * 0.25;
  final dy = rect.height * 0.25;
  final ix = math.min(edgeInset, rect.width * 0.2);
  final iy = math.min(edgeInset, rect.height * 0.2);
  return {
    'center': rect.center,
    'topLeftQ': rect.center + Offset(-dx, -dy),
    'topRightQ': rect.center + Offset(dx, -dy),
    'bottomLeftQ': rect.center + Offset(-dx, dy),
    'bottomRightQ': rect.center + Offset(dx, dy),
    if (includeEdges) ...{
      'topEdge': Offset(rect.center.dx, rect.top + iy),
      'bottomEdge': Offset(rect.center.dx, rect.bottom - iy),
      'leftEdge': Offset(rect.left + ix, rect.center.dy),
      'rightEdge': Offset(rect.right - ix, rect.center.dy),
    },
  };
}

HitTestFinding? _checkPoint({
  required WidgetTester tester,
  required String surface,
  required DiscoveredControl control,
  required String probeName,
  required Offset point,
}) {
  final path = hitTestPathAt(tester, point);
  if (path.isEmpty) {
    return HitTestFinding(
      surface: surface,
      control: control.summary,
      kind: HitTestIssueKind.occluded,
      probeName: probeName,
      point: point,
      occluder: '<empty>',
      detail: 'HitTestResult was empty',
    );
  }
  final ownIndex = path.indexWhere(
    (ro) => _isDescendantOrSelf(ro, control.renderBox),
  );
  if (ownIndex < 0) {
    return HitTestFinding(
      surface: surface,
      control: control.summary,
      kind: HitTestIssueKind.occluded,
      probeName: probeName,
      point: point,
      occluder: describeHitRenderObject(path.first),
      detail: 'control RenderBox was not reached in HitTestResult',
    );
  }
  if (ownIndex > 0) {
    final front = path.first;
    if (!_isDescendantOrSelf(front, control.renderBox)) {
      return HitTestFinding(
        surface: surface,
        control: control.summary,
        kind: HitTestIssueKind.frontBlocker,
        probeName: probeName,
        point: point,
        occluder: describeHitRenderObject(front),
        detail: 'sibling/overlay sits in front of control in HitTestResult',
      );
    }
  }
  return null;
}

/// Runs the full interactive hit-test, occlusion, and hover-stability audit on
/// the currently rendered widget tree.
Future<HitTestAuditReport> auditHitTests(
  WidgetTester tester, {
  required String surface,
  HitTestAuditOptions options = const HitTestAuditOptions(),
}) async {
  final (controls, skipped) = discoverInteractiveControls(
    tester,
    options: options,
  );
  final findings = <HitTestFinding>[];

  for (final control in controls) {
    final points = _probePointsFor(
      control.visibleBounds,
      includeEdges: options.probeEdges,
      edgeInset: options.edgeInset,
    );
    for (final entry in points.entries) {
      if (options.ignoreProbe?.call(control, entry.key) == true) continue;
      final finding = _checkPoint(
        tester: tester,
        surface: surface,
        control: control,
        probeName: entry.key,
        point: entry.value,
      );
      if (finding != null) findings.add(finding);
    }
  }

  if (options.probeHoverStability && controls.isNotEmpty) {
    final ownedMouse = options.mouse == null;
    final mouse =
        options.mouse ??
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    if (ownedMouse) await mouse.addPointer(location: Offset.zero);
    try {
      for (final control in controls) {
        if (!control.element.mounted || !control.renderBox.attached) continue;
        final hoverTargets = <String, Offset>{
          'hover-center': control.visibleBounds.center,
          if (options.probeEdges)
            'hover-rightEdge': Offset(
              control.visibleBounds.right -
                  math.min(
                    options.edgeInset,
                    control.visibleBounds.width * 0.2,
                  ),
              control.visibleBounds.center.dy,
            ),
        };
        for (final entry in hoverTargets.entries) {
          if (options.ignoreProbe?.call(control, entry.key) == true) continue;
          final before = _checkPoint(
            tester: tester,
            surface: surface,
            control: control,
            probeName: entry.key,
            point: entry.value,
          );
          if (before != null) continue;

          await mouse.moveTo(entry.value);
          await tester.pump();
          await tester.pump(options.hoverSettleDuration);

          if (!control.element.mounted || !control.renderBox.attached) {
            findings.add(
              HitTestFinding(
                surface: surface,
                control: control.summary,
                kind: HitTestIssueKind.hoverUnstable,
                probeName: entry.key,
                point: entry.value,
                occluder: '<unmounted>',
                detail: 'control unmounted after hovering onto it',
              ),
            );
            break;
          }

          final after = _checkPoint(
            tester: tester,
            surface: surface,
            control: control,
            probeName: entry.key,
            point: entry.value,
          );
          if (after != null) {
            findings.add(
              HitTestFinding(
                surface: surface,
                control: control.summary,
                kind: HitTestIssueKind.hoverUnstable,
                probeName: entry.key,
                point: entry.value,
                occluder: after.occluder,
                detail:
                    'control became occluded after hovering (${after.detail})',
              ),
            );
          }
        }
      }
      if (ownedMouse) {
        await mouse.moveTo(Offset.zero);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }
    } finally {
      if (ownedMouse) await mouse.removePointer();
    }
  }

  return HitTestAuditReport(
    surface: surface,
    probedControls: controls.length,
    skippedControls: skipped,
    findings: findings,
  );
}
