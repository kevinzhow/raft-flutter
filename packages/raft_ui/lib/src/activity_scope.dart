import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'control_typography.dart';
import 'form_controls.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'indicators.dart';
import 'localization.dart';
import 'select_field.dart';
import 'text_scaling.dart' show RaftScaled;
import 'theme.dart';
import 'recipe_surface.dart' show RaftCssBoxDecoration;

/// Mounted ThreadsInbox views; the application owns each accepted result scope.
enum RaftActivityView {
  all('All', RaftGlyph.inbox),
  unread('Unread', RaftGlyph.mail),
  mentions('Mentions', RaftGlyph.atSign),
  saved('Saved', RaftGlyph.bookmark),
  dms('DMs', RaftGlyph.messageCircle),
  done('Done', RaftGlyph.checkCircle2);

  const RaftActivityView(this.label, this.glyph);
  final String label;
  final RaftGlyph glyph;
}

/// Presentation data only. The application owns accepted facets and authority.
class RaftActivityGroup {
  const RaftActivityGroup({
    required this.id,
    required this.label,
    required this.count,
    this.dm = false,
    this.icon,
  });
  final String id, label;
  final int count;
  final bool dm;
  final Widget? icon;
}

/// ThreadsInbox compact master toolbar (88px) or mobile view strip (54px).
/// MainLayout mounts compactActivitySidebar for the desktop Activity master.
class RaftActivityScopeToolbar extends StatelessWidget {
  const RaftActivityScopeToolbar({
    super.key,
    required this.view,
    required this.compact,
    required this.onView,
    required this.onOpenSwitcher,
    required this.sort,
    required this.onSort,
    this.scopeLabel,
    this.markAllRead,
    this.search,
  });
  final RaftActivityView view;
  final bool compact;
  final ValueChanged<RaftActivityView> onView;
  final VoidCallback onOpenSwitcher;
  final String sort;
  final ValueChanged<String> onSort;
  final String? scopeLabel;
  final Widget? markAllRead, search;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      key: const ValueKey('activity-enabled-toolbar'),
      height: compact ? null : 54,
      constraints: compact ? const BoxConstraints(minHeight: 88) : null,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 8 : 0),
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(
          bottom: BorderSide(color: t.line, width: t.border),
        ),
      ),
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                _ActivityButton(
                  key: const ValueKey('activity-scope-switcher'),
                  label:
                      '${raftText(context, view.label)}${scopeLabel == null ? '' : ' · $scopeLabel'}',
                  onPressed: onOpenSwitcher,
                  height: 32,
                  border: true,
                  strongBorder: true,
                  shadowed: true,
                  child: Row(
                    spacing: 8,
                    children: [
                      RaftIcon(view.glyph, size: 14),
                      Text(raftText(context, view.label)),
                      if (scopeLabel != null) ...[
                        Container(width: 1, height: 16, color: t.line),
                        Expanded(
                          child: Text(
                            scopeLabel!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      RaftIcon(RaftGlyph.chevronDown, size: 14, color: t.muted),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) => _ActivityToolbarControls(
                    width: constraints.maxWidth,
                    direction: Directionality.of(context),
                    search: search,
                    read: markAllRead,
                    sort: SizedBox(
                      height: RaftScaled.extent(context, 32),
                      child: RaftSelectField<String>(
                        value: sort,
                        label: raftText(context, 'Sort Activity'),
                        visualHeight: 32,
                        minimumTargetHeight: 32,
                        items: [
                          for (final entry in const {
                            'desc': 'Newest',
                            'asc': 'Oldest',
                          }.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(
                                raftText(context, entry.value),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) onSort(value);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              spacing: 12,
              children: [
                Expanded(
                  child: _ActivityViewStrip(view: view, onView: onView),
                ),
                ?markAllRead,
              ],
            ),
    );
  }
}

// Measure the action itself: its localized label, recipe padding and text
// scaling determine the space available for search and sort. A render layout
// keeps the same input element when it moves between one and two rows.
class _ActivityToolbarControls extends MultiChildRenderObjectWidget {
  _ActivityToolbarControls({
    required this.width,
    required this.direction,
    required Widget sort,
    Widget? search,
    Widget? read,
  }) : hasSearch = search != null,
       hasRead = read != null,
       super(
         children: [
           search ?? const SizedBox.shrink(),
           sort,
           read ?? const SizedBox.shrink(),
         ],
       );

  final double width;
  final TextDirection direction;
  final bool hasSearch, hasRead;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderActivityToolbarControls(this);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderActivityToolbarControls renderObject,
  ) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _ActivityToolbarParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderActivityToolbarControls extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ActivityToolbarParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ActivityToolbarParentData> {
  _RenderActivityToolbarControls(this.config);
  _ActivityToolbarControls config;
  static const _gap = 8.0, _minimumSearch = 64.0, _minimumSort = 64.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ActivityToolbarParentData) {
      child.parentData = _ActivityToolbarParentData();
    }
  }

  Size _layout(
    BoxConstraints constraints,
    ChildLayouter layoutChild, {
    bool position = false,
  }) {
    final search = firstChild!, sort = childAfter(search)!, read = lastChild!;
    final width = constraints.constrainWidth(config.width);
    final readSize = layoutChild(read, BoxConstraints(maxWidth: width));
    final available = math.max(
      0.0,
      width - readSize.width - (config.hasRead ? _gap : 0),
    );
    final wrapped =
        config.hasSearch && available < _minimumSearch + _gap + _minimumSort;
    final sortWidth = math.min(
      116.0,
      config.hasSearch && !wrapped
          ? available - _minimumSearch - _gap
          : available,
    );
    final sortSize = layoutChild(
      sort,
      BoxConstraints.tightFor(width: sortWidth),
    );
    final searchSize = layoutChild(
      search,
      BoxConstraints.tightFor(
        width: config.hasSearch
            ? wrapped
                  ? width
                  : available - sortWidth - _gap
            : 0,
      ),
    );
    final controlsHeight = math.max(readSize.height, sortSize.height);
    final height = config.hasSearch
        ? wrapped
              ? searchSize.height + _gap + controlsHeight
              : math.max(searchSize.height, controlsHeight)
        : controlsHeight;
    if (position) {
      void place(RenderBox child, Size size, double x, double y) {
        (child.parentData! as _ActivityToolbarParentData).offset = Offset(
          config.direction == TextDirection.rtl ? width - x - size.width : x,
          y,
        );
      }

      final top = wrapped
          ? searchSize.height + _gap
          : (height - controlsHeight) / 2;
      place(
        search,
        searchSize,
        0,
        wrapped ? 0 : (height - searchSize.height) / 2,
      );
      place(
        sort,
        sortSize,
        available - sortSize.width,
        top + (controlsHeight - sortSize.height) / 2,
      );
      place(
        read,
        readSize,
        width - readSize.width,
        top + (controlsHeight - readSize.height) / 2,
      );
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  void performLayout() {
    size = _layout(constraints, ChildLayoutHelper.layoutChild, position: true);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _ActivityViewStrip extends StatefulWidget {
  const _ActivityViewStrip({required this.view, required this.onView});
  final RaftActivityView view;
  final ValueChanged<RaftActivityView> onView;
  @override
  State<_ActivityViewStrip> createState() => _ActivityViewStripState();
}

class _ActivityViewStripState extends State<_ActivityViewStrip> {
  final anchors = {
    for (final view in RaftActivityView.values) view: GlobalKey(),
  };

  void revealSelected({bool forward = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = anchors[widget.view]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignmentPolicy: forward
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    revealSelected();
  }

  @override
  void didUpdateWidget(_ActivityViewStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view) {
      revealSelected(forward: widget.view.index > oldWidget.view.index);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      spacing: 4,
      children: [
        for (final value in RaftActivityView.values)
          KeyedSubtree(
            key: anchors[value],
            child: _ActivityButton(
              key: ValueKey('activity-view-${value.name}'),
              label: raftText(context, value.label),
              onPressed: () => widget.onView(value),
              selected: widget.view == value,
              shadowed: widget.view == value,
              border: true,
              height: 32,
              child: Text(raftText(context, value.label)),
            ),
          ),
      ],
    ),
  );
}

/// DialogCard's shared view/group content. Source closes on any selection;
/// the caller owns the route and accepted request scope.
class RaftActivityScopePicker extends StatelessWidget {
  const RaftActivityScopePicker({
    super.key,
    required this.view,
    required this.onView,
    required this.groups,
    required this.onGroup,
    required this.onClearGroup,
    this.selectedGroup,
    this.counts = const {},
  });
  final RaftActivityView view;
  final ValueChanged<RaftActivityView> onView;
  final List<RaftActivityGroup> groups;
  final ValueChanged<String> onGroup;
  final VoidCallback onClearGroup;
  final String? selectedGroup;
  final Map<RaftActivityView, int> counts;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hiddenCounts = [
      RaftActivityView.saved,
      RaftActivityView.dms,
      RaftActivityView.done,
    ].contains(view);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .68,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              spacing: 4,
              children: [
                for (final value in RaftActivityView.values)
                  _ActivityButton(
                    key: ValueKey('activity-switcher-nav-${value.name}'),
                    label: raftText(context, value.label),
                    selected: view == value,
                    onPressed: () => onView(value),
                    dialog: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      spacing: 12,
                      children: [
                        RaftIcon(value.glyph, size: 18),
                        Expanded(child: Text(raftText(context, value.label))),
                        if (counts[value] case final count?
                            when count > 0 || value == RaftActivityView.all)
                          Text(
                            '$count',
                            style: RaftTypography.mono(
                              t,
                              size: 14,
                              line: 20,
                              color: t.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      raftText(context, 'DM and Channels'),
                      style: RaftTypography.body(
                        t,
                        size: 12,
                        line: 16,
                        weight: RaftTypography.black(t),
                        color: t.muted,
                      ),
                    ),
                  ),
                  if (selectedGroup != null)
                    _ActivityButton(
                      key: const ValueKey('activity-clear-channel-filter'),
                      label: raftText(context, 'Clear Filters'),
                      onPressed: onClearGroup,
                      fontSize: 10,
                      padding: const EdgeInsets.all(4),
                      child: Text(raftText(context, 'Clear Filters')),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Column(
              spacing: 4,
              children: [
                for (final group in groups)
                  _ActivityButton(
                    key: ValueKey('activity-switcher-group-${group.id}'),
                    label: group.label,
                    selected: selectedGroup == group.id,
                    onPressed: () => onGroup(group.id),
                    dialog: true,
                    border: true,
                    group: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      spacing: 12,
                      children: [
                        group.icon ?? RaftActivityGroupIcon(dm: group.dm),
                        Expanded(
                          child: Text(
                            group.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!hiddenCounts)
                          Text(
                            '${group.count}',
                            style: RaftTypography.mono(
                              t,
                              size: 14,
                              line: 20,
                              color: t.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityButton extends StatelessWidget {
  const _ActivityButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
    this.selected = false,
    this.border = false,
    this.dialog = false,
    this.group = false,
    this.strongBorder = false,
    this.shadowed = false,
    this.fontSize,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });
  final String label;
  final VoidCallback onPressed;
  final Widget child;
  final bool selected, border, dialog, group, strongBorder, shadowed;
  final double? height, fontSize;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftInteractive(
      semanticLabel: label,
      selected: selected,
      onPressed: onPressed,
      builder: (context, state) {
        final fill = dialog
            ? (selected
                  ? t.colors['fill-muted']!
                  : state.hovered
                  ? t.colors['fill-muted']!.withValues(alpha: .6)
                  : Colors.transparent)
            : selected
            ? t.colors['primary-soft']!
            : t.panel;
        // Larger text: the pinned height is a minimum.
        final grows = height != null && RaftScaled.grows(context);
        return Container(
          height: grows ? null : height,
          constraints: grows ? BoxConstraints(minHeight: height!) : null,
          foregroundDecoration: !border && state.focusVisible
              ? BoxDecoration(border: Border.all(color: t.ink, width: 2))
              : null,
          padding: padding,
          decoration: RaftCssBoxDecoration(
            color: fill,
            boxShadow: shadowed ? t.themeShadows.sm.paintOrder : null,
            border: border
                ? Border.all(
                    color: state.focusVisible || selected || strongBorder
                        ? (t.colors['line-strong']!)
                        : group
                        ? Colors.transparent
                        : t.line,
                    width: t.border,
                  )
                : null,
          ),
          alignment: Alignment.centerLeft,
          child: DefaultTextStyle(
            style: RaftControlTypography.of(
              context,
              RaftTypography.body(
                t,
                size: fontSize ?? (dialog ? 14 : 12),
                line: fontSize == 10
                    ? 15
                    : dialog
                    ? 20
                    : 16,
                weight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            child: ExcludeSemantics(child: child),
          ),
        );
      },
    );
  }
}

/// ThreadsInbox's source selector fallback: 20px square, 12px DM/hash glyph.
class RaftActivityGroupIcon extends StatelessWidget {
  const RaftActivityGroupIcon({super.key, this.dm = false});
  final bool dm;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dm ? t.colors['primary-soft'] : t.colors['fill-muted'],
        border: Border.all(color: t.line, width: t.border),
      ),
      child: dm
          ? const RaftDirectMessageIcon(size: 12)
          : const RaftIcon(RaftGlyph.hash, size: 12),
    );
  }
}

/// Source search remains desktop-only, with scoped Escape when its query is empty.
class RaftActivitySearchInput extends StatelessWidget {
  const RaftActivitySearchInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onDismissEmpty,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onDismissEmpty;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            controller.text.isEmpty) {
          onDismissEmpty();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        height: RaftScaled.extent(context, 32),
        child: RaftTextInput(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          semanticLabel: raftText(context, 'Search Activity'),
          hintText: raftText(context, 'Search Activity'),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          style: RaftTypography.body(
            t,
            size: 12,
            line: 16,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// ConversationCardSkeleton's six real loading cards; no synthetic result rows.
class RaftActivityLoadingList extends StatelessWidget {
  const RaftActivityLoadingList({super.key});
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      label: raftText(context, 'Loading Activity'),
      child: ListView.separated(
        // v1.21.23: the cards sit in the `py-1` scroller edge to edge; the
        // pre-theme looks inset them 16 (activity.loadingCards).
        padding: t.option('activity.loadingCards', or: 'edge') == 'edge'
            ? const EdgeInsets.symmetric(vertical: 4)
            : const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.panel,
            borderRadius: t.option('activity.loadingCards', or: 'edge') == 'edge'
                ? BorderRadius.circular(
                    t.size('radius.container', fallback: 10),
                  )
                : null,
            // `border border-line-muted theme-brutal:border-2`: the muted rule
            // colour stays in Brutal, only the width grows.
            border: Border.all(
              color: t.option('activity.loadingCards', or: 'edge') == 'edge'
                  ? t.colors['line-hairline']!
                  : t.colors['line-muted']!,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              const Row(
                spacing: 10,
                children: [
                  RaftSkeleton(
                    variant: RaftSkeletonVariant.line,
                    width: 80,
                    themed: true,
                  ),
                  RaftSkeleton(
                    variant: RaftSkeletonVariant.line,
                    width: 64,
                    themed: true,
                  ),
                  RaftSkeleton(
                    variant: RaftSkeletonVariant.line,
                    width: 40,
                    themed: true,
                  ),
                ],
              ),
              const RaftSkeleton(
                variant: RaftSkeletonVariant.line,
                themed: true,
              ),
              const FractionallySizedBox(
                widthFactor: .6,
                alignment: Alignment.centerLeft,
                child: RaftSkeleton(
                  variant: RaftSkeletonVariant.line,
                  themed: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
