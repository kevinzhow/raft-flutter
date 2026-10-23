import 'package:material_ui/material_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';

/// An animated indicator showing three dots bouncing, typically used to show
/// that another user is typing.
class IsTypingIndicator extends StatefulWidget {
  /// Size of each dot.
  final double size;

  /// Color of the dots. Defaults to the theme's `onSurface` color.
  final Color? color;

  /// Duration of a single bounce animation cycle for a dot.
  final Duration? duration;

  /// Horizontal spacing between the dots.
  final double spacing;

  /// Creates an animated typing indicator.
  const IsTypingIndicator({
    super.key,
    this.size = 6,
    this.color,
    this.duration = const Duration(milliseconds: 150),
    this.spacing = 3,
  });

  @override
  State<IsTypingIndicator> createState() => _IsTypingIndicatorState();
}

class _IsTypingIndicatorState extends State<IsTypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<CurvedAnimation> _curves;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: the dots hold still instead of bouncing for as long as
    // someone is typing.
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    if (reduced) {
      for (final controller in _controllers) {
        controller.stop();
      }
    } else if (!_controllers.any((controller) => controller.isAnimating)) {
      _controllers[0].forward();
    }
  }

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(vsync: this, duration: widget.duration),
    );

    _curves = [
      for (final controller in _controllers)
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
    ];

    _controllers[0].forward();

    _controllers[0].addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controllers[0].reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controllers[1].forward();
      }
    });

    _controllers[1].addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controllers[1].reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controllers[2].forward();
      }
    });

    _controllers[2].addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controllers[2].reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controllers[0].forward();
      }
    });
  }

  @override
  void dispose() {
    for (final curve in _curves) {
      curve.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _resolveDotColor(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.size / 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: widget.spacing,
        children: List.generate(3, (index) {
          if (_reduced) {
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            );
          }
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0),
              end: Offset(0, -0.5),
            ).animate(_curves[index]),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }

  Color? _resolveDotColor(BuildContext context) {
    if (widget.color != null) return widget.color;

    try {
      return context.select((ChatTheme theme) => theme.colors.onSurface);
    } catch (_) {
      return null;
    }
  }
}
