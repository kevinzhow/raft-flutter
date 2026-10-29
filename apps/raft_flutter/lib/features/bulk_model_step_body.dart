import 'package:flutter/widgets.dart';

/// Web `StepBody` (BulkChangeModelDialog): the steps share one shell. The
/// shell's height follows its content (`transition-[height] duration-200
/// ease-out`) and a newly shown step slides 16px in from the right while it
/// fades in (`bulk-model-step-in`, 200ms ease-out). Reduced motion switches
/// instantly.
class BulkModelStepBody extends StatelessWidget {
  const BulkModelStepBody({
    super.key,
    required this.stepKey,
    required this.child,
  });

  /// The step shown; a new value restarts the slide/fade.
  final String stepKey;
  final Widget child;

  static const duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    // `-m-1 overflow-hidden` with `p-1` inside: the clip box is 4px larger
    // than the content so brutal's offset shadows and focus rings are kept.
    final step = _StepIn(
      key: ValueKey(stepKey),
      reduced: reduced,
      child: child,
    );
    return ClipRect(
      clipper: const _Grown(4),
      // AnimatedSize cannot run for zero time, so reduced motion skips it.
      child: reduced
          ? step
          : AnimatedSize(
              duration: duration,
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              child: step,
            ),
    );
  }
}

class _Grown extends CustomClipper<Rect> {
  const _Grown(this.by);
  final double by;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-by, -by, size.width + by, size.height + by);
  @override
  bool shouldReclip(_Grown old) => old.by != by;
}

class _StepIn extends StatefulWidget {
  const _StepIn({super.key, required this.reduced, required this.child});
  final bool reduced;
  final Widget child;
  @override
  State<_StepIn> createState() => _StepInState();
}

class _StepInState extends State<_StepIn> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: BulkModelStepBody.duration,
    value: widget.reduced ? 1 : 0,
  );
  late final CurvedAnimation progress = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduced) controller.forward();
  }

  @override
  void didUpdateWidget(_StepIn old) {
    super.didUpdateWidget(old);
    if (widget.reduced) controller.value = 1;
  }

  @override
  void dispose() {
    progress.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: progress.value,
      child: Transform.translate(
        offset: Offset(16 * (1 - progress.value), 0),
        child: child,
      ),
    ),
  );
}
