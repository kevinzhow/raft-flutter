import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:raft_ui/raft_ui.dart';

import 'timeline_row_trace.dart';

typedef TimelinePreviewExtent = ({
  double height,
  bool preparing,
  RaftMessageCollapseLayout? collapse,
});

typedef TimelineRowPreviewBuilder = Widget? Function(
  BuildContext context,
  int index,
  TimelinePreviewExtent extent,
);

typedef TimelineRowHydrationSpec = ({
  double width,
  double Function() estimate,
  Widget? Function(BuildContext, TimelinePreviewExtent) preview,
  bool Function() entering,
});

typedef TimelineRowRevision = ({Object layout, Object invalidation});

typedef TimelineRowMeasurement = ({
  String id,
  Object content,
  Object? style,
  int width,
  TextScaler scale,
});

typedef _MeasuredRow = ({double height, RaftMessageCollapseLayout? collapse});

class TimelineRowHydrator {
  TimelineRowHydrator({
    required this.isVisible,
    required this.direction,
    required this.beforeSwap,
    required this.prepareEdit,
  });

  final bool Function() isVisible;
  final ScrollDirection Function() direction;
  final void Function(RenderBox row) beforeSwap;
  final void Function(double extra) prepareEdit;
  final _versions = Expando<Object>();
  final _measurements = <TimelineRowMeasurement, _MeasuredRow>{};
  final _pending = <_TimelineHydratedRowState>{};
  bool _scheduled = false;
  _TimelineHydratedRowState? _preparing;
  _TimelineHydratedRowState? _reserved;
  Duration? _fullBuildFrame;

  bool _claimColdBuild() {
    if (_preparing == null) return true;
    final frame = SchedulerBinding.instance.currentFrameTimeStamp;
    if (_reserved != null || _fullBuildFrame == frame) return false;
    _fullBuildFrame = frame;
    return true;
  }

  void _startSwap(_TimelineHydratedRowState row) {
    if (_reserved == row) _reserved = null;
    _fullBuildFrame = SchedulerBinding.instance.currentFrameTimeStamp;
  }

  ({RenderBox box, RenderViewport viewport})? _geometry(
    _TimelineHydratedRowState row,
  ) {
    final box = row.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final host = RenderAbstractViewport.maybeOf(box);
    return host is RenderViewport && _laidOut(box, host)
        ? (box: box, viewport: host)
        : null;
  }

  void _add(_TimelineHydratedRowState row) {
    _pending.add(row);
    schedule();
  }

  void schedule() {
    if (_scheduled ||
        (_pending.isEmpty && _preparing == null) ||
        !isVisible()) {
      return;
    }
    _scheduled = true;
    // ignore: raft_lints/avoid_unreviewed_idle_work -- consumes one mounted row per frame and only continues while rows are waiting
    SchedulerBinding.instance.addPostFrameCallback(_hydrate);
  }

  void _hydrate(Duration _) {
    _scheduled = false;
    if (!isVisible()) return;
    final budget = Stopwatch()..start();
    final motion = direction();
    _TimelineHydratedRowState? nearest;
    RenderBox? nearestBox;
    var best = double.infinity;
    for (final row in _pending) {
      if (_preparing != null && row._phase == _HydrationPhase.editing) {
        continue;
      }
      final geometry = _geometry(row);
      if (geometry == null) continue;
      final (box: box, viewport: host) = geometry;
      final top = box.localToGlobal(Offset.zero, ancestor: host).dy;
      final bottom = top + box.size.height;
      final viewport = host.size.height;
      final distance = top >= viewport
          ? top - viewport + (motion == ScrollDirection.forward ? viewport : 0)
          : bottom <= 0
          ? -bottom + (motion == ScrollDirection.reverse ? viewport : 0)
          : 0.0;
      if (distance < best) {
        nearest = row;
        nearestBox = box;
        best = distance;
      }
      if (budget.elapsedMicroseconds >= 3000) break;
    }
    if (nearest == null) {
      final edit = _preparing;
      if (edit == null) return;
      final box = _pending.contains(edit) ? _geometry(edit)?.box : null;
      if (box == null) {
        _finishPreparation();
        schedule();
        return;
      }
      nearest = edit;
      nearestBox = box;
    } else if (_preparing == null && nearest._mayRevealRows(nearestBox!)) {
      _preparing = nearest;
      prepareEdit(nearestBox.size.height);
      schedule();
      return;
    }
    final row = nearest;
    final finishing = row == _preparing;
    _pending.remove(row);
    _reserved = row;
    beforeSwap(nearestBox!);
    row.hydrate();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_reserved == row) _reserved = null;
      if (finishing && _preparing == row) {
        _finishPreparation();
        schedule();
      }
    });
    if (!finishing) schedule();
  }

  void _finishPreparation() {
    _preparing = null;
    prepareEdit(0);
  }

  static bool _laidOut(RenderBox box, RenderViewport viewport) {
    RenderObject child = box;
    for (var parent = child.parent; parent != null; parent = child.parent) {
      if (!parent.paintsChild(child)) return false;
      if (parent == viewport) return true;
      child = parent;
    }
    return false;
  }

  void _record(TimelineRowMeasurement key, _MeasuredRow measurement) {
    _measurements.remove(key);
    _measurements[key] = measurement;
    if (_measurements.length > 1024) {
      _measurements.remove(_measurements.keys.first);
    }
  }
}

