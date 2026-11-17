import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

/// Tapping the selected phone bottom-bar tab again (Web `retapTabRoot`,
/// `useTabRootScroll`): the tab root's scroller goes to the top, smoothly.
/// At the top nothing else happens (no navigation, no reset); only Search adds
/// a step there ([retapScroll]'s `atTop`). A root with its own meaning for the
/// tap passes `onRetap` as the registered handler instead of [retapScroll]
/// (Web: Activity goes to the next unread item).
///
/// Web's other half, remembering each root's scroll across tab switches, is
/// not ported: every root keeps its position through a [PageStorageKey] or a
/// controller that the workspace keeps alive.
///
/// Roots register only while they are the phone tab root (a pushed page, a
/// channel's own Tasks view and the wide layout register nothing) and
/// unregister on dispose, only if the handler is still theirs.
class TabRootRetap {
  const TabRootRetap._();

  static final _handlers = <String, VoidCallback>{};

  /// The tab bar's tap on the selected [tab]. False when no root of that tab
  /// is on screen to take it.
  static bool retap(String tab) {
    final handler = _handlers[tab];
    if (handler == null) return false;
    handler();
    return true;
  }

  /// Registers [handler] for [tab]; the returned function unregisters it, and
  /// only if it is still the registered one.
  static VoidCallback register(String tab, VoidCallback handler) {
    _handlers[tab] = handler;
    return () {
      if (identical(_handlers[tab], handler)) _handlers.remove(tab);
    };
  }

  /// A test seam: the tabs that have a root registered.
  static Set<String> get registered => _handlers.keys.toSet();
}

/// The default retap: scroll [controller] to the top smoothly, or run [atTop]
/// when it already is there (Web: `scrollTop > 0` -> `scrollTo({top: 0,
/// behavior: 'smooth'})`, else `onRetapAtTop`).
void retapScroll(ScrollController? controller, {VoidCallback? atTop}) {
  if (controller != null &&
      controller.hasClients &&
      controller.positions.length == 1 &&
      controller.offset > 0) {
    controller.animateTo(
      0,
      duration: RaftPrimitives.smoothScrollDuration,
      curve: RaftPrimitives.smoothScrollCurve,
    );
    return;
  }
  atTop?.call();
}

/// Holds one registration for a stateful tab root: [bind] on init and when the
/// tab changes, [release] on dispose.
class TabRootRetapBinding {
  VoidCallback? _release;
  String? _tab;

  void bind(String? tab, VoidCallback handler) {
    if (tab == _tab && (tab == null || _release != null)) return;
    release();
    _tab = tab;
    if (tab != null) _release = TabRootRetap.register(tab, handler);
  }

  void release() {
    _release?.call();
    _release = null;
    _tab = null;
  }
}

/// A tab root whose scroller this widget owns (Home): hands [builder] a
/// controller and registers the default retap for [tab] (null: nothing).
class TabRootScroller extends StatefulWidget {
  const TabRootScroller({super.key, required this.tab, required this.builder});

  final String? tab;
  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  @override
  State<TabRootScroller> createState() => _TabRootScrollerState();
}

class _TabRootScrollerState extends State<TabRootScroller> {
  final controller = ScrollController();
  final binding = TabRootRetapBinding();

  @override
  void dispose() {
    binding.release();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    binding.bind(widget.tab, () => retapScroll(controller));
    return widget.builder(context, controller);
  }
}

/// The phone tab a page below is the root of (null: none). Provided around
/// the lists the workspace mounts as tab roots.
class TabRootRetapScope extends InheritedWidget {
  const TabRootRetapScope({super.key, required this.tab, required super.child});

  final String? tab;

  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabRootRetapScope>()?.tab;

  @override
  bool updateShouldNotify(TabRootRetapScope old) => tab != old.tab;
}

/// A list page's share of the re-tap: the registration and the Search
/// scroller. The page calls [TabRootRetapBinding.bind] from
/// `didChangeDependencies` and [disposeRetap] on dispose.
mixin ResourcePageRetap<T extends StatefulWidget> on State<T> {
  final retapBinding = TabRootRetapBinding();
  final searchScroll = ScrollController();

  void disposeRetap() {
    retapBinding.release();
    searchScroll.dispose();
  }
}
