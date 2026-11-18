import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'raft/pixel_spinner.dart';
import 'theme.dart';

/// Touch refresh for an always-scrollable vertical list. The owner supplies
/// the refresh and retains its rows while the read runs.
class RaftPullToRefresh extends StatefulWidget {
  const RaftPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.enabled = true,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final bool enabled;

  @override
  State<RaftPullToRefresh> createState() => _RaftPullToRefreshState();
}

class _RaftPullToRefreshState extends State<RaftPullToRefresh> {
  static const _threshold = 100.0;
  static const _maxPull = 140.0;
  static const _hold = 60.0;
  static const _damping = .55;

  final _fingers = <int>{};
  PointerDownEvent? _origin;
  bool _atTop = false;
  bool _armed = false;
  bool _refreshing = false;
  double _distance = 0;

  void _start(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _fingers.add(event.pointer);
    if (_fingers.length > 1) {
      _resetPull();
    } else if (!_refreshing) {
      _origin = event;
    }
  }

  bool _onScroll(ScrollNotification event) {
    if (event.depth != 0 || event.metrics.axisDirection != AxisDirection.down) {
      return false;
    }
    if (event is ScrollStartNotification && event.dragDetails != null) {
      _atTop = event.metrics.pixels <= event.metrics.minScrollExtent;
      if (!_atTop) _origin = null;
    }
    return false;
  }

  void _move(PointerMoveEvent event) {
    final origin = _origin;
    if (origin == null || event.pointer != origin.pointer) return;
    final delta = event.position - origin.position;
    if (_distance == 0 &&
        !_armed &&
        (delta.dy < -6 ||
            (delta.dx.abs() > 10 && delta.dx.abs() > delta.dy) ||
            event.timeStamp - origin.timeStamp >=
                const Duration(milliseconds: 500))) {
      _resetPull();
      return;
    }
    if (!_atTop || (delta.dy <= 6 && _distance == 0 && !_armed)) return;
    setState(() {
      _distance = (delta.dy * _damping).clamp(0, _maxPull);
      _armed = _armed || _distance >= _threshold;
    });
  }

  void _finish(PointerEvent event) {
    _fingers.remove(event.pointer);
    if (event.pointer != _origin?.pointer) return;
    final release = event is PointerUpEvent && _armed;
    _resetPull();
    if (release) unawaited(_refresh());
  }

  void _resetPull() {
    _origin = null;
    _atTop = false;
    _armed = false;
    if (_distance != 0) setState(() => _distance = 0);
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  void didUpdateWidget(RaftPullToRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _resetPull();
      _fingers.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final android = Theme.of(context).platform == TargetPlatform.android;
    final tokens = RaftTokens.of(context);
    final label = MaterialLocalizations.of(context)
        .refreshIndicatorSemanticLabel;
    final pull = _refreshing ? _hold : _distance;
    final progress = (_distance / _threshold).clamp(0.0, 1.0);
    final extent = android ? 40.0 : pull;
    final duration = _origin != null || MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    return Listener(
      onPointerDown: _start,
      onPointerMove: _move,
      onPointerUp: _finish,
      onPointerCancel: _finish,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          alignment: Alignment.topCenter,
          fit: StackFit.expand,
          children: [
            AnimatedPadding(
              duration: duration,
              curve: Curves.easeOut,
              padding: EdgeInsets.only(top: android ? 0 : pull),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  physics: const ClampingScrollPhysics(),
                  overscroll: false,
                ),
                child: widget.child,
              ),
            ),
            if (pull > 0)
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOut,
                top: android ? pull - extent : 0,
                height: extent,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: android
                        ? SizedBox.square(
                            dimension: extent,
                            // ds-allow: raft-ui selects the Material progress arc on Android.
                            child: RefreshProgressIndicator(
                              value: _refreshing ? null : progress,
                              color: tokens.muted,
                              backgroundColor: tokens.popover,
                              semanticsLabel: _refreshing ? label : null,
                              indicatorMargin: EdgeInsets.zero,
                            ),
                          )
                        : Semantics(
                            liveRegion: _refreshing,
                            label: _refreshing ? label : null,
                            excludeSemantics: true,
                            child: Opacity(
                              opacity: _refreshing ? 1 : progress,
                              child: RaftPixelSpinner(
                                color: tokens.muted,
                                progress: _refreshing ? null : progress,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
