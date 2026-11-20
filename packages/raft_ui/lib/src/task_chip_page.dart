part of 'task_chip_list.dart';

/// Web `TaskRowSelection` (components/task/TaskChipList.tsx): rows that can be
/// selected on the Tasks page. Facts and one callback; the app owns the
/// selection (its anchor, the range, the scope).
@immutable
class RaftTaskRowSelection {
  const RaftTaskRowSelection({
    required this.selecting,
    required this.isSelected,
    required this.onSelect,
  });

  /// Something is selected: every row shows its box and a tap selects.
  final bool selecting;
  final bool Function(String taskId) isSelected;

  /// The row was picked: [range] with Shift (a run from the last pick), else
  /// a toggle.
  final void Function(RaftTaskChipRow task, {required bool range}) onSelect;
}

/// Tailwind `inset-ring-2`: the keyboard focus ring of a row.
const double _focusRingWidth = 2;
const double _pageRowEndInset = 12;

/// The list's own width under which a row is narrow (Web `@max-md/tasks`,
/// 28rem of the page's `@container/tasks`): the channel moves into the
/// trailing group and the status keeps only its pixel.
const double raftTaskPageNarrowWidth = 448;

/// Web v1.24 `TaskChipList` `variant="page"` (components/task/TaskChipList.tsx,
/// compactRow.ts `COMPACT_LIST_PAGE`): the Tasks page's list, a box as wide as
/// the page with rows edge to edge, no chevron (a row opens the task beside the
/// list). With [selection] a row is a list cell: a check box in a left gutter
/// (on hover with a pointer, on every row while something is selected, on a
/// selected row), the title wrapping, the trailing group (channel, assignee,
/// status, time) wrapping as a whole onto a second line where the row is too
/// narrow for both.
///
/// Gestures (touch and pointer follow [RaftInteraction], never the width):
/// Cmd/Ctrl-click toggles, Shift-click asks for a range, any tap while
/// selecting toggles instead of opening, a long press by touch selects,
/// Enter/Space opens (selects while selecting).
class RaftTaskPageList extends StatelessWidget {
  const RaftTaskPageList({
    super.key,
    required this.tasks,
    required this.onOpen,
    this.showStatus = true,
    this.showChannel = false,
    this.showAssignee = true,
    this.showUnassigned = false,
    this.unassignedLabel,
    this.currentTaskId,
    this.selection,
    this.wrapTitle = true,
    this.rowWrap,
  });
  final List<RaftTaskChipRow> tasks;

  /// Wraps each row (its id and the row), for what the app marks a row with
  /// (the task slot's focus return). The row's key stays on the row.
  final Widget Function(String taskId, Widget row)? rowWrap;
  final ValueChanged<RaftTaskChipRow> onOpen;
  final bool showStatus;

  /// Across channels: the number names its channel (`#design:#25`).
  final bool showChannel;

  /// False where every row's assignee is the reader (Assigned to me).
  final bool showAssignee;

  /// Say [unassignedLabel] where nobody has the task.
  final bool showUnassigned;

  /// Web `task.filter.unassigned`, translated by the app (the shared
  /// catalog's "Unassigned" is another action's copy).
  final String? unassignedLabel;

  /// The task open beside the list: its row takes the selected-cell fill.
  final String? currentTaskId;
  final RaftTaskRowSelection? selection;

