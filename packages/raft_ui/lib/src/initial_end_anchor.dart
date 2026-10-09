import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// Keeps a newly mounted, variable-height timeline at its actual end while its
/// lazy extent estimates settle. External scrolling owns the viewport thereafter.
///
/// The child owns rendering and pagination. This component owns neither data nor
/// read state. Context changes must give it a fresh controller/key; highlighted
/// history starts with [enabled] false and never receives an end correction.
class RaftInitialEndAnchor extends StatefulWidget {
  const RaftInitialEndAnchor({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
    this.presentationActive = true,
    this.contentReady = true,
    this.onInitialReady,
  });
  final ScrollController controller;
  final Widget child;
  final bool enabled;
  final bool presentationActive;

  /// Empty first-page loading must not retire the initial positioning epoch.
  final bool contentReady;
  final VoidCallback? onInitialReady;
  @override
  State<RaftInitialEndAnchor> createState() => _RaftInitialEndAnchorState();
}

class _RaftInitialEndAnchorState extends State<RaftInitialEndAnchor> {
  late bool following;
  bool correcting = false, queued = false;
  int revision = 0;
  Timer? readiness;
  @override
  void initState() {
    super.initState();
    following = widget.enabled;
    widget.controller.addListener(scrolled);
    HardwareKeyboard.instance.addHandler(keyInput);
    correctEnd();
  }

  void retire() {
    if (!following) {
      return;
    }
    following = false;
    ++revision;
    readiness?.cancel();
    widget.onInitialReady?.call();
  }

  bool keyInput(KeyEvent event) {
    if (!following || !widget.presentationActive || event is! KeyDownEvent) {
      return false;
    }
    var owned = false;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
      element,
    ) {
      if (identical(element, context)) {
        owned = true;
        return false;
      }
      return true;
    });
    if (owned) {
      retire();
    }
    return false;
  }

  void scrolled() {
    // Includes explicit history/focus jumps; corrections may never undo them.
    if (!correcting && widget.presentationActive) {
      retire();
    }
  }

  void awaitReadiness() {
    readiness?.cancel();
    if (!following ||
        !widget.enabled ||
        !widget.presentationActive ||
        !widget.contentReady) {
      return;
    }
    final controller = widget.controller, ticket = revision;
    // A bounded initial epoch, retired once the actual end geometry stays quiet
    // through the installed timeline's 250ms metrics/affordance delay. Later
    // append/prepend/reading resizes belong to the child's viewport contract.
    readiness = Timer(const Duration(milliseconds: 250), () {
      if (!mounted ||
          ticket != revision ||
          !following ||
          !identical(controller, widget.controller) ||
          !controller.hasClients) {
        return;
      }
      final position = controller.position;
      if (position.hasContentDimensions &&
          (position.pixels - position.maxScrollExtent).abs() <= .01) {
        retire();
      } else {
        correctEnd();
        WidgetsBinding.instance.ensureVisualUpdate();
      }
    });
  }

  void correctEnd() {
    if (!following ||
        !widget.enabled ||
        !widget.presentationActive ||
        !widget.contentReady ||
        queued) {
      return;
    }
    queued = true;
    final controller = widget.controller, ticket = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          ticket != revision ||
          !identical(controller, widget.controller) ||
          !following ||
          !widget.enabled ||
          !widget.presentationActive ||
          !widget.contentReady) {
        return;
      }
      queued = false;
      if (!controller.hasClients) {
        return;
      }
      final position = controller.position;
      if (!position.hasContentDimensions) {
        return;
      }
      if ((position.pixels - position.maxScrollExtent).abs() > .01) {
        correcting = true;
        try {
          controller.jumpTo(position.maxScrollExtent);
        } finally {
          correcting = false;
        }
      }
      awaitReadiness();
    });
    // Metrics arrive in a microtask after layout. A post-frame callback alone
    // does not request the frame needed to consume this one-shot correction.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(RaftInitialEndAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(scrolled);
      widget.controller.addListener(scrolled);
      ++revision;
      queued = false;
      readiness?.cancel();
      following = widget.enabled;
      correctEnd();
    } else if (!widget.enabled) {
      retire();
    } else if (oldWidget.presentationActive != widget.presentationActive) {
      ++revision;
      queued = false;
      readiness?.cancel();
      if (widget.presentationActive) correctEnd();
    } else if (oldWidget.contentReady != widget.contentReady) {
      ++revision;
      queued = false;
      readiness?.cancel();
      if (widget.contentReady) {
        correctEnd();
      }
    }
  }

  @override
  void dispose() {
    ++revision;
    readiness?.cancel();
    HardwareKeyboard.instance.removeHandler(keyInput);
    widget.controller.removeListener(scrolled);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          readiness?.cancel();
          correctEnd();
          return false;
        },
        child: Listener(
          onPointerDown: (_) => retire(),
          onPointerSignal: (_) => retire(),
          child: widget.child,
        ),
      );
}

/// Begins a freshly mounted accepted window at its actual end in layout.
/// The viewport's normal correction loop resolves lazy geometry before paint;
/// after the first accepted dimensions, all scrolling belongs to its host.
class RaftInitialEndScrollController extends ScrollController {
  RaftInitialEndScrollController({super.debugLabel})
    : super(keepScrollOffset: false);

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _RaftInitialEndPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

class _RaftInitialEndPosition extends ScrollPositionWithSingleContext {
  _RaftInitialEndPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });
  bool initialLayout = true;
  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (initialLayout &&
        maxScrollExtent.isFinite &&
        pixels != maxScrollExtent) {
      correctPixels(maxScrollExtent);
      return false;
    }
    final accepted = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    if (accepted) initialLayout = false;
    return accepted;
  }
}
