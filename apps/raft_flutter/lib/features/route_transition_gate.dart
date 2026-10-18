import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Tells whether a phone page route is in the middle of a transition: a push,
/// a pop, or a predictive-back gesture (dragging and the settle that follows).
///
/// While a page scales or slides, any visual change inside it (or inside the
/// page it covers or reveals) invalidates its cached layer, and the engine
/// re-records and re-rasterises every glyph at the new scale on each frame.
/// Data and state keep being accepted as usual; only consumers that ask this
/// gate hold their rebuild and apply it once when the transition settles.
///
/// The page that is being pushed in stays live ([quietFor] is false for it).
/// A transition that never settles releases after [timeout]. The gate of a
/// route is found with [of]; a route no gate tracks is never held.
class RouteTransitionGate extends ChangeNotifier {
  RouteTransitionGate({this.timeout = const Duration(seconds: 2)});

  /// A gate that stays closed this long is released regardless.
  final Duration timeout;

  static final _gates = Expando<RouteTransitionGate>();

  /// The gate that tracks [route], if its page stack has one.
  static RouteTransitionGate? of(Route<dynamic>? route) =>
      route == null ? null : _gates[route];

  final Map<Route<dynamic>, AnimationStatusListener> _tracked = {};
  final Set<Route<dynamic>> _animating = {};
  final Map<VoidCallback, VoidCallback> _queued = {};
  Route<dynamic>? _entering;
  bool _gesture = false, _closed = false, _disposed = false;
  Timer? _timer;

  /// True while a push, pop or back gesture is in progress.
  bool get closed => _closed;

  /// Whether [route]'s live updates are held: any route of the stack during a
  /// transition, except the one being pushed in.
  bool quietFor(Route<dynamic>? route) =>
      _closed && !identical(route, _entering);

  /// Runs [apply] now, or once when the transition that holds [route]
  /// settles. Calling again with the same [apply] before then queues one run.
  /// Returns whether it was deferred.
  static bool defer(Route<dynamic>? route, VoidCallback apply) {
    final gate = of(route);
    if (gate == null || !gate.quietFor(route)) return false;
    void flush() {
      if (gate.quietFor(route)) return;
      gate.removeListener(flush);
      gate._queued.remove(apply);
      apply();
    }

    gate._queued[apply]?.call();
    gate._queued[apply] = () => gate.removeListener(flush);
    gate.addListener(flush);
    return true;
  }

  void _track(Route<dynamic>? route) {
    final animation = route is TransitionRoute ? route.animation : null;
    if (route == null || animation == null || _tracked.containsKey(route)) {
      return;
    }
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.forward ||
          status == AnimationStatus.reverse) {
        _animating.add(route);
      } else {
        _animating.remove(route);
        if (status == AnimationStatus.dismissed) _untrack(route);
      }
      _evaluate();
    }

    _gates[route] = this;
    _tracked[route] = listener;
    animation.addStatusListener(listener);
    if (animation.isAnimating) _animating.add(route);
  }

  void _untrack(Route<dynamic>? route) {
    final listener = _tracked.remove(route);
    _animating.remove(route);
    if (listener != null && route is TransitionRoute) {
      route.animation?.removeStatusListener(listener);
    }
  }

  void _evaluate() {
    final next = _gesture || _animating.isNotEmpty;
    if (next == _closed || _disposed) return;
    _closed = next;
    if (next) {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot safety release armed only while a transition runs; cancelled when it settles and never re-armed from its callback.
      _timer ??= Timer(timeout, _timedOut);
      return;
    }
    _timer?.cancel();
    _timer = null;
    _entering = null;
    _notifySettled();
  }

  void _timedOut() {
    _timer = null;
    for (final route in _tracked.keys.toList()) {
      _untrack(route);
    }
    _gesture = false;
    _evaluate();
  }

  /// Listeners flush held work here; never from inside a build.
  void _notifySettled() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && !_closed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final route in _tracked.keys.toList()) {
      _untrack(route);
    }
    super.dispose();
  }
}

/// Observes the phone page [Navigator] for pushes, pops and back gestures.
class RouteTransitionObserver extends NavigatorObserver {
  RouteTransitionObserver(this.gate);
  final RouteTransitionGate gate;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    gate
      .._track(route)
      .._track(previousRoute)
      .._entering = route
      .._evaluate();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    gate
      .._track(route)
      .._track(previousRoute)
      .._entering = null
      .._evaluate();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    gate
      .._track(newRoute)
      .._track(oldRoute)
      .._evaluate();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    gate
      .._untrack(route)
      .._evaluate();
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    gate
      .._track(route)
      .._track(previousRoute)
      .._entering = null
      .._gesture = true
      .._evaluate();
  }

  @override
  void didStopUserGesture() {
    gate
      .._gesture = false
      .._evaluate();
  }
}

/// A [ListenableBuilder] whose page holds its rebuild while its route is in a
/// transition: a notification during the transition rebuilds once when it
/// settles. Outside a phone page stack it behaves like [ListenableBuilder].
class QuietListenableBuilder extends StatefulWidget {
  const QuietListenableBuilder({
    super.key,
    required this.listenable,
    required this.builder,
    this.child,
  });
  final Listenable listenable;
  final TransitionBuilder builder;
  final Widget? child;

  @override
  State<QuietListenableBuilder> createState() => _QuietListenableBuilderState();
}

class _QuietListenableBuilderState extends State<QuietListenableBuilder> {
  Route<dynamic>? _route;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(QuietListenableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listenable == oldWidget.listenable) return;
    oldWidget.listenable.removeListener(_changed);
    widget.listenable.addListener(_changed);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (RouteTransitionGate.defer(_route, _apply)) {
      _pending = true;
      return;
    }
    setState(() {});
  }

  void _apply() {
    if (mounted && _pending) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _pending = false;
    return widget.builder(context, widget.child);
  }
}
