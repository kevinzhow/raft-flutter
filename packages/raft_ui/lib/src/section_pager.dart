import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controlled section paging. The owner supplies the accepted selection;
/// neighboring pages do not mount their content until first selected.
///
/// Visited pages retain their elements. Inactive pages cannot receive focus,
/// pointer input or accessibility actions, and their tickers are suspended.
/// Swipes commit after scrolling stops, so owners do not mount data views or
/// change the outgoing page's presentation during the drag/settling frames.
/// Change [key] when the authority owning the content changes.
class RaftSectionPager<T extends Object> extends StatefulWidget {
  const RaftSectionPager({
    super.key,
    required this.sections,
    required this.value,
    required this.onChanged,
    required this.builder,
    this.swipeEnabled = true,
    this.initiallyMounted = const [],
    this.unvisitedBuilder,
  }) : assert(sections.length > 0);

  final List<T> sections;
  final T value;

  /// Null when navigation is owned by controls outside the pager.
  /// Such a pager exposes no section keyboard or accessibility actions.
  final ValueChanged<T>? onChanged;
  final Widget Function(BuildContext, T) builder;
  final WidgetBuilder? unvisitedBuilder;
  final bool swipeEnabled;
  final List<T> initiallyMounted;

  @override
  State<RaftSectionPager<T>> createState() => _RaftSectionPagerState<T>();
}

