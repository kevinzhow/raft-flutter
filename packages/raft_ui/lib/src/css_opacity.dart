import 'package:flutter/widgets.dart';

/// The compositing boundary measured in the mounted Source component.
enum RaftOpacityCompositing {
  /// A separate opacity layer, used by ordinary dialogs and Composer actions.
  layer,

  /// Alpha-only filtering, used by the onboarding footer's grouped surface.
  alphaFilter,
}

/// CSS group opacity without an intermediate 8-bit premultiplied-alpha round.
///
/// A complex surface rendered with [Opacity] can lose one RGB step before
/// compositing onto its parent. An alpha-only color filter matches Chromium's
/// onboarding-footer compositing while leaving colors and shadow layers intact.
/// Ordinary dialogs and Composer actions have a different Chromium compositing
/// boundary and keep [Opacity]; this wrapper does not replace it globally.
/// The wrappers keep their identity when opacity changes, so a live editor
/// retains its input connection. Zero opacity keeps [Opacity]'s semantics rule.
class RaftCssOpacity extends StatelessWidget {
  const RaftCssOpacity({super.key, required this.opacity, required this.child})
    : assert(opacity >= 0 && opacity <= 1);

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity == 0 ? 0 : 1,
    child: ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        opacity,
        0,
      ]),
      child: child,
    ),
  );
}
