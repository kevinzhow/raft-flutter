import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Set to true when the stable engine includes flutter/flutter#193025.
const kRaftEngineReportsIosFolds = false;

/// A native layout snapshot, in the Flutter view's logical coordinates.
@immutable
class FoldSnapshot {
  const FoldSnapshot({
    required this.hinge,
    required this.regions,
    required this.viewSize,
  });

  final String hinge;
  final List<({String kind, bool active, Rect bounds})> regions;
  final Size viewSize;

  static FoldSnapshot? parse(Object? payload) {
    if (payload is! Map) return null;
    double? number(Object? value) =>
        value is num && value.isFinite ? value.toDouble() : null;
    final width = number(payload['viewWidth']);
    final height = number(payload['viewHeight']);
    final hinge = payload['hinge'];
    final raw = payload['regions'];
    if (width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        !const [
          'none',
          'unknown',
          'closed',
          'partiallyOpen',
          'fullyOpen',
        ].contains(hinge) ||
        raw is! List) {
      return null;
    }
    final regions = <({String kind, bool active, Rect bounds})>[];
    for (final region in raw) {
      if (region is! Map) return null;
      final x = number(region['x']);
      final y = number(region['y']);
      final w = number(region['w']);
      final h = number(region['h']);
      final kind = region['kind'];
      final active = region['active'];
      if (x == null ||
          y == null ||
          w == null ||
          h == null ||
          !const ['division', 'occlusion'].contains(kind) ||
          active is! bool) {
        return null;
      }
      regions.add((
        kind: kind as String,
        active: active,
        bounds: Rect.fromLTWH(x, y, w, h),
      ));
    }
    return FoldSnapshot(
      hinge: hinge as String,
      regions: List.unmodifiable(regions),
      viewSize: Size(width, height),
    );
  }
}

/// Matches the engine's reserved-region mapping, including active cutouts when flat.
List<DisplayFeature> raftFoldFeatures(FoldSnapshot snapshot) {
  if (snapshot.hinge == 'closed' || snapshot.hinge == 'none') return const [];
  return [
    for (final region in snapshot.regions)
      if (region.active &&
          !region.bounds.isEmpty &&
          (region.kind == 'occlusion' ||
              (region.kind == 'division' && snapshot.hinge == 'partiallyOpen')))
        if (!region.bounds.intersect(Offset.zero & snapshot.viewSize).isEmpty)
          DisplayFeature(
            bounds: region.bounds.intersect(Offset.zero & snapshot.viewSize),
            type: region.kind == 'division'
                ? DisplayFeatureType.fold
                : DisplayFeatureType.cutout,
            state: region.kind == 'division'
                ? DisplayFeatureState.postureHalfOpened
                : DisplayFeatureState.unknown,
          ),
  ];
}

// EventChannel reports activation failures through FlutterError rather than its
// stream. Handle the same channel protocol here so an unavailable bridge stays
// an empty feature list, including in hosts that do not register iOS plugins.
Stream<Object?> _nativeFoldEvents() {
  const channel = EventChannel('app.raft/display-folds');
  final methods = MethodChannel(
    channel.name,
    channel.codec,
    channel.binaryMessenger,
  );
  late StreamController<Object?> events;
  events = StreamController<Object?>(
    onListen: () async {
      channel.binaryMessenger.setMessageHandler(channel.name, (message) async {
        if (message == null) {
          await events.close();
        } else {
          try {
            events.add(channel.codec.decodeEnvelope(message));
          } catch (error, stack) {
            events.addError(error, stack);
          }
        }
        return null;
      });
      try {
        await methods.invokeMethod<void>('listen');
      } catch (error, stack) {
        if (!events.isClosed) events.addError(error, stack);
      }
    },
    onCancel: () async {
      channel.binaryMessenger.setMessageHandler(channel.name, null);
      try {
        await methods.invokeMethod<void>('cancel');
      } catch (_) {
        // The listener is gone; a missing bridge has no resources to release.
      }
    },
  );
  return events.stream;
}