class _RaftSectionPagerState<T extends Object>
    extends State<RaftSectionPager<T>> {
  late final PageController controller = PageController(
    initialPage: index,
    keepPage: false,
  );
  late final Set<T> visited = {...widget.initiallyMounted, widget.value};
  late final selection = ValueNotifier<T>(widget.value);
  int syncRevision = 0;
  bool synchronizing = false;
  T? reportedSwipe;
  int get index => widget.sections
      .indexOf(widget.value)
      .clamp(0, widget.sections.length - 1);

  @override
  void didUpdateWidget(RaftSectionPager<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    visited.removeWhere((id) => !widget.sections.contains(id));
    visited.add(widget.value);
    selection.value = widget.value;
    final fromSwipe = widget.value == reportedSwipe;
    reportedSwipe = null;
    if (oldWidget.value != widget.value && !fromSwipe ||
        !listEquals(oldWidget.sections, widget.sections)) {
      synchronizing = true;
      final revision = ++syncRevision;
      if (controller.hasClients && controller.position.hasViewportDimension) {
        controller.jumpToPage(index);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != syncRevision) return;
        if (controller.hasClients && controller.page != index.toDouble()) {
          // Jumping directly also avoids activating intermediate sections
          // (and starting their reads) when a distant tab is clicked.
          controller.jumpToPage(index);
        }
        synchronizing = false;
      });
    }
  }

  /// Pointers that went down inside the display's system Back edges.
  final edgePointers = <int>{};

  void _pointerDown(PointerDownEvent event) {
    // A non-swiping host has no competing drag to guard.
    if (!widget.swipeEnabled ||
        Theme.of(context).platform != TargetPlatform.android) {
      return;
    }
    final insets = MediaQuery.systemGestureInsetsOf(context);
    if (insets.left <= 0 && insets.right <= 0) return;
    // Insets are physical display edges, not logical start/end or the local
    // bounds of a panel. Flutter pointer coordinates are in logical pixels.
    final view = View.of(context);
    final displayWidth = view.physicalSize.width / view.devicePixelRatio;
    final x = event.position.dx;
    if (x < insets.left || x >= displayWidth - insets.right) {
      edgePointers.add(event.pointer);
    }
  }

  void select(int next) {
    if (next < 0 || next >= widget.sections.length) return;
    final value = widget.sections[next];
    if (value != widget.value) widget.onChanged?.call(value);
  }

  @override
  void dispose() {
    ++syncRevision;
    controller.dispose();
    selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      if (widget.onChanged != null)
        const SingleActivator(LogicalKeyboardKey.pageDown, control: true): () =>
            select(index + 1),
      if (widget.onChanged != null)
        const SingleActivator(LogicalKeyboardKey.pageUp, control: true): () =>
            select(index - 1),
    },
    child: Semantics(
      onIncrease: widget.onChanged != null && index + 1 < widget.sections.length
          ? () => select(index + 1)
          : null,
      onDecrease: widget.onChanged != null && index > 0
          ? () => select(index - 1)
          : null,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          if (notification.depth != 0 ||
              notification.metrics.axis != Axis.horizontal ||
              synchronizing ||
              !controller.hasClients) {
            return false;
          }
          final page = controller.page?.round();
          if (page != null && page >= 0 && page < widget.sections.length) {
            reportedSwipe = widget.sections[page];
            select(page);
          }
          return false;
        },
        child: Listener(
          // Records where a pointer went down so the pager's own drag can
          // ignore gestures that start in the system Back edges. Content
          // still receives the pointer: a plain tap on a control in the edge
          // strip (composer attach / send) must work, and Android cancels
          // the pointer itself when its Back swipe takes over.
          behavior: HitTestBehavior.translucent,
          onPointerDown: _pointerDown,
          onPointerUp: (e) => edgePointers.remove(e.pointer),
          onPointerCancel: (e) => edgePointers.remove(e.pointer),
          child: PageView.builder(
            controller: controller,
            physics: widget.swipeEnabled
                ? _EdgeGuardPhysics(() => edgePointers.isNotEmpty)
                : const NeverScrollableScrollPhysics(),
            itemCount: widget.sections.length,
            findChildIndexCallback: (key) {
              if (key is! ValueKey<T>) return null;
              final i = widget.sections.indexOf(key.value);
              return i >= 0 ? i : null;
            },
            itemBuilder: (context, i) {
              final id = widget.sections[i];
              return _RetainedSection<T>(
                key: ValueKey<T>(id),
                section: id,
                selection: selection,
                child: visited.contains(id)
                    ? widget.builder(context, id)
                    : widget.unvisitedBuilder?.call(context) ??
                          const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _RetainedSection<T extends Object> extends StatefulWidget {
  const _RetainedSection({
    super.key,
    required this.child,
    required this.section,
    required this.selection,
  });
  final Widget child;
  final T section;
  final ValueListenable<T> selection;
  @override
  State<_RetainedSection<T>> createState() => _RetainedSectionState<T>();
}

class _RetainedSectionState<T extends Object> extends State<_RetainedSection<T>>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Kept-alive sliver children need not re-enter itemBuilder when selection
    // changes. Update their presentation directly, including offscreen pages.
    return ValueListenableBuilder<T>(
      valueListenable: widget.selection,
      child: widget.child,
      builder: (context, selected, child) {
        final active = selected == widget.section;
        return TickerMode(
          enabled: active,
          child: ExcludeFocus(
            excluding: !active,
            child: ExcludeSemantics(
              excluding: !active,
              child: IgnorePointer(ignoring: !active, child: child),
            ),
          ),
        );
      },
    );
  }
}

// System back owns gestures which *start* in the display's side insets. The
// pager's own drag must not scroll a page for them: a late cancellation from
// the system can already have moved a page. Only the pager's drag is ignored;
// controls inside the page still get ordinary taps in the edge strips, which
// the system passes through (it takes over only once the finger swipes).
class _EdgeGuardPhysics extends PageScrollPhysics {
  const _EdgeGuardPhysics(this.blocked, {super.parent});

  final bool Function() blocked;

  @override
  _EdgeGuardPhysics applyTo(ScrollPhysics? ancestor) =>
      _EdgeGuardPhysics(blocked, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      blocked() ? 0 : super.applyPhysicsToUserOffset(position, offset);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) => super.createBallisticSimulation(position, blocked() ? 0 : velocity);
}
