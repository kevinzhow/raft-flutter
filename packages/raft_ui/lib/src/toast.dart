import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'recipe_surface.dart';
import 'recipes/toast_styles.g.dart';
import 'theme.dart';

/// The mounted Web selection toast: inline, title-only, without an icon or
/// dismiss button (ChatPanel/ThreadPanel SELECTION_TOAST_OPTIONS). Paint comes
/// from raft-ui toastStyles; LocalizedToastProvider overrides title to normal
/// weight and permits wrapping. This is not the stacked/action toast variant.
class RaftToast extends StatelessWidget {
  const RaftToast({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    final s = RaftToastRecipe.resolve(
      theme: t.recipeTheme,
      layout: RaftToastRecipeLayout.inline,
      tone: RaftToastRecipeTone.success,
      states: t.recipeStates(
        extra: const [
          'not:has:data-slot=toast-icon',
          'not:has:data-slot=toast-actions',
          'not:has:data-slot=toast-description',
        ],
      ),
      tokens: rt,
    );
    final titleStyle = s.title.text(rt).copyWith(fontWeight: FontWeight.w400);
    return Semantics(
      liveRegion: true,
      container: true,
      child: RaftRecipeBox(
        style: s.root,
        tokens: rt,
        child: RaftRecipeBox(
          style: s.content,
          tokens: rt,
          child: Text(title, style: titleStyle, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// UI-owned transient feedback. No payload persistence or app/API dependency.
/// A new notice replaces this owner's old notice and restarts its timeout.
class RaftToastController extends ChangeNotifier {
  Timer? _timer;
  DateTime? _started;
  Duration _remaining = Duration.zero;
  bool _paused = false;
  String? _title;
  String? get title => _title;

  /// raft-ui ToastProvider's authored default is 5000ms.
  void show(String title, {Duration duration = const Duration(seconds: 5)}) {
    _timer?.cancel();
    _title = title;
    _remaining = duration;
    if (!_paused) _start();
    notifyListeners();
  }

  void _start() {
    _started = DateTime.now();
    _timer = Timer(_remaining, clear);
  }

  void pause(bool value) {
    if (_paused == value) return;
    _paused = value;
    if (_title == null) return;
    if (value) {
      _timer?.cancel();
      final elapsed = DateTime.now().difference(_started!);
      _remaining = _remaining - elapsed;
      if (_remaining.isNegative) _remaining = Duration.zero;
    } else {
      _start();
    }
  }

  void clear() {
    _timer?.cancel();
    if (_title == null) return;
    _title = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _title = null;
    super.dispose();
  }
}

/// Scoped portal: inherits the owner's theme and disappears with its widget.
/// Matches the bottom-center viewport: min(24rem, viewport - 2rem), bottom 16.
/// Safe-area/keyboard insets protect native system chrome without moving the
/// underlying layout or capturing focus. Hover/focus pauses the timeout.
class RaftToastPortal extends StatefulWidget {
  const RaftToastPortal({
    super.key,
    required this.controller,
    this.child = const SizedBox.shrink(),
  });
  final RaftToastController controller;
  final Widget child;
  @override
  State<RaftToastPortal> createState() => _RaftToastPortalState();
}

class _RaftToastPortalState extends State<RaftToastPortal> {
  final portal = OverlayPortalController();
  bool hovered = false, focused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
    if (widget.controller.title != null) portal.show();
  }

  void changed() {
    if (widget.controller.title == null) {
      portal.hide();
    } else {
      portal.show();
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(RaftToastPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(changed);
      oldWidget.controller.pause(false);
      widget.controller.addListener(changed);
      widget.controller.pause(hovered || focused);
      changed();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    // Only this owner's controller is affected, never another toast host.
    widget.controller.pause(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: portal,
    overlayChildBuilder: (context) {
      final m = MediaQuery.of(context);
      final title = widget.controller.title;
      if (title == null) return const SizedBox.shrink();
      return Positioned(
        bottom: 16 + math.max(m.padding.bottom, m.viewInsets.bottom),
        left: 16 + m.padding.left,
        right: 16 + m.padding.right,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: Focus(
              onFocusChange: (value) {
                focused = value;
                widget.controller.pause(hovered || focused);
              },
              child: MouseRegion(
                onEnter: (_) {
                  hovered = true;
                  widget.controller.pause(true);
                },
                onExit: (_) {
                  hovered = false;
                  widget.controller.pause(focused);
                },
                child: RaftToast(title: title),
              ),
            ),
          ),
        ),
      );
    },
    child: widget.child,
  );
}