/// Supplies iOS folds above the Navigator until the engine owns this data.
class RaftNativeDisplayFeatures extends StatefulWidget {
  const RaftNativeDisplayFeatures({
    super.key,
    required this.child,
    this.snapshots,
    this.engineReportsIosFolds = kRaftEngineReportsIosFolds,
  });

  final Widget child;
  final Stream<FoldSnapshot>? snapshots;
  final bool engineReportsIosFolds;

  @override
  State<RaftNativeDisplayFeatures> createState() =>
      _RaftNativeDisplayFeaturesState();
}

class _RaftNativeDisplayFeaturesState extends State<RaftNativeDisplayFeatures> {
  StreamSubscription<Object?>? _subscription;
  FoldSnapshot? _snapshot;
  List<DisplayFeature> _features = const [];
  // ignore: raft_lints/avoid_imperative_notice_state -- Suppresses duplicate debug logs; no user-visible notice state.
  bool _loggedError = false;

  bool get _ownsFeatures =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      !widget.engineReportsIosFolds;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    if (!_ownsFeatures) return;
    final Stream<Object?> stream = widget.snapshots ?? _nativeFoldEvents();
    _subscription = stream.listen((event) {
      final snapshot = event is FoldSnapshot
          ? event
          : FoldSnapshot.parse(event);
      if (snapshot == null) {
        _failed('Invalid display-fold snapshot');
      } else {
        setState(() => _snapshot = snapshot);
      }
    }, onError: (Object error) => _failed(error));
  }

  void _failed(Object error) {
    if (!_loggedError) {
      _loggedError = true;
      debugPrint('Display folds unavailable: $error');
    }
    setState(() => _snapshot = null);
  }

  @override
  void didUpdateWidget(RaftNativeDisplayFeatures oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshots != widget.snapshots ||
        oldWidget.engineReportsIosFolds != widget.engineReportsIosFolds) {
      _subscription?.cancel();
      _snapshot = null;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ownsFeatures) return widget.child;
    final media = MediaQuery.of(context);
    final snapshot = _snapshot;
    final next = <DisplayFeature>[];
    if (snapshot != null &&
        (snapshot.viewSize.width - media.size.width).abs() <= 1 &&
        (snapshot.viewSize.height - media.size.height).abs() <= 1) {
      for (final feature in raftFoldFeatures(snapshot)) {
        final rect = feature.bounds;
        next.add(
          DisplayFeature(
            bounds: Rect.fromLTRB(
              rect.left,
              rect.top,
              rect.right == snapshot.viewSize.width
                  ? media.size.width
                  : rect.right,
              rect.bottom == snapshot.viewSize.height
                  ? media.size.height
                  : rect.bottom,
            ),
            type: feature.type,
            state: feature.state,
          ),
        );
      }
    }
    if (!listEquals(_features, next)) _features = List.unmodifiable(next);
    Widget child = widget.child;
    if (!kReleaseMode && const bool.fromEnvironment('RAFT_FOLD_DEBUG')) {
      child = Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _FoldPainter(_features)),
            ),
          ),
        ],
      );
    }
    return MediaQuery(
      data: media.copyWith(displayFeatures: _features),
      child: child,
    );
  }
}

class _FoldPainter extends CustomPainter {
  _FoldPainter(this.features);
  final List<DisplayFeature> features;

  @override
  void paint(Canvas canvas, Size size) {
    // ds-allow: diagnostic feature rectangles, debug/profile builds only.
    final paint = Paint()..color = const Color(0x66FF0066);
    for (final feature in features) {
      canvas.drawRect(feature.bounds, paint);
    }
  }

  @override
  bool shouldRepaint(_FoldPainter oldDelegate) =>
      !identical(features, oldDelegate.features);
}