class TimelineHydratedRow extends StatefulWidget {
  const TimelineHydratedRow({
    super.key,
    required this.hydrator,
    required this.message,
    required this.revision,
    required this.width,
    required this.estimate,
    required this.preview,
    required this.builder,
    required this.entering,
  });

  final TimelineRowHydrator hydrator;
  final chat.Message message;
  final Object? revision;
  final double width;
  final double Function() estimate;
  final Widget? Function(BuildContext, TimelinePreviewExtent) preview;
  final WidgetBuilder builder;
  final bool entering;

  @override
  State<TimelineHydratedRow> createState() => _TimelineHydratedRowState();
}

enum _HydrationPhase { preview, light, full, editing, swapping }

class _TimelineHydratedRowState extends State<TimelineHydratedRow> {
  Widget? _layout;
  late var _phase = widget.entering
      ? _HydrationPhase.preview
      : _HydrationPhase.full;

  void hydrate() => setState(() {
    _layout = null;
    _phase = _HydrationPhase.swapping;
  });

  Object? _layoutRevision(TimelineHydratedRow row) => switch (row.revision) {
    final TimelineRowRevision revision => revision.layout,
    final revision => revision,
  };

  @override
  void didUpdateWidget(TimelineHydratedRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((_phase == _HydrationPhase.full || _phase == _HydrationPhase.editing) &&
        _layout != null &&
        _layoutRevision(oldWidget) == _layoutRevision(widget) &&
        _canDeferEdit(oldWidget.message, widget.message)) {
      _phase = _HydrationPhase.editing;
      widget.hydrator._add(this);
      return;
    }
    _phase = switch (_phase) {
      _HydrationPhase.light => _HydrationPhase.preview,
      _HydrationPhase.editing || _HydrationPhase.full => _HydrationPhase.full,
      _ => _phase,
    };
    _layout = null;
    widget.hydrator._pending.remove(this);
  }

  bool _canDeferEdit(chat.Message before, chat.Message after) {
    if (identical(before, after) || before.authorId != after.authorId) {
      return false;
    }
    final old = before.metadata;
    final next = after.metadata;
    return old?['content'] != next?['content'] &&
        old?['deletedAt'] == next?['deletedAt'] &&
        next?['messageType'] != 'system' &&
        _sameActionContent(old?['actionMetadata'], next?['actionMetadata']);
  }

  bool _sameActionContent(Object? before, Object? after) =>
      identical(before, after) ||
      (before is Map &&
          after is Map &&
          before['kind'] == 'forwarded-bundle' &&
          after['kind'] == 'forwarded-bundle' &&
          jsonEncode(before) == jsonEncode(after));

  bool _mayRevealRows(RenderBox box) =>
      _phase == _HydrationPhase.editing &&
      box.size.height - widget.estimate() > 128;