  /// The title takes the row's remaining width and wraps (breaking anywhere);
  /// false keeps it on one line, cut.
  final bool wrapTitle;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final radius = t.size('radius.container', fallback: 10);
    return LayoutBuilder(
      builder: (context, box) {
        final narrow =
            box.maxWidth.isFinite && box.maxWidth < raftTaskPageNarrowWidth;
        return DecoratedBox(
          key: const ValueKey('tasks-page-list'),
          decoration: BoxDecoration(
            color: t.ui.layerCard,
            border: Border.all(color: t.ui.lineHairline),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(RaftSpace.hairline),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < tasks.length; i++)
                    _wrapped(
                      tasks[i].id,
                      _PageRow(
                        key: ValueKey('tasks-page-row-${tasks[i].id}'),
                        task: tasks[i],
                        divider: i > 0,
                        narrow: narrow,
                        list: this,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

extension on RaftTaskPageList {
  Widget _wrapped(String id, Widget row) => rowWrap?.call(id, row) ?? row;
}

class _PageRow extends StatefulWidget {
  const _PageRow({
    super.key,
    required this.task,
    required this.divider,
    required this.narrow,
    required this.list,
  });
  final RaftTaskChipRow task;
  final bool divider, narrow;
  final RaftTaskPageList list;

  @override
  State<_PageRow> createState() => _PageRowState();
}

class _PageRowState extends State<_PageRow> {
  bool _hovered = false, _pressed = false, _boxFocused = false;
  final _boxFocus = FocusNode(debugLabel: 'tasks-page-row-select');

  @override
  void initState() {
    super.initState();
    _boxFocus.addListener(_boxFocusChanged);
  }

  @override
  void dispose() {
    _boxFocus
      ..removeListener(_boxFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _boxFocusChanged() {
    if (_boxFocused != _boxFocus.hasFocus) {
      setState(() => _boxFocused = _boxFocus.hasFocus);
    }
  }

  RaftTaskRowSelection? get _selection => widget.list.selection;

  /// A click (a tap, Enter, Space) on the row: selects while selecting, with
  /// Cmd/Ctrl or Shift; else opens.
  void _activate() {
    final sel = _selection;
    if (sel != null) {
      final keys = HardwareKeyboard.instance;
      final shift = keys.isShiftPressed;
      if (sel.selecting ||
          keys.isMetaPressed ||
          keys.isControlPressed ||
          shift) {
        sel.onSelect(widget.task, range: shift);
        return;
      }
    }
    widget.list.onOpen(widget.task);
  }

  void _longPress() {
    final sel = _selection;
    if (sel == null) return;
    HapticFeedback.selectionClick();
    sel.onSelect(widget.task, range: false);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final list = widget.list;
    final task = widget.task;
    final sel = _selection;
    final touch = RaftInteraction.of(context).touch;
    final selected = sel?.isSelected(task.id) ?? false;
    final current = list.currentTaskId == task.id;
    final selecting = sel?.selecting ?? false;

    final base = selected || current ? t.colors['fill-cell-selected'] : null;
    final overlay = _pressed
        ? t.colors['fill-medium']
        : _hovered
        ? t.colors['fill-subtle']
        : null;
    final fill = base == null
        ? overlay
        : overlay == null
        ? base
        : Color.alphaBlend(overlay, base);

    final boxShown = selecting || selected;
    // `pl-3 md:pointer-fine:pl-2` and the 20px box: the gutter at the cell's
    // inner start, as tall as the row.
    final gutterWidth = sel == null ? 0.0 : (t.desktop ? 8.0 : 12.0) + 20;
    final gutter = sel == null
        ? null
        : GestureDetector(
            // The gutter around the box opens the task, as the rest of the row.
            behavior: HitTestBehavior.opaque,
            onTap: _activate,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: t.desktop ? 8 : 12),
              child: Center(
                widthFactor: 1,
                child: SizedBox.square(
                  dimension: 20,
                  child: touch && !boxShown
                      ? null
                      : Opacity(
                          opacity:
                              boxShown || (!touch && (_hovered || _boxFocused))
                              ? 1
                              : 0,
                          alwaysIncludeSemantics: true,
                          child: RaftCheckbox(
                            key: ValueKey('tasks-page-row-select-${task.id}'),
                            value: selected,
                            focusNode: _boxFocus,
                            semanticLabel: raftFormat(
                              context,
                              'Select #{taskNumber} {title}',
                              {'taskNumber': task.number, 'title': task.title},
                            ),
                            onChanged: (_) => sel.onSelect(
                              task,
                              range: HardwareKeyboard.instance.isShiftPressed,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          );

    final opens = raftFormat(context, 'Open task #{number}: {title}', {
      'number': task.number,
      'title': task.title,
    });
    final open = task.replyCount > 0 || task.unread
        ? '$opens, ${raftTaskChipRepliesLabel(context, count: task.replyCount, unread: task.unread)}'
        : opens;
    final minHeight = t.desktop ? RaftDesktopMetrics.rowHeight : 44.0;
    final vertical = t.desktop ? 5.5 : 6.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (e) {
          if (e.buttons & kPrimaryButton != 0) setState(() => _pressed = true);
        },
        onPointerUp: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        child: DecoratedBox(
          key: ValueKey('tasks-page-row-cell-${task.id}'),
          decoration: BoxDecoration(
            color: fill,
            border: Border(
              top: widget.divider
                  ? BorderSide(color: t.ui.lineHairline)
                  : BorderSide.none,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(start: gutterWidth),
                child: RaftInteractive(
                  semanticLabel: open,
                  // The status is an icon alone where the list is narrow: say
                  // it after the label.
                  semanticValue: list.showStatus
                      ? raftText(context, raftTaskStatusLabel(task.status))
                      : null,
                  selected: current,
                  expandTouchTarget: false,
                  onPressed: _activate,
                  onLongPress: touch && sel != null ? _longPress : null,
                  builder: (context, state) => DecoratedBox(
                    key: ValueKey('tasks-page-row-open-${task.id}'),
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      // `focus-visible:inset-ring-2 inset-ring-ink`.
                      border: state.focusVisible
                          ? Border.all(color: t.ink, width: _focusRingWidth)
                          : null,
                    ),
                    child: ExcludeSemantics(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              sel == null ? 12 : 8,
                              vertical,
                              _pageRowEndInset,
                              vertical,
                            ),
                            child: _PageRowContent(
                              task: task,
                              list: list,
                              narrow: widget.narrow,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (gutter != null)
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: gutterWidth,
                  child: gutter,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageRowContent extends StatelessWidget {
  const _PageRowContent({
    required this.task,
    required this.list,
    required this.narrow,
  });
  final RaftTaskChipRow task;
  final RaftTaskPageList list;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final callout = t.scale(RaftTypeScale.callout);
    final mono = t
        .scale(RaftTypeScale.monoMeta, mono: true, color: t.ui.foregroundHint)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final lineMono = mono.copyWith(
      height: callout.fontSize! * callout.height! / mono.fontSize!,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final number = '#${task.number}';
    final lead = list.showChannel && !narrow && task.ref != null
        ? task.ref!
        : number;
    final channel =
        list.showChannel &&
            narrow &&
            task.channelName != null &&
            task.channelName!.isNotEmpty
        ? '#${task.channelName!.replaceFirst(RegExp('^#'), '')}'
        : null;
    final assigned = task.assigneeName != null;
    final showAssignee = list.showAssignee && assigned;
    final unassigned = list.showAssignee && list.showUnassigned && !assigned;
    final statusLabel = raftText(context, raftTaskStatusLabel(task.status));
    final titleStyle = t.scale(
      RaftTypeScale.callout,
      weight: FontWeight.w400,
      color: t.ui.foreground,
    );
    return _RowFlow(
      gap: 8,
      rowGap: 4,
      basis: 160,
      children: [
        RaftCssText(
          lead,
          key: const ValueKey('message-task-chip-number'),
          style: lineMono,
        ),
        Row(
          key: const ValueKey('message-task-chip-title-group'),
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: 6,
          children: [
            Flexible(
              child: list.wrapTitle
                  ? RaftCssText(
                      task.title,
                      key: const ValueKey('message-task-chip-title'),
                      style: titleStyle,
                      softWrap: true,
                    )
                  : Text(
                      task.title,
                      key: const ValueKey('message-task-chip-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
            ),
            if (task.replyCount > 0 || task.unread)
              RaftTaskReplyCount(task: task, style: lineMono),
          ],
        ),
        Wrap(
          key: const ValueKey('message-task-chip-meta'),
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            if (channel != null)
              RaftCssText(
                channel,
                key: const ValueKey('message-task-chip-channel'),
                style: lineMono,
              ),
            if (unassigned)
              Text(
                unassignedLabel(list),
                key: const ValueKey('message-task-chip-unassigned'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.scale(
                  RaftTypeScale.caption,
                  color: t.ui.foregroundHint,
                ),
              ),
            if (showAssignee) RaftTaskAssignee(task: task),
            if (list.showStatus)
              KeyedSubtree(
                key: const ValueKey('message-task-chip-status'),
                child: RaftTaskStatusBadge(
                  status: raftTaskStatusOf(task.status),
                  label: statusLabel,
                  labelHidden: list.showChannel && narrow,
                ),
              ),
            ?task.time,
          ],
        ),
      ],
    );
  }

  String unassignedLabel(RaftTaskPageList list) =>
      list.unassignedLabel ?? 'Unassigned';
}

/// The page row's flex-wrap line (compactRow.ts `COMPACT_ROW_BODY`): the
/// number, the title group taking the rest of the line, and the trailing group
/// at the right, all on the first baseline. The trailing group wraps, whole,
/// onto a second line (still at the right) when the line cannot hold it beside
/// a readable title ([basis] wide).
class _RowFlow extends MultiChildRenderObjectWidget {
  const _RowFlow({
    required super.children,
    required this.gap,
    required this.rowGap,
    required this.basis,
  });
  final double gap, rowGap, basis;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRowFlow(gap: gap, rowGap: rowGap, basis: basis);

  @override
  void updateRenderObject(BuildContext context, _RenderRowFlow renderObject) {
    renderObject
      ..gap = gap
      ..rowGap = rowGap
      ..basis = basis;
  }
}

class _RowFlowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderRowFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RowFlowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RowFlowParentData> {
  _RenderRowFlow({
    required double gap,
    required double rowGap,
    required double basis,
  }) : _gap = gap,
       _rowGap = rowGap,
       _basis = basis;

  double _gap, _rowGap, _basis;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  set rowGap(double v) {
    if (v == _rowGap) return;
    _rowGap = v;
    markNeedsLayout();
  }

  set basis(double v) {
    if (v == _basis) return;
    _basis = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowFlowParentData) {
      child.parentData = _RowFlowParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final lead = firstChild!;
    final title = childAfter(lead)!;
    final trail = childAfter(title)!;
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : constraints.minWidth;
    Size measure(RenderBox box, BoxConstraints c) {
      if (dry) return box.getDryLayout(c);
      box.layout(c, parentUsesSize: true);
      return box.size;
    }

    double baseline(RenderBox box, BoxConstraints c, Size s) {
      final b = dry
          ? box.getDryBaseline(c, TextBaseline.alphabetic)
          : box.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true);
      return b ?? s.height / 2;
    }

    final loose = BoxConstraints(maxWidth: width);
    final leadSize = measure(lead, loose);
    final trailConstraints = BoxConstraints(maxWidth: width + _pageRowEndInset);
    final trailSize = measure(trail, trailConstraints);
    final fits =
        leadSize.width + _gap + _basis + _gap + trailSize.width <= width + .5;
    final titleWidth =
        (fits
                ? width - leadSize.width - trailSize.width - 2 * _gap
                : width - leadSize.width - _gap)
            .clamp(0.0, double.infinity);
    final titleConstraints = BoxConstraints(
      minWidth: titleWidth,
      maxWidth: titleWidth,
    );
    final titleSize = measure(title, titleConstraints);

    final leadBase = baseline(lead, loose, leadSize);
    final titleBase = baseline(title, titleConstraints, titleSize);
    var ascent = leadBase > titleBase ? leadBase : titleBase;
    var descent = (leadSize.height - leadBase) > (titleSize.height - titleBase)
        ? leadSize.height - leadBase
        : titleSize.height - titleBase;
    double trailBase = 0;
    if (fits) {
      trailBase = baseline(trail, trailConstraints, trailSize);
      if (trailBase > ascent) ascent = trailBase;
      final d = trailSize.height - trailBase;
      if (d > descent) descent = d;
    }
    final lineHeight = ascent + descent;
    var height = lineHeight;
    if (!dry) {
      (lead.parentData as _RowFlowParentData).offset = Offset(
        0,
        ascent - leadBase,
      );
      (title.parentData as _RowFlowParentData).offset = Offset(
        leadSize.width + _gap,
        ascent - titleBase,
      );
      if (fits) {
        (trail.parentData as _RowFlowParentData).offset = Offset(
          width - trailSize.width,
          ascent - trailBase,
        );
      } else {
        (trail.parentData as _RowFlowParentData).offset = Offset(
          (width - trailSize.width).clamp(0.0, width),
          lineHeight + _rowGap,
        );
      }
    }
    if (!fits) height = lineHeight + _rowGap + trailSize.height;
    return constraints.constrain(Size(width, height));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
