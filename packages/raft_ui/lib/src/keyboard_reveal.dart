// Keeps the focused text field and the page's primary action above the soft
// keyboard on pages that own the whole window (the auth / onboarding pages).
//
// Web gets this from the browser: focusing an input scrolls it into view of the
// visual viewport. Flutter's EditableText does the same for the caret, but only
// when the scroll view has somewhere to scroll to. A page that does not shrink
// for the keyboard (a route without a resizing Scaffold) has no scroll extent
// below the form, so the field under the keyboard is never moved. This file is
// the one mechanism for that:
//
// * [RaftKeyboardScrollView] is the page scroll view. The page spends the
//   keyboard inset on its own bottom padding (the auth shell does), the viewport
//   shrinks, the content scrolls, and the centred composition returns when the
//   keyboard goes away.
// * It reveals the focused field and the nearest [RaftPrimaryAction] below it
//   (the submit button) together when both fit above the keyboard, and the
//   field alone when they do not. It only moves when something is hidden, so
//   switching fields neither jumps nor re-centres.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Extra room kept around the revealed field (its label and frame) and action.
const double _revealMargin = 16;

class _RevealScope extends InheritedWidget {
  const _RevealScope({required this.state, required super.child});
  final _RaftKeyboardScrollViewState state;

  @override
  bool updateShouldNotify(_RevealScope old) => state != old.state;
}

/// Marks the page's primary action (the submit / continue button). The nearest
/// [RaftKeyboardScrollView] keeps it visible above the keyboard together with
/// the focused field when both fit.
class RaftPrimaryAction extends StatefulWidget {
  const RaftPrimaryAction({super.key, required this.child});
  final Widget child;

  @override
  State<RaftPrimaryAction> createState() => _RaftPrimaryActionState();
}

class _RaftPrimaryActionState extends State<RaftPrimaryAction> {
  _RaftKeyboardScrollViewState? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context
        .dependOnInheritedWidgetOfExactType<_RevealScope>()
        ?.state;
    if (next == _scope) return;
    _scope?._actions.remove(context);
    _scope = next;
    _scope?._actions.add(context);
  }

  @override
  void dispose() {
    _scope?._actions.remove(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The scroll view of a full-window form page. See the library comment.
///
/// [child] is laid out like a [SingleChildScrollView] child. The widget reads
/// the window's keyboard height only to know when to reveal; the caller
/// shrinks the viewport (padding by the inset, or a resizing layout).
class RaftKeyboardScrollView extends StatefulWidget {
  const RaftKeyboardScrollView({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  State<RaftKeyboardScrollView> createState() => _RaftKeyboardScrollViewState();
}

class _RaftKeyboardScrollViewState extends State<RaftKeyboardScrollView>
    with WidgetsBindingObserver {
  final controller = ScrollController();
  final Set<BuildContext> _actions = {};
  double _inset = 0;
  Size _size = Size.zero;
  bool _scheduled = false, _animate = false;
  Timer? _settle;

  /// The keyboard height the window reports, in dp. Read from the view, not
  /// from `MediaQuery`: a page below a resizing layout (the workspace, a
  /// Scaffold) sees the inset already spent and would never learn that a
  /// keyboard is up.
  double _keyboard() {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_focusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _inset = _keyboard();
    _size = MediaQuery.sizeOf(context);
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final inset = _keyboard();
    final size = MediaQuery.sizeOf(context);
    final moved = inset != _inset || size != _size;
    final opening = inset > _inset;
    _inset = inset;
    _size = size;
    // The viewport follows the keyboard frame by frame: no animation.
    if (moved && inset > 0) _schedule(animate: false, settle: !opening);
  }

  @override
  void dispose() {
    _settle?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_focusChanged);
    controller.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (_inset > 0) _schedule(animate: true, settle: true);
  }

  void _schedule({required bool animate, required bool settle}) {
    _animate = animate;
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        _reveal(_animate);
      });
    }
    _settle?.cancel();
    // EditableText scrolls its own caret into view (100 ms) after a focus or
    // inset change; one more pass once that has finished makes this mechanism
    // the last word when the two disagree about the action button.
    _settle = Timer(const Duration(milliseconds: 180), () {
      if (mounted) _reveal(true);
    });
  }

  void _reveal(bool animate) {
    if (!mounted || !controller.hasClients || _keyboard() <= 0) return;
    final position = controller.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null ||
        !focusContext.mounted ||
        focusContext.findAncestorStateOfType<EditableTextState>() == null) {
      return;
    }
    final field = focusContext.findRenderObject();
    if (field is! RenderBox || !field.attached || !field.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(field);
    if (viewport == null ||
        Scrollable.maybeOf(focusContext)?.position != position) {
      return;
    }

    double top(RenderBox box, EdgeInsets margin) => viewport
        .getOffsetToReveal(
          box,
          0,
          rect: margin.inflateRect(Offset.zero & box.size),
        )
        .offset;
    double bottom(RenderBox box, EdgeInsets margin) => viewport
        .getOffsetToReveal(
          box,
          1,
          rect: margin.inflateRect(Offset.zero & box.size),
        )
        .offset;

    const fieldMargin = EdgeInsets.symmetric(vertical: _revealMargin);
    // Offsets that show the whole field: [low, high].
    var low = bottom(field, fieldMargin);
    final high = top(field, fieldMargin);

    // The nearest primary action below the field.
    RenderBox? action;
    var actionTop = double.infinity;
    for (final c in _actions) {
      if (!c.mounted) continue;
      final box = c.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if (RenderAbstractViewport.maybeOf(box) != viewport) continue;
      final t = top(box, EdgeInsets.zero);
      if (t >= high - 1 && t < actionTop) {
        actionTop = t;
        action = box;
      }
    }
    if (action != null) {
      final both = math.max(
        low,
        bottom(action, const EdgeInsets.only(bottom: _revealMargin / 2)),
      );
      if (both <= high) {
        low = both; // field and action fit together
      } else {
        // They do not (a short window): the field goes to the top so that as
        // much of the form below it as possible is in view.
        low = high;
      }
    }

    if (low > high) low = high; // a field taller than the viewport
    final target = position.pixels
        .clamp(low, high)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < .5) return;
    if (animate) {
      unawaited(
        position.animateTo(
          target,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      position.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) => _RevealScope(
    state: this,
    child: SingleChildScrollView(
      controller: controller,
      padding: widget.padding,
      child: widget.child,
    ),
  );
}