  @override
  Widget build(BuildContext context) {
    if (_layout case final layout?) return layout;
    final message = widget.message;
    final hydrator = widget.hydrator;
    final key = (
      id: message.id,
      content: hydrator._versions[message] ??= Object(),
      style: _layoutRevision(widget),
      width: widget.width.round(),
      scale: MediaQuery.textScalerOf(context),
    );
    if (_phase == _HydrationPhase.preview) {
      final measured = hydrator._measurements[key];
      final extent = (
        height:
            measured?.height ?? widget.estimate() * (key.scale.scale(15) / 15),
        preparing: hydrator._preparing != null,
        collapse: measured?.collapse,
      );
      final preview = timelineRowTrace(
        'light.build',
        message.id,
        () => widget.preview(context, extent),
      );
      if (preview != null || !hydrator._claimColdBuild()) {
        _phase = _HydrationPhase.light;
        hydrator._add(this);
        return _layout = _TimelineMeasuredRow(
          id: message.id,
          child:
              preview ??
              SizedBox(
                height: extent.height,
                child: Text(
                  (message.metadata?['content'] ?? '').toString(),
                  maxLines: 2,
                ),
              ),
        );
      }
    }
    final Widget child;
    if (_phase == _HydrationPhase.swapping) {
      hydrator._startSwap(this);
      child = timelineRowTrace(
        'hydrate',
        message.id,
        () => widget.builder(context),
      );
    } else {
      child = widget.builder(context);
    }
    _phase = _HydrationPhase.full;
    RaftMessageCollapseLayout? collapse;
    return _layout = _TimelineMeasuredRow(
      id: message.id,
      onLayout: (size) {
        if (size.width.round() == key.width) {
          hydrator._record(key, (height: size.height, collapse: collapse));
        }
      },
      child: RaftMessageCollapseObserver(
        tile: ValueKey('message-${message.id}'),
        record: (layout) => collapse = layout,
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    widget.hydrator._pending.remove(this);
    super.dispose();
  }
}

class TimelineHydrationAnchor {
  const TimelineHydrationAnchor(
    this.box,
    this.offset,
    this.changing,
    this.height,
  );

  final RenderBox box;
  final double offset;
  final RenderBox changing;
  final double height;

  static TimelineHydrationAnchor? capture(
    RenderViewport view,
    RenderBox changing,
    Iterable<RenderBox> rows,
  ) {
    RenderBox? firstVisible;
    var leading = double.infinity;
    for (final row in rows) {
      if (row == changing || !TimelineRowHydrator._laidOut(row, view)) {
        continue;
      }
      final top = row.localToGlobal(Offset.zero, ancestor: view).dy;
      if (top >= view.size.height ||
          top >= leading ||
          top + row.size.height <= 0) {
        continue;
      }
      firstVisible = row;
      leading = top;
    }
    return firstVisible == null
        ? null
        : TimelineHydrationAnchor(
            firstVisible,
            view.getOffsetToReveal(firstVisible, 0).offset,
            changing,
            changing.size.height,
          );
  }

  double? correction(RenderViewport view) {
    if (!changing.attached ||
        !changing.hasSize ||
        (changing.size.height - height).abs() <= .5 ||
        !box.attached ||
        !TimelineRowHydrator._laidOut(box, view)) {
      return null;
    }
    return view.getOffsetToReveal(box, 0).offset - offset;
  }
}

class _TimelineMeasuredRow extends SingleChildRenderObjectWidget {
  const _TimelineMeasuredRow({
    required this.id,
    this.onLayout,
    required super.child,
  });

  final String id;
  final ValueChanged<Size>? onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTimelineMeasuredRow(id, onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderTimelineMeasuredRow renderObject,
  ) => renderObject
    ..id = id
    ..onLayout = onLayout;
}

class _RenderTimelineMeasuredRow extends RenderProxyBox {
  _RenderTimelineMeasuredRow(this.id, this.onLayout);

  String id;
  ValueChanged<Size>? onLayout;

  @override
  void performLayout() {
    final record = onLayout;
    if (record == null) {
      timelineRowTrace('light.layout', id, super.performLayout);
    } else {
      super.performLayout();
      record(size);
    }
  }
}

class TimelineWidth extends StatefulWidget {
  const TimelineWidth({super.key, required this.builder});

  final Widget Function(BuildContext, double) builder;

  @override
  State<TimelineWidth> createState() => _TimelineWidthState();
}

class _TimelineWidthState extends State<TimelineWidth> {
  double? _width;

  @override
  Widget build(BuildContext context) => _TimelineWidthObserver(
    onWidth: (width) {
      if (mounted && _width != width) setState(() => _width = width);
    },
    child: widget.builder(context, _width ?? MediaQuery.sizeOf(context).width),
  );
}

class _TimelineWidthObserver extends SingleChildRenderObjectWidget {
  const _TimelineWidthObserver({required this.onWidth, required super.child});

  final ValueChanged<double> onWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTimelineWidthObserver(onWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderTimelineWidthObserver renderObject,
  ) => renderObject.onWidth = onWidth;
}

class _RenderTimelineWidthObserver extends RenderProxyBox {
  _RenderTimelineWidthObserver(this.onWidth);

  ValueChanged<double> onWidth;
  double? _width;

  @override
  void performLayout() {
    super.performLayout();
    final width = size.width;
    if (_width == width) return;
    _width = width;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached && _width == width) onWidth(width);
    });
  }
}

