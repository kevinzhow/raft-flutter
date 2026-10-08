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
    this.onInitialReady,
  });
  final ScrollController controller;
  final Widget child;
  final bool enabled;
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
    if (!following || event is! KeyDownEvent) {
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
    if (!correcting) {
      retire();
    }
  }

  void awaitReadiness() {
    readiness?.cancel();
    if (!following || !widget.enabled) {
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
    if (!following || !widget.enabled || queued) {
      return;
    }
    queued = true;
    final controller = widget.controller, ticket = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          ticket != revision ||
          !identical(controller, widget.controller) ||
          !following ||
          !widget.enabled) {
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