class TimelineRowPreview extends StatelessWidget {
  const TimelineRowPreview({
    super.key,
    required this.tile,
    required this.height,
    required this.linkGroups,
    required this.onLink,
    this.collapse,
    this.onExpandedChanged,
  });

  final RaftMessageTile tile;
  final double height;
  final List<List<RaftMessageSemanticsLink>> linkGroups;
  final ValueChanged<String> onLink;
  final RaftMessageCollapseLayout? collapse;
  final void Function(bool, BuildContext)? onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final text = raftMessageSemanticsText(
      context,
      tile.semanticsContent ?? tile.content,
    );
    final excerpt = raftMessageSemanticsExcerpt(
      text,
      collapse?.visibleFraction,
    );
    final lineEnd = excerpt.indexOf('\n');
    final firstLine = lineEnd < 0 ? excerpt : excerpt.substring(0, lineEnd);
    final visibleReactions = tile.visibleReactions;
    final heading = tile.compactHeading(visibleReactions);
    final actions = tile.compactActions(visibleReactions);
    // Like the full row: a collapsed row publishes no link actions.
    final links =
        tile.coarsePointer &&
            collapse?.expanded != false &&
            linkGroups.any((group) => group.isNotEmpty)
        ? RaftMessageLinkActions()
        : null;
    Widget body = ExcludeSemantics(
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: RaftSpace.x4,
            top: RaftSpace.x1,
            end: RaftSpace.x4,
          ),
          child: Text(
            '${tile.author}\n$firstLine',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
    if (linkGroups.isNotEmpty &&
        (links != null || collapse?.expanded != false)) {
      body = Stack(
        fit: StackFit.expand,
        children: [
          body,
          for (final group in linkGroups)
            RaftMessageProseSemantics(
              links: group,
              onLink: onLink,
              linkActions: links,
              child: const SizedBox.shrink(),
            ),
        ],
      );
    }
    if (collapse case final layout? when onExpandedChanged != null) {
      body = Stack(
        fit: StackFit.expand,
        children: [
          body,
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: RaftSpace.x4),
              child: RaftShowMoreToggle(
                label: raftText(
                  context,
                  layout.expanded ? 'Collapse' : 'Show More',
                ),
                expanded: layout.expanded,
                onPressed: () => onExpandedChanged!(
                  !layout.expanded,
                  context
                          .findAncestorStateOfType<_TimelineHydratedRowState>()
                          ?.context ??
                      context,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return RaftMessageRowSemantics(
      label: excerpt.isEmpty ? heading : '$heading\n$excerpt',
      actions: [
        for (final action in actions) action.label,
        if (tile.onAuthor != null)
          raftFormat(context, 'Mention {name}', {'name': tile.author}),
      ],
      onAction: (index) {
        if (index < actions.length) {
          actions[index].onInvoke(context);
        } else {
          tile.onAuthor?.call();
        }
      },
      onLongPress: () {
        final box = context.findRenderObject();
        tile.onActionsAt?.call(
          box is RenderBox && box.hasSize
              ? box.localToGlobal(box.size.center(Offset.zero))
              : Offset.zero,
        );
      },
      linkActions: links,
      child: ClipRect(
        child: SizedBox(height: height, child: body),
      ),
    );
  }
}
